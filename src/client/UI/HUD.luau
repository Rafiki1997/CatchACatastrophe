--!strict
-- The always-on readout: money, city income, the bank and its Collect button,
-- the regional Legendary forecast, the sidebar, and the save-state pill.
--
-- Everything here renders the snapshot. It never computes a price or a rate of
-- its own, so the HUD and the server cannot drift apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)

local HUD = {}

local SIDEBAR = {
	{ panel = "Creatures", icon = "C", caption = "Creatures" },
	{ panel = "Atlas", icon = "A", caption = "Atlas" },
	{ panel = "Recipes", icon = "R", caption = "Recipes" },
	{ panel = "Workshop", icon = "W", caption = "Workshop" },
	{ panel = "Quests", icon = "Q", caption = "Quests" },
	{ panel = "Cities", icon = "V", caption = "Cities" },
	{ panel = "Relaunch", icon = "L", caption = "Relaunch" },
	{ panel = "Settings", icon = "S", caption = "Settings" },
}

local gui: ScreenGui? = nil
local coinsLabel: TextLabel? = nil
local incomeLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local bankLabel: TextLabel? = nil
local bankBar: any = nil
local collectButton: TextButton? = nil
local dataPill: TextLabel? = nil
local offlineCard: Frame? = nil
local offlineText: TextLabel? = nil
local visitChip: TextButton? = nil
local buildPill: TextLabel? = nil
local forecastRow: Frame? = nil
local forecastChips: { [string]: TextLabel } = {}
local forecastData: { [string]: { nextLegendaryAt: number, surgeUntil: number } } = {}

