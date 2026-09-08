--!strict
-- "Supply Depot": everything you buy with Coins, and everything you have earned.
--
-- It is deliberately the shop players meet first. Robux lives in a separate
-- panel, so a child browsing what their Coins can do never lands in a price
-- list by accident, and Coins keep a use after the upgrade tree runs out.
--
-- Three tabs, one per cosmetic family: Style (auras, mostly earned), Decor (one
-- ornament per corner of your city) and Ground (what your city is built on).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local Cosmetics = Config.Cosmetics

-- tab -> the family it shows
local TABS = { "Style", "Decor", "Ground" }
local FAMILY_OF = { Style = "aura", Decor = "decor", Ground = "skin" }

local built = false
local gui: ScreenGui
local panel: any
local activeTab = "Style"
local scrolls: { [string]: ScrollingFrame } = {}
local rows: { [string]: any } = {}

local function regionName(regionId: string): string
	local region = Config.Regions.byId[regionId]
	return if region then region.name else regionId
end

local function createRow(parent: Instance, item: any, order: number): any
	local card = W.card(parent, 74, order)
	-- a dot in the item's own colour: for an aura it is the particle, for a
	-- decoration or a ground it is the paint
	W.label({
		parent = card,
		text = if item.family == "aura" then "●" else "■",
		size = UDim2.new(0, 46, 0, 46),
		position = UDim2.new(0, 10, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		textSize = 26,
		xalign = Enum.TextXAlignment.Center,
		color = item.color,
		bg = Theme.colors.bgDeep,
		radius = Theme.sizes.radiusSmall,
	})
	W.label({
		parent = card,
		text = item.name,
		size = UDim2.new(1, -210, 0, 20),
		position = UDim2.new(0, 66, 0, 10),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	local detail = W.label({
		parent = card,
		text = item.desc,
		size = UDim2.new(1, -210, 0, 34),
		position = UDim2.new(0, 66, 0, 30),
		textSize = 12,
		color = Theme.colors.textDim,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = "",
		size = UDim2.new(0, 118, 0, 46),
		position = UDim2.new(1, -12, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 15,
		wrap = true,
		onClick = function()
			local snap = State.get()
			if not snap then
				return
			end
			if snap.cosmetics.owned[item.id] then
				local key = Cosmetics.slotKeyOf[item.id] or item.family
				local wearing = snap.cosmetics.equipped[key] == item.id
				Net.fire("EquipCosmetic", key, if wearing then "" else item.id)
			else
				Net.fire("BuyCosmetic", item.id)
			end
		end,
	})
	return { frame = card, button = button, detail = detail, item = item }
end

-- Owned items offer Wear or Wearing; unowned ones show a price, or what to do
-- when they cannot be bought at all.
local function updateRow(row: any, snap: Snapshot)
	local item = row.item
	local owned = snap.cosmetics.owned[item.id] == true
	local key = Cosmetics.slotKeyOf[item.id] or item.family
	local price = Cosmetics.price(item)
	if owned then
		if snap.cosmetics.equipped[key] == item.id then
			row.button.Text = if item.family == "aura" then "Wearing" else "Placed"
			W.setButtonColor(row.button, Theme.colors.success, Theme.colors.ink)
		else
			row.button.Text = if item.family == "aura" then "Wear" else "Place"
			W.setButtonColor(row.button, Theme.colors.accentAlt, Theme.colors.ink)
		end
		W.setEnabled(row.button, true)
	elseif price then
		row.button.Text = Format.abbreviate(price) .. "\nCoins"
		W.setButtonColor(row.button, Theme.colors.accent, Theme.colors.ink)
		W.setEnabled(row.button, snap.coins >= price)
	else
		row.button.Text = "Locked"
		W.setEnabled(row.button, false)
		W.tooltip(row.button :: GuiObject, Cosmetics.requirement(item, regionName))
	end
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	if not panel.frame.Visible then
		return
	end
	for _, name in TABS do
		local scroll = scrolls[name]
		if scroll then
			scroll.Visible = name == activeTab
		end
	end
	for _, row in rows do
		updateRow(row, snap)
	end
end

local function refresh()
	M.update(State.get())
end

function M.init()
	if built then
		return
	end
	gui = W.screenGui("Panels", 10)
	if not gui:FindFirstChildOfClass("UIScale") then
		W.attachScale(gui)
	end
	panel = W.panel(gui, "Supply", "Supply Depot", UDim2.new(0, 660, 0, 470))
	local body = panel.body

	local _, selectTab = W.tabs(body, TABS, function(name)
		activeTab = name
		refresh()
	end)

	for _, name in TABS do
		local scroll = W.scroll(body, UDim2.new(1, 0, 1, -66), UDim2.new(0, 0, 0, 66), 6)
		scroll.Visible = false
		scrolls[name] = scroll
		local family = FAMILY_OF[name]
		local header = if name == "Style" then "Auras follow you around. Most are earned by playing; the prestige ones cannot be bought at all."
			elseif name == "Decor" then "One ornament per corner of your city. Anyone who visits you will see them."
			else "What your whole city is built on."
		W.label({
			parent = W.card(scroll, 40, 0),
			text = header,
			size = UDim2.new(1, -20, 1, -8),
			position = UDim2.new(0, 10, 0, 4),
			textSize = 13,
			color = Theme.colors.textDim,
			wrap = true,
		})
		for i, item in Cosmetics.byFamily[family] or {} do
			rows[item.id] = createRow(scroll, item, i)
		end
	end

	built = true
	panel.refresh = refresh
	selectTab("Style")
	refresh()
end

return M
