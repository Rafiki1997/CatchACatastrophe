--!strict
-- "Crisis": the live Containment Crisis banner that appears over the HUD, and
-- the panel explaining how the event works and what it pays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local E = Config.Events.crisis

local built = false
local gui: ScreenGui
local panel: any
local banner: Frame
local bannerTitle: TextLabel
local bannerTimer: TextLabel
local pylonBars: { any } = {}
local workLabel: TextLabel
local panelBody: TextLabel
local current: Types.CrisisState? = nil

local function phaseColor(phase: string): Color3
	if phase == "warning" then
		return Theme.colors.warn
	elseif phase == "active" then
		return Theme.colors.danger
	elseif phase == "success" then
		return Theme.colors.success
	end
	return Theme.colors.textDim
end

local function renderBanner()
	local state = current
	if not state or not built then
		if built then
			banner.Visible = false
		end
		return
	end
	banner.Visible = true

	local title = ""
	if state.phase == "warning" then
		title = "CONTAINMENT CRISIS INCOMING: " .. state.bossName
	elseif state.phase == "active" then
		title = "CRISIS: " .. state.bossName .. "  ·  hold the pylons"
	elseif state.phase == "success" then
		title = "CONTAINED!"
	else
		title = "The crisis broke loose."
	end
	bannerTitle.Text = title
	bannerTitle.TextColor3 = phaseColor(state.phase)

	local left = math.max(0, state.endsAt - State.now())
	bannerTimer.Text = if state.phase == "success" or state.phase == "failed" then "" else Format.clock(left)

	for i, bar in pylonBars do
		local pylon = state.pylons[i]
		if pylon then
			bar.frame.Visible = true
			local fraction = if pylon.need > 0 then pylon.progress / pylon.need else 0
			bar.set(fraction, "Pylon " .. tostring(i) .. (if pylon.done then "  LOCKED" else ""))
			bar.fill.BackgroundColor3 = if pylon.done then Theme.colors.success else Theme.colors.accentAlt
		else
			bar.frame.Visible = false
		end
	end

	if state.phase == "active" then
		workLabel.Text = ("Your work: %.1f / %d"):format(state.myWork, E.qualifyWork) .. (if state.qualified then "  (qualified)" else "  (hold a pylon to qualify)")
		workLabel.TextColor3 = if state.qualified then Theme.colors.success else Theme.colors.warn
	elseif state.phase == "warning" then
		workLabel.Text = "Head to the arena south of the hub."
		workLabel.TextColor3 = Theme.colors.textDim
	else
		workLabel.Text = ""
	end
end

function M.setCrisis(state: any)
	current = if typeof(state) == "table" then state else nil
	renderBanner()
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	renderBanner()
	if not panel.frame.Visible then
		return
	end
	panelBody.Text = "Every "
		.. tostring(math.floor(E.interval / 60))
		.. " minutes an oversized creature turns up in the arena south of the hub for "
		.. tostring(E.duration)
		.. " seconds.\n\n"
		.. "Hold each of the three containment pylons until they lock in. The work each pylon needs grows with how many people are there, so one person alone can still finish it.\n\n"
		.. "Dodge the boss the same way you dodge a capture hazard. Being hit only pushes you around; you cannot lose creatures or Coins here.\n\n"
		.. "Everyone who does at least "
		.. tostring(E.qualifyWork)
		.. " seconds of pylon work when the crisis is contained gets paid once, scaled to their own city's production (between "
		.. Format.abbreviate(E.rewardMin)
		.. " and "
		.. Format.abbreviate(E.rewardMax)
		.. " Coins). Standing nearby earns nothing.\n\n"
		.. "This event is a bonus. Nothing in your city depends on it."
end

local function refresh()
	M.update(State.get())
end

function M.init()
	if built then
		return
	end
	gui = W.screenGui("Panels", 10)
	if not gui:FindFirstChildOfClass("UIScale") then
		W.attachScale(gui)
	end
	panel = W.panel(gui, "Crisis", "Containment Crisis", UDim2.new(0, 560, 0, 400))
	panelBody = W.label({
		parent = panel.body,
		size = UDim2.new(1, 0, 1, 0),
		textSize = 13,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	-- the banner lives in its own ScreenGui so it sits over the HUD
	local bannerGui = W.screenGui("CatchCrisis", 7)
	W.attachScale(bannerGui)
	banner = W.frame({
		parent = bannerGui,
		name = "CrisisBanner",
		size = UDim2.new(0, 420, 0, 128),
		position = UDim2.new(0.5, 0, 0, 8),
		anchor = Vector2.new(0.5, 0),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.danger,
		strokeThickness = 3,
		visible = false,
	})
	bannerTitle = W.label({
		parent = banner,
		size = UDim2.new(1, -76, 0, 24),
		position = UDim2.new(0, 12, 0, 6),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.danger,
		xalign = Enum.TextXAlignment.Left,
	})
	bannerTimer = W.label({
		parent = banner,
		size = UDim2.new(0, 60, 0, 24),
		position = UDim2.new(1, -12, 0, 6),
		anchor = Vector2.new(1, 0),
		textSize = 16,
		font = Theme.fonts.number,
		color = Theme.colors.warn,
		xalign = Enum.TextXAlignment.Right,
	})
	for i = 1, E.pylons do
		local bar = W.progress(banner, UDim2.new(1, -24, 0, 18), Theme.colors.accentAlt, nil, UDim2.new(0, 12, 0, 32 + (i - 1) * 22))
		pylonBars[i] = bar
	end
	workLabel = W.label({
		parent = banner,
		size = UDim2.new(1, -24, 0, 20),
		position = UDim2.new(0, 12, 1, -24),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.warn,
		xalign = Enum.TextXAlignment.Left,
	})

	-- keep the countdown moving between server pushes
	task.spawn(function()
		while true do
			task.wait(0.5)
			if built and current then
				local left = math.max(0, current.endsAt - State.now())
				bannerTimer.Text = if current.phase == "success" or current.phase == "failed" then "" else Format.clock(left)
			end
		end
	end)

	built = true
	panel.refresh = refresh
	refresh()
end

return M
