# Cinder Quarry — Studio validation run

Everything about this region so far is headless: a Lune build, a rasterised
render of placeholder primitives, and geometric ray tests. Astra's twelve meshes
are now captured in `src/server/Map/CinderQuarryTemplates.rbxm` and have **never
been seen rendered**. This is the run that closes that.

Rojo is already serving this repository on **localhost:34872** (PID 24736).
Paste each snippet into the **Server** command bar (the dropdown next to the
command bar must read *Server*, not *Client*) unless a step says otherwise.

---

## 1 — Sync (Edit mode, before anything else)

1. If Studio is in Play, **stop Play first**. Editing scripts while Play is
   running is what the protocol in `AGENTS.md` forbids.
2. Rojo plugin → **Connect** → `localhost`, port `34872`.
3. Confirm the sync actually landed, in Edit mode:

```lua
local src = game.ServerScriptService.Server.Map.CinderCanyon.Source
print("quarry module:", src:find("Cinder Quarry") ~= nil, "#lines", select(2, src:gsub("\n", "")) + 1)
print("templates:", game.ServerScriptService.Server.Map:FindFirstChild("CinderQuarryTemplates") ~= nil)
```

**Expect:** `quarry module: true`, roughly 750 lines, `templates: true`.
If `quarry module: false` you are still on the old Sculpted Ravine source and
the plugin has not synced — do not go on.

---

## 2 — Boot and read the two suites

Press **Play**. Watch Output. The self test prints 3 seconds in; the live test
runs once your avatar has a plot, within 45 seconds.

**Expect:** `[SelfTest]` and `[LiveTest]` each reporting **0 failures**.
Copy me anything that is not zero, plus any `[MapBuilder]` or `[Encounters]`
warning.

---

## 3 — Did the real meshes actually place?

This is the headline question: the swap is proven headlessly against the
captured library, but Studio is the first place the meshes are truly loaded.

```lua
local r = workspace.Regions.cinder_canyon
print("scenery", r:GetAttribute("SceneryVersion"), r:GetAttribute("ConceptId"))
print("propsVersion", r:GetAttribute("BlenderPropsVersion"), "count", r:GetAttribute("BlenderPropCount"))
print("field", r:GetAttribute("FieldHalf"), "spawnRadius", r:GetAttribute("SpawnRadius"))
local props = r:FindFirstChild("BlenderProps")
print("BlenderProps children", props and #props:GetChildren() or "MISSING")
local sites = r.Landmarks.PropSites
local placed, art = 0, 0
for _, s in sites:GetChildren() do
	if s:GetAttribute("AssetPlaced") then placed += 1 end
	if s:FindFirstChild("PlaceholderArt") then art += 1 end
end
print("sites", #sites:GetChildren(), "placed", placed, "placeholders left", art)
```

**Expect:** `scenery 5 cinder-canyon-v1-03-cinder-quarry`, `propsVersion 1
count 136`, `field 92, 0, 72`, `spawnRadius 72`, `BlenderProps children 136`,
`sites 136 placed 136 placeholders left 0`.

**If `BlenderProps` is MISSING**, the library was rejected — the module is
deliberately all-or-nothing. Run this to find out which check failed:

```lua
local Spec = require(game.ServerScriptService.Server.Map.CinderQuarryAssetSpec)
local lib = game.ServerScriptService.Server.Map.CinderQuarryTemplates
for name, expected in Spec.quarry do
	local m = lib:FindFirstChild(name, true)
	if not m then
		print(name, "MISSING")
	else
		local ratio = m.MeshSize / expected
		print(name, "size", m.Size, "meshId", m.MeshId ~= "", "tex", m.TextureID ~= "", "ratio", ratio)
	end
end
```

Every row should show `size` equal to the contract bounds, `meshId true`,
and a `ratio` whose three components are equal to each other (the importer's
uniform 28.444×). A row whose ratio components differ is axis distortion; a
`meshId false` row means an un-uploaded mesh. Send me the output either way.

---

## 4 — Look at it

Unlock the region and walk it. Cinder entry is 15,000 coins:

```lua
local Profiles = require(game.ServerScriptService.Server.Systems.Profiles)
local S = require(game.ServerScriptService.Server.Systems.Services)
local p = Profiles.get(game.Players:GetPlayers()[1])
S.Economy.addCoins(p, 200000, "studio")
print(S.Workshop.unlockRegion(p, "splashwater_bay"))
print(S.Workshop.unlockRegion(p, "cinder_canyon"))
```

Then walk in from the **south threshold** and northward up the lane. What I need
judged, in order of how likely it is to be wrong:

1. **The rock.** The whole border band, the mine butte and the terrace are now
   real faceted meshes where my render only ever showed boxes. Does the band
   read as one continuous mass, or as separated rocks with gaps?
2. **Mine, rail and cart.** The rail and cart hang off the mine's delivered
   `DoorBase` socket. Does the rail actually meet the doorway, and does the cart
   sit **on** the rail rather than sunk into it or floating?
3. **The hoist** on the terrace shelf — fully on the shelf, hanging load clear of
   anything walkable?
4. **The lava cascade.** Three drops down the terrace's step faces into the pool.
   This was invisible in two earlier iterations, so look hard: is every drop on
   the rock face rather than inside it, and is the pool visible?
5. **Scale and palette** against `comparison-concept-vs-build.png` beside this
   file. The floor is `238,134,86` Sandstone; the render brightens it about 15%,
   so Studio is the first honest read on the colour.
6. **Z-fighting** anywhere — particularly the mesa seams and the terrace steps.

Take screenshots from roughly the concept's angle (south, looking north,
elevated) and send them over.

---

## 5 — Gameplay that the geometry could have broken

```lua
-- creatures are on open floor, not inside rock
local r = workspace.Regions.cinder_canyon
local centre = r:GetPivot().Position
for _, m in workspace:GetDescendants() do
	if m:GetAttribute("EncounterUid") then
		local p = m:GetPivot().Position
		if (p - centre).Magnitude < 200 then
			print(m.Name, "local x", math.floor(p.X - centre.X), "z", math.floor(p.Z - centre.Z))
		end
	end
end
```

Then, still in Play, fire the hazard suite — it unlocks every region, drives a
capture per element and checks the telegraphs, Heat included:

```lua
local f = workspace:FindFirstChild("CaptureHazardTests")
f:SetAttribute("Request", os.clock())
task.wait(25)
print(f:GetAttribute("Status"))
print(f:GetAttribute("Results"))
```

**Expect:** `Status` = `passed`. While it runs, watch that the **Heat telegraph
draws flat on the quarry floor and stays visible** — nothing in this region
raises the walkable surface above y = 0.30, and that was the point of not
laying a new ground skin.

Last, walk the whole 24-wide centre lane end to end, and try to push through the
rock band and into the lava pocket: containment is invisible proxies, so a gap
would let you walk into a rock or stand in lava.

---

## What I do with the results

Send me the Output text and the screenshots. Anything that fails I fix in source
and you re-sync — the whole loop is Rojo, no hand-patching of `.Source`.

Still untested after this run, and not covered here: publishing (yours to do,
manually), and mobile performance of the region's part budget.
