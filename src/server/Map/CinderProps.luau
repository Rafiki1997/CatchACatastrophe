--!strict
-- Imported Blender meshes live in the sibling CinderPropTemplates model.
-- An incomplete import leaves the entire blockout intact.
local Props = {}
local V = Vector3.new
local NAMES = {
	"CC_Basalt_Tall", "CC_Basalt_Wide", "CC_Basalt_Low",
	"CC_Ember_Tall", "CC_Ember_Fan", "CC_Ember_Small",
	"CC_Sandstone_Wide", "CC_Sandstone_Tall", "CC_Sandstone_Rubble",
}

function Props.apply(parent: Model, frame: CFrame): boolean
	local library = script.Parent:FindFirstChild("CinderPropTemplates")
	if not library then return false end
	local templates: { [string]: MeshPart } = {}
	for _, name in NAMES do
		local mesh = library:FindFirstChild(name, true)
		if not mesh or not mesh:IsA("MeshPart") or mesh.MeshId == "" then
			warn("[CinderProps] Import incomplete: " .. name)
			return false
		end
		templates[name] = mesh
	end
	local landmarks = parent:FindFirstChild("Landmarks")
	if not landmarks or parent:FindFirstChild("BlenderProps") then return false end
	local props = Instance.new("Model")
	props.Name = "BlenderProps"
	props.Parent = parent
	local function place(name: string, size: Vector3, cf: CFrame, shadow: boolean?): MeshPart
		local mesh = templates[name]:Clone()
		mesh.Size = size
		-- MeshPart CFrames are bounding-box centres, irrespective of FBX pivots.
		mesh.PivotOffset = CFrame.identity
		mesh.CFrame = cf
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh.CastShadow = shadow ~= false
		mesh:SetAttribute("BlenderAsset", name)
		mesh.Parent = props
		return mesh
	end
	local function ring(deg: number, radius: number): CFrame
		local angle = math.rad(deg)
		return frame * CFrame.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius) * CFrame.Angles(0, -angle, 0)
	end
	for _, p in landmarks:GetChildren() do
		if not p:IsA("BasePart") then continue end
		local asset: string? = nil
		if p.Name == "FieldStone" then asset = "CC_Sandstone_Rubble"
		elseif p.Name == "CurbStone" then asset = "CC_Basalt_Wide"
		elseif p.Name == "ChannelStone" then asset = "CC_Basalt_Low"
		elseif p.Name == "ApproachBoulder" then asset = "CC_Sandstone_Wide"
		end
		if asset then
			place(asset, p.Size, p.CFrame, p.Name ~= "FieldStone")
		end
		if asset or p.Name == "BasaltPrism" or p.Name == "EmberCrystal" or p.Name == "CrystalCore" then
			if p.CanCollide then
				-- Keep Claude's tested collision footprint under the art.
				p.Transparency = 1
				p.CastShadow = false
				p:SetAttribute("BlenderCollisionProxy", true)
			else
				p:Destroy()
			end
		end
	end
	for index, site in { { 63, 18 }, { 66, 300 }, { 62, 168 }, { 64, 282 }, { 62, 340 } } do
		local height = 15.6 + index * 0.6
		place("CC_Basalt_Tall", V(9.6, height, 5.0), ring(site[2], site[1]) * CFrame.new(0, height / 2, 0.9))
	end
	local variants = { "CC_Ember_Tall", "CC_Ember_Fan", "CC_Ember_Small" }
	for index, site in { { 67, 214 }, { 65, 246 }, { 63, 262 }, { 60, 24 }, { 68, 196 }, { 62, 330 } } do
		local height = 5.2 + index * 0.2
		local mesh = place(variants[(index - 1) % 3 + 1], V(4.3, height, 2.8), ring(site[2], site[1]) * CFrame.new(0, height / 2, 0.55))
		-- The atlas carries the orange facets; do not make the basalt base Neon.
		if index <= 2 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 153, 65)
			light.Brightness = 0.45
			light.Range = 8
			light.Shadows = false
			light.Parent = mesh
		end
	end
	for _, deg in { 144, 182 } do
		place("CC_Sandstone_Tall", V(3.006, 3.5, 2.529), ring(deg, 68) * CFrame.new(0, 1.75, 0))
	end
	parent:SetAttribute("BlenderPropsVersion", 1)
	return true
end

return Props
