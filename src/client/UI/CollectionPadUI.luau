--!strict
-- Local display only: server attributes confirm occupancy, timing and payment.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.Parent.State)
local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)

local M = {}
local built = false
local DURATION = 1 -- CollectionPadService's confirmed collection cycle

function M.init()
	if built then return end
	built = true
	local player = Players.LocalPlayer
	local gui = Instance.new("BillboardGui")
	gui.Name = "CollectionPadFeedback"
	gui.Size = UDim2.fromOffset(260, 104)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 45
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local card = W.frame({ parent = gui, size = UDim2.new(1, -6, 1, -6), position = UDim2.fromOffset(3, 3),
		color = Theme.colors.bg, radius = 12, stroke = Theme.colors.ink })
	local bank = W.label({ parent = card, name = "Bank", textSize = 20, font = Theme.fonts.bold,
		color = Theme.colors.coin, size = UDim2.new(1, -16, 0, 28), position = UDim2.fromOffset(8, 4),
		xalign = Enum.TextXAlignment.Center })
	local status = W.label({ parent = card, name = "Status", textSize = 16,
		size = UDim2.new(1, -16, 0, 28), position = UDim2.fromOffset(8, 33), xalign = Enum.TextXAlignment.Center })
	local progress = W.progress(card, UDim2.new(1, -20, 0, 22), Theme.colors.success, nil, UDim2.fromOffset(10, 67))
	progress.frame.Name = "Progress"
	local originalLabel: BillboardGui? = nil
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			local pad: BasePart? = nil
			local plots = workspace:FindFirstChild("Plots")
			for _, plot in if plots then plots:GetChildren() else {} do
				if plot:GetAttribute("OwnerUserId") == player.UserId then
					local candidate = plot:FindFirstChild("CollectPad")
					if candidate and candidate:IsA("BasePart") then pad = candidate end
					break
				end
			end
			local snap = State.get()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local near = pad ~= nil and root ~= nil and root:IsA("BasePart")
				and (root.Position - pad.Position).Magnitude <= 35 and snap ~= nil and not snap.visiting
			if originalLabel then originalLabel.Enabled = true end
			originalLabel = nil
			gui.Adornee = pad
			gui.Enabled = near == true
			if pad and gui.Enabled then
				local label = pad:FindFirstChild("Label")
				if label and label:IsA("BillboardGui") then
					originalLabel = label
					label.Enabled = false
				end
			end
			if snap then
				bank.Text = (if snap.bankFull then "BANK FULL: " else "Bank: ") .. Format.abbreviate(math.floor(snap.bank))
			end
		end
		if not gui.Enabled then return end
		local now = workspace:GetServerTimeNow()
		local phase = player:GetAttribute("CollectionStatus")
		local since = player:GetAttribute("CollectionStartedAt")
		local lastAt = player:GetAttribute("CollectionLastAt")
		local amount = player:GetAttribute("CollectionLastAmount")
		local paid = typeof(lastAt) == "number" and now - lastAt >= 0 and now - lastAt < 1.5
			and typeof(amount) == "number" and amount > 0
		status.TextColor3 = if paid then Theme.colors.coin else Theme.colors.text
		if paid then
			status.Text = "Collected +" .. Format.abbreviate(amount) .. " Coins"
		elseif phase == "Collecting" then
			status.Text = "Stay on the pad"
		elseif phase == "Waiting" then
			status.Text = "Waiting for Coins"
		else
			status.Text = "Stand here to collect"
		end
		if phase == "Collecting" and typeof(since) == "number" then
			local fraction = math.clamp((now - since) / DURATION, 0, 1)
			progress.set(fraction, if fraction >= 1 then "Finishing..." else "Collecting...")
		else
			progress.set(if paid then 1 else 0, if paid then "Collected!" else "Stand for 1 second")
		end
	end)
end

return M
