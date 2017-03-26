# Add specified caste to regions where it can live.  Good for repopulating a nearly extinct species, or adding one that never lived in the world.
=begin

populate -s CREATURE [-r #] [-l #] [-e] [-n] [-b #] [-i #] [-x #] [-f] [-d] [-v]

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
    opts.banner = "Usage: populate -s CREATURE [-r #] [-l #] [-e] [-n] [-b #] [-i #] [-x #] [-f] [-a] [-d] [-v]"
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

    opts.separator "Mandatory arguments:"
    opts.on("-s", "--species CREATURE", "Raw creature name to [re]populate.") do |s|
        options[:species] = s.upcase
    end
    opts.separator "Filters:"
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
    opts.separator "Modifiers:"
    opts.on("-b", "--boost #", Integer, "Increment region populations by the specified amount.") do |b|
        options[:boost] = b
    end
    opts.on("-i", "--increment #", Integer, "Increment local populations by the specified amount.") do |i|
        options[:increment] = i
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

creature = options[:species]
creature_idx = df.world.raws.creatures.all.index { |cr| cr.creature_id == creature }
if not creature_idx
    puts('ERROR: %s could not be found in creature raws.' % [creature])
    exit
end
creature = df.world.raws.creatures.all[creature_idx]
creature_name = creature.name[1].gsub(/\w+/, &:capitalize)
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
def world_population_alloc(type, race_idx, min=1, max=1)
    pop = DFHack::WorldPopulation.cpp_new
    pop.type = type
    pop.race = race_idx
    pop.count_min = min
    pop.count_max = max
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

check_location = lambda{ |data_world, creature_raw, x, y, sorted_regions, local_pops, populatable, count, filtered_sites, opts|
    # Get the region map for this location
    location = data_world.region_map[x][y]
    region_id = location.region_id
    # Get the region itself for this location
    world_region = data_world.regions[region_id]
    # Get the list of populations for this region - moved
    #region_populations = world_region.population
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
                new_region_pop = world_population_alloc(:Animal, creature_idx, creature_min, creature_max)
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

local_populations, found = get_local[creature_idx, width, height, options]
world_pop_by_region = get_region[world_data, creature_idx, options]
region_count = world_pop_by_region.length
available_regions, locations_count, filtered_sites = get_available_regions[world_data, creature, world_pop_by_region, local_populations, width, height, options]
found_str = ( found == 0 and region_count == 0 ) ? "%s exist nowhere in this world, at this time." % [creature_name] : "%s have been found already living in %d region(s), which contain %d location(s) that have active populations." % [creature_name, region_count, found]
puts(found_str)
add_region_pops[world_data, available_regions, world_pop_by_region, locations_count, filtered_sites, options]
