# Add credits for need levels to non-dwarves for social activities they may not be capable of performing.
=begin

fix_distracted

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
        df.world.history.figures.each_with_index do |figure, i|
            if figure.id == hist_fig_id
                historical_fig_dict[hist_fig_id] = figure
            end
        end
    end
}

# This will return the english version of the word IDs given in the passed array (used here for getting the last name, but could be for anything)
lookup_words = lambda{ |words|
    # We're adding this all together into a single string
    return_string = ""
    words.each_with_index do |word_int, i|
        # Skip non-entries
        if word_int == -1
            next
        end
        # Add the found word
        return_string += df.world.raws.language.words[word_int].word
    end
    return return_string
}

# Set needs values to highest fulfillment level.  Will cause the unit to become extremely "focused"
fix_distraction = lambda{ |personality, needs|
    needs.each_with_index do |need, n|
        # Skip already fulfilled needs
        if need.focus_level >= 400 and need.need_level <= 1
            next
        end
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

df.world.units.active.each_with_index do |unit, i|
    # skip dead units
    if unit.flags1.dead
        next
    end
    soul = unit.status.souls[0]
    # Skip current player race, as this isn't for cheating
    if soul.race == player_race
        next
    end
    personality = soul.personality
    # Skip units that have all of their needs met
    if not personality.flags.has_unmet_needs
        next
    end
    # Track how many we're working on for printing later
    counter += 1
    needs = personality.needs
    needs_str = ""
    # Find Dieties in the needs list of this unit
    needs.each_with_index do |need, n|
        # Skip needs that are met
        if need.focus_level >= 400 and need.need_level == 1
            next
        end
        deity_name_str = ""
        if need.deity_id != -1
            # Search for the Diety in the historical figures list
            if not historical_fig_dict[need.deity_id]
                lookup_hist_fig[need.deity_id]
            end
            # Get the Diety name
            deity_name_obj = historical_fig_dict[need.deity_id].name
            # Format the Diety's full name for printing
            deity_name_str = (deity_name_obj.first_name + " " + lookup_words[deity_name_obj.words]).gsub(/\w+/, &:capitalize)
        end
        # Add this need to the print string.  Focus is best at 400, and worst below 0.  Decay is best at 1, and worst at 10.
        needs_str += need.id.inspect + "=" + need.focus_level.inspect + " focus," + need.need_level.inspect + " decay," + deity_name_str + "|"
    end
    # Store the overall focus levels as float so that a fractional value can be examined later
    undistracted_focus = personality.undistracted_focus * 1.0
    current_focus = personality.current_focus * 1.0
    # Set a default distraction value in the event that current focus is zero ( undistracted focus is the number of needs multiplied by four )
    distraction_level = (undistracted_focus / 4.0)
    if personality.current_focus != 0
        # Distraction level of 1.00-1.99 is "distracted"(yellow) and 2.0-?.?? is "Distracted!"(red) on the UI
        distraction_level = (undistracted_focus / current_focus)
    end
    # Get the species name of the unit for printing
    race_name = df.world.raws.creatures.all[soul.race].name[0].gsub(/\w+/, &:capitalize)
    civilization = "Foreigner"
    # Locals are animal units born on the map as tame or trained to tame status while a child.  They are also the sentient members of the fortress.
    if player_civ == personality.civ_id
        civilization = "Local"
    end
    name = "Nameless"
    if unit.name.has_name
        # Get the name of the unit for printing
        name = (unit.name.first_name + " " + lookup_words[unit.name.words]).gsub(/\w+/, &:capitalize)
    end
    # Not sure if a distraction level of 0.25 is too high or low to trigger this on, but anything at 1.0 or over will definitely need to be addressed by this script.
    if distraction_level >= 0.25
        puts("^" + civilization + ", " + race_name + ", " + name + "|Stress:" + personality.stress_level.inspect + "|Distraction:#{format("%.2f", distraction_level)}|" + needs_str )
        fix_distraction[personality, needs]
    end
end

puts(counter.inspect)
