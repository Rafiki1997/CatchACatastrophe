--!strict
-- Fixed V7 Blender export envelopes, in Roblox studs (X/Y/Z).
local sizes: { [string]: Vector3 } = {
	OO_Gravity_Cradle = Vector3.new(16, 22, 16),
	OO_Gravity_Meteor = Vector3.new(6, 11, 6),
	OO_Orbit_Stone = Vector3.new(2.8, 2.4, 2.6),
	OO_Lunar_Boulder = Vector3.new(8, 4, 6),
	OO_Crystal_Cluster = Vector3.new(4, 5, 4),
	OO_Alien_Mushroom_Tall = Vector3.new(6, 7, 5),
	OO_Alien_Mushroom_Cluster = Vector3.new(4, 3, 3),
	OO_Alien_Fern = Vector3.new(4, 3, 4),
	OO_Star_Bloom_Tuft = Vector3.new(3, 1.2, 3),
	OO_Survey_Drone = Vector3.new(3.2, 2.8, 3.2),
	OO_Drone_Dock = Vector3.new(5, 1.5, 5),
	OO_Sample_Pod = Vector3.new(3, 4, 3),
	OO_Cosmic_Beacon = Vector3.new(1.2, 3, 1.2),
	OO_Field_Lab_Base = Vector3.new(16, 5, 16),
	OO_Field_Lab_Dome_Frame = Vector3.new(16, 6.5, 16),
}
return sizes

