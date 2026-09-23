-- Run through the Studio bridge in the Client datamodel during Play:
--   python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client
--   python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client --prepend "AUDIT_SCALE = 0.7"
-- Audits the live UI against the kid-friendly restyle contract and prints one
-- "[UIAudit] {json}" line. It opens each panel in turn by toggling its frame
-- (it cannot reach the game's own Widgets module state), then restores what
-- was visible. With AUDIT_SCALE set, every ScreenGui's UIScale is forced to
-- that value for the run (0.7 is the phone floor in Widgets.attachScale) and
-- restored afterwards. Outside the Rojo tree; never ships.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local scale = (getfenv().AUDIT_SCALE :: number?) or 1

-- same rule as Widgets.outline: light text must carry the dark outline
local function isLight(c: Color3): boolean
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B > 0.3
end

local function rgb(c: Color3)
	return { math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255) }
end

local function shown(inst: Instance): boolean
	local node: Instance? = inst
	while node and not node:IsA("ScreenGui") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and (node :: ScreenGui).Enabled
end

local report = {
	scale = scale,
	counts = { text = 0, outlined = 0, fits = 0 },
	failures = {},
	panels = {},
	sidebar = { grid = false, tiles = 0, columns = 0 },
}

local function fail(kind: string, inst: Instance, detail: string)
	table.insert(report.failures, { kind = kind, path = inst:GetFullName(), detail = detail })
end

local seen: { [Instance]: boolean } = {}
local function auditText(root: Instance)
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shown(d) and not seen[d] then
			seen[d] = true
			report.counts.text += 1
			if isLight(d.TextColor3) then
				local outline = d:FindFirstChild("TextOutline")
				if outline and outline:IsA("UIStroke") and outline.Enabled and outline.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
					report.counts.outlined += 1
				else
					fail("no-outline", d, d.Text)
				end
			end
			if d.TextScaled or d.TextFits then
				report.counts.fits += 1
			else
				fail("text-overflow", d, d.Text)
			end
		end
	end
end

-- force the audit scale
local scales: { [UIScale]: number } = {}
for _, gui in playerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		local s = gui:FindFirstChildOfClass("UIScale")
		if s then
			scales[s] = s.Scale
			s.Scale = scale
		end
	end
end
task.wait(0.2)

local hud = playerGui:FindFirstChild("CatchHUD")
if hud then
	auditText(hud)
	local sidebar = hud:FindFirstChild("Sidebar", true)
	if sidebar then
		report.sidebar.grid = sidebar:FindFirstChildOfClass("UIGridLayout") ~= nil
		local xs: { [number]: boolean } = {}
		for _, child in sidebar:GetChildren() do
			if child:IsA("GuiButton") and child.Visible then
				report.sidebar.tiles += 1
				xs[math.round(child.AbsolutePosition.X)] = true
			end
		end
		for _ in xs do
			report.sidebar.columns += 1
		end
	else
		table.insert(report.failures, { kind = "no-sidebar", path = "CatchHUD", detail = "" })
	end
end

-- every panel window: a Frame named "<Name>Panel" with a Header child
local panels: { Frame } = {}
for _, gui in playerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		for _, f in gui:GetChildren() do
			if f:IsA("Frame") and string.match(f.Name, "Panel$") and f:FindFirstChild("Header") then
				table.insert(panels, f)
			end
		end
	end
end
local wasVisible: { [Frame]: boolean } = {}
for _, p in panels do
	wasVisible[p] = p.Visible
	p.Visible = false
end
for _, p in panels do
	p.Visible = true
	task.wait(0.25)
	auditText(p)
	local name = string.gsub(p.Name, "Panel$", "")
	local header = p:FindFirstChild("Header") :: Frame
	local parent = p.Parent :: Instance
	report.panels[name] = {
		header = rgb(header.BackgroundColor3),
		body = rgb(p.BackgroundColor3),
		shadow = parent:FindFirstChild(p.Name .. "Shadow") ~= nil,
	}
	p.Visible = false
end
for p, v in wasVisible do
	p.Visible = v
end
for s, v in scales do
	s.Scale = v
end

print("[UIAudit] " .. HttpService:JSONEncode(report))
