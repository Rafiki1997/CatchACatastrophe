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
local DecorModels = require(ReplicatedStorage.Shared.Models.DecorModels)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)
local DecorPlacer = require(script.Parent.Parent.Parent.Controllers.DecorPlacer)

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
	local card = W.card(parent, 78, order)
	-- a decoration gets a real preview, since "what does it look like" is the
	-- whole question; an aura or a ground is a colour, so a swatch says it
	if item.family == "decor" and DecorModels.has(item.preset) then
		local vp = W.viewport(card, UDim2.new(0, 54, 0, 64), UDim2.new(0, 8, 0.5, -32), Theme.colors.bgDeep)
		local ok, model = pcall(DecorModels.build, item.preset, item.color, item.id)
		if ok and model then
			vp.setModel(model)
		end
	else
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
	end
	W.label({
		parent = card,
		text = item.name,
		size = UDim2.new(1, -250, 0, 20),
		position = UDim2.new(0, 70, 0, 10),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	local detail = W.label({
		parent = card,
		text = item.desc,
		size = UDim2.new(1, -250, 0, 34),
		position = UDim2.new(0, 70, 0, 30),
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
			if not snap.cosmetics.owned[item.id] then
				Net.fire("BuyCosmetic", item.id)
			elseif item.family == "decor" then
				-- choosing where it goes happens in the city, not in this list
				local rot = 0
				for _, entry in snap.cosmetics.placed do
					if entry.id == item.id then
						rot = entry.rot
					end
				end
				DecorPlacer.start(item.id, rot)
			else
				Net.fire("EquipCosmetic", item.family, if snap.cosmetics.equipped[item.family] == item.id then "" else item.id)
			end
		end,
	})
	-- only a decoration can be put away again
	local storeButton: TextButton? = nil
	if item.family == "decor" then
		local made = W.button({
			parent = card,
			name = "PutAway",
			text = "Put away",
			size = UDim2.new(0, 92, 0, 46),
			position = UDim2.new(1, -136, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = Theme.colors.bgAlt,
			textColor = Theme.colors.textDim,
			textSize = 13,
			wrap = true,
			onClick = function()
				local snap = State.get()
				if not snap then
					return
				end
				for slotId, entry in snap.cosmetics.placed do
					if entry.id == item.id then
						Net.fire("StoreDecor", slotId)
						return
					end
				end
			end,
		})
		made.Visible = false
		storeButton = made
	end
	return { frame = card, button = button, storeButton = storeButton, detail = detail, item = item }
end

-- Owned items offer Wear or Wearing; unowned ones show a price, or what to do
-- when they cannot be bought at all.
local function updateRow(row: any, snap: Snapshot)
	local item = row.item
	local owned = snap.cosmetics.owned[item.id] == true
	local price = Cosmetics.price(item)
	if owned and item.family == "decor" then
		-- a decoration is either out in the city or waiting in the inventory,
		-- and either way it can only be touched from home
		local isOut = false
		for _, entry in snap.cosmetics.placed do
			if entry.id == item.id then
				isOut = true
			end
		end
		local canDecorate = DecorPlacer.canDecorate()
		row.button.Text = if isOut then "Move it" else "Place it"
		W.setButtonColor(row.button, if isOut then Theme.colors.accentAlt else Theme.colors.accent, Theme.colors.ink)
		W.setEnabled(row.button, canDecorate)
		row.detail.Text = if not canDecorate then "Stand in your own city to place this."
			elseif isOut then item.desc .. "  It is out in your city."
			else item.desc .. "  Waiting in your inventory."
		if row.storeButton then
			row.storeButton.Visible = isOut
			W.setEnabled(row.storeButton, canDecorate)
		end
		return
	end
	if owned then
		if snap.cosmetics.equipped[item.family] == item.id then
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
			elseif name == "Decor" then "Buy an ornament, then stand in your city and press Place it. You pick the spot and which way it faces."
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
