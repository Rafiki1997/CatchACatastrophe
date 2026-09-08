--!strict
-- "Store": the Robux items. Passes, Coins, Boosts and the Cosmic Egg.
--
-- Two rules this panel keeps:
--   * Nothing pretends to be for sale. An item with no Creator Dashboard id
--     yet says "Coming soon" on a disabled button rather than opening a window
--     that cannot work.
--   * The egg says what it does before it takes anything. Its odds are on the
--     tab, in plain percentages, next to the pity lines that say how many
--     hatches are left before each chase tier is guaranteed. The tab is hidden
--     outright for accounts whose policy restricts paid random items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)
local EggModels = require(ReplicatedStorage.Shared.Models.EggModels)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local Store = Config.Store
local Rarities = Config.Rarities

local TABS = { "Passes", "Coins", "Boosts", "Eggs" }

local built = false
local gui: ScreenGui
local panel: any
local activeTab = "Passes"
local scrolls: { [string]: ScrollingFrame } = {}
local rows: { [string]: any } = {}
local eggUi: any = nil
local reveal: any = nil

local function robuxText(entry: any): string
	return tostring(entry.robuxHint) .. " R$"
end

-- Disclosed odds have to be the real odds, so this keeps a decimal wherever one
-- exists rather than rounding: Mythic is 2.5%, not 3%.
local function percentText(percent: number): string
	local rounded = math.round(percent * 100) / 100
	if rounded == math.floor(rounded) then
		return tostring(math.floor(rounded)) .. "%"
	end
	return tostring(rounded) .. "%"
end

