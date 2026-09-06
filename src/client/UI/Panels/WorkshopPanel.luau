--!strict
-- "Workshop": the coin upgrades and the six region unlocks.
-- Every card says what the upgrade does now, what it would do next, and what
-- it costs, so nothing has to be guessed or remembered.

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

local built = false
local gui: ScreenGui
local panel: any
local coinsLabel: TextLabel
local upgradeScroll: ScrollingFrame
local regionScroll: ScrollingFrame
local activeTab = "Upgrades"
local upgradeRows: { [string]: any } = {}
local regionRows: { [string]: any } = {}

-- What the level number means in words, for the "now / next" line.
local function effectText(id: string, level: number, snap: Snapshot): string
	local def = Config.Economy.upgradeById[id]
	if not def then
		return ""
	end
	if id == "tether_speed" then
		return ("x%.2f capture speed"):format(1 + level * def.perLevel)
	elseif id == "tether_range" then
		return tostring(math.min(Config.Capture.tetherRange + level * def.perLevel, def.cap or 30)) .. " studs"
	elseif id == "move_speed" then
		return tostring(math.min(16 + level * def.perLevel, def.cap or 24)) .. " walk speed"
	elseif id == "habitat_capacity" then
		return tostring(math.min(Config.Relaunch.startingPads(snap.relaunch) + level, Config.Economy.deploy.hardCap)) .. " work pads"
	elseif id == "circuit_efficiency" then
		return "+" .. Format.percent(level * def.perLevel) .. " circuit bonus"
	elseif id == "bank_capacity" then
		return Format.duration(Config.Economy.income.bankCapSeconds + level * def.perLevel) .. " of bank"
	elseif id == "storage" then
		return tostring(math.min(Config.Economy.storage.base + level * def.perLevel, def.cap or 120)) .. " creature storage"
	elseif id == "decoration" then
		return if level <= 0 then "Plain lot" else "Decoration tier " .. tostring(level)
	end
	return tostring(level)
end

local function maxLevelFor(id: string, snap: Snapshot): number
	local def = Config.Economy.upgradeById[id]
	if not def then
		return 0
	end
	if id == "habitat_capacity" then
		return math.max(0, Config.Economy.deploy.hardCap - Config.Relaunch.startingPads(snap.relaunch))
	end
	return def.maxLevel
end

