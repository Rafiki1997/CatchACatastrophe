--!strict
-- Holds the latest Snapshot from the server and notifies listeners.
--   local snap = State.get()          -- may be nil before the first sync
--   State.onChanged(function(snap) end)
--   State.now()                       -- server time, compare with *At / *Until fields

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
type Snapshot = Types.Snapshot

local State = {}

local current: Snapshot? = nil
local listeners: { (Snapshot) -> () } = {}

function State.get(): Snapshot?
	return current
end

function State.set(snapshot: Snapshot)
	current = snapshot
	for _, cb in listeners do
		task.spawn(cb, snapshot)
	end
end

function State.onChanged(callback: (Snapshot) -> ()): () -> ()
	table.insert(listeners, callback)
	if current then
		task.spawn(callback, current)
	end
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function State.now(): number
	return workspace:GetServerTimeNow()
end

-- Seconds until a server timestamp (0 when passed).
function State.until_(serverTime: number): number
	return math.max(0, serverTime - State.now())
end

return State
