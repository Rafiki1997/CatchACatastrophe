--!strict
-- Visual language for the whole UI: a playful disaster-management company.
-- Chunky rounded panels, dark ink strokes, hazard-stripe accents, readable
-- text. Base design resolution is 1280x720; Widgets.attachScale shrinks for phones.

local Theme = {}

Theme.colors = {
	bg = Color3.fromRGB(36, 40, 56), -- panel background (slate blue)
	bgAlt = Color3.fromRGB(48, 53, 74), -- card / row background
	bgDeep = Color3.fromRGB(26, 29, 42),
	ink = Color3.fromRGB(18, 20, 30), -- strokes
	text = Color3.fromRGB(255, 252, 245),
	textDim = Color3.fromRGB(186, 190, 210),
	accent = Color3.fromRGB(255, 184, 48), -- hazard yellow: primary buttons
	accentAlt = Color3.fromRGB(88, 196, 255), -- sky: secondary buttons
	success = Color3.fromRGB(96, 214, 120),
	warn = Color3.fromRGB(255, 200, 80),
	danger = Color3.fromRGB(240, 84, 96),
	gold = Color3.fromRGB(255, 214, 64),
	coin = Color3.fromRGB(255, 208, 72),
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

Theme.fonts = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	number = Enum.Font.FredokaOne,
}

Theme.sizes = {
	radius = 12,
	radiusSmall = 8,
	stroke = 3,
	padding = 10,
	buttonHeight = 44, -- touch friendly
	sidebarButton = 64,
	textSmall = 14,
	text = 16,
	textLarge = 20,
	title = 26,
	hudNumber = 28,
}

Theme.hudSafeTop = 8

return Theme
