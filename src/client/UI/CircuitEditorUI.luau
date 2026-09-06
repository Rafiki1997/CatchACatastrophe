--!strict
-- The panel that appears when you click a work pad in your own city: what the
-- pair would make, what it would earn, and the buttons to build, upgrade or
-- overdrive it.
--
-- The income preview is an estimate drawn from the snapshot. The server
-- recomputes everything when it acts on the request, so a stale preview can
-- mislead the eye for a moment but can never mislead the wallet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)

local CircuitEditorUI = {}

export type Preview = {
	padA: number,
	padB: number,
	recipeId: string?,
	reason: string?,
	beforeCps: number,
	afterCps: number,
	bonus: number,
}

local card: Frame? = nil
local headline: TextLabel? = nil
local detail: TextLabel? = nil
local incomeLine: TextLabel? = nil
local connectButton: TextButton? = nil
local disconnectButton: TextButton? = nil
local upgradeButton: TextButton? = nil
local overdriveButton: TextButton? = nil
local overdriveHelp: TextLabel? = nil
local closeButton: TextButton? = nil

local selection: { padA: number?, padB: number? } = { padA = nil, padB = nil }
local activeEntry: Types.CircuitEntry? = nil

local OD = Config.Circuits.overdrive

local function hideAllButtons()
	for _, b in { connectButton, disconnectButton, upgradeButton, overdriveButton } do
		if b then
			b.Visible = false
		end
	end
	if overdriveHelp then
		overdriveHelp.Visible = false
	end
end

function CircuitEditorUI.init()
	local gui = W.screenGui("CatchCircuitEditor", 6)
	W.attachScale(gui)

	card = W.frame({
		parent = gui,
		name = "CircuitCard",
		size = UDim2.new(0, 340, 0, 230),
		position = UDim2.new(1, -14, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.circuit,
		strokeThickness = 3,
		visible = false,
		zindex = 6,
	})

	headline = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -46, 0, 28),
		position = UDim2.new(0, 12, 0, 8),
		textSize = 20,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
		zindex = 7,
	})
	closeButton = W.button({
		parent = card,
		text = "X",
		size = UDim2.new(0, 28, 0, 28),
		position = UDim2.new(1, -10, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.textDim,
		textSize = 15,
		zindex = 7,
		onClick = function()
			CircuitEditorUI.hide()
		end,
	})
	detail = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 52),
		position = UDim2.new(0, 12, 0, 38),
		textSize = 14,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
		zindex = 7,
	})
	incomeLine = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 24),
		position = UDim2.new(0, 12, 0, 92),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.coin,
		xalign = Enum.TextXAlignment.Left,
		zindex = 7,
	})

	local row = W.frame({
		parent = card,
		size = UDim2.new(1, -24, 0, 38),
		position = UDim2.new(0, 12, 0, 120),
		transparency = 1,
		zindex = 7,
	})
	W.list(row, Enum.FillDirection.Horizontal, 6)

	connectButton = W.button({
		parent = row,
		text = "Connect",
		size = UDim2.new(0, 150, 1, 0),
		color = Theme.colors.circuit,
		textColor = Theme.colors.ink,
		textSize = 16,
		order = 1,
		zindex = 8,
		onClick = function()
			if selection.padA and selection.padB then
				Net.fire("ConnectCircuit", selection.padA, selection.padB)
			end
		end,
	})
	disconnectButton = W.button({
		parent = row,
		text = "Disconnect",
		size = UDim2.new(0, 150, 1, 0),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 16,
		order = 2,
		zindex = 8,
		onClick = function()
			local entry = activeEntry
			if entry then
				Net.fire("DisconnectCircuit", entry.padA)
			end
		end,
	})
	upgradeButton = W.button({
		parent = row,
		text = "Upgrade",
		size = UDim2.new(0, 150, 1, 0),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 16,
		order = 3,
		zindex = 8,
		onClick = function()
			local entry = activeEntry
			if entry then
				Net.fire("UpgradeCircuit", entry.padA, entry.padB)
			end
		end,
	})

	overdriveButton = W.button({
		parent = card,
		text = "Overdrive",
		size = UDim2.new(1, -24, 0, 34),
		position = UDim2.new(0, 12, 0, 164),
		color = Theme.colors.overdrive,
		textColor = Theme.colors.ink,
		textSize = 16,
		zindex = 8,
		onClick = function()
			local entry = activeEntry
			if entry then
				Net.fire("StartOverdrive", entry.padA, entry.padB)
			end
		end,
	})
	overdriveHelp = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 26),
		position = UDim2.new(0, 12, 1, -8),
		anchor = Vector2.new(0, 1),
		textSize = 12,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		wrap = true,
		zindex = 7,
	})

	hideAllButtons()
end

function CircuitEditorUI.hide()
	if card then
		card.Visible = false
	end
	selection = { padA = nil, padB = nil }
	activeEntry = nil
end

function CircuitEditorUI.isOpen(): boolean
	return card ~= nil and card.Visible
end

