--!strict
-- Builds a creature model by species id. Shared so the server can spawn wild
-- creatures / pad workers and the client can render Atlas previews in
-- ViewportFrames.
--
--   local model = CreatureModels.build("breeze_bean", "Overcharged")
--
-- Builder modules live in `CreatureBuilders/*` and export
--   { [speciesId] = function(model: Model, root: BasePart, palette, def) end }
-- Each builder adds parts with ModelKit relative to the root (feet at y = 0,
-- facing -Z) and calls Kit.setAnim / Kit.orbiter as needed. It must NOT call
-- Kit.finalize, applyVariant or applyRarityGlow; this module does that.

local Kit = require(script.Parent.ModelKit)
local Config = require(script.Parent.Parent.Config)

local CreatureModels = {}

local builders: { [string]: (Model, BasePart, any, any) -> () } = {}

for _, child in script.Parent.CreatureBuilders:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok and typeof(result) == "table" then
			for id, fn in result do
				builders[id] = fn
			end
		else
			warn("[CreatureModels] failed to load builder", child.Name, result)
		end
	end
end

-- Fallback so a missing builder still yields something visible and named.
local function fallback(model: Model, _root: BasePart, palette, def)
	Kit.blob(model, Vector3.new(2.2, 2, 2.2), CFrame.new(0, 1.2, 0), palette.primary)
	Kit.eyes(model, CFrame.new(0, 1.5, -0.9), 0.7, 0.25)
	Kit.setAnim(model, def.anim, def.animSpeed)
end

function CreatureModels.hasBuilder(id: string): boolean
	return builders[id] ~= nil
end

function CreatureModels.builderIds(): { string }
	local ids = {}
	for id in builders do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- scale: optional uniform scale (event boss uses Config.Events.crisis.bossScale)
function CreatureModels.build(id: string, variant: string?, silhouette: boolean?, scale: number?): Model
	local def = Config.Species.byId[id]
	assert(def, "unknown species " .. tostring(id))
	local model, root = Kit.newModel(def.name)
	model:SetAttribute("SpeciesId", id)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Element", def.element)
	model:SetAttribute("Variant", variant or "Normal")
	-- Egg-only species may have their own builder or borrow another species' builder.
	local builder = builders[def.builder or id] or builders[id] or fallback
	local ok, err = pcall(builder, model, root, def.palette, def)
	if not ok then
		warn("[CreatureModels] builder error for", id, err)
		fallback(model, root, def.palette, def)
	end
	if model:GetAttribute("AnimStyle") == nil then
		Kit.setAnim(model, def.anim, def.animSpeed)
	end
	if silhouette then
		for _, inst in model:GetDescendants() do
			if inst:IsA("BasePart") and inst ~= root then
				inst.Color = Color3.fromRGB(28, 28, 36)
				inst.Material = Enum.Material.SmoothPlastic
				inst.Reflectance = 0
				if inst.Transparency < 1 then
					inst.Transparency = 0
				end
			elseif inst:IsA("ParticleEmitter") or inst:IsA("Light") then
				inst:Destroy()
			end
		end
	else
		if variant and variant ~= "Normal" then
			Kit.applyVariant(model, variant)
		end
		Kit.applyRarityGlow(model, def.rarity)
	end
	local finalScale = scale or def.scale
	if finalScale and finalScale ~= 1 then
		model:ScaleTo(finalScale)
	end
	Kit.finalize(model)
	return model
end

return CreatureModels
