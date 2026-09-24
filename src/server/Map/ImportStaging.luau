--!strict
-- Imported FBX galleries are editing material, never playable world geometry.
-- Preserve recognized raw bundles in storage before physics can drop them.
local Staging = {}
local LIBRARIES = {
	GustyPropsBundle = "GustyPropTemplates",
	SplashwaterPropsBundle = "SplashwaterPropTemplates",
	CinderPropsBundle = "CinderPropTemplates",
	FrostbitePropsBundle = "FrostbitePropTemplates",
	OrbitPropsBundle = "OrbitPropTemplates",
	ThunderworksPropsBundle = "ThunderPropTemplates",
	PlotPropsBundle = "PlotPropTemplates",
	CinderQuarryBundle = "CinderQuarryTemplates",
	TropicalTidepoolsBundle = "SplashwaterTidepoolTemplates",
	AlpineOutpostBundle = "FrostbiteAlpineTemplates",
	PowderFirsBundle = "FrostbitePowderTemplates",
	GustyBroadleafBundle = "GustyBroadleafTemplates",
}

function Staging.move(source: Instance, storage: Instance): number
	local moved = 0
	for _, bundle in source:GetChildren() do
		local libraryName = LIBRARIES[bundle.Name]
		if not libraryName or not bundle:IsA("Model") then continue end
		local library = script.Parent:FindFirstChild(libraryName)
		-- Recognize a first import before its native library exists. New kits
		-- always require every exact name once, including subsequent imports.
		local firstKit: any = nil
		local firstKitCount = 0
		-- A kit whose bundle may carry spare meshes the layout does not place:
		-- every required name exactly once, and nothing outside the two lists.
		local required: any = nil
		if bundle.Name == "GustyBroadleafBundle" then
			firstKit = require(script.Parent.GustyBroadleafSpec).parts
			for _ in firstKit do firstKitCount += 1 end
		elseif bundle.Name == "PowderFirsBundle" then
			firstKit = require(script.Parent.FrostbitePowderSpec).parts
			for _ in firstKit do firstKitCount += 1 end
		elseif bundle.Name == "CinderQuarryBundle" then
			firstKit, firstKitCount = require(script.Parent.CinderQuarryAssetSpec).quarry, 12
		elseif bundle.Name == "TropicalTidepoolsBundle" then
			firstKit, firstKitCount = require(script.Parent.SplashwaterTidepoolAssetSpec).tidepools, 8
		elseif bundle.Name == "AlpineOutpostBundle" then
			local spec = require(script.Parent.FrostbiteAlpineAssetSpec)
			required = spec.alpine
			firstKit = {}
			for name in spec.alpine do firstKit[name] = true end
			for name in spec.unplaced do firstKit[name] = true end
		elseif not library and bundle.Name == "OrbitPropsBundle" then
			firstKit, firstKitCount = require(script.Parent.OrbitAssetSpec), 15
		elseif not library and bundle.Name == "PlotPropsBundle" then
			firstKit, firstKitCount = require(script.Parent.PlotAssetSpec), 12
		end
		if not library and not firstKit then continue end
		local known: { [string]: string } = {}
		for _, p in (if library then library:GetDescendants() else {}) do
			if p:IsA("MeshPart") then known[p.Name] = p.MeshId end
		end
		local count, recognized = 0, true
		local seen: { [string]: boolean } = {}
		for _, p in bundle:GetDescendants() do
			if p:IsA("BasePart") then
				if not p:IsA("MeshPart") or p:GetAttribute("BlenderAsset") then
					recognized = false
					break
				end
				if firstKit then
					if not firstKit[p.Name] or seen[p.Name] or p.MeshId == "" then recognized = false break end
					seen[p.Name] = true
				end
				-- a spare mesh the captured library never took is not a mismatch
				local spare = required ~= nil and not required[p.Name] and known[p.Name] == nil
				if library and not spare and known[p.Name] ~= p.MeshId then recognized = false break end
				count += 1
			end
		end
		if required then
			for name in required do
				recognized = recognized and seen[name] == true
			end
		elseif firstKit and count ~= firstKitCount then
			recognized = false
		end
		if not recognized or count == 0 then continue end
		local target = storage:FindFirstChild("RegionImportStaging")
		if not target then
			target = Instance.new("Folder")
			target.Name = "RegionImportStaging"
			target.Parent = storage
		end
		for _, p in bundle:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.AssemblyLinearVelocity = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
			end
		end
		bundle:SetAttribute("NativeTemplateLibrary", libraryName)
		bundle:SetAttribute("NativeAssetCount", count)
		bundle.Parent = target
		moved += 1
	end
	return moved
end

-- A copy of an imported mesh falls at raw scale too, whatever it is called:
-- on 2026-09-22 a hand-made FrostbiteALpineTemplates model with one 184-stud
-- crate dropped onto the hub at every start. Run after move. Anything built
-- only from meshes already known as import material, a staged gallery's or a
-- captured library's, is parked apart from the native galleries. Placed props
-- and anything holding other parts stay where they are.
function Staging.quarantine(source: Instance, storage: Instance): number
	local known: { [string]: boolean } = {}
	local function learn(root: Instance?)
		for _, p in (if root then root:GetDescendants() else {}) do
			if p:IsA("MeshPart") and p.MeshId ~= "" then known[p.MeshId] = true end
		end
	end
	learn(storage:FindFirstChild("RegionImportStaging"))
	for _, libraryName in LIBRARIES do
		learn(script.Parent:FindFirstChild(libraryName))
	end
	local moved = 0
	for _, child in source:GetChildren() do
		local parts = child:GetDescendants()
		table.insert(parts, child)
		local count, stray = 0, true
		for _, p in parts do
			if p:IsA("BasePart") then
				if not p:IsA("MeshPart") or not known[p.MeshId] or p:GetAttribute("BlenderAsset") then
					stray = false
					break
				end
				count += 1
			end
		end
		if not stray or count == 0 then continue end
		local target = storage:FindFirstChild("RegionImportStrays")
		if not target then
			target = Instance.new("Folder")
			target.Name = "RegionImportStrays"
			target.Parent = storage
		end
		for _, p in parts do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.AssemblyLinearVelocity = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
			end
		end
		child.Parent = target
		moved += 1
	end
	return moved
end

return Staging
