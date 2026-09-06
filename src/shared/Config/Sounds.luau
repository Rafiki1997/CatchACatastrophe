--!strict
-- Only sounds that ship inside the Roblox client are used (rbxasset://), so
-- nothing depends on an asset the player cannot access. Any id that fails to
-- load simply plays nothing (Effects.sound pcalls).

local Sounds = {}

Sounds.ids = {
	click = "rbxasset://sounds/volume_slider.ogg",
	tether_start = "rbxasset://sounds/action_swim.mp3",
	tether_tick = "rbxasset://sounds/electronicpingshort.wav",
	capture = "rbxasset://sounds/action_get_up.mp3",
	hit = "rbxasset://sounds/ouch.ogg",
	warn = "rbxasset://sounds/action_falling.ogg",
	break_ = "rbxasset://sounds/oof.ogg",
	deploy = "rbxasset://sounds/action_jump_land.mp3",
	collect = "rbxasset://sounds/impact_water.mp3",
	purchase = "rbxasset://sounds/action_jump.mp3",
	circuit = "rbxasset://sounds/impact_generic.mp3",
	overdrive = "rbxasset://sounds/impact_explosion_03.mp3",
	relaunch = "rbxasset://sounds/impact_explosion_03.mp3",
	crisis = "rbxasset://sounds/action_falling.ogg",
	error = "rbxasset://sounds/oof.ogg",
	quest = "rbxasset://sounds/action_get_up.mp3",
}

Sounds.volume = {
	click = 0.35,
	tether_start = 0.5,
	tether_tick = 0.25,
	capture = 0.8,
	hit = 0.8,
	warn = 0.5,
	break_ = 0.6,
	deploy = 0.6,
	collect = 0.6,
	purchase = 0.6,
	circuit = 0.7,
	overdrive = 0.7,
	relaunch = 0.9,
	crisis = 0.6,
	error = 0.4,
	quest = 0.7,
}

return Sounds
