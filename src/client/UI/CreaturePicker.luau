--!strict
-- The picker behind a work pad's E prompt: your stored creatures, one tap to
-- put one on this pad. An occupied pad also offers "Send to storage".
--
--   CreaturePicker.init()
--   CreaturePicker.open(pad)
--   CreaturePicker.close()
--
-- Everything shown is a display estimate from the snapshot. The server
-- validates every deploy, move and store again (CityService), and a move from
-- storage onto an occupied pad is already a swap there: the occupant takes the
-- mover's old place, which for a stored creature is storage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type Snapshot = Types.Snapshot
type CreatureEntry = Types.CreatureEntry

local CreaturePicker = {}

local gui: ScreenGui = nil :: any
local built = false
local escapeConn: RBXScriptConnection? = nil

local BOX_W = 440
local BOX_H = 430
local ROW_H = 56
local SIDE = 14

local function speciesName(id: string): string
	local def = Config.Species.byId[id]
	return if def then def.name else id
end

-- A stored creature carries no income in the snapshot (it earns nothing), but
-- the whole point of this list is choosing what to deploy, so estimate what it
-- WOULD earn: region base x rarity x variant x relaunch, the same factors
-- Stats applies. Display only; the server pays its own number.
local function incomeEstimate(snap: Snapshot, entry: CreatureEntry): number
	if entry.normalCps > 0 then
		return entry.normalCps
	end
	local def = Config.Species.byId[entry.id]
	if not def then
		return 0
	end
	local region = Config.Regions.byId[def.region]
	local rarity = Config.Rarities.info[def.rarity]
	if not region or not rarity then
		return 0
	end
	return region.baseIncome * rarity.mult * Config.Variants.mult(entry.variant) * snap.relaunchMult
end

function CreaturePicker.init()
	if built then
		return
	end
	built = true
	gui = W.screenGui("CreaturePicker", 60)
	W.attachScale(gui)
end

function CreaturePicker.close()
	if escapeConn then
		escapeConn:Disconnect()
		escapeConn = nil
	end
	if not gui then
		return
	end
	local existing = gui:FindFirstChild("Picker")
	if existing then
		existing:Destroy()
	end
end

