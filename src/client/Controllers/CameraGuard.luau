--!strict
-- The game never scripts the camera. If anything leaves it detached from the
-- character (a Studio tool that parks it for a screenshot, a plugin, a replaced
-- Camera instance), hand it back within a second. A tool that wants the camera
-- for a moment sets the ScriptedCamera attribute on the Camera and the guard
-- stands down until it is cleared.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraGuard = {}

local player = Players.LocalPlayer

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function guard()
	local cam = workspace.CurrentCamera
	if not cam or cam:GetAttribute("ScriptedCamera") then
		return
	end
	local hum = humanoid()
	if not hum or hum.Health <= 0 then
		return
	end
	if cam.CameraType ~= Enum.CameraType.Custom then
		cam.CameraType = Enum.CameraType.Custom
	end
	if cam.CameraSubject ~= hum then
		cam.CameraSubject = hum
	end
end

function CameraGuard.init()
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		guard()
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		task.defer(guard)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			guard()
		end
	end)
end

return CameraGuard