function HUD.init()
	local g = W.screenGui("CatchHUD", 2)
	W.attachScale(g)
	gui = g
	-- anchor to the safe area, not the raw screen, so a notch or a home
	-- indicator never sits on top of the wallet or the sidebar
	local safe = W.safeArea(g)

	-- ---------------------------------------------------------------- wallet
	local wallet = W.frame({
		parent = safe,
		name = "Wallet",
		size = UDim2.new(0, 264, 0, 132),
		position = UDim2.new(0, 14, 0, Theme.hudSafeTop + 6),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
	})

	coinsLabel = W.label({
		parent = wallet,
		name = "Coins",
		text = "0",
		size = UDim2.new(1, -20, 0, 38),
		position = UDim2.new(0, 12, 0, 8),
		textSize = Theme.sizes.hudNumber,
		font = Theme.fonts.number,
		color = Theme.colors.coin,
		xalign = Enum.TextXAlignment.Left,
		strokeText = true,
	})
	incomeLabel = W.label({
		parent = wallet,
		name = "Income",
		text = "City income 0/s",
		size = UDim2.new(1, -20, 0, 20),
		position = UDim2.new(0, 12, 0, 46),
		textSize = 15,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	titleLabel = W.label({
		parent = wallet,
		name = "Title",
		text = "",
		size = UDim2.new(1, -20, 0, 18),
		position = UDim2.new(0, 12, 0, 64),
		textSize = 14,
		font = Theme.fonts.bold,
		color = Theme.colors.accentAlt,
		xalign = Enum.TextXAlignment.Left,
	})
	bankBar = W.progress(wallet, UDim2.new(1, -24, 0, 20), Theme.colors.coin, nil, UDim2.new(0, 12, 0, 84))
	bankLabel = W.label({
		parent = wallet,
		name = "Bank",
		text = "Collectible: 0",
		size = UDim2.new(1, -120, 0, 22),
		position = UDim2.new(0, 12, 0, 106),
		textSize = 14,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	collectButton = W.button({
		parent = wallet,
		name = "Collect",
		text = "Collect",
		size = UDim2.new(0, 96, 0, 28),
		position = UDim2.new(1, -12, 0, 104),
		anchor = Vector2.new(1, 0),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 15,
		onClick = function()
			Net.fire("CollectBank")
		end,
	})

	-- ---------------------------------------------------------------- forecast
	forecastRow = W.frame({
		parent = safe,
		name = "Forecast",
		size = UDim2.new(0, 300, 0, 30),
		position = UDim2.new(1, -14, 0, Theme.hudSafeTop + 6),
		anchor = Vector2.new(1, 0),
		transparency = 1,
	})
	W.list(forecastRow, Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Right)

	-- ---------------------------------------------------------------- sidebar
	local sidebar = W.frame({
		parent = safe,
		name = "Sidebar",
		size = UDim2.new(0, 72, 0, #SIDEBAR * 72),
		position = UDim2.new(0, 14, 0.5, 20),
		anchor = Vector2.new(0, 0.5),
		transparency = 1,
	})
	W.list(sidebar, Enum.FillDirection.Vertical, 6)
	for i, entry in SIDEBAR do
		W.iconButton(sidebar, entry.icon, entry.caption, Theme.colors.bgAlt, function()
			W.togglePanel(entry.panel)
		end, i)
	end

	-- ---------------------------------------------------------------- offline card
	offlineCard = W.frame({
		parent = safe,
		name = "Offline",
		size = UDim2.new(0, 340, 0, 96),
		position = UDim2.new(0.5, 0, 0, 60),
		anchor = Vector2.new(0.5, 0),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.accent,
		strokeThickness = 3,
		visible = false,
		zindex = 4,
	})
	W.label({
		parent = offlineCard,
		text = "While you were away",
		size = UDim2.new(1, -20, 0, 24),
		position = UDim2.new(0, 12, 0, 8),
		textSize = 18,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
		zindex = 5,
	})
	offlineText = W.label({
		parent = offlineCard,
		text = "",
		size = UDim2.new(1, -20, 0, 22),
		position = UDim2.new(0, 12, 0, 32),
		textSize = 15,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		zindex = 5,
	})
	W.button({
		parent = offlineCard,
		text = "Collect it",
		size = UDim2.new(1, -24, 0, 30),
		position = UDim2.new(0, 12, 1, -10),
		anchor = Vector2.new(0, 1),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 16,
		zindex = 5,
		onClick = function()
			Net.fire("ClaimOffline")
		end,
	})

	-- ---------------------------------------------------------------- visiting chip
	visitChip = W.button({
		parent = safe,
		name = "Visiting",
		text = "Visiting a city - go home",
		size = UDim2.new(0, 250, 0, 34),
		position = UDim2.new(0.5, 0, 1, -14),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.accentAlt,
		textColor = Theme.colors.ink,
		textSize = 15,
		onClick = function()
			Net.fire("VisitCity", 0)
		end,
	})
	visitChip.Visible = false

	-- ---------------------------------------------------------------- data pill
	buildPill = W.label({
		parent = safe,
		name = "BuildPill",
		text = "",
		size = UDim2.new(0, 240, 0, 26),
		position = UDim2.new(1, -14, 1, -44),
		anchor = Vector2.new(1, 1),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.textDim,
		bg = Theme.colors.bgDeep,
		radius = Theme.sizes.radiusSmall,
	})
	dataPill = W.label({
		parent = safe,
		name = "DataPill",
		text = "",
		size = UDim2.new(0, 200, 0, 26),
		position = UDim2.new(1, -14, 1, -14),
		anchor = Vector2.new(1, 1),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.textDim,
		bg = Theme.colors.bgDeep,
		radius = Theme.sizes.radiusSmall,
	})

	-- Tooltips: the HUD abbreviates every number, so hovering gives the exact
	-- figure and, where it helps, what the number actually means.
	W.tooltip(coinsLabel :: GuiObject, function()
		local snap = State.get()
		if not snap then
			return "Coins"
		end
		return "Coins: " .. Format.commas(math.floor(snap.coins)) .. "\nEarned all time: " .. Format.commas(math.floor(snap.lifetimeCoins))
	end)
	W.tooltip(incomeLabel :: GuiObject, function()
		local snap = State.get()
		if not snap then
			return "City income"
		end
		local line = "Your city earns " .. Format.commas(math.floor(snap.cps)) .. " Coins every second."
		if snap.cps > snap.normalCps + 0.5 then
			line ..= "\nOverdrive is running. Without it: " .. Format.commas(math.floor(snap.normalCps)) .. "/s."
		end
		return line
	end)
	W.tooltip(bankLabel :: GuiObject, function()
		local snap = State.get()
		if not snap then
			return "Bank"
		end
		return "Waiting to collect: "
			.. Format.commas(math.floor(snap.bank))
			.. "\nHolds up to "
			.. Format.commas(math.floor(snap.bankCap))
			.. " ("
			.. Format.duration(snap.derived.bankCapSeconds)
			.. " of production).\nIt stops filling when full, so collect before then."
	end)
	W.tooltip(collectButton :: GuiObject, "Move everything in the bank into your wallet. You can also step on the collection pad in your city.")
	W.tooltip(dataPill :: GuiObject, function()
		local snap = State.get()
		if not snap then
			return "Save status"
		end
		if not snap.dataSafe then
			return "Your save could not be loaded, so nothing is being written this session. Your real city is untouched."
		elseif snap.testAdapter then
			return "Studio has DataStores turned off, so this city lives only while the server runs."
		end
		return "Your progress is being saved automatically."
	end)

	Net.on("Forecast", function(data)
		if typeof(data) == "table" then
			forecastData = data
			HUD.refreshForecast()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			HUD.refreshForecast()
		end
	end)
end

function HUD.refreshForecast()
	local snap = State.get()
	if not snap or not forecastRow then
		return
	end
	local now = State.now()
	for _, def in Config.Regions.list do
		local unlocked = snap.regions[def.id] == true
		local chip = forecastChips[def.id]
		if unlocked and not chip then
			chip = W.label({
				parent = forecastRow,
				name = def.id,
				text = "",
				size = UDim2.new(0, 92, 1, 0),
				textSize = 12,
				font = Theme.fonts.bold,
				color = Theme.colors.text,
				bg = Theme.colors.bgDeep,
				radius = Theme.sizes.radiusSmall,
				order = def.index,
			})
			forecastChips[def.id] = chip
		end
		if chip then
			chip.Visible = unlocked
			local entry = forecastData[def.id]
			if entry and now < entry.surgeUntil then
				chip.Text = def.element .. "\nSURGE " .. Format.clock(entry.surgeUntil - now)
				chip.TextColor3 = Theme.colors.overdrive
			elseif entry then
				chip.Text = def.element .. "\n" .. Format.clock(math.max(0, entry.nextLegendaryAt - now))
				chip.TextColor3 = def.color
			else
				chip.Text = def.element .. "\n--"
				chip.TextColor3 = Theme.colors.textDim
			end
		end
	end
end

function HUD.update(snap: Types.Snapshot)
	if not gui then
		return
	end

	if coinsLabel then
		coinsLabel.Text = Format.abbreviate(snap.coins)
	end
	if incomeLabel then
		incomeLabel.Text = "City income " .. Format.abbreviate(snap.cps) .. "/s"
		if snap.cps > snap.normalCps + 0.5 then
			incomeLabel.Text ..= "  (OVERDRIVE)"
			incomeLabel.TextColor3 = Theme.colors.overdrive
		else
			incomeLabel.TextColor3 = Theme.colors.textDim
		end
	end
	if titleLabel then
		titleLabel.Text = snap.title or ""
	end

	if bankBar then
		local fraction = if snap.bankCap > 0 then snap.bank / snap.bankCap else 0
		bankBar.set(fraction, "")
		bankBar.fill.BackgroundColor3 = if snap.bankFull then Theme.colors.danger else Theme.colors.coin
	end
	if bankLabel then
		if snap.bankFull then
			bankLabel.Text = "BANK FULL - collect now"
			bankLabel.TextColor3 = Theme.colors.danger
		else
			bankLabel.Text = "Collectible: " .. Format.abbreviate(snap.bank)
			bankLabel.TextColor3 = Theme.colors.textDim
		end
	end
	if collectButton then
		W.setEnabled(collectButton, snap.bank >= 1)
	end

	if offlineCard and offlineText then
		if snap.offline then
			offlineCard.Visible = true
			offlineText.Text = "Your city earned " .. Format.abbreviate(snap.offline.amount) .. " Coins over " .. Format.duration(snap.offline.seconds) .. "."
		else
			offlineCard.Visible = false
		end
	end

	if visitChip then
		visitChip.Visible = snap.visiting ~= nil
	end

	if buildPill then
		if RunService:IsStudio() or snap.testAdapter then
			buildPill.Visible = true
			buildPill.Text = ("Build %d | %s"):format(snap.build.placeVersion, snap.build.environment)
			buildPill.TextColor3 = if snap.build.environment == "Live" then Theme.colors.success else Theme.colors.warn
		else
			buildPill.Visible = false
		end
	end

	if dataPill then
		if not snap.dataSafe then
			dataPill.Text = "Not saving this session"
			dataPill.TextColor3 = Theme.colors.danger
		elseif snap.testAdapter then
			dataPill.Text = "Studio test data"
			dataPill.TextColor3 = Theme.colors.warn
		elseif snap.dataState == "saving" then
			dataPill.Text = "Saving..."
			dataPill.TextColor3 = Theme.colors.accentAlt
		elseif snap.dataState == "loading" then
			dataPill.Text = "Loading your city..."
			dataPill.TextColor3 = Theme.colors.accentAlt
		else
			dataPill.Text = "Saved"
			dataPill.TextColor3 = Theme.colors.success
		end
	end

	HUD.refreshForecast()
end

return HUD
