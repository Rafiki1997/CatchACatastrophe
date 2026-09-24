--!strict
-- Swap the Alpine Outpost placeholders for Astra's imported meshes, or leave the
-- whole blockout untouched. Every site and every template is validated against
-- FrostbiteAlpineAssetSpec before a single placeholder is destroyed, so a
-- partial kit, a 100x FBX scale or a distorted mesh shows up as the blockout
-- rather than as a region with holes in it.
--
-- Unlike the quarry, some sites place a mesh at a uniform scale (firs of several
-- heights from three meshes). A site declares that with AssetScale, and its
-- AssetSize must be the spec bounds times exactly that number on all three axes.
-- The native MeshSize is never touched; only the placed Size scales.
--
-- The kit lives in a sibling model named FrostbiteAlpineTemplates. props-v1's
-- FrostbitePropTemplates is left alone beside it; it belongs to the superseded
-- circular blockout and is not read here.
local Props = {}
local Spec = require(script.Parent.FrostbiteAlpineAssetSpec)

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
	local library = script.Parent:FindFirstChild(Spec.library)
	local landmarks = parent:FindFirstChild("Landmarks")
	local sites = if landmarks then landmarks:FindFirstChild("PropSites") else nil
	if not library or not sites then return false end

	-- One template per spec name. Size is normalized to the spec at capture;
	-- MeshSize is the native data and may carry a uniform unit conversion, but
	-- never a per-axis one.
	local templates: { [string]: MeshPart } = {}
	for _, obj in library:GetDescendants() do
		if Spec.alpine[obj.Name] then
			if not obj:IsA("MeshPart") or templates[obj.Name] then return false end
			templates[obj.Name] = obj
		end
	end
	for name, expected in Spec.alpine do
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
		local scale = site:GetAttribute("AssetScale")
		local ground = site:GetAttribute("GroundCF")
		local role = site:GetAttribute("PlacementRole")
		local art = site:FindFirstChild("PlaceholderArt")
		if typeof(name) ~= "string" or typeof(size) ~= "Vector3" or typeof(ground) ~= "CFrame"
			or typeof(scale) ~= "number" or not Spec.alpine[name] or not art or not art:IsA("Model")
			or site:GetAttribute("AssetLibrary") ~= Spec.library
			or site:GetAttribute("PivotMode") ~= "BottomCenter"
			or site:GetAttribute("SizeLock") ~= "Uniform"
			or site:GetAttribute("CollisionRole") ~= "none"
			or (role ~= "Grounded" and role ~= "Stacked") then return false end
		-- The bounds are the contract: spec times the declared scale, the same
		-- on every axis. This is the check that catches a 100x import.
		if not finite(scale) or scale < 0.25 or scale > 2
			or not finite(size.X) or not finite(size.Y) or not finite(size.Z)
			or (size - Spec.alpine[name] * scale).Magnitude > 0.005 then return false end
		for _, obj in art:GetDescendants() do
			if obj:IsA("BasePart") and (obj.CanCollide or obj.CanQuery) then return false end
		end
		-- A native MeshPart's CFrame is its bounds centre, so the bottom-centre
		-- site frame is lifted by half the placed height exactly once.
		local cf = frame * ground * CFrame.new(0, size.Y / 2, 0)
		for _, value in { cf:GetComponents() } do
			if not finite(value) then return false end
		end
		table.insert(prepared, { site = site, art = art, template = templates[name], size = size, cf = cf })
	end
	if #prepared == 0 or #prepared ~= sites:GetAttribute("AssetCount") then return false end

	local props = Instance.new("Model")
	props.Name = "BlenderProps"
	for _, item in prepared do
		local mesh = item.template:Clone()
		mesh.Name = item.site.Name
		mesh.Size = item.size
		mesh.PivotOffset = CFrame.identity
		mesh.CFrame = item.cf
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
