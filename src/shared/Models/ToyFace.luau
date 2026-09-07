--!strict
-- The approved Gusty Gardens face language, shared by creature builders only.
local Kit = require(script.Parent.ModelKit)
local ToyFace = {}
ToyFace.ink = Color3.fromRGB(39, 47, 58)

function ToyFace.eyes(model: Model, centre: CFrame, spacing: number, radius: number)
	for _, side in { -1, 1 } do
		local at = centre * CFrame.new(side * spacing / 2, 0, 0)
		Kit.eye(model, at, radius, ToyFace.ink)
		Kit.part(model, { name = "EyeGlint", shape = "Ball", size = Vector3.one * radius * 0.32,
			cf = at * CFrame.new(-radius * 0.15, radius * 0.21, -radius * 1.04), color = Color3.new(1, 1, 1), role = "fixed", castShadow = false })
	end
end

function ToyFace.smile(model: Model, at: CFrame, width: number)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Smile", size = Vector3.new(width * 0.55, width * 0.14, 0.07),
			cf = at * CFrame.new(side * width * 0.23, width * 0.05, 0) * CFrame.Angles(0, 0, side * math.rad(18)), color = ToyFace.ink, role = "fixed" })
	end
end

function ToyFace.cheeks(model: Model, at: CFrame, spacing: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		local cheek = Kit.blob(model, Vector3.new(size, size * 0.5, 0.08), at * CFrame.new(side * spacing / 2, 0, 0), color, "fixed")
		cheek.Name = "Cheek"
	end
end

return ToyFace
