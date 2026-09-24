# Kid-friendly UI Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the whole Catch a Catastrophe client UI as a bright, colourful kids' game (in the style of `docs/art/UIReferences/IconSample.png`): candy-colour panels, glossy chunky buttons, outlined white text, and a 2-column icon-tile sidebar with slots for Astra's icons.

**Architecture:** Every colour already lives in `src/client/UI/Theme.luau`, and every widget is built by `src/client/UI/Widgets.luau`. The restyle therefore lands there, plus a sidebar rebuild in `src/client/UI/HUD.luau`. Panel files do not change. Light text stays legal on candy colours because every text widget gets a `UIStroke` text outline by default. Two tools make it verifiable: a headless Lune check of Theme, and a live Studio UI audit driven by a small StudioMCP stdio client.

**Tech Stack:** Luau (Roblox, `--!strict`), Rojo (the only sync path), Lune 0.10.5 for headless checks, Python 3.11 for the StudioMCP client, and Roblox Studio via the bundled `StudioMCP.exe`.

**Spec:** `docs/superpowers/specs/2026-09-23-kid-friendly-ui-design.md`

## Global Constraints

- All colours stay in `src/client/UI/Theme.luau`. Panel files add no `Color3.fromRGB`. (After this plan, `Widgets.luau` holds none either.)
- These existing Theme colour keys stay defined, so no call site breaks: `bg`, `bgAlt`, `bgDeep`, `ink`, `text`, `textDim`, `accent`, `accentAlt`, `success`, `warn`, `danger`, `gold`, `coin`, `stripe`, `circuit`, `overdrive`, `silhouette`, `token`, `steal`, plus `Theme.elements`. Only their values change.
- The existing `Widgets` public API (function names, parameters, return types) is unchanged. New behaviour is additive: new optional props, new Theme tables, and new functions.
- Every text-bearing widget (`label`, `button`, `iconButton`, `badge`, progress label, tab, tooltip) gets an outline by default. A label can opt out with `outline = false`.
- The base design resolution stays 1280x720, and `W.attachScale` / `W.safeArea` keep working as today.
- Rojo is the only sync path into Studio. Never hand-patch a script `.Source` through StudioMCP. Never publish.
- **Working tree:** the main checkout `C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe` holds another session's uncommitted work. Stage only the exact paths each task names (`git add <path>`, never `git add -A` / `.`). Do **not** edit `src/client/UI/Panels/CreaturesPanel.luau`, `QuestsPanel.luau`, `SettingsPanel.luau` or `src/client/UI/TutorialUI.luau`, because they carry uncommitted edits that are not ours. `RELAY.md` and `docs/CONTRACTS.md` also carry them, so edit those files but never commit them.
- Environment traps: the Bash tool strips backslashes in Windows paths (use forward slashes, or the PowerShell tool). `cat > file` with no heredoc waits on stdin forever. Set `PYTHONIOENCODING=utf-8` for anything that touches StudioMCP.

## File map

| File | Task | Responsibility |
|---|---|---|
| `tools/studio_mcp.py` (new) | 1 | CLI stdio client for StudioMCP: state, play/stop, exec a Luau file, any raw tool call |
| `tools/ui_audit.luau` (new) | 1 | Client-datamodel audit of the live UI: text outlines, text overflow, panel colours/shadows, sidebar grid |
| `src/client/UI/Theme.luau` | 2 | Candy palette, `Theme.panels`, `Theme.panelColors`, `Theme.icons`, gloss colours, outline/tile/shadow sizes |
| `tools/verify_theme.luau` (new) | 2 | Headless contract check of Theme |
| `src/client/UI/Widgets.luau` | 3, 4 | `W.outline`, `W.gloss`, `W.shadow`, outline-by-default, per-panel colours, `W.iconTile` |
| `src/client/UI/HUD.luau` | 4 | Sidebar becomes a 2-column icon-tile grid |
| `docs/art/UIReferences/ICON-REQUEST.md` (new) | 4 | Exact icon request for Astra |
| `docs/CONTRACTS.md`, `RELAY.md` | 5 | Documentation (edited, not committed) |

---

### Task 1: StudioMCP client, UI audit, and a pre-change baseline

**Files:**
- Create: `tools/studio_mcp.py`
- Create: `tools/ui_audit.luau`

**Interfaces:**
- Produces: the CLI `python tools/studio_mcp.py state | play | stop | exec FILE --dm Edit|Server|Client [--prepend CODE] | call TOOL JSON [--out PATH]`.
- Produces: `tools/ui_audit.luau`, which prints exactly one line starting with `[UIAudit] ` followed by JSON of the shape
  `{ scale, counts = { text, outlined, fits }, failures = [ { kind, path, detail } ], panels = { [name] = { header = {r,g,b}, body = {r,g,b}, shadow = bool } }, sidebar = { grid = bool, tiles = n, columns = n } }`.
  It honours a global `AUDIT_SCALE` (number) when one is prepended.
- Produces: the baseline in the report file (`SelfTest` / `LiveTest` pass/fail counts, plus the audit JSON before any restyle).

- [ ] **Step 1: Write `tools/studio_mcp.py`**

