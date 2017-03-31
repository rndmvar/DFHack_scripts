-- Sets the leave_countdown or vanish_countdown of specific species to zero so they move to the map edge and leave
local usage = [====[

deport
=======================
Selects all units of target species and sets their map departure countdown to zero, or the currently selected unit onscreen.
Deported units are added back to the region population count.

Arguments::

    -unit <unit ID#>
        Sets the unit to deport via ID#.
    -race <CREATURE name in raws>
        set the target unit(s)
    -deport
        Tells units of race to path to map edge and leave the map.
    -banish
        This sends the unit directly to The Circus, and adds their sorry soul to the death list.
        This should only be used on units with pathing issues that are causing FPS drops.
    -forest
        Removes the unit from merchant/diplomat/visitor groups.
]====]
local utils = require 'utils'

--validArgs = validArgs or utils.invert({
validArgs = utils.invert({
 'help',
 'unit',
 'race',
 'deport',
 'banish',
 'forest',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

local count = 0

local function deport(unit)
    count = count + 1
    local unit_name = unit.name.has_name and dfhack.TranslateName(unit.name) or 'Nameless'
    local civilization = ( unit.civ_id == dwarf_civ ) and 'Local' or 'Foreigner'
    local leave_countdown = unit.animal.leave_countdown
    local vanish_countdown = unit.animal.vanish_countdown
    local meeting = unit.meeting.state
    print(('%s, %s, %s, leave: %d, vanish: %d, meeting: %d (before)'):format(civilization, race_name, unit_name, leave_countdown, vanish_countdown, meeting))
    if args.deport then
        unit.animal.leave_countdown = 2
        -- Doesn't work on sentient visitors yet.
        unit.following = nil
        unit.meeting.state = 3
    elseif args.banish then
        unit.animal.vanish_countdown = 2
    end
    if args.forest then
        unit.flags1.merchant = false
        unit.flags1.diplomat = false
        unit.flags2.visitor = false
        unit.flags1.forest = true
    end
    leave_countdown = unit.animal.leave_countdown
    vanish_countdown = unit.animal.vanish_countdown
    meeting = unit.meeting.state
    print(('%s, %s, %s, leave: %d, vanish: %d, meeting: %d (after)'):format(civilization, race_name, unit_name, leave_countdown, vanish_countdown, meeting))
end

local dwarf_race = df.global.ui.race_id
local dwarf_civ = df.global.ui.civ_id

local args_race = args.race and args.race:upper() or false

local race_name = 'No such race'
local race_id = -1
if args.race then
    for i, creature in pairs(df.global.world.raws.creatures.all) do
        if creature.creature_id == args_race then
            race_id = i
            race_name = creature.name[0]
            race_name = string.gsub(" "..race_name, "%W%l", string.upper):sub(2)
        end
    end
end

local unit = args.unit and df.unit.find(args.unit) or dfhack.gui.getSelectedUnit(true)

if args.race and not race_id  == -1 then
    for i, unit in pairs(df.global.world.units.active) do
        local flags1 = unit.flags1
        if not flags1.dead then
            if args_race and unit.race == race_id then
                deport(unit)
            end
        end
    end
elseif args.race and race_id == -1 then
    print('ERROR: Race not found.')
    print(usage)
    return
elseif unit then
    deport(unit)
elseif not unit then
    print('ERROR: A unit needs to be selected on screen or specified with "-unit <ID#>".')
    print(usage)
    return
else
    print(usage)
    return
end

print('Units to depart map: '..count)
