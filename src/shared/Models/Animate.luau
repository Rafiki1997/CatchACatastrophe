--!strict
-- Data-driven idle animation for Oddities, pets, eggs and runway walkers.
-- Runs on the CLIENT only. Models opt in via attributes written by ModelKit:
--   AnimStyle / AnimSpeed / AnimAmp   -> whole-model motion (relative to base pivot)
--   BasePivot (CFrame attribute)      -> where the model rests; set by the server
--   PathFrom / PathTo / PathStart / PathDuration -> runway walkers: base pivot is
--                                        computed from the path each frame
--   Carried (bool)                    -> skip; the model is welded to a character
--   Rainbow (bool)                    -> hue-cycle tintable parts (Prism variant)
--   HasOrbiters                       -> parts with OrbitRadius revolve around the root
-- Parts:
--   OrbitRadius/OrbitSpeed/OrbitPhase/OrbitTilt/OrbitHeight
--   FlickerMin/FlickerMax             -> transparency pulse
--   ShiftGroup (int)                  -> only one group visible at a time ("shift" style)
--
-- Usage (client):
--   Animate.track(model) -> boolean  -- true when animating (now or already);
--                                    false when the model has no root part YET.
--                                    A model replicated from the server arrives
--                                    before its parts, so a call from the tag
--                                    signal is usually false: call again when
--                                    its children land (WorldAnimator does).
--   Animate.isTracked(model) -> boolean
--   Animate.untrack(model)
--   Animate.step(now, cameraPos)  -- call every RenderStepped

local Animate = {}

type Tracked = {
	model: Model,
	root: BasePart,
	style: string,
	speed: number,
	amp: number,
	phase: number,
	base: CFrame,
	tintable: { BasePart },
	orbiters: { { part: BasePart, radius: number, speed: number, phase: number, tilt: number, axis: string, centre: Vector3, rigid: boolean } },
	flickers: { { part: BasePart, min: number, max: number } },
	shiftGroups: { [number]: { BasePart } },
	shiftCount: number,
	lastShift: number,
	baseHeight: number,
}

local tracked: { [Model]: Tracked } = {}
local CULL_DISTANCE = 220

local function collect(model: Model, t: Tracked)
	t.tintable = {}
	t.orbiters = {}
	t.flickers = {}
	t.shiftGroups = {}
	t.shiftCount = 0
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			local role = inst:GetAttribute("Role")
			if role == "primary" or role == "secondary" or role == "accent" then
				table.insert(t.tintable, inst)
			end
			local radius = inst:GetAttribute("OrbitRadius")
			if typeof(radius) == "number" then
				table.insert(t.orbiters, {
					part = inst,
					radius = radius,
					speed = (inst:GetAttribute("OrbitSpeed") :: number?) or 1,
					phase = (inst:GetAttribute("OrbitPhase") :: number?) or 0,
					tilt = (inst:GetAttribute("OrbitTilt") :: number?) or 0,
					axis = (inst:GetAttribute("OrbitAxis") :: string?) or "Y",
					centre = (inst:GetAttribute("OrbitCentre") :: Vector3?)
						or Vector3.new(0, (inst:GetAttribute("OrbitHeight") :: number?) or 2, 0),
					rigid = inst:GetAttribute("OrbitRigid") == true,
				})
			end
			local fmin = inst:GetAttribute("FlickerMin")
			if typeof(fmin) == "number" then
				table.insert(t.flickers, { part = inst, min = fmin, max = (inst:GetAttribute("FlickerMax") :: number?) or 0.5 })
			end
			local group = inst:GetAttribute("ShiftGroup")
			if typeof(group) == "number" then
				local list = t.shiftGroups[group]
				if not list then
					list = {}
					t.shiftGroups[group] = list
					t.shiftCount = math.max(t.shiftCount, group + 1)
				end
				table.insert(list, inst)
			end
		end
	end
end

function Animate.track(model: Model): boolean
	if tracked[model] then
		return true
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
	if not root then
		return false
	end
	local base = model:GetAttribute("BasePivot")
	local t: Tracked = {
		model = model,
		root = root,
		style = (model:GetAttribute("AnimStyle") :: string?) or "bob",
		speed = (model:GetAttribute("AnimSpeed") :: number?) or 1,
		amp = (model:GetAttribute("AnimAmp") :: number?) or 1,
		phase = math.random() * math.pi * 2,
		base = if typeof(base) == "CFrame" then base else model:GetPivot(),
		tintable = {},
		orbiters = {},
		flickers = {},
		shiftGroups = {},
		shiftCount = 0,
		lastShift = -1,
		baseHeight = (model:GetAttribute("Height") :: number?) or 3,
	}
	collect(model, t)
	tracked[model] = t
	-- keep base pivot in sync when the server moves the model
	model:GetAttributeChangedSignal("BasePivot"):Connect(function()
		local cf = model:GetAttribute("BasePivot")
		if typeof(cf) == "CFrame" then
			t.base = cf
		end
	end)
	model:GetAttributeChangedSignal("AnimSpeed"):Connect(function()
		t.speed = (model:GetAttribute("AnimSpeed") :: number?) or 1
	end)
	return true
end

function Animate.isTracked(model: Model): boolean
	return tracked[model] ~= nil
end

function Animate.untrack(model: Model)
	tracked[model] = nil
end

local function pathPivot(model: Model, now: number): CFrame?
	local from = model:GetAttribute("PathFrom")
	local to = model:GetAttribute("PathTo")
	local start = model:GetAttribute("PathStart")
	local duration = model:GetAttribute("PathDuration")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or typeof(start) ~= "number" or typeof(duration) ~= "number" or duration <= 0 then
		return nil
	end
	local alpha = math.clamp((now - start) / duration, 0, 1)
	local pos = from:Lerp(to, alpha)
	local dir = (to - from)
	if dir.Magnitude < 0.01 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + dir.Unit)
