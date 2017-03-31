-- Set the sexual orientation of the selected unit
local usage = [====[

set-unit-orientation
=======================
Sets the selected unit to romance and/or marry a specific sex.
Only the asexual option will unset orientations.

Arguments::

    -unit id
        set the target unit
    -clear
        Clear all current flags from the unit before setting new ones.
    -male [1|2|3]
        Use 1 for romancing males , 2 for marrying males, and 3 for both.
    -female [1|2|3]
        Use 1 for romancing females, 2 for marrying females, and 3 for both.
    -asexual [1|2]
        Use 1 for forbidding marraige with both sexes, and 2 to forbid both marraige and romance.
        This option is handled last, if you want specific orientations, then use -clear

]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
 'help',
 'clear',
 'unit',
 'male',
 'female',
 'asexual',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

local function setorientation(orientations,clear,male,female,asexual)
    local changed = false
    if clear or male or female or asexual then
        changed = true
    end
    if clear then
        orientations.marry_male = false
        orientations.marry_female = false
        orientations.romance_male = false
        orientations.romance_female = false
    end
    if male == 1 then
        orientations.romance_male = true
    elseif male == 2 then
        orientations.marry_male = true
    elseif male == 3 then
        orientations.romance_male = true
        orientations.marry_male = true
    end
    if female == 1 then
        orientations.romance_female = true
    elseif female == 2 then
        orientations.marry_female = true
    elseif female == 3 then
        orientations.romance_female = true
        orientations.marry_female = true
    end
    if asexual > 0 then
        orientations.marry_male = false
        orientations.marry_female = false
        if asexual > 1 then
            orientations.romance_male = false
            orientations.romance_female = false
        end
    end
    return changed
end

-- This will return the english version of the word IDs given in the passed array (used here for getting the last name, but could be for anything)
local function lookup_words(words)
    -- We're adding this all together into a single string
    local return_string = ''
    for i, word_int in ipairs(words) do
        -- Only lookup real entries
        if word_int > -1 then
            -- Add the found word
            local word_str = df.global.world.raws.language.words[word_int].word:lower()
            return_string = return_string .. word_str
        end
    end
    return return_string
end

local unit = args.unit and df.unit.find(args.unit) or dfhack.gui.getSelectedUnit(true)
if not unit then qerror('A unit needs to be selected on screen or specified with "-unit <ID#>".') end

local name = 'Nameless'
if unit.name.has_name then
    -- Get the name of the unit for printing
    local last_name = lookup_words(unit.name.words)
    name = unit.name.first_name .. ' ' .. last_name
    name = string.gsub(" "..name, "%W%l", string.upper):sub(2)
end

local soul = unit.status.current_soul
local orientations = soul.orientation_flags
local romance_male = orientations.romance_male
local marry_male = orientations.marry_male
local romance_female = orientations.romance_female
local marry_female = orientations.marry_female
local race = df.global.world.raws.creatures.all[unit.race]
local caste = race.caste[unit.caste]

print(("%s (before):\n        Romance    Marry\nMale: %8s %8s\nFemale: %6s %8s"):format(name, tostring(romance_male), tostring(marry_male), tostring(romance_female), tostring(marry_female)))

local clear = args.clear or false
local male = args.male and tonumber(args.male) or 0
local female = args.female and tonumber(args.female) or 0
local asexual = args.asexual and tonumber(args.asexual) or 0

local changed = setorientation(orientations,clear,male,female,asexual)

if changed then
    romance_male = orientations.romance_male
    marry_male = orientations.marry_male
    romance_female = orientations.romance_female
    marry_female = orientations.marry_female

    print(("%s (after):\n        Romance    Marry\nMale: %8s %8s\nFemale: %6s %8s"):format(name, tostring(romance_male), tostring(marry_male), tostring(romance_female), tostring(marry_female)))
end
