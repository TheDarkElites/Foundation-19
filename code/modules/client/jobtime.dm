// this is for timelocks, written by TheDarkElites

/datum/jobtime
	var/is_guest = FALSE
	var/load_failed = null

	var/client/client = null
	var/client_ckey = null

	var/list/jobtimes = list()

	var/current_job = null
	var/start_time = null

/datum/jobtime/New(client/C)
	if(istype(C))
		client = C
		client_ckey = C.ckey
		SScharacter_setup.jobtime_datums[C.ckey] = src

		if(SScharacter_setup.initialized)
			setup()
		else
			SScharacter_setup.jobtime_awaiting_setup += src

/datum/jobtime/proc/setup()

	if(client)
		if(IsGuestKey(client.key))
			is_guest = TRUE
		else
			for(var/job in SSjobs.primary_job_datums) //initializes our jobs from map jobs
				jobtimes[job] = 0
			load_data()

/datum/jobtime/proc/load_data()
	load_failed = null
	var/stage = "pre"
	try
		var/pref_path = get_path(client_ckey, "jobtime")
		if(!fexists(pref_path))
			return
		stage = "load"
		load_job_time()
	catch(var/exception/E)
		load_failed = "{[stage]} [E]"
		throw E
