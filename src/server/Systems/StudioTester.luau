--!strict
-- Studio only. The in-memory test adapter starts every session with an empty
-- city, so checking income, the bank and the collection pad used to mean
-- catching and deploying a creature first. In Studio each tester is handed a
-- Prismatic Big Whoops, the strongest creature (128 x 20 x 2 = 5,120 Coins/s),
-- already working on their first free pad. Never runs outside Studio, and never
-- for a profile backed by real data.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)
local Sync = require(script.Parent.Sync)
local Notify = require(script.Parent.Notify)

local StudioTester = {}

local SPECIES = "the_big_whoops"
local VARIANT = "Prismatic"
local gifted: { [Player]: boolean } = {}
-- The live suite deploys onto pads 1 and 2 a few seconds after the first join and
-- checks what it finds there. Gift only once it reports done (Main.server sets
-- the flag), or after its 45-second deadline has certainly passed.
local HARNESS_DEADLINE = 50
local started = os.clock()

local function gift(profile: Profiles.Profile): boolean
	if not S.City or not profile.plot then
		return false
	end
	local uid = S.City.grantCreature(profile, SPECIES, VARIANT, true)
	if not uid then
		return false
	end
	local placed = false
	for pad = 1, 6 do
		if S.City.deploy(profile, uid, pad) then
			placed = true
			break
		end
	end
	Sync.push(profile)
	local text = "Studio tester: a Prismatic Big Whoops is in your storage."
	if placed then
		text = "Studio tester: a Prismatic Big Whoops is already working for you (5,120 Coins/s)."
	end
	Notify.player(profile.player, "info", text, 7)
	return true
end

function StudioTester.init()
	if not RunService:IsStudio() then
		return
	end
	started = os.clock()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		if not workspace:GetAttribute("LiveTestDone") and os.clock() - started < HARNESS_DEADLINE then
			return
		end
		for player, profile in Profiles.all() do
			if not gifted[player] and profile.testAdapter and profile.plot then
				gifted[player] = true
				local ok, err = pcall(gift, profile)
				if not ok then
					warn("[StudioTester] " .. tostring(err))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		gifted[player] = nil
	end)
end

return StudioTester