```python
"""Tiny stdio client for Roblox Studio's bundled StudioMCP.exe.

No Studio MCP server is configured for Claude, so this speaks JSON-RPC to the
exe directly. Run from the repository root:

  python tools/studio_mcp.py state
  python tools/studio_mcp.py play            # start Play
  python tools/studio_mcp.py stop            # stop Play
  python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client [--prepend "AUDIT_SCALE = 0.7"]
  python tools/studio_mcp.py call screen_capture '{"capture_id": "hud"}' --out shot.png

The studio_id is discovered automatically (Studio can take ~15 s to answer the
first time); set STUDIO_ID to skip discovery. Set PYTHONIOENCODING=utf-8.
"""
import argparse
import base64
import glob
import json
import os
import re
import subprocess
import sys
import time

OFFICIAL_PLACE = "6f9cd136-faa6-4b44-b5bc-3f40ee0f50d9"
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def find_exe():
    paths = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))
    if not paths:
        sys.exit("StudioMCP.exe not found under %LOCALAPPDATA%/Roblox/Versions")
    return max(paths, key=os.path.getmtime)


class Client:
    def __init__(self):
        self.proc = subprocess.Popen(
            [find_exe()],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
        )
        self.next_id = 0
        self.request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "cac-studio-mcp", "version": "1"},
        })
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _send(self, message):
        self.proc.stdin.write(json.dumps(message) + "\n")
        self.proc.stdin.flush()

    def request(self, method, params=None):
        self.next_id += 1
        request_id = self.next_id
        self._send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params or {}})
        while True:
            line = self.proc.stdout.readline()
            if not line:
                sys.exit(f"StudioMCP closed the pipe during {method}")
            message = json.loads(line)
            if message.get("id") == request_id:
                if "error" in message:
                    sys.exit(f"{method} failed: {message['error']}")
                return message["result"]

    def call(self, tool, arguments):
        return self.request("tools/call", {"name": tool, "arguments": arguments})

    def studio_id(self, timeout=60):
        if os.environ.get("STUDIO_ID"):
            return os.environ["STUDIO_ID"]
        deadline = time.time() + timeout
        while time.time() < deadline:
            ids = UUID.findall(text_of(self.call("list_roblox_studios", {})))
            if ids:
                return OFFICIAL_PLACE if OFFICIAL_PLACE in ids else ids[0]
            time.sleep(3)
        sys.exit("Roblox Studio did not answer; is it open with the MCP plugin enabled?")

    def close(self):
        self.proc.kill()


def text_of(result):
    return "\n".join(c.get("text", "") for c in result.get("content", []) if c.get("type") == "text")


def save_images(result, out):
    images = [c for c in result.get("content", []) if c.get("type") == "image"]
    for index, image in enumerate(images):
        path = out if len(images) == 1 else f"{os.path.splitext(out)[0]}_{index}{os.path.splitext(out)[1]}"
        with open(path, "wb") as handle:
            handle.write(base64.b64decode(image["data"]))
        print(f"saved {path}")
    return len(images)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("state")
    sub.add_parser("play")
    sub.add_parser("stop")
    ex = sub.add_parser("exec")
    ex.add_argument("file")
    ex.add_argument("--dm", default="Client", choices=["Edit", "Server", "Client"])
    ex.add_argument("--prepend", default="")
    raw = sub.add_parser("call")
    raw.add_argument("tool")
    raw.add_argument("args", nargs="?", default="{}")
    raw.add_argument("--out", default="")
    opts = parser.parse_args()

    client = Client()
    try:
        sid = client.studio_id()
        if opts.cmd == "state":
            result = client.call("get_studio_state", {"studio_id": sid})
        elif opts.cmd in ("play", "stop"):
            result = client.call("start_stop_play", {"studio_id": sid, "is_start": opts.cmd == "play"})
        elif opts.cmd == "exec":
            with open(opts.file, encoding="utf-8") as handle:
                code = handle.read()
            if opts.prepend:
                code = opts.prepend + "\n" + code
            result = client.call("execute_luau", {"studio_id": sid, "datamodel_type": opts.dm, "code": code})
        else:
            arguments = json.loads(opts.args)
            arguments.setdefault("studio_id", sid)
            result = client.call(opts.tool, arguments)
        print(text_of(result))
        if opts.cmd == "call" and opts.out:
            if save_images(result, opts.out) == 0:
                print("no image content in the result")
        if result.get("isError"):
            sys.exit(1)
    finally:
        client.close()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Smoke-test the client**

Run: `PYTHONIOENCODING=utf-8 python tools/studio_mcp.py state`
Expected: a text description of Studio's state, which says whether it is in Edit or Play. If it exits with "did not answer", Studio is not open. Report `BLOCKED` with that message; do not try to launch Studio yourself.

- [ ] **Step 3: Write `tools/ui_audit.luau`**

```lua
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
```

- [ ] **Step 4: Take the baseline (before any restyle)**

1. Check `%LOCALAPPDATA%/Roblox/logs/*Studio*_last.log` (newest by mtime) for lines from the last 5 minutes that show another pane driving Play or MCP. If you find any, report `BLOCKED` ("another session is using Studio").
2. Run `python tools/studio_mcp.py state`. If Studio is in Play, run `python tools/studio_mcp.py stop`.
3. Run `python tools/studio_mcp.py play`, then poll `state` every 5 s until the Client datamodel exists (60 s at most).
4. Wait 20 s for boot, then read the newest `*Studio*_last.log` and copy the `[SelfTest]` and `[LiveTest]` summary lines (pass/fail counts) written after this Play started.
5. Run `python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client` and copy the whole `[UIAudit]` line.
6. Run `python tools/studio_mcp.py call screen_capture '{"capture_id": "baseline-hud"}' --out <report-dir>/baseline-hud.png` (the report file's directory). If the tool needs other arguments or returns no image, record what it returned and move on; screenshots are a nice-to-have in this task.
7. Run `python tools/studio_mcp.py stop`.

Expected: the audit shows `no-outline` failures (outlines don't exist yet), `sidebar.grid = false`, and every `panels[*].shadow = false`. **This is the red test for Tasks 3 and 4.** Record in the report file: the SelfTest and LiveTest counts, the audit's `counts`, how many failures of each kind, and the full list of `text-overflow` paths (Task 5 compares against it).

- [ ] **Step 5: Commit**

```bash
git add tools/studio_mcp.py tools/ui_audit.luau
git commit -m "tools: StudioMCP stdio client and live UI audit for the restyle"
```

---

### Task 2: Candy Theme and its headless contract check

**Files:**
- Modify: `src/client/UI/Theme.luau` (full rewrite, content below)
- Create: `tools/verify_theme.luau`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces (used by Tasks 3 and 4, all exact):
  - `export type PanelColors = { body: Color3, header: Color3, tile: Color3 }`
  - `Theme.panels: { [string]: PanelColors }`, with keys `default, Creatures, Atlas, Recipes, Workshop, Supply, Premium, Quests, Cities, Relaunch, Settings, Crisis`
  - `Theme.panelColors(name: string): PanelColors`, which falls back to `Theme.panels.default`
  - `export type IconSlot = { image: string, glyph: string }`, and `Theme.icons: { [string]: IconSlot }` keyed by the 10 sidebar panel names
  - `Theme.gloss = { top: Color3, mid: Color3, bottom: Color3 }`
  - `Theme.colors.disabled: Color3` (new key)
  - `Theme.sizes.textOutline = 2`, `textOutlineLarge = 3`, `stroke = 4`, `strokePanel = 5`, `sidebarTile = 84`, `shadowOffset = 6`, `shadowTransparency = 0.55`

- [ ] **Step 1: Write the failing check, `tools/verify_theme.luau`**

```lua
-- Run from the repository root with Lune 0.10.5:
--   lune run tools/verify_theme.luau
-- Loads src/client/UI/Theme.luau headlessly and proves the kid-friendly
-- restyle contract: every panel has its candy colours, every sidebar entry has
-- an icon slot, and white text keeps at least 3:1 contrast (the WCAG
-- large-text bar; the outline carries the rest) on every surface it sits on.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0
local function check(ok: boolean, message: string)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. message)
	end
end

local Theme = luau.load(fs.readFile("src/client/UI/Theme.luau"), {
	debugName = "Theme",
	environment = { Color3 = roblox.Color3, Enum = roblox.Enum, UDim = roblox.UDim },
})()

-- names come straight from the code, so a new panel cannot slip past
local panelNames = {}
for _, entry in fs.readDir("src/client/UI/Panels") do
	if string.sub(entry, -5) == ".luau" then
		local text = fs.readFile("src/client/UI/Panels/" .. entry)
		for name in string.gmatch(text, 'W%.panel%(%s*gui%s*,%s*"([^"]+)"') do
			table.insert(panelNames, name)
		end
	end
end
local sidebarNames = {}
for name in string.gmatch(fs.readFile("src/client/UI/HUD.luau"), '{%s*panel%s*=%s*"([^"]+)"') do
	table.insert(sidebarNames, name)
end
check(#panelNames >= 11, "found " .. #panelNames .. " W.panel names, expected at least 11")
check(#sidebarNames >= 10, "found " .. #sidebarNames .. " sidebar entries, expected at least 10")

local function channel(c: number): number
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(c): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end
local function contrast(a, b): number
	local la, lb = luminance(a), luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end

check(type(Theme.panels) == "table", "Theme.panels missing")
check(type(Theme.panelColors) == "function", "Theme.panelColors missing")
local text = Theme.colors.text
local panels = Theme.panels or {}
local names = { "default" }
for _, n in panelNames do
	table.insert(names, n)
end
for _, n in sidebarNames do
	table.insert(names, n)
end
for _, name in names do
	local entry = panels[name]
	check(entry ~= nil, "Theme.panels." .. name .. " missing")
	if entry then
		for _, field in { "body", "header", "tile" } do
			local c = entry[field]
			check(typeof(c) == "Color3", name .. "." .. field .. " is not a Color3")
			if typeof(c) == "Color3" then
				local ratio = contrast(text, c)
				check(ratio >= 3.0, ("%s.%s contrast %.2f < 3.0"):format(name, field, ratio))
			end
		end
	end
end
if type(Theme.panelColors) == "function" then
	check(Theme.panelColors("NoSuchPanel") == panels.default, "panelColors does not fall back to default")
	check(Theme.panelColors("Premium") == panels.Premium, "panelColors does not return the named entry")
end
for _, key in { "bg", "bgAlt", "bgDeep" } do
	local ratio = contrast(text, Theme.colors[key])
	check(ratio >= 3.0, ("colors.%s contrast %.2f < 3.0"):format(key, ratio))
end

check(type(Theme.icons) == "table", "Theme.icons missing")
for _, name in sidebarNames do
	local slot = (Theme.icons or {})[name]
	check(slot ~= nil, "Theme.icons." .. name .. " missing")
	if slot then
		check(type(slot.glyph) == "string" and slot.glyph ~= "", name .. " icon has no glyph")
		check(slot.image == "" or string.sub(slot.image, 1, 13) == "rbxassetid://", name .. " icon image must be '' or rbxassetid://")
	end
end

for _, key in { "top", "mid", "bottom" } do
	check(typeof((Theme.gloss or {})[key]) == "Color3", "Theme.gloss." .. key .. " missing")
end
check(typeof(Theme.colors.disabled) == "Color3", "Theme.colors.disabled missing")
for _, key in { "textOutline", "textOutlineLarge", "strokePanel", "sidebarTile", "shadowOffset", "shadowTransparency" } do
	check(type(Theme.sizes[key]) == "number", "Theme.sizes." .. key .. " missing")
end
-- legacy keys must survive so no call site breaks
for _, key in { "bg", "bgAlt", "bgDeep", "ink", "text", "textDim", "accent", "accentAlt", "success", "warn", "danger", "gold", "coin", "stripe", "circuit", "overdrive", "silhouette", "token", "steal" } do
	check(typeof(Theme.colors[key]) == "Color3", "Theme.colors." .. key .. " missing")
end

print(("verify_theme: %d passed, %d failed"):format(passed, failed))
process.exit(if failed == 0 then 0 else 1)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `lune run tools/verify_theme.luau`
Expected: FAIL lines including `Theme.panels missing` and `Theme.icons missing`, then exit code 1.

- [ ] **Step 3: Rewrite `src/client/UI/Theme.luau`**

```lua
--!strict
-- Visual language for the whole UI: a bright, colourful kids' game. Every
-- panel has its own candy colour, buttons are glossy and chunky with thick dark
-- strokes, and light text always carries a heavy dark outline (Widgets.outline)
-- so it reads on any colour. Base design resolution is 1280x720;
-- Widgets.attachScale shrinks for phones. Reference art:
-- docs/art/UIReferences/IconSample.png

local Theme = {}

Theme.colors = {
	bg = Color3.fromRGB(38, 132, 222), -- default panel body (sky blue)
	bgAlt = Color3.fromRGB(34, 44, 96), -- card / row background (deep indigo, like the sample's tiles)
	bgDeep = Color3.fromRGB(20, 26, 60), -- insets, bar troughs, tooltips
	ink = Color3.fromRGB(22, 24, 40), -- strokes and text outlines
	text = Color3.fromRGB(255, 252, 245),
	textDim = Color3.fromRGB(206, 226, 255), -- light pastel, still outlined
	accent = Color3.fromRGB(255, 196, 40), -- sunshine yellow: primary buttons
	accentAlt = Color3.fromRGB(60, 200, 255), -- bright sky: secondary buttons
	success = Color3.fromRGB(70, 200, 90),
	warn = Color3.fromRGB(255, 170, 40),
	danger = Color3.fromRGB(236, 64, 80),
	gold = Color3.fromRGB(255, 214, 64),
	coin = Color3.fromRGB(255, 208, 72),
	disabled = Color3.fromRGB(120, 128, 160),
	stripe = Color3.fromRGB(40, 40, 44), -- hazard stripe dark band
	circuit = Color3.fromRGB(120, 255, 200),
	overdrive = Color3.fromRGB(255, 120, 60),
	silhouette = Color3.fromRGB(28, 28, 36),
	-- legacy keys used by the copied Notifications module
	token = Color3.fromRGB(190, 120, 255),
	steal = Color3.fromRGB(255, 96, 120),
}

-- Element colours (mirror Config.Regions but available without a Config require).
Theme.elements = {
	Wind = Color3.fromRGB(150, 230, 170),
	Water = Color3.fromRGB(90, 180, 255),
	Heat = Color3.fromRGB(255, 120, 60),
	Frost = Color3.fromRGB(170, 230, 255),
	Storm = Color3.fromRGB(255, 230, 90),
	Cosmic = Color3.fromRGB(200, 130, 255),
}

-- One candy colour per panel: the window body, its header banner (a deeper
-- shade), and its sidebar tile. Every value keeps white text at >= 3:1
-- contrast; tools/verify_theme.luau enforces it.
export type PanelColors = { body: Color3, header: Color3, tile: Color3 }

local function candy(body: Color3, header: Color3, tile: Color3): PanelColors
	return { body = body, header = header, tile = tile }
end

Theme.panels = {
	default = candy(Color3.fromRGB(38, 132, 222), Color3.fromRGB(24, 104, 196), Color3.fromRGB(30, 118, 210)),
	Creatures = candy(Color3.fromRGB(142, 68, 210), Color3.fromRGB(118, 44, 188), Color3.fromRGB(128, 54, 200)),
	Atlas = candy(Color3.fromRGB(0, 142, 150), Color3.fromRGB(0, 114, 124), Color3.fromRGB(0, 128, 138)),
	Recipes = candy(Color3.fromRGB(214, 98, 20), Color3.fromRGB(190, 76, 8), Color3.fromRGB(202, 86, 12)),
	Workshop = candy(Color3.fromRGB(52, 96, 214), Color3.fromRGB(34, 72, 190), Color3.fromRGB(42, 84, 204)),
	Supply = candy(Color3.fromRGB(40, 150, 64), Color3.fromRGB(26, 122, 46), Color3.fromRGB(32, 136, 54)),
	Premium = candy(Color3.fromRGB(216, 48, 64), Color3.fromRGB(186, 28, 46), Color3.fromRGB(200, 36, 54)),
	Quests = candy(Color3.fromRGB(208, 54, 150), Color3.fromRGB(180, 30, 124), Color3.fromRGB(194, 42, 136)),
	Cities = candy(Color3.fromRGB(28, 136, 210), Color3.fromRGB(14, 108, 184), Color3.fromRGB(20, 122, 198)),
	Relaunch = candy(Color3.fromRGB(226, 72, 44), Color3.fromRGB(196, 50, 26), Color3.fromRGB(210, 60, 34)),
	Settings = candy(Color3.fromRGB(82, 92, 190), Color3.fromRGB(60, 68, 166), Color3.fromRGB(70, 80, 178)),
	Crisis = candy(Color3.fromRGB(200, 40, 40), Color3.fromRGB(164, 20, 20), Color3.fromRGB(182, 30, 30)),
} :: { [string]: PanelColors }

function Theme.panelColors(name: string): PanelColors
	return Theme.panels[name] or Theme.panels.default
end

-- Sidebar icon slots. `image` is Astra's painted icon once it is uploaded
-- (an rbxassetid:// string, see docs/art/UIReferences/ICON-REQUEST.md);
-- until then the tile shows the `glyph`.
export type IconSlot = { image: string, glyph: string }

Theme.icons = {
	Creatures = { image = "", glyph = utf8.char(0x1F43E) }, -- paw prints
	Atlas = { image = "", glyph = utf8.char(0x1F30D) }, -- globe
	Recipes = { image = "", glyph = utf8.char(0x1F4D6) }, -- open book
	Workshop = { image = "", glyph = utf8.char(0x1F527) }, -- wrench
	Supply = { image = "", glyph = utf8.char(0x1F4E6) }, -- package
	Premium = { image = "", glyph = utf8.char(0x1F6D2) }, -- shopping cart
	Quests = { image = "", glyph = utf8.char(0x1F3C6) }, -- trophy
	Cities = { image = "", glyph = utf8.char(0x1F3E0) }, -- house
	Relaunch = { image = "", glyph = utf8.char(0x1F680) }, -- rocket
	Settings = { image = "", glyph = utf8.char(0x2699, 0xFE0F) }, -- gear
} :: { [string]: IconSlot }

-- Top-lit gloss for buttons, headers and tiles. A UIGradient multiplies the
-- colour it sits on, so these are tints, not colours.
Theme.gloss = {
	top = Color3.fromRGB(255, 255, 255),
	mid = Color3.fromRGB(236, 236, 236),
	bottom = Color3.fromRGB(196, 196, 196),
}

Theme.fonts = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	number = Enum.Font.FredokaOne,
}

Theme.sizes = {
	radius = 12,
	radiusSmall = 8,
	stroke = 4, -- buttons and frames
	strokePanel = 5, -- panel windows and dialogs
	textOutline = 2, -- dark outline around light text
	textOutlineLarge = 3, -- titles, captions, HUD numbers
	padding = 10,
	buttonHeight = 44, -- touch friendly
	sidebarButton = 64,
	sidebarTile = 84,
	shadowOffset = 6,
	shadowTransparency = 0.55,
	textSmall = 14,
	text = 16,
	textLarge = 20,
	title = 26,
	hudNumber = 28,
}

Theme.hudSafeTop = 8

return Theme
```

- [ ] **Step 4: Run the check and watch it pass**

Run: `lune run tools/verify_theme.luau`
Expected: `verify_theme: N passed, 0 failed`, exit code 0.

- [ ] **Step 5: Static checks**

Run: `python tools/luau_lint.py src` and `python tools/quote_scan.py src`
Expected: both clean. (There's a known quote_scan false positive on line-initial `if` expressions; this file has none.)

- [ ] **Step 6: Commit**

```bash
git add src/client/UI/Theme.luau tools/verify_theme.luau
git commit -m "feat(ui): candy palette, per-panel colours and icon slots in Theme"
```

---

### Task 3: Widgets — outlines, gloss, shadows, per-panel colours

**Files:**
- Modify: `src/client/UI/Widgets.luau`

**Interfaces:**
- Consumes (Task 2): `Theme.panelColors(name)`, `Theme.gloss`, `Theme.colors.disabled`, `Theme.sizes.textOutline`, `textOutlineLarge`, `stroke`, `strokePanel`, `shadowOffset`, `shadowTransparency`.
- Consumes (Task 1): `tools/studio_mcp.py`, `tools/ui_audit.luau`, and the baseline in the Task 1 report.
- Produces (used by Task 4):
  - `W.outline(inst: TextLabel | TextButton, thickness: number?): UIStroke`, which names the stroke `"TextOutline"`, uses `ApplyStrokeMode.Contextual`, and is enabled only while the text colour is light
  - `W.gloss(inst: GuiObject): UIGradient`, named `"Gloss"`
  - `W.shadow(target: GuiObject, offset: number?): Frame`, a sibling named `target.Name .. "Shadow"`
  - `W.stroke` now names its UIStroke `"Border"`
  - `LabelProps.outline: boolean?`, `ButtonProps.outline: boolean?`, `ButtonProps.gloss: boolean?` (both default true)

- [ ] **Step 1: Add the new primitives** after `W.stroke` (around `Widgets.luau:41`). Also change `W.stroke` to set `s.Name = "Border"` before `s.Parent = inst`.

```lua
-- Light text on a candy colour reads only with a heavy dark outline around the
-- glyphs, the reference sample's look. Contextual mode strokes the text rather
-- than the box, so it sits alongside a button's Border stroke. Dark text gets
-- none: it already contrasts with the bright surfaces it is used on. The
-- luminance here is the cheap gamma-space estimate; 0.3 keeps danger red
-- outlined.
local function isLight(color: Color3): boolean
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.3
end

function W.outline(inst: TextLabel | TextButton, thickness: number?): UIStroke
	local existing = inst:FindFirstChild("TextOutline")
	local stroke: UIStroke
	if existing and existing:IsA("UIStroke") then
		stroke = existing
	else
		stroke = Instance.new("UIStroke")
		stroke.Name = "TextOutline"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = Theme.colors.ink
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = inst
		inst:GetPropertyChangedSignal("TextColor3"):Connect(function()
			stroke.Enabled = isLight(inst.TextColor3)
		end)
	end
	stroke.Thickness = thickness or Theme.sizes.textOutline
	stroke.Enabled = isLight(inst.TextColor3)
	return stroke
end

-- Top-lit gloss. The gradient multiplies BackgroundColor3, so hover and press
-- recolouring through BaseColor keeps working underneath it.
function W.gloss(inst: GuiObject): UIGradient
	local existing = inst:FindFirstChild("Gloss")
	if existing and existing:IsA("UIGradient") then
		return existing
	end
	local g = Instance.new("UIGradient")
	g.Name = "Gloss"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.gloss.top),
		ColorSequenceKeypoint.new(0.5, Theme.gloss.mid),
		ColorSequenceKeypoint.new(1, Theme.gloss.bottom),
	})
	g.Parent = inst
	return g
end

-- Drop shadow drawn as a sibling behind the target: under ZIndexBehavior.Sibling
-- a child always draws above its parent, so it cannot be a child. It follows
-- the target's size, position, anchor and visibility, and dies with it.
function W.shadow(target: GuiObject, offset: number?): Frame
	local o = offset or Theme.sizes.shadowOffset
	local corner = target:FindFirstChildOfClass("UICorner")
	local shadow = W.frame({
		parent = target.Parent,
		name = target.Name .. "Shadow",
		color = Theme.colors.ink,
		transparency = Theme.sizes.shadowTransparency,
		radius = if corner then corner.CornerRadius.Offset else 0,
		zindex = math.max(target.ZIndex - 1, 1),
	})
	local function sync()
		shadow.AnchorPoint = target.AnchorPoint
		shadow.Size = target.Size
		shadow.Position = target.Position + UDim2.fromOffset(o, o)
		shadow.Visible = target.Visible
	end
	sync()
	for _, prop in { "AnchorPoint", "Size", "Position", "Visible" } do
		target:GetPropertyChangedSignal(prop):Connect(sync)
	end
	target.Destroying:Connect(function()
		shadow:Destroy()
	end)
	return shadow
end
```

- [ ] **Step 2: Outline by default in `W.label`.**
  - Add `outline: boolean?, -- dark text outline (default on; off for text in dark insets)` to `LabelProps`.
  - Replace the block `if props.strokeText then l.TextStrokeTransparency = 0.2 l.TextStrokeColor3 = Theme.colors.ink end` with:

```lua
	if props.outline ~= false then
		W.outline(l, if props.strokeText then Theme.sizes.textOutlineLarge else nil)
	end
```

  - Update the `strokeText` comment to `-- heavier outline (HUD numbers, captions)`.

- [ ] **Step 3: Style `W.button`.**
  - Add `outline: boolean?` and `gloss: boolean?` to `ButtonProps`.
  - The default text colour becomes light: `b.TextColor3 = props.textColor or Theme.colors.text`.
  - Replace `W.stroke(b, props.stroke or Theme.colors.ink, Theme.sizes.stroke)` with:

```lua
	W.stroke(b, props.stroke or Theme.colors.ink, Theme.sizes.stroke)
	if props.gloss ~= false then
		W.gloss(b)
	end
	if props.outline ~= false then
		W.outline(b)
	end
```

  - In `W.setEnabled`, replace `disabledColor or Color3.fromRGB(96, 92, 112)` with `disabledColor or Theme.colors.disabled`.

- [ ] **Step 4: Per-panel colours in `W.panel`.** Replace the body of `W.panel` from `local frame = W.frame({` down to (but not including) `local body = W.frame({` with:

```lua
	local colors = Theme.panelColors(name)
	local frame = W.frame({
		parent = gui,
		name = name .. "Panel",
		size = size or UDim2.new(0, 640, 0, 440),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = colors.body,
		radius = Theme.sizes.radius + 4,
		stroke = Theme.colors.ink,
		strokeThickness = Theme.sizes.strokePanel,
		zindex = 10,
		visible = false,
	})
	W.shadow(frame)
	-- the header is a glossy rounded banner inset in the window, in the
	-- panel's deeper shade; it no longer needs its bottom corners squared off
	local header = W.frame({
		parent = frame,
		name = "Header",
		size = UDim2.new(1, -12, 0, 44),
		position = UDim2.new(0, 6, 0, 6),
		color = colors.header,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		zindex = 11,
	})
	W.gloss(header)
	local titleLabel = W.label({
		parent = header,
		text = title,
		size = UDim2.new(1, -110, 1, 0),
		position = UDim2.new(0, 14, 0, 0),
		textSize = Theme.sizes.title,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		strokeText = true,
		zindex = 12,
	})
	local close = W.button({
		parent = header,
		name = "Close",
		text = "X",
		size = UDim2.new(0, 40, 0, 34),
		position = UDim2.new(1, -6, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 20,
		zindex = 12,
		onClick = function()
			W.closePanels()
		end,
	})
```

The `body` frame that follows keeps its size and position (`UDim2.new(1, -24, 1, -64)` at `UDim2.new(0, 12, 0, 56)`), so panel content does not move.

- [ ] **Step 5: Chunkier dialogs and cards.**
  - In `W.confirm`, change the box's `strokeThickness = 4` to `strokeThickness = Theme.sizes.strokePanel`, and add `W.shadow(box)` right after the box is created.
  - In `W.card`, change `strokeThickness = 2` to `strokeThickness = 3`.
  - In `W.tooltip`, change `W.stroke(label, Theme.colors.ink, 2)` to `W.stroke(label, Theme.colors.ink, 3)`.

- [ ] **Step 6: Static checks and grep**

Run: `python tools/luau_lint.py src`, `python tools/quote_scan.py src`, and `lune run tools/verify_theme.luau`
Expected: all clean. Also confirm that `grep -n "Color3.fromRGB" src/client/UI/Widgets.luau` prints nothing.

- [ ] **Step 7: Rojo build**

Run: `rojo build -o build/KidUI.rbxl` (from the repo root)
Expected: the build succeeds.

- [ ] **Step 8: Live audit (the green test for outlines and panels)**

Confirm Studio has the new source by running `python tools/studio_mcp.py call script_grep '{"query": "function W.outline"}'`. It should report a hit in Widgets; if not, Rojo is not syncing, so report `BLOCKED`. Then run the Play cycle from Task 1 Step 4 (sub-steps 1–7; save the screenshot as `task3-hud.png`) and also open one panel for a capture: run `exec` on a one-liner file in your scratch directory that sets `PlayerGui.<gui>.PremiumPanel.Visible = true`, capture `task3-premium.png`, then set it back to false.

Expected:
- `failures` contains **no `no-outline`** entries.
- Every entry in `panels` has `shadow = true`, and each `header` / `body` RGB equals `Theme.panels[name].header` / `.body` from Task 2 (Crisis included).
- Every `text-overflow` path was already in the Task 1 baseline list, or is fixed.
- The SelfTest and LiveTest fail counts are no higher than the baseline.
- In the screenshot, buttons show both the box border and the text outline. **If a TextButton shows only one of the two strokes** (Roblox rendering only one UIStroke), change `W.outline` for `TextButton` only: skip the UIStroke and set `inst.TextStrokeColor3 = Theme.colors.ink` and `inst.TextStrokeTransparency = if isLight(...) then 0 else 1`, keeping the property-changed hook. Update `tools/ui_audit.luau` to accept `TextStrokeTransparency == 0` on TextButtons as outlined. Record this in the report.

- [ ] **Step 9: Commit**

```bash
git add src/client/UI/Widgets.luau
git commit -m "feat(ui): outlined text, gloss, shadows and per-panel candy colours in Widgets"
```

(Include `tools/ui_audit.luau` in the `git add` only if Step 8's fallback changed it.)

---

### Task 4: Icon-tile sidebar and the Astra icon request

**Files:**
- Modify: `src/client/UI/Widgets.luau` (add `W.iconTile`)
- Modify: `src/client/UI/HUD.luau:23-34` (the `SIDEBAR` table) and `HUD.luau:181-227` (the sidebar block)
- Create: `docs/art/UIReferences/ICON-REQUEST.md`

**Interfaces:**
- Consumes (Task 2): `Theme.panelColors`, `Theme.icons`, `Theme.sizes.sidebarTile`, `Theme.sizes.stroke`.
- Consumes (Task 3): `W.button` (glossy, outlined), `W.label` with `strokeText`, `W.stroke` naming its instance `"Border"`, and `W.grid`.
- Produces: `W.iconTile(parent: Instance, panelName: string, caption: string, onClick: () -> (), order: number?): TextButton`. The tile is named `panelName`, with child `"Icon"` (an ImageLabel or TextLabel) and child `"Caption"` (a TextLabel).
- Constraint: every `SIDEBAR` entry keeps the literal form `{ panel = "<Name>", caption = "<Caption>" }`, because `tools/verify_theme.luau` parses `{ panel = "`.

- [ ] **Step 1: Add `W.iconTile`** to `Widgets.luau`, directly after `W.iconButton`:

```lua
-- Sidebar tile in the reference sample's style: a glossy square in the panel's
-- candy colour, a big icon (Astra's painted art once uploaded, a glyph until
-- then) and the caption in outlined text overlapping the bottom edge.
function W.iconTile(parent: Instance, panelName: string, caption: string, onClick: () -> (), order: number?): TextButton
	local colors = Theme.panelColors(panelName)
	local slot = Theme.icons[panelName]
	local tile = W.button({
		parent = parent,
		name = panelName,
		text = "",
		size = UDim2.fromOffset(Theme.sizes.sidebarTile, Theme.sizes.sidebarTile),
		color = colors.tile,
		order = order,
		onClick = onClick,
	})
	if slot and slot.image ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Image = slot.image
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(0.86, 0.72)
		image.Position = UDim2.fromScale(0.5, 0.04)
		image.AnchorPoint = Vector2.new(0.5, 0)
		image.ZIndex = tile.ZIndex + 1
		image.Parent = tile
	else
		W.label({
			parent = tile,
			name = "Icon",
			text = if slot then slot.glyph else string.sub(caption, 1, 1),
			size = UDim2.fromScale(1, 0.66),
			position = UDim2.fromScale(0, 0.04),
			textSize = 38,
			font = Theme.fonts.title,
			xalign = Enum.TextXAlignment.Center,
			zindex = tile.ZIndex + 1,
		})
	end
	W.label({
		parent = tile,
		name = "Caption",
		text = caption,
		size = UDim2.new(1, 10, 0, 24),
		position = UDim2.new(0.5, 0, 1, 6),
		anchor = Vector2.new(0.5, 1),
		textSize = 16,
		font = Theme.fonts.title,
		xalign = Enum.TextXAlignment.Center,
		strokeText = true,
		zindex = tile.ZIndex + 2,
	})
	return tile
end
```

- [ ] **Step 2: Rebuild the sidebar in `HUD.luau`.** Replace the `SIDEBAR` table with:

```lua
-- The icon for each entry lives in Theme.icons (Astra's art, or a glyph).
local SIDEBAR = {
	{ panel = "Creatures", caption = "Creatures" },
	{ panel = "Atlas", caption = "Atlas" },
	{ panel = "Recipes", caption = "Recipes" },
	{ panel = "Workshop", caption = "Workshop" },
	{ panel = "Supply", caption = "Supply" },
	{ panel = "Premium", caption = "Premium" },
	{ panel = "Quests", caption = "Quests" },
	{ panel = "Cities", caption = "Cities" },
	{ panel = "Relaunch", caption = "Relaunch" },
	{ panel = "Settings", caption = "Settings" },
}
```

Then replace the sidebar block, from `local sidebar = Instance.new("ScrollingFrame")` through the end of the `W.onPanelChanged(...)` call, with:

```lua
	local tile = Theme.sizes.sidebarTile
	local gap = 10
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, tile * 2 + gap + 18, 1, -(Theme.hudSafeTop + 166))
	sidebar.Position = UDim2.new(0, 14, 0, Theme.hudSafeTop + 150)
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.CanvasSize = UDim2.new()
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
	sidebar.ScrollBarThickness = 3
	sidebar.ScrollBarImageColor3 = Theme.colors.textDim
	sidebar.Parent = safe
	-- the bottom padding leaves room for the last row's overlapping captions
	W.padding(sidebar, { left = 4, right = 12, top = 4, bottom = 12 })
	W.grid(sidebar, UDim2.fromOffset(tile, tile), gap)
	for i, entry in SIDEBAR do
		local button = W.iconTile(sidebar, entry.panel, entry.caption, function()
			W.togglePanel(entry.panel)
		end, i)
		-- hidden until it means something; HUD.refreshSidebar decides
		button.Visible = Config.Quests.panelGateById[entry.panel] == nil
		navButtons[entry.panel] = button
	end
	-- the open panel's tile gets a white rim and a pop
	W.onPanelChanged(function(panelName: string?)
		for name, button in navButtons do
			local selected = name == panelName
			local border = button:FindFirstChild("Border")
			if border and border:IsA("UIStroke") then
				border.Color = if selected then Theme.colors.text else Theme.colors.ink
				border.Thickness = if selected then Theme.sizes.stroke + 1 else Theme.sizes.stroke
			end
			if selected then
				W.pop(button, 1.08)
			end
		end
	end)
```

- [ ] **Step 3: Write `docs/art/UIReferences/ICON-REQUEST.md`**

```markdown
# Sidebar icon request (for Astra)

**Reference:** `IconSample.png` in this folder. Match its style exactly: glossy, chunky 3D cartoon
objects with soft highlights, a thick dark outline and saturated candy colours, in a slight 3/4 view,
reading clearly at 60 px.

## Format (every icon)

- Transparent PNG, **512x512**, with the subject filling about 85% of the canvas and centred.
- **No text, letters or numbers** in the image (the game draws the caption).
- No background tile or frame: the game draws the coloured tile behind the icon.
- File name `icon_<panel>.png` (lower case), delivered to `docs/art/UIReferences/icons/`.

## Icons

| File | Panel (caption) | Subject | Main colour (tile colour behind it) |
|---|---|---|---|
| `icon_creatures.png` | Creatures | A friendly round little storm creature with big eyes, peeking out of a glass capture jar | Purple tile (128, 54, 200): creature in teal/yellow |
| `icon_atlas.png` | Atlas | A cartoon globe on a small stand with a red map pin | Teal tile (0, 128, 138): globe blue/green |
| `icon_recipes.png` | Recipes | An open recipe book with a sparkle and a bookmark ribbon | Orange tile (202, 86, 12): book cream/red |
| `icon_workshop.png` | Workshop | A crossed wrench and hammer | Blue tile (42, 84, 204): steel silver, orange handle |
| `icon_supply.png` | Supply | A wooden supply crate with a lid ajar and a coin poking out | Green tile (32, 136, 54): crate warm brown |
| `icon_premium.png` | Premium | A red shopping basket like the sample's "Store" icon, with a gold star | Red tile (200, 36, 54): basket bright red |
| `icon_quests.png` | Quests | A clipboard checklist with a gold star sticker and two green ticks | Pink tile (194, 42, 136): clipboard cream/brown |
| `icon_cities.png` | Cities | Three chunky toy city buildings (one tall, two short) with lit windows | Sky tile (20, 122, 198): buildings warm colours |
| `icon_relaunch.png` | Relaunch | A cartoon rocket lifting off with a puff of smoke | Orange-red tile (210, 60, 34): rocket white/red |
| `icon_settings.png` | Settings | A glossy blue-and-white gear, like the sample's "Setting" icon | Indigo tile (70, 80, 178): gear light blue |

## How they land in the game

1. Upload each PNG to Roblox as a Decal or Image (Studio's Asset Manager, or Open Cloud).
2. Paste each asset id into `src/client/UI/Theme.luau` → `Theme.icons.<Panel>.image = "rbxassetid://<id>"`.
3. Run `lune run tools/verify_theme.luau`; the tile switches from the glyph to the image automatically.
```

- [ ] **Step 4: Static checks, Theme check and build**

Run: `python tools/luau_lint.py src`, `python tools/quote_scan.py src`, `lune run tools/verify_theme.luau`, and `rojo build -o build/KidUI.rbxl`
Expected: all clean and the build succeeds. `verify_theme` still finds 10 sidebar entries.

- [ ] **Step 5: Live audit (the green test for the sidebar)**

Confirm the sync with `python tools/studio_mcp.py call script_grep '{"query": "function W.iconTile"}'`, then run the Play cycle from Task 1 Step 4 (sub-steps 1–7; save the screenshot as `task4-hud.png`).
Expected:
- `sidebar.grid = true` and `sidebar.columns = 2`. `sidebar.tiles` equals the number of sidebar panels this test player has unlocked; for the Studio test profile, record what it is.
- No `no-outline` failures, and no `text-overflow` on any `Sidebar` path. If a caption overflows, drop the caption `textSize` from 16 to 15 and rerun.
- SelfTest and LiveTest fail counts are no higher than the baseline.
- In the screenshot, the tiles form a 2-column grid under the wallet with glyphs visible. If the glyphs render as empty boxes (tofu), replace every `Theme.icons` glyph with the caption's first letter (`"C"`, `"A"`, …) and record that in the report.

- [ ] **Step 6: Commit**

```bash
git add src/client/UI/Widgets.luau src/client/UI/HUD.luau docs/art/UIReferences/ICON-REQUEST.md
git commit -m "feat(ui): icon-tile sidebar grid and the Astra icon request"
```

(Include `src/client/UI/Theme.luau` only if Step 5 changed the glyphs.)

---

### Task 5: Full Studio pass, phone scale, and documentation

**Files:**
- Modify only if a check below fails: `src/client/UI/Theme.luau`, `src/client/UI/Widgets.luau`, `src/client/UI/HUD.luau`, and non-dirty UI modules (`Notifications.luau`, `CaptureHUD.luau`, `CaptureReveal.luau`, `CreaturePicker.luau`, `CollectionPadUI.luau`, `FloatingText.luau`, `CircuitEditorUI.luau`, and the panels other than the four listed in Global Constraints). Changes in modules may only swap Theme tokens or pass `outline = false`. No `Color3.fromRGB`.
- Modify (not committed): `docs/CONTRACTS.md`, `RELAY.md`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: the final evidence (audit JSON at scale 1 and 0.7, screenshots, SelfTest and LiveTest counts) in the report file, plus the doc updates.

- [ ] **Step 1: Desktop pass.** Run the Play cycle (Task 1 Step 4). For **each** panel in the audit's `panels` list, set only that panel visible through a one-line `exec`, capture `final-<panel>.png`, then hide it again. Also capture `final-hud.png` with no panel open.

- [ ] **Step 2: Phone pass.** In the same Play session, run `python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client --prepend "AUDIT_SCALE = 0.7"` and capture `final-hud-phone.png` while the scale is forced. (For the capture, prepend a separate one-liner that sets every ScreenGui `UIScale.Scale = 0.7`, and a second one that restores it to 1 afterwards.)

- [ ] **Step 3: Triage.** Every `no-outline` failure, and every `text-overflow` not in the Task 1 baseline, at either scale, gets fixed within the file limits above, then Steps 1–2 are re-run. A problem that only a dirty file (the four panels / TutorialUI) could fix is **not** fixed: record it in the report as `deferred (dirty file)`. Look at each screenshot yourself and list any text you cannot read, clipped element or overlap in the report. Fix it if the fix fits the file limits; otherwise record it.

- [ ] **Step 4: Stop Play**, then run the static checks, `lune run tools/verify_theme.luau` and `rojo build -o build/KidUI.rbxl` one last time.

- [ ] **Step 5: Documentation (edit, do not commit).**
  - In `docs/CONTRACTS.md` at the Widgets line (around `:604`), add `outline gloss shadow iconTile` to the Widgets function list, and change the Theme sentence to: `Theme` (DONE) has `colors`, `elements`, `panels` + `panelColors(name)`, `icons`, `gloss`, `fonts`, `sizes`. Around `:654`, add a bullet: `- Kid-friendly candy style: each panel has its own colours (Theme.panels); light text always carries a dark outline (W.outline, default on); buttons, headers and tiles are glossy (W.gloss); panels and dialogs drop a shadow (W.shadow). Check with lune run tools/verify_theme.luau and tools/ui_audit.luau.`
  - Add a new top entry to `RELAY.md` dated 2026-09-23: "Kid-friendly UI restyle". Give the commits, the spec/plan paths, the baseline vs final SelfTest/LiveTest and audit counts, the screenshot paths, what's deferred (the icon art from Astra via `ICON-REQUEST.md`, and any `deferred (dirty file)` items), and that nothing was published.

- [ ] **Step 6: Commit** (only if Step 3 changed code; stage exactly the files you changed, never the docs):

```bash
git add <each changed UI file>
git commit -m "fix(ui): readability fixes from the full Studio restyle pass"
```
