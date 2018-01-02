--template_item.lua v1.0
--@ module = true
local usage = [====[
template_item - used to copy items with different materials
	Requires a reaction

	REACTION OPTIONS:
		Reagents require the [PRESERVE_REAGENT] tag, as the script expects them to -
		 - exist upon execution, and will handle consumption of the appropriate amount.
		The item to be copied must have the reagent tag of 'template'
		The item to use as material must have the reagent tag of 'material'
		The product must always use 'GET_ITEM_DATA_FROM_REAGENT' -
		 - and target the 'template' reagent.

	EXAMPLE REACTION:
		[REACTION:LUA_TEMPLATE_ITEM_EXAMPLE_1] <- LUA_TEMPLATE_ITEM is required
			[NAME:copy metal armor]
			[REAGENT:template:1:ARMOR:NONE:NONE:NONE][REACTION_CLASS:METAL][PRESERVE_REAGENT]
			[REAGENT:material:5:BAR:NONE:NONE:NONE][REACTION_CLASS:METAL][PRESERVE_REAGENT]
			[PRODUCT:100:1:GET_ITEM_DATA_FROM_REAGENT:template:NONE]
			[SKILL:FORGE_ARMOR]

]====]

function templateitem(reaction,reaction_product,unit,input_items,input_reagents,output_items)
	--printreaction(reaction,reaction_product,unit,input_items,input_reagents,output_items)
	local template_item, mat_item
	local mat_array = {}
	local mat_count = 0

	-- find the 'template' and 'material' reagents, and count the total 'material' reagents
	for iter,item in ipairs(input_reagents) do
		if not template_item and item.code == 'template' then
			template_item = input_items[iter]
		elseif item.code == 'material' then
			-- the material of the finished product will be chosen by the last item in the list
			-- which is the first input material from the Adventurer UI
			mat_item = input_items[iter]
			-- store the material item objects for potential consumption later
			mat_array[mat_count] = input_items[iter]
			mat_count = mat_count + 1
		end
	end
	-- correction for a zero based array
	mat_count = mat_count - 1

	-- determine the amount of material to consume
	local def = dfhack.items.getSubtypeDef(template_item:getType(), template_item:getSubtype())
	local material_size = 1
	-- items without a subtype (flasks) will not return a material size. 
	if def then material_size = def.material_size end
	-- http://dwarffortresswiki.org/index.php/40d:Material_size
	-- http://dwarffortresswiki.org/index.php/DF2014:Melt_item#Yield
	-- Using the community agreed upon standard of 0.3 units of raw material per 1 material size, and rounding up to 1 as a minimum amount
	local mat_req = material_size * 0.3
	local mat_min = math.floor(mat_req)
	-- for fractions of a material, roll a random float to determine if one extra material will be consumed
	-- chance of consumption is equal to the fraction of material
	-- 0.2 material equals a 20% chance for one extra material to be consumed
	-- this method is preferable to attempting to emulate the workshop behavior of
	 -- storing fractions of metal bars when melting items
	if (mat_req - mat_min) >= randomGen:drandom() then
		-- because we're using a zero based array, this is actually consuming one extra material
		mat_req = mat_min
	else
		-- correction for a zero based array
		mat_req = mat_min - 1
		-- preserve minimum consumption of 1 reagent
		if mat_req < 0 then
			mat_req = 0
		end
	end

	print((mat_req + 1), 'reagents consumed.')
	-- remove reagents that were consumed
	-- by removing reagents here, we keep inventory location sane
	-- the alternative, of not preserving reagents, and then adding back the ones that weren't consumed would spawn the items to the floor
	local rem_item
	-- since we're using a zero based array, we'll count down to -1
	while mat_req > -1 do
		rem_item = mat_array[mat_req]
		-- remove the item reference for safe cleanup
		mat_array[mat_req] = nil
		-- remove the item directly
		dfhack.items.remove(rem_item)
		-- remove the item reference immediately
		rem_item = nil
		mat_req = mat_req - 1
	end

	-- set the copied item's material type and index, as well as left/right handedness for gloves
	local handedness = template_item:getGloveHandedness()
	for iter,item in ipairs(output_items) do
		item.mat_type = mat_item.mat_type
		item.mat_index = mat_item.mat_index
		if handedness > 0 then
			if #output_items >= 2 then
				-- even iterations get left gloves, and odd gets right gloves
				if iter % 2 == 0 then
					item:setGloveHandedness(1)
				else
					item:setGloveHandedness(2)
				end
			else
				item:setGloveHandedness(handedness)
			end
		end
	end
end

function printreaction(reaction,reaction_product,unit,input_items,input_reagents,output_items)
 print('reaction')
 print(reaction)
 printall(reaction)
 print('reaction_product')
 print(reaction_product)
 printall(reaction_product)
 print('unit')
 print(unit)
 printall(unit)
 print('input_items')
 print(input_items)
 printall(input_items)
 for _,item in ipairs(input_items or {}) do
	print(_)
	print(item)
	printall(item)
 end
 print('input_reagents')
 print(input_reagents)
 printall(input_reagents)
 for _,item in ipairs(input_reagents or {}) do
	print(_)
	print(item)
	printall(item)
 end
 print('output_items')
 print(output_items)
 printall(output_items)
 for _,item in ipairs(output_items or {}) do
	print(_)
	print(item)
	printall(item)
 end
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

local eventful = require 'plugins.eventful'
local utils = require 'utils'

randomGen = randomGen or dfhack.random.new()

eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.templateItemTrigger = function() print('Template Items: Unloaded') end

eventful.onReactionComplete.templateItemTrigger = function(reaction,reaction_product,unit,input_items,input_reagents,output_items)
	if string.starts(reaction.code,'LUA_TEMPLATE_ITEM') then
		templateitem(reaction,reaction_product,unit,input_items,input_reagents,output_items)
	end
end

if moduleMode then
 return
end

local args = {...} or {}
args = utils.processArgs(args, validArgs)

if args.help then
 print(usage)
 return
end

print('Template Items: Loaded')
