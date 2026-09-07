--!strict
-- The moment after a successful capture: a card with the creature turning in a
-- viewport, what it is, and whether the catch was clean.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local CaptureReveal = {}

local gui: ScreenGui? = nil
local card: Frame? = nil
local viewport: any = nil
local nameLabel: TextLabel? = nil
local metaLabel: TextLabel? = nil
local incomeLabel: TextLabel? = nil
local perfectRibbon: TextLabel? = nil
local hideAt = 0

function CaptureReveal.init()
	local g = W.screenGui("CatchReveal", 8)
	W.attachScale(g)
	gui = g

	card = W.frame({
		parent = g,
		name = "RevealCard",
		size = UDim2.new(0, 340, 0, 372),
		position = UDim2.new(0.5, 0, 0.5, -40),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius + 4,
		stroke = Theme.colors.ink,
		strokeThickness = 4,
		visible = false,
		zindex = 20,
	})

	W.label({
		parent = card,
		text = "CAUGHT!",
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.new(0, 0, 0, 12),
		textSize = 28,
		xalign = Enum.TextXAlignment.Center,
		font = Theme.fonts.title,
		color = Theme.colors.accent,
		zindex = 21,
	})

	local frame = W.frame({
		parent = card,
		size = UDim2.new(1, -40, 0, 150),
		position = UDim2.new(0, 20, 0, 52),
		color = Theme.colors.bgDeep,
		radius = Theme.sizes.radiusSmall,
		stroke = Theme.colors.ink,
		strokeThickness = 2,
		zindex = 21,
	})
	viewport = W.viewport(frame)
	viewport.frame.ZIndex = 22

	nameLabel = W.label({
		parent = card,
		text = "",
		-- leaves room for the PERFECT pill at the right end of this row
		size = UDim2.new(1, -124, 0, 30),
		position = UDim2.new(0, 12, 0, 210),
		textSize = 22,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		zindex = 21,
	})
	metaLabel = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 22),
		position = UDim2.new(0, 12, 0, 240),
		textSize = 15,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		zindex = 21,
	})
	W.tooltip(metaLabel :: GuiObject, function()
		local v = metaLabel and metaLabel:GetAttribute("Variant")
		return if typeof(v) == "string" and v ~= "Normal" then Config.Variants.describe(v) else ""
	end)

	incomeLabel = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 24),
		position = UDim2.new(0, 12, 0, 264),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.coin,
		zindex = 21,
	})

	-- A pill in the name row, right of the name. The old 190-wide ribbon was
	-- anchored at y 180 across a picture that ends at y 202, so it sat on the edge.
	perfectRibbon = W.label({
		parent = card,
		text = "PERFECT",
		size = UDim2.new(0, 92, 0, 22),
		position = UDim2.new(1, -12, 0, 214),
		anchor = Vector2.new(1, 0),
		xalign = Enum.TextXAlignment.Center,
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.ink,
		bg = Theme.colors.gold,
		radius = Theme.sizes.radiusSmall,
		zindex = 23,
	})

	-- the creature is already in storage at this point; say so
	local storeButton = W.button({
		parent = card,
		text = "Store",
		size = UDim2.new(0, 140, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(0.5, -74, 1, -16),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 16,
		zindex = 21,
		onClick = function()
			CaptureReveal.hide()
		end,
	})
	W.tooltip(storeButton :: GuiObject, "Keeps it in storage. Deploy it later from Creatures or at a work pad.")
	W.button({
		parent = card,
		text = "Deploy it",
		size = UDim2.new(0, 140, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(0.5, 74, 1, -16),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 16,
		zindex = 21,
		onClick = function()
			CaptureReveal.hide()
			W.openPanel("Creatures")
		end,
	})

	-- auto-close so it never sits over a fight
	task.spawn(function()
		while true do
			task.wait(0.25)
			if card and card.Visible and hideAt > 0 and os.clock() > hideAt then
				CaptureReveal.hide()
			end
		end
	end)
end

function CaptureReveal.hide()
	if card then
		card.Visible = false
	end
	if viewport then
		viewport.setModel(nil)
	end
	hideAt = 0
end

function CaptureReveal.show(result: any)
	if not card or typeof(result) ~= "table" then
		return
	end
	local def = Config.Species.byId[result.speciesId]
	if not def then
		return
	end
	local variant = if Config.Variants.isValid(result.variant) then result.variant else "Normal"
	local variantInfo = Config.Variants.info[variant]

	local ok, model = pcall(CreatureModels.build, def.id, variant)
	if ok and viewport then
		viewport.setModel(model)
	end

	if nameLabel then
		nameLabel.Text = def.name
		nameLabel.TextColor3 = Config.Rarities.color(def.rarity)
	end
	if metaLabel then
		metaLabel:SetAttribute("Variant", variant)
		local variantText = if variant ~= "Normal" then "   " .. variantInfo.icon .. " " .. variantInfo.label else ""
		metaLabel.Text = Config.Rarities.label(def.rarity) .. "   " .. def.element .. variantText
	end
	if incomeLabel then
		local snap = State.get()
		local mult = if snap then snap.relaunchMult else 1
		local income = Config.Species.baseIncome(def.id) * Config.Variants.mult(variant) * mult
		incomeLabel.Text = Format.abbreviate(income) .. "/s when deployed"
	end
	if perfectRibbon then
		perfectRibbon.Visible = result.perfect == true
	end

	card.Visible = true
	local snap = State.get()
	if not snap or not snap.settings.reducedMotion then
		W.pop(card, 1.2)
	end
	hideAt = os.clock() + 6
end

return CaptureReveal
