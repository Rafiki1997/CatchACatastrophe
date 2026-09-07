--!strict
-- Opt-in Studio integration tests, restricted to the in-memory save adapter.
-- A real client issues StartCapture; normal server heartbeat code resolves and
-- grants captures. Only avatar placement and encounter roaming are controlled.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)
local Harness = {}

local function copy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in value do
		result[k] = copy(v)
	end
	return result
end

function Harness.install()
	if not RunService:IsStudio() then
		return
	end
	local state = Instance.new("Folder")
	state.Name = "CaptureHazardTests"
	state.Parent = workspace
	local running = false
	state:GetAttributeChangedSignal("Request"):Connect(function()
		if running then
			return
		end
		local player = Players:GetPlayers()[1]
		local profile = player and Profiles.get(player)
		if not profile or not profile.loaded or not profile.testAdapter or profile.capture then
			state:SetAttribute("Status", "Requires an idle player using the Studio in-memory adapter")
			return
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return
		end
		running = true
		state:SetAttribute("Status", "running")
		state:SetAttribute("Results", "[]")
		local savedData = copy(profile.data)
		local savedCF, savedAnchored = hrp.CFrame, hrp.Anchored
		local standingOffset = hrp.Position.Y - S.Capture.feetY(hrp)
		local frozen = {}
		local results = {}
		local ok, err = pcall(function()
			hrp.Anchored = true
			profile.data.upgrades.tether_speed = 0
			profile.data.upgrades.tether_range = 0
			for _, region in Config.Regions.list do
				profile.data.regions[region.id] = true
			end
			local function move(pos: Vector3, jumping: boolean?)
				hrp.CFrame = CFrame.new(pos.X, pos.Y + standingOffset + (if jumping then 5 else 0.3), pos.Z)
			end
			local function choose(element: string)
				local best = nil
				for _, model in CollectionService:GetTagged("Wild") do
					local uid = model:GetAttribute("EncounterUid")
					local e = if typeof(uid) == "string" then S.Encounters.get(uid) else nil
					if e and e.element == element and not e.claimedBy and (not best or Config.Rarities.rank(e.rarity) < Config.Rarities.rank(best.rarity)) then
						best = e
					end
				end
				assert(best, "No available encounter for " .. element)
				return best
			end
			local function safePosition(cap: any, origin: Vector3): Vector3
				for i = 0, 35 do
					local a = i * math.pi / 18
					local candidate = origin + Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 16)
					local safe = true
					for _, entry in cap.hazards do
						local ev = entry.event
						if ev.activeEndsAt >= workspace:GetServerTimeNow() then
							for j = 0, 8 do
								local t = ev.telegraphEndsAt + (ev.activeEndsAt - ev.telegraphEndsAt) * j / 8
								if S.Capture.hazardHits(ev, candidate, t, origin.Y + 0.3) then
									safe = false
								end
							end
						end
					end
					if safe then
						return candidate
					end
				end
				error("No safe capture position")
			end
			for _, element in { "Water", "Heat", "Frost", "Storm", "Cosmic" } do
				for _, mode in { "hit", "dodge" } do
					state:SetAttribute("Stage", element .. " / " .. mode)
					local e = choose(element)
					local region = Config.Regions.byElement[element]
					local origin = workspace.Regions[region.id]:GetAttribute("Centre")
					table.insert(frozen, { e = e, cf = e.model:GetPivot(), from = e.model:GetAttribute("PathFrom"), to = e.model:GetAttribute("PathTo"), start = e.model:GetAttribute("PathStart"), duration = e.model:GetAttribute("PathDuration"), legEndsAt = e.legEndsAt })
					e.model:PivotTo(CFrame.new(origin))
					e.model:SetAttribute("PathFrom", origin)
					e.model:SetAttribute("PathTo", origin)
					e.model:SetAttribute("PathStart", workspace:GetServerTimeNow())
					e.model:SetAttribute("PathDuration", 300)
					e.legEndsAt = workspace:GetServerTimeNow() + 300
					move(origin + Vector3.new(8, 0, 0))
					state:SetAttribute("EncounterUid", e.uid)
					local deadline = os.clock() + 5
					repeat task.wait(0.05) until profile.capture or os.clock() > deadline
					assert(profile.capture and profile.capture.uid == e.uid, "Client did not start capture")
					local cap = profile.capture
					local initialCaptures = profile.data.stats.captures
					local initialPerfect = profile.data.stats.perfect
					local health = player.Character:FindFirstChildOfClass("Humanoid").Health
					local first = nil
					local beforeHit = 0
					local sawWarning, sawPenalty, sawHit = false, false, false
					deadline = os.clock() + 44
					while profile.capture and os.clock() < deadline do
						local now = workspace:GetServerTimeNow()
						first = first or (cap.hazards[1] and cap.hazards[1].event)
						if first and now < first.telegraphEndsAt then
							assert(cap.hits == 0, "Hit during warning")
							sawWarning = true
							beforeHit = cap.progress
						end
						if mode == "hit" and first and now <= first.activeEndsAt then
							local u = math.clamp((now - first.telegraphEndsAt) / (first.activeEndsAt - first.telegraphEndsAt), 0, 1)
							local target = first.positions[1] or first.origin
							if first.shape == "ring" then target = first.origin + Vector3.new(first.travel * u, 0, 0) end
							if first.shape == "line" then target = first.origin + first.direction * first.travel * u end
							move(target)
							if cap.hits > 0 and not sawHit then
								sawHit = true
								sawPenalty = cap.progress < beforeHit - 1 and not cap.perfect and cap.stunUntil > now
							end
							assert(cap.hits <= 1, "Same hazard hit more than once")
						elseif element == "Water" then
							-- Elevated avatar verifies the real R6/R15 feet calculation.
							move(origin + Vector3.new(8, 0, 0), true)
						else
							move(safePosition(cap, origin))
						end
						task.wait(0.025)
					end
					assert(not profile.capture, "Capture timed out")
					assert(sawWarning, "No telegraph observed")
					assert(profile.data.stats.captures == initialCaptures + 1, "No capture grant")
					if mode == "hit" then
						assert(sawHit and sawPenalty and cap.hits == 1, "Expected one hit, penalty, and stun")
						assert(profile.data.stats.perfect == initialPerfect, "Hit capture awarded perfect")
					else
						assert(cap.hits == 0 and cap.perfect, "Dodge lost perfect capture")
						assert(profile.data.stats.perfect == initialPerfect + 1, "Perfect capture not recorded")
					end
					assert(player.Character:FindFirstChildOfClass("Humanoid").Health == health, "Capture hazard damaged health")
					assert(not S.Encounters.get(e.uid), "Captured encounter not consumed")
					table.insert(results, { element = element, mode = mode, hits = cap.hits, perfect = cap.perfect, passed = true })
					state:SetAttribute("Results", HttpService:JSONEncode(results))
					print("[HazardTest] " .. element .. " " .. mode .. " passed")
					task.wait(0.4)
				end
			end
		end)
		S.Capture.cancel(profile)
		profile.data = savedData
		profile.dirty = true
		for _, row in frozen do
			if row.e.model.Parent then
				row.e.model:PivotTo(row.cf)
				row.e.model:SetAttribute("PathFrom", row.from)
				row.e.model:SetAttribute("PathTo", row.to)
				row.e.model:SetAttribute("PathStart", row.start)
				row.e.model:SetAttribute("PathDuration", row.duration)
				row.e.legEndsAt = row.legEndsAt
			end
		end
		hrp.CFrame = savedCF
		hrp.Anchored = savedAnchored
		hrp.AssemblyLinearVelocity = Vector3.zero
		state:SetAttribute("EncounterUid", nil)
		state:SetAttribute("Status", if ok then "passed" else "failed: " .. tostring(err))
		state:SetAttribute("Passed", #results)
		if not ok then warn("[HazardTest] " .. tostring(err)) end
		running = false
	end)
end

return Harness
