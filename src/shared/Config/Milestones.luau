--!strict
-- Collection milestones: permanent cosmetic city decorations and titles,
-- claimable once each when the Atlas reaches the species count.

export type Milestone = {
	count: number,
	decoration: string, -- PlotTemplate decoration key
	decorationName: string,
	title: string,
}

local Milestones = {}

Milestones.list = {
	{ count = 4, decoration = "hazard_flags", decorationName = "Hazard Bunting", title = "Trainee Wrangler" },
	{ count = 8, decoration = "smiling_billboard", decorationName = "Smiling Monster Billboard", title = "Field Agent" },
	{ count = 12, decoration = "pipe_fountain", decorationName = "Pipe Fountain", title = "Disaster Manager" },
	{ count = 18, decoration = "neon_company_sign", decorationName = "Neon Company Sign", title = "Catastrophe Director" },
	{ count = 24, decoration = "golden_statue", decorationName = "Golden Catcher Statue", title = "Master of Mayhem" },
} :: { Milestone }

Milestones.byCount = {} :: { [number]: Milestone }
for _, m in Milestones.list do
	Milestones.byCount[m.count] = m
end

return Milestones
