--!strict
-- Decorative Blender kit placement. Keep existing solid rock proxies and paths.
local Props = {}
local CollectionService = game:GetService("CollectionService")
local V = Vector3.new
local KIT = {
	Wind = { library = "GustyPropTemplates", names = {
		"GG_Moss_Rock_Wide", "GG_Moss_Rock_Tall", "GG_Daisy_Cluster", "GG_Bluebell_Cluster",
		"GG_Fern", "GG_Meadow_Shrub", "GG_Windbent_Tree", "GG_Flower_Planter",
	} },
	Water = { library = "SplashwaterPropTemplates", names = {
		"SB_Coastal_Rock_Wide", "SB_Coastal_Rock_Tall", "SB_Driftwood", "SB_Shell_Cluster",
		"SB_Starfish", "SB_Rope_Bollard", "SB_Harbor_Barrel", "SB_Marker_Buoy",
	} },
}

function Props.apply(parent: Model, frame: CFrame, element: string): boolean
	local kit = KIT[element]
	if not kit or parent:FindFirstChild("BlenderProps") then return false end
	local library = script.Parent:FindFirstChild(kit.library)
	local landmarks = parent:FindFirstChild("Landmarks")
	if not library or not landmarks then return false end
	local templates: { [string]: MeshPart } = {}
	for _, name in kit.names do
		local p = library:FindFirstChild(name, true)
		if not p or not p:IsA("MeshPart") or p.MeshId == "" or p.MeshSize.Magnitude == 0 then
			warn("[GardenBayProps] Incomplete native template: " .. name)
			return false
		end
		templates[name] = p
	end
	local model = Instance.new("Model")
	model.Name = "BlenderProps"
	model.Parent = parent
	local function place(name: string, size: Vector3, cf: CFrame): MeshPart
		local p = templates[name]:Clone()
		p.Size = size
		p.PivotOffset = CFrame.identity
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p:SetAttribute("BlenderAsset", name)
		p.Parent = model
		return p
	end
	local function at(name: string, bottom: CFrame, scale: number?, size: Vector3?): MeshPart
		local dimensions = size or templates[name].Size * (scale or 1)
		local p = place(name, dimensions, frame * bottom * CFrame.new(0, dimensions.Y / 2, 0))
		if name == "GG_Fern" or name == "GG_Meadow_Shrub"
			or name == "GG_Daisy_Cluster" or name == "GG_Bluebell_Cluster" then
			p:SetAttribute("SceneryPivot", frame * bottom)
			p:SetAttribute("SceneryOffset", CFrame.new(0, dimensions.Y / 2, 0))
			p:SetAttribute("SceneryMode", "Sway")
			p:SetAttribute("ScenerySpeed", 0.9)
			p:SetAttribute("SceneryPhase", bottom.X * 0.08 + bottom.Z * 0.035)
			p:SetAttribute("SceneryAmplitude", 0.025)
			CollectionService:AddTag(p, "SceneryMotion")
		end
		return p
	end
	local function retire(p: BasePart)
		if p.CanCollide then
			p.Transparency = 1
			p.CastShadow = false
			p:SetAttribute("BlenderCollisionProxy", true)
		else
			p:Destroy()
		end
	end
	local rocks, flowers = 0, 0
	-- Wind's kit-bearing geometry is parented straight to Landmarks. Splashwater
	-- Bay files its boulders and shore dressing under Shore and Boundary and
	-- inside the grotto / cascade models, so Water walks the whole region.
	local scan = if element == "Wind" then landmarks:GetChildren() else parent:GetDescendants()
	for _, p in scan do
		if not p:IsA("BasePart") then continue end
		if element == "Wind" then
			if p.Name == "GardenStone" then
				rocks += 1
				place(if rocks % 3 == 0 then "GG_Moss_Rock_Tall" else "GG_Moss_Rock_Wide", p.Size, p.CFrame)
				retire(p)
			elseif p.Name == "FlowerBed" then
				flowers += 1
				local localPosition = frame:PointToObjectSpace(p.Position)
				at(if flowers % 3 == 0 then "GG_Bluebell_Cluster" else "GG_Daisy_Cluster",
					CFrame.new(localPosition.X, 0.55, localPosition.Z) * CFrame.Angles(0, flowers * 0.7, 0), 1.05)
			elseif p.Name == "LeaningTrunk" or p.Name == "TreeBranch" or p.Name == "WindCanopy"
				or p.Name == "FlowerStem" or p.Name == "Petal" or p.Name == "FlowerCentre" then
				retire(p)
			end
		else
			-- Every swap below reuses the placeholder's own CFrame, so the kit
			-- follows the layout instead of a second copy of its coordinates.
			-- Only parts built as blocks or balls qualify; the barrels and logs
			-- are stacked cylinders whose CFrame carries a baked quarter turn,
			-- so those are retired and re-placed from the list further down.
			if p.Name == "TideRock" then
				rocks += 1
				place(if rocks % 3 == 0 then "SB_Coastal_Rock_Tall" else "SB_Coastal_Rock_Wide", p.Size, p.CFrame)
				retire(p)
			elseif p.Name == "SeaShell" then
				place("SB_Shell_Cluster", V(1.9, 0.45, 1.15), p.CFrame)
				retire(p)
			elseif p.Name == "Starfish" then
				place("SB_Starfish", V(2.6, 0.5, 2.6), p.CFrame * CFrame.new(0, 0.12, 0))
				retire(p)
			elseif p.Name == "ShellRidge" or p.Name == "StarfishArm"
				or p.Name == "Driftwood" or p.Name == "DriftwoodBranch"
				or p.Name == "BayBarrel" or p.Name == "BayBarrelBand" or p.Name == "BayBarrelTop" then
				retire(p)
			end
		end
	end
	if element == "Wind" then
		for _, spec in { { -56, -36, 1 }, { 57, -24, 0.9 }, { -58, 27, 1.15 }, { 48, 46, 1.2 }, { 18, 66, 0.9 } } do
			local x, z, scale = spec[1], spec[2], spec[3]
			-- Static trunk and crown: existing meadow grass and mill still animate.
			at("GG_Windbent_Tree", CFrame.new(x + 2 * scale, 0.4, z), 1, V(14, 19, 8.5) * scale)
			at("GG_Fern", CFrame.new(x - 3, 0.4, z - 3) * CFrame.Angles(0, x, 0), 0.85)
		end
		for _, deg in { 40, 100, 250, 300 } do
			local a = math.rad(deg)
			at("GG_Meadow_Shrub", CFrame.new(math.sin(a) * 67, 0.4, -math.cos(a) * 67) * CFrame.Angles(0, -a, 0), 1.2)
		end
		for _, pos in { V(-10, 0.4, 60), V(-34, 0.4, 56) } do
			at("GG_Flower_Planter", CFrame.new(pos), 1.1)
		end
	else
		-- The two logs and five barrels SplashwaterBay lays out; keep these in
		-- step with its own `barrel` and driftwood lists if either moves.
		for _, spec in { { 70, -52, 0.7 }, { -66, 66, -0.5 } } do
			at("SB_Driftwood", CFrame.new(spec[1], 0.4, spec[2]) * CFrame.Angles(0, spec[3], 0), 1.1)
		end
		for _, spec in { { 124, -6, 0.4 }, { 118, -14, -0.2 }, { -122, -4, 0.5 }, { -34, 82, 0.3 }, { -42, 80, -0.4 } } do
			at("SB_Harbor_Barrel", CFrame.new(spec[1], 0.4, spec[2]) * CFrame.Angles(0, spec[3], 0), 1)
		end
		-- SB_Rope_Bollard and SB_Marker_Buoy are harbour props: the boardwalk
		-- and the moorings they dressed are gone with the lighthouse concept,
		-- and Tropical Tidepools has nowhere for them. They stay in the kit
		-- contract so the bundle still validates.
	end
	parent:SetAttribute("BlenderPropsVersion", 1)
	return true
end

return Props
