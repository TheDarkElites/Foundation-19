SUBSYSTEM_DEF(character_setup_and_track)
	name = "Character Setup and Track"
	init_order = SS_INIT_CHAR_SETUP
	priority = SS_PRIORITY_CHAR_SETUP
	flags = SS_BACKGROUND
	wait = 1 SECOND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT

	var/last_fired

	var/list/prefs_awaiting_setup = list()
	var/list/jobtime_awaiting_setup = list()
	var/list/preferences_datums = list()
	var/list/jobtime_datums = list()
	var/list/newplayers_requiring_init = list()

	var/list/save_queue_pref = list()
	var/list/save_queue_jobtime = list()

/datum/controller/subsystem/character_setup_and_track/Initialize()
	last_fired = world.time
	while(prefs_awaiting_setup.len)
		var/datum/preferences/prefs = prefs_awaiting_setup[prefs_awaiting_setup.len]
		prefs_awaiting_setup.len--
		prefs.setup()
	while(jobtime_awaiting_setup.len)
		var/datum/jobtime/jobtimes = jobtime_awaiting_setup[jobtime_awaiting_setup.len]
		jobtime_awaiting_setup.len--
		jobtimes.setup()
	while(newplayers_requiring_init.len)
		var/mob/new_player/new_player = newplayers_requiring_init[newplayers_requiring_init.len]
		newplayers_requiring_init.len--
		new_player.deferred_login()
	. = ..()

/datum/controller/subsystem/character_setup_and_track/fire(resumed = FALSE)
	while(save_queue_pref.len)
		var/datum/preferences/prefs = save_queue_pref[save_queue_pref.len]
		save_queue_pref.len--

		if(!QDELETED(prefs))
			prefs.save_preferences()

		if(MC_TICK_CHECK)
			break

	while(save_queue_jobtime.len)
		var/datum/jobtime/jobtimes = save_queue_jobtime[save_queue_jobtime.len]
		save_queue_jobtime.len--

		if(!QDELETED(jobtimes))
			jobtimes.save_job_time()

		if(MC_TICK_CHECK)
			break

	handle_jobtime_update()

/datum/controller/subsystem/character_setup_and_track/proc/queue_preferences_save(datum/preferences/prefs)
	save_queue_pref |= prefs

/datum/controller/subsystem/character_setup_and_track/proc/queue_jobtime_save(datum/jobtime/jobtimes)
	save_queue_jobtime |= jobtimes

/datum/controller/subsystem/character_setup_and_track/proc/handle_jobtime_update()
	var/time_elapsed_since_last_fire = world.time - last_fired
	last_fired = world.time

	//if(!SSdbcore.Connect())
		//return -1

	for(var/client/C in GLOB.clients)
		if(C.is_afk())
			continue
		if(!ishuman(C.mob)) //TODO: Implement tracking for more than just human jobs (Oberservers, antags, SCPs and other non humans, etc.)
			continue
		var/mob/living/carbon/human/H = C.mob
		var/datum/jobtime/jobtimes = jobtime_datums[C.ckey]
		jobtimes.update_job_time(H.mind.assigned_job, time_elapsed_since_last_fire)