end

local function styleOffset(style: string, tm: number, amp: number): CFrame
	if style == "bob" then
		return CFrame.new(0, math.sin(tm * 2) * 0.18 * amp, 0)
	elseif style == "waddle" then
		return CFrame.new(0, math.abs(math.sin(tm * 4)) * 0.12 * amp, 0) * CFrame.Angles(0, 0, math.sin(tm * 4) * 0.12 * amp)
	elseif style == "hop" then
		local h = math.max(0, math.sin(tm * 3))
		return CFrame.new(0, h * h * 0.9 * amp, 0) * CFrame.Angles(-h * 0.15 * amp, 0, 0)
	elseif style == "flutter" then
		return CFrame.new(math.sin(tm * 1.3) * 0.25 * amp, 0.4 + math.sin(tm * 5) * 0.12 * amp, 0) * CFrame.Angles(0, 0, math.sin(tm * 5) * 0.08)
	elseif style == "sway" then
		return CFrame.Angles(0, math.sin(tm * 1.2) * 0.12 * amp, math.sin(tm * 0.8) * 0.06 * amp)
	elseif style == "spin" then
		return CFrame.new(0, 0.3 + math.sin(tm * 1.5) * 0.15 * amp, 0) * CFrame.Angles(0, tm * 0.9, 0)
	elseif style == "hover" then
		return CFrame.new(0, 0.9 + math.sin(tm * 1.4) * 0.3 * amp, 0) * CFrame.Angles(math.sin(tm * 0.9) * 0.05, 0, math.sin(tm * 1.1) * 0.06)
	elseif style == "orbit" then
		return CFrame.new(0, 0.4 + math.sin(tm * 1.2) * 0.2 * amp, 0) * CFrame.Angles(0, math.sin(tm * 0.5) * 0.2, 0)
	elseif style == "pulse" then
		return CFrame.new(0, math.sin(tm * 2.5) * 0.08 * amp, 0)
	elseif style == "flicker" then
		return CFrame.new(math.sin(tm * 9) * 0.03, 0.2 + math.sin(tm * 2) * 0.1, 0)
	elseif style == "drift" then
		return CFrame.new(math.sin(tm * 0.7) * 0.5 * amp, 0.7 + math.sin(tm * 1.1) * 0.25 * amp, math.cos(tm * 0.7) * 0.5 * amp) * CFrame.Angles(0, tm * 0.3, 0)
	elseif style == "shift" then
		return CFrame.new(0, math.sin(tm * 1.7) * 0.1, 0) * CFrame.Angles(0, math.sin(tm * 0.6) * 0.3, 0)
	end
	return CFrame.new()
end

function Animate.step(now: number, cameraPos: Vector3?)
	for model, t in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		if model:GetAttribute("Carried") then
			continue
		end
		-- Machines and work stations idle when they are not producing. A model
		-- with no Working attribute (every creature) always animates.
		if model:GetAttribute("Working") == false then
			continue
		end
		local base = pathPivot(model, now) or t.base
		if cameraPos and (base.Position - cameraPos).Magnitude > CULL_DISTANCE then
			continue
		end
		-- Overdrive doubles the tempo; a cooling pair slows to a crawl.
		local tempo = 1
		if model:GetAttribute("Overdrive") then
			tempo = 2
		elseif model:GetAttribute("Cooling") then
			tempo = 0.25
		end
		local tm = now * t.speed * tempo + t.phase
		local pivot = base * styleOffset(t.style, tm, t.amp)
		model:PivotTo(pivot)

		if #t.orbiters > 0 then
			for _, o in t.orbiters do
				local angle = tm * o.speed + o.phase
				-- The circle lives in the plane normal to `axis`. "X" and "Z"
				-- give vertical wheels (windmill blades, water wheels, turbines);
				-- "Y" is the default horizontal ring, whose plane `tilt` tips over.
				local local_: CFrame
				if o.axis == "X" then
					local_ = CFrame.new(o.centre) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, o.radius, 0)
				elseif o.axis == "Z" then
					local_ = CFrame.new(o.centre) * CFrame.Angles(0, 0, angle) * CFrame.new(o.radius, 0, 0)
				else
					local_ = CFrame.new(o.centre) * CFrame.Angles(0, 0, o.tilt) * CFrame.Angles(0, angle, 0) * CFrame.new(o.radius, 0, 0)
				end
				local world = pivot * local_
				if o.rigid then
					-- blades and paddles keep the wheel's orientation
					o.part.CFrame = world
				else
					local spin = if o.part:GetAttribute("OrbitNoSpin") then 0 else angle
					o.part.CFrame = CFrame.new(world.Position) * CFrame.Angles(0, spin, spin * 0.5)
				end
			end
		end
		if #t.flickers > 0 then
			for _, f in t.flickers do
				local a = (math.sin(tm * 6) + math.sin(tm * 13.7)) * 0.25 + 0.5
				f.part.Transparency = f.min + (f.max - f.min) * a
			end
		end
		if t.shiftCount > 0 then
			local group = math.floor(tm * 0.8) % t.shiftCount
			if group ~= t.lastShift then
				t.lastShift = group
				for g, parts in t.shiftGroups do
					local hidden = g ~= group
					for _, p in parts do
						p.Transparency = if hidden then 1 else 0
					end
				end
			end
		end
		if model:GetAttribute("Rainbow") then
			local hue = (now * 0.15 + t.phase) % 1
			local col = Color3.fromHSV(hue, 0.55, 1)
			for _, p in t.tintable do
				p.Color = col
			end
		end
	end
end

function Animate.count(): number
	local n = 0
	for _ in tracked do
		n += 1
	end
	return n
end

return Animate
