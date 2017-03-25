-- Add the priority tag to jobs of selected type. 
--(Good for jobs for storing items in location/hospital which will never be completed so long as stockpile jobs keep getting queued above it)
local usage = [====[

priority
=======================
Set's the do_now flag on all of the selected types of jobs.

Arguments::

    -BringItemToDepot
        Sets the do_now flag for jobs of this type.
    -ConstructBuilding
        Sets the do_now flag for jobs of this type.
    -DestroyBuilding
        Sets the do_now flag for jobs of this type.
    -DumpItem
        Sets the do_now flag for jobs of this type.
    -LoadCageTrap
        Sets the do_now flag for jobs of this type.
    -LoadCatapult
        Sets the do_now flag for jobs of this type.
    -LoadStoneTrap
        Sets the do_now flag for jobs of this type.
    -LoadWeaponTrap
        Sets the do_now flag for jobs of this type.
    -ManageWorkOrders
        Sets the do_now flag for jobs of this type.
    -PenLargeAnimal
        Sets the do_now flag for jobs of this type.
    -PenSmallAnimal
        Sets the do_now flag for jobs of this type.
    -PullLever
        Sets the do_now flag for jobs of this type.
    -RecoverPet
        Sets the do_now flag for jobs of this type.
    -RecoverWounded
        Sets the do_now flag for jobs of this type.
    -ReleaseLargeCreature
        Sets the do_now flag for jobs of this type.
    -ReleasePet
        Sets the do_now flag for jobs of this type.
    -ReleaseSmallCreature
        Sets the do_now flag for jobs of this type.
    -RemoveConstruction
        Sets the do_now flag for jobs of this type.
    -StoreItemInBag
        Sets the do_now flag for jobs of this type.
    -StoreItemInBarrel
        Sets the do_now flag for jobs of this type.
    -StoreItemInBin
        Sets the do_now flag for jobs of this type.
    -StoreItemInHospital
        Sets the do_now flag for jobs of this type.
    -StoreItemInLocation
        Sets the do_now flag for jobs of this type.
    -StoreItemInStockpile
        Sets the do_now flag for jobs of this type.
    -StoreItemInVehicle
        Sets the do_now flag for jobs of this type.
    -TameAnimal
        Sets the do_now flag for jobs of this type.
    -TameVermin
        Sets the do_now flag for jobs of this type.
    -TradeAtDepot
        Sets the do_now flag for jobs of this type.
    -TrainAnimal
        Sets the do_now flag for jobs of this type.
    -TrainHuntingAnimal
        Sets the do_now flag for jobs of this type.
    -TrainWarAnimal
        Sets the do_now flag for jobs of this type.

]====]
local utils = require 'utils'

--validArgs = validArgs or utils.invert({
validArgs = utils.invert({
 'help',
 'BringItemToDepot',
 'ConstructBuilding',
 'DestroyBuilding',
 'DumpItem',
 'LoadCageTrap',
 'LoadCatapult',
 'LoadStoneTrap',
 'LoadWeaponTrap',
 'ManageWorkOrders',
 'PenLargeAnimal',
 'PenSmallAnimal',
 'PullLever',
 'RecoverPet',
 'RecoverWounded',
 'ReleaseLargeCreature',
 'ReleasePet',
 'ReleaseSmallCreature',
 'RemoveConstruction',
 'StoreItemInBag',
 'StoreItemInBarrel',
 'StoreItemInBin',
 'StoreItemInHospital',
 'StoreItemInLocation',
 'StoreItemInStockpile',
 'StoreItemInVehicle',
 'TameAnimal',
 'TameVermin',
 'TradeAtDepot',
 'TrainAnimal',
 'TrainHuntingAnimal',
 'TrainWarAnimal',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

local function donow(type_of_job)
    for k, post in pairs(df.global.world.job_postings) do
        if not post.flags.dead then
            local job = post.job
            local job_type = job.job_type
            if job_type == type_of_job and not job.flags.do_now then
                job.flags.do_now = true
                print(('Job at index %d updated.'):format(k))
            end
        end
    end
end

local function filter_args(list_of_jobs)
    for job_name, i in pairs(validArgs) do
        if list_of_jobs[job_name] and df.job_type[job_name] then
            print('Setting do_now flag on jobs of type: ' .. job_name)
            donow(df.job_type[job_name])
        end
    end
end

filter_args(args)
