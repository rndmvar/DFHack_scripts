# Remove needs from units that cannot fulfill them, and/or multiple deities to pray to on a single unit.
=begin

fix_needs

=end

counter = 0

# Store references to Dieties that are to be prayed to here
historical_fig_dict = {}

# Get the player's race (may not be dwarf if on Masterwork) and civilization ID (So we know if the unit is a local or foreigner)
player_race = df.ui.race_id
player_civ = df.ui.civ_id

# Lookup the Diety by ID
lookup_hist_fig = lambda{ |hist_fig_id|
    # return immediately if called on a non-entity entry
    if hist_fig_id == -1
        return
    end
    # Don't redo work already done
    if not historical_fig_dict[hist_fig_id]
        # Loop through the Historical figures, because I don't know of a faster way
        historical_fig_dict[hist_fig_id] = df.world.history.figures.find() { |fig| fig.id == hist_fig_id }
    end
    return historical_fig_dict[hist_fig_id]
}

race_dict = {}

lookup_race = lambda{ |race_id|
    if not race_dict[race_id]
        race_dict[race_id] = df.world.raws.creatures.all[race_id]
    end
    return race_dict[race_id]
}

get_unit_name = lambda{ |unit|
    # Get the species (singular version) name of the unit for printing
    race_name = lookup_race[unit.status.current_soul.race].name[0].gsub(/\w+/, &:capitalize)
    civilization = "Foreigner"
    # Locals are animal units born on the map as tame or trained to tame status while a child.  They are also the sentient members of the fortress.
    if player_civ == unit.status.current_soul.personality.civ_id
        civilization = "Local"
    end
    name = "Nameless"
    if unit.name.has_name
        # Get the name of the unit for printing
        name = "#{unit.name}".gsub(/\w+/, &:capitalize)
    end
    return "%s, %s, %s" % [civilization, race_name, name]
}

get_needs = lambda{ |needs, unit|
    needs_str = ""
    deity_needs = {}
    need_flags = {}
    source = lookup_hist_fig[unit.hist_figure_id]
    # Find Dieties in the needs list of this unit
    needs.each_with_index do |need, i|
        deity_name_str = ""
        need_flags[need.id] = true
        if need.deity_id != -1
            # Get the Diety name
            deity_obj = lookup_hist_fig[need.deity_id]
            deity_needs[deity_obj.id] = i
            # Format the Diety's full name for printing
            deity_name_str = ", #{deity_obj.name}".gsub(/\w+/, &:capitalize)
        end
        # Add this need to the print string.  Focus is best at 400, and worst below 0.  Decay is best at 1, and worst at 10.
        needs_str += "%21s: %6d focus, %2d decay%s\n" % [need.id.inspect, need.focus_level, need.need_level, deity_name_str]
    end
    deity_hist = {}
    if not source == nil
        source.histfig_links.each_with_index do |fig, i|
            if fig.getType() == :DEITY
                deity_hist[fig.target_hf] = i
            end
        end
     end
    #deity_hist.reverse!
    #deity_needs.reverse!
    return [needs_str, deity_needs, need_flags, deity_hist]
}

# Set needs values to highest fulfillment level.  Will cause the unit to become extremely "focused"
fix_distraction = lambda{ |personality, needs|
    needs.each_with_index do |need, n|
        # Set the need level to the just fulfilled value
        need.focus_level = 400
        # Set the need level decay to the lowest level of one
        need.need_level = 1
    end
    # Set the current focus to the undistracted focus level
    personality.current_focus = personality.undistracted_focus
    # Set the unmet needs flag to false, as everything is maxed out now.
    personality.flags.has_unmet_needs = false
}

# Removes historical links from the source to the target. -- Used here to clear dieties, but can also be used to remove friendships and marraiges
remove_historical_links = lambda{ |source, relationships| #target, relationship|
    to_delete = []
    source.histfig_links.each_with_index do |fig, i|
        target_hf = fig.target_hf
        rel_type = fig.getType()
        if relationships.has_key?(target_hf) and relationships[target_hf] == rel_type
        #if source.histfig_links[i].target_hf == target.id
            #if not relationship or relationship == source.histfig_links[i].getType()
            to_delete.push(i)
            #end
        end
    end
    to_delete.reverse!
    to_delete.each do |index|
        source.histfig_links.delete_at(index)
    end
}

# Removes all links from the unit to the diety, both the need and the historical link
remove_dieties = lambda{ |unit, deities, hist_deities, leave_one|
    to_delete = []
    if leave_one
        remaining = deities.keys
        remaining.sort!
        #Remove one of the dieties so that the unit isn't left with none
        to_remain = remaining.pop()
        deities.delete(to_remain)
        if hist_deities.has_key?(to_remain)
            hist_deities.delete(to_remain)
        end
    end
    relationships = {}
    unit_hf = lookup_hist_fig[unit.hist_figure_id]
    deities.each_key do |deity|
        to_delete.push(deities[deity])
        #unit.status.current_soul.personality.needs.delete_at(deities[deity])
        #relationships[deity] = [] if not relationships[deity]
        #relationships[deity].push(:DEITY)
        #remove_historical_links[unit_hf, deity[1], :DEITY]
    end
    to_delete.reverse!
    to_delete.each do |deleter|
        unit.status.current_soul.personality.needs.delete_at(deleter)
    end
    to_delete = []
    deities.each_key do |deity_hist|
        to_delete.push(hist_deities[deity_hist])
    end
    to_delete.reverse!
    to_delete.each do |deleter|
        unit_hf.histfig_links.delete_at(deleter)
    end
    #remove_historical_links[unit_hf, relationships]
}

