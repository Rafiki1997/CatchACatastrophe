-- Headless whole-map harness. Loads the real src tree under a virtual Roblox
-- module tree and runs MapBuilder.build(), then dumps every BasePart to JSON.
--   lune run worldharness.luau <out.json>
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local P = require("./lune_proxy")

local REPO = "C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe/"
local OUT = process.args[1] or "map.json"

local V3, CF = roblox.Vector3, roblox.CFrame

-- Lune's CFrame.lookAt negates Z relative to Roblox; replace it.
local function lookAt(pos, target, up)
	up = up or V3.new(0, 1, 0)
	local look = (target - pos).Unit
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look)
	return CF.fromMatrix(pos, right, up2, -look)
end
local CFshim = setmetatable({ lookAt = lookAt }, { __index = CF })

-- Roblox's Random, which lune lacks. Deterministic per seed; the stream differs
-- from Roblox's, so seeded decorative scatter renders in a different (but
-- stable) arrangement than in Studio. Layout-bearing geometry never uses it.
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	return setmetatable({ s = (tonumber(seed) or 0) % 2147483647 + 1 }, RandomShim)
end
function RandomShim:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function RandomShim:NextNumber(a, b)
	if a == nil then return self:_next() end
	return a + (b - a) * self:_next()
end
function RandomShim:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next()) 
end
function RandomShim:NextUnitVector()
	local z = self:NextNumber(-1, 1)
	local t = self:NextNumber(0, math.pi * 2)
	local r = math.sqrt(math.max(0, 1 - z * z))
	return V3.new(math.cos(t) * r, z, math.sin(t) * r)
end
function RandomShim:Clone() return RandomShim.new(self.s) end


-- ------------------------------------------------------- virtual module tree
-- Built eagerly: lune's fs calls yield, which is illegal inside __index.
local Node = {}
-- A module folder must also quack like an Instance: the prop modules reach for
-- their .rbxm libraries with script.Parent:FindFirstChild(name).
local function nodeValue(n)
	if n == nil then return nil end
	return rawget(n, "__rbxm") or n
end
local NODE_METHODS = {
	FindFirstChild = function(self, name)
		return nodeValue(rawget(self, "__kids")[name])
	end,
	WaitForChild = function(self, name)
		return nodeValue(rawget(self, "__kids")[name])
	end,
	GetChildren = function(self)
		local out = {}
		for _, v in rawget(self, "__kids") do table.insert(out, nodeValue(v)) end
		return out
	end,
	IsA = function(_, cls) return cls == "Folder" or cls == "Instance" end,
	GetDescendants = function() return {} end,
}
Node.__index = function(self, key)
	local m = NODE_METHODS[key]
	if m then return m end
	return rawget(self, "__kids")[key]
end

local function newNode(fields)
	return setmetatable(fields, Node)
end

local function buildTree(dir, parent)
	local node = newNode({ __dir = dir, __kids = {}, Parent = parent, Name = dir:match("([^/]+)$") })
	for _, entry in fs.readDir(REPO .. dir) do
		local full = dir .. "/" .. entry
		if fs.isDir(REPO .. full) then
			node.__kids[entry] = buildTree(full, node)
		elseif entry:sub(-5) == ".luau" then
			local stem = entry:sub(1, -6)
			if stem == "init" then
				node.__file = full
			else
				node.__kids[stem] = newNode({ __file = full, __kids = {}, Parent = node, Name = stem })
			end
		elseif entry:sub(-5) == ".rbxm" then
			local stem = entry:sub(1, -6)
			local model = nil
			local ok, res = pcall(function() return roblox.deserializeModel(fs.readFile(REPO .. full)) end)
			if ok and res and res[1] then model = res[1] end
			node.__kids[stem] = newNode({ __rbxm = P.wrap(model or roblox.Instance.new("Folder")),
				__kids = {}, Parent = node, Name = stem })
		end
	end
	return node
end

local loaded = {}
local function req(node)
	if typeof(node) ~= "table" then error("require of non-module: " .. tostring(node)) end
	local rbxm = rawget(node, "__rbxm")
	if rbxm then return rbxm end
	local file = rawget(node, "__file")
	if not file then error("require of a folder with no init: " .. tostring(rawget(node, "__dir"))) end
	if loaded[file] then return loaded[file] end
	local src = fs.readFile(REPO .. file)
	local env
	env = {
		Vector3 = roblox.Vector3, CFrame = CFshim, Color3 = roblox.Color3, Enum = roblox.Enum,
		Instance = P.Instance, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2,
		NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Rect = roblox.Rect,
		BrickColor = roblox.BrickColor, Ray = roblox.Ray, Region3 = roblox.Region3, Faces = roblox.Faces,
		TweenInfo = roblox.TweenInfo, PhysicalProperties = roblox.PhysicalProperties,
		script = node, require = req,
		math = math, table = table, string = string, os = os, coroutine = coroutine, utf8 = utf8,
		tostring = tostring, tonumber = tonumber, type = type, typeof = P.typeof, pairs = pairs,
		ipairs = ipairs, next = next, select = select, assert = assert, error = error,
		pcall = pcall, xpcall = xpcall, unpack = table.unpack, print = print,
		warn = function(...) print("[warn]", ...) end,
		setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
		rawequal = rawequal, rawlen = rawlen, tick = os.clock, time = os.time, task = TASK,
		workspace = WORKSPACE, game = GAME, Random = RandomShim, buffer = buffer, bit32 = bit32,
	}
	env._G = env
	local f = luau.load(src, { debugName = file, environment = env })
	local v = f()
	loaded[file] = v
	return v
