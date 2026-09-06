--!strict
-- Client-side remote wrapper. Use this instead of touching RemoteEvents.
--   Net.fire("CollectAll")
--   Net.on("Notify", function(kind, text, duration) end)
--   local snap = Net.invoke("GetState")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

local remotes = Remotes.get()

function Net.fire(name: string, ...: any)
	local ev = remotes.Event[name]
	if not ev then
		warn("[Net] unknown remote", name)
		return
	end
	ev:FireServer(...)
end

function Net.on(name: string, callback: (...any) -> ()): RBXScriptConnection
	local ev = remotes.Event[name]
	assert(ev, "unknown remote " .. name)
	return ev.OnClientEvent:Connect(callback)
end

function Net.invoke(name: string, ...: any): ...any
	local fn = remotes.Function[name]
	assert(fn, "unknown remote function " .. name)
	return fn:InvokeServer(...)
end

return Net
