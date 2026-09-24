--!strict
-- Swap only named prop-site art. Boundary and Walkways remain authoritative.
local Props = {}

function Props.apply(parent: Model, frame: CFrame): boolean
	if parent:FindFirstChild("BlenderProps") then return false end
	local library = script.Parent:FindFirstChild("FrostbitePropTemplates")
	local landmarks = parent:FindFirstChild("Landmarks")
	local sites = if landmarks then landmarks:FindFirstChild("PropSites") else nil
	if not library or not sites then return false end
	local prepared: { { site: Model, template: MeshPart, size: Vector3, cf: CFrame } } = {}
	-- Validate the complete set before replacing any placeholder.
	for _, site in sites:GetChildren() do
		if not site:IsA("Model") then continue end
		local name = site:GetAttribute("AssetName")
		local size = site:GetAttribute("AssetSize")
		local ground = site:GetAttribute("GroundCF")
		local role = site:GetAttribute("CollisionRole")
		if typeof(name) ~= "string" or typeof(size) ~= "Vector3" or typeof(ground) ~= "CFrame"
			or (role ~= "none" and role ~= "hanging") then return false end
		if size.X <= 0 or size.Y <= 0 or size.Z <= 0 or size.Magnitude >= 35 then return false end
		local template = library:FindFirstChild(name, true)
		if not template or not template:IsA("MeshPart") or template.MeshId == ""
			or template.MeshSize.Magnitude == 0 or template.TextureID == "" then return false end
		local offset = if role == "hanging" then -size.Y / 2 else size.Y / 2
		local cf = frame * ground * CFrame.new(0, offset, 0)
		for _, value in { cf:GetComponents() } do
			if value ~= value or math.abs(value) == math.huge then return false end
		end
		table.insert(prepared, { site = site, template = template, size = size, cf = cf })
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
		for _, part in item.site:GetDescendants() do
			if part:IsA("BasePart") then
				-- Keep any future collision proxy; only decorative art is removed.
				if part.CanCollide then
					part.Transparency = 1
					part.CastShadow = false
					part:SetAttribute("BlenderCollisionProxy", true)
				else
					part:Destroy()
				end
			end
		end
		item.site:SetAttribute("AssetPlaced", true)
	end
	parent:SetAttribute("BlenderPropsVersion", 1)
	return true
end

return Props
