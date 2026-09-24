--!strict
-- Swap the plot's placeholder art for Astra's native meshes, all or nothing.
--
-- Same contract as ThunderProps / OrbitProps: every site under `PropSites` is a
-- Model carrying AssetName, AssetSize, plot-local GroundCF (bottom-centre),
-- PivotMode "BottomCenter", CollisionRole "none", PlacementRole Grounded or
-- Stacked, and a PlaceholderArt child Model with no colliding part. The native
-- library is `script.Parent.PlotPropTemplates` (a Rojo-synced .rbxm of
-- MeshParts named per PlotAssetSpec). Anything off -> false, nothing touched.
local Props = {}
local sizes = require(script.Parent.PlotAssetSpec)

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function Props.apply(parent: Model, frame: CFrame): boolean
	if parent:FindFirstChild("BlenderProps") then
		return false
	end
	local library = script.Parent:FindFirstChild("PlotPropTemplates")
	local sites = parent:FindFirstChild("PropSites")
	if not library or not sites then
		return false
	end
	local prepared: { { site: Model, art: Model, template: MeshPart, size: Vector3, cf: CFrame } } = {}
	for _, site in sites:GetChildren() do
		if not site:IsA("Model") then
			return false
		end
		local name = site:GetAttribute("AssetName")
		local size = site:GetAttribute("AssetSize")
		local ground = site:GetAttribute("GroundCF")
		local role = site:GetAttribute("PlacementRole")
		local art = site:FindFirstChild("PlaceholderArt")
		if typeof(name) ~= "string" or typeof(size) ~= "Vector3" or typeof(ground) ~= "CFrame"
			or not sizes[name] or not art or not art:IsA("Model")
			or site:GetAttribute("PivotMode") ~= "BottomCenter"
			or site:GetAttribute("CollisionRole") ~= "none"
			or (role ~= "Grounded" and role ~= "Stacked") then
			return false
		end
		if not finite(size.X) or not finite(size.Y) or not finite(size.Z)
			or (size - sizes[name]).Magnitude > 0.005 then
			return false
		end
		local template = library:FindFirstChild(name, true)
		if not template or not template:IsA("MeshPart") or template.MeshId == ""
			or template.MeshSize.Magnitude <= 0 then
			return false
		end
		for _, obj in art:GetDescendants() do
			if obj:IsA("BasePart") and obj.CanCollide then
				return false
			end
		end
		local cf = frame * ground * CFrame.new(0, size.Y / 2, 0)
		for _, value in { cf:GetComponents() } do
			if not finite(value) then
				return false
			end
		end
		table.insert(prepared, { site = site, art = art, template = template, size = size, cf = cf })
	end
	if #prepared == 0 or #prepared ~= sites:GetAttribute("AssetCount") then
		return false
	end
	local props = Instance.new("Model")
	props.Name = "BlenderProps"
	for _, item in prepared do
		local mesh = item.template:Clone()
		mesh.Name = item.site.Name
		mesh.Size = item.size
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
