local usage = [====[

off_map_fix
=======================
Deletes units that are stuck on the map edge.

]====]
local utils = require 'utils'

--validArgs = validArgs or utils.invert({
validArgs = utils.invert({
 'help',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

local count = 0
local creatures = df.global.world.raws.creatures

local function titleize(input)
    return string.gsub(" "..input, "%W%l", string.upper):sub(2)
end

local dwarf_race = df.global.ui.race_id
local dwarf_civ = df.global.ui.civ_id

for i, unit in pairs(df.global.world.units.all) do
    if unit.flags1.incoming then
        local race = creatures.all[unit.race]
        local caste = race.caste[unit.caste]
        local creature_id = race.creature_id
        local caste_id = caste.caste_id
        local race_name = titleize(race.name[0])
        local name = unit.name.has_name and dfhack.TranslateName(unit.name) or 'Nameless'
        local civilization = ( unit.civ_id == dwarf_civ ) and 'Local' or 'Foreigner'
        local print_str = ('%s, %s, %s:'):format(civilization, race_name, name)
        print_str = print_str .. ('%d, %d, %d'):format(unit.pos.x, unit.pos.y, unit.pos.z)
        -- print_str = print_str .. (' %s'):format(tostring(unit.flags1.move_state))
        -- print_str = print_str .. (' %s'):format(tostring(unit.flags1.invader_origin))
        -- print_str = print_str .. (' %s'):format(tostring(unit.flags1.invades))
        -- print_str = print_str .. (' %s'):format(tostring(unit.flags2.calculated_inventory))
        -- print_str = print_str .. (' %s'):format(tostring(unit.path.path))
        unit.flags2.cleanup_2 = true
        print(print_str)
    end
end
