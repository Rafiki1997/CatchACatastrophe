-- Run from Studio's plugin/command context with a raw imported Model and the
-- manifest's assets array. Returns an unparented native library and metadata;
-- callers serialize with SerializationService, never reconstruct MeshParts.
return function(bundle: Model, assets: { any }, libraryName: string)
	assert(bundle:IsA("Model"), "raw bundle must be a Model")
	local expected, meshes = {}, {}
	for _, asset in assets do
		assert(not expected[asset.name], "duplicate manifest asset")
		expected[asset.name] = Vector3.new(table.unpack(asset.dimensions_studs_xyz))
	end
	local count, importScale = 0, nil
	for _, obj in bundle:GetDescendants() do
		if obj:IsA("BasePart") then
			assert(obj:IsA("MeshPart") and expected[obj.Name] and not meshes[obj.Name], "unexpected or duplicate part: " .. obj.Name)
			assert(obj.MeshId:match("^rbxassetid://%d+$") and obj.MeshSize.X > 0 and obj.MeshSize.Y > 0 and obj.MeshSize.Z > 0,
				"native uploaded mesh missing: " .. obj.Name)
			local appearance = obj:FindFirstChildWhichIsA("SurfaceAppearance")
			assert(obj.TextureID ~= "" or (appearance and appearance.ColorMap ~= ""), "texture missing: " .. obj.Name)
			local size = expected[obj.Name]
			local ratio = obj.Size / size
			importScale = importScale or ratio.X
			for _, value in { ratio.X, ratio.Y, ratio.Z } do
				assert(value == value and value > 0 and value < math.huge
					and math.abs(value / importScale - 1) < 0.001, "nonuniform import scale: " .. obj.Name)
			end
			meshes[obj.Name], count = obj, count + 1
		end
	end
	assert(count == #assets and count > 0, "incomplete imported kit")
	local library = Instance.new("Model")
	library.Name = libraryName
	library:SetAttribute("NativeImportedKit", bundle.Name)
	library:SetAttribute("AssetCount", count)
	local report = { importScale = importScale, meshes = {} }
	for _, asset in assets do
		local source, size = meshes[asset.name], expected[asset.name]
		local mesh = source:Clone()
		mesh.Size = size
		mesh.CFrame = CFrame.new(0, size.Y / 2, 0)
		mesh.PivotOffset = CFrame.identity
		mesh.Anchored, mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = true, false, false, false
		mesh.Transparency, mesh.Color = 0, Color3.new(1, 1, 1)
		mesh.Parent = library
		local surface = mesh:FindFirstChildWhichIsA("SurfaceAppearance")
		table.insert(report.meshes, {
			name = mesh.Name, meshId = mesh.MeshId, textureId = mesh.TextureID,
			colorMap = if surface then surface.ColorMap else nil,
			size = { size.X, size.Y, size.Z },
			nativeMeshSize = { mesh.MeshSize.X, mesh.MeshSize.Y, mesh.MeshSize.Z },
		})
	end
	return library, report
end
