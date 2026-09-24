--!strict
-- Roblox XYZ bounds of the Alpine Outpost kit, exactly as the asset request
-- fixes them: docs/art/regions/2026-09-22-frostbite-peaks/
-- ALPINE-OUTPOST-V2-ASSET-REQUEST.md.
--
-- Width X x Height Y x Depth Z in studs, bottom-centre pivot, front facing the
-- site frame's local -Z. Astra delivered the kit to this contract
-- (assets/frostbite-peaks/alpine-v2/manifest.json, version 3): seventeen sizes
-- kept from Astra's first draft, the lodge, bridge and tent resized to the
-- measured concept, eight new. tools/verify_frostbite_alpine.luau reads that
-- manifest independently and fails on any drift. FrostbitePeaks authors its
-- PropSites to these and FrostbiteAlpineProps refuses any import that does not
-- match them.
local V = Vector3.new

local Spec = {}

Spec.alpine = {
	FP_Alpine_Lodge = V(40, 30, 24),
	FP_Alpine_Bridge = V(10, 7.5, 34),
	FP_Alpine_Shelf_North = V(42.5, 10, 23.5),
	FP_Alpine_Shelf_South = V(29, 10, 15),
	FP_Alpine_Gorge_Rock = V(12, 11, 50),
	FP_Alpine_Cliff_Tall = V(25, 34, 22),
	FP_Alpine_Cliff_Wide = V(29, 20, 21),
	FP_Alpine_Cliff_Block = V(14, 12, 12),
	FP_Alpine_Snow_Rock = V(11, 6, 9),
	FP_Alpine_Snow_Rock_Small = V(5, 3.5, 4.5),
	FP_Alpine_Snow_Drift = V(13, 2.5, 8),
	-- As delivered. V2's firs are slenderer (about 2.6 to 1 against these 1.7);
	-- a slender re-export is a recommended follow-up, not a blocker.
	FP_Alpine_Fir_Tall = V(15, 26, 15),
	FP_Alpine_Fir_Medium = V(11, 18, 11),
	FP_Alpine_Fir_Sapling = V(6, 10, 6),
	FP_Alpine_Frosted_Shrub = V(7, 5, 7),
	FP_Alpine_Grass = V(6, 4, 6),
	FP_Alpine_Tent = V(8, 6, 9),
	FP_Alpine_Woodpile = V(6, 4, 6),
	FP_Alpine_Crate = V(4.5, 4.5, 4.5),
	FP_Alpine_Barrel = V(3.5, 4.5, 3.5),
	FP_Alpine_Camp_Sled = V(5, 2, 3),
	FP_Alpine_Notice_Board = V(4, 5, 1),
	FP_Alpine_Pennant = V(5, 11, 1),
	FP_Alpine_Lantern_Post = V(2.4, 7, 3),
	FP_Alpine_Trail_Post = V(1, 3.5, 1),
	FP_Alpine_Signpost = V(6, 7, 1),
	FP_Alpine_Railing = V(12, 4.5, 1),
	FP_Alpine_Terrace_Post = V(2, 7.5, 2),
} :: { [string]: Vector3 }

-- Names Astra's bundle may also carry that the layout does not place. They are
-- tolerated in the raw import and ignored by the swap.
Spec.unplaced = {
	FP_Alpine_Cliff_Shelf = true,
	FP_Alpine_Icicles = true,
} :: { [string]: boolean }

-- Base-local Roblox sockets, exactly as the delivered manifest reports them.
Spec.sockets = {
	FP_Alpine_Lodge = {
		DoorBase = CFrame.new(4.0, 1.0, -5.5),
		PorchStep = CFrame.new(4.0, 0, -12.0),
		PorchEntry = CFrame.new(4.0, 1.0, -11.0),
		ChimneyTop = CFrame.new(8.5, 30.0, 7.5),
		WindowW = CFrame.new(11.5, 6.75, -5.45),
		WindowE = CFrame.new(-3.5, 6.75, -5.45),
		WindowGable = CFrame.new(4.0, 16.5, -5.45),
		AnnexWindow = CFrame.new(-14.75, 5.5, -0.45),
		PorchLanternW = CFrame.new(14.0, 7.5, -10.7),
		PorchLanternE = CFrame.new(-6.0, 7.5, -10.7),
	},
	FP_Alpine_Bridge = {
		NorthDeck = CFrame.new(0, 1.5, 17.0),
		SouthDeck = CFrame.new(0, 1.5, -17.0),
		DeckMiddle = CFrame.new(0, 0.3, 0),
		LanternNW = CFrame.new(4.6, 7.0, 16.3),
		LanternSE = CFrame.new(-4.6, 7.0, -16.3),
	},
	FP_Alpine_Shelf_North = {
		BridgeLanding = CFrame.new(-9.25, 8.5, 3.75),
		Signpost = CFrame.new(16.75, 8.5, -10.25),
		RailStart = CFrame.new(7.25, 8.5, -11.0),
	},
	FP_Alpine_Shelf_South = {
		StairTop = CFrame.new(0, 8.5, -7.5),
		BridgeLanding = CFrame.new(4.2, 8.5, 7.5),
	},
	FP_Alpine_Cliff_Tall = { TopMount = CFrame.new(0, 34, 0) },
	FP_Alpine_Cliff_Wide = { TopMount = CFrame.new(0, 20, 0) },
	FP_Alpine_Cliff_Block = { TopMount = CFrame.new(0, 12, 0) },
	FP_Alpine_Tent = { DoorBase = CFrame.new(0, 0, -4.5) },
	FP_Alpine_Lantern_Post = { Light = CFrame.new(0, 4.61934, -0.65223) },
	FP_Alpine_Pennant = { PoleBase = CFrame.new(-2.3663, 0, 0.05549) },
	FP_Alpine_Fir_Tall = { TrunkBase = CFrame.new(-0.10574, 0, -0.14616) },
	FP_Alpine_Fir_Medium = { TrunkBase = CFrame.new(-0.16694, 0, 0.36689) },
	FP_Alpine_Fir_Sapling = { TrunkBase = CFrame.new(0.21665, 0, 0.02943) },
	FP_Alpine_Railing = { EndLeft = CFrame.new(-5.56154, 0, 0.02462), EndRight = CFrame.new(5.52842, 0, 0.02462) },
	FP_Alpine_Signpost = { TextUpper = CFrame.new(0, 5.29244, -0.27554), TextLower = CFrame.new(0, 4.05034, -0.27554) },
	FP_Alpine_Notice_Board = { BoardFace = CFrame.new(0.002, 3.179, -0.14) },
} :: { [string]: { [string]: CFrame } }

Spec.manifest = "assets/frostbite-peaks/alpine-v2/manifest.json"

Spec.library = "FrostbiteAlpineTemplates"
Spec.bundle = "AlpineOutpostBundle"

return Spec
