--!strict
-- "Atlas": the permanent record of every species discovered, its variants,
-- perfect captures, and the collection milestones.
--
-- Undiscovered species show as a black silhouette of the real model, so the
-- shape is a genuine hint rather than a question mark.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local built = false
local gui: ScreenGui
local panel: any
local headerLabel: TextLabel
local cardScroll: ScrollingFrame
local milestoneScroll: ScrollingFrame
local activeRegion = Config.Regions.list[1].id

local cards: { [string]: any } = {}
local milestoneRows: { [number]: any } = {}

-- Building 24 viewport models at once stutters; spread them over frames.
local buildQueue: { () -> () } = {}
local function queueBuild(job: () -> ())
	table.insert(buildQueue, job)
end
task.spawn(function()
	while true do
		task.wait(0.06)
		local job = table.remove(buildQueue, 1)
		if job then
			pcall(job)
		end
	end
end)

local function ownedCount(snap: Snapshot, speciesId: string): number
	local n = 0
	for _, entry in snap.creatures do
		if entry.id == speciesId then
			n += 1
		end
	end
	return n
end

local function createCard(speciesId: string): any
	local def = Config.Species.byId[speciesId]
	local card = W.frame({
		parent = cardScroll,
		name = speciesId,
		size = UDim2.new(0, 0, 0, 0),
		color = Theme.colors.bgAlt,
		radius = Theme.sizes.radiusSmall,
		stroke = Theme.colors.ink,
		strokeThickness = 2,
	})

	local vp = W.viewport(card, UDim2.new(1, -8, 0, 96), UDim2.new(0, 4, 0, 4), Theme.colors.bgDeep)

	local nameLabel = W.label({
		parent = card,
		size = UDim2.new(1, -8, 0, 20),
		position = UDim2.new(0, 4, 0, 102),
		textSize = 14,
		font = Theme.fonts.bold,
	})
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local rarityLabel = W.label({
		parent = card,
		size = UDim2.new(1, -8, 0, 16),
		position = UDim2.new(0, 4, 0, 122),
		textSize = 12,
		color = Theme.colors.textDim,
	})
	local incomeLabel = W.label({
		parent = card,
		size = UDim2.new(1, -8, 0, 16),
		position = UDim2.new(0, 4, 0, 138),
		textSize = 12,
		color = Theme.colors.coin,
	})
	local statsLabel = W.label({
		parent = card,
		size = UDim2.new(1, -8, 0, 40),
		position = UDim2.new(0, 4, 0, 154),
		textSize = 11,
		color = Theme.colors.textDim,
		wrap = true,
	})
	statsLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local variantRow = W.frame({
		parent = card,
		size = UDim2.new(1, -8, 0, 18),
		position = UDim2.new(0, 4, 1, -22),
		transparency = 1,
	})
	W.list(variantRow, Enum.FillDirection.Horizontal, 3)
	local variantBadges: { [string]: TextLabel } = {}
	for i, variant in Config.Variants.order do
		local info = Config.Variants.info[variant]
		variantBadges[variant] = W.badge(variantRow, if variant == "Normal" then "N" else info.icon, info.color, i)
	end

	local record = {
		frame = card,
		vp = vp,
		nameLabel = nameLabel,
		rarityLabel = rarityLabel,
		incomeLabel = incomeLabel,
		statsLabel = statsLabel,
		variantBadges = variantBadges,
		modelKey = "",
		def = def,
	}
	cards[speciesId] = record
	return record
end

local function updateCard(card: any, snap: Snapshot, speciesId: string)
	local def = Config.Species.byId[speciesId]
	if not def then
		return
	end
	local entry = snap.atlas.species[speciesId]
	local discovered = entry ~= nil

	local wantKey = if discovered then "known" else "silhouette"
	if card.modelKey ~= wantKey then
		card.modelKey = wantKey
		queueBuild(function()
			if card.frame.Parent == nil then
				return
			end
			card.vp.setModel(CreatureModels.build(speciesId, "Normal", not discovered))
		end)
	end

	if discovered then
		card.nameLabel.Text = def.name
		card.nameLabel.TextColor3 = Config.Rarities.color(def.rarity)
		card.rarityLabel.Text = Config.Rarities.label(def.rarity)
		card.incomeLabel.Text = Format.abbreviate(Config.Species.baseIncome(speciesId) * snap.relaunchMult) .. "/s"
		local owned = ownedCount(snap, speciesId)
		card.statsLabel.Text = "Owned " .. tostring(owned) .. "   Caught " .. tostring(entry.caught) .. "\nPerfect " .. tostring(entry.perfect) .. "   Found " .. Format.date(entry.firstAt)
		for variant, badge in card.variantBadges do
			badge.Visible = entry.variants[variant] == true
		end
	else
		card.nameLabel.Text = "???"
		card.nameLabel.TextColor3 = Theme.colors.textDim
		card.rarityLabel.Text = Config.Rarities.label(def.rarity)
		card.incomeLabel.Text = ""
		card.statsLabel.Text = def.silhouette
		for _, badge in card.variantBadges do
			badge.Visible = false
		end
	end
