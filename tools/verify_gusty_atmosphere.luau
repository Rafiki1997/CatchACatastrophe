-- Execute on the Studio client. Simulates observers without moving the player.
local Players = game:GetService("Players")
local region = workspace.Regions.gusty_gardens
local centre = region:GetAttribute("Centre")
local module = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.GustyAtmosphere)
local camera = workspace.CurrentCamera
local initialCamera = camera.CFrame
local existingGrades = {}
for _, child in game.Lighting:GetChildren() do existingGrades[child] = true end
local fx = module.create(region)
local grade = nil
for _, child in game.Lighting:GetChildren() do
	if child.Name == "GustyMeadowGrade" and not existingGrades[child] then grade = child end
end
local function run()
	local settings = { reducedMotion = false, reducedFlashing = false }
	local count, beams = 0, 0
	for _, p in fx.root:GetDescendants() do
		if p:IsA("BasePart") then
			assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
			count += 1
		elseif p:IsA("Beam") then beams += 1 end
	end
	assert(count == 21 and beams == 3, "bounded effect population")
	local minRadius, maxRadius = math.huge, 0
	local previous = nil
	local moved = false
	for _ = 1, 180 do
		fx.step(0.5, centre, settings, false)
		assert(fx.root:GetAttribute("Active"))
		for _, p in fx.root:GetChildren() do
			if p.Name ~= "DriftingLeaf" then continue end
			local delta = p.Position - centre
			local radius = Vector3.new(delta.X, 0, delta.Z).Magnitude
			minRadius, maxRadius = math.min(minRadius, radius), math.max(maxRadius, radius)
			assert(radius > 48 and radius < 70, "leaf drift entered field or crossed boundary")
			for _, value in { p.CFrame:GetComponents() } do assert(value == value and math.abs(value) < math.huge) end
		end
		local current = fx.root:FindFirstChild("DriftingLeaf").Position
		if previous and (current - previous).Magnitude > 0.001 then moved = true end
		previous = current
	end
	assert(moved, "leaf animation did not move")
	assert(grade and grade.Enabled and grade.Saturation > 0.03, "local warmth did not fade in")
	fx.step(0.1, centre, settings, true)
	assert(math.abs(fx.root:GetAttribute("Visibility") - 0.2) < 0.001)
	for _, p in fx.root:GetDescendants() do if p:IsA("Beam") then assert(not p.Enabled, "capture ribbons visible") end end
	settings.reducedFlashing = true
	fx.step(0.1, centre, settings, false)
	for _, p in fx.root:GetDescendants() do if p:IsA("Beam") then assert(not p.Enabled, "reduced-flashing ribbons visible") end end
	settings.reducedMotion = true
	fx.step(0.1, centre, settings, false)
	assert(not fx.root:GetAttribute("Active"))
	for _, p in fx.root:GetChildren() do if p:IsA("BasePart") then assert(p.Transparency == 1) end end
	settings.reducedMotion, settings.reducedFlashing = false, false
	fx.step(0.1, centre + Vector3.new(200, 0, 0), settings, false)
	assert(not fx.root:GetAttribute("Active"), "distant effects did not cull")
	fx.step(0.1, nil, settings, false)
	assert(not fx.root:GetAttribute("Active"), "respawn must hide effects")
	for _ = 1, 100 do fx.step(0.1, nil, settings, false) end
	assert(not grade.Enabled and grade.TintColor == Color3.new(1, 1, 1), "warmth remained after leaving")
	fx.destroy()
	fx.destroy()
	assert(fx.root.Parent == nil, "effect cleanup failed")
	assert(grade.Parent == nil, "local grading leaked after cleanup")
	assert(camera.CFrame == initialCamera, "atmosphere changed the player camera")
	return { parts = count, beams = beams, minimumLeafRadius = minRadius, maximumLeafRadius = maxRadius,
		motion = true, captureSuppression = true, reducedSettings = true, distanceCulling = true, warmthFade = true, cleanup = true }
end
local ok, result = pcall(run)
fx.destroy()
assert(ok, result)
return game.HttpService:JSONEncode(result)
