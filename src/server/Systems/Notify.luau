--!strict
-- Thin wrappers over the server -> client remotes so systems never touch
-- RemoteEvents directly. Every function is safe to call for a player who
-- has already left (it checks Parent).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

local R = Remotes.get()

local function alive(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil
end

-- kind: info | success | warn | error | event | capture
function Notify.player(player: Player, kind: string, text: string, duration: number?)
	if alive(player) then
		R.Event.Notify:FireClient(player, kind, text, duration)
	end
end

function Notify.broadcast(text: string, color: Color3?)
	R.Event.Broadcast:FireAllClients(text, color)
end

function Notify.all(kind: string, text: string, duration: number?)
	R.Event.Notify:FireAllClients(kind, text, duration)
end

function Notify.floating(player: Player, text: string, worldPos: Vector3, color: Color3?)
	if alive(player) then
		R.Event.FloatingText:FireClient(player, text, worldPos, color)
	end
end

-- kind: capture | deploy | collect | circuit | overdrive | relaunch | hit | purchase | pylon | store | sell
function Notify.effect(kind: string, worldPos: Vector3, extra: any?)
	R.Event.Effect:FireAllClients(kind, worldPos, extra)
end

function Notify.effectFor(player: Player, kind: string, worldPos: Vector3, extra: any?)
	if alive(player) then
		R.Event.Effect:FireClient(player, kind, worldPos, extra)
	end
end

function Notify.tutorial(player: Player, step: number, done: boolean)
	if alive(player) then
		R.Event.TutorialStep:FireClient(player, step, done)
	end
end

-- state: Types.CaptureState | nil (nil = capture ended)
function Notify.captureState(player: Player, state: any?)
	if alive(player) then
		R.Event.CaptureState:FireClient(player, state)
	end
end

-- players: a list of players to receive the telegraph, or nil for everyone
function Notify.hazard(players: { Player }?, hazard: any)
	if players then
		for _, p in players do
			if alive(p) then
				R.Event.Hazard:FireClient(p, hazard)
			end
		end
	else
		R.Event.Hazard:FireAllClients(hazard)
	end
end

function Notify.knockback(player: Player, direction: Vector3, strength: number)
	if alive(player) then
		R.Event.Knockback:FireClient(player, direction, strength)
	end
end

-- result: { speciesId, variant, perfect, uid }
function Notify.captureResult(player: Player, result: any)
	if alive(player) then
		R.Event.CaptureResult:FireClient(player, result)
	end
end

-- forecast: { [regionId] = { nextLegendaryAt, surgeUntil } }; player nil = everyone
function Notify.forecast(player: Player?, forecast: any)
	if player then
		if alive(player) then
			R.Event.Forecast:FireClient(player, forecast)
		end
	else
		R.Event.Forecast:FireAllClients(forecast)
	end
end

-- state: Types.CrisisState | nil; player nil = everyone
function Notify.crisis(player: Player?, state: any?)
	if player then
		if alive(player) then
			R.Event.CrisisState:FireClient(player, state)
		end
	else
		R.Event.CrisisState:FireAllClients(state)
	end
end

function Notify.leaderboard(boards: any)
	R.Event.Leaderboard:FireAllClients(boards)
end

function Notify.nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	return if p then p.DisplayName else "Someone"
end

return Notify
