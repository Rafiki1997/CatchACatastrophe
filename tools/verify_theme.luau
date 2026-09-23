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
				-- secondary text and the yellow / sky highlights sit on the same
				-- surfaces; they are outlined too, so a lower bar holds them
				for _, key in { "textDim", "accent", "accentAlt" } do
					local r = contrast(Theme.colors[key], c)
					check(r >= 2.0, ("colors.%s on %s.%s contrast %.2f < 2.0"):format(key, name, field, r))
				end
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
local sizes = { textOutline = 2, textOutlineLarge = 3, strokePanel = 5, sidebarTile = 84, shadowOffset = 6, shadowTransparency = 0.55 }
for key, value in sizes do
	check(Theme.sizes[key] == value, ("Theme.sizes.%s is %s, expected %s"):format(key, tostring(Theme.sizes[key]), tostring(value)))
end

-- the live audit and Widgets.outline must agree on what counts as light text;
-- %1 matches whatever the colour argument is called in each copy, and the
-- frontiers stop a changed threshold such as 0.35 from matching
local isLightPattern = "%f[%d]0%.2126 %* ([%a_][%w_]*)%.R %+ 0%.7152 %* %1%.G %+ 0%.0722 %* %1%.B > 0%.3%f[^%d]"
for _, path in { "tools/ui_audit.luau", "src/client/UI/Widgets.luau" } do
	check(string.find(fs.readFile(path), isLightPattern) ~= nil, path .. " lost the shared isLight expression")
end
-- legacy keys must survive so no call site breaks
for _, key in { "bg", "bgAlt", "bgDeep", "ink", "text", "textDim", "accent", "accentAlt", "success", "warn", "danger", "gold", "coin", "stripe", "circuit", "overdrive", "silhouette", "token", "steal" } do
	check(typeof(Theme.colors[key]) == "Color3", "Theme.colors." .. key .. " missing")
end

-- Rarity and variant glyphs must draw in every Theme font. Gotham shows a box
-- for a glyph it lacks and Fredoka drops it silently, so a new glyph has to be
-- seen rendered in Studio (FredokaOne, GothamMedium, GothamBold) before it is
-- added here. Seen rendering in all three on 2026-09-23.
local SAFE_GLYPHS = {}
for _, g in { "●", "◆", "★", "◈", "▲", "■", "◉", "◎", "♦", "♥", "♠", "♣", "✚", "❖", "☀", "✿", "▼", "◇" } do
	SAFE_GLYPHS[g] = true
end
SAFE_GLYPHS["⚡"] = true -- emoji: every font falls back to the colour emoji
SAFE_GLYPHS[""] = true -- the Normal variant has no glyph
local configEnv = { Color3 = roblox.Color3, Enum = roblox.Enum }
local Rarities = luau.load(fs.readFile("src/shared/Config/Rarities.luau"), { debugName = "Rarities", environment = configEnv })()
local Variants = luau.load(fs.readFile("src/shared/Config/Variants.luau"), { debugName = "Variants", environment = configEnv })()
local iconsSeen = {}
for name, info in Rarities.info do
	check(SAFE_GLYPHS[info.icon] == true, ("rarity %s icon %q is not a glyph every UI font draws"):format(name, info.icon))
	check(iconsSeen[info.icon] == nil, ("rarity %s reuses the %s icon"):format(name, iconsSeen[info.icon] or ""))
	iconsSeen[info.icon] = name
end
for name, info in Variants.info do
	check(SAFE_GLYPHS[info.icon] == true, ("variant %s icon %q is not a glyph every UI font draws"):format(name, info.icon))
end

print(("verify_theme: %d passed, %d failed"):format(passed, failed))
process.exit(if failed == 0 then 0 else 1)
