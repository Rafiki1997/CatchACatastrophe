-- Run in the Studio Client datamodel before requesting the server hazard suite.
local R = game.ReplicatedStorage.Remotes
local state = workspace:WaitForChild("CaptureHazardTests")
local old = game.Players.LocalPlayer.PlayerGui:FindFirstChild("HazardTestObserver")
assert(not old, "Observer already installed")
local observer = Instance.new("Folder")
observer.Name = "HazardTestObserver"
observer.Parent = game.Players.LocalPlayer.PlayerGui
local HttpService = game:GetService("HttpService")
local rows = {}
local results = 0
local connections = {}
table.insert(connections, state:GetAttributeChangedSignal("EncounterUid"):Connect(function()
	local uid = state:GetAttribute("EncounterUid")
	if uid then
		R.StartCapture:FireServer(uid)
	end
end))
table.insert(connections, R.CaptureResult.OnClientEvent:Connect(function()
	results += 1
	observer:SetAttribute("CaptureResults", results)
end))
table.insert(connections, R.Hazard.OnClientEvent:Connect(function(ev)
	if state:GetAttribute("Status") ~= "running" then
		return
	end
	task.delay(0.1, function()
		local parts = 0
		for _, p in workspace.ClientFX:GetChildren() do
			if p:GetAttribute("HazardId") == ev.id then
				parts += 1
			end
		end
		local warning = ""
		for _, obj in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
			if obj.Name == "HazardWarning" and obj:IsA("TextLabel") then warning = obj.Text end
		end
		local row = { id = ev.id, element = ev.element, shape = ev.shape, parts = parts, warning = warning }
		table.insert(rows, row)
		observer:SetAttribute("Events", HttpService:JSONEncode(rows))
		task.delay(math.max(0, ev.activeEndsAt - workspace:GetServerTimeNow()) + 0.7, function()
			local remaining = 0
			for _, p in workspace.ClientFX:GetChildren() do
				if p:GetAttribute("HazardId") == ev.id then remaining += 1 end
			end
			row.remaining = remaining
			observer:SetAttribute("Events", HttpService:JSONEncode(rows))
		end)
	end)
end))
table.insert(connections, observer.Destroying:Connect(function()
	for _, c in connections do c:Disconnect() end
end))
return "Observer ready"
