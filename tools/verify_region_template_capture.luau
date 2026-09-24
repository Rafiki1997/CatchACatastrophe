-- Exercises the capture preparation against real native mesh fixtures in memory.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local path = "tools/studio/prepare_region_templates.luau"
assert(fs.isFile(path), "native template capture preparation is missing")
local prepare = luau.load(fs.readFile(path), { environment = {
	Instance = r.Instance, Vector3 = r.Vector3, CFrame = r.CFrame, Color3 = r.Color3,
} })()
local native = r.deserializeModel(fs.readFile("src/server/Map/CinderPropTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
fixture.MeshSize = fixture.InitialSize
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
fixture.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
local specs = { { name = "TestMine", dimensions_studs_xyz = { 64, 42, 48 } },
	{ name = "TestRail", dimensions_studs_xyz = { 12, 1, 26 } } }
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function bundle()
	local model = r.Instance.new("Model")
	for _, spec in specs do
		local p = fixture:Clone()
		p.Name, p.Size, p.Parent = spec.name, r.Vector3.new(table.unpack(spec.dimensions_studs_xyz)) * 100, model
		p.CFrame, p.Anchored = r.CFrame.new(100, 400, 200), false
	end
	return model
end
local raw = bundle()
local library, report = prepare(raw, specs, "TestTemplates")
check(library.Name == "TestTemplates" and library.Parent == nil and #library:GetChildren() == 2, "capture library wrong")
check(math.abs(report.importScale - 100) < 0.001, "100x import scale not detected")
for _, spec in specs do
	local mesh, original = library:FindFirstChild(spec.name), raw:FindFirstChild(spec.name)
	local expected = r.Vector3.new(table.unpack(spec.dimensions_studs_xyz))
	check(mesh.Size == expected and mesh.MeshSize == original.MeshSize and mesh.MeshId == original.MeshId
		and mesh.TextureID == original.TextureID, "native data lost while normalizing")
	check(mesh.Anchored and not mesh.CanCollide and not mesh.CanTouch and not mesh.CanQuery
		and mesh.CFrame.Position == r.Vector3.new(0, expected.Y / 2, 0), "template flags/base wrong")
	check(original.Size == expected * 100 and not original.Anchored, "capture altered raw gallery")
end
for _, failure in { "partial", "duplicate", "distorted", "mixedScale", "texture", "mesh", "primitive" } do
	local bad = bundle()
	if failure == "partial" then bad.TestRail:Destroy()
	elseif failure == "duplicate" then bad.TestRail:Clone().Parent = bad
	elseif failure == "distorted" then bad.TestRail.Size *= r.Vector3.new(1, 2, 1)
	elseif failure == "mixedScale" then bad.TestRail.Size /= 100
	elseif failure == "texture" then bad.TestRail.TextureID = ""
	elseif failure == "mesh" then bad.TestRail.MeshId = ""
	elseif failure == "primitive" then r.Instance.new("Part").Parent = bad end
	local ok = pcall(prepare, bad, specs, "TestTemplates")
	check(not ok, failure .. " import incorrectly accepted")
end
print("Native template capture: " .. checks .. " checks passed (fixture only)")
