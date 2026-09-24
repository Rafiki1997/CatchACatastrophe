--!strict
-- Distinct region silhouettes with a clear central capture field. Large props
-- stay around the edge; the entrance is local -Z, facing the hub.
--
-- Every element now has its own hand-built module and this is purely the
-- dispatcher: it works out the region's frame once and hands it on. The
-- generic palette builder that used to stand in for the unbuilt regions went
-- with the last of them, Cosmic.
local Scenery = {}

-- A builder may return a layout spec -- its open field rectangle and any
-- keep-out volumes -- which MapBuilder publishes on the region. Returning
-- nothing keeps the region on the circular bounds it was built with.
function Scenery.build(parent: Model, def: any, centre: Vector3, radius: number, makePart: (any) -> Part): any
	local frame = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))
	if def.element == "Wind" then
		return require(script.Parent.GustyGardens).build(parent, frame, radius, makePart)
	elseif def.element == "Water" then
		return require(script.Parent.SplashwaterBay).build(parent, frame, radius, makePart)
	elseif def.element == "Heat" then
		return require(script.Parent.CinderCanyon).build(parent, frame, radius, makePart)
	elseif def.element == "Frost" then
		return require(script.Parent.FrostbitePeaks).build(parent, frame, radius, makePart)
	elseif def.element == "Storm" then
		require(script.Parent.Thunderworks).build(parent, frame, radius, makePart)
	elseif def.element == "Cosmic" then
		require(script.Parent.OrbitOutpost).build(parent, frame, radius, makePart)
	else
		error("Unknown region scenery element")
	end
	return nil
end

return Scenery