local function createUpgradeRow(def: any): any
	local card = W.card(upgradeScroll, 84)
	local icon = W.label({
		parent = card,
		text = def.icon,
		size = UDim2.new(0, 46, 0, 46),
		position = UDim2.new(0, 8, 0, 8),
		textSize = 26,
		bg = Theme.colors.bgDeep,
		radius = Theme.sizes.radiusSmall,
	})
	local title = W.label({
		parent = card,
		text = def.name,
		size = UDim2.new(1, -190, 0, 20),
		position = UDim2.new(0, 62, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	local levelLabel = W.label({
		parent = card,
		size = UDim2.new(1, -190, 0, 18),
		position = UDim2.new(0, 62, 0, 26),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	local effect = W.label({
		parent = card,
		size = UDim2.new(1, -190, 0, 32),
		position = UDim2.new(0, 62, 0, 44),
		textSize = 12,
		color = Theme.colors.accentAlt,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = "Buy",
		size = UDim2.new(0, 120, 0, 46),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 14,
		wrap = true,
		onClick = function()
			Net.fire("BuyUpgrade", def.id)
		end,
	})
	-- the button shows an abbreviated price; the tooltip gives the exact figure
	-- and how far off it is
	W.tooltip(button, function()
		local snap = State.get()
		if not snap then
			return def.name
		end
		local level = snap.upgrades[def.id] or 0
		if level >= maxLevelFor(def.id, snap) then
			return def.name .. " is at its maximum level."
		end
		local cost = Config.Economy.upgradeCost(def.id, level)
		local short = cost - snap.coins
		return def.name
			.. "\nCost: "
			.. Format.commas(cost)
			.. " Coins"
			.. (if short > 0 then "\nYou need " .. Format.commas(short) .. " more." else "\nYou can afford this.")
	end)

	local record = { frame = card, icon = icon, title = title, levelLabel = levelLabel, effect = effect, button = button, def = def }
	upgradeRows[def.id] = record
	return record
end

local function updateUpgradeRow(row: any, snap: Snapshot)
	local def = row.def
	local level = snap.upgrades[def.id] or 0
	local maxLevel = maxLevelFor(def.id, snap)
	row.levelLabel.Text = "Level " .. tostring(level) .. " / " .. tostring(maxLevel) .. "   ·   " .. def.desc

	if level >= maxLevel then
		row.effect.Text = effectText(def.id, level, snap) .. "  (maxed)"
		row.button.Text = "Maxed"
		W.setEnabled(row.button, false)
		return
	end

	row.effect.Text = effectText(def.id, level, snap) .. "  ->  " .. effectText(def.id, level + 1, snap)
	local cost = Config.Economy.upgradeCost(def.id, level)
	row.button.Text = Format.abbreviate(cost) .. "\nCoins"
	W.setEnabled(row.button, snap.coins >= cost)
end

local function createRegionRow(def: any): any
	local card = W.card(regionScroll, 84)
	local swatch = W.frame({
		parent = card,
		size = UDim2.new(0, 10, 1, -16),
		position = UDim2.new(0, 8, 0, 8),
		color = def.color,
		radius = 5,
	})
	local title = W.label({
		parent = card,
		text = def.name,
		size = UDim2.new(1, -190, 0, 20),
		position = UDim2.new(0, 26, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		color = def.color,
		xalign = Enum.TextXAlignment.Left,
	})
	W.label({
		parent = card,
		text = def.element .. "   ·   base " .. Format.abbreviate(def.baseIncome) .. "/s",
		size = UDim2.new(1, -190, 0, 18),
		position = UDim2.new(0, 26, 0, 26),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	W.label({
		parent = card,
		text = def.desc,
		size = UDim2.new(1, -190, 0, 32),
		position = UDim2.new(0, 26, 0, 44),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = "Unlock",
		size = UDim2.new(0, 120, 0, 46),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 14,
		wrap = true,
		onClick = function()
			Net.fire("UnlockRegion", def.id)
		end,
	})
	local record = { frame = card, button = button, def = def, swatch = swatch, title = title }
	card.LayoutOrder = def.index
	regionRows[def.id] = record
	return record
end

local function updateRegionRow(row: any, snap: Snapshot)
	local def = row.def
	if snap.regions[def.id] then
		row.button.Text = "Open"
		W.setEnabled(row.button, false)
	else
		row.button.Text = Format.abbreviate(def.unlockCost) .. "\nCoins"
		W.setEnabled(row.button, snap.coins >= def.unlockCost)
	end
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	coinsLabel.Text = Format.abbreviate(snap.coins) .. " Coins"
	if not panel.frame.Visible then
		return
	end
	upgradeScroll.Visible = activeTab == "Upgrades"
	regionScroll.Visible = activeTab == "Regions"

	if activeTab == "Upgrades" then
		for i, def in Config.Economy.upgrades do
			local row = upgradeRows[def.id] or createUpgradeRow(def)
			row.frame.LayoutOrder = i
			updateUpgradeRow(row, snap)
		end
	else
		for _, def in Config.Regions.list do
			local row = regionRows[def.id] or createRegionRow(def)
			updateRegionRow(row, snap)
		end
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
	panel = W.panel(gui, "Workshop", "Upgrade Workshop", UDim2.new(0, 640, 0, 440))
	local body = panel.body

	coinsLabel = W.label({
		parent = body,
		text = "0 Coins",
		size = UDim2.new(1, 0, 0, 20),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.coin,
		xalign = Enum.TextXAlignment.Left,
	})

	local tabBar = W.frame({ parent = body, size = UDim2.new(1, 0, 0, 34), position = UDim2.new(0, 0, 0, 24), transparency = 1 })
	W.tabs(tabBar, { "Upgrades", "Regions" }, function(name)
		activeTab = name
		refresh()
	end, 34)

	upgradeScroll = W.scroll(body, UDim2.new(1, 0, 1, -66), UDim2.new(0, 0, 0, 66), 6)
	regionScroll = W.scroll(body, UDim2.new(1, 0, 1, -66), UDim2.new(0, 0, 0, 66), 6)
	regionScroll.Visible = false

	built = true
	panel.refresh = refresh
	refresh()
end

return M
