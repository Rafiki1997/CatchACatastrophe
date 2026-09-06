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
Config.MaxPlayers = 8
Config.DataVersion = 1
Config.DataStoreName = "CatchCatastrophe_v1"
-- Studio test adapter namespace (in-memory, never touches production keys).
Config.TestNamespace = "CatchCatastrophe_test"

return Config
