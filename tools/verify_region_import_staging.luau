-- Raw galleries must be quarantined without resizing or replacing native data.
-- All fixtures stay in memory; they are never production templates.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local r = require("@lune/roblox")
local map, cache = r.Instance.new("Folder"), {}
for _, file in fs.readDir("src/server/Map") do
	if file:sub(-5) == ".luau" then
		local m = r.Instance.new("ModuleScript")
		m.Name, m.Source, m.Parent = file:sub(1, -6), fs.readFile("src/server/Map/" .. file), map
	end
end
local function loadModule(m)
	assert(m, "missing required module")
	if cache[m] then return cache[m] end
	local result = luau.load(m.Source, { environment = {
		script = m, require = function(other) return loadModule(other) end,
		Vector3 = r.Vector3, CFrame = r.CFrame, Instance = r.Instance,
	} })()
	cache[m] = result
	return result
end
local staging = loadModule(map.ImportStaging)
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local native = r.deserializeModel(fs.readFile("src/server/Map/CinderPropTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
fixture.MeshSize = fixture.InitialSize
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
fixture.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
for _, kit in {
	{ "assets/cinder-canyon/quarry-v2/manifest.json", "CinderQuarryBundle", "CinderQuarryTemplates" },
	{ "assets/splashwater-bay/tidepools-v2/manifest.json", "TropicalTidepoolsBundle", "SplashwaterTidepoolTemplates" },
} do
	local manifest = serde.decode("json", fs.readFile(kit[1]))
	local source, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
	local function bundle()
		local model = r.Instance.new("Model")
		model.Name, model.Parent = kit[2], source
		for _, asset in manifest.assets do
			local mesh = fixture:Clone()
			mesh.Name = asset.name
			mesh.Size = r.Vector3.new(table.unpack(asset.dimensions_studs_xyz)) * 100
			mesh.Anchored, mesh.Parent = false, model
		end
		return model
	end
	local raw = bundle()
	local original = {}
	for _, mesh in raw:GetChildren() do original[mesh] = { mesh.Size, mesh.MeshSize, mesh.MeshId, mesh.TextureID } end
	check(staging.move(source, storage) == 1 and raw.Parent == storage.RegionImportStaging,
		kit[2] .. " complete first import was not staged")
	check(raw:GetAttribute("NativeTemplateLibrary") == kit[3] and raw:GetAttribute("NativeAssetCount") == #manifest.assets,
		kit[2] .. " import metadata missing")
	for mesh, values in original do
		check(mesh.Anchored and mesh.Size == values[1] and mesh.MeshSize == values[2]
			and mesh.MeshId == values[3] and mesh.TextureID == values[4], "staging changed native data")
	end
	check(staging.move(source, storage) == 0, "already staged bundle moved twice")
	for _, invalid in { "partial", "duplicate", "primitive", "placed", "unuploaded" } do
		local bad = bundle()
		local first = bad:GetChildren()[1]
		if invalid == "partial" then first:Destroy()
		elseif invalid == "duplicate" then first:Clone().Parent = bad
		elseif invalid == "primitive" then r.Instance.new("Part").Parent = bad
		elseif invalid == "placed" then first:SetAttribute("BlenderAsset", first.Name)
		elseif invalid == "unuploaded" then first.MeshId = "" end
		check(staging.move(source, storage) == 0 and bad.Parent == source, invalid .. " kit moved")
		bad:Destroy()
	end
	local library = raw:Clone()
	library.Name, library.Parent = kit[3], map
	local known = bundle()
	check(staging.move(source, storage) == 1 and known:IsDescendantOf(storage), "known library import not staged")
	local wrong = bundle()
	wrong:GetChildren()[1].MeshId = "rbxassetid://1"
	check(staging.move(source, storage) == 0 and wrong.Parent == source, "unrelated asset moved")
	wrong:Destroy()
	local partialKnown = bundle()
	partialKnown:GetChildren()[1]:Destroy()
	check(staging.move(source, storage) == 0 and partialKnown.Parent == source, "partial known kit moved")
	library:Destroy()
end
print(serde.encode("json", { checks = checks, newKitsStaged = true, nativeDataPreserved = true }))
