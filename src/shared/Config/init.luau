--!strict
-- Aggregated game configuration. `require(ReplicatedStorage.Shared.Config)`
-- returns every table below. Systems read from here; nothing is hard-coded.

local Config = {
	Regions = require(script.Regions),
	Rarities = require(script.Rarities),
	Species = require(script.Species),
	Variants = require(script.Variants),
	Circuits = require(script.Circuits),
	Capture = require(script.Capture),
	Economy = require(script.Economy),
	Relaunch = require(script.Relaunch),
	Quests = require(script.Quests),
	Events = require(script.Events),
	Milestones = require(script.Milestones),
	Sounds = require(script.Sounds),
}

Config.GameName = "Catch a Catastrophe!"
Config.CompanyName = "Catastrophe Containment Co."
-- Map layout under comparison (2026-09-07). A: eight cities every 45 degrees and
-- the region roads dog-leg around them. B: six cities seated between the six
-- straight region roads, and the crisis arena moved out past the Frostbite gate
-- (see MapBuilder). Cities per server follows the layout.
Config.MapLayout = "B"
Config.MaxPlayers = if Config.MapLayout == "B" then 6 else 8
-- How far the camera may pull back. Past about 100 studs a creature is a few
-- pixels wide and clicking it fails; 60 still frames a whole city. Applied to
-- the Player at join (StarterPlayer properties do not sync through Rojo here).
Config.CameraMaxZoomDistance = 60
Config.DataVersion = 1
Config.DataStoreName = "CatchCatastrophe_v1"
-- Studio test adapter namespace (in-memory, never touches production keys).
Config.TestNamespace = "CatchCatastrophe_test"

return Config
