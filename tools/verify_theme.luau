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
