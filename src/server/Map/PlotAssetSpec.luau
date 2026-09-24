--!strict
-- Roblox XYZ bounds of the Pocket Power Town plot kit. Astra builds the meshes
-- to these; PlotTemplate authors its PropSites and its stand-in art to these;
-- PlotProps refuses any import that does not match them. Pivot is bottom-centre
-- and an asset's front faces its site frame's local -Z (the plot's front).
return {
	PP_Water_Tower = Vector3.new(6.0, 14.8, 6.0),
	PP_Utility_Workshop = Vector3.new(16.4, 9.5, 6.4),
	PP_Dispatch_Booth = Vector3.new(10.8, 6.9, 9.4),
	PP_Owner_Sign = Vector3.new(12.4, 7.8, 4.2),
	PP_Coin_Platform = Vector3.new(7.4, 0.9, 7.4),
	PP_Pad_Frame = Vector3.new(7.6, 0.62, 7.6),
	PP_Lantern = Vector3.new(1.1, 1.25, 1.1),
	PP_Pipe_Run = Vector3.new(10.0, 2.6, 1.4),
	PP_Pipe_Elbow = Vector3.new(1.4, 2.9, 1.4),
	PP_Shrub_Cluster = Vector3.new(2.6, 1.3, 2.0),
	PP_Flower_Bed = Vector3.new(2.8, 1.25, 1.9),
	PP_Round_Tree = Vector3.new(8.2, 10.2, 8.2),
}