end

-- --------------------------------------------------------------- game stubs
WORKSPACE = P.wrap(roblox.Instance.new("Folder"))
WORKSPACE.Name = "Workspace"

TASK = {
	wait = function() end, spawn = function(f, ...) return f(...) end,
	defer = function(f, ...) return f(...) end, delay = function(_, f, ...) return f(...) end,
}

local SHARED = buildTree("src/shared", nil)
local SERVER = buildTree("src/server", nil)
local RS = P.wrap(roblox.Instance.new("Folder")); RS.Name = "ReplicatedStorage"
local SS = P.wrap(roblox.Instance.new("Folder")); SS.Name = "ServerStorage"

local tagged = {}
local SERVICES = {
	ReplicatedStorage = setmetatable({ Shared = SHARED, inst = RS }, { __index = RS }),
	ServerStorage = SS,
	ServerScriptService = setmetatable({ Server = SERVER }, {}),
	CollectionService = {
		AddTag = function(_, inst, tag) tagged[tag] = (tagged[tag] or 0) + 1 end,
		RemoveTag = function() end, HasTag = function() return false end,
		GetTagged = function() return {} end,
	},
	RunService = { IsStudio = function() return false end, IsServer = function() return true end },
	Lighting = P.wrap(roblox.Instance.new("Folder")),
	TweenService = { Create = function() return { Play = function() end } end },
	Debris = { AddItem = function() end },
	Players = P.wrap(roblox.Instance.new("Folder")),
	SoundService = P.wrap(roblox.Instance.new("Folder")),
	PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end },
}
GAME = {
	GetService = function(_, name)
		local s = SERVICES[name]
		if not s then error("harness: unstubbed service " .. name) end
		return s
	end,
	Workspace = WORKSPACE,
}

-- ReplicatedStorage.Shared must resolve as a module node
setmetatable(SERVICES.ReplicatedStorage, { __index = function(_, k)
	if k == "Shared" then return SHARED end
	return rawget(RS, k)
end })

-- ------------------------------------------------------------------- build
-- Lune Models have no PivotTo; the only caller is the layout-B arena move,
-- which the linear layout replaces with an explicit position. Flip to A for
-- the baseline dump so the harness can run today's code unmodified.
local CFG = req(SHARED.Config)
-- layout kept as authored; PivotTo is shimmed

local MapBuilderNode = SERVER.Map.MapBuilder
local MapBuilder = req(MapBuilderNode)
local refs = MapBuilder.build()

-- CityService, not MapBuilder, stands the plots up; the lobby is mostly plots,
-- so build them here too at the CFrames the map handed back.
local PlotTemplate = req(SERVER.Map.PlotTemplate)
local plotFolder = P.wrap(roblox.Instance.new("Folder"))
plotFolder.Name = "Plots"
plotFolder.Parent = WORKSPACE
local built = 0
for index, cframe in refs.plots do
	local ok, plot = pcall(PlotTemplate.build, cframe, index)
	if ok then
		built += 1
		if typeof(plot) == "table" and plot.model then plot.model.Parent = plotFolder end
	else
		print("[harness] plot " .. tostring(index) .. " failed: " .. tostring(plot))
	end
end
print("plots built: " .. tostring(built))

-- ------------------------------------------------------------------- dump
-- A SpecialMesh reshapes the part it hangs off: the bay's shallow lagoons are
-- 66-stud cubes wearing a squashed sphere. Dump it so the renderer can too.
local function meshOf(c)
	for _, m in c:GetChildren() do
		if m.ClassName == "SpecialMesh" then
			local s = m.Scale
			return { kind = m.MeshType.Name, scale = { s.X, s.Y, s.Z } }
		end
	end
	return nil
end

local parts = {}
-- "Plots/Plot_1/PropSites/Shrub_3/PlaceholderArt": the parent's name alone
-- cannot tell one site's placeholder from another's.
local function ancestry(inst)
	local names = {}
	local node = inst.Parent
	while node and node ~= WORKSPACE do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end
local function walk(inst)
	for _, c in inst:GetChildren() do
		if c:IsA("BasePart") then
			local cf = c.CFrame
			local x, y, z = cf.Position.X, cf.Position.Y, cf.Position.Z
			local r = { cf.RightVector, cf.UpVector, -cf.LookVector }
			table.insert(parts, {
				name = c.Name,
				path = tostring(c.Parent and c.Parent.Name or "?"),
				full = ancestry(c),
				size = { c.Size.X, c.Size.Y, c.Size.Z },
				cf = { x, y, z,
					r[1].X, r[2].X, r[3].X,
					r[1].Y, r[2].Y, r[3].Y,
					r[1].Z, r[2].Z, r[3].Z },
				color = { math.floor(c.Color.R * 255 + 0.5), math.floor(c.Color.G * 255 + 0.5), math.floor(c.Color.B * 255 + 0.5) },
				material = c.Material.Name,
				transparency = c.Transparency,
				collide = c.CanCollide,
				shape = (c:IsA("Part") and c.Shape and c.Shape.Name) or (c.ClassName == "WedgePart" and "Wedge") or "Block",
				mesh = meshOf(c),
			})
		end
		walk(c)
	end
end
walk(WORKSPACE)
print(("parts dumped: %d   (MapBuilder reported %s)"):format(#parts, tostring(refs.partCount)))
fs.writeFile(OUT, serde.encode("json", parts))