-- One stored creature: name, rarity, variant, income, and the button that
-- puts it on the pad. Buttons are 44 tall for touch, like everywhere else.
local function creatureRow(parent: Instance, snap: Snapshot, entry: CreatureEntry, order: number, actionText: string, onPick: () -> ())
	local card = W.card(parent, ROW_H, order)
	local def = Config.Species.byId[entry.id]
	local rarity = if def then def.rarity else "Common"

	W.label({
		parent = card,
		text = speciesName(entry.id),
		size = UDim2.new(1, -150, 0, 22),
		position = UDim2.new(0, 12, 0, 6),
		textSize = Theme.sizes.text,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	local badges = W.frame({
		parent = card,
		size = UDim2.new(1, -150, 0, 20),
		position = UDim2.new(0, 12, 0, 30),
		transparency = 1,
	})
	W.list(badges, Enum.FillDirection.Horizontal, 4)
	W.badge(badges, Config.Rarities.label(rarity), Config.Rarities.color(rarity), 1)
	local variantInfo = Config.Variants.info[entry.variant]
	if entry.variant ~= "Normal" and variantInfo then
		W.badge(badges, variantInfo.icon .. " " .. variantInfo.label, variantInfo.color, 2)
	end
	W.badge(badges, Format.abbreviate(incomeEstimate(snap, entry)) .. "/s", Theme.colors.coin, 3)

	W.button({
		parent = card,
		text = actionText,
		size = UDim2.new(0, 118, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(1, -8, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.success,
		textColor = Theme.colors.ink,
		textSize = Theme.sizes.textSmall,
		onClick = onPick,
	})
	return card
end

function CreaturePicker.open(pad: number)
	if not built then
		CreaturePicker.init()
	end
	CreaturePicker.close()
	local snap = State.get()
	if not snap then
		return
	end

	local occupantUid: string? = nil
	local occupant: CreatureEntry? = nil
	local stored: { { uid: string, entry: CreatureEntry } } = {}
	for uid, entry in snap.creatures do
		if entry.pad == pad then
			occupantUid = uid
			occupant = entry
		elseif entry.pad == nil then
			table.insert(stored, { uid = uid, entry = entry })
		end
	end
	-- best earner first; stored creatures report 0 income so sort on the estimate
	table.sort(stored, function(a, b)
		local ea, eb = incomeEstimate(snap, a.entry), incomeEstimate(snap, b.entry)
		if ea ~= eb then
			return ea > eb
		end
		return a.uid < b.uid
	end)
	local hasOccupant = occupant ~= nil and occupantUid ~= nil

	local overlay = W.frame({
		parent = gui,
		name = "Picker",
		size = UDim2.new(1, 0, 1, 0),
		color = Color3.new(0, 0, 0),
		transparency = 0.45,
		zindex = 60,
	})
	-- tapping the dark area closes, the same as the X
	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.Text = ""
	dismiss.Size = UDim2.new(1, 0, 1, 0)
	dismiss.BackgroundTransparency = 1
	dismiss.BorderSizePixel = 0
	dismiss.AutoButtonColor = false
	dismiss.ZIndex = 60
	dismiss.Activated:Connect(CreaturePicker.close)
	dismiss.Parent = overlay

	local box = W.frame({
		parent = overlay,
		name = "Box",
		size = UDim2.new(0, BOX_W, 0, BOX_H),
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
		text = "Pad " .. tostring(pad),
		size = UDim2.new(1, -80, 0, 32),
		position = UDim2.new(0, SIDE, 0, 10),
		textSize = Theme.sizes.title,
		font = Theme.fonts.title,
		color = Theme.colors.accent,
	})
	W.button({
		parent = box,
		text = "X",
		size = UDim2.new(0, 44, 0, 44),
		position = UDim2.new(1, -8, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.colors.danger,
		onClick = CreaturePicker.close,
	})

	local top = 54
	if hasOccupant and occupant and occupantUid then
		local uidHere: string = occupantUid
		local here = W.card(box, ROW_H, nil, Theme.colors.bgDeep)
		here.Size = UDim2.new(1, -SIDE * 2, 0, ROW_H)
		here.Position = UDim2.new(0, SIDE, 0, top)
		W.label({
			parent = here,
			text = "On this pad",
			size = UDim2.new(1, -170, 0, 16),
			position = UDim2.new(0, 12, 0, 6),
			textSize = 12,
			color = Theme.colors.textDim,
		})
		W.label({
			parent = here,
			text = speciesName(occupant.id) .. "  ·  " .. Format.abbreviate(occupant.normalCps) .. "/s",
			size = UDim2.new(1, -170, 0, 22),
			position = UDim2.new(0, 12, 0, 24),
			textSize = Theme.sizes.text,
			font = Theme.fonts.bold,
			color = Theme.colors.text,
		})
		W.button({
			parent = here,
			text = "Send to storage",
			size = UDim2.new(0, 140, 0, Theme.sizes.buttonHeight),
			position = UDim2.new(1, -8, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = Theme.colors.warn,
			textColor = Theme.colors.ink,
			textSize = Theme.sizes.textSmall,
			onClick = function()
				CreaturePicker.close()
				Net.fire("StoreCreature", uidHere)
			end,
		})
		top += ROW_H + 12
	end

	W.label({
		parent = box,
		text = if hasOccupant then "Swap in from storage" else "Put on this pad from storage",
		size = UDim2.new(1, -SIDE * 2, 0, 20),
		position = UDim2.new(0, SIDE, 0, top),
		textSize = Theme.sizes.textSmall,
		color = Theme.colors.textDim,
	})
	local listTop = top + 26
	local footerH = 38
	local listH = BOX_H - listTop - footerH - 10

	if #stored == 0 then
		W.label({
			parent = box,
			text = "Nothing in storage. Go catch something in the wild.",
			size = UDim2.new(1, -SIDE * 2, 0, listH),
			position = UDim2.new(0, SIDE, 0, listTop),
			textSize = Theme.sizes.text,
			color = Theme.colors.textDim,
			wrap = true,
			xalign = Enum.TextXAlignment.Center,
		})
	else
		local scroll = W.scroll(box, UDim2.new(1, -SIDE * 2, 0, listH), UDim2.new(0, SIDE, 0, listTop), 6)
		for i, item in stored do
			local uid = item.uid
			creatureRow(scroll, snap, item.entry, i, if hasOccupant then "Swap in" else "Put here", function()
				CreaturePicker.close()
				if hasOccupant then
					Net.fire("MoveCreature", uid, pad)
				else
					Net.fire("DeployCreature", uid, pad)
				end
			end)
		end
	end

	local hint = if hasOccupant and occupant
		then speciesName(occupant.id) .. " goes back to storage when you swap."
		else "Click the pad itself to wire a circuit."
	W.label({
		parent = box,
		text = hint,
		size = UDim2.new(1, -SIDE * 2, 0, footerH),
		position = UDim2.new(0, SIDE, 1, -footerH - 6),
		textSize = 13,
		color = Theme.colors.textDim,
		wrap = true,
		xalign = Enum.TextXAlignment.Center,
	})

	-- Escape / B closes, like every panel
	escapeConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			CreaturePicker.close()
		end
	end)

	W.pop(box, 1.06)
end

return CreaturePicker
