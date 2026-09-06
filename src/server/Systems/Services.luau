--!strict
-- Late-bound service registry. Modules register themselves at the bottom of
-- their file (`S.Economy = Economy`) and reach each other through `S.X` at
-- call time, which avoids circular requires. Main requires every system
-- before the first player can join, so lookups are always populated.

local Services: { [string]: any } = {}

return Services
