--!strict
-- Three mutually exclusive appearances per species.
--   Normal      1x
--   Overcharged 1.5x  perfect capture during the region's forecasted surge
--   Prismatic   2x    species-bound upgrade after 30 cumulative online minutes
--                     in an active circuit + 3 perfect captures of the species

export type VariantInfo = {
	mult: number,
	label: string,
	icon: string,
	color: Color3,
	material: Enum.Material?,
	tint: Color3?, -- blended into tintable parts
	tintAmount: number,
	particles: string?, -- ModelKit particle preset
	rainbow: boolean,
	glow: boolean,
}

local Variants = {}

Variants.order = { "Normal", "Overcharged", "Prismatic" }

Variants.info = {
	Normal = { mult = 1, label = "Normal", icon = "", color = Color3.fromRGB(200, 200, 200), tintAmount = 0, rainbow = false, glow = false },
	Overcharged = { mult = 1.5, label = "Overcharged", icon = "⚡", color = Color3.fromRGB(120, 230, 255), material = Enum.Material.Neon, tint = Color3.fromRGB(120, 230, 255), tintAmount = 0.35, particles = "lightning", rainbow = false, glow = true },
	Prismatic = { mult = 2, label = "Prismatic", icon = "◈", color = Color3.fromRGB(255, 150, 255), material = Enum.Material.Glass, tint = Color3.fromRGB(255, 200, 255), tintAmount = 0.25, particles = "sparkle", rainbow = true, glow = true },
} :: { [string]: VariantInfo }

-- Prismatic mastery requirements (per species, per claim). Both counters
-- reset to zero when a Prismatic upgrade is claimed for that species.
Variants.prismatic = {
	circuitMinutes = 30, -- cumulative ONLINE minutes producing inside an active circuit
	perfectCaptures = 3,
}

function Variants.mult(variant: string): number
	local v = Variants.info[variant]
	return if v then v.mult else 1
end

function Variants.isValid(variant: string): boolean
	return Variants.info[variant] ~= nil
end

return Variants
