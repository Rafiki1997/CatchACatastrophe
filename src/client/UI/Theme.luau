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
