--!strict
-- Authored bounds and base-local sockets from tidepools-v2/manifest.json.
local V = Vector3.new
local Spec = {}
Spec.library = "SplashwaterTidepoolTemplates"
Spec.tidepools = {
	SB_Tidepool_Grotto = V(65, 27, 53),
	SB_Cascade_Rocks = V(60, 42, 50),
	SB_Palm_Tall = V(26, 33, 26),
	SB_Palm_Bent = V(26, 30, 26),
	SB_Palm_Small = V(19, 22, 19),
	SB_Tropical_Leaf_Broad = V(15, 7, 15),
	SB_Tropical_Leaf_Low = V(11, 5, 11),
	SB_Hibiscus_Clump = V(6, 3, 6),
} :: { [string]: Vector3 }
Spec.sockets = {
	SB_Tidepool_Grotto = {
		GrottoFallLip = V(5.183, 9.8539, -4.0568),
		GrottoFallFoot = V(5.183, 0.4807, -8.2053),
		MouthCenter = V(0.1996, 6.7295, -17.5395),
	},
	SB_Cascade_Rocks = {
		UpperLip = V(-0.0372, 31.6859, -3.0141),
		MidPool = V(-0.0372, 16.8331, -9.4601),
		LowerLip = V(-0.0372, 16.8331, -16.8977),
		LowerFoot = V(-0.0372, 0.5941, -19.3769),
	},
	SB_Palm_Tall = {
		CrownPivot = V(-0.3411, 29.0855, 0.3178),
	},
	SB_Palm_Bent = {
		CrownPivot = V(0.4237, 26.447, 0.5324),
	},
	SB_Palm_Small = {
		CrownPivot = V(0.1673, 19.3898, 0.3836),
	},
	SB_Tropical_Leaf_Broad = {
	},
	SB_Tropical_Leaf_Low = {
	},
	SB_Hibiscus_Clump = {
	},
} :: { [string]: { [string]: Vector3 } }
return Spec
