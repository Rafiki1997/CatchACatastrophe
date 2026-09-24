--!strict
-- All-site validation and detached clones precede retirement of any old tree.
local Props = {}
local Spec = require(script.Parent.GustyBroadleafSpec)
local V = Vector3.new
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function positive(v: Vector3): boolean
	return finite(v.X) and finite(v.Y) and finite(v.Z) and v.X > 0 and v.Y > 0 and v.Z > 0
end
local function uploaded(id: string): boolean
	return id:match("^rbxassetid://[1-9]%d*$") ~= nil
end
local function finiteCF(cf: CFrame): boolean
	for _, n in { cf:GetComponents() } do
		if not finite(n) then return false end
	end
	return true
end

function Props.apply(parent: Model, frame: CFrame): boolean
	if parent:FindFirstChild("BroadleafTrees") then return false end
	local function reject(reason: string): boolean
		warn("[GustyBroadleaf] Keeping existing trees: " .. reason)
		return false
	end
	local library = script.Parent:FindFirstChild(Spec.library)
	if not library then return false end
	-- Native FBX vertex orientation is measured during capture, independently of
	-- the manifest's centers. This import needs 180 degrees about each part center.
	local nativeYaw = library:GetAttribute("NativeMeshYawDegrees")
	if nativeYaw ~= 0 and nativeYaw ~= 180 then return reject("unverified native mesh orientation") end
	local nativeRotation = CFrame.Angles(0, math.rad(nativeYaw), 0)
	local boundary = parent:FindFirstChild("Boundary")
	local sites = if boundary then boundary:FindFirstChild("BroadleafSites") else nil
	if not sites or not finiteCF(frame) then return reject("missing sites or invalid region frame") end
	local templates: { [string]: MeshPart } = {}
	for _, p in library:GetDescendants() do
		if p:IsA("LuaSourceContainer") then return reject("script in template library") end
		if p:IsA("BasePart") then
			if not p:IsA("MeshPart") or not Spec.parts[p.Name] or templates[p.Name] then return reject("unexpected or duplicate template") end
			templates[p.Name] = p
		end
	end
	for name, def in Spec.parts do
		local p = templates[name]
		if not p or not p.Archivable or not uploaded(p.MeshId) or not positive(p.MeshSize)
			or not positive(p.Size) or (p.Size - def.size).Magnitude > 0.005 then return reject("invalid template " .. name) end
		local ratio = p.MeshSize / def.size
		if math.abs(ratio.Y / ratio.X - 1) > 0.002 or math.abs(ratio.Z / ratio.X - 1) > 0.002 then return reject("distorted template " .. name) end
		local textured = uploaded(p.TextureID)
		for _, child in p:GetDescendants() do
			if child:IsA("BasePart") then return reject("nested template geometry") end
			if child:IsA("SurfaceAppearance") and uploaded(child.ColorMapContent.Uri) then textured = true end
		end
		if not textured then return reject("missing texture " .. name) end
	end
	local ordered = sites:GetChildren()
	if #ordered ~= Spec.siteCount then return reject("expected all " .. Spec.siteCount .. " sites") end
	table.sort(ordered, function(a, b) return a.Name < b.Name end)
	local prepared, seen = {}, {}
	for i, site in ordered do
		local ground, scale = site:GetAttribute("GroundCF"), site:GetAttribute("AssetScale")
		if not site:IsA("Model") or seen[site.Name] or site:GetAttribute("PivotMode") ~= "TrunkBase"
			or site:GetAttribute("SizeLock") ~= "Uniform" or typeof(ground) ~= "CFrame" or not finiteCF(ground)
			or typeof(scale) ~= "number" or not finite(scale) or scale <= 0 then return reject("invalid site " .. site.Name) end
		seen[site.Name] = true
		local trunk, art = site:FindFirstChild("MeadowTreeTrunk"), site:FindFirstChild("PlaceholderArt")
		if not trunk or not trunk:IsA("BasePart") or not trunk.CanCollide or trunk.CanQuery
			or (trunk.Size - V(2.6, 8.5, 2.6) * scale).Magnitude > 0.005
			or not art or not art:IsA("Model") then return reject("missing art/proxy " .. site.Name) end
		local expected = frame * ground * CFrame.new(0, 4.2 * scale, 0)
		local delta = expected:ToObjectSpace(trunk.CFrame)
		local _, angle = delta:ToAxisAngle()
		if delta.Position.Magnitude > 0.005 or math.abs(angle) > 0.001 then return reject("proxy/socket mismatch " .. site.Name) end
		local count = 0
		for _, p in art:GetDescendants() do
			if p:IsA("LuaSourceContainer") then return reject("script inside placeholder") end
			if p:IsA("BasePart") then
				if p.Name ~= "MeadowTreeLobe" or p.CanCollide or p.CanQuery or p.CanTouch then return reject("invalid placeholder " .. site.Name) end
				count += 1
			end
		end
		if count ~= 6 then return reject("incomplete crown " .. site.Name) end
		local variant = Spec.variants[(i - 1) % #Spec.variants + 1]
		for _, name in variant.parts do
			local def = Spec.parts[name]
			local low, high = def.center - def.size / 2, def.center + def.size / 2
			for _, axis in { "X", "Y", "Z" } do
				if low[axis] < Spec.envelopeMin[axis] - 0.001 or high[axis] > Spec.envelopeMax[axis] + 0.001 then return reject("export escapes site envelope") end
			end
		end
		table.insert(prepared, { site = site, ground = ground, scale = scale, trunk = trunk, art = art, variant = variant })
	end
	local group = Instance.new("Model")
	group.Name = "BroadleafTrees"
	local count = 0
	local ok, problem = pcall(function()
		for _, item in prepared do
			local tree = Instance.new("Model")
			tree.Name, tree.Parent = item.site.Name, group
			tree:SetAttribute("Variant", item.variant.id)
			tree:SetAttribute("UniformScale", item.scale)
			tree:SetAttribute("BaseCF", frame * item.ground)
			for _, name in item.variant.parts do
				local def = Spec.parts[name]
				local p = templates[name]:Clone()
				p.Size = def.size * item.scale
				p.CFrame = frame * item.ground * CFrame.new(def.center * item.scale) * nativeRotation
				p.PivotOffset = CFrame.identity
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
				p.Transparency, p.Color = 0, Color3.new(1, 1, 1)
				p:SetAttribute("BlenderAsset", name)
				p:SetAttribute("PropSite", item.site.Name)
				p.Parent = tree
				count += 1
			end
		end
	end)
	if not ok then group:Destroy(); return reject("clone failed: " .. tostring(problem)) end
	group.Parent = parent
	for _, item in prepared do
		item.art:Destroy()
		item.trunk.Transparency, item.trunk.CastShadow = 1, false
		item.trunk:SetAttribute("BlenderCollisionProxy", true)
		item.site:SetAttribute("BroadleafVariant", item.variant.id)
	end
	parent:SetAttribute("BroadleafVersion", 1)
	parent:SetAttribute("BroadleafCount", #prepared)
	parent:SetAttribute("BroadleafPartCount", count)
	return true
end
return Props
