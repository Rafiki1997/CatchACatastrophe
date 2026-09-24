-- Run in Studio Edit via execute_luau. Geometry stays outside Workspace.
-- Fixture meshes exercise placement only; they do not represent Frost artwork.
local map = game.ServerScriptService.Server.Map
local sandbox = Instance.new("Folder")
local region = Instance.new("Model")
region.Parent = sandbox
local function run()
	for _, name in { "FrostbitePeaks", "FrostbiteProps", "ImportStaging" } do
		map[name]:Clone().Parent = sandbox
	end
	local props = require(sandbox.FrostbiteProps)
	local frame = CFrame.new(37, 4, -280) * CFrame.Angles(0, 0.7, 0)
	require(sandbox.FrostbitePeaks).build(region, frame, 75, function(spec)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = spec.name, spec.size, spec.cf, spec.color
		p.Material = spec.material
		p.Anchored, p.CanCollide, p.CanQuery = true, spec.collide, spec.query
		p.Parent = spec.parent
		return p
	end)
	local sites = region.Landmarks.PropSites
	assert(#sites:GetChildren() == 56, "expected measured 56-site layout")
	assert(not region:FindFirstChild("BlenderProps"), "missing library must retain blockout")
	local countBefore = #sites:GetDescendants()
	local protected = {}
	for _, host in { region.Boundary, region.Walkways } do
		for _, part in host:GetDescendants() do
			if part:IsA("BasePart") then
				protected[part] = { part.Size, part.CFrame, part.CanCollide, part.Transparency }
			end
		end
	end
	local library = Instance.new("Model")
	library.Name = "FrostbitePropTemplates"
	library.Parent = sandbox
	local source = map.GustyPropTemplates:FindFirstChildWhichIsA("MeshPart", true)
	assert(source and source.MeshSize.Magnitude > 0, "native test mesh unavailable")
	for _, site in sites:GetChildren() do
		local name = site:GetAttribute("AssetName")
		if name ~= "FP_Rope_Coil" and not library:FindFirstChild(name) then
			local mesh = source:Clone()
			mesh.Name = name
			mesh.Parent = library
		end
	end
	assert(not props.apply(region, frame), "incomplete kit must be rejected")
	assert(#sites:GetDescendants() == countBefore, "partial kit removed placeholders")
	local coil = source:Clone()
	coil.Name, coil.Parent = "FP_Rope_Coil", library
	assert(props.apply(region, frame), "complete kit must apply")
	assert(#region.BlenderProps:GetChildren() == 56, "wrong placement count")
	local hanging, grounded = 0, 0
	for _, site in sites:GetChildren() do
		local mesh = region.BlenderProps:FindFirstChild(site.Name)
		local size = site:GetAttribute("AssetSize")
		local isHanging = site:GetAttribute("CollisionRole") == "hanging"
		local mount = mesh.CFrame * CFrame.new(0, (if isHanging then 1 else -1) * size.Y / 2, 0)
		local anchor = frame * site:GetAttribute("GroundCF")
		assert((mount.Position - anchor.Position).Magnitude < 0.001, "incorrect ground/top anchor")
		assert(mesh.CFrame.LookVector:Dot(anchor.LookVector) > 0.9999, "incorrect yaw")
		assert((mesh.Size - size).Magnitude < 0.0001, "import size not normalized")
		assert(mesh.Anchored and not mesh.CanCollide and not mesh.CanQuery and not mesh.CanTouch)
		assert(not site:FindFirstChildWhichIsA("BasePart", true), "placeholder geometry remains")
		if isHanging then hanging += 1 else grounded += 1 end
	end
	local protectedCount = 0
	for part, original in protected do
		protectedCount += 1
		assert(part:IsDescendantOf(region) and part.Size == original[1] and part.CFrame == original[2]
			and part.CanCollide == original[3] and part.Transparency == original[4], "protected geometry changed")
	end
	assert(not props.apply(region, frame) and #region.BlenderProps:GetChildren() == 56, "duplicate placement")
	local imports, storage = Instance.new("Folder"), Instance.new("Folder")
	imports.Parent, storage.Parent = sandbox, sandbox
	local raw = library:Clone()
	raw.Name, raw.Parent = "FrostbitePropsBundle", imports
	for _, mesh in raw:GetDescendants() do
		if mesh:IsA("BasePart") then mesh.Anchored = false mesh.Size *= 100 end
	end
	assert(require(sandbox.ImportStaging).move(imports, storage) == 1, "Frost import not quarantined")
	for _, mesh in raw:GetDescendants() do
		if mesh:IsA("BasePart") then assert(mesh.Anchored and mesh:IsDescendantOf(storage)) end
	end
	return { placements = 56, grounded = grounded, hanging = hanging, protectedParts = protectedCount,
		missingAndPartialFallback = true, idempotent = true, oversizedImportQuarantined = true }
end
local ok, result = pcall(run)
sandbox:Destroy()
assert(ok, result)
return game.HttpService:JSONEncode(result)
