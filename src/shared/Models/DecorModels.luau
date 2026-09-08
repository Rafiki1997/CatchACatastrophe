--!strict
-- City decorations, built the same procedural way as the creatures so a new one
-- costs a function rather than an art pipeline.
--
-- Each builder returns a model whose origin sits on the ground, so the placer
-- can drop it straight onto a plot corner without knowing anything about it.

local Kit = require(script.Parent.ModelKit)

local DecorModels = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(38, 40, 54)

local builders: { [string]: (Model, BasePart, Color3) -> () } = {}

-- A creature on a plinth. The shape is deliberately vague: it reads as "a
-- creature" without claiming to be any particular one.
builders.statue = function(model, _root, color)
	Kit.part(model, { name = "Base", size = Vector3.new(6, 1, 6), cf = CFrame.new(0, 0.5, 0), color = INK, material = Enum.Material.Slate, collide = true })
	Kit.part(model, { name = "Plinth", size = Vector3.new(4.4, 3, 4.4), cf = CFrame.new(0, 2.5, 0), color = color, material = Enum.Material.Concrete, collide = true })
	Kit.blob(model, Vector3.new(3, 2.8, 3), CFrame.new(0, 5.6, 0), color, nil, Enum.Material.Concrete)
	Kit.blob(model, Vector3.new(1.1, 1.6, 1.1), CFrame.new(-0.9, 7.4, 0), color, nil, Enum.Material.Concrete)
	Kit.blob(model, Vector3.new(1.1, 1.6, 1.1), CFrame.new(0.9, 7.4, 0), color, nil, Enum.Material.Concrete)
	Kit.eyes(model, CFrame.new(0, 5.9, -1.3), 1.0, 0.28)
end

builders.fountain = function(model, _root, color)
	Kit.part(model, { name = "Basin", size = Vector3.new(7, 1.2, 7), cf = CFrame.new(0, 0.6, 0), color = rgb(196, 192, 200), material = Enum.Material.Concrete, collide = true, shape = Enum.PartType.Cylinder })
	Kit.part(model, { name = "Water", size = Vector3.new(6.2, 0.3, 6.2), cf = CFrame.new(0, 1.25, 0), color = color, material = Enum.Material.Neon, shape = Enum.PartType.Cylinder })
	Kit.part(model, { name = "Column", size = Vector3.new(1.2, 3.4, 1.2), cf = CFrame.new(0, 2.9, 0), color = rgb(196, 192, 200), material = Enum.Material.Concrete, collide = true })
	local top = Kit.part(model, { name = "Spout", size = Vector3.new(2.6, 0.4, 2.6), cf = CFrame.new(0, 4.7, 0), color = color, material = Enum.Material.Neon, shape = Enum.PartType.Cylinder })
	Kit.particles(top, "rain", color)
	Kit.light(top, color, 0.8, 12)
end

builders.banner = function(model, _root, color)
	Kit.part(model, { name = "Foot", size = Vector3.new(3, 0.8, 3), cf = CFrame.new(0, 0.4, 0), color = INK, collide = true })
	Kit.part(model, { name = "Pole", size = Vector3.new(0.5, 12, 0.5), cf = CFrame.new(0, 6.4, 0), color = rgb(150, 156, 170), material = Enum.Material.Metal, collide = true })
	Kit.part(model, { name = "Cloth", size = Vector3.new(0.2, 6, 4.4), cf = CFrame.new(0.4, 8.4, 0), color = color, material = Enum.Material.SmoothPlastic })
	Kit.part(model, { name = "Trim", size = Vector3.new(0.24, 0.6, 4.4), cf = CFrame.new(0.4, 5.5, 0), color = INK })
	Kit.part(model, { name = "Finial", size = Vector3.new(0.9, 0.9, 0.9), cf = CFrame.new(0, 12.6, 0), color = color, material = Enum.Material.Neon, shape = Enum.PartType.Ball })
end

builders.beacon = function(model, _root, color)
	Kit.part(model, { name = "Base", size = Vector3.new(5, 1, 5), cf = CFrame.new(0, 0.5, 0), color = INK, collide = true })
	Kit.part(model, { name = "Tower", size = Vector3.new(2.4, 7, 2.4), cf = CFrame.new(0, 4.5, 0), color = rgb(96, 132, 168), material = Enum.Material.Metal, collide = true })
	local lamp = Kit.part(model, { name = "Lamp", size = Vector3.new(3.2, 2.2, 3.2), cf = CFrame.new(0, 9.1, 0), color = color, material = Enum.Material.Neon })
	Kit.part(model, { name = "Cap", size = Vector3.new(3.6, 0.5, 3.6), cf = CFrame.new(0, 10.4, 0), color = INK })
	Kit.light(lamp, color, 2, 26)
	Kit.particles(lamp, "glint", color)
	-- the lamp turns; the animator reads this the same way it reads a creature
	Kit.setAnim(model, "spin", 0.5)
end

function DecorModels.has(preset: string): boolean
	return builders[preset] ~= nil
end

function DecorModels.build(preset: string, color: Color3, name: string?): Model?
	local builder = builders[preset]
	if not builder then
		return nil
	end
	local model, root = Kit.newModel(name or ("Decor_" .. preset))
	local ok, err = pcall(builder, model, root, color)
	if not ok then
		warn("[DecorModels] " .. preset .. ": " .. tostring(err))
		model:Destroy()
		return nil
	end
	Kit.finalize(model)
	return model
end

return DecorModels
