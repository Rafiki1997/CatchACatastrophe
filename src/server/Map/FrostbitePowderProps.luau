--!strict
-- Replace every existing Frost fir site with one approved Powder Fir variant.
-- Template validation and all placement preparation finish before old art moves.
local Props = {}
local Spec = require(script.Parent.FrostbitePowderSpec)
local Alpine = require(script.Parent.FrostbiteAlpineAssetSpec)

local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function positive(v: Vector3): boolean
	return finite(v.X) and finite(v.Y) and finite(v.Z) and v.X > 0 and v.Y > 0 and v.Z > 0
end
local function uploaded(id: string): boolean
	return id:match("^rbxassetid://[1-9]%d*$") ~= nil
end

-- Preserve the old trunk anchor and fit the entire new crown within the old
-- oriented site envelope. This protects paths, walls, and cliff-top supports.
function Props.placement(site: Model, variant: any): (CFrame?, number?)
	local asset = site:GetAttribute("AssetName")
	local size, oldScale, ground = site:GetAttribute("AssetSize"), site:GetAttribute("AssetScale"), site:GetAttribute("GroundCF")
	if typeof(asset) ~= "string" or not Spec.firs[asset] or typeof(size) ~= "Vector3"
		or typeof(oldScale) ~= "number" or not finite(oldScale) or oldScale <= 0
		or typeof(ground) ~= "CFrame" or not positive(size)
		or (size - Alpine.alpine[asset] * oldScale).Magnitude > 0.005 then return nil, nil end
	for _, n in { ground:GetComponents() } do
		if not finite(n) then return nil, nil end
	end
	local oldRoot = Alpine.sockets[asset].TrunkBase.Position * oldScale
	local root, half, oldHalf = variant.root, variant.size / 2, size / 2
	local scale = math.min(size.Y / variant.size.Y,
		(oldHalf.X - oldRoot.X) / (half.X - root.X), (oldHalf.X + oldRoot.X) / (half.X + root.X),
		(oldHalf.Z - oldRoot.Z) / (half.Z - root.Z), (oldHalf.Z + oldRoot.Z) / (half.Z + root.Z))
	if not finite(scale) or scale <= 0 then return nil, nil end
	return ground * CFrame.new(oldRoot - root * scale), scale
end

function Props.apply(parent: Model, frame: CFrame): boolean
	if parent:FindFirstChild("PowderFirs") then return false end
	local library = script.Parent:FindFirstChild(Spec.library)
	local landmarks = parent:FindFirstChild("Landmarks")
	local sites = if landmarks then landmarks:FindFirstChild("PropSites") else nil
	if not library or not sites then return false end
	local templates: { [string]: MeshPart } = {}
	for _, p in library:GetDescendants() do
		if p:IsA("LuaSourceContainer") then return false end
		if p:IsA("BasePart") then
			if not p:IsA("MeshPart") or not Spec.parts[p.Name] or templates[p.Name] then return false end
			templates[p.Name] = p
		end
	end
	for name, def in Spec.parts do
		local p = templates[name]
		if not p or not p.Archivable or not uploaded(p.MeshId) or not positive(p.MeshSize)
			or not positive(p.Size) or (p.Size - def.size).Magnitude > 0.005 then return false end
		local ratio = p.MeshSize / def.size
		if math.abs(ratio.Y / ratio.X - 1) > 0.002 or math.abs(ratio.Z / ratio.X - 1) > 0.002 then return false end
		local textured = uploaded(p.TextureID)
		for _, child in p:GetDescendants() do
			if child:IsA("BasePart") then return false end
			-- ColorMap requires Plugin security; its Content URI is readable in-game.
			if child:IsA("SurfaceAppearance") and uploaded(child.ColorMapContent.Uri) then textured = true end
		end
		if not textured then return false end
	end
	local treeSites: { Model } = {}
	for _, site in sites:GetChildren() do
		local name = site:GetAttribute("AssetName")
		if typeof(name) == "string" and Spec.firs[name] then
			if not site:IsA("Model") then return false end
			table.insert(treeSites, site)
		end
	end
	if #treeSites == 0 then return false end
	table.sort(treeSites, function(a, b) return a.Name < b.Name end)
	local oldProps = parent:FindFirstChild("BlenderProps")
	local prepared = {}
	for i, site in treeSites do
		if site:GetAttribute("AssetLibrary") ~= Alpine.library or site:GetAttribute("CollisionRole") ~= "none"
			or site:GetAttribute("PivotMode") ~= "BottomCenter" or site:GetAttribute("SizeLock") ~= "Uniform" then return false end
		local variant = Spec.variants[(i - 1) % #Spec.variants + 1]
		local base, scale = Props.placement(site, variant)
		if not base or not scale then return false end
		local holder = site:FindFirstChild("PlaceholderArt")
		local old = if oldProps then oldProps:FindFirstChild(site.Name) else nil
		if not holder and not old then return false end
		if holder then
			if not holder:IsA("Model") then return false end
			for _, p in holder:GetDescendants() do
				if p:IsA("BasePart") and (p.CanCollide or p.CanQuery or p.CanTouch) then return false end
			end
		end
		if old and (not old:IsA("MeshPart") or old:GetAttribute("BlenderAsset") ~= site:GetAttribute("AssetName")
			or old.CanCollide or old.CanQuery or old.CanTouch) then return false end
		table.insert(prepared, { site = site, variant = variant, base = base, scale = scale, holder = holder, old = old })
	end
	local group = Instance.new("Model")
	group.Name = "PowderFirs"
	local partCount = 0
	for _, item in prepared do
		local tree = Instance.new("Model")
		tree.Name = item.site.Name
		tree:SetAttribute("Variant", item.variant.id)
		tree:SetAttribute("UniformScale", item.scale)
		tree:SetAttribute("BaseCF", frame * item.base)
		for _, name in item.variant.parts do
			local def = Spec.parts[name]
			local p = templates[name]:Clone()
			p.Size = def.size * item.scale
			p.PivotOffset = CFrame.identity
			p.CFrame = frame * item.base * CFrame.new(def.center * item.scale)
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.Color, p.Transparency = Color3.new(1, 1, 1), 0
			-- RenderFidelity is authored on the template; runtime can only clone it.
			p:SetAttribute("BlenderAsset", name)
			p:SetAttribute("PropSite", item.site.Name)
			p.Parent = tree
			partCount += 1
		end
		tree.Parent = group
	end
	group.Parent = parent
	for _, item in prepared do
		if item.holder then item.holder:Destroy() end
		if item.old then item.old:Destroy() end
		item.site:SetAttribute("AssetPlaced", true)
		item.site:SetAttribute("PowderFirVariant", item.variant.id)
	end
	if oldProps then parent:SetAttribute("BlenderPropCount", #oldProps:GetChildren()) end
	parent:SetAttribute("PowderFirVersion", 1)
	parent:SetAttribute("PowderFirCount", #prepared)
	parent:SetAttribute("PowderFirPartCount", partCount)
	return true
end
return Props
