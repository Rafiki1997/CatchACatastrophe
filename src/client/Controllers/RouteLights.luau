--!strict
-- Marching lights on the routes.
--
-- Floor paint foreshortens to nothing exactly when you are standing on it, so a
-- static road never tells you which way to go. The server builds each route's
-- chevrons as Neon parts tagged "RouteChevron" carrying RouteId / Index / Count.
-- This runs a bright head with a fading tail along every route, toward its
-- destination, so a road reads as a direction from across the plaza.
--
-- Client-only. Honours Settings: with reducedFlashing the lights hold steady,
-- all lit, no motion. Routes far from the camera are left dim and untouched.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local State = require(script.Parent.Parent.State)

local RouteLights = {}

local TAG = "RouteChevron"
local SPEED = 5 -- chevrons per second the head advances (spacing is 11 studs, so ~55 studs/s)
local TRAIL = 3 -- chevrons of fading tail behind the head
local DIM = 0.65 -- an unlit chevron: Neon still glows a little at this transparency
local STEADY = 0.15 -- reducedFlashing: every chevron lit, nothing moves
local CULL = 320 -- studs from the camera beyond which a route is not animated
local TICK = 0.08

type Route = { parts: { BasePart }, index: { [BasePart]: number }, count: number, centre: Vector3 }
local routes: { [string]: Route } = {}

local function add(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local id = inst:GetAttribute("RouteId")
	local index = inst:GetAttribute("Index")
	local count = inst:GetAttribute("Count")
	if typeof(id) ~= "string" or typeof(index) ~= "number" or typeof(count) ~= "number" then
		return
	end
	local route = routes[id]
	if not route then
		route = { parts = {}, index = {}, count = count, centre = inst.Position }
		routes[id] = route
	end
	if route.index[inst] == nil then
		table.insert(route.parts, inst)
		route.index[inst] = index
		route.count = math.max(route.count, count)
		-- running mean: the cull point sits near the middle of the road
		route.centre = route.centre:Lerp(inst.Position, 1 / #route.parts)
	end
	inst.Transparency = DIM
end

local function remove(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	for id, route in routes do
		if route.index[inst] ~= nil then
			route.index[inst] = nil
			local i = table.find(route.parts, inst)
			if i then
				table.remove(route.parts, i)
			end
			if #route.parts == 0 then
				routes[id] = nil
			end
			return
		end
	end
end

local function setAll(transparency: number)
	for _, route in routes do
		for _, p in route.parts do
			p.Transparency = transparency
		end
	end
end

function RouteLights.count(): number
	local n = 0
	for _ in routes do
		n += 1
	end
	return n
end

function RouteLights.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

	local acc = 0
	local steady = false
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0

		local snap = State.get()
		if snap and snap.settings.reducedFlashing == true then
			if not steady then
				setAll(STEADY)
				steady = true
			end
			return
		end
		if steady then
			setAll(DIM)
			steady = false
		end

		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else nil
		local t = workspace:GetServerTimeNow() * SPEED
		for _, route in routes do
			if camPos and (route.centre - camPos).Magnitude > CULL then
				continue
			end
			local count = route.count
			if count < 1 then
				continue
			end
			-- the head runs 0..count and wraps; higher Index is nearer the destination
			local head = t % count
			for _, p in route.parts do
				local behind = (head - (route.index[p] - 1)) % count
				local lit = math.clamp(1 - behind / TRAIL, 0, 1)
				p.Transparency = DIM * (1 - lit)
			end
		end
	end)
end

return RouteLights
