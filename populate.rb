# Add specified caste to regions where it can live.  Good for repopulating a nearly extinct species, or adding one that never lived in the world.
=begin

populate -s CREATURE ( [-r #] [-l #] [-e] [-n] [-b #] [-i #] [-x #] [-f] ) ( [-t #] [-c #] [-o CREATURE] [-a] [-m #] [-p #] [-k] [-z] [-u #] ) [-d] [-v]

=end

# Below assumes that the path to the current script file is Dwarf Fortress=>hack=>scripts
file_dir = File.dirname(__dir__)
ruby_dir = file_dir + File::SEPARATOR + 'ruby'
$LOAD_PATH.unshift(file_dir) unless $LOAD_PATH.include?(file_dir)
$LOAD_PATH.unshift(ruby_dir) unless $LOAD_PATH.include?(ruby_dir)

require 'optparse'

options = {}

$script_args << '-h' if $script_args.empty?

arg_parse = OptionParser.new do |opts|
    opts.default_argv = $script_args # Ruby plugin for Dwarf Fortress does not populate ARGV natively
    opts.banner = "Usage: populate -s CREATURE ( [-r #] [-l #] [-e] [-n] [-b #] [-i #] [-x #] [-f] ) ( [-t #] [-c #] [-o CREATURE] [-a] [-m #] [-p #] [-k] [-z] [-u #] ) [-d] [-v]"
    options[:regions] = 0
    options[:locations] = 0
    options[:display] = false
    options[:verbose] = false
    options[:existing] = false
    options[:require_site] = false
    options[:extinct] = false
    options[:boost] = false
    options[:increment] = false
    options[:fortress] = false
    options[:site_id] = false
    options[:civ_id] = false
    options[:civ_race] = false
    options[:add_race] = false
    options[:set_amount] = 0
    options[:add_amount] = 0
    options[:all_vermin] = false
    options[:remove_animal] = false
    options[:trade_priority] = 0

    opts.separator "Mandatory arguments:"
    opts.on("-s", "--species CREATURE", "Raw creature name to [re]populate.") do |s|
        options[:species] = s.upcase
    end
    opts.separator "Population Filters:"
    opts.on("-r", "--regions #", Integer, "Maximum number of regions to limit creature to.", " - Regions are collections of orthogonally connected locations (x,y coordinates)", "   on the world map that share their major Biome type.") do |r|
        options[:regions] = r
    end
    opts.on("-l", "--locations #", Integer, "Maximum number of locations to limit creature to.", " - Locations are x,y coordinates on the world map.") do |l|
        options[:locations] = l
    end
    opts.on("-e", "--existing", "Add populations only to regions where a regional population already exists.") do |e|
        options[:existing] = e
    end
    opts.on("-n", "--need-site [TYPE]", "Restrict habitable locations to those with sites.", "Valid TYPEs: PlayerFortress, DarkFortress, Cave, MountainHalls,", "  ForestRetreat, Town, ImportantLocation, LairShrine, Fortress, Camp, Monument") do |n|
        options[:require_site] = n ? n : true
    end
    opts.separator "Population Modifiers:"
    opts.on("-b", "--boost #", Integer, "Increment region populations by the specified amount.") do |b|
        options[:boost] = b
    end
    opts.on("-i", "--increment #", Integer, "Increment local populations by the specified amount.") do |i|
        options[:increment] = i
    end
    opts.separator "Site Filters:"
    opts.on("-t", "--site-id #", Integer, "The ID of the site in memory.") do |t|
        options[:site_id] = t - 1
    end
    opts.on("-c", "--civilization-id #", Integer, "The ID of the target civilization in memory.") do |c|
        options[:civ_id] = c
    end
    opts.on("-o", "--civilization-race CREATURE", "The raw creature name of the founder of the civilization.") do |o|
        options[:civ_race] = o.upcase
    end
    opts.separator "Site Modifiers:"
    opts.on("-a", "--add-creature", "The creature [-s] will be added to the filtered site(s) that do not already have any.") do |a|
        options[:add_race] = a
    end
    opts.on("-m", "--set-amount #", Integer, "The creature [-s] will have their population(s) at the filtered site(s) set to # amount.") do |m|
        options[:set_amount] = m
    end
    opts.on("-p", "--add-amount #", Integer, "The creature [-s] will have their population(s) at the filtered site(s) increased by # amount.") do |p|
        options[:add_amount] = p
    end
    opts.on("-k", "--all-vermin", "All vermin creatures will be matched on operations for the target civilization\'s pet list/trading goods and site populations.") do |k|
        options[:all_vermin] = k
    end
    opts.on("-z", "--remove-animal", "The creature [-s] will be removed from the target civilization\'s pet list/trading goods and site populations.") do |z|
        options[:remove_animal] = z
    end
    opts.on("-y", "--trade-priority #", Integer, "The creature [-s] that was added [-a] will have all of their trade goods set to this priority.") do |y|
        options[:trade_priority] = y
    end
    opts.separator "Special options:"
    opts.on("-x", "--extinct #", Integer, "Remove the extinct flag from populations of this species,", " and set the population amount to the specified number.") do |x|
        options[:extinct] = x
    end
    opts.on("-f", "--fortress", "Force adding a population to the current fortress location.", " - Will show a warning if the surroundings/biome don\'t match the creature\'s raws.") do |f|
        options[:fortress] = f
    end
    opts.on("-d", "--display", "Display only.  Do not do any additions.") do |d|
        options[:display] = d
    end
    opts.on("-v", "--verbose", "Print extra information to the console.") do |v|
        options[:verbose] = v
    end
    opts.separator "Examples:"
    opts.separator "  Add Kea birds to 3 regions and 10 locations:"
    opts.separator "    populate -s BIRD_KEA -r 3 -l 10"
    opts.separator "  Now only add to 10 locations in up to 3 regions where Keas already live:"
    opts.separator "    populate -s BIRD_KEA -r 3 -l 10 -e"
    opts.separator "  Or drop some wild populations on the Elves by requiring sites with ForestRetreat:"
    opts.separator "    populate -s BIRD_KEA -r 3 -l 10 -n ForestRetreat"
    opts.separator "  Or maybe just increase already existing populations:"
    opts.separator "    populate -s BIRD_KEA -b 1000 -i 100"
    opts.separator "  Or maybe you want (tame) ones in Elven trade caravans:"
    opts.separator "    populate -s BIRD_KEA -o ELF -a"
    opts.separator "  Or maybe you don\'t want (tame) ones in Elven trade caravans:"
    opts.separator "    populate -s BIRD_KEA -o ELF -z"
    opts.separator "  And you don\'t want (tame) vermin either:"
    opts.separator "    populate -s BIRD_KEA -o ELF -z -k"
    opts.separator "  Or you think the Elves need MORE (TAME) KEAS:"
    opts.separator "    populate -s BIRD_KEA -o ELF -p 1000"
    opts.separator "  Maybe you just want to see what a command WILL do:"
    opts.separator "    populate -s BIRD_KEA -o ELF -p 1000 -d"
    opts.separator "  You really want lots of text printed to your screen:"
    opts.separator "    populate -s BIRD_KEA -o ELF -p 1000 -d -v"
end

begin
  arg_parse.parse!
  mandatory = [:species]
  missing = mandatory.select{ |param| options[param].nil? }
  unless missing.empty?
    raise OptionParser::MissingArgument.new(missing.join(', '))
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts arg_parse
  exit
end

if options[:require_site].is_a?(''.class)
    site_types = {}
    DFHack::WorldSiteType.enum.each do |key, value|
        site_types[value.inspect.sub(':', '')] = value
    end
    options[:require_site] = site_types[options[:require_site]]
end

options[:trade_priority] = 0 if options[:trade_priority] < 0
options[:trade_priority] = 4 if options[:trade_priority] > 4

creature = options[:species]
creature_idx = df.world.raws.creatures.all.index { |cr| cr.creature_id == creature }
if not creature_idx
    puts('ERROR: %s could not be found in creature raws.' % [creature])
    exit
else
    creature = df.world.raws.creatures.all[creature_idx]
    creature_name = creature.name[1].gsub(/\w+/, &:capitalize)
    puts("FOUND: %s (%s: %d) in creature raws." % [creature_name, creature.creature_id, creature_idx])
end
# POPULATION_NUMBER appears to be reversed in array ordering
creature_min = creature.population_number[1]
creature_max = creature.population_number[0]

# Ensure that the creature can exist as a spawned unit before trying to add a population of it.
if creature.flags[:DOES_NOT_EXIST]
    puts('Creature cannot be added, as it is purely mythological.')
    exit
elsif creature.flags[:AnyVermin]
    puts('Adding vermin populations is currently not supported.')
    exit
end

# Convert the target civilization creature name to a creature_raw entry
if options[:civ_race]
    civ_race = options[:civ_race]
    options[:civ_race] = df.world.raws.creatures.all.index { |cr| cr.creature_id == civ_race }
    if not options[:civ_race]
        puts('ERROR: %s could not be found in creature raws.' % [civ_race])
        exit
    end
end

world_data = df.world.world_data
width = world_data.world_width
height = world_data.world_height

fort_id = df.ui.site_id
fortress_site = world_data.sites[fort_id - 1] # site_id is off by one as array addressing starts at zero, while site.id starts at one
fortress_location = nil
# Should never be needed, but just in case the off by one is changed
if not fortress_site or ( fortress_site and fortress_site.id != fort_id )
    world_data.sites.each_with_index do |site, idx|
        if site.id == fort_id
            fortress_site = site
            break
        end
    end
end

# Put two arrays together as a 2D array and test if a set of values is contained within
# a = [0,1]
# b = [2,3]
# test_collection = [ [0, 2], [1, 3] ]
# test_collection.include? [0, 2] => true
# test_collection.include? [1, 2] => false
# test_collection.include? 0 => false
# test_collection.include? [ [0], 2 ] => false
two_includes = lambda{ |first_array, second_array, value_one, value_two|
    test_collection = first_array.collect.with_index {|x, i| [x, second_array[i]]}
    return test_collection.include? [value_one, value_two]
}

surroundings = lambda{ |evilness, savagery|
    flags = {}
    good = evilness <= 32 ? true : false
    evil = evilness >= 67 ? true : false
    benign = savagery <= 32 ? true : false
    savage = savagery >= 67 ? true : false
    e_neutral = ( not good and not evil ) ? true : false
    s_neutral = ( not benign and not savage ) ? true : false
    flags[:GOOD] = good
    flags[:EVIL] = evil
    #flags["e_neutral"] = e_neutral
    #flags["benign"] = benign
    flags[:SAVAGE] = savage
    #flags["s_neutral"] = s_neutral

    description = false
    if good
        description ||= ( benign ) ? 'Serene' : false
        description ||= ( s_neutral ) ? 'Mirthful' : false
        description ||= ( savage ) ? 'Joyous Wilds' : false
    elsif e_neutral
        description ||= ( benign ) ? 'Calm' : false
        description ||= ( s_neutral ) ? 'Wilderness' : false
        description ||= ( savage ) ? 'Untamed Wilds' : false
    elsif evil
        description ||= ( benign ) ? 'Sinister' : false
        description ||= ( s_neutral ) ? 'Haunted' : false
        description ||= ( savage ) ? 'Terrifying' : false
    end
    return flags, description
}

# Get the biome type(s) and description for this location
region_type = lambda{ |rainfall, drainage, elevation, temperature, salinity, biome_type, has_river|
    # Remove the symbol decorator from the biome type symbol
    type_name = biome_type.inspect.sub(':', '')

    # Perform tests on environment values here, and set one boolean flag.  To increase speed of environment checks in the biome_flags section.
    artic = ( temperature <= -5 ) ? true : false
    tropical = ( temperature >= 85 ) ? true : false
    temperate = ( not artic and not tropical ) ? true : false
    fresh_water = ( salinity <= 32 ) ? true : false
    salt_water = ( salinity >= 66 ) ? true : false
    brackish_water = ( not fresh_water and not salt_water ) ? true : false
    fresh_swamp = ( salinity <= 65 ) ? true : false
    wetlands = ( rainfall >= 33 and rainfall <= 65 ) ? true : false
    hills = ( drainage >= 33 ) ? true : false
    marsh = ( not hills and wetlands ) ? true : false
    shrubland = ( hills and wetlands ) ? true : false
    taiga_temp = ( temperature >= -4 and temperature <= 9 ) ? true : false
    forest_conifer = ( hills and rainfall >= 66 and rainfall <= 74 ) ? true : false
    forest_broadleaf = ( hills and rainfall >= 75 ) ? true : false
    grassland = ( rainfall >= 10 and rainfall <= 19 ) ? true : false
    savanna = ( rainfall >= 20 and rainfall <= 32 ) ? true : false
    desert = ( biome_type == :Desert ) ? true : false
    ocean = ( biome_type == :Ocean ) ? true : false
    swamp = ( biome_type == :Swamp ) ? true : false
    lake = ( biome_type == :Lake ) ? true : false
    wood_land = ( biome_type == :Jungle or biome_type == :Steppe or biome_type == :Hills ) ? true : false

    # Check environment to determine Biome (sub)type.
    biome_flags = {}
    biome_flags[:BIOME_MOUNTAIN] = ( biome_type == :Mountains ) ? true : false
    biome_flags[:BIOME_GLACIER] =  ( biome_type == :Glacier ) ? true : false
    biome_flags[:BIOME_TUNDRA] = ( biome_type == :Tundra ) ? true : false
    biome_flags[:BIOME_DESERT_SAND] = ( desert and drainage <= 32 ) ? true : false
    biome_flags[:BIOME_DESERT_ROCK] = ( desert and drainage > 32 and drainage <= 66 ) ? true : false
    biome_flags[:BIOME_DESERT_BADLAND] = ( desert and drainage > 66 ) ? true : false
    biome_flags[:BIOME_OCEAN_ARCTIC] = ( ocean and artic ) ? true : false
    biome_flags[:BIOME_OCEAN_TEMPERATE] = ( ocean and temperate ) ? true : false
    biome_flags[:BIOME_OCEAN_TROPICAL] = ( ocean and tropical ) ? true : false
    biome_flags[:BIOME_SWAMP_TEMPERATE_FRESHWATER] = ( swamp and fresh_swamp and temperate ) ? true : false
    biome_flags[:BIOME_SWAMP_TEMPERATE_SALTWATER] = ( swamp and not fresh_swamp and temperate ) ? true : false
    biome_flags[:BIOME_LAKE_TEMPERATE_FRESHWATER] = ( lake and fresh_water and temperate ) ? true : false
    biome_flags[:BIOME_LAKE_TEMPERATE_BRACKISHWATER] = ( lake and brackish_water and temperate ) ? true : false
    biome_flags[:BIOME_LAKE_TEMPERATE_SALTWATER] = ( lake and salt_water and temperate ) ? true : false
    biome_flags[:BIOME_LAKE_TROPICAL_FRESHWATER] = ( lake and fresh_water and tropical ) ? true : false
    biome_flags[:BIOME_LAKE_TROPICAL_BRACKISHWATER] = ( lake and brackish_water and tropical ) ? true : false
    biome_flags[:BIOME_LAKE_TROPICAL_SALTWATER] = ( lake and brackish_water and tropical ) ? true : false
    biome_flags[:BIOME_RIVER_TEMPERATE_FRESHWATER] = ( has_river and fresh_water and temperate ) ? true : false
    biome_flags[:BIOME_RIVER_TEMPERATE_BRACKISHWATER] = ( has_river and brackish_water and temperate ) ? true : false
    biome_flags[:BIOME_RIVER_TEMPERATE_SALTWATER] = ( has_river and salt_water and temperate ) ? true : false
    biome_flags[:BIOME_RIVER_TROPICAL_FRESHWATER] =  ( has_river and fresh_water and tropical ) ? true : false
    biome_flags[:BIOME_RIVER_TROPICAL_BRACKISHWATER] = ( has_river and brackish_water and tropical ) ? true : false
    biome_flags[:BIOME_RIVER_TROPICAL_SALTWATER] = ( has_river and salt_water and tropical ) ? true : false
    biome_flags[:BIOME_MARSH_TEMPERATE_FRESHWATER] = ( marsh and fresh_swamp and temperate ) ? true : false
    biome_flags[:BIOME_MARSH_TEMPERATE_SALTWATER] = ( marsh and salt_water and temperate ) ? true : false
    biome_flags[:BIOME_MARSH_TROPICAL_FRESHWATER] = ( marsh and fresh_swamp and tropical ) ? true : false
    biome_flags[:BIOME_MARSH_TROPICAL_SALTWATER] = ( marsh and salt_water and tropical ) ? true : false
    biome_flags[:BIOME_FOREST_TAIGA] = ( wood_land and forest_conifer and taiga_temp ) ? true : false
    biome_flags[:BIOME_FOREST_TEMPERATE_CONIFER] = ( wood_land and forest_conifer and temperate and not taiga_temp ) ? true : false
    biome_flags[:BIOME_FOREST_TEMPERATE_BROADLEAF] = ( wood_land and forest_broadleaf and temperate ) ? true : false
    biome_flags[:BIOME_FOREST_TROPICAL_CONIFER] = ( wood_land and forest_conifer and tropical ) ? true : false
    biome_flags[:BIOME_FOREST_TROPICAL_DRY_BROADLEAF] = ( wood_land and forest_broadleaf and tropical and rainfall <= 87 ) ? true : false
    biome_flags[:BIOME_FOREST_TROPICAL_MOIST_BROADLEAF] = ( wood_land and forest_broadleaf and tropical and rainfall > 87 ) ? true : false
    biome_flags[:BIOME_GRASSLAND_TEMPERATE] = ( wood_land and grassland and temperate ) ? true : false
    biome_flags[:BIOME_SAVANNA_TEMPERATE] = ( wood_land and savanna and temperate ) ? true : false
    biome_flags[:BIOME_SHRUBLAND_TEMPERATE] = ( wood_land and shrubland and temperate ) ? true : false
    biome_flags[:BIOME_GRASSLAND_TROPICAL] = ( wood_land and grassland and tropical ) ? true : false
    biome_flags[:BIOME_SAVANNA_TROPICAL] = ( wood_land and savanna and tropical ) ? true : false
    biome_flags[:BIOME_SHRUBLAND_TROPICAL] = ( wood_land and shrubland and tropical ) ? true : false
    biome_flags[:BIOME_SWAMP_TROPICAL_FRESHWATER] = ( swamp and fresh_swamp and tropical ) ? true : false
    biome_flags[:BIOME_SWAMP_TROPICAL_SALTWATER] = ( swamp and salt_water and tropical and drainage > 9 ) ? true : false
    biome_flags[:BIOME_SWAMP_MANGROVE] = ( swamp and salt_water and tropical and drainage <= 9 ) ? true : false

    # Sets description of the Biome per http://dwarffortresswiki.org/index.php/DF2014:Biome#Generating_a_Biome
    description = false
    if rainfall <= 9
        description ||= ( drainage <= 32 ) ? 'Sand Desert' : false
        description ||= ( drainage <= 49 ) ? 'Rocky Wasteland (flat)' : false
        description ||= ( drainage <= 65 ) ? 'Rocky Wasteland (hilly)' : false
        description ||= ( drainage >= 66 ) ? 'Badlands' : false
    elsif rainfall <= 19
        description ||= ( drainage <= 49 ) ? 'Grassland (flat)' : false
        description ||= ( drainage >= 50 ) ? 'Grassland (hilly)' : false
    elsif rainfall <= 32
        description ||= ( drainage <= 49 ) ? 'Savanna (flat)' : false
        description ||= ( drainage >= 50 ) ? 'Savanna (hilly)' : false
    elsif rainfall <= 65
        description ||= ( drainage <= 32 ) ? 'Marsh' : false
        description ||= ( drainage <= 49 ) ? 'Shrubland (flat)' : false
        description ||= ( drainage >= 50 ) ? 'Shrubland (hilly)' : false
    elsif rainfall >= 66
        description ||= ( drainage <= 32 ) ? 'Swamp' : false
        description ||= ( rainfall <= 74 ) ? 'Conifer Forest' : false
        description ||= ( rainfall >= 75 ) ? 'Broadleaf Forest' : false
    end
    if has_river
        description = description ? description + ' & River' : 'River'
    end
    final_out = ( not ( ( ocean and elevation <= 95 ) or ( biome_type == :Mountains and elevation >= 200 ) or ( desert and not has_river ) or biome_type == :Glacier or lake or swamp ) ) ? '%s [%9s]' % [description, type_name] : '[%9s]' % [type_name]
    return biome_flags, final_out
}

# Check to see if a creature's raws will allow it to inhabit this location's biome
can_habitate = lambda{ |creature_raw, surround_flags, biome_flags|
    alignment = true
    alignment_match = nil
    biome = false
    biome_match = nil
    surr_flags = []
    bio_flags = []
    # Alignment flags are exclusionary, if one is set then it must be matched.
    # However, it is not a requirement to have an alignment.  
    # So, we exclude locations where the creature's required alignment is not present.
    surround_flags.each do |key, align|
        if creature_raw.flags[key] and not align
            alignment = false
        elsif creature_raw.flags[key] and align
            alignment_match = key
        end
        if align
            surr_flags.push(key)
        end
    end
    biome_flags.each do |key, bio|
        if creature_raw.flags[key] and bio
            biome = true
            biome_match = key
            # Only one biome match is needed for habitation
            break if not options[:verbose]
        end
        if bio
            bio_flags.push(key)
        end
    end
    return alignment, biome, alignment_match, biome_match, surr_flags, bio_flags
}

# Despite the name, this population tracker is tied to a df.world.world_data.regions entry. Thus it's not a global population, but a population tied to a region
def world_population_alloc(type, race_idx, min=1, max=1, owner=-1)
    pop = DFHack::WorldPopulation.cpp_new
    pop.type = type
    pop.race = race_idx
    pop.count_min = min
    pop.count_max = max
    pop.owner = owner
    return pop
end

# This entry ties a local population entry back to the world population entry, by way of storing the index entry for the world population.
def world_population_ref_alloc(region_x=0, region_y=0, index=0)
    ref = DFHack::WorldPopulationRef.cpp_new
    ref.population_idx = index
    ref.region_x = region_x
    ref.region_y = region_y
    # Adding units to non-surface biomes (caves, caverns, magma sea, underworld) requires more research and work than what can be accomplished right now
    ref.depth = -1
    ref.feature_idx = -1
    ref.cave_id = -1
    return ref
end

# This entry is the local population that is tied to an X,Y coordinate on the world map (via the world_population_reference).
def local_population_alloc(type, race, quantity=1, x=0, y=0, index=0)
    world_pop_reference = world_population_ref_alloc(x, y, index)
    pop = DFHack::LocalPopulation.cpp_new
    pop.population = world_pop_reference
    pop.type = type
    pop.race = race
    pop.quantity = quantity
    pop.quantity2 = quantity
    pop.flags.discovered = false
    pop.flags.extinct = false
    pop.flags.already_removed = false
    return pop
end

def format_flags(flags, join_str=", ")
    flags_array = flags.inspect.sub('>', '').split(" ")[1..100].sort!
    return flags_array.join(join_str)
end

def join_vector(vector, join_str=", ")
    v_arr = []
    vector.each do |item|; v_arr.push(item); end
    return v_arr.join(join_str)
end

def describe_reaction_product(prod, indent="  ")
    description_str = "\n"
    prod.id.each_with_index do |id, idx|
        description_str += "Type: %s\n%s" % [id, indent]
        prod.str.each do |type_str|
            description_str += "%s " % [type_str[idx]]
        end
        description_str += "\n"
    end
    description_str = description_str.split("\n").join("\n" + indent)
    return description_str
end

def describe_material(mat, index=-1, indent="  ")
    description_str = "%s (%d)\nValue: %d\n" % [mat.id, index, mat.material_value]
    description_str += "Flags: %s \n" % [format_flags(mat.flags)]
    description_str += "Reaction Classes: %s\n" % [join_vector(mat.reaction_class)]
    description_str += "Reaction Products: %s\n" % [describe_reaction_product(mat.reaction_product)]
    description_str = description_str.split("\n").join("\n" + indent)
    return description_str + "\n"
end

def material_by_id(mat=-1, matidx=-1)
    if mat == -1 or matidx == -1
        return ""
    end
    # I don't know why entries are off by 19 consistently, but they are
    index = mat - 19
    target_creature = df.world.raws.creatures.all[matidx]
    return "%s %s" % [target_creature.creature_id, describe_material(target_creature.material[index], index, "    ")]
end

# Check for existing local populations so that we are not adding duplicates
get_local = lambda{ |race_index, world_width, world_height, opts|
    incremented = 0
    located = 0

    # Track the matching local populations by x,y coordinates
    local_pops = Array.new(world_width) { Array.new(world_height) }
    df.world.populations.each_with_index do |local_pop, index|
        next if not local_pop.race == race_index
        located += 1
        x = local_pop.population.region_x
        y = local_pop.population.region_y
        local_pops[x][y] = [index, local_pop]
        dead_pop = ( local_pop.flags.already_removed or local_pop.flags.unk3 )
        if opts[:extinct] and local_pop.flags.extinct and not dead_pop and not opts[:display]
            local_pop.flags.extinct = false
            local_pop.quantity = opts[:extinct]
            local_pop.quantity2 = opts[:extinct]
            puts('[%3d, %3d] Repopulated with %d %s' % [x, y, opts[:extinct], creature_name])
        end
        dead_pop = ( local_pop.flags.extinct or local_pop.flags.already_removed or local_pop.flags.unk3 )
        if opts[:increment] and not dead_pop
            old_count = local_pop.quantity
            if not opts[:display]
                local_pop.quantity += opts[:increment]
                # Not sure if quantity2 is linked to quantity, so we'll set it's value, rather than try to raise it.
                # Suspect it may be linked as all values of quantity2 that I've observed have been equal to quantity(1)
                local_pop.quantity2 = local_pop.quantity
            end
            incremented += 1
            puts('[%3d, %3d] Repopulated with %d %s. [old: %d, new: %d]' % [x, y, opts[:increment], creature_name, old_count, local_pop.quantity])
        end
    end
    puts('%d local population(s) modified.' % [incremented]) if incremented > 0
    return local_pops, located
}

get_region = lambda{ |data_world, race_index, opts|
    boosted = 0
    world_pops = {}
    # Check for existing regional populations so that we are not adding duplicates
    data_world.regions.each_with_index do |region, reg_idx|
        region.population.each_with_index do |reg_pop, pop_idx|
            if reg_pop.race == race_index
                world_pops[reg_idx] = [pop_idx, reg_pop]
                if opts[:boost]
                    min = reg_pop.count_min
                    max = reg_pop.count_max
                    if not opts[:display]
                        reg_pop.count_min += opts[:boost]
                        reg_pop.count_max += opts[:boost]
                    end
                    boosted += 1
                    puts("Region %d repopulated with %d %s.\n  Old: [min: %7d, max: %7d]\n  New: [min: %7d, max: %7d]" % [reg_idx, opts[:boost], creature_name, min, max, reg_pop.count_min, reg_pop.count_max])
                end
                break # only one world_population per region
            end
        end
    end
    puts('%d region population(s) modified.' % [boosted]) if boosted > 0
    return world_pops
}

get_site_desc = lambda{ |site|
    site_type = site.type.inspect.sub(':', '')
    civ_id = site.civ_id
    civ = df.world.entities.all[civ_id]
    civ_name = civ.name.to_s.gsub(/\w+/, &:capitalize)
    owner_id = site.cur_owner_id
    entity = df.world.entities.all[owner_id]
    site_name = site.name.to_s.gsub(/\w+/, &:capitalize)
    ent_name = entity.name.to_s.gsub(/\w+/, &:capitalize)
    ent_race_idx = entity.race
    ent_race = df.world.raws.creatures.all[ent_race_idx]
    ent_race_name = ent_race.name[1].gsub(/\w+/, &:capitalize)
    site_description = "\n[%s: %s (%d)]\n  Owner: %s (%d, %s)\n  Civilization: %s (%d)\n" % [site_type, site_name, site.id, ent_name, owner_id, ent_race_name, civ_name, civ_id]
    return site_description
}

get_sites = lambda{ |data_world, race_idx, opts|
    available = {}
    site_pops = {}
    civs_found = []
    # Ruby doesn't have a boolean class, so this is the most readable way to test if an option is boolean or some other type
    is_boolean = [true, false]
    data_world.sites.each_with_index do |site, site_idx|
        # Skip sites where no animals currently reside
        # I don't believe that it is safe to add animal entries if there aren't any already there
        next if site.animals.length == 0
        # Skip sites if the site type does not match the user provided one
        next if not is_boolean.include? opts[:require_site] and not opts[:require_site] == site.type
        # Skip sites if the site ID does not match the user provided one
        next if opts[:site_id] and not opts[:site_id] == ( site_idx + 1 )
        # Skip sites without a valid civilization or the civilization ID does not match the user provided one
        next if site.civ_id == -1 or ( opts[:civ_id] and not opts[:civ_id] == site.civ_id )
        # Skip sites without a valid owner
        next if site.cur_owner_id == -1
        # Skip sites where the civilization's starting race does not match the user selected race
        # Golbin civilizations where the Goblins are all dead, but their former slaves live on will still be marked as GOBLIN
        next if opts[:civ_race] and not opts[:civ_race] == df.world.entities.all[site.cur_owner_id].race
        display_str = get_site_desc[site]
        found_match = false
        site.animals.each_with_index do |animal, animal_idx|
            animal_raws = df.world.raws.creatures.all[animal.race]
            animal_id = animal_raws.creature_id
            animal_name = animal_raws.name[1].gsub(/\w+/, &:capitalize)
            # animal.count_min is always the exact number of creatures currently present on the site
            pop_min = animal.count_min
            # animal.count_max is always 10000001 (infinite) for site populations
            #pop_max = animal.count_max
            animal_str = "%33s (%26s): %7d\n" % [animal_name, animal_id, pop_min]
            if animal.race == race_idx or (options[:all_vermin] and animal_raws.flags[:AnyVermin])
                site_pops[site_idx] = animal
                found_match = true
                civs_found.push(site.civ_id) if not civs_found.include? site.civ_id
                animal_str.sub!("\n", " !MATCH!\n") if opts[:verbose]
                display_str += animal_str if not opts[:verbose]
            end
            display_str += animal_str if opts[:verbose]
        end
        available[site_idx] = site if not found_match
        puts(display_str) if found_match or opts[:verbose]
    end
    return available, site_pops, civs_found
}

check_location = lambda{ |data_world, creature_raw, x, y, sorted_regions, local_pops, populatable, count, filtered_sites, opts|
    # Get the region map for this location
    location = data_world.region_map[x][y]
    region_id = location.region_id
    # Get the region itself for this location
    world_region = data_world.regions[region_id]
    # Check the surroundings
    surround_flags, surround_description = surroundings[location.evilness, location.savagery]
    # Check the biome
    has_river = location.flags[0]
    has_site = location.flags[3]
    site_type_match = false
    biome_flags, biome_description = region_type[location.rainfall, location.drainage, location.elevation, location.temperature, location.salinity, world_region.type, has_river]
    # Check if the creature can habitate here given the surroundings and biome
    alignment, biome, alignment_match, biome_match, surr_flags, bio_flags = can_habitate[creature_raw, surround_flags, biome_flags]
    # Both must be true, or both must be false
    # (T&T) To use existing, the flag must be set, and there must be an established regional population.
    # (F&F) To not use existing, the flag must not be set, and there must be no existing regional population.
    use_existing = ( ( opts[:existing] and sorted_regions[region_id] ) or ( not opts[:existing] and not sorted_regions[region_id] ) )
    location_info = {region: region_id, x: x, y: y, surr_desc: surround_description, biome_desc: biome_description, site: false, sites: false}
    if has_site
        location_info[:sites] = location.sites
        site_str = ''
        location.sites.each do |site|
            site_str += '%s, ' % [site.type.inspect.sub(':', '')]
            if ( opts[:require_site] and opts[:require_site].is_a?(true.class) ) or opts[:require_site] == site.type
                site_type_match = true
            end
        end
        location_info[:site] = site_str
    end
    if opts[:verbose]
        puts("[%3d, %3d] Alignment match: %s; type: %s; Biome match: %s; type: %s;\n  Alignment: %s\n  Biomes: %s\n  Sites: %s\n" % [x, y, alignment, alignment_match, biome, biome_match, surr_flags.inspect, bio_flags.inspect, location_info[:site]])
    end
    if opts[:fortress] and not local_pops[x][y] and x == fortress_site.pos.x and y == fortress_site.pos.y
        fortress_location = location_info
        if not alignment
            puts('Warning: %s despise the %s surroundings of your fort\'s location.' % [creature_name, surround_description])
        end
        if not biome
            puts('Warning: %s wither in the %s biome of your fort\'s location.' % [creature_name, biome_description])
        end
    end
    if alignment and biome and use_existing and not local_pops[x][y]
        if not populatable[region_id]
            populatable[region_id] = []
        end
        count += 1
        if opts[:require_site] and not site_type_match
            filtered_sites += 1
        else
            populatable[region_id].push(location_info)
        end
    end
    return populatable, count, filtered_sites
}

get_available_regions = lambda{ |data_world, creature_raw, sorted_regions, local_pops, world_width, world_height, opts|
    available = {}

    min_x = 0
    max_x = world_width - 1 # no off by one errors please
    min_y = 0
    max_y = world_height - 1 # no off by one errors please

    x_range = (min_x..max_x).to_a
    y_range = (min_y..max_y).to_a

    count = 0
    sites_filtered = 0
    # Go through each location and check it's biome for if the selected creature can habitate that location
    x_range.each do |x|
        y_range.each do |y|
            available, count, sites_filtered = check_location[data_world, creature_raw, x, y, sorted_regions, local_pops, available, count, sites_filtered, opts]
        end
    end
    return available, count, sites_filtered
}

add_region_pops = lambda{ |data_world, populatable, sorted_regions, count_location, sites_filtered, opts|
    # Get the list of regions
    region_keys = populatable.keys
    # Sort the region list by number of habitable locations contained within each region
    region_keys.sort_by!{ |key| populatable[key].length }
    # Reverse the sort, so that the most habitable regions are at the begining of the list, rather than the end
    region_keys.reverse!
    # Remove regions past the maximum allowed amount.  This will remove the regions with the least number of habitable locations.
    # -- doesn't delete them from the actual table, just our key map
    region_keys.slice!(opts[:regions]..65536)
    # Take the locations in all of the remaining regions, and put them into a flat/one dimensional list
    flat_locations = []
    region_keys.each do |key|
        populatable[key].each do |location|
            flat_locations.push(location)
        end
    end
    # Randomly sort the list of locations
    flat_locations.shuffle!
    # Remove locations past the maximum allowed amount (65 default, or what was selected by the user)
    flat_locations.slice!(opts[:locations]..65536)
    if fortress_location
        if flat_locations.length >= opts[:locations]
            flat_locations.pop()
        end
        flat_locations.push(fortress_location)
    end
    # Sorts the remaining locations by multiplying their x,y values.  This effectively groups most of the locations by region too.
    flat_locations.sort_by!{ |loc| loc[:x] * loc[:y] }
    exist_desc = ( opts[:existing] ) ? 'existing' : 'new'
    location_str = "%s can live in %d %s region(s), which contain %d new location(s) that are available for habitation.\nFilters limit future habitation to %d region(s) within which %d location(s) can be inhabited." % [creature_name, populatable.length, exist_desc, count_location, region_keys.length, flat_locations.length, sites_filtered]
    location_str += "\n Of the potential locations for habitation, %d lost consideration for lack of a [matching] site." % [sites_filtered] if sites_filtered > 0
    work_str = "\n"
    work_str += "\nDRY RUN:\n" if opts[:display]
    flat_locations.each do |location|
        location_str += "\n[%3d, %3d]: Surroundings: %13s; Biome: %45s; RegionID: %4d" % [location[:x], location[:y], location[:surr_desc], location[:biome_desc], location[:region]]
        if location[:site]
            location_str += "; Sites: %s" % [location[:site].gsub(/, $/, '')]
        end
        region_id = location[:region]
        world_region = data_world.regions[region_id]
        region_populations = world_region.population
        if not sorted_regions[region_id]
            work_str += "[RegionID: %d] New region population added.\n" % [region_id]
            # skip doing actual work if display flag is set
            if not opts[:display]
                new_region_pop = world_population_alloc(:Animal, creature_idx, creature_min, creature_max, -1)
                region_populations.push(new_region_pop)
                pop_idx = region_populations.length - 1 # no off by one errors please
                sorted_regions[region_id] = [pop_idx, new_region_pop]
            end
        elsif not opts[:display]
            pop_idx = sorted_regions[region_id][0]
        end
        new_amount = rand(creature_min..creature_max)
        work_str += "[%3d, %3d] New local population of %d %s added.\n" % [location[:x], location[:y], new_amount, creature_name]
        next if opts[:display]
        new_local_pop = local_population_alloc(:Animal, creature_idx, new_amount, location[:x], location[:y], pop_idx)
        df.world.populations.push(new_local_pop)
    end
    puts(location_str + work_str)
}

def get_empty_prices()
    return_hash = {}
    DFHack::EntitySellCategory::ENUM.values.each do |key|
        return_hash[key] = []
    end
    return return_hash
end

def get_sell_prices(civ_idx=-1)
    civ = df.world.entities.all[civ_idx]
    sell_prices = nil
    sell_requests = nil
    civ.meeting_events.each do |meeting|
        next if not meeting.sell_prices
        sell_prices = meeting.sell_prices.price
        sell_requests = meeting.sell_prices.items.priority
    end
    df.ui.dip_meeting_info.each do |meeting|
        next if not meeting.civ_id == civ.id
        # For that brief point in time where the diplomat has entered the map, but not met with the noble to discuss exports/imports
        sell_requests = meeting.sell_requests.priority if meeting.sell_requests
        meeting.events.each do |event|
            next if event.sell_prices == nil
            sell_prices = event.sell_prices.price
            sell_requests = event.sell_prices.items.priority
        end
    end
    return sell_prices, sell_requests
end

# remove items at given indexes in all vectors passed in the vectors array
def remove_vector_items(indexes=[], vectors=[])
    # sort indexes, then remove duplicates (shouldn't ever be any)
    # then reverse their order so that removals aren't targeting the wrong item
    indexes.sort!
    indexes.uniq!
    indexes.reverse!
    vectors.each do |vector|
        indexes.each do |idx|
            vector.delete_at(idx)
        end
    end
end

def add_material_by_type(creature_idx=-1, material_idx=-1, materials)
    return materials if creature_idx == -1 or material_idx == -1
    creature_raws = df.world.raws.creatures.all[creature_idx]
    # I don't know why materials indexes are off by 19 right now, but they are
    adjusted_index = material_idx - 19
    material = creature_raws.material[adjusted_index]
    flags = material.flags
    new_mat = [creature_idx, material_idx]
    materials[:Leather].push(new_mat) if flags[:LEATHER] and not materials[:Leather].include? new_mat
    materials[:Silk].push(new_mat) if flags[:SILK] and not materials[:Silk].include? new_mat
    materials[:Wool].push(new_mat) if flags[:YARN] and not materials[:Wool].include? new_mat
    materials[:Bone].push(new_mat) if flags[:BONE] and not materials[:Bone].include? new_mat
    materials[:Shell].push(new_mat) if flags[:SHELL] and not materials[:Shell].include? new_mat
    materials[:Pearl].push(new_mat) if flags[:PEARL] and not materials[:Pearl].include? new_mat
    materials[:Ivory].push(new_mat) if flags[:TOOTH] and not materials[:Ivory].include? new_mat
    materials[:Horn].push(new_mat) if flags[:HORN] and not materials[:Horn].include? new_mat
    materials[:Crafts].push(new_mat) if ( flags[:TOOTH] or flags[:HORN] or flags[:BONE] ) and not materials[:Crafts].include? new_mat
    materials[:Flasks].push(new_mat) if flags[:LEATHER] and not materials[:Flasks].include? new_mat
    materials[:Quivers].push(new_mat) if flags[:LEATHER] and not materials[:Quivers].include? new_mat
    materials[:Backpacks].push(new_mat) if flags[:LEATHER] and not materials[:Backpacks].include? new_mat
    materials[:Cheese].push(new_mat) if flags[:CHEESE] and not materials[:Cheese].include? new_mat
    materials[:Extracts].push(new_mat) if ( flags[:LIQUID_MISC_CREATURE] and flags[:EDIBLE_RAW] and flags[:EDIBLE_COOKED] ) and not materials[:Extracts].include? new_mat
    materials[:Meat].push(new_mat) if flags[:MEAT] and not materials[:Meat].include? new_mat
    # Go through reaction products and add valid items
    material.reaction_product.id.each_with_index do |id, idx|
        prod = material.reaction_product
        materials = add_material_by_type(prod.material.mat_index[idx], prod.material.mat_type[idx], materials)
    end
    return materials
end

def get_creature_harvestables(creature_idx=-1)
    creature_raws = df.world.raws.creatures.all[creature_idx]
    materials = {
                 Leather:   [],
                 Silk:      [],
                 Wool:      [],
                 Bone:      [],
                 Shell:     [],
                 Pearl:     [],
                 Ivory:     [],
                 Horn:      [],
                 Crafts:    [],
                 Flasks:    [],
                 Quivers:   [],
                 Backpacks: [],
                 Cheese:    [],
                 Extracts:  [],
                 Meat:      [],
                 Eggs:      [],
                }
    creature_raws.caste.each do |caste|
        misc = caste.misc
        extracts = caste.extracts
        add_material_by_type(extracts.milkable_matidx, extracts.milkable_mat, materials)
        add_material_by_type(extracts.webber_matidx, extracts.webber_mat, materials)
        extracts.egg_material_mattype.each_with_index do |mattype, idx|
            materials[:Eggs].push([extracts.egg_material_matindex[idx], mattype]) if extracts.egg_material_matindex[idx] > -1
        end
        if caste.shearable_tissue_layer.length > 0
            shearable_parts = []
            caste.shearable_tissue_layer.each do |shearable|
                shearable.part_idx.each_with_index do |part_idx, idx|
                    shearable_parts.push caste.body_info.body_parts[part_idx].layers[shearable.layer_idx[idx]].tissue_id
                end
            end
            shearable_parts.sort!
            shearable_parts.uniq!
            shearable_parts.each do |tissue_idx|
                tissue = creature_raws.tissue[tissue_idx]
                add_material_by_type(tissue.mat_index, tissue.mat_type, materials)
            end
        end
        harvestable = []
        caste.body_info.body_parts.each_with_index do |part, part_idx|
            part.layers.each_with_index do |layer, layer_idx|
                harvestable.push(layer.tissue_id)
            end
        end
        harvestable.sort!
        harvestable.uniq!
        harvestable.each do |tissue_idx|
            tissue = creature_raws.tissue[tissue_idx]
            add_material_by_type(tissue.mat_index, tissue.mat_type, materials)
        end
    end
    return materials
end

def add_resources_entity(entity_idx=-1, creature_idx=-1, sell_prices, sell_requests, opts)
    harvestables = get_creature_harvestables(creature_idx)
    # Emulate a sell_prices/sell_requests list if none is returned to simplify code later
    sell_prices = get_empty_prices() if not sell_prices
    sell_requests = get_empty_prices() if not sell_requests
    # get entity by index
    entity = df.world.entities.all[entity_idx]
    # create shortcuts for resources
    resources = entity.resources
    organic = resources.organic
    refuse = resources.refuse
    misc_mat = resources.misc_mat
    work_str = ""
    # create a hash table of materials to check for addition
    materials = {Leather:   [organic.leather,    [ [ sell_prices[:Leather],       sell_requests[:Leather] ],  
                                                   [ sell_prices[:BagsLeather],   sell_requests[:BagsLeather] ] ] ], # direct leather mappings
                 Silk:      [organic.silk,       [ [ sell_prices[:ClothSilk],     sell_requests[:ClothSilk] ],
                                                   [ sell_prices[:BagsSilk],      sell_requests[:BagsSilk] ],
                                                   [ sell_prices[:ThreadSilk],    sell_requests[:ThreadSilk] ],
                                                   [ sell_prices[:RopesSilk],     sell_requests[:RopesSilk] ] ] ], # direct silk mappings
                 Wool:      [organic.wool,       [ [ sell_prices[:BagsYarn],      sell_requests[:BagsYarn] ],
                                                   [ sell_prices[:RopesYarn],     sell_requests[:RopesYarn] ],
                                                   [ sell_prices[:ClothYarn],     sell_requests[:ClothYarn] ],
                                                   [ sell_prices[:ThreadYarn],    sell_requests[:ThreadYarn] ] ] ], # direct yarn mappings
                 Bone:      [refuse.bone,        [] ], # no direct bone mappings
                 Shell:     [refuse.shell,       [] ], # no direct shell mappings
                 Pearl:     [refuse.pearl,       [] ], # no direct pearl mappings
                 Ivory:     [refuse.ivory,       [] ], # no direct ivory mappings :: tusks, and teeth
                 Horn:      [refuse.horn,        [] ], # no direct horn mappings  :: hoofs too
                 # direct craft mappings :: metal, stone, gem, bone, etc...
                 Crafts:    [misc_mat.crafts,    [ [ sell_prices[:Crafts],        sell_requests[:Crafts] ] ] ], 
                 # direct mappings from flasks to :FlasksWaterskins :: metal flasks and leather waterskins
                 Flasks:    [misc_mat.flasks,    [ [ sell_prices[:FlasksWaterskins], 
                                                       sell_requests[:FlasksWaterskins] ] ] ], 
                 # Quivers and Backpacks are NOT included with Leather as their values are NOT mapped directly to Leather's
                 Quivers:   [misc_mat.quivers,   [ [ sell_prices[:Quivers],       sell_requests[:Quivers] ] ] ], # leather
                 Backpacks: [misc_mat.backpacks, [ [ sell_prices[:Backpacks],     sell_requests[:Backpacks] ] ] ], # leather
                 Cheese:    [misc_mat.cheese,    [ [ sell_prices[:Cheese],        sell_requests[:Cheese] ] ] ],
                 # direct extracts mappings :: milk, venom, blood, sweat, etc...
                 Extracts:  [misc_mat.extracts,  [ [ sell_prices[:Extracts],      sell_requests[:Extracts] ] ] ], 
                 # direct meat mappings :: muscle, brain, liver, pancreas, etc...
                 Meat:      [misc_mat.meat,      [ [ sell_prices[:Meat],          sell_requests[:Meat] ] ] ], 
                 # Unknown where sheet/parchment is held in memory at this time
                 #Sheet:     [,      []], # skin => parchment
                 }
    # go through each material and check for matching additions using the harvestables table
    materials.each do |key, material|
        # skip materials the creature doesn't have available
        next if not harvestables[key] or harvestables[key].length == 0
        addable = []
        mat_index = material[0].mat_index.to_a
        mat_type = material[0].mat_type.to_a
        # create a 2d array of each vectors values to test if the harvestable is already present
        mats = mat_index.collect.with_index {|x, i| [x, mat_type[i]]}
        harvestables[key].each do |harvestable|
            next if mats.include? harvestable
            addable.push(harvestable) if not addable.include? harvestable
        end
        work_str += "Adding %d %s items.\n" % [addable.length, key]
        next if opts[:display]
        addable.each do |new_item|
            # insert the new material at index zero for the entity resources
            material[0].mat_index.insert_at(0, new_item[0])
            material[0].mat_type.insert_at(0, new_item[1])
            # insert new entries for the prices and requests vectors for civs the player has trade agreements with
            material[1].each do |sell_entries|
                # do not operate on non-vectors
                if not sell_entries[0].is_a?(Array)
                    # 128 appears to be the default price for items
                    sell_entries[0].insert_at(0, 128)
                end
                if not sell_entries[1].is_a?(Array)
                    # using 3 here for visibility
                    sell_entries[1].insert_at(0, opts[:trade_priority])
                end
            end
        end
    end
    return work_str
end

def remove_entity_resources(entity_idx=-1, creature_idx=-1, sell_prices, sell_requests, opts)
    work_str = ""
    # Emulate a sell_prices/sell_requests list if none is returned to simplify code later
    sell_prices = get_empty_prices() if not sell_prices
    sell_requests = get_empty_prices() if not sell_requests
    # get entity by index
    entity = df.world.entities.all[entity_idx]
    # create shortcuts for resources
    resources = entity.resources
    organic = resources.organic
    refuse = resources.refuse
    misc_mat = resources.misc_mat
    # get creature by index
    creature_raws = df.world.raws.creatures.all[creature_idx]
    # create a hash table of materials to check for removal
    materials = {Leather:   [organic.leather,    [], [ sell_prices[:Leather],       sell_requests[:Leather],  
                                                       sell_prices[:BagsLeather],   sell_requests[:BagsLeather] ] ], # direct leather mappings
                 Silk:      [organic.silk,       [], [ sell_prices[:ClothSilk],     sell_requests[:ClothSilk],
                                                       sell_prices[:BagsSilk],      sell_requests[:BagsSilk], 
                                                       sell_prices[:ThreadSilk],    sell_requests[:ThreadSilk], 
                                                       sell_prices[:RopesSilk],     sell_requests[:RopesSilk] ] ], # direct silk mappings
                 Wool:      [organic.wool,       [], [ sell_prices[:BagsYarn],      sell_requests[:BagsYarn],
                                                       sell_prices[:RopesYarn],     sell_requests[:RopesYarn], 
                                                       sell_prices[:ClothYarn],     sell_requests[:ClothYarn], 
                                                       sell_prices[:ThreadYarn],    sell_requests[:ThreadYarn] ] ], # direct yarn mappings
                 Bone:      [refuse.bone,        [], [] ], # no direct bone mappings
                 Shell:     [refuse.shell,       [], [] ], # no direct shell mappings
                 Pearl:     [refuse.pearl,       [], [] ], # no direct pearl mappings
                 Ivory:     [refuse.ivory,       [], [] ], # no direct ivory mappings :: tusks, and teeth
                 Horn:      [refuse.horn,        [], [] ], # no direct horn mappings  :: hoofs too
                 # direct craft mappings :: metal, stone, gem, bone, etc...
                 Crafts:    [misc_mat.crafts,    [], [ sell_prices[:Crafts],        sell_requests[:Crafts] ] ], 
                 # direct mappings from flasks to :FlasksWaterskins :: metal flasks and leather waterskins
                 Flasks:    [misc_mat.flasks,    [], [ sell_prices[:FlasksWaterskins], 
                                                       sell_requests[:FlasksWaterskins] ] ], 
                 # Quivers and Backpacks are NOT included with Leather as their values are NOT mapped directly to Leather's
                 Quivers:   [misc_mat.quivers,   [], [ sell_prices[:Quivers],       sell_requests[:Quivers] ] ], # leather
                 Backpacks: [misc_mat.backpacks, [], [ sell_prices[:Backpacks],     sell_requests[:Backpacks] ] ], # leather
                 Cheese:    [misc_mat.cheese,    [], [ sell_prices[:Cheese],        sell_requests[:Cheese] ] ],
                 # direct extracts mappings :: milk, venom, blood, sweat, etc...
                 Extracts:  [misc_mat.extracts,  [], [ sell_prices[:Extracts],      sell_requests[:Extracts] ] ], 
                 # direct meat mappings :: muscle, brain, liver, pancreas, etc...
                 Meat:      [misc_mat.meat,      [], [ sell_prices[:Meat],          sell_requests[:Meat] ]], 
                 # Unknown where sheet/parchment is held in memory at this time
                 #Sheet:     [,      []], # skin => parchment
                 }
    # go through each material and check for entries using the creature index
    materials.each do |key, material|
        # record the indexes of each material which belongs to the creature being removed
        num_materials = material[0].mat_index.length
        material[0].mat_index.each_with_index do |mat_idx, idx|
            next if not mat_idx == creature_idx
            material[1].push(idx)
        end
        material[1].reverse!
        remove_array = [ material[0].mat_index, material[0].mat_type ]
        # add any additional vectors with entries needing to be removed to the remove_array
        material[2].each do |mat_vector|
            # skip vectors that are not aligned
            next if not mat_vector.length == num_materials
            # add vector to array
            remove_array.push(mat_vector)
        end
        if opts[:verbose]
            work_str += "Removing %2d %s materials from %s.\n" % [material[1].length, creature_raws.creature_id, key]
        end
        if material[1].length > 0 and not opts[:display]
            remove_vector_items(material[1], remove_array)
        end
    end
    return work_str
end

add_entity_pops = lambda{ |entity_idx, race_idx, opts|
    entity_str = ""
    entity = df.world.entities.all[entity_idx]
    animals = entity.resources.animals
    race = df.world.raws.creatures.all[race_idx]
    sell_prices, sell_requests = get_sell_prices(entity_idx) # will be nil,nil for non-civ entities
    race.caste.each_with_index do |caste, caste_idx|
        flags = caste.flags
        pet = ( ( flags[:PET] or flags[:PET_EXOTIC] ) and not two_includes[animals.pet_races, animals.pet_castes, race_idx, caste_idx] )
        # Until the membership in the animals.exotic_pet_races is understood, no new creatures should be added to it.
        #pet_exotic = ( flags[:PET_EXOTIC] and not two_includes[animals.exotic_pet_races, animals.exotic_pet_castes, race_idx, caste_idx] )
        pack_animal = ( flags[:PACK_ANIMAL] and not two_includes[animals.pack_animal_races, animals.pack_animal_castes, race_idx, caste_idx] )
        wagon_puller = ( flags[:WAGON_PULLER] and not two_includes[animals.wagon_puller_races, animals.wagon_puller_castes, race_idx, caste_idx] )
        mount = ( ( flags[:MOUNT] or flags[:MOUNT_EXOTIC] ) and not two_includes[animals.mount_races, animals.mount_castes, race_idx, caste_idx] )
        minion = ( flags[:TRAINABLE_WAR] and not flags[:CAN_LEARN] and not two_includes[animals.minion_races, animals.minion_castes, race_idx, caste_idx] )
        egg_layer = ( ( flags[:LAYS_EGGS] or flags[:LAYS_UNUSUAL_EGGS] ) and not two_includes[animals.minion_races, animals.minion_castes, race_idx, caste_idx] )
        entity_str += "%20s: PET=%5s, PACK_ANIMAL=%5s, WAGON_PULLER=%5s, MOUNT=%5s, MINION=%5s\n" % [caste.caste_id, pet, pack_animal, wagon_puller, mount, minion]
        next if opts[:display]
        # Only creatures in the animals.pet_races array will be available for trade
        if pet
            animals.pet_races.insert_at(0, race_idx)
            animals.pet_castes.insert_at(0, caste_idx)
            sell_prices[:Pets].insert_at(0, 128) if sell_prices
            sell_requests[:Pets].insert_at(0, opts[:trade_priority]) if sell_requests
        end
        # Membership in the animals.exotic_pet_races is not tied to the PET_EXOTIC tag
        # Members of animals.pet_races can be members of animals.exotic_pet_races, 
        #  but the logic behind such membership does not appear to be tied to rarity of the species in the world
        #if pet_exotic
        #    animals.exotic_pet_races.push(race_idx)
        #    animals.exotic_pet_castes.push(caste_idx)
        #end
        if pack_animal
            animals.pack_animal_races.insert_at(0, race_idx)
            animals.pack_animal_castes.insert_at(0, caste_idx)
        end
        if wagon_puller
            animals.wagon_puller_races.insert_at(0, race_idx)
            animals.wagon_puller_castes.insert_at(0, caste_idx)
        end
        if mount
            animals.mount_races.insert_at(0, race_idx)
            animals.mount_castes.insert_at(0, caste_idx)
        end
        if minion
            animals.minion_races.insert_at(0, race_idx)
            animals.minion_castes.insert_at(0, caste_idx)
        end
        if egg_layer
            entity.resources.egg_races.insert_at(0, race_idx)
            entity.resources.egg_castes.insert_at(0, caste_idx)
            sell_prices[:Eggs].insert_at(0, 128) if sell_prices
            sell_requests[:Eggs].insert_at(0, opts[:trade_priority]) if sell_requests
        end
    end
    entity_str += add_resources_entity(entity_idx, race_idx, sell_prices, sell_requests, opts)
    return entity_str
}

remove_site_pops = lambda{ |site_idx, race_id, opts|
    site = df.world.world_data.sites[site_idx]
    # modifying a player fortress' populations this way is probably a bad idea, as spawned units are involved
    return if site.type == :PlayerFortress
    # keep track of which animals will need to have their population deleted from memory
    found_animals = []
    animals_remove = []
    animal_strings = []
    site.animals.each_with_index do |animal, idx|
        race_idx = animal.race
        found_animals.push(race_idx)
        animal_raws = df.world.raws.creatures.all[race_idx]
        if race_idx == race_id or (opts[:all_vermin] and animal_raws.flags[:AnyVermin])
            animal_name = animal_raws.name[1].gsub(/\w+/, &:capitalize)
            animal_strings.push("%33s (%26s): %7d (remove)\n" % [animal_name, animal_raws.creature_id, animal.count_min])
            animals_remove.push(idx)
        end
    end
    # reverse the list of indexes to remove so that we're not addressing the wrong ones after removing the first from the array
    animals_remove.reverse!
    removed = animals_remove.length
    display_str = get_site_desc[site]
    display_str += "    Removing %d population(s)" % [removed]
    puts(display_str)
    puts(animal_strings.join(''))
    if not opts[:display]
        animals_remove.each do |idx|
            # save the reference to the population for deleting
            old_animal = site.animals[idx]
            # delete the entry in the array for the population
            site.animals.delete_at(idx)
            # delete the population itself
            old_animal._cpp_delete
        end
    end
    return found_animals
}

remove_entity_pops = lambda{ |entity_id, race_id, opts|
    work_str = ""
    entity = df.world.entities.all[entity_id]
    resources = entity.resources
    animals = resources.animals
    # put together a 2d array of races, castes, and their string description for operating on
    pet_pairs = [
                [animals.pet_races, animals.pet_castes, 'pets'], # description word "pets" is used in a conditional below
                [animals.wagon_races, animals.wagon_castes, 'wagons'],
                [animals.pack_animal_races, animals.pack_animal_castes, 'pack animals'],
                [animals.wagon_puller_races, animals.wagon_puller_castes, 'wagon pullers'],
                [animals.mount_races, animals.mount_castes, 'mounts'],
                # surprisingly vermin are possible entries in the minion_races array, as they can be marked [TRAINABLE]
                [animals.minion_races, animals.minion_castes, 'minions'],
                [animals.exotic_pet_races, animals.exotic_pet_castes, 'exotic pets'],
                # These aren't in animals, so disabled for now
                #[resources.fish_races, resources.fish_castes],
                [resources.egg_races, resources.egg_castes, 'egg layers'], # description word "egg layers" is used in a conditional below
                ]
    found_races = []
    found_animals = []
    # go through any child entities, and remove their race entries first
    entity.entity_links.each do |child|
        # only work from the top down, not the bottom up.  lest we start an infinite loop
        # -- not sure what strength is for, but it was 100 from civ to site governments in my test case
        next if not child.type == :CHILD or not child.strength == 100
        child_races, child_animals = remove_entity_pops[child.target, race_id, opts]
        if entity.type == :Civilization
            found_races.concat child_races
            found_animals.concat child_animals
        end
    end
    # go through any attached sites, and remove marked populations
    entity.site_links.each_with_index do |site_link, idx|
        flags = site_link.flags
        # target is 1 based, while index is zero based
        site_idx = site_link.target - 1
        site = df.world.world_data.sites[site_idx]
        next if not site.cur_owner_id == entity_id and not site.civ_id == entity_id
        correct_site = ( flags.residence or flags.capital or flags.fortress or flags.land_for_holding or flags.central_holding_land or flags.land_holder_residence )
        # skip sites where a noble of this civ cannot reside (trading partners, monuments, sites of warring civs, etc)
        next if not correct_site or not site_link.link_strength == 100
        found_animals.concat remove_site_pops[site_idx, race_id, opts]
    end
    # track the removed pet indexes here for removal from export agreements later
    removed_pets = []
    # track the removed egg layer indexes here for removal from export agreements later
    removed_layers = []
    # go through this entity's races and remove marked populations
    pet_pairs.each_with_index do |pet_types, idx|
        remove_indexes = []
        remove_races = []
        pet_types[0].each_with_index do |race_idx, idx|
            raws = df.world.raws.creatures.all[race_idx]
            found_races.push(race_idx)
            # Skip adding back the race(s) we want to remove
            next if not ( race_idx == race_id or ( opts[:all_vermin] and raws.flags[:AnyVermin] ) )
            remove_indexes.push(idx)
            remove_races.push(race_idx) if not remove_races.include? race_idx
        end
        # reverse the list of indexes to remove so that we're not addressing the wrong ones after removing the first from the array
        #remove_indexes.reverse!
        if remove_indexes.length > 0
            work_str += "Removing %3d %13s from %s %d" % [remove_races.length, pet_types[2], entity.type.inspect, entity.id]
        end
        next if opts[:display]
        remove_vector_items(remove_indexes, [pet_types[0], pet_types[1]])
        removed_pets = remove_indexes if pet_types[2] == "pets"
        removed_layers = remove_indexes if pet_types[2] == "egg layers"
    end
    sell_prices, sell_requests = get_sell_prices(entity_id) # will be nil,nil for non-civ entities
    if entity.type == :Civilization
        if opts[:verbose]
            found_races.sort!
            found_races.uniq!
            found_animals.sort!
            found_animals.uniq!
            civ_name = entity.name.to_s.gsub(/\w+/, &:capitalize)
            work_str += "\nCivilization: %s (%d)\n" % [civ_name, entity_id]
            no_populations = found_races.select{ |race| not found_animals.include? race }
            no_populations.each do |race_idx|
                animal_raws = df.world.raws.creatures.all[race_idx]
                animal_name = animal_raws.name[1].gsub(/\w+/, &:capitalize)
                work_str += "%33s (%26s) (no site pops)\n" % [animal_name, animal_raws.creature_id]
            end
        end
        if not opts[:display]
            if sell_prices
                remove_vector_items(removed_pets, [ sell_prices[:Pets], sell_requests[:Pets] ])
                remove_vector_items(removed_layers, [ sell_prices[:Eggs], sell_requests[:Eggs] ])
            elsif sell_requests
                remove_vector_items(removed_pets, [ sell_requests[:Pets] ])
                remove_vector_items(removed_layers, [ sell_requests[:Eggs] ])
            end
        end
    end
    work_str += remove_entity_resources(entity_id, race_id, sell_prices, sell_requests, opts)
    puts(work_str) if not work_str == ""
    return found_races, found_animals
}

# vector.insert_at only works for integers, so we have to do insertion on a proper array 
# then assign the correctly aligned pointers from the array back to the vector
# kinda kludgy, but it works
pop_at_position = lambda{ |vector, insert_at, new_pop|
    pops = []
    # get all of the current populations in the vector
    vector.each do |pop|; pops.push(pop); end
    # allocate new position in vector
    vector.push(new_pop)
    # insert the new_population into our array
    pops.insert(insert_at, new_pop)
    # reassign the populations in the vector based on their position in the array
    pops.each_with_index do |pop, idx|
        vector[idx] = pop
    end
    # we don't return anything, as the vector is a memory object
}

add_site_pops = lambda{ |sites, pops, race_idx, opts|
    work_str = ''
    civs = []
    sites.each do |site_idx, site|
        work_str += get_site_desc[site]
        new_amount = rand(creature_min..creature_max)
        work_str += "%33s (%26s): %7d (created)\n" % [creature_name, race_idx, new_amount]
        work_str += add_entity_pops[site.cur_owner_id, race_idx, opts]
        civs.push(site.civ_id) if not civs.include? site.civ_id
        next if opts[:display]
        new_site_pop = world_population_alloc(:Animal, race_idx, new_amount, 10000001, site.cur_owner_id)
        #site.animals.insert_at(0, new_site_pop) # doesn't work
        # push the new_site_pop to position zero in the vector.
        pop_at_position[site.animals, 0, new_site_pop]
        pops[site_idx] = new_site_pop
     end
     # update the parent civilization with the new pets, if they aren't already in there
     # this is necessary for caravans to access the new animals if the animals are tradeable
     civs.each do |civ|
        work_str += add_entity_pops[civ, race_idx, opts]
     end
     work_str += "\nCreated a population at %d site(s)." % [sites.length]
     puts(work_str)
     return pops
}

update_site_pops = lambda{ |data_world, pops, exact=false, amount=0, opts|
    work_str = ''
    pops.each do |site_idx, animal|
        site = data_world.sites[site_idx]
        work_str += get_site_desc[site]
        old_amount = animal.count_min
        new_amount = amount
        if not exact
            new_amount += old_amount
        end
        work_str += "%33s (%26s): %7d => %7d (modified)\n" % [creature_name, animal.race, old_amount, new_amount]
        animal.count_min = new_amount if not opts[:display]
    end
    work_str += "Modified a population at %d site(s)." % [pops.length]
    puts(work_str)
}

if options[:site_id] or options[:civ_id] or options[:civ_race]
    available_sites, matching_sites, found_civs = get_sites[world_data, creature_idx, options]
    found_civs.push(options[:civ_id]) if options[:civ_id] and not found_civs.include? options[:civ_id]
    info_str = "Found %d site(s) with an existing population.\nFound %d site(s) where a population can be added." % [matching_sites.length, available_sites.length]
    puts(info_str)
    if options[:add_race]
        matching_sites = add_site_pops[available_sites, matching_sites, creature_idx, options]
    end
    if options[:set_amount] > 0
        update_site_pops[world_data, matching_sites, true, options[:set_amount], options]
    end
    if options[:add_amount] > 0
        update_site_pops[world_data, matching_sites, false, options[:add_amount], options]
    end
    if options[:remove_animal] or options[:all_vermin]
        found_civs.each do |civ_id|
            remove_entity_pops[civ_id, creature_idx, options]
        end
    end
end
if options[:regions] > 0 or options[:locations] > 0 or options[:boost] or options[:increment]
    local_populations, found = get_local[creature_idx, width, height, options]
    world_pop_by_region = get_region[world_data, creature_idx, options]
end
if options[:regions] > 0 or options[:locations] > 0
    region_count = world_pop_by_region.length
    available_regions, locations_count, filtered_sites = get_available_regions[world_data, creature, world_pop_by_region, local_populations, width, height, options]
    found_str = ( found == 0 and region_count == 0 ) ? "%s exist nowhere in this world, at this time." % [creature_name] : "%s have been found already living in %d region(s), which contain %d location(s) that have active populations." % [creature_name, region_count, found]
    puts(found_str)
    add_region_pops[world_data, available_regions, world_pop_by_region, locations_count, filtered_sites, options]
end
