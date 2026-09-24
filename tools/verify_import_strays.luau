-- A copy of an imported kit mesh left loose in Workspace falls at raw import
-- scale on every start, whatever it is called. 2026-09-22: a hand-made
-- FrostbiteALpineTemplates model holding one 184-stud FP_Alpine_Crate dropped
-- onto the hub each time the game started. All fixtures stay in memory.
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
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
local RAW = r.Vector3.new(184.32, 184.32, 184.32)

local function copy(name, parent)
	local model = r.Instance.new("Model")
	model.Name = name
	local crate = fixture:Clone()
	crate.Name, crate.Size, crate.Anchored, crate.Parent = "FP_Alpine_Crate", RAW, false, model
	model.Parent = parent
	return model, crate
end

-- The reported case: the gallery it was copied from is already staged.
local source, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
local staged = r.Instance.new("Folder")
staged.Name, staged.Parent = "RegionImportStaging", storage
local gallery = r.Instance.new("Model")
gallery.Name, gallery.Parent = "AlpineOutpostBundle", staged
fixture:Clone().Parent = gallery
local stray, crate = copy("FrostbiteALpineTemplates", source)
check(staging.quarantine(source, storage) == 1, "renamed copy of a staged mesh left in the world")
check(stray.Parent == storage:FindFirstChild("RegionImportStrays"), "copy not parked with the strays")
check(crate.Anchored and crate.AssemblyLinearVelocity == r.Vector3.zero, "parked copy can still fall")
check(crate.Size == RAW and crate.MeshId == fixture.MeshId, "quarantine changed the mesh")
check(stray:GetAttribute("NativeTemplateLibrary") == nil, "a stray copy posed as a native kit")
check(#staged:GetChildren() == 1, "a stray copy was mixed into the native galleries")
check(staging.quarantine(source, storage) == 0, "quarantine is not idempotent")

local loose = fixture:Clone()
loose.Anchored, loose.Parent = false, source
check(staging.quarantine(source, storage) == 1 and loose.Parent == storage.RegionImportStrays, "loose top-level mesh left in the world")

-- Not import material: left exactly where it is.
local mixed = copy("Mixed", source)
r.Instance.new("Part").Parent = mixed
local unknown, other = copy("Unknown", source)
other.MeshId = "rbxassetid://1"
local placed, prop = copy("Placed", source)
prop:SetAttribute("BlenderAsset", "FP_Alpine_Crate")
local empty = r.Instance.new("Model")
empty.Parent = source
check(staging.quarantine(source, storage) == 0, "unrelated content was quarantined")
for _, kept in { mixed, unknown, placed, empty } do
	check(kept.Parent == source, kept.Name .. " was moved")
end

-- A captured library makes its meshes known with nothing staged.
local source2, storage2 = r.Instance.new("Folder"), r.Instance.new("Folder")
local leftover = copy("Leftover", source2)
check(staging.quarantine(source2, storage2) == 0, "unknown mesh quarantined with no library")
local library = r.Instance.new("Model")
library.Name, library.Parent = "CinderPropTemplates", map
fixture:Clone().Parent = library
check(staging.quarantine(source2, storage2) == 1 and leftover.Parent == storage2.RegionImportStrays, "copy of a library mesh left in the world")
library:Destroy()

print(serde.encode("json", { checks = checks, strayCopiesQuarantined = true, unrelatedPreserved = true }))
