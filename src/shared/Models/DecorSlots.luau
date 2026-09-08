--!strict
-- Where a decoration may stand.
--
-- The slots are worked out from the plot itself rather than written down, so
-- they can never drift out of step with the city: a lattice over the deck, with
-- every point that is too close to something already there thrown away. Server
-- and client both call this and get the same answer, so the ghost a player is
-- dragging lands exactly where the server will put the real thing.
--
-- In practice this leaves the forecourt, the strip between the work pads and
-- the collection pad, which is the ground every player crosses on the way to
-- bank. A decoration there is one you actually see.

export type Slot = {
	id: string, -- stable across sessions: derived from the lattice coordinates
	offset: Vector3, -- plot-local, on the deck
}

local DecorSlots = {}

-- The lattice. Wider spacing than the decorations are big, so two neighbours
-- never touch.
--
-- The points sit on multiples of `spacing` in plot-local space, NOT on the
-- bounds below. A slot id is made from its coordinates and is written into
-- save files, so anchoring to the bounds would mean that widening the area
-- later renamed every existing slot, and every decoration a player had
-- placed would quietly fail to come back. Anchored to multiples, widening
-- only ever adds new slots.
DecorSlots.spacing = 4
DecorSlots.minX, DecorSlots.maxX = -26, 26
DecorSlots.minZ, DecorSlots.maxZ = -27, 26
DecorSlots.clearance = 3.5 -- studs of empty deck a decoration needs around it

-- Parts that are the ground or fly over it: standing next to them is fine.
local IGNORED = {
	Platform = true,
	Kerb = true,
	Apron = true,
	Stripe = true,
	NeonTrim = true,
	CraneBridge = true,
	CraneHook = true,
	CraneRailL = true,
	CraneRailR = true,
}

local DECOR_FOLDER = "Decorations"
local MAX_HEIGHT = 14 -- above this it is overhead structure, not an obstacle

local function obstacles(model: Model): { { x: number, z: number, hx: number, hz: number } }
	local base = model:GetPivot()
	local decor = model:FindFirstChild(DECOR_FOLDER)
	local list = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not IGNORED[part.Name] and not (decor and part:IsDescendantOf(decor)) then
			local local_ = base:PointToObjectSpace(part.Position)
			if local_.Y < MAX_HEIGHT then
				table.insert(list, { x = local_.X, z = local_.Z, hx = part.Size.X / 2, hz = part.Size.Z / 2 })
			end
		end
	end
	return list
end

function DecorSlots.idFor(x: number, z: number): string
	return ("s%d_%d"):format(math.round(x), math.round(z))
end

-- Every free point on the lattice, nearest the front of the plot first, so the
-- first slot a player is offered is the one they will walk past.
function DecorSlots.compute(model: Model): { Slot }
	local blocked = obstacles(model)
	local clearance = DecorSlots.clearance
	local slots: { Slot } = {}
	local spacing = DecorSlots.spacing
	local firstX = math.ceil(DecorSlots.minX / spacing) * spacing
	local firstZ = math.ceil(DecorSlots.minZ / spacing) * spacing
	local z = firstZ
	while z <= DecorSlots.maxZ do
		local x = firstX
		while x <= DecorSlots.maxX do
			local free = true
			for _, part in blocked do
				if math.abs(x - part.x) < part.hx + clearance and math.abs(z - part.z) < part.hz + clearance then
					free = false
					break
				end
			end
			if free then
				table.insert(slots, { id = DecorSlots.idFor(x, z), offset = Vector3.new(x, 0, z) })
			end
			x += spacing
		end
		z += spacing
	end
	return slots
end

function DecorSlots.find(model: Model, slotId: string): Slot?
	for _, slot in DecorSlots.compute(model) do
		if slot.id == slotId then
			return slot
		end
	end
	return nil
end

-- Rotation is in eighths of a turn, so a child can spin something to any of the
-- eight sensible angles and never end up with a decoration at 3 degrees.
DecorSlots.rotationSteps = 8

function DecorSlots.angleOf(step: number): number
	return (step % DecorSlots.rotationSteps) * (360 / DecorSlots.rotationSteps)
end

return DecorSlots
