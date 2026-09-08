--!strict
-- The eggs, as models rather than an emoji.
--
-- A Cosmic Egg is what a player is deciding whether to spend on, so it gets a
-- real object: a deep space-violet shell speckled with stars, a brighter band
-- around its middle, a faint glow and slow sparkles. The colour is the whole
-- identity, so it is one field per egg and every other egg added later reuses
-- this builder with different colours.

local Kit = require(script.Parent.ModelKit)

export type EggStyle = {
	shell: Color3,
	speckle: Color3,
	band: Color3,
	glow: Color3,
	preset: string, -- particle preset for the drifting motes
}

local EggModels = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

EggModels.styles = {
	cosmic_egg = {
		shell = rgb(58, 40, 110), -- deep violet, not the pale shell an ordinary egg has
		speckle = rgb(255, 245, 200),
		band = rgb(150, 90, 240),
		glow = rgb(190, 130, 255),
		preset = "motes",
	},
} :: { [string]: EggStyle }

EggModels.defaultStyle = {
	shell = rgb(230, 224, 236),
	speckle = rgb(255, 255, 255),
	band = rgb(200, 190, 215),
	glow = rgb(255, 250, 235),
	preset = "sparkle",
} :: EggStyle

function EggModels.styleFor(eggId: string): EggStyle
	return EggModels.styles[eggId] or EggModels.defaultStyle
end

-- An egg is a squashed sphere: wider at the bottom than the top, which is the
-- whole trick to reading as an egg rather than a ball.
function EggModels.build(eggId: string, scale: number?): Model
	local style = EggModels.styleFor(eggId)
	local model, root = Kit.newModel("Egg_" .. eggId)
	model:SetAttribute("EggId", eggId)

	local shell = Kit.blob(model, Vector3.new(2.0, 2.7, 2.0), CFrame.new(0, 1.5, 0), style.shell, nil, Enum.Material.SmoothPlastic)
	shell.Name = "Shell"
	-- the taper: a smaller sphere set high, same colour, reads as the narrow end
	local crown = Kit.blob(model, Vector3.new(1.45, 1.5, 1.45), CFrame.new(0, 2.35, 0), style.shell, nil, Enum.Material.SmoothPlastic)
	crown.Name = "Crown"

	-- a band around the middle, the way a decorated egg is painted
	local band = Kit.part(model, {
		name = "Band",
		size = Vector3.new(2.06, 0.34, 2.06),
		cf = CFrame.new(0, 1.35, 0),
		color = style.band,
		material = Enum.Material.Neon,
		mesh = "Sphere",
		meshScale = Vector3.new(1, 0.16, 1),
	})

	-- stars across the shell, placed around it rather than randomly scattered so
	-- every egg looks deliberate
	for i = 1, 9 do
		local angle = (i / 9) * math.pi * 2
		local height = 0.9 + (i % 3) * 0.55
		local radius = 0.86 - math.abs(height - 1.6) * 0.16
		Kit.part(model, {
			name = "Speckle",
			size = Vector3.new(0.2, 0.2, 0.2),
			cf = CFrame.new(math.cos(angle) * radius, height + 0.35, math.sin(angle) * radius),
			color = style.speckle,
			material = Enum.Material.Neon,
			mesh = "Sphere",
		})
	end

	Kit.light(shell, style.glow, 1.2, 10)
	Kit.particles(shell, style.preset, style.glow)
	Kit.setAnim(model, "bob", 0.7)

	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	Kit.finalize(model)
	local _ = root
	return model
end

return EggModels
