--!strict
-- Tutorial (7 steps), repeatable quests and 3 rotating daily objectives.
-- Quest progress counters are bumped by the server on: capture, perfect
-- capture, collect, connect, overdrive, production. Rewards are Coins scaled
-- to the player's current normal production so they stay useful at any stage.

export type TutorialStep = {
	step: number,
	title: string,
	body: string,
	target: string, -- client arrow target key (see CONTRACTS section 9)
	info: boolean, -- true = "Got it" button advances; false = server advances on the action
}

export type QuestDef = {
	id: string,
	name: string,
	stat: string, -- counter key: captures | perfect | collects | connects | overdrives | earned | rare_captures | region_captures
	target: number,
	rewardSeconds: number, -- Coins = clamp(cps x rewardSeconds, rewardMin, rewardMax)
	rewardMin: number,
	rewardMax: number,
	regionScoped: boolean, -- daily only: instance picks an accessible region
	desc: string,
}

local Quests = {}

Quests.tutorial = {
	{ step = 1, title = "Head to Gusty Gardens", body = "Follow the arrow to the green gate. Wild creatures roam past it.", target = "region:gusty_gardens", info = false },
	{ step = 2, title = "Catch a Breeze Bean", body = "Get close, press Capture and stay within range while you dodge the gust. Fill the ring to catch it.", target = "species:breeze_bean", info = false },
	{ step = 3, title = "Put it to work", body = "Back in your city, open Creatures and deploy the Breeze Bean on a work pad. Its windmill will start turning.", target = "plot:pad1", info = false },
	{ step = 4, title = "Collect your Coins", body = "Stand on the Collection Pad in your city for one second to move your bank into your wallet.", target = "plot:collect", info = false },
	{ step = 5, title = "Buy an upgrade", body = "Visit the Upgrade Workshop in the hub and buy any upgrade. Tether Speed is a good start.", target = "hub:workshop", info = false },
	{ step = 6, title = "Unlock Splashwater Bay", body = "Save up 2,500 Coins and open the blue gate. New creatures mean new circuits later.", target = "region:splashwater_bay", info = false },
	{ step = 7, title = "Learn about Disaster Circuits", body = "Open the Recipe Book. Two matching creatures on side-by-side pads make a circuit and earn extra. Water + Heat is the first one you can build.", target = "none", info = true },
} :: { TutorialStep }
Quests.tutorialDoneStep = #Quests.tutorial + 1

Quests.repeatable = {
	{ id = "wrangler", name = "Wrangler", stat = "captures", target = 5, rewardSeconds = 90, rewardMin = 150, rewardMax = 2e9, regionScoped = false, desc = "Capture 5 creatures." },
	{ id = "producer", name = "Producer", stat = "earned", target = 0, rewardSeconds = 60, rewardMin = 100, rewardMax = 2e9, regionScoped = false, desc = "Earn Coins from your city." },
	{ id = "engineer", name = "Engineer", stat = "connects", target = 2, rewardSeconds = 150, rewardMin = 300, rewardMax = 2e9, regionScoped = false, desc = "Connect 2 Disaster Circuits." },
	{ id = "overdriver", name = "Overdriver", stat = "overdrives", target = 3, rewardSeconds = 120, rewardMin = 250, rewardMax = 2e9, regionScoped = false, desc = "Run Overdrive 3 times." },
} :: { QuestDef }
-- "producer" target is dynamic: 10 minutes of current production, min 500 (Stats.questTarget).
Quests.producerSeconds = 600
Quests.producerMin = 500

Quests.dailyPool = {
	{ id = "daily_region", name = "Regional Round-Up", stat = "region_captures", target = 3, rewardSeconds = 300, rewardMin = 400, rewardMax = 5e9, regionScoped = true, desc = "Capture 3 creatures in %s." },
	{ id = "daily_perfect", name = "Clean Catches", stat = "perfect", target = 2, rewardSeconds = 360, rewardMin = 500, rewardMax = 5e9, regionScoped = false, desc = "Make 2 perfect captures." },
	{ id = "daily_collect", name = "Payday", stat = "collects", target = 5, rewardSeconds = 240, rewardMin = 300, rewardMax = 5e9, regionScoped = false, desc = "Collect your bank 5 times." },
	{ id = "daily_overdrive", name = "Pedal to the Metal", stat = "overdrives", target = 2, rewardSeconds = 300, rewardMin = 400, rewardMax = 5e9, regionScoped = false, desc = "Run Overdrive 2 times." },
	{ id = "daily_rare", name = "Something Shiny", stat = "rare_captures", target = 1, rewardSeconds = 420, rewardMin = 600, rewardMax = 5e9, regionScoped = false, desc = "Capture a Rare or Legendary creature." },
	{ id = "daily_connect", name = "Wire It Up", stat = "connects", target = 1, rewardSeconds = 300, rewardMin = 400, rewardMax = 5e9, regionScoped = false, desc = "Connect a Disaster Circuit." },
} :: { QuestDef }
Quests.dailyCount = 3
-- Daily pool entries that need something the player cannot yet do are skipped:
-- "connects"/"overdrives" need two circuit-compatible regions unlocked.
Quests.dailyNeedsCircuit = { daily_overdrive = true, daily_connect = true }

Quests.repeatableById = {} :: { [string]: QuestDef }
for _, q in Quests.repeatable do
	Quests.repeatableById[q.id] = q
end
Quests.dailyById = {} :: { [string]: QuestDef }
for _, q in Quests.dailyPool do
	Quests.dailyById[q.id] = q
end

-- Daily reset is UTC midnight; the key is the UTC date string.
function Quests.dayKey(unix: number): string
	local d = os.date("!*t", unix)
	return ("%04d-%02d-%02d"):format(d.year, d.month, d.day)
end

function Quests.secondsUntilReset(unix: number): number
	return 86400 - (unix % 86400)
end

return Quests
