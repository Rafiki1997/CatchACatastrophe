-- Transparent proxy over lune's roblox instances, adding the DOM methods lune
-- omits (PivotTo / GetPivot / GetBoundingBox / MoveTo). Every instance a module
-- can reach is a proxy, so property assignment always passes through __newindex
-- and gets unwrapped -- that consistency is what makes the shim invisible.
local roblox = require("@lune/roblox")
local P = {}
P.MISSING_DEFAULTS = {
	MeshId = "", TextureID = "", TextureId = "", MeshSize = roblox.Vector3.new(0, 0, 0),
	AssetId = "", ContentId = "",
}

local CF, V3 = roblox.CFrame, roblox.Vector3
local cache = setmetatable({}, { __mode = "kv" })
local isProxy = setmetatable({}, { __mode = "k" })

local wrap, unwrap

function unwrap(v)
	if type(v) == "table" and isProxy[v] then return rawget(v, "__r") end
	return v
end

local function unwrapAll(...)
	local n = select("#", ...)
	local out = table.create(n)
	for i = 1, n do out[i] = unwrap((select(i, ...))) end
	return table.unpack(out, 1, n)
end

local function wrapResult(v)
	if typeof(v) == "Instance" then return wrap(v) end
	if type(v) == "table" then
		local out = {}
		for k, item in v do out[k] = (typeof(item) == "Instance") and wrap(item) or item end
		return out
	end
	return v
end

-- --------------------------------------------------------------- pivot shims
local function descendantParts(real)
	local out = {}
	local function walk(i)
		for _, c in i:GetChildren() do
			if c:IsA("BasePart") then table.insert(out, c) end
			walk(c)
		end
	end
	if real:IsA("BasePart") then table.insert(out, real) end
	walk(real)
	return out
end

local function boundsCentre(real)
	local parts = descendantParts(real)
	if #parts == 0 then return CF.new() end
	local mn = V3.new(math.huge, math.huge, math.huge)
	local mx = V3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local cf, s = p.CFrame, p.Size
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local c = cf:PointToWorldSpace(V3.new(s.X * sx, s.Y * sy, s.Z * sz))
					mn = V3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z))
					mx = V3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z))
				end
			end
		end
	end
	return CF.new((mn + mx) / 2)
end

local function getPivot(real)
	if real:IsA("BasePart") then return real.CFrame end
	local ok, pp = pcall(function() return real.PrimaryPart end)
	if ok and pp then return pp.CFrame end
	return boundsCentre(real)
end

local SHIM = {}
function SHIM.GetPivot(real) return getPivot(real) end
function SHIM.PivotTo(real, cf)
	local delta = cf * getPivot(real):Inverse()
	for _, p in descendantParts(real) do p.CFrame = delta * p.CFrame end
end
function SHIM.MoveTo(real, pos) SHIM.PivotTo(real, CF.new(pos)) end
function SHIM.GetBoundingBox(real)
	local c = boundsCentre(real)
	local parts = descendantParts(real)
	local mn = V3.new(math.huge, math.huge, math.huge)
	local mx = V3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local cf, s = p.CFrame, p.Size
		for _, sx in { -0.5, 0.5 } do for _, sy in { -0.5, 0.5 } do for _, sz in { -0.5, 0.5 } do
			local q = cf:PointToWorldSpace(V3.new(s.X * sx, s.Y * sy, s.Z * sz))
			mn = V3.new(math.min(mn.X, q.X), math.min(mn.Y, q.Y), math.min(mn.Z, q.Z))
			mx = V3.new(math.max(mx.X, q.X), math.max(mx.Y, q.Y), math.max(mx.Z, q.Z))
		end end end
	end
	return c, (mx - mn)
end
function SHIM.SetPrimaryPartCFrame(real, cf) SHIM.PivotTo(real, cf) end

-- ------------------------------------------------------------------- proxy
local meta = {
	__index = function(t, k)
		local real = rawget(t, "__r")
		local shim = SHIM[k]
		if shim then
			return function(_, ...) return shim(real, ...) end
		end
		local ok, v = pcall(function() return real[k] end)
		if not ok then
			-- lune has no defaults for a few properties an .rbxm may omit. The
			-- prop modules read these to decide whether a native mesh library is
			-- complete; a benign empty value makes them take their documented
			-- "library incomplete -> keep placeholders" path instead of erroring.
			local msg = tostring(v)
			if msg:find("missing default value") then
				local D = P.MISSING_DEFAULTS[k]
				if D ~= nil then return D end
				return nil
			end
			error(msg, 2)
		end
		if type(v) == "function" then
			return function(_, ...) return wrapResult(v(real, unwrapAll(...))) end
		end
		return wrapResult(v)
	end,
	__newindex = function(t, k, v)
		rawget(t, "__r")[k] = unwrap(v)
	end,
	__tostring = function(t) return tostring(rawget(t, "__r")) end,
	__eq = function(a, b) return unwrap(a) == unwrap(b) end,
}

function wrap(real)
	if real == nil then return nil end
	local got = cache[real]
	if got then return got end
	local p = setmetatable({ __r = real }, meta)
	cache[real] = p
	isProxy[p] = true
	return p
end

P.wrap, P.unwrap, P.isProxy = wrap, unwrap, isProxy
P.Instance = {
	new = function(cls, parent) return wrap(roblox.Instance.new(cls, unwrap(parent))) end,
}
function P.typeof(v)
	if type(v) == "table" and isProxy[v] then return "Instance" end
	return typeof(v)
end
return P