-- One pad picked, or two picked with a preview of what they would make.
function CircuitEditorUI.showSelection(padA: number?, padB: number?, preview: Preview?)
	if not card then
		return
	end
	selection = { padA = padA, padB = padB }
	activeEntry = nil
	card.Visible = true
	hideAllButtons()

	if not padA then
		card.Visible = false
		return
	end

	if not padB or not preview then
		if headline then
			headline.Text = "Pad " .. tostring(padA)
			headline.TextColor3 = Theme.colors.text
		end
		if detail then
			detail.Text = "Now pick a pad directly next to it, up, down, left or right. Diagonal pads do not connect."
		end
		if incomeLine then
			incomeLine.Text = ""
		end
		return
	end

	if headline then
		headline.Text = "Pads " .. tostring(padA) .. " + " .. tostring(padB)
		headline.TextColor3 = Theme.colors.text
	end

	if not preview.recipeId then
		if detail then
			detail.Text = preview.reason or "Those two elements do not make a circuit. Check the Recipe Book for the six pairings."
			detail.TextColor3 = Theme.colors.danger
		end
		if incomeLine then
			incomeLine.Text = ""
		end
		return
	end

	local recipe = Config.Circuits.byId[preview.recipeId]
	if headline and recipe then
		headline.Text = recipe.name
		headline.TextColor3 = recipe.color
	end
	if detail and recipe then
		detail.Text = recipe.desc
		detail.TextColor3 = Theme.colors.textDim
	end
	if incomeLine then
		incomeLine.Text = "+"
			.. Format.percent(preview.bonus)
			.. " each: "
			.. Format.abbreviate(preview.beforeCps)
			.. "/s -> "
			.. Format.abbreviate(preview.afterCps)
			.. "/s"
	end
	if connectButton then
		connectButton.Visible = true
	end
end

-- An existing circuit: its controls and its Overdrive state.
function CircuitEditorUI.showCircuitCard(entry: Types.CircuitEntry)
	if not card then
		return
	end
	activeEntry = entry
	selection = { padA = entry.padA, padB = entry.padB }
	card.Visible = true
	hideAllButtons()

	local recipe = Config.Circuits.byId[entry.circuitId]
	if headline then
		headline.Text = if recipe then recipe.name else entry.circuitId
		headline.TextColor3 = if recipe then recipe.color else Theme.colors.text
	end
	if detail then
		detail.Text = (if recipe then recipe.desc else "")
			.. "\nPads "
			.. tostring(entry.padA)
			.. " and "
			.. tostring(entry.padB)
			.. (if entry.upgraded then "  (upgraded)" else "")
		detail.TextColor3 = Theme.colors.textDim
	end
	if incomeLine then
		incomeLine.Text = "Each creature earns +" .. Format.percent(entry.bonus)
	end

	if disconnectButton then
		disconnectButton.Visible = true
	end
	if upgradeButton then
		upgradeButton.Visible = not entry.upgraded
		if not entry.upgraded then
			local snap = State.get()
			local affordable = snap ~= nil and snap.coins >= entry.upgradeCost
			upgradeButton.Text = "Upgrade  " .. Format.abbreviate(entry.upgradeCost)
			W.setEnabled(upgradeButton, affordable)
		end
	end

	if overdriveButton and overdriveHelp then
		overdriveButton.Visible = true
		overdriveHelp.Visible = true
		local phase = entry.overdrive.phase
		local left = math.max(0, entry.overdrive.until_ - State.now())
		if phase == "active" then
			overdriveButton.Text = "OVERDRIVE  " .. ("%.0f"):format(left) .. "s"
			W.setEnabled(overdriveButton, false)
			overdriveHelp.Text = if entry.overdrive.vented
				then "Vented. No cooldown when this ends."
				else "Hold the vent at your control booth before it ends to skip the " .. tostring(OD.cooldownSeconds) .. "s of zero output."
			overdriveHelp.TextColor3 = Theme.colors.warn
		elseif phase == "cooldown" then
			overdriveButton.Text = "Cooling  " .. ("%.0f"):format(left) .. "s"
			W.setEnabled(overdriveButton, false)
			overdriveHelp.Text = "This pair earns nothing until it finishes cooling. Your other creatures keep working."
			overdriveHelp.TextColor3 = Theme.colors.danger
		else
			overdriveButton.Text = "Overdrive"
			W.setEnabled(overdriveButton, true)
			overdriveHelp.Text = "x"
				.. tostring(OD.multiplier)
				.. " output for "
				.. tostring(OD.activeSeconds)
				.. "s, then "
				.. tostring(OD.cooldownSeconds)
				.. "s of nothing from this pair, unless you vent at your booth. Stay nearby for the best return."
			overdriveHelp.TextColor3 = Theme.colors.textDim
		end
	end
end

-- Refresh the live numbers on an open card.
function CircuitEditorUI.update(snap: Types.Snapshot)
	if not card or not card.Visible or not activeEntry then
		return
	end
	local key = Config.Circuits.pairKey(activeEntry.padA, activeEntry.padB)
	local entry = snap.circuits[key]
	if entry then
		CircuitEditorUI.showCircuitCard(entry)
	else
		CircuitEditorUI.hide()
	end
end

return CircuitEditorUI
