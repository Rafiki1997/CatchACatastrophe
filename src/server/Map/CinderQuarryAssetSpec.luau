--!strict
-- Roblox XYZ bounds of the Cinder Quarry kit, exactly as the approved handoff
-- fixes them: docs/art/regions/2026-09-22-cinder-canyon/
-- CINDER-QUARRY-CLAUDE-HANDOFF.md, "Fixed asset interface -- twelve meshes".
--
-- Bounds are Width X x Height Y x Depth Z in studs. Every asset has a
-- horizontally centred base origin and faces its site frame's local -Z.
-- CinderCanyon authors its PropSites to these; CinderQuarryProps refuses any
-- import that does not match them, which is what catches the 100x scale an
-- FBX conversion can introduce.
local V = Vector3.new

local Spec = {}

Spec.quarry = {
	CC_Quarry_Mine = V(64, 42, 48),
	CC_Quarry_Terrace = V(72, 36, 56),
	CC_Quarry_Hoist = V(20, 22, 16),
	CC_Quarry_Cart = V(11, 8, 14),
	CC_Quarry_Rail = V(12, 1, 26),
	CC_Quarry_Mesa_Large = V(27, 22, 21),
	CC_Quarry_Mesa_Low = V(22, 11, 17),
	CC_Quarry_Cactus_Tall = V(9, 17, 7),
	CC_Quarry_Cactus_Round = V(7, 6, 7),
	CC_Quarry_Agave = V(11, 7, 11),
	CC_Quarry_Flowers = V(6, 4, 6),
	CC_Quarry_Crate = V(6, 6, 6),
} :: { [string]: Vector3 }

-- Delivered base-local Roblox sockets from quarry-v2/manifest.json. The
-- placement verifier reads the JSON independently to catch transcription drift.
Spec.sockets = {
	CC_Quarry_Mine = {
		DoorBase = CFrame.new(-0.2121, 0, -19.5395),
		Lantern = CFrame.new(-17.6773, 16.8, -20.5134),
	},
	CC_Quarry_Terrace = {
		HoistBase = CFrame.new(3.9204, 36, 9.501),
		LavaUpperLip = CFrame.new(-24.0018, 20, -10.4575),
		LavaLowerLip = CFrame.new(-24.0018, 10, -18.8611),
		LavaFoot = CFrame.new(-24.0018, 0.5, -26.2142),
		Crystal01 = CFrame.new(-14.0296, 19, -12.5584),
		Crystal02 = CFrame.new(10.9009, 13, -20.962),
	},
}

-- props-v1, already imported and living in CinderPropTemplates. These meshes
-- were authored for the superseded Sculpted Ravine, so they carry no fixed
-- envelope: a site that names one declares the size it wants and the swap
-- scales the mesh to it, which is what CinderProps always did. Only the three
-- that still match the quarry's art are listed -- charcoal rock beside the
-- lava, amber minerals, and small sandstone rubble.
Spec.reused = {
	CC_Basalt_Wide = true,
	CC_Basalt_Low = true,
	CC_Ember_Tall = true,
	CC_Ember_Fan = true,
	CC_Ember_Small = true,
	CC_Sandstone_Rubble = true,
} :: { [string]: boolean }

Spec.library = {
	CC_Quarry = "CinderQuarryTemplates",
	CC_Reused = "CinderPropTemplates",
}

return Spec
