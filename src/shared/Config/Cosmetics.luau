--!strict
-- Cosmetics: things that change how you look and nothing else.
--
-- One catalogue for every family (auras now; decorations and plot skins reuse
-- this shape later) and one `source` per item saying how it is obtained. Free
-- items are earned by playing and are the majority on purpose: a city full of
-- players should not read as "paid" versus "not paid".
--
-- The six element auras are the visible record of the map you have opened, one
-- per region, earned by unlocking it. The prestige auras cannot be bought at
-- all, so there is always something money will not get you.
--
-- Auras survive a relaunch. Regions do not (a relaunch closes them again), so
-- ownership is stored per item rather than recomputed from `data.regions`.

-- A coin price is an unlock of its own: earned currency, so it stays on the
-- free side of the line even though it is bought.
export type Unlock =
	{ kind: "region", regionId: string }
	| { kind: "coins", price: number }
	| { kind: "relaunch", count: number }
	| { kind: "crisis", wins: number }
	| { kind: "store" }

export type Cosmetic = {
	id: string,
	family: string, -- "aura" (decorations and plot skins to come)
	name: string,
	desc: string,
	color: Color3,
	preset: string, -- aura: ModelKit particle preset; decor: DecorModels builder id
	rate: number, -- aura emitter rate; the renderer scales this, never the preset
	source: string, -- "region" | "relaunch" | "crisis" | "coins" | "store"
	unlock: Unlock,
	slot: string?, -- decor: the one place on the plot it goes, so no picker is needed
	palette: { platform: Color3, apron: Color3, kerb: Color3 }?, -- skin: what it repaints
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Cosmetics = {}

Cosmetics.families = { "aura", "decor", "skin" }

-- The four corners of the 60x60 platform, clear of the pad grid (pads reach
-- x +-15 and z -6..+34) and of the collection pad. Each decoration owns one
-- corner, so buying one never asks the player where to put it.
Cosmetics.slots = {
	front_left = Vector3.new(-24, 0, -24),
	front_right = Vector3.new(24, 0, -24),
	back_left = Vector3.new(-24, 0, 24),
	back_right = Vector3.new(24, 0, 24),
}

-- Rendering rules the client obeys, kept here so design and code agree.
Cosmetics.render = {
	captureRate = 0.25, -- auras fade to this much while a capture runs, so a telegraph is never lost behind them
	farDistance = 60, -- past this, other players' auras thin out
	farRate = 0.35,
	hideDistance = 220, -- past this they are off entirely
}

Cosmetics.list = {
	-- one per region, earned by opening it
	{ id = "aura_wind", family = "aura", name = "Breeze Trail", desc = "Wisps of wind circle you. Earned by opening Gusty Gardens.", color = rgb(180, 240, 200), preset = "sparkle", rate = 8, source = "region", unlock = { kind = "region", regionId = "gusty_gardens" } },
	{ id = "aura_water", family = "aura", name = "Tide Ring", desc = "Droplets drift around your feet. Earned by opening Splashwater Bay.", color = rgb(110, 190, 255), preset = "rain", rate = 10, source = "region", unlock = { kind = "region", regionId = "splashwater_bay" } },
	{ id = "aura_heat", family = "aura", name = "Ember Coat", desc = "Warm embers rise off you. Earned by opening Cinder Canyon.", color = rgb(255, 120, 60), preset = "fire", rate = 9, source = "region", unlock = { kind = "region", regionId = "cinder_canyon" } },
	{ id = "aura_frost", family = "aura", name = "Frost Halo", desc = "Snow turns slowly overhead. Earned by opening Frostbite Peaks.", color = rgb(170, 230, 255), preset = "stars", rate = 9, source = "region", unlock = { kind = "region", regionId = "frostbite_peaks" } },
	{ id = "aura_storm", family = "aura", name = "Live Wire", desc = "Sparks jump around you. Earned by opening Thunderworks.", color = rgb(255, 235, 110), preset = "lightning", rate = 8, source = "region", unlock = { kind = "region", regionId = "thunderworks" } },
	{ id = "aura_cosmic", family = "aura", name = "Star Field", desc = "Tiny stars orbit you. Earned by opening Orbit Outpost.", color = rgb(200, 130, 255), preset = "motes", rate = 10, source = "region", unlock = { kind = "region", regionId = "orbit_outpost" } },

	-- prestige: never for sale
	{ id = "aura_relaunch_1", family = "aura", name = "Fresh Start", desc = "A quiet glow for relaunching once.", color = rgb(140, 235, 255), preset = "glint", rate = 7, source = "relaunch", unlock = { kind = "relaunch", count = 1 } },
	{ id = "aura_relaunch_5", family = "aura", name = "Old Hand", desc = "Five relaunches. People will ask about this one.", color = rgb(255, 214, 64), preset = "aura", rate = 10, source = "relaunch", unlock = { kind = "relaunch", count = 5 } },
	{ id = "aura_crisis_10", family = "aura", name = "Containment Crew", desc = "Ten crises held. Earned on the pylons, not in a shop.", color = rgb(255, 120, 100), preset = "confetti", rate = 9, source = "crisis", unlock = { kind = "crisis", wins = 10 } },

	-- ---------------------------------------------------------------- decorations
	-- Bought with Coins, one per corner of your city, and visible to anyone who
	-- visits you.
	{ id = "decor_statue", family = "decor", name = "Creature Statue", desc = "A stone creature on a plinth, watching over the front of your city.", color = rgb(196, 192, 200), preset = "statue", rate = 0, source = "coins", unlock = { kind = "coins", price = 4000 }, slot = "front_left" },
	{ id = "decor_fountain", family = "decor", name = "Containment Fountain", desc = "Water that never quite escapes. Very calming.", color = rgb(110, 190, 255), preset = "fountain", rate = 0, source = "coins", unlock = { kind = "coins", price = 12000 }, slot = "front_right" },
	{ id = "decor_banner", family = "decor", name = "Company Banner", desc = "Fly the Catastrophe Containment Co. colours over your lot.", color = rgb(255, 184, 48), preset = "banner", rate = 0, source = "coins", unlock = { kind = "coins", price = 2500 }, slot = "back_left" },
	{ id = "decor_beacon", family = "decor", name = "Signal Beacon", desc = "A slow turning light. Visitors can find you from the hub.", color = rgb(120, 235, 255), preset = "beacon", rate = 0, source = "coins", unlock = { kind = "coins", price = 30000 }, slot = "back_right" },

	-- ---------------------------------------------------------------- plot skins
	-- Repaints the ground your whole city stands on.
	{ id = "skin_default", family = "skin", name = "Company Standard", desc = "The concrete the company issued you. Free.", color = rgb(196, 192, 200), preset = "", rate = 0, source = "coins", unlock = { kind = "coins", price = 0 }, palette = { platform = rgb(196, 192, 200), apron = rgb(150, 156, 170), kerb = rgb(150, 156, 170) } },
	{ id = "skin_meadow", family = "skin", name = "Meadow Turf", desc = "Grass underfoot, like the Gardens came home with you.", color = rgb(120, 190, 100), preset = "", rate = 0, source = "coins", unlock = { kind = "coins", price = 6000 }, palette = { platform = rgb(120, 190, 100), apron = rgb(150, 108, 74), kerb = rgb(96, 168, 92) } },
	{ id = "skin_cinder", family = "skin", name = "Cinder Rock", desc = "Cracked red stone that looks warm even when it is not.", color = rgb(150, 70, 50), preset = "", rate = 0, source = "coins", unlock = { kind = "coins", price = 18000 }, palette = { platform = rgb(150, 70, 50), apron = rgb(90, 46, 38), kerb = rgb(255, 120, 60) } },
	{ id = "skin_cosmic", family = "skin", name = "Deep Space", desc = "The floor of the Outpost, stars and all.", color = rgb(70, 55, 120), preset = "", rate = 0, source = "coins", unlock = { kind = "coins", price = 60000 }, palette = { platform = rgb(45, 40, 70), apron = rgb(70, 55, 120), kerb = rgb(200, 130, 255) } },
} :: { Cosmetic }

Cosmetics.byId = {} :: { [string]: Cosmetic }
Cosmetics.byFamily = {} :: { [string]: { Cosmetic } }
-- Where a worn item is recorded. One slot per family, except decorations,
-- which own a corner each and so can all be out at once.
Cosmetics.slotKeyOf = {} :: { [string]: string }
for _, item in Cosmetics.list do
	Cosmetics.byId[item.id] = item
	Cosmetics.slotKeyOf[item.id] = if item.family == "decor" and item.slot then "decor_" .. item.slot else item.family
	Cosmetics.byFamily[item.family] = Cosmetics.byFamily[item.family] or {}
	table.insert(Cosmetics.byFamily[item.family], item)
end

-- What a player has to do to get it, in words, for the locked rows.
function Cosmetics.requirement(item: Cosmetic, regionName: ((string) -> string)?): string
	local unlock = item.unlock
	if unlock.kind == "coins" then
		return if unlock.price <= 0 then "Free" else "Costs " .. tostring(unlock.price) .. " Coins"
	elseif unlock.kind == "region" then
		local name = if regionName then regionName(unlock.regionId) else unlock.regionId
		return "Open " .. name
	elseif unlock.kind == "relaunch" then
		return "Relaunch " .. tostring(unlock.count) .. (if unlock.count == 1 then " time" else " times")
	elseif unlock.kind == "crisis" then
		return "Win " .. tostring(unlock.wins) .. " crises"
	end
	return "From the Store"
end

-- Coin price, or nil when it is not for sale with Coins.
function Cosmetics.price(item: Cosmetic): number?
	return if item.unlock.kind == "coins" then item.unlock.price else nil
end

return Cosmetics
