-- Run through the Studio bridge in the Client datamodel during Play:
--   python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client
--   python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client --prepend "AUDIT_SCALE = 0.7"
--   python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client --prepend "AUDIT_PHONE = { width = 844, height = 390 }"
-- Audits the live UI against the kid-friendly restyle contract and prints one
-- "[UIAudit] {json}" line. Text checks run over the visible content of every
-- ScreenGui in PlayerGui (hidden overlays are not forced open), then over each
-- panel, which it opens in turn by toggling its frame (it cannot reach the
-- game's own Widgets module state), restoring what was visible afterwards.
-- With AUDIT_SCALE set, every ScreenGui's UIScale is forced to that value for
-- the run (0.7 is the phone floor in Widgets.attachScale) and restored.
--
-- AUDIT_PHONE simulates a phone viewport on the desktop window, since the
-- Device Emulator cannot be driven from here. The scale is the one
-- Widgets.attachScale would pick for that viewport, and the design space is
-- (width / scale, height / scale). Every SafeArea is resized to that space,
-- and each panel's scale-relative size and position are resolved against it,
-- so layouts land as they would on the phone. Any visible element whose
-- design-space bounds leave the space is a "phone-offscreen" failure; a
-- clipping frame (a ScrollingFrame such as the Sidebar) is checked as a whole
-- and not below, and neither are the children of an element that already
-- failed. The phone's top bar and notch insets are not modelled.
-- Outside the Rojo tree; never ships.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

type Phone = { width: number, height: number }
local phone = getfenv().AUDIT_PHONE :: Phone?
local scale = if phone
	then math.clamp(math.min(phone.width / 1280, phone.height / 720), 0.7, 1.1)
	else (getfenv().AUDIT_SCALE :: number?) or 1
local design = if phone then Vector2.new(phone.width / scale, phone.height / scale) else nil

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

-- the surface the text is drawn on: the nearest mostly opaque background
local function backdrop(inst: Instance): GuiObject?
	local node: Instance? = inst
	while node and not node:IsA("ScreenGui") do
		if node:IsA("GuiObject") and node.BackgroundTransparency < 0.5 then
			return node
		end
		node = node.Parent
	end
	return nil
end

local report = {
	scale = scale,
	phone = if phone and design
		then { width = phone.width, height = phone.height, design = { math.round(design.X), math.round(design.Y) } }
		else nil,
	counts = { text = 0, outlined = 0, fits = 0, dark = 0 },
	failures = {},
	panels = {},
	sidebar = { grid = false, tiles = 0, columns = 0 },
	guis = {},
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
			else
				report.counts.dark += 1
				local bg = backdrop(d)
				if bg and not isLight(bg.BackgroundColor3) then
					fail("dark-on-dark", d, ("%s | text %s on %s %s"):format(
						d.Text,
						HttpService:JSONEncode(rgb(d.TextColor3)),
						bg.Name,
						HttpService:JSONEncode(rgb(bg.BackgroundColor3))
					))
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

-- phone mode: flag anything visible that leaves the design space. `origin` is
-- the on-screen top-left of that space.
local function checkBounds(inst: Instance, origin: Vector2)
	if not design then
		return
	end
	if inst:IsA("GuiObject") then
		if not inst.Visible then
			return
		end
		local size = inst.AbsoluteSize / scale
		if size.X > 0 and size.Y > 0 then
			local min = (inst.AbsolutePosition - origin) / scale
			local max = min + size
			if min.X < -1 or min.Y < -1 or max.X > design.X + 1 or max.Y > design.Y + 1 then
				fail("phone-offscreen", inst, ("x %d..%d, y %d..%d in %dx%d"):format(
					math.round(min.X),
					math.round(max.X),
					math.round(min.Y),
					math.round(max.Y),
					math.round(design.X),
					math.round(design.Y)
				))
				return
			end
		end
		if inst.ClipsDescendants then
			return
		end
	end
	for _, child in inst:GetChildren() do
		checkBounds(child, origin)
	end
end

local guis: { ScreenGui } = {}
for _, gui in playerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		table.insert(guis, gui)
	end
end

-- force the audit scale
local scales: { [UIScale]: number } = {}
for _, gui in guis do
	local s = gui:FindFirstChildOfClass("UIScale")
	if s then
		scales[s] = s.Scale
		s.Scale = scale
	end
end

-- phone mode: every SafeArea becomes the phone's design space
local safeAreas: { [Frame]: { size: UDim2, position: UDim2 } } = {}
if design then
	for _, gui in guis do
		local safe = gui:FindFirstChild("SafeArea")
		if safe and safe:IsA("Frame") then
			safeAreas[safe] = { size = safe.Size, position = safe.Position }
			safe.Size = UDim2.fromOffset(design.X, design.Y)
			safe.Position = UDim2.new()
		end
	end
end
task.wait(0.3)

-- per-gui and per-panel text counts show where counts.text comes from; the
-- panels fill in as live data arrives, so totals drift between runs
for _, gui in guis do
	local before = report.counts.text
	auditText(gui)
	report.guis[gui.Name] = report.counts.text - before
end

local hud = playerGui:FindFirstChild("CatchHUD")
if hud then
	local sidebar = hud:FindFirstChild("Sidebar", true)
	if sidebar and sidebar:IsA("ScrollingFrame") then
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
		if design then
			report.sidebar.phoneScrolls = sidebar.AbsoluteCanvasSize.Y > sidebar.AbsoluteWindowSize.Y + 1
			report.sidebar.phoneHeight = math.round(sidebar.AbsoluteSize.Y / scale)
			report.sidebar.phoneCanvas = math.round(sidebar.AbsoluteCanvasSize.Y / scale)
		end
	else
		table.insert(report.failures, { kind = "no-sidebar", path = "CatchHUD", detail = "" })
	end
end
for safe in safeAreas do
	-- record where the simulated space landed, as a check on the method
	report.phone.safeArea = report.phone.safeArea or {}
	report.phone.safeArea[(safe.Parent :: Instance).Name] = { math.round(safe.AbsoluteSize.X), math.round(safe.AbsoluteSize.Y) }
	for _, child in safe:GetChildren() do
		checkBounds(child, safe.AbsolutePosition)
	end
end

-- every panel window: a Frame named "<Name>Panel" with a Header child
local panels: { Frame } = {}
for _, gui in guis do
	for _, f in gui:GetChildren() do
		if f:IsA("Frame") and string.match(f.Name, "Panel$") and f:FindFirstChild("Header") then
			table.insert(panels, f)
		end
	end
end
local function onPhone(u: UDim2): UDim2
	local d = design :: Vector2
	return UDim2.fromOffset(u.X.Scale * d.X + u.X.Offset, u.Y.Scale * d.Y + u.Y.Offset)
end
local wasVisible: { [Frame]: boolean } = {}
for _, p in panels do
	wasVisible[p] = p.Visible
	p.Visible = false
end
for _, p in panels do
	local size, position = p.Size, p.Position
	if design then
		p.Size = onPhone(size)
		p.Position = onPhone(position)
	end
	p.Visible = true
	task.wait(0.25)
	local before = report.counts.text
	auditText(p)
	checkBounds(p, (p.Parent :: ScreenGui).AbsolutePosition)
	local name = string.gsub(p.Name, "Panel$", "")
	local header = p:FindFirstChild("Header") :: Frame
	local parent = p.Parent :: Instance
	report.panels[name] = {
		header = rgb(header.BackgroundColor3),
		body = rgb(p.BackgroundColor3),
		shadow = parent:FindFirstChild(p.Name .. "Shadow") ~= nil,
		text = report.counts.text - before,
	}
	p.Visible = false
	p.Size, p.Position = size, position
end
for p, v in wasVisible do
	p.Visible = v
end
for safe, saved in safeAreas do
	safe.Size, safe.Position = saved.size, saved.position
end
for s, v in scales do
	s.Scale = v
end

print("[UIAudit] " .. HttpService:JSONEncode(report))
