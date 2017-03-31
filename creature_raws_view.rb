# Show information about the selected creature as found in df.world.raws.creatures
=begin

creature_raws_view -s CREATURE

=end

# Below assumes that the path to the current script file is Dwarf Fortress=>hack=>scripts
file_dir = File.dirname(__dir__)
ruby_dir = file_dir + File::SEPARATOR + 'ruby'
$LOAD_PATH.unshift(file_dir) unless $LOAD_PATH.include?(file_dir)
$LOAD_PATH.unshift(ruby_dir) unless $LOAD_PATH.include?(ruby_dir)

# requires optparse.rb from Ruby's main distrobution be in Dwarf Fortress=>hack=>ruby
# (copy at https://github.com/rndmvar/DFHack_scripts/blob/master/optparse.rb)
require 'optparse'

options = {}

$script_args << '-h' if $script_args.empty?

arg_parse = OptionParser.new do |opts|
    opts.default_argv = $script_args # Ruby plugin for Dwarf Fortress does not populate ARGV natively
    opts.banner = "Usage: creature_raws_view -s CREATURE"

    opts.separator "Mandatory arguments:"
    opts.on("-s", "--species CREATURE", "Raw creature name to [re]populate.") do |s|
        options[:species] = s.upcase
    end
    opts.separator "Examples:"
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

def fill_string(input="", titleize=false, default="none")
    return_string = ( input and not input == "" ) ? input : default
    return_string.gsub!(/\w+/, &:capitalize) if titleize
    return return_string
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

def describe_caste(creature_raw, caste, indent="  ")
    description_str = "Caste: %s\n" % [caste.caste_id]
    misc = caste.misc
    extracts = caste.extracts
    has_eggs = ( extracts.egg_material_mattype.length > 0 or extracts.lays_unusual_eggs_itemtype.length > 0 )
    description_str += "Population Ratio: %d\n" % [misc.pop_ratio]
    #description_str += "Misc: %s\n" % [caste.misc.inspect]
    description_str += "Litter size: %d-%d\n" % [misc.litter_size_min, misc.litter_size_max] if not has_eggs
    description_str += "Egg amount: %d-%d\n" % [misc.clutch_size_min, misc.clutch_size_max] if has_eggs
    description_str += "Egg size: %d\n" % [misc.egg_size] if has_eggs
    description_str += "Baby age: %d year(s)\n" % [misc.baby_age]
    description_str += "Child age: %d year(s)\n" % [misc.child_age]
    life_span = ( misc.maxage_min == -1 and misc.maxage_max == -1 ) ? "ageless" : "%d-%d year(s)" % [misc.maxage_min, misc.maxage_max]
    description_str += "Max lifespan: %s\n" % [life_span]
    description_str += "Adult size: %d\n" % [misc.adult_size]
    description_str += "Building Destroyer: "
    if misc.buildingdestroyer == 0
        description_str += "false\n"
    elsif misc.buildingdestroyer == 1
        description_str += "doors, hatches, and furniture only\n"
    elsif misc.buildingdestroyer == 2
        description_str += "all buildings\n"
    end
    #description_str += "Mod value: %d\n" % [misc.modvalue]
    description_str += "Pet value: %d\n" % [misc.petvalue] if caste.flags[:PET_EXOTIC] or caste.flags[:PET]
    description_str += "Milk amount: %s\n" % [misc.milkable] if extracts.milkable_mat > -1
    description_str += "Trade capacity: %d\n" % [misc.trade_capacity] if caste.flags[:PACK_ANIMAL]
    description_str += "Grazer value: %d\n" % [misc.grazer] if caste.flags[:GRAZER]
    description_str += "Prone to RAGE: %s\n" % [(misc.prone_to_rage == 0) ? "false" : "true"]
    #description_str += "Bone material: %d\n" % [describe_material(misc.bone_mat)]
    description_str += "Flags: %s\n" % [format_flags(caste.flags, "\n     " + indent)]
    description_str += "Extracts:\n"
    description_str += "  MILK: %s\n" % [material_by_id(extracts.milkable_mat, extracts.milkable_matidx)] if extracts.milkable_mat > -1
    description_str += "  BLOOD: %s\n" % [material_by_id(extracts.blood_mat, extracts.blood_matidx)] if extracts.blood_mat > -1
    description_str += "  WEB: %s\n" % [material_by_id(extracts.webber_mat, extracts.webber_matidx)] if extracts.webber_mat > -1
    description_str += "  EGG:\n" if extracts.egg_material_mattype.length > 0
    extracts.egg_material_mattype.each_with_index do |mattype, idx|
        description_str += "%s\n" % material_by_id(mattype, extracts.egg_material_matindex[idx])
    end
    description_str += "Shearable Parts:\n" if caste.shearable_tissue_layer.length > 0
    shearable_parts = []
    caste.shearable_tissue_layer.each do |shearable|
        shearable.part_idx.each_with_index do |part_idx, idx|
            shearable_parts.push caste.body_info.body_parts[part_idx].layers[shearable.layer_idx[idx]].tissue_id
        end
    end
    shearable_parts.sort!.uniq!
    shearable_parts.each do |mat_idx|
        description_str += "  %s" % [describe_material(creature_raw.material[mat_idx], mat_idx, "    ")]
    end
    #description_str += "UNUSUAL_EGG:\n"
    #extracts.lays_unusual_eggs_itemtype.each_with_index do |mattype, idx|
    #    description_str += "%s\n" % material_by_id(mattype, extracts.egg_material_matindex[idx])
    #end
    #description_str += "EGG: %s\n" % [material_by_id(extracts.egg_material_mattype, extracts.egg_material_matindex)]
    #description_str += "Secretions: %s\n" % [caste.secretion.inspect]
    #description_str += "Body Info: %s\n" % [caste.body_info.inspect]
    # Unknown2 is right, I have no idea what this is used for
    #description_str += "Unknown2?: %s\n" % [caste.unknown2.inspect]
    description_str = description_str.split("\n").join("\n" + indent)
    return description_str
end

def describe_creature(creature_id='')
    creature_idx = df.world.raws.creatures.all.index { |cr| cr.creature_id == creature_id }
    if not creature_idx
        puts('ERROR: %s could not be found in creature raws.' % [creature_id])
        return false
    else
        creature_raw = df.world.raws.creatures.all[creature_idx]
        creature_name = creature_raw.name[1].gsub(/\w+/, &:capitalize)
        puts("FOUND: %s (%s: %d) in creature raws." % [creature_name, creature_raw.creature_id, creature_idx])
    end
    general_baby_name = fill_string(creature_raw.general_baby_name[1], true)
    general_child_name = fill_string(creature_raw.general_child_name[1], true)
    description_str = "Baby Name: %s\nChild Name: %s\n" % [general_baby_name, general_child_name]
    description_str += "Frequency: %d%%\nPopulation size: %d-%d\n" % [creature_raw.frequency, creature_raw.population_number[1], creature_raw.population_number[0]]
    description_str += "Size (Adult): %d\n" % [creature_raw.adultsize]
    #description_str += "Caste Population Ratio: %s\n" % [creature_raw.pop_ratio.inspect]
    description_str += "Flags: %s\n" % [format_flags(creature_raw.flags, "\n       ")]
    puts(description_str)
    material_strings = []
    creature_raw.material.each_with_index do |material, idx|
        material_strings.push(describe_material(material, idx, "    "))
    end
    puts("CREATURE MATERIALS:\n  " + material_strings.join('  '))
    creature_raw.caste.each do |caste|
        puts(describe_caste(creature_raw, caste))
    end
end

describe_creature(options[:species])
