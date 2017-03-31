-- Make chickens supply tasty omelets.
--[====[

eggsplosion
===========
Makes chickens want to lay eggs immediately.

Usage:

:eggsplosion:           Make all chickens pregnant
:eggsplosion list:      List IDs of all animals on the map
:eggsplosion ID ...:    Make animals with given ID(s) want to drop eggs

Animals will drop eggs as soon as they can reach an available nest box.

]====]

world = df.global.world

if not dfhack.isWorldLoaded() then
    qerror('World not loaded.')
end

args = {...}
list_only = false
creatures = {}

if #args > 0 then
    for _, arg in pairs(args) do
        if arg == 'list' then
            list_only = true
        else
            creatures[arg:upper()] = true
        end
    end
else
    creatures.BIRD_CHICKEN = true
end

total = 0
total_changed = 0

males = {}
females = {}

for _, unit in pairs(world.units.all) do
    local flags1 = unit.flags1
    if not flags1.dead then
        local id = world.raws.creatures.all[unit.race].creature_id
        males[id] = males[id] or {}
        females[id] = females[id] or {}
        table.insert((dfhack.units.isFemale(unit) and females or males)[id], unit)
    end
end

if list_only then
    print("Type                   Male # Female #")
    -- sort IDs alphabetically
    local ids = {}
    for id in pairs(males) do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in pairs(ids) do
        print(("%22s %6d %8d"):format(id, #males[id], #females[id]))
    end
    return
end

for id in pairs(creatures) do
    local females = females[id] or {}
    total = total + #females
    for _, female in pairs(females) do
        for i, trait in pairs(female.status.misc_traits) do
            if trait.id == df.misc_trait_type.EggSpent then
                print_str = ('Egg Timer (before): %d'):format(trait.value)
                trait.value = math.random(1, 100)
                print(('%s; Egg Timer (after): %d'):format(print_str, female.status.misc_traits[i].value))
                total_changed = total_changed + 1
            end
        end
    end
end

if total_changed ~= 0 then
    print(("%d eggs accelerated."):format(total_changed))
end
if total == 0 then
    qerror("No creatures matched.")
end
print(("Total creatures checked: %d"):format(total))
