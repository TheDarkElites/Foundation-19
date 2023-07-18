/datum/scp

	///SCP name
	var/name
	///SCP Designation (i.e 173 or 096)
	var/designation
	///SCP Class (SAFE, EUCLID, ETC.)
	var/classification

	///Meta Flags for the SCP
	var/metaFlags

	///Flags that determine how a memetic scp is detected
	var/memeticFlags

	///Datum Parent
	var/atom/parent

	///Components
	var/datum/component/memetic/meme_comp

	///Proc called as an effect from memetic scps
	var/memetic_proc

/datum/scp/New(atom/creation, vName, vClass = SAFE, vDesg, vMetaFlags)
	GLOB.SCP_list += creation

	name = vName
	designation = vDesg
	classification = vClass
	metaFlags = vMetaFlags

	parent = creation

	parent.SetName(name)

	set_faction(parent, FACTION_SCPS)

	if(ismob(parent))
		var/mob/pMob = parent
		pMob.fully_replace_character_name(name)

	onGain()

/datum/scp/Destroy()
	. = ..()
	if(LAZYLEN(GLOB.SCP_list))
		GLOB.SCP_list -= src
	parent = null

///Run only after adding appropriate flags for components.
/datum/scp/proc/compInit() //if more comps are added for SCPs, they can be put here
	if(metaFlags & MEMETIC)
		meme_comp = parent.AddComponent(/datum/component/memetic, memeticFlags, memetic_proc)

/datum/scp/proc/isCompatible(atom/A)
	return 1

/datum/scp/proc/Remove()
	if(parent)
		onLose()
		parent.TakeComponent(meme_comp)
		parent.SCP = null
		qdel(src)

	else
		qdel(src)

/datum/scp/proc/onGain()

/datum/scp/proc/onLose()

/atom/proc/canBeSCP(datum/scp/SCP_)
	return SCP_.isCompatible(src)