-- One row per catalogue entry: icon, name, what it does, and the button. Eggs
-- show the actual egg instead of a glyph, since that is what is being sold.
local function createRow(parent: Instance, entry: any, order: number, onBuy: () -> ()): any
	local card = W.card(parent, 78, order)
	local eggId = if entry.grant and entry.grant.kind == "eggs" then entry.grant.eggId else nil
	if eggId then
		local vp = W.viewport(card, UDim2.new(0, 52, 0, 62), UDim2.new(0, 8, 0.5, -31), Theme.colors.bgDeep)
		local ok, model = pcall(EggModels.build, eggId)
		if ok then
			vp.setModel(model)
		end
	else
		W.label({
			parent = card,
			text = entry.icon,
			size = UDim2.new(0, 46, 0, 46),
			position = UDim2.new(0, 10, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			textSize = 24,
			xalign = Enum.TextXAlignment.Center,
			bg = Theme.colors.bgDeep,
			radius = Theme.sizes.radiusSmall,
		})
	end
	W.label({
		parent = card,
		text = entry.name,
		size = UDim2.new(1, -210, 0, 22),
		position = UDim2.new(0, 66, 0, 12),
		textSize = 17,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	local detail = W.label({
		parent = card,
		text = entry.desc,
		size = UDim2.new(1, -210, 0, 34),
		position = UDim2.new(0, 66, 0, 34),
		textSize = 13,
		color = Theme.colors.textDim,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = robuxText(entry),
		size = UDim2.new(0, 118, 0, 46),
		position = UDim2.new(1, -12, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 16,
		wrap = true,
		onClick = onBuy,
	})
	return { frame = card, button = button, detail = detail }
end

-- Disabled with a reason, or buyable. Everything reads "Coming soon" until the
-- owner creates the products and pastes their ids into Config.Store.
local function setRowState(row: any, entry: any, ownedText: string?)
	if ownedText then
		row.button.Text = ownedText
		W.setEnabled(row.button, false)
	elseif not Store.isLive(entry) then
		row.button.Text = "Coming\nsoon"
		W.setEnabled(row.button, false)
	else
		row.button.Text = robuxText(entry)
		W.setEnabled(row.button, true)
	end
end

-- ---------------------------------------------------------------- hatch reveal

local function buildReveal(parent: Instance)
	local shade = W.frame({
		parent = parent,
		name = "HatchReveal",
		size = UDim2.new(1, 0, 1, 0),
		color = Theme.colors.bgDeep,
		transparency = 0.12,
		zindex = 40,
		visible = false,
	})
	local title = W.label({
		parent = shade,
		text = "HATCHED!",
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.new(0, 0, 0, 10),
		textSize = 26,
		xalign = Enum.TextXAlignment.Center,
		font = Theme.fonts.title,
		color = Theme.colors.accent,
		zindex = 41,
	})
	local grid = W.frame({
		parent = shade,
		size = UDim2.new(1, -24, 1, -110),
		position = UDim2.new(0, 12, 0, 52),
		transparency = 1,
		zindex = 41,
	})
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 118, 0, 118)
	layout.CellPadding = UDim2.new(0, 8, 0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = grid
	W.button({
		parent = shade,
		text = "Nice!",
		size = UDim2.new(0, 150, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(0.5, 0, 1, -14),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 16,
		zindex = 41,
		onClick = function()
			shade.Visible = false
		end,
	})
	reveal = { frame = shade, grid = grid, title = title, cells = {} }
end

local function showReveal(results: { any })
	if not reveal then
		return
	end
	for _, cell in reveal.cells do
		cell:Destroy()
	end
	reveal.cells = {}
	local bestRank, bestRarity = 0, ""
	for i, result in results do
		local def = Config.Species.byId[result.speciesId]
		local color = Rarities.color(result.rarity)
		local cell = W.frame({
			parent = reveal.grid,
			size = UDim2.new(0, 118, 0, 118),
			color = Theme.colors.bg,
			radius = Theme.sizes.radiusSmall,
			stroke = color,
			strokeThickness = 3,
			order = i,
			zindex = 42,
		})
		local vp = W.viewport(cell, UDim2.new(1, -8, 0, 76), UDim2.new(0, 4, 0, 4))
		vp.frame.ZIndex = 43
		local ok, model = pcall(CreatureModels.build, result.speciesId)
		if ok then
			vp.setModel(model)
		end
		W.label({
			parent = cell,
			text = if def then def.name else result.speciesId,
			size = UDim2.new(1, -8, 0, 16),
			position = UDim2.new(0, 4, 0, 82),
			textSize = 12,
			xalign = Enum.TextXAlignment.Center,
			color = Theme.colors.text,
			zindex = 43,
		})
		W.label({
			parent = cell,
			text = Rarities.label(result.rarity),
			size = UDim2.new(1, -8, 0, 14),
			position = UDim2.new(0, 4, 0, 98),
			textSize = 12,
			xalign = Enum.TextXAlignment.Center,
			color = color,
			zindex = 43,
		})
		table.insert(reveal.cells, cell)
		if Rarities.rank(result.rarity) > bestRank then
			bestRank = Rarities.rank(result.rarity)
			bestRarity = result.rarity
		end
	end
	-- a chase tier is the moment, so the card says which one instead of "hatched"
	reveal.title.Text = if Rarities.isEggTier(bestRarity) then Rarities.label(bestRarity) .. "!" else "HATCHED!"
	reveal.title.TextColor3 = if bestRank > 0 then Rarities.color(bestRarity) else Theme.colors.accent
	reveal.frame.Visible = true
	local snap = State.get()
	if not snap or not snap.settings.reducedMotion then
		W.pop(reveal.frame, 1.03)
	end
end

-- ---------------------------------------------------------------- eggs tab

local function buildEggTab(parent: Instance)
	local egg = Store.eggs.cosmic_egg
	local odds = W.card(parent, 176, 1)
	-- the egg itself, turning slowly, so the tab leads with the thing it sells
	local hero = W.viewport(odds, UDim2.new(0, 108, 0, 150), UDim2.new(1, -14, 0.5, -75), Theme.colors.bgDeep)
	hero.frame.AnchorPoint = Vector2.new(1, 0)
	local okHero, heroModel = pcall(EggModels.build, "cosmic_egg")
	if okHero then
		hero.setModel(heroModel)
	end
	W.label({
		parent = odds,
		text = egg.name .. " odds",
		size = UDim2.new(1, -140, 0, 20),
		position = UDim2.new(0, 10, 0, 8),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	for i, row in Store.eggOdds("cosmic_egg") do
		local column = (i - 1) % 2
		local line = math.floor((i - 1) / 2)
		W.label({
			parent = odds,
			text = Rarities.label(row.rarity) .. "   " .. percentText(row.percent),
			size = UDim2.new(0.36, -12, 0, 18),
			position = UDim2.new(0.36 * column, 10, 0, 32 + line * 20),
			textSize = 13,
			color = Rarities.color(row.rarity),
		})
	end
	local pityLabel = W.label({
		parent = odds,
		text = "",
		size = UDim2.new(1, -140, 0, 34),
		position = UDim2.new(0, 10, 1, -40),
		textSize = 12,
		color = Theme.colors.textDim,
		wrap = true,
	})

	local haveCard = W.card(parent, 74, 2)
	local haveLabel = W.label({
		parent = haveCard,
		text = "",
		size = UDim2.new(1, -270, 0, 46),
		position = UDim2.new(0, 12, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	local hatchOne = W.button({
		parent = haveCard,
		text = "Hatch 1",
		size = UDim2.new(0, 112, 0, 46),
		position = UDim2.new(1, -134, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accentAlt,
		textColor = Theme.colors.ink,
		textSize = 15,
		onClick = function()
			Net.fire("HatchEgg", "cosmic_egg", 1)
		end,
	})
	local hatchMany = W.button({
		parent = haveCard,
		text = "Hatch " .. tostring(Store.hatchBatch),
		size = UDim2.new(0, 112, 0, 46),
		position = UDim2.new(1, -12, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 15,
		onClick = function()
			Net.fire("HatchEgg", "cosmic_egg", Store.hatchBatch)
		end,
	})
	eggUi = { pity = pityLabel, have = haveLabel, hatchOne = hatchOne, hatchMany = hatchMany }
end

-- ---------------------------------------------------------------- update

local function updatePasses(snap: Snapshot)
	for _, pass in Store.passes do
		local row = rows["pass:" .. pass.id]
		if row then
			setRowState(row, pass, if snap.store.passes[pass.id] then "Owned" else nil)
		end
	end
end

local function updateProducts(snap: Snapshot)
	for _, product in Store.products do
		local row = rows["product:" .. product.id]
		if row then
			setRowState(row, product, nil)
			if product.grant.kind == "boost" then
				local live = snap.store.boosts[product.grant.boostId]
				if live then
					local left = math.max(0, live.expiresAt - State.now())
					row.detail.Text = product.desc .. "   Running: " .. Format.clock(left) .. " left."
				else
					row.detail.Text = product.desc
				end
			end
		end
	end
end

local function updateEggs(snap: Snapshot)
	if not eggUi then
		return
	end
	local owned = snap.store.eggs.counts.cosmic_egg or 0
	eggUi.have.Text = if owned > 0
		then "You have " .. tostring(owned) .. " Cosmic Egg" .. (if owned == 1 then "" else "s")
		else "No Cosmic Eggs yet. Buy some below."
	W.setEnabled(eggUi.hatchOne, owned >= 1)
	W.setEnabled(eggUi.hatchMany, owned >= Store.hatchBatch)

	local lines = {}
	for _, entry in Store.pityRemaining("cosmic_egg", snap.store.eggs.pity.cosmic_egg) do
		table.insert(lines, Rarities.label(entry.rarity) .. " within " .. tostring(entry.remaining) .. " hatches")
	end
	eggUi.pity.Text = "Guaranteed: " .. table.concat(lines, "   ·   ")
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	if not panel.frame.Visible then
		return
	end
	-- The whole tab goes when the account cannot buy random items, rather than
	-- showing an egg that refuses at the last step.
	local eggsAllowed = snap.store.eggAllowed
	if not eggsAllowed and activeTab == "Eggs" then
		activeTab = "Passes"
	end
	for _, name in TABS do
		local scroll = scrolls[name]
		if scroll then
			scroll.Visible = name == activeTab and (name ~= "Eggs" or eggsAllowed)
		end
	end
	updatePasses(snap)
	updateProducts(snap)
	updateEggs(snap)
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
	panel = W.panel(gui, "Premium", "Premium Depot", UDim2.new(0, 660, 0, 470))
	local body = panel.body

	local _, selectTab = W.tabs(body, TABS, function(name)
		activeTab = name
		refresh()
	end)

	for _, name in TABS do
		local scroll = W.scroll(body, UDim2.new(1, 0, 1, -66), UDim2.new(0, 0, 0, 66), 6)
		scroll.Visible = false
		scrolls[name] = scroll
	end

	for i, pass in Store.passes do
		rows["pass:" .. pass.id] = createRow(scrolls.Passes, pass, i, function()
			Net.fire("PromptPurchase", "pass", pass.id)
		end)
	end
	local coinOrder, boostOrder, eggOrder = 0, 0, 10
	for _, product in Store.products do
		local kind = product.grant.kind
		local parent = if kind == "coins" then scrolls.Coins elseif kind == "boost" then scrolls.Boosts else scrolls.Eggs
		local order
		if kind == "coins" then
			coinOrder += 1
			order = coinOrder
		elseif kind == "boost" then
			boostOrder += 1
			order = boostOrder
		else
			eggOrder += 1
			order = eggOrder
		end
		rows["product:" .. product.id] = createRow(parent, product, order, function()
			Net.fire("PromptPurchase", "product", product.id)
		end)
	end

	buildEggTab(scrolls.Eggs)
	buildReveal(panel.frame)

	Net.on("HatchResult", function(results)
		if typeof(results) == "table" and #results > 0 then
			showReveal(results)
		end
	end)

	built = true
	panel.refresh = refresh
	selectTab("Passes")
	refresh()
end

return M
