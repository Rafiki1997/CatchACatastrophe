--!strict
-- Complete-kit replacement. All clones/effects are prepared before fallback
-- art retires. The old SplashwaterPropTemplates kit remains independent.
local Props = {}
local Spec = require(script.Parent.SplashwaterTidepoolAssetSpec)
local V = Vector3.new

local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end

local function textured(mesh: MeshPart): boolean
	if mesh.TextureID ~= "" then return true end
	local surface = mesh:FindFirstChildWhichIsA("SurfaceAppearance")
	return surface ~= nil and surface.ColorMap ~= ""
end

local function effects(parent: Model, asset: string, base: CFrame, scale: number)
	local sockets = Spec.sockets[asset]
	local function point(name: string): Vector3
		return base:PointToWorldSpace(sockets[name] * scale)
	end
	local function water(name: string, size: Vector3, cf: CFrame, foam: boolean?): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size * scale, cf
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Material = if foam then Enum.Material.SmoothPlastic else Enum.Material.Glass
		p.Color = if foam then Color3.fromRGB(252, 252, 248) else Color3.fromRGB(64, 214, 235)
		p.Transparency = if foam then 0 else 0.18
		p.Reflectance = if foam then 0 else 0.08
		p:SetAttribute("TidepoolEffect", true)
		p:SetAttribute("AssetName", asset)
		p.Parent = parent
		return p
	end
	local function plane(name: string, socket: string, width: number, depth: number, foam: boolean?)
		local p = water(name, V(width, 0.22, depth), base * CFrame.new(sockets[socket] * scale), foam)
		p:SetAttribute("Socket", socket)
	end
	local function fall(name: string, from: string, to: string, width: number)
		local a, b = point(from), point(to)
		-- The sheet's long Y axis joins the two sockets exactly. Rotate around
		-- that axis to keep its width across the rock's local X direction.
		local cf = CFrame.fromMatrix((a + b) / 2, base.RightVector, (a - b).Unit)
		local p = water(name, V(width, (a - b).Magnitude / scale, 0.65), cf)
		p.Material, p.Transparency = Enum.Material.Neon, 0.30
		p:SetAttribute("SocketFrom", from)
		p:SetAttribute("SocketTo", to)
	end
	if asset == "SB_Tidepool_Grotto" then
		plane("GrottoNativeLip", "GrottoFallLip", 8.5, 1.4)
		fall("GrottoNativeFall", "GrottoFallLip", "GrottoFallFoot", 8)
		plane("GrottoNativeFoam", "GrottoFallFoot", 10, 3, true)
	elseif asset == "SB_Cascade_Rocks" then
		plane("CascadeNativeUpperLip", "UpperLip", 10, 1.5)
		fall("CascadeNativeUpperFall", "UpperLip", "MidPool", 10)
		local a, b = sockets.MidPool, sockets.LowerLip
		water("CascadeNativeShelfPool", V(12, 0.22, (a - b).Magnitude + 1),
			base * CFrame.new((a + b) * (scale / 2)))
		plane("CascadeNativeLowerLip", "LowerLip", 14, 1.5)
		fall("CascadeNativeLowerFall", "LowerLip", "LowerFoot", 14)
		plane("CascadeNativeFoam", "LowerFoot", 17, 3.5, true)
	end
end

