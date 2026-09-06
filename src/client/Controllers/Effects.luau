--!strict
-- Sounds and one-shot particle bursts. Everything is local: the server sends
-- "something happened here" and this decides what it looks and sounds like,
-- which keeps effects off the network and lets each player mute their own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)

local Effects = {}

local BURSTS: { [string]: { color: Color3, count: number, speed: number, size: number, texture: string? } } = {
	capture = { color = Color3.fromRGB(255, 220, 120), count = 26, speed = 22, size = 1.1 },
	deploy = { color = Color3.fromRGB(120, 230, 170), count = 16, speed = 14, size = 0.9 },
	collect = { color = Color3.fromRGB(255, 208, 72), count = 20, speed = 16, size = 0.8 },
	purchase = { color = Color3.fromRGB(255, 208, 72), count = 14, speed = 12, size = 0.7 },
	circuit = { color = Color3.fromRGB(120, 255, 200), count = 24, speed = 18, size = 1.0 },
	overdrive = { color = Color3.fromRGB(255, 120, 60), count = 34, speed = 26, size = 1.3 },
	relaunch = { color = Color3.fromRGB(140, 235, 255), count = 60, speed = 34, size = 1.6 },
	hit = { color = Color3.fromRGB(255, 110, 110), count = 18, speed = 20, size = 1.0 },
	pylon = { color = Color3.fromRGB(120, 235, 255), count = 22, speed = 18, size = 1.0 },
	store = { color = Color3.fromRGB(180, 190, 210), count = 10, speed = 10, size = 0.7 },
	sell = { color = Color3.fromRGB(255, 180, 120), count = 12, speed = 12, size = 0.7 },
}

local SOUND_FOR: { [string]: string } = {
	capture = "capture",
	deploy = "deploy",
	collect = "collect",
	purchase = "purchase",
	circuit = "circuit",
	overdrive = "overdrive",
	relaunch = "relaunch",
	hit = "hit",
	pylon = "circuit",
	store = "click",
	sell = "purchase",
}

local function settings()
	local snap = State.get()
	if snap then
		return snap.settings
	end
	return { music = 0.6, sfx = 0.8, reducedMotion = false, reducedFlashing = false, notifications = true }
end

function Effects.sound(name: string, position: Vector3?)
	local s = settings()
	if s.sfx <= 0 then
		return
	end
	local id = Config.Sounds.ids[name]
	if not id then
		return
	end
	local ok, err = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = (Config.Sounds.volume[name] or 0.5) * s.sfx
		sound.RollOffMaxDistance = 140
		if position then
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.Position = position
			anchor.Parent = workspace
			sound.Parent = anchor
			sound:Play()
			Debris:AddItem(anchor, 5)
		else
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 5)
		end
	end)
	if not ok then
		-- a missing built-in sound is never worth breaking the moment over
		local _ = err
	end
end

function Effects.burst(kind: string, position: Vector3, colorOverride: Color3?)
	local s = settings()
	local spec = BURSTS[kind]
	if not spec then
		return
	end
	local count = spec.count
	if s.reducedMotion then
		count = math.floor(count * 0.4)
	end
	if count <= 0 then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.texture or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colorOverride or spec.color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(spec.speed * 0.5, spec.speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = if s.reducedFlashing then 0.2 else 0.8
	emitter.Parent = anchor
	emitter:Emit(count)

	Debris:AddItem(anchor, 2)
end

function Effects.play(kind: string, position: Vector3, extra: any?)
	Effects.burst(kind, position, if typeof(extra) == "Color3" then extra else nil)
	local sound = SOUND_FOR[kind]
	if sound then
		Effects.sound(sound, position)
	end
end

function Effects.init()
	-- nothing to build; the module is driven entirely by remotes
end

return Effects
