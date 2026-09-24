--!strict
-- "Creatures": everything the player owns, deployed or stored. Deploy, Store,
-- Move (all through a 6x4 pad picker), Favorite, Sell and Prismatic upgrade
-- all live here. Prices/values shown are display estimates only; the server
-- re-validates and pays its own number.
--
--   CreaturesPanel.init()
--   CreaturesPanel.update(snap)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)
local Types = require(ReplicatedStorage.Shared.Types)

type Snapshot = Types.Snapshot
type CreatureEntry = Types.CreatureEntry

local M = {}

local gui: ScreenGui = nil :: any
local panel: any = nil
local built = false

local headerLabel: TextLabel
local warningLabel: TextLabel
local listScroll: ScrollingFrame
local emptyLabel: TextLabel

local activeTab = "Deployed" -- "Deployed" | "Stored" | "All"
local sortMode = "Income" -- "Income" | "Rarity" | "Region" | "Newest" | "Favorites"
local SORT_MODES = { "Income", "Rarity", "Region", "Newest", "Favorites" }

local ROW_HEIGHT = 136
local STAR_ON = "★" -- favourited
local STAR_OFF = "☆" -- not favourited

local rows: { [string]: any } = {}

-- Model previews are built a few per frame so opening a full storage never
-- freezes the client.
local buildQueue: { () -> () } = {}
local buildRunning = false
local function queueBuild(job: () -> ())
	table.insert(buildQueue, job)
	if buildRunning then
		return
	end
	buildRunning = true
	task.spawn(function()
		while #buildQueue > 0 do
			for _ = 1, 3 do
				local nextJob = table.remove(buildQueue, 1)
				if not nextJob then
					break
				end
				local ok, err = pcall(nextJob)
				if not ok then
					warn("[CreaturesPanel] preview build failed", err)
				end
			end
			task.wait()
		end
		buildRunning = false
	end)
end

-- ------------------------------------------------------------ helpers

-- pad index -> { uid, entry } for every deployed creature.
local function padOccupancy(snap: Snapshot): { [number]: { uid: string, entry: CreatureEntry } }
	local out = {}
	for uid, entry in snap.creatures do
		if entry.pad then
			out[entry.pad] = { uid = uid, entry = entry }
		end
	end
	return out
end

-- Pads unlock as a contiguous block 1..snap.pads.total.
local function padUnlocked(snap: Snapshot, pad: number): boolean
	return pad <= snap.pads.total
end

local function speciesName(id: string): string
	local def = Config.Species.byId[id]
	return if def then def.name else id
end

local function sellEstimate(entry: CreatureEntry): number
	local def = Config.Species.byId[entry.id]
	if not def then
		return 0
	end
	local info = Config.Rarities.info[def.rarity]
	if not info then
		return 0
	end
	return info.sellSeconds * entry.normalCps
end

local function prismaticEligible(snap: Snapshot, entry: CreatureEntry): (boolean, string)
	if entry.variant == "Prismatic" then
		return false, ""
	end
	local mastery = snap.mastery[entry.id]
	local need = Config.Variants.prismatic
	local circuitMin = if mastery then mastery.circuitSeconds / 60 else 0
	local perfect = if mastery then mastery.perfect else 0
	local text = Format.abbreviate(math.floor(circuitMin)) .. " / " .. tostring(need.circuitMinutes) .. " min - "
		.. tostring(perfect) .. " / " .. tostring(need.perfectCaptures) .. " perfect"
	local ready = circuitMin >= need.circuitMinutes and perfect >= need.perfectCaptures
	return ready, text
end

-- ------------------------------------------------------------ pad picker

local function closePadPicker()
	local existing = gui:FindFirstChild("PadPicker")
	if existing then
		existing:Destroy()
	end
end

