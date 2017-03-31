-- Set the age of the target unit in years
local usage = [====[

set-unit-age
=======================
Set the age of a unit by ID or screen selection.

Arguments::

    -unit <ID#>
        set the target unit via ID number
    -exact <years>
        exactly how old the selected unit should be
        using this will ignore settings for the -low and -high options
    -low <years>
        the lowest age in years that the unit should be
        the highest will, by default, be set to the earliest death age, minus ten years
    -high <years>
        the highest age in years that the unit should be
        the lowest will, by default, be set to the year past childhood, plus five years

]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
--validArgs = utils.invert({
 'help',
 'unit',
 'exact',
 'low',
 'high',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

local function setage(unit,new_birth_year,new_old_year)
    unit.birth_year = new_birth_year
    unit.old_year = new_old_year
    -- Fix for ageless beings
    if new_old_year == -1 then
        unit.old_time = -1
    end
end

local unit = args.unit and df.unit.find(args.unit) or dfhack.gui.getSelectedUnit(true)
if not unit then qerror('A unit needs to be selected on screen or specified with "-unit <ID#>".') end


local name = unit.name.has_name and dfhack.TranslateName(unit.name) or 'Nameless'

local current_year = df.global.cur_year
local birth_year = unit.birth_year
local current_age = current_year - birth_year
local old_year = unit.old_year
local race = df.global.world.raws.creatures.all[unit.race]
local caste = race.caste[unit.caste]
local caste_min_age = caste.misc.maxage_min
local caste_max_age = caste.misc.maxage_max
local child_age = caste.misc.child_age or 0
local remaining_years = old_year - current_year

if old_year == -1 then
    print(("%s is %d year(s) old, born in the year %d, and is ageless.\nThe current year is %d."):format(name, current_age, birth_year, current_year))
else
    print(("%s is %d year(s) old, born in the year %d, and may die of old age no sooner than year %d.\nThe current year is %d, which leaves %s with %d year(s) to live."):format(name, current_age, birth_year, old_year, current_year, name, remaining_years))
end

if not ( args.exact or args.low or args.high ) then
    return
end

local min_age = args.low and tonumber(args.low) or ( child_age + 5 )
local max_age = args.high and tonumber(args.high) or ( caste_min_age - 10 )
math.randomseed( os.time() )
local new_age = args.exact and tonumber(args.exact) or math.random(min_age, max_age)

--local new_age = tonumber(args.exact)
local new_birth_year = current_year - new_age
local random_death_age = math.random(caste_min_age, caste_max_age)
local new_old_year = new_birth_year + random_death_age
-- Fix for immortals
if caste_min_age == -1 then
    new_old_year = -1
end
local new_remaining_years = new_old_year - current_year

setage(unit, new_birth_year, new_old_year)

if new_old_year == -1 then
    print(("%s is %d year(s) old, born in the year %d, and is ageless.\nThe current year is %d."):format(name, new_age, new_birth_year, current_year))
else
    print(("%s is now %d year(s) old, born in the year %d, and may die of old age no sooner than year %d.\nThe current year is %d, which leaves %s with %d year(s) to live."):format(name, new_age, new_birth_year, new_old_year, current_year, name, new_remaining_years))
end
