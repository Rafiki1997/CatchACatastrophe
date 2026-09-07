--!strict
-- Which code is running. Reads the generated ReplicatedStorage.Shared.Build
-- module (written by tools/stamp.py, gitignored) and falls back to
-- "unstamped" when it is missing, so a fresh clone still boots.

export type Build = {
	hash: string,
	commitTime: string,
	dirty: boolean,
	stampedAt: string,
}

local BuildInfo = {}

local FALLBACK: Build = { hash = "unstamped", commitTime = "", dirty = false, stampedAt = "" }
local cached: Build? = nil

function BuildInfo.get(): Build
	if cached then
		return cached
	end
	local shared = script.Parent and script.Parent.Parent
	local module = if shared then shared:FindFirstChild("Build") else nil
	local info: Build = FALLBACK
	if module and module:IsA("ModuleScript") then
		local ok, value = pcall(require, module)
		if ok and typeof(value) == "table" and typeof(value.hash) == "string" then
			info = {
				hash = value.hash,
				commitTime = if typeof(value.commitTime) == "string" then value.commitTime else "",
				dirty = value.dirty == true,
				stampedAt = if typeof(value.stampedAt) == "string" then value.stampedAt else "",
			}
		end
	end
	cached = info
	return info
end

-- "a1b2c3d* 21:20" : hash, a star when uncommitted changes were included, the
-- stamp time without the date. For the HUD pill.
function BuildInfo.short(info: Build?): string
	local b = info or BuildInfo.get()
	local clock = b.stampedAt:match("(%d%d:%d%d)$") or ""
	local text = b.hash .. (if b.dirty then "*" else "")
	if clock ~= "" then
		text = text .. " " .. clock
	end
	return text
end

-- "Build a1b2c3d (uncommitted changes), stamped 2026-09-07 21:20" : for Settings and the server log.
function BuildInfo.long(info: Build?): string
	local b = info or BuildInfo.get()
	local text = "Build " .. b.hash
	if b.dirty then
		text = text .. " (uncommitted changes)"
	end
	if b.stampedAt ~= "" then
		text = text .. ", stamped " .. b.stampedAt
	end
	return text
end

return BuildInfo