-- kind: "Deploy" | "Move". For Deploy only free unlocked pads are pickable.
-- For Move, any unlocked pad other than the creature's current one is pickable
-- (server swaps if occupied).
local function openPadPicker(kind: string, uid: string, currentPad: number?)
	closePadPicker()
	local snap = State.get()
	if not snap then
		return
	end
	local occ = padOccupancy(snap)

	local overlay = W.frame({
		parent = gui,
		name = "PadPicker",
		size = UDim2.new(1, 0, 1, 0),
		color = Color3.new(0, 0, 0),
		transparency = 0.45,
		zindex = 60,
	})
	local box = W.frame({
		parent = overlay,
		size = UDim2.new(0, 420, 0, 340),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius + 4,
		stroke = Theme.colors.ink,
		strokeThickness = 4,
		zindex = 61,
	})
	W.label({
		parent = box,
		text = if kind == "Deploy" then "Choose a pad" else "Move to pad",
		size = UDim2.new(1, -24, 0, 32),
		position = UDim2.new(0, 12, 0, 8),
		textSize = Theme.sizes.title,
		font = Theme.fonts.title,
		color = Theme.colors.accent,
		zindex = 62,
	})
	W.button({
		parent = box,
		text = "X",
		size = UDim2.new(0, 36, 0, 32),
		position = UDim2.new(1, -8, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.colors.danger,
		zindex = 63,
		onClick = closePadPicker,
	})

	local gridFrame = W.frame({
		parent = box,
		size = UDim2.new(1, -24, 0, 220),
		position = UDim2.new(0, 12, 0, 48),
		transparency = 1,
		zindex = 62,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 62, 0, 48)
	grid.CellPadding = UDim2.new(0, 4, 0, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	local cols = Config.Circuits.grid.cols
	for pad = 1, Config.Circuits.maxPads do
		local col, row = Config.Circuits.padCoords(pad)
		local unlocked = padUnlocked(snap, pad)
		local occupant = occ[pad]
		local isSelf = currentPad == pad
		local label = tostring(pad)
		local color = Theme.colors.success
		local enabled = true
		if not unlocked then
			color = Theme.colors.bgAlt
			enabled = false
			label = "🔒"
		elseif isSelf then
			color = Theme.colors.accentAlt
			enabled = false
			label = tostring(pad) .. "\n(here)"
		elseif occupant then
			if kind == "Deploy" then
				color = Theme.colors.bgAlt
				enabled = false
			else
				color = Theme.colors.warn
				enabled = true
			end
			label = speciesName(occupant.entry.id)
		end
		local b = W.button({
			parent = gridFrame,
			name = "Pad" .. tostring(pad),
			text = label,
			size = UDim2.new(0, 62, 0, 48),
			color = color,
			textColor = Theme.colors.ink,
			textSize = 11,
			wrap = true,
			order = (row - 1) * cols + col,
			onClick = function()
				closePadPicker()
				if kind == "Deploy" then
					Net.fire("DeployCreature", uid, pad)
				else
					Net.fire("MoveCreature", uid, pad)
				end
			end,
		})
		W.setEnabled(b, enabled, Theme.colors.bgAlt)
	end

	W.label({
		parent = box,
		text = "Green = free · Yellow = swap · Grey = locked/occupied",
		size = UDim2.new(1, -24, 0, 40),
		position = UDim2.new(0, 12, 1, -46),
		textSize = 13,
		wrap = true,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Center,
		zindex = 62,
	})
	W.pop(box, 1.05)
end

-- ------------------------------------------------------------ rows

local function closeCreatureView()
	local view = panel.frame:FindFirstChild("CreatureView")
	if view then
		view:Destroy()
	end
end

local function openCreatureView(entry: CreatureEntry)
	closeCreatureView()
	local def = Config.Species.byId[entry.id]
	if not def then
		return
	end
	local box = W.frame({ parent = panel.frame, name = "CreatureView", size = UDim2.fromScale(1, 1), color = Theme.colors.bg, radius = Theme.sizes.radius, zindex = 60 })
	box.Active = true
	W.label({ parent = box, text = def.name, position = UDim2.fromOffset(16, 12), size = UDim2.new(1, -130, 0, 32), font = Theme.fonts.title, textSize = 24, zindex = 62 })
	W.label({ parent = box, text = Config.Rarities.label(def.rarity) .. " / " .. entry.variant, position = UDim2.fromOffset(16, 48), size = UDim2.new(1, -32, 0, 24), color = Config.Rarities.color(def.rarity), textSize = 16, zindex = 62 })
	W.button({ parent = box, name = "CloseView", text = "Back", size = UDim2.fromOffset(88, 44), position = UDim2.new(1, -104, 0, 12), zindex = 63, onClick = closeCreatureView })
	local vp = W.viewport(box, UDim2.new(1, -32, 1, -144), UDim2.fromOffset(16, 80), Theme.colors.bgDeep)
	vp.frame.ZIndex = 61
	local model = CreatureModels.build(entry.id, entry.variant, false)
	vp.setModel(model)
	local camera = vp.frame.CurrentCamera
	local centre = model:GetBoundingBox().Position
	local offset = if camera then camera.CFrame.Position - centre else Vector3.new(0, 3, -10)
	local angle = 0
	local function rotate(delta: number)
		angle += delta
		if camera then
			camera.CFrame = CFrame.lookAt(centre + CFrame.Angles(0, angle, 0):VectorToWorldSpace(offset), centre)
		end
	end
	W.button({ parent = box, name = "RotateLeft", text = "Rotate left", position = UDim2.new(0.5, -154, 1, -56), size = UDim2.fromOffset(148, 44), zindex = 62, onClick = function() rotate(-math.pi / 4) end })
	W.button({ parent = box, name = "RotateRight", text = "Rotate right", position = UDim2.new(0.5, 6, 1, -56), size = UDim2.fromOffset(148, 44), zindex = 62, onClick = function() rotate(math.pi / 4) end })
end

-- Rows are pooled per uid (see M.update), so a row belongs to one creature for
-- its whole life and the handlers can capture `uid` once. They read the live
-- entry from the snapshot at click time so a stale row never acts on stale data.
local function createRow(uid: string): any
	-- The text stack (name, pills, income, mastery) ends at y 90 and the button
	-- row starts at y 92, so nothing is hidden behind the buttons.
	local card = W.card(listScroll, ROW_HEIGHT)

	local vp = W.viewport(card, UDim2.new(0, 60, 0, 60), UDim2.new(0, 4, 0, 4), Theme.colors.bgDeep)

	local nameLabel = W.label({
		parent = card,
		size = UDim2.new(1, -240, 0, 22),
		position = UDim2.new(0, 70, 0, 4),
		textSize = 17,
		font = Theme.fonts.title,
	})
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local badgeRow = W.frame({
		parent = card,
		size = UDim2.new(1, -240, 0, Theme.sizes.badgeHeight),
		position = UDim2.new(0, 70, 0, 29),
		transparency = 1,
	})
	W.list(badgeRow, Enum.FillDirection.Horizontal, 4)
	local rarityBadge = W.badge(badgeRow, "", Theme.colors.textDim, 1)
	local variantBadge = W.badge(badgeRow, "", Theme.colors.textDim, 2)
	-- badges read as mystery labels without this (playtest: what is Prismatic and Overcharged?)
	variantBadge:SetAttribute("Variant", "Normal")
	W.tooltip(variantBadge :: GuiObject, function()
		return Config.Variants.describe(variantBadge:GetAttribute("Variant") or "Normal")
	end)

	local cpsLabel = W.label({
		parent = card,
		size = UDim2.new(1, -240, 0, 18),
		position = UDim2.new(0, 70, 0, 55),
		textSize = 15,
		font = Theme.fonts.title,
		color = Theme.colors.coin,
	})

	local masteryLabel = W.label({
		parent = card,
		size = UDim2.new(1, -240, 0, 16),
		position = UDim2.new(0, 70, 0, 74),
		textSize = 13,
		font = Theme.fonts.title,
		color = Theme.colors.textDim,
	})

	local statusLabel = W.label({
		parent = card,
		size = UDim2.new(0, 150, 0, 22),
		position = UDim2.new(1, -158, 0, 4),
		textSize = 15,
		font = Theme.fonts.title,
		xalign = Enum.TextXAlignment.Right,
	})

	-- Button borders draw 4 px outside each button, so 12 px of padding leaves
	-- a clear gutter between them; the row starts 6 px in for the same reason.
	local buttonRow = W.frame({
		parent = card,
		size = UDim2.new(1, -12, 0, 40),
		position = UDim2.new(0, 6, 1, -44),
		transparency = 1,
	})
	W.list(buttonRow, Enum.FillDirection.Horizontal, 12)

	local favButton = W.button({
		parent = buttonRow,
		text = STAR_OFF,
		size = UDim2.new(0, 40, 0, 40),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.textDim,
		textSize = 24,
		order = 1,
	})
	W.tooltip(favButton :: GuiObject, "Favourite: a favourite can't be sold until you un-star it.")
	local primaryButton = W.button({
		parent = buttonRow,
		text = "Deploy",
		size = UDim2.new(0, 90, 0, 40),
		color = Theme.colors.accentAlt,
		textSize = 14,
		order = 2,
	})
	local moveButton = W.button({
		parent = buttonRow,
		text = "Move",
		size = UDim2.new(0, 80, 0, 40),
		color = Theme.colors.accentAlt,
		textSize = 14,
		order = 3,
	})
	local sellButton = W.button({
		parent = buttonRow,
		text = "Sell",
		size = UDim2.new(0, 80, 0, 40),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 14,
		order = 4,
	})
	local prismaticButton = W.button({
		parent = buttonRow,
		text = "Prismatic",
		size = UDim2.new(0, 110, 0, 40),
		color = Theme.colors.gold,
		textSize = 13,
		order = 5,
	})

	local function currentEntry(): CreatureEntry?
		local snap = State.get()
		return if snap then snap.creatures[uid] else nil
	end

	W.button({
		parent = buttonRow,
		name = "ViewCreature",
		text = "View",
		size = UDim2.fromOffset(72, 40),
		color = Theme.colors.accent,
		textSize = 14,
		order = 0,
		onClick = function()
			local entry = currentEntry()
			if entry then
				openCreatureView(entry)
			end
		end,
	})

	favButton.Activated:Connect(function()
		local entry = currentEntry()
		if entry then
			Net.fire("SetFavorite", uid, not entry.favorite)
		end
	end)

	primaryButton.Activated:Connect(function()
		local entry = currentEntry()
		if not entry then
			return
		end
		if entry.pad then
			Net.fire("StoreCreature", uid)
		else
			openPadPicker("Deploy", uid, nil)
		end
	end)

	moveButton.Activated:Connect(function()
		local entry = currentEntry()
		if entry and entry.pad then
			openPadPicker("Move", uid, entry.pad)
		end
	end)

	sellButton.Activated:Connect(function()
		local entry = currentEntry()
		if not entry or entry.favorite or entry.anchored then
			return
		end
		local def = Config.Species.byId[entry.id]
		W.confirm(
			gui,
			"Sell " .. (if def then def.name else "creature") .. "?",
			"You get about " .. Format.abbreviate(sellEstimate(entry)) .. " Coins. This creature is gone for good, but it stays in your Atlas.",
			"Sell it",
			function()
				Net.fire("SellCreature", uid)
			end,
			true
		)
	end)

	prismaticButton.Activated:Connect(function()
		local snap = State.get()
		local entry = currentEntry()
		if not snap or not entry then
			return
		end
		local ready = prismaticEligible(snap, entry)
		if not ready then
			return
		end
		local def = Config.Species.byId[entry.id]
		local warning = if entry.favorite then "\n\nThis one is a favorite. It will be transformed, not replaced." else ""
		W.confirm(
			gui,
			"Make this " .. (if def then def.name else "creature") .. " Prismatic?",
			"It becomes Prismatic (x"
				.. tostring(Config.Variants.mult("Prismatic"))
				.. " income). This transforms the creature you picked, it does not make a copy. Your progress towards the next one starts again from zero."
				.. warning,
			"Transform",
			function()
				Net.fire("PrismaticUpgrade", uid)
			end,
			false
		)
	end)

	return {
		frame = card,
		vp = vp,
		modelKey = "",
		uid = uid,
		nameLabel = nameLabel,
		rarityBadge = rarityBadge,
		variantBadge = variantBadge,
		cpsLabel = cpsLabel,
		masteryLabel = masteryLabel,
		statusLabel = statusLabel,
		favButton = favButton,
		primaryButton = primaryButton,
		moveButton = moveButton,
		sellButton = sellButton,
		prismaticButton = prismaticButton,
	}
end

type Sortable = { uid: string, entry: CreatureEntry }

local function buildOrder(snap: Snapshot): { Sortable }
	local list: { Sortable } = {}
	for uid, entry in snap.creatures do
		if activeTab == "Deployed" and not entry.pad then
			continue
		end
		if activeTab == "Stored" and entry.pad then
			continue
		end
		table.insert(list, { uid = uid, entry = entry })
	end

	table.sort(list, function(a, b)
		if sortMode == "Rarity" then
			local defA, defB = Config.Species.byId[a.entry.id], Config.Species.byId[b.entry.id]
			local ra = if defA then Config.Rarities.rank(defA.rarity) else 0
			local rb = if defB then Config.Rarities.rank(defB.rarity) else 0
			if ra ~= rb then
				return ra > rb
			end
		elseif sortMode == "Region" then
			local defA, defB = Config.Species.byId[a.entry.id], Config.Species.byId[b.entry.id]
			local ra = if defA then Config.Regions.byId[defA.region].index else 0
			local rb = if defB then Config.Regions.byId[defB.region].index else 0
			if ra ~= rb then
				return ra < rb
			end
		elseif sortMode == "Newest" then
			if a.entry.caughtAt ~= b.entry.caughtAt then
				return a.entry.caughtAt > b.entry.caughtAt
			end
		elseif sortMode == "Favorites" then
			if a.entry.favorite ~= b.entry.favorite then
				return a.entry.favorite
			end
		else -- "Income"
			if a.entry.cps ~= b.entry.cps then
				return a.entry.cps > b.entry.cps
			end
		end
		return a.uid < b.uid
	end)
	return list
end

local function updateRow(row: any, uid: string, entry: CreatureEntry, snap: Snapshot)
	row.uid = uid
	local def = Config.Species.byId[entry.id]
	if not def then
		return
	end

	local wantModel = entry.id .. "|" .. entry.variant
	if row.modelKey ~= wantModel then
		row.modelKey = wantModel
		queueBuild(function()
			if row.frame.Parent == nil then
				return
			end
			row.vp.setModel(CreatureModels.build(entry.id, entry.variant, false))
		end)
	end

	row.nameLabel.Text = def.name
	-- plain name: the pill's font can't draw every rarity glyph, and a pill
	-- with a glyph next to one without reads as a mistake
	local rarityInfo = Config.Rarities.info[def.rarity]
	row.rarityBadge.Text = if rarityInfo then rarityInfo.label else def.rarity
	row.rarityBadge.BackgroundColor3 = Config.Rarities.color(def.rarity)

	local variantInfo = Config.Variants.info[entry.variant]
	local showVariant = entry.variant ~= "Normal" and variantInfo ~= nil
	row.variantBadge.Visible = showVariant
	if showVariant and variantInfo then
		row.variantBadge.Text = variantInfo.label
		row.variantBadge.BackgroundColor3 = variantInfo.color
		row.variantBadge:SetAttribute("Variant", entry.variant)
	end

	-- a stored creature earns nothing now; show what it would earn so a fresh
	-- catch from a rich region does not read as worthless
	row.cpsLabel.Text = if entry.pad then Format.cps(entry.cps) else Format.cps(entry.potentialCps or entry.normalCps) .. " when deployed"
	if entry.circuitId then
		local circuit = Config.Circuits.byId[entry.circuitId]
		row.cpsLabel.Text ..= "  (" .. (if circuit then circuit.name else entry.circuitId) .. ")"
	end

	row.statusLabel.Text = if entry.pad then "Pad " .. tostring(entry.pad) else "Stored"

	local ready, masteryText = prismaticEligible(snap, entry)
	local hasMastery = snap.mastery[entry.id] ~= nil
	row.masteryLabel.Visible = hasMastery and entry.variant ~= "Prismatic"
	row.masteryLabel.Text = masteryText

	-- off: a hollow pale star on the dark button; on: a filled white star on gold
	local favFill = if entry.favorite then Theme.colors.gold else Theme.colors.bgAlt
	local favStar = if entry.favorite then Theme.colors.text else Theme.colors.textDim
	W.setButtonColor(row.favButton, favFill, favStar)
	row.favButton.Text = if entry.favorite then STAR_ON else STAR_OFF

	if entry.pad then
		row.primaryButton.Text = "Store"
		W.setButtonColor(row.primaryButton, Theme.colors.accentAlt, Theme.colors.ink)
		row.moveButton.Visible = true
	else
		row.primaryButton.Text = "Deploy"
		W.setButtonColor(row.primaryButton, Theme.colors.success, Theme.colors.ink)
		row.moveButton.Visible = false
	end

	local sellDisabled = entry.favorite or entry.anchored
	W.setEnabled(row.sellButton, not sellDisabled)
	row.sellButton.Text = if sellDisabled then "Sell" else ("Sell ~" .. Format.abbreviate(sellEstimate(entry)))

	row.prismaticButton.Visible = hasMastery
	W.setEnabled(row.prismaticButton, ready)
	row.prismaticButton.Text = if ready then "Prismatic!" else "Prismatic"
end

-- ------------------------------------------------------------ public

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	headerLabel.Text = "Storage " .. tostring(snap.storage.used) .. " / " .. tostring(snap.storage.max)
		.. "  ·  Pads " .. tostring(snap.pads.used) .. " / " .. tostring(snap.pads.total)
	warningLabel.Visible = snap.storage.used >= snap.storage.max
	if not panel.frame.Visible then
		return
	end

	local order = buildOrder(snap)
	local live: { [string]: boolean } = {}

	for i, item in order do
		local row = rows[item.uid]
		if not row then
			row = createRow(item.uid)
			rows[item.uid] = row
		end
		live[item.uid] = true
		row.frame.LayoutOrder = i
		updateRow(row, item.uid, item.entry, snap)
	end

	local dead: { string } = {}
	for uid in rows do
		if not live[uid] then
			table.insert(dead, uid)
		end
	end
	for _, uid in dead do
		rows[uid].frame:Destroy()
		rows[uid] = nil
	end

	emptyLabel.Visible = #order == 0
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
	panel = W.panel(gui, "Creatures", "Creatures", UDim2.new(0, 640, 0, 440))
	panel.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.frame.Visible then
			closeCreatureView()
		end
	end)
	local body = panel.body

	headerLabel = W.label({
		parent = body,
		text = "Storage 0 / 0  ·  Pads 0 / 0",
		size = UDim2.new(1, 0, 0, 20),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
	})
	warningLabel = W.label({
		parent = body,
		text = "Storage full! Sell or relaunch to make room.",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 0, 20),
		textSize = 13,
		color = Theme.colors.danger,
		visible = false,
	})

	local tabBar = W.frame({ parent = body, size = UDim2.new(1, 0, 0, 34), position = UDim2.new(0, 0, 0, 40), transparency = 1 })
	W.tabs(tabBar, { "Deployed", "Stored", "All" }, function(name)
		activeTab = name
		refresh()
	end, 34)

	local sortBar = W.frame({ parent = body, size = UDim2.new(1, 0, 0, 30), position = UDim2.new(0, 0, 0, 78), transparency = 1 })
	W.label({ parent = sortBar, text = "Sort:", size = UDim2.new(0, 44, 1, 0), textSize = 13, color = Theme.colors.textDim })
	local sortHolder = W.frame({ parent = sortBar, size = UDim2.new(1, -48, 1, 0), position = UDim2.new(0, 48, 0, 0), transparency = 1 })
	W.tabs(sortHolder, SORT_MODES, function(name)
		sortMode = name
		refresh()
	end, 28)

	listScroll = W.scroll(body, UDim2.new(1, 0, 1, -114), UDim2.new(0, 0, 0, 114), 6)

	emptyLabel = W.label({
		parent = body,
		text = "No creatures here yet. Go catch some disasters!",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.new(0, 0, 0, 150),
		textSize = 15,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Center,
		visible = false,
	})

	built = true
	panel.refresh = refresh
	refresh()
end

return M