# Remove a specific need, or all needs if need_type is false
remove_needs = lambda{ |unit, need_type|
    needs = unit.status.current_soul.personality.needs
    to_delete = []
    needs.each_with_index do |need, i|
        if not need_type or need.id == need_type
            to_delete.push(i)
        end
    end
    to_delete.reverse!
    to_delete.each do |index|
        needs.delete_at(index)
    end
}

#Strips all needs from pastured animals, as they will never be fulfilled, and will only create distraction, and FPS lag from invalid pathing
df.world.buildings.all.each do |building|
    next if building._rtti_classname != :building_civzonest
    next if not building.zone_flags.pen_pasture or building.assigned_units == nil or building.assigned_units.length == 0
    puts("Pasture center = x: %4d, y: %4d, z: %4d" % [building.centerx, building.centery, building.z])
    building.assigned_units.each do |unit_id|
        unit = df.unit_find(unit_id)
        counter += 1
        soul = unit.status.current_soul
        personality = soul.personality
        needs = personality.needs
        if needs.length == 0
            next
        end
        unit_name = get_unit_name[unit]
        needs_print, needs_deities, needs_flags, hist_deities = get_needs[needs, unit]
        puts( "BEFORE: %d\n%s (Pastured)\n%s\n" % [needs.length, unit_name, needs_print] )
        if needs_flags[:PrayOrMedidate]
            remove_dieties[unit, needs_deities, hist_deities, false]
        end
        remove_needs[unit, false]
        fix_distraction[personality, needs]
        needs_print, needs_deities, needs_flags, hist_deities = get_needs[needs, unit]
        puts( "AFTER: %d\n%s (Pastured)\n%s\n" % [needs.length, unit_name, needs_print] )
    end
end

df.world.units.active.each_with_index do |unit, i|
    # skip dead units
    if unit.flags1.dead
        next
    end
    soul = unit.status.current_soul
    # Some units which are not marked as dead may not have a soul
    if soul == nil
        next
    end
    personality = soul.personality
    needs = personality.needs
    if needs.length == 0
        next
    end
    # Track how many we're working on for printing later
    counter += 1
    
    needs_print, needs_deities, needs_flags, hist_deities = get_needs[needs, unit]
    
    race = lookup_race[unit.status.current_soul.race]
    caste = race.caste[unit.caste]

    # Removes all needs from creatures without brains, as its impossible for them to have a possitive or negative thought
    if caste.flags[:NOTHOUGHT]
        unit_name = get_unit_name[unit]
        puts( "BEFORE: %d\n%s (Brainless)\n%s\n" % [needs.length, unit_name, needs_print] )
        remove_dieties[unit, needs_deities, hist_deities, false]
        remove_needs[unit, false]
        fix_distraction[personality, needs]
        needs_print, needs_deities, needs_flags, hist_deities = get_needs[needs, unit]
        puts( "AFTER: %d\n%s (Brainless)\n%s\n" % [needs.length, unit_name, needs_print] )
    # Remove needs that require speech from creatures that cannot speak
    elsif not caste.flags[:CAN_SPEAK] and ( needs_flags[:Socialize] or needs_flags[:PrayOrMedidate] )
        unit_name = get_unit_name[unit]
        puts( "BEFORE: %d\n%s (Can\'t Speak)\n%s\n" % [needs.length, unit_name, needs_print] )
        if needs_flags[:PrayOrMedidate]
            remove_dieties[unit, needs_deities, hist_deities, false]
            remove_needs[unit, :PrayOrMedidate]
        end
        if needs_flags[:Socialize]
            remove_needs[unit, :Socialize]
        end
        fix_distraction[personality, needs]
        needs_print, needs_deities, needs_flags, hist_deities = get_needs[needs, unit]
        puts( "AFTER: %d\n%s (Can\'t Speak)\n%s\n" % [needs.length, unit_name, needs_print] )
    elsif needs_deities.length > 1 or hist_deities.length > 1
        puts(hist_deities.inspect)
        unit_name = get_unit_name[unit]
        puts( "BEFORE: %d\n%s\n%s\n" % [needs.length, unit_name, needs_print] )
        remove_dieties[unit, needs_deities, hist_deities, true]
        fix_distraction[personality, needs]
        needs_print, needs_deities, needs_flags, hist_deities = get_needs[needs, unit]
        puts( "AFTER: %d\n%s\n%s\n" % [needs.length, unit_name, needs_print] )
    end
end

puts(counter.inspect)