end

local function createMilestoneRow(milestone: any): any
	local card = W.card(milestoneScroll, 62)
	local title = W.label({
		parent = card,
		size = UDim2.new(1, -140, 0, 20),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	local body = W.label({
		parent = card,
		size = UDim2.new(1, -140, 0, 30),
		position = UDim2.new(0, 10, 0, 26),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = "Claim",
		size = UDim2.new(0, 116, 0, 40),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 14,
		onClick = function()
			Net.fire("ClaimMilestone", milestone.count)
		end,
	})
	local record = { frame = card, title = title, body = body, button = button, milestone = milestone }
	milestoneRows[milestone.count] = record
	return record
end

local function updateMilestoneRow(row: any, snap: Snapshot)
	local m = row.milestone
	local claimed = snap.atlas.claimed[tostring(m.count)] == true
	local reached = snap.atlas.discovered >= m.count
	row.title.Text = tostring(m.count) .. " species  ·  " .. m.title
	row.body.Text = "Unlocks " .. m.decorationName .. " for your city."
	if claimed then
		row.button.Text = "Claimed"
		W.setEnabled(row.button, false)
	elseif reached then
		row.button.Text = "Claim"
		W.setEnabled(row.button, true)
	else
		row.button.Text = tostring(snap.atlas.discovered) .. " / " .. tostring(m.count)
		W.setEnabled(row.button, false)
	end
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	headerLabel.Text = "Discovered " .. tostring(snap.atlas.discovered) .. " / " .. tostring(Config.Species.count)
	if not panel.frame.Visible then
		return
	end

	local list = Config.Species.byRegion[activeRegion] or {}
	local found = 0
	for _, def in list do
		if snap.atlas.species[def.id] then
			found += 1
		end
	end
	local region = Config.Regions.byId[activeRegion]
	headerLabel.Text ..= "   ·   " .. (if region then region.name else activeRegion) .. " " .. tostring(found) .. " / " .. tostring(#list)

	for speciesId, card in cards do
		local def = Config.Species.byId[speciesId]
		card.frame.Visible = def ~= nil and def.region == activeRegion
	end
	for _, def in list do
		local card = cards[def.id] or createCard(def.id)
		card.frame.Visible = true
		card.frame.LayoutOrder = Config.Rarities.rank(def.rarity)
		updateCard(card, snap, def.id)
	end

	for _, m in Config.Milestones.list do
		local row = milestoneRows[m.count] or createMilestoneRow(m)
		updateMilestoneRow(row, snap)
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
	-- 640 x 440 truncated every region tab and cut the card text; six 136 px
	-- tabs and four 200 px cards need the width, three description lines the height
	panel = W.panel(gui, "Atlas", "Catastrophe Atlas", UDim2.new(0, 880, 0, 600))
	local body = panel.body

	headerLabel = W.label({
		parent = body,
		text = "Discovered 0 / 24",
		size = UDim2.new(1, 0, 0, 20),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})

	local names = {}
	for _, def in Config.Regions.list do
		table.insert(names, def.name)
	end
	local tabBar = W.frame({ parent = body, size = UDim2.new(1, 0, 0, 32), position = UDim2.new(0, 0, 0, 24), transparency = 1 })
	W.tabs(tabBar, names, function(name)
		for _, def in Config.Regions.list do
			if def.name == name then
				activeRegion = def.id
			end
		end
		refresh()
	end, 32)

	cardScroll = W.scrollGrid(body, UDim2.new(0, 200, 0, 224), UDim2.new(1, 0, 0, 240), UDim2.new(0, 0, 0, 62), 8)

	W.label({
		parent = body,
		text = "Collection milestones",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 0, 308),
		textSize = 14,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})
	milestoneScroll = W.scroll(body, UDim2.new(1, 0, 1, -332), UDim2.new(0, 0, 0, 332), 6)

	built = true
	panel.refresh = refresh
	refresh()
end

return M
