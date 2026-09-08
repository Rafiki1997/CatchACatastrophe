--!strict
-- Draws the aura every player is wearing, including other people's.
--
-- The server publishes the worn id as a Player attribute, so this needs no
-- remote of its own: it watches the attribute on every player, present and
-- future, and rebuilds the emitters when it changes or the character respawns.
--
-- Three things it is careful about, in order of importance:
--   * A capture must stay readable. Auras drop to a quarter rate while the
--     local player is tethering, so a hazard telegraph is never lost behind
--     someone's particles.
--   * The player's own settings win: reduced motion turns auras off entirely,
--     reduced flashing keeps them steady and slow.
--   * A full server is not a particle storm. Other people's auras thin out past
--     60 studs and stop past 220.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(ReplicatedStorage.Shared.Models.ModelKit)

local State = require(script.Parent.Parent.State)

local AuraController = {}

local Cosmetics = Config.Cosmetics
local RENDER = Cosmetics.render
local ATTRIBUTE = "Aura"
local FOLDER = "AuraFX"

local localPlayer = Players.LocalPlayer
local tracked: { [Player]: { id: string?, emitters: { ParticleEmitter }, root: BasePart? } } = {}
local capturing = false

local function clear(entry: any)
	for _, emitter in entry.emitters do
		emitter:Destroy()
	end
	entry.emitters = {}
	entry.root = nil
end

local function build(player: Player, entry: any)
	clear(entry)
	local id = entry.id
	local item = if id then Cosmetics.byId[id] else nil
	if not item then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	-- Emitters live in their own folder-less attachment on the root so nothing
	-- has to be cleaned up if the character is destroyed mid-frame.
	local attachment = root:FindFirstChild(FOLDER)
	if not attachment then
		local a = Instance.new("Attachment")
		a.Name = FOLDER
		a.Position = Vector3.new(0, -0.5, 0)
		a.Parent = root
		attachment = a
	end
	local emitter = Kit.particles(attachment :: any, item.preset, item.color)
	emitter.Name = "Aura_" .. item.id
	entry.emitters = { emitter }
	entry.root = root
	AuraController.refreshRates()
end

-- Rate depends on distance, the local capture, and the player's settings, so it
-- is recomputed rather than baked in when the emitter is made.
function AuraController.refreshRates()
	local snap = State.get()
	local reducedMotion = snap ~= nil and snap.settings.reducedMotion
	local reducedFlashing = snap ~= nil and snap.settings.reducedFlashing
	local ownRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	for player, entry in tracked do
		local item = if entry.id then Cosmetics.byId[entry.id] else nil
		for _, emitter in entry.emitters do
			if not item or reducedMotion then
				emitter.Enabled = false
			else
				local rate = item.rate
				if capturing then
					rate *= RENDER.captureRate
				end
				if reducedFlashing then
					rate *= 0.6
				end
				if player ~= localPlayer and entry.root and ownRoot and ownRoot:IsA("BasePart") then
					local distance = (entry.root.Position - ownRoot.Position).Magnitude
					if distance > RENDER.hideDistance then
						rate = 0
					elseif distance > RENDER.farDistance then
						rate *= RENDER.farRate
					end
				end
				emitter.Rate = rate
				emitter.Enabled = rate > 0
			end
		end
	end
end

local function watch(player: Player)
	local entry = { id = player:GetAttribute(ATTRIBUTE) :: string?, emitters = {}, root = nil }
	tracked[player] = entry
	build(player, entry)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		entry.id = player:GetAttribute(ATTRIBUTE) :: string?
		build(player, entry)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.4)
		if tracked[player] == entry then
			build(player, entry)
		end
	end)
	if player.Character then
		build(player, entry)
	end
end

function AuraController.setCapturing(active: boolean)
	if capturing ~= active then
		capturing = active
		AuraController.refreshRates()
	end
end

function AuraController.init()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local entry = tracked[player]
		if entry then
			clear(entry)
			tracked[player] = nil
		end
	end)
	State.onChanged(function()
		AuraController.refreshRates()
	end)
	-- distance is the only input that changes without an event
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.5 then
			elapsed = 0
			AuraController.refreshRates()
		end
	end)
end

return AuraController
