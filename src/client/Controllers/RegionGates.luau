--!strict
-- Region gates and their signs.
--
-- The gate is a per-player wall. Character physics is client-simulated, so
-- clearing CanCollide here opens the gate for this player only, without the
-- server needing a copy of the world per person.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)

local RegionGates = {}

local TAG = "RegionGate"
local PROMPT = "UnlockPrompt"
-- The nudge must outlast its own toast or it re-arms the moment it fades.
local NUDGE_SECONDS = 4
local NUDGE_COOLDOWN = 15
local player = Players.LocalPlayer
local forecast: { [string]: { nextLegendaryAt: number, surgeUntil: number } } = {}
local lastNudge = 0
local widgets: any = nil
local confirmGui: ScreenGui? = nil
local LOCKED_TRANSPARENCY = 0.45
local wasOpen: { [BasePart]: boolean } = {}

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

-- An open gate is gone, not dimmed: the pane fades out the moment the region
-- unlocks and stays invisible, leaving the posts and lintel as an archway.
-- Walking through a faint glowing wall read as "still blocked".
local function applyGate(gate: BasePart, unlocked: boolean)
	gate.CanCollide = not unlocked
	local before = wasOpen[gate]
	wasOpen[gate] = unlocked
	if unlocked then
		if before == false then
			-- this player just opened it: let them watch it dissolve
			TweenService:Create(gate, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		else
			gate.Transparency = 1
		end
	else
		gate.Transparency = LOCKED_TRANSPARENCY
	end
	local prompt = gate:FindFirstChild(PROMPT)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not unlocked
	end
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

-- The gate is where the tutorial sends you, so the gate has to be able to open.
-- This only asks; WorkshopService.unlockRegion charges and refuses.
local function askToUnlock(gate: BasePart)
	if not widgets then
		return
	end
	local regionId = gate:GetAttribute("RegionId")
	local def = if typeof(regionId) == "string" then Config.Regions.byId[regionId] else nil
	if not def then
		return
	end
	local snap = State.get()
	if snap and snap.regions[def.id] then
		return
	end
	if not confirmGui then
		confirmGui = widgets.screenGui("GateUnlock", 60)
		widgets.attachScale(confirmGui)
	end
	local coins = if snap then snap.coins else 0
	local short = coins < def.unlockCost
	local body = def.desc
		.. "\n\nCost: "
		.. Format.abbreviate(def.unlockCost)
		.. " Coins    You have: "
		.. Format.abbreviate(coins)
	if short then
		body = body .. "\n\nYou cannot afford this yet."
	end
	widgets.confirm(confirmGui, "Open " .. def.name .. "?", body, "Unlock", function()
		Net.fire("UnlockRegion", def.id)
	end)
end

local function watchPrompts()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= PROMPT then
			return
		end
		local gate = prompt.Parent
		if gate and gate:IsA("BasePart") and CollectionService:HasTag(gate, TAG) then
			askToUnlock(gate)
		end
	end)
end

-- Bumping a closed gate should explain itself rather than just stopping you.
local function watchBumps(Notifications: any)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local snap = State.get()
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if snap and hrp and hrp:IsA("BasePart") and os.clock() - lastNudge > NUDGE_COOLDOWN then
				for _, gate in CollectionService:GetTagged(TAG) do
					if gate:IsA("BasePart") and gate.CanCollide then
						if (gate.Position - hrp.Position).Magnitude < 16 then
							local regionId = gate:GetAttribute("RegionId")
							local def = if typeof(regionId) == "string" then Config.Regions.byId[regionId] else nil
							if def and Notifications then
								lastNudge = os.clock()
								Notifications.push(
									"info",
									"Hold E at the gate to open " .. def.name .. " for " .. Format.abbreviate(def.unlockCost) .. " Coins.",
									NUDGE_SECONDS
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

function RegionGates.init(Notifications: any?, W: any?)
	widgets = W
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

	watchPrompts()
	watchBumps(Notifications)
end

return RegionGates
