-- Modifies the physical attributes of units matching the filters applied to emulate inheritance of traits from the parents of the unit.
-- Ignores units without a mother (non-historic units spawned from map edge, or those created by world gen)
-- Units that have a parent off map or dead may not work, as the attribute values for those units may not exist
local usage = [====[

genetics
=======================
Passes on physical and mental attributes of the mother and father to the child.

Arguments::

    -creature <name from raws>
        set the target unit(s) via creature raw ID
    -caste <name from raws; requires -species>
        set the target unit(s) via creature and caste raw IDs
    -days <days>
        units older than 0 years and this many days will not be modified
    -dry
        does a dry run without updating values, while still printing results and stats
]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
--validArgs = utils.invert({
 'help',
 'creature',
 'caste',
 'days',
 'dry',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

math.randomseed( os.time() )

local creature = args.creature and args.creature:upper() or false
local caste_arg = args.caste and arg.caste:upper() or false

local day_ticks = 1200.0
local year_days = 336
local year_ticks = year_days * day_ticks

local ticks_filter = args.days and ( tonumber(args.days) * day_ticks ) or day_ticks

local creatures = df.global.world.raws.creatures

local physical_attributes = { 'STRENGTH', 'AGILITY', 'TOUGHNESS', 'ENDURANCE', 'RECUPERATION', 'DISEASE_RESISTANCE' }
local mental_attributes = { 'ANALYTICAL_ABILITY', 'FOCUS', 'WILLPOWER', 'CREATIVITY', 'INTUITION', 'PATIENCE', 'MEMORY', 'LINGUISTIC_ABILITY', 'SPATIAL_SENSE', 'MUSICALITY', 'KINESTHETIC_SENSE', 'EMPATHY', 'SOCIAL_AWARENESS' }

local crit_miss_total = 0
local crit_hit_total = 0
local positive_dom_total = 0
local negative_dom_total = 0
local genius_total = 0
local runt_total = 0
local mutation_total = 0


local function float_date(year, tick)
    return ( year * 1.0 ) + ( tick / year_ticks )
end

local function titleize(input)
    return string.gsub(" "..input, "%W%l", string.upper):sub(2)
end

local function get_creature_id(unit)
    local race_name = creatures.all[unit.race].creature_id
end

-- shuffle the input array, for genetic mutation
local function shuffle(t)
  local n = #t -- gets the length of the table 
  while n < 2 do -- only run if the table has more than 1 element
    local k = math.random(n) -- get a random number
    t[n], t[k] = t[k], t[n]
    n = n - 1
 end
 return t
end

-- add two arrays together
-- first and last determine which section of the two arrays should be added together, rather than the whole
local function add_arrays(one, two, first, last)
    if not #one == #two then
        return
    end
    local return_array = {}
    for i, num in pairs(one) do
        return_array[i] = one[i]
        if i <= last and i >= first and type(2) == type(num) then
            return_array[i] = one[i] + two[i]
        end
    end
    return return_array
end

-- get the eldest of two units presented
-- used solely for determining which unit would be best suited as a surrogate father
local function get_eldest(one, two)
    local one_birth = float_date( one.birth_year, one.birth_time )
    local two_birth = float_date( two.birth_year, two.birth_time )
    if one_birth > two_birth then
        return one
    else
        return two
    end
end

-- create the data structure for storing the genetic data of the parents, and the resultant new values to be applied
local function create_genes()
    local genes = {['inherited'] = {}, ['dominant'] = {}, ['results'] = {}}
    for i, phys_attr in pairs(physical_attributes) do
        genes.inherited[phys_attr] = { [0] = false, false }
        genes.dominant[phys_attr] = { [0] = false, false, false }
        genes.results[phys_attr] = { [0] = false, false, false }
    end
    for i, ment_attr in pairs(mental_attributes) do
        genes.inherited[ment_attr] = { [0] = false, false }
        genes.dominant[ment_attr] = { [0] = false, false, false }
        genes.results[ment_attr] = { [0] = false, false, false }
    end
    return genes
end

-- store the genes of the parents
local function record_genes(genes, parent, entry)
    for i, phys_attr in pairs(physical_attributes) do
        genes.inherited[phys_attr][entry] = parent.body.physical_attrs[phys_attr].value
    end
    for i, ment_attr in pairs(mental_attributes) do
        genes.inherited[ment_attr][entry] = parent.status.current_soul.mental_attrs[ment_attr].value
    end
    return genes
end

-- this function determines which of the genetic values will be set as the dominant value
local function get_dominant(first, second)
    -- This should generate an error, as we shouldn't be calling this function if no parents were found
    if not first and not second then
        return
    -- copy genes here if a parent is missing
    elseif not first then
        first = second
    elseif not second then
        second = first
    end
    local crit_miss = false
    local crit_hit = false
    local low = math.min(first, second) * 1.0
    local high = math.max(first, second) * 1.0
    local max_val = 5000.0 - high
    -- roll 2d20
    local dice = math.random(1, 40)
    local end_value = 0.0
    -- critical miss
    if dice == 1 then
        end_value = low - ( low * 0.1 )
        crit_miss = true
        crit_miss_total = crit_miss_total + 1
        negative_dom_total = negative_dom_total + 1
    -- major miss
    elseif dice == 2 then
        end_value = low - ( low * 0.05 )
        negative_dom_total = negative_dom_total + 1
    -- critical hit
    elseif dice >= 39 then
        end_value = high + ( max_val * 0.25 )
        crit_hit = true
        crit_hit_total = crit_hit_total + 1
        positive_dom_total = positive_dom_total + 1
    -- major hit
    elseif dice >= 37 then
        end_value = high + ( max_val * 0.1 )
        positive_dom_total = positive_dom_total + 1
    -- miss 1/3 chance ( accounting for all misses )
        -- technically should be 1/2 and 1/2, however, DF doesn't have support for miscarraiges or fatal mutations on birth_date
        -- thus, the most unlucky here would not survive to term, or die shortly after birth
            -- TODO?:  Add sudden death due to S.I.D.s, or if this script can trigger on birth, then notify of miscarraige/fatal deformity and kill the baby?
                -- could also possibly subtract blood from the mother, and chance to go crazy on baby death ( !FUN! )
                -- add job to rest in the hospital?
                    -- and 'meeting' job with father and mother?
    elseif dice <= 13 then
        end_value = low
        negative_dom_total = negative_dom_total + 1
    -- hit 2/3 chance ( accounting for all hits )
    elseif dice >= 14 then
        end_value = high
        positive_dom_total = positive_dom_total + 1
    end
    return { [0] = math.floor(end_value), crit_miss, crit_hit }
end

-- set the dominant gene to be used in calculations
-- genes that are valid for use are from either the mother or father
local function set_dominant(genes)
    for i, phys_attr in pairs(physical_attributes) do
        genes.dominant[phys_attr] = get_dominant(genes.inherited[phys_attr][0], genes.inherited[phys_attr][1])
    end
    for i, ment_attr in pairs(mental_attributes) do
        genes.dominant[ment_attr] = get_dominant(genes.inherited[ment_attr][0], genes.inherited[ment_attr][1])
    end
    return genes
end

-- return an array of percentage values for use in modifying the dominant genes
-- the arrays are applied in order of the distance from each of the caste's set values (PHYS_ATT_RANGE|MENT_ATT_RANGE: [lowest:lower:low:median:high:higher:highest])
local function get_range_array(crit_hit)
    local average = {[0] = 0.01, 0.02, 0.03, 0.04, 0.03, 0.02, 0.01}
    local runt = {[0] = 0.04, 0.03, 0.02, 0.01, 0.01, 0.01, 0.01}
    local genius = {[0] = 0.01, 0.01, 0.01, 0.01, 0.02, 0.03, 0.04}
    local dice = math.random(1, 40)
    local return_table = {['crit_miss'] = false, ['crit_hit'] = false, ['ranges'] = average, ['mutated'] = false}
    
    if dice == 1 and not crit_hit then
        return_table.crit_miss = true
        crit_miss_total = crit_miss_total + 1
        local tmp_table = get_range_array( return_table.crit_hit )
        return_table.ranges = add_arrays( runt, tmp_table.ranges, 0, 6 )
        runt_total = runt_total + 1
    elseif dice == 2 and not crit_hit then
        return_table.ranges = runt
        runt_total = runt_total + 1
    elseif dice >= 39 then
        return_table.crit_hit = true
        crit_hit_total = crit_hit_total + 1
        local tmp_table = get_range_array( return_table.crit_hit )
        return_table.ranges = add_arrays( genius, tmp_table.ranges, 0, 6 )
        genius_total = genius_total + 1
    elseif dice >= 37 then
        return_table.ranges = genius
        genius_total = genius_total + 1
    -- mutation!
    elseif dice == 7 then
        return_table = get_range_array( crit_hit )
        return_table.ranges = shuffle( return_table.ranges )
        return_table.mutated = true
        mutation_total = mutation_total + 1
    end
    return return_table
end

-- apply percentage modifiers to the dominant genes, and return a random value inside of the resultant range
local function get_results(dominant_value, caste_range)
    local adjust = get_range_array(dominant_value[2])
    local lowest = 1.0
    if not adjust.crit_miss then
        lowest = caste_range[0]
    end
    local highest = 5000.0
    if not adjust.crit_hit then
        highest = caste_range[6]
    end
    local above_percent = 0.0
    local below_percent = 0.0
    for i, quality in pairs(caste_range) do
        if quality >= dominant_value[0] and not adjust.crit_miss then
            above_percent = above_percent + adjust.ranges[i]
        elseif quality <= dominant_value[0] and not adjust.crit_hit then
            below_percent = below_percent + adjust.ranges[i]
        end
    end
    local low = math.floor( dominant_value[0] - ( ( dominant_value[0] - lowest ) * below_percent ) )
    local high = math.floor( dominant_value[0] + ( ( highest - dominant_value[0] ) * above_percent ) )
    return { [0] = math.random(low, high), adjust.crit_miss, adjust.crit_hit, adjust.mutated }
end

-- apply percentage modifiers to each dominant gene based on how far the value is from average
local function apply_creature_ranges(caste, genes)
    for i, phys_attr in pairs(physical_attributes) do
        genes.results[phys_attr] = get_results(genes.dominant[phys_attr], caste.attributes.phys_att_range[phys_attr])
    end
    for i, ment_attr in pairs(mental_attributes) do
        genes.results[ment_attr] = get_results(genes.dominant[ment_attr], caste.attributes.ment_att_range[ment_attr])
    end
    return genes
end

-- finally update the genes of the target unit, and print what has been done
local function update_genes(unit, genes, print_str)
    local current_value = 0
    local dom_crit = '-'
    local range_crit = '-'
    local mutated = '-'
    for i, phys_attr in pairs(physical_attributes) do
        current_value = unit.body.physical_attrs[phys_attr].value
        new_value = genes.results[phys_attr]
        difference = new_value[0] - current_value
        dom_crit = ( genes.dominant[phys_attr][1] and 'X' ) or ( genes.dominant[phys_attr][2] and '$' ) or '-'
        range_crit = ( new_value[1] and 'X' ) or ( new_value[2] and '$' ) or '-'
        mutated = ( new_value[3] and '?' ) or '-'
        print_str = print_str .. ('\n%19s Old:%8d New:%8d Diff:%8d Crit: %s%s%s'):format(phys_attr, current_value, new_value[0], difference, dom_crit, range_crit, mutated)
        if not args.dry then
            unit.body.physical_attrs[phys_attr].value = new_value[0]
        end
    end
    for i, ment_attr in pairs(mental_attributes) do
        current_value = unit.status.current_soul.mental_attrs[ment_attr].value
        new_value = genes.results[ment_attr]
        difference = new_value[0] - current_value
        dom_crit = ( genes.dominant[ment_attr][1] and 'X' ) or ( genes.dominant[ment_attr][2] and '$' ) or '-'
        range_crit = ( new_value[1] and 'X' ) or ( new_value[2] and '$' ) or '-'
        mutated = ( new_value[3] and '?' ) or '-'
        print_str = print_str .. ('\n%19s Old:%8d New:%8d Diff:%8d Crit: %s%s%s'):format(ment_attr, current_value, new_value[0], difference, dom_crit, range_crit, mutated)
        if not args.dry then
            unit.status.current_soul.mental_attrs[ment_attr].value = new_value[0]
        end
    end
    print_str = print_str .. '\n'
    print(print_str)
end

-- current date as a float where it's valued as year.fraction_of_current_year
local current_date = float_date( df.global.cur_year, df.global.cur_year_tick )
-- same format as above, except that it's the earliest date that is allowable for setting genetic values
local filter_date = ( current_date - ( ticks_filter / year_ticks ) )

-- save these for printing info later
local dwarf_race = df.global.ui.race_id
local dwarf_civ = df.global.ui.civ_id

-- store all the units that have a living mother on the map, and meet the time, species, and caste filters
local units = {}

-- try and use the oldest living male unit of the species if the child has a father off map
local surrogate_fathers = {}

-- Filter units before doing anything else
for i, unit in pairs(df.global.world.units.all) do
    local birth_date = float_date( unit.birth_year, unit.birth_time )
    local race = creatures.all[unit.race]
    local caste = race.caste[unit.caste]
    local creature_id = race.creature_id
    local caste_id = caste.caste_id
    
    if not unit.flags1.dead then
        -- Yes, this may allow for a child to be thier own father
        if unit.sex == 1 then
            if surrogate_fathers[creature_id] then
                surrogate_fathers[creature_id] = get_eldest(surrogate_fathers[creature_id], unit)
            else
                surrogate_fathers[creature_id] = unit
            end
        end
        if ( birth_date >= filter_date ) and ( creature == creature_id or not creature ) and ( caste_arg == caste_id or not caste_arg ) then
            -- As units can arrive on the map pregnant, it is far more typical for the unit to have a mother, but no father, rather than to be missing both
            if unit.relationship_ids[df.unit_relationship_type.Mother] ~= -1 and df.unit.find(unit.relationship_ids[df.unit_relationship_type.Mother]) and not df.unit.find(unit.relationship_ids[df.unit_relationship_type.Mother]).flags1.dead then
                table.insert(units, unit)
            else
                local name = unit.name.has_name and dfhack.TranslateName(unit.name) or 'Nameless'
                local race_name = titleize(race.name[0])
                local civilization = ( unit.civ_id == dwarf_civ ) and 'Local' or 'Foreigner'
                if unit.relationship_ids[df.unit_relationship_type.Father] ~= -1 and df.unit.find(unit.relationship_ids[df.unit_relationship_type.Father]) and not df.unit.find(unit.relationship_ids[df.unit_relationship_type.Father]).flags1.dead then
                    print(('%s, %s, %s born on %.2f, has no mother on the map, but does have their father on the map.'):format(civilization, race_name, name, birth_date))
                else
                    print(('%s, %s, %s born on %.2f, has no mother or father, or they are not on the map.'):format(civilization, race_name, name, birth_date))
                end
            end
        end
    end
end

for i, unit in pairs(units) do
    local race = creatures.all[unit.race]
    local caste = race.caste[unit.caste]
    local creature_id = race.creature_id
    local caste_id = caste.caste_id
    local race_name = titleize(race.name[0])
    local genes = create_genes()
    local name = unit.name.has_name and dfhack.TranslateName(unit.name) or 'Nameless'
    local civilization = ( unit.civ_id == dwarf_civ ) and 'Local' or 'Foreigner'
    local print_str = ('%s, %s, %s:'):format(civilization, race_name, name)
    local mother = df.unit.find(unit.relationship_ids[df.unit_relationship_type.Mother])
    genes = record_genes(genes, mother, 0)
    -- mother will act as father in the event that a surrogate hasn't been located
    local father = mother
    -- Father's that are not on the map do not have unit data
    if unit.relationship_ids[df.unit_relationship_type.Father] ~= -1 and df.unit.find(unit.relationship_ids[df.unit_relationship_type.Father]) and not df.unit.find(unit.relationship_ids[df.unit_relationship_type.Father]).flags1.dead then
        father = df.unit.find(unit.relationship_ids[df.unit_relationship_type.Father])
    elseif surrogate_fathers[creature_id] then
        father = surrogate_fathers[creature_id]
    end
    genes = record_genes(genes, father, 1)
    genes = set_dominant(genes)
    genes = apply_creature_ranges(caste, genes)
    update_genes(unit, genes, print_str)
end
print(('Totals:\n\n  Criticals:\n    Hits: %12d\n    Misses: %10d\n\n  Inherited Genes:\n    Positive: %8d\n    Negative: %8d\n\n  Mutations:\n    Genius: %10d\n    Runt: %12d\n    Strange: %9d\n'):format(crit_hit_total, crit_miss_total, positive_dom_total, negative_dom_total, genius_total, runt_total, mutation_total ))