function Props.apply(parent: Model, frame: CFrame): boolean
	if parent:FindFirstChild("TidepoolProps") then return false end
	local library = script.Parent:FindFirstChild(Spec.library)
	local landmarks = parent:FindFirstChild("Landmarks")
	local sites = if landmarks then landmarks:FindFirstChild("TidepoolSites") else nil
	local boundary = parent:FindFirstChild("Boundary")
	if not library or not sites or not boundary then return false end
	local templates: { [string]: MeshPart } = {}
	for name, size in Spec.tidepools do
		local template = library:FindFirstChild(name, true)
		if not template or not template:IsA("MeshPart") or not template.Archivable
			or template.MeshId == "" or not textured(template) then return false end
		for _, axis in { "X", "Y", "Z" } do
			if not finite(template.Size[axis]) or not finite(template.MeshSize[axis]) or template.MeshSize[axis] <= 0
				or math.abs(template.Size[axis] - size[axis]) > size[axis] * 0.01 + 0.02 then return false end
		end
		-- Duplicate names are ambiguous importer output, not a usable kit.
		local count = 0
		for _, obj in library:GetDescendants() do
			if obj.Name == name then count += 1 end
		end
		if count ~= 1 then return false end
		templates[name] = template
	end

	local prepared: { { site: Model, art: Model, asset: string, size: Vector3, base: CFrame, scale: number } } = {}
	local represented: { [string]: number } = {}
	for _, site in sites:GetChildren() do
		if not site:IsA("Model") then return false end
		local name = site:GetAttribute("AssetName")
		local ground = site:GetAttribute("GroundCF")
		local scale = site:GetAttribute("UniformScale")
		local art = site:FindFirstChild("PlaceholderArt")
		if typeof(name) ~= "string" or not templates[name] or typeof(ground) ~= "CFrame"
			or typeof(scale) ~= "number" or not finite(scale) or scale <= 0 or scale > 2
			or not art or not art:IsA("Model") or #art:GetChildren() == 0
			or site:GetAttribute("AssetLibrary") ~= Spec.library or site:GetAttribute("PivotMode") ~= "BottomCenter" then return false end
		local size = Spec.tidepools[name] * scale
		local recordedSize = site:GetAttribute("AssetSize")
		if typeof(recordedSize) ~= "Vector3" or (recordedSize - size).Magnitude > 0.005 then return false end
		local base = frame * ground
		for _, n in { base:GetComponents() } do
			if not finite(n) then return false end
		end
		if name == "SB_Tidepool_Grotto" or name == "SB_Cascade_Rocks" then
			local fallback = site:FindFirstChild("FallbackEffects")
			if not fallback or not fallback:IsA("Model") then return false end
		end
		represented[name] = (represented[name] or 0) + 1
		table.insert(prepared, { site = site, art = art, asset = name, size = size, base = base, scale = scale })
	end
	if #prepared == 0 or #prepared ~= sites:GetAttribute("AssetCount") then return false end
	for name in Spec.tidepools do
		if not represented[name] then return false end
	end
	if represented.SB_Tidepool_Grotto ~= 1 or represented.SB_Cascade_Rocks ~= 1 then return false end

	local props, water = Instance.new("Model"), Instance.new("Model")
	props.Name, water.Name = "TidepoolProps", "TidepoolWaterEffects"
	for _, item in prepared do
		local mesh = templates[item.asset]:Clone()
		mesh.Name, mesh.Size = item.site.Name, item.size
		mesh.PivotOffset = CFrame.identity
		mesh.CFrame = item.base * CFrame.new(0, item.size.Y / 2, 0)
		mesh.Color, mesh.Transparency = Color3.new(1, 1, 1), 0
		mesh.Anchored, mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = true, false, false, false
		mesh:SetAttribute("BlenderAsset", item.asset)
		mesh:SetAttribute("PropSite", item.site.Name)
		mesh.Parent = props
		effects(water, item.asset, item.base, item.scale)
	end
	-- Preserve the exact solid parts, transforms and query flags. Only their
	-- obsolete appearance retires; the sculpted cave never gets a solid hull.
	for _, item in prepared do
		for _, p in item.art:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide then
				p.Transparency, p.CastShadow = 1, false
				p:SetAttribute("TidepoolCollisionProxy", true)
				p.Parent = boundary
			end
		end
		item.art:Destroy()
		local fallback = item.site:FindFirstChild("FallbackEffects")
		if fallback then fallback:Destroy() end
		item.site:SetAttribute("AssetPlaced", true)
	end
	props.Parent, water.Parent = parent, parent
	parent:SetAttribute("TidepoolPropCount", #prepared)
	parent:SetAttribute("TidepoolPropsVersion", 1)
	return true
end

return Props
