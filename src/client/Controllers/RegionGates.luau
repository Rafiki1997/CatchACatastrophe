--!strict
-- Region gates and their signs.
--
-- The gate is a per-player wall. Character physics is client-simulated, so
-- clearing CanCollide here opens the gate for this player only, without the
-- server needing a copy of the world per person.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)

local RegionGates = {}

local TAG = "RegionGate"
local player = Players.LocalPlayer
local forecast: { [string]: { nextLegendaryAt: number, surgeUntil: number } } = {}
local lastNudge = 0

local function signOf(gate: BasePart): { title: TextLabel?, cost: TextLabel?, forecast: TextLabel? }?
	local region = gate.Parent
	if not region then
		return nil
	end
	local sign = region:FindFirstChild("GateSign")
	local gui = sign and sign:FindFirstChild("Gui")
	if not gui then
		return nil
	end
	return {
		title = gui:FindFirstChild("Title") :: TextLabel?,
		cost = gui:FindFirstChild("Cost") :: TextLabel?,
		forecast = gui:FindFirstChild("Forecast") :: TextLabel?,
	}
end

local function applyGate(gate: BasePart, unlocked: boolean)
	gate.CanCollide = not unlocked
	gate.Transparency = if unlocked then 0.8 else 0.45
	local labels = signOf(gate)
	if labels and labels.cost then
		local regionId = gate:GetAttribute("RegionId")
		local def = if typeof(regionId) == "string" then Config.Regions.byId[regionId] else nil
		if unlocked then
			labels.cost.Text = "OPEN"
			labels.cost.TextColor3 = Color3.fromRGB(140, 240, 160)
		elseif def then
			labels.cost.Text = "Unlock: " .. Format.abbreviate(def.unlockCost) .. " Coins"
			labels.cost.TextColor3 = Color3.fromRGB(255, 232, 150)
		end
	end
end

local function refreshAll()
	local snap = State.get()
	for _, gate in CollectionService:GetTagged(TAG) do
		if gate:IsA("BasePart") then
			local regionId = gate:GetAttribute("RegionId")
			local unlocked = typeof(regionId) == "string" and snap ~= nil and snap.regions[regionId] == true
			applyGate(gate, unlocked)
		end
	end
end

local function refreshForecast()
	local now = workspace:GetServerTimeNow()
	for _, gate in CollectionService:GetTagged(TAG) do
		if gate:IsA("BasePart") then
			local regionId = gate:GetAttribute("RegionId")
			local entry = if typeof(regionId) == "string" then forecast[regionId] else nil
			local labels = signOf(gate)
			if labels and labels.forecast then
				if entry and now < entry.surgeUntil then
					labels.forecast.Text = "SURGE! Perfect catches can be Overcharged (" .. Format.clock(math.max(0, entry.surgeUntil - now)) .. ")"
					labels.forecast.TextColor3 = Color3.fromRGB(255, 220, 120)
				elseif entry then
					labels.forecast.Text = "Legendary forecast: " .. Format.clock(math.max(0, entry.nextLegendaryAt - now))
					labels.forecast.TextColor3 = Color3.fromRGB(200, 230, 255)
				else
					labels.forecast.Text = "Legendary forecast: --"
				end
			end
		end
	end
end

function RegionGates.setForecast(data: any)
	if typeof(data) ~= "table" then
		return
	end
	forecast = data
	refreshForecast()
end

function RegionGates.forecastFor(regionId: string)
	return forecast[regionId]
end

-- Bumping a closed gate should explain itself rather than just stopping you.
local function watchBumps(Notifications: any)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local snap = State.get()
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if snap and hrp and hrp:IsA("BasePart") and os.clock() - lastNudge > 5 then
				for _, gate in CollectionService:GetTagged(TAG) do
					if gate:IsA("BasePart") and gate.CanCollide then
						if (gate.Position - hrp.Position).Magnitude < 16 then
							local regionId = gate:GetAttribute("RegionId")
							local def = if typeof(regionId) == "string" then Config.Regions.byId[regionId] else nil
							if def and Notifications then
								lastNudge = os.clock()
								Notifications.push(
									"info",
									"Unlock " .. def.name .. " for " .. Format.abbreviate(def.unlockCost) .. " Coins in the Upgrade Workshop.",
									5
								)
							end
							break
						end
					end
				end
			end
		end
	end)
end

function RegionGates.init(Notifications: any?)
	refreshAll()
	State.onChanged(refreshAll)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(refreshAll)

	Net.on("Forecast", RegionGates.setForecast)

	task.spawn(function()
		while true do
			task.wait(1)
			refreshForecast()
		end
	end)

	watchBumps(Notifications)
end

return RegionGates
