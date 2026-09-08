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

export type Unlock =
	{ kind: "region", regionId: string }
	| { kind: "relaunch", count: number }
	| { kind: "crisis", wins: number }
	| { kind: "store" }

export type Cosmetic = {
	id: string,
	family: string, -- "aura" (decorations and plot skins to come)
	name: string,
	desc: string,
	color: Color3,
	preset: string, -- ModelKit particle preset
	rate: number, -- emitter rate; the renderer scales this, never the preset
	source: string, -- "region" | "relaunch" | "crisis" | "store"
	unlock: Unlock,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Cosmetics = {}

Cosmetics.families = { "aura" }

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
} :: { Cosmetic }

Cosmetics.byId = {} :: { [string]: Cosmetic }
Cosmetics.byFamily = {} :: { [string]: { Cosmetic } }
for _, item in Cosmetics.list do
	Cosmetics.byId[item.id] = item
	Cosmetics.byFamily[item.family] = Cosmetics.byFamily[item.family] or {}
	table.insert(Cosmetics.byFamily[item.family], item)
end

-- What a player has to do to get it, in words, for the locked rows.
function Cosmetics.requirement(item: Cosmetic, regionName: ((string) -> string)?): string
	local unlock = item.unlock
	if unlock.kind == "region" then
		local name = if regionName then regionName(unlock.regionId) else unlock.regionId
		return "Open " .. name
	elseif unlock.kind == "relaunch" then
		return "Relaunch " .. tostring(unlock.count) .. (if unlock.count == 1 then " time" else " times")
	elseif unlock.kind == "crisis" then
		return "Win " .. tostring(unlock.wins) .. " crises"
	end
	return "From the Store"
end

return Cosmetics
