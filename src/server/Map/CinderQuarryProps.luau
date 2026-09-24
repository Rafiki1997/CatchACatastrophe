--!strict
-- Swap the Cinder Quarry placeholders for Astra's imported meshes, or leave the
-- whole blockout untouched. There is no halfway state: every site is validated
-- against the fixed bounds in CinderQuarryAssetSpec before a single placeholder
-- is destroyed, so a partial or mis-scaled import shows as the blockout rather
-- than as a region with holes in it.
--
-- The kit lives in a sibling model named CinderQuarryTemplates. props-v1's
-- CinderPropTemplates is left alone beside it; it belongs to the superseded
-- Sculpted Ravine layout and is not read here.
local Props = {}
local Spec = require(script.Parent.CinderQuarryAssetSpec)

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function positiveSize(size: Vector3): boolean
	return finite(size.X) and finite(size.Y) and finite(size.Z)
		and size.X > 0 and size.Y > 0 and size.Z > 0
end

local function uploaded(id: string): boolean
	return id:match("^rbxassetid://[1-9]%d*$") ~= nil
		or id:match("^https?://www%.roblox%.com/asset/%?id=[1-9]%d*$") ~= nil
end

function Props.apply(parent: Model, frame: CFrame): boolean
	if parent:FindFirstChild("BlenderProps") then return false end
	local library = script.Parent:FindFirstChild(Spec.library.CC_Quarry)
	local landmarks = parent:FindFirstChild("Landmarks")
	local sites = if landmarks then landmarks:FindFirstChild("PropSites") else nil
	if not library or not sites then return false end

	-- Validate every delivered type once. Size is normalized during capture;
	-- MeshSize remains the imported native data, which may have a uniform unit
	-- conversion (the actual importer used 28.4444x). Reject axis distortion.
	local templates: { [string]: MeshPart } = {}
	for _, obj in library:GetDescendants() do
		if Spec.quarry[obj.Name] then
			if not obj:IsA("MeshPart") or templates[obj.Name] then return false end
			templates[obj.Name] = obj
		end
	end
	for name, expected in Spec.quarry do
		local template = templates[name]
		if not template or not template.Archivable or not positiveSize(template.Size)
			or (template.Size - expected).Magnitude > 0.005
			or not positiveSize(template.MeshSize) or not uploaded(template.MeshId) then return false end
		local ratio = template.MeshSize / expected
		if math.abs(ratio.Y / ratio.X - 1) > 0.002 or math.abs(ratio.Z / ratio.X - 1) > 0.002 then return false end
		local textured = uploaded(template.TextureID)
		for _, obj in template:GetDescendants() do
			if obj:IsA("BasePart") or obj:IsA("LuaSourceContainer") then return false end
			if obj:IsA("SurfaceAppearance") and uploaded(obj.ColorMap) then textured = true end
		end
		if not textured then return false end
	end

	local prepared: { { site: Model, art: Model, template: MeshPart, size: Vector3, cf: CFrame } } = {}
	for _, site in sites:GetChildren() do
		if not site:IsA("Model") then return false end
		local name = site:GetAttribute("AssetName")
		local size = site:GetAttribute("AssetSize")
		local ground = site:GetAttribute("GroundCF")
		local role = site:GetAttribute("PlacementRole")
		local art = site:FindFirstChild("PlaceholderArt")
		if typeof(name) ~= "string" or typeof(size) ~= "Vector3" or typeof(ground) ~= "CFrame"
			or not Spec.quarry[name] or not art or not art:IsA("Model")
			or site:GetAttribute("AssetLibrary") ~= Spec.library.CC_Quarry
			or site:GetAttribute("PivotMode") ~= "BottomCenter"
			or site:GetAttribute("SizeLock") ~= "Fixed"
			or site:GetAttribute("CollisionRole") ~= "none"
			or (role ~= "Grounded" and role ~= "Stacked" and role ~= "Suspended") then return false end
		-- The bounds are the contract, and this is the check that catches the
		-- 100x an FBX conversion can introduce.
		if not finite(size.X) or not finite(size.Y) or not finite(size.Z)
			or (size - Spec.quarry[name]).Magnitude > 0.005 then return false end
		local template = templates[name]
		-- Placeholder art is art. Anything that keeps a player out of a rock is
		-- a proxy in Boundary and is never filed under a site.
		for _, obj in art:GetDescendants() do
			if obj:IsA("BasePart") and obj.CanCollide then return false end
		end
		-- A native MeshPart's CFrame is its bounds centre, so a bottom-centre
		-- site frame has to be lifted by half the asset's height exactly once.
		local cf = frame * ground * CFrame.new(0, size.Y / 2, 0)
		for _, value in { cf:GetComponents() } do
			if not finite(value) then return false end
		end
		table.insert(prepared, { site = site, art = art, template = template, size = size, cf = cf })
	end
	if #prepared == 0 or #prepared ~= sites:GetAttribute("AssetCount") then return false end

	local props = Instance.new("Model")
	props.Name = "BlenderProps"
	for _, item in prepared do
		local mesh = item.template:Clone()
		mesh.Name = item.site.Name
		mesh.Size = item.size
		-- MeshPart CFrames are bounding-box centres irrespective of FBX pivots.
		mesh.PivotOffset = CFrame.identity
		mesh.CFrame = item.cf
		mesh.Color = Color3.new(1, 1, 1)
		mesh.Transparency = 0
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh:SetAttribute("BlenderAsset", item.site:GetAttribute("AssetName"))
		mesh:SetAttribute("PropSite", item.site.Name)
		mesh.Parent = props
	end
	props.Parent = parent
	for _, item in prepared do
		item.art:Destroy()
		item.site:SetAttribute("AssetPlaced", true)
	end
	parent:SetAttribute("BlenderPropsVersion", 1)
	parent:SetAttribute("BlenderPropCount", #prepared)
	return true
end

return Props
