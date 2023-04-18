GLOBAL_LIST_EMPTY(scp173s)

/datum/scp/scp_173
	name = "SCP-173"
	designation = "173"
	classification = EUCLID

/mob/living/scp_173
	name = "SCP-173"
	desc = "A statue, constructed from concrete and rebar with traces of Krylon brand spray paint."
	icon = 'icons/SCP/scp-173.dmi'
	icon_state = "173"
	SCP = /datum/scp/scp_173
	status_flags = NO_ANTAG

	see_invisible = SEE_INVISIBLE_NOLIGHTING
	see_in_dark = 7

	maxHealth = 5000
	health = 5000

	mob_size = MOB_LARGE //173 should not be able to be pulled around by humans

	can_pull_size = 0 // Can't pull things
	a_intent = "harm" // Doesn't switch places with people
	can_be_buckled = FALSE

	/// Reference to the area we were created in
	var/area/spawn_area

	/// List of humans under the blinking influence
	var/list/next_blinks = list()
	/// List of times at which humans joined the list (Used for HUD calculation)
	var/list/next_blinks_join_time = list()

	/// Current attack cooldown
	var/snap_cooldown
	/// Amount of the attack cooldown
	var/snap_cooldown_time = 4 SECONDS
	/// Current light break cooldown
	var/light_break_cooldown
	/// Amount of light fixture break cooldown
	var/light_break_cooldown_time = 3 SECONDS
	/// Cooldown for defecation...
	var/defecation_cooldown
	/// How much time you have to wait before defecating again
	var/defecation_cooldown_time = 45 SECONDS
	/// What kind of objects/effects we spawn on defecation. Also used when checking the area
	var/list/defecation_types = list(/obj/effect/decal/cleanable/blood/gibs/red, /obj/effect/decal/cleanable/vomit, /obj/effect/decal/cleanable/mucus)

	/// Simple cooldown for warning message for passive breach
	var/warning_cooldown
	/// Same, but for breaching effect
	var/breach_cooldown

	/// This one to avoid sound spam when opening doors
	var/door_cooldown

	///AI Related vars

	//AI's current target
	var/atom/movable/target
	//How many tiles 173 moves in a single run of life
	var/tile_move_range = 3
	//How far wander targets can be set
	var/wander_distance = 8
	//How far fleeing targets can be set
	var/flee_distance = 30
	//Are we fleeing?
	var/is_fleeing = FALSE

/mob/living/scp_173/Initialize()
	GLOB.scp173s += src
	defecation_cooldown = world.time + 10 MINUTES // Give everyone some time to prepare
	spawn_area = get_area(src)
	add_language(LANGUAGE_EAL, FALSE)
	add_language(LANGUAGE_SKRELLIAN, FALSE)
	add_language(LANGUAGE_GUTTER, FALSE)
	add_language(LANGUAGE_SIGN, FALSE)
	add_language(LANGUAGE_ENGLISH, FALSE)
	return ..()

/mob/living/scp_173/Destroy()
	for(var/mob/living/carbon/human/H in next_blinks)
		H.disable_blink(src)
	next_blinks = null
	next_blinks_join_time = null
	target = null

	GLOB.scp173s -= src
	return ..()

/mob/living/scp_173/say(message)
	return // lol you can't talk

/mob/living/scp_173/Move(a,b,f)
	if(IsBeingWatched())
		return FALSE
	return ..()

/mob/living/scp_173/face_atom(atom/A)
	if(IsBeingWatched())
		return FALSE
	return ..()

/mob/living/scp_173/movement_delay()
	return -5

/mob/living/scp_173/UnarmedAttack(atom/A)
	if(IsBeingWatched() || incapacitated())// We can't do anything while being watched
		return
	if(ishuman(A))
		if(snap_cooldown > world.time)
			to_chat(src, SPAN_WARNING("You can't attack yet."))
			return
		var/mob/living/carbon/human/H = A
		if(H.SCP)
			to_chat(src, SPAN_WARNING("<I>[H] is a fellow SCP!</I>"))
			return
		if(H.stat == DEAD)
			to_chat(src, SPAN_WARNING("<I>[H] is already dead!</I>"))
			return
		snap_cooldown = world.time + snap_cooldown_time
		visible_message(SPAN_DANGER("[src] snaps [H]'s neck!"))
		playsound(loc, pick('sound/scp/spook/NeckSnap1.ogg', 'sound/scp/spook/NeckSnap3.ogg'), 50, 1)
		show_sound_effect(loc, src)
		H.death()
		return
	if(istype(A, /obj/machinery/door))
		OpenDoor(A)
		return
	if(istype(A,/obj/machinery/floor_light))
		if(get_area(A) == spawn_area)
			to_chat(src, SPAN_WARNING("You can't reach the lights in your own containment zone."))
			return
		if(light_break_cooldown > world.time) //cooldown
			to_chat(src, SPAN_WARNING("You can't break that yet."))
			return
		var/obj/machinery/floor_light/W = A
		W.physical_attack_hand(src)
		light_break_cooldown = world.time + light_break_cooldown_time
		return
	if(istype(A,/obj/machinery/light))
		if(get_area(A) == spawn_area)
			to_chat(src, SPAN_WARNING("You can't reach the lights in your own containment zone."))
			return
		if(light_break_cooldown > world.time) //cooldown
			to_chat(src, SPAN_WARNING("You can't break that yet."))
			return
		var/obj/machinery/light/W = A
		W.broken()
		light_break_cooldown = world.time + light_break_cooldown_time
		return
	if(istype(A,/obj/structure/window))
		var/obj/structure/window/W = A
		W.shatter()
		return
	if(istype(A,/obj/structure/grille))
		playsound(get_turf(A), 'sound/effects/grillehit.ogg', 50, 1)
		qdel(A)
		return
	if(istype(A, /obj/structure/inflatable))
		var/obj/structure/inflatable/W = A
		W.deflate(violent=1)
	if(istype(A, /obj/structure/closet))
		var/obj/structure/closet/C = A
		if(C.open())
			return
		C.dump_contents()
		QDEL_NULL(C)
	return

/mob/living/scp_173/Life()
	. = ..()
	//if(length(GLOB.clients) <= 30 && !client)
		//return
	//In case we are caged, we must see if our cage is being looked at rather than us
	var/list/our_view = dview(7, istype(loc, /obj/structure/scp173_cage) ? loc : src)
	for(var/mob/living/carbon/human/H in next_blinks)
		if(!(H in our_view))
			H.disable_blink(src)
			next_blinks -= H
	for(var/mob/living/carbon/human/H in our_view)
		H.enable_blink(src)
		next_blinks += H
	handle_regular_hud_updates()
	process_blink_hud(src)
	if(!isturf(loc)) // Inside of something
		return
	if(world.time > defecation_cooldown)
		Defecate()
	if(client) // AI controls from here
		return
	handle_AI()

/mob/living/scp_173/ClimbCheck(atom/A)
	if(IsBeingWatched())
		to_chat(src, SPAN_DANGER("You can't climb while being watched."))
		return FALSE
	return TRUE

/mob/living/scp_173/proc/IsBeingWatched()
	// Same as before, cage needs to be used as reference rather than 173
	var/atom/A = src
	if(istype(loc, /obj/structure/scp173_cage))
		A = loc
	for(var/mob/living/L in dview(7, A))
		if((istype(L, /mob/living/simple_animal/scp_131)) && (InCone(L, L.dir)))
			return TRUE
		if(!istype(L, /mob/living/carbon/human))
			continue
		var/mob/living/carbon/human/H = L
		if(H.SCP)
			continue
		if(H.can_see(A))
			return TRUE
	return FALSE

/mob/living/scp_173/proc/OpenDoor(obj/machinery/door/A)
	if(door_cooldown > world.time)
		return

	if(!istype(A))
		return

	if(!A.density)
		return

	if(!A.Adjacent(src))
		to_chat(src, SPAN_WARNING("\The [A] is too far away."))
		return

	var/open_time = 3 SECONDS
	if(istype(A, /obj/machinery/door/blast))
		if(get_area(A) == spawn_area)
			to_chat(src, SPAN_WARNING("You cannot open blast doors in your containment zone."))
			return
		open_time = 15 SECONDS

	if(istype(A, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/AR = A
		if(AR.locked)
			open_time += 2 SECONDS
		if(AR.welded)
			open_time += 2 SECONDS
		if(AR.secured_wires)
			open_time += 2 SECONDS

	A.visible_message(SPAN_WARNING("\The [src] begins to pry open \the [A]!"))
	playsound(get_turf(A), 'sound/machines/airlock_creaking.ogg', 35, 1)
	door_cooldown = world.time + open_time // To avoid sound spam
	if(!do_after(src, open_time, A))
		return

	if(istype(A, /obj/machinery/door/blast))
		var/obj/machinery/door/blast/DB = A
		DB.visible_message(SPAN_DANGER("\The [src] forcefully opens \the [DB]!"))
		DB.force_open()
		return

	if(istype(A, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/AR = A
		AR.unlock(TRUE) // No more bolting in the SCPs and calling it a day
		AR.welded = FALSE
	A.stat |= BROKEN
	var/check = A.open(1)
	src.visible_message("\The [src] slices \the [A]'s controls[check ? ", ripping it open!" : ", breaking it!"]")

/mob/living/scp_173/proc/Defecate()
	if(!isobj(loc) && world.time > defecation_cooldown)
		defecation_cooldown = world.time + defecation_cooldown_time
		var/feces = pick(defecation_types)
		var/obj/effect/new_f = new feces(loc)
		new_f.update_icon()
		if(!client) // So it doesn't spam it in one spot
			var/Tdir = pick(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
			//if(Tdir && !IsBeingWatched())
				//SelfMove(Tdir)
	// Breach check
	var/feces_amount = CheckFeces()
	if(feces_amount >= 60) // Breach, gonna take ~45 minutes
		if(breach_cooldown > world.time)
			return
		breach_cooldown = world.time + 15 MINUTES
		warning_cooldown = world.time + 5 MINUTES // Just in case 173 doesn't immediately leave the area
		command_announcement.Announce("ALERT! SCP-173 containment zone security measures have shut down due to severe acidic degradation.")
		BreachEffect()
	else if((feces_amount >= 40) && world.time > warning_cooldown) // Warning, after ~20 minutes
		warning_cooldown = world.time + 2 MINUTES
		command_announcement.Announce("ATTENTION! SCP-173 containment zone is suffering from mild acidic degradation. Janitorial services involvement is required.")

/mob/living/scp_173/proc/CheckFeces(containment_zone = TRUE) // Proc that returns amount of 173 feces in the area
	var/area/A = get_area(src)
	if((A != spawn_area) && containment_zone) // Not in containment zone
		return 0
	var/feces_amount = 0
	for(var/obj/O in A)
		if(O.type in defecation_types)
			feces_amount += 1
			continue
	return feces_amount

/mob/living/scp_173/proc/BreachEffect()
	var/area/A = get_area(src)
	A.full_breach()

// 173 AI procs

/mob/living/scp_173/proc/handle_AI()
	if(IsBeingWatched())
		if(is_fleeing) //resets fleeing state if we are looked at
			is_fleeing = FALSE
			target = null
		return
	if(istype(loc, /obj/structure/scp173_cage))
		loc.relaymove(src, NORTH) //just moves us north to try to break free from the cage
		return

	var/list/possible_human_targets = list()

	for(var/mob/living/carbon/human/H in dview(7, src)) //Identifies possible targets
		if(H.SCP)
			continue
		if(H.stat == DEAD)
			continue
		//if(!AStar(loc, H.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, max_nodes=25, max_node_depth=7, id=all_access_ID))
			//continue // We can't reach this person anyways
		possible_human_targets += H

	if(target) //this will handle any no longer valid targets
		switch(target.type)
			if(/mob/living/carbon/human)
				var/mob/living/carbon/human/H = target
				if(!(H in possible_human_targets))
					target = null
			if(/obj/machinery/light)
				var/obj/machinery/light/L = target
				if(L.get_status() != LIGHT_OK)
					target = null
			if(/turf)
				if(LAZYLEN(possible_human_targets) && !is_fleeing) //If we get a possible target or if our wandering target is invalid we stop wandering and remove our wander target
					target = null

	if(target && get_dist(loc, get_turf(target)) <= 1)
		if(!isturf(target)) //If 173 has a non wander (non turf) target, and we are in range, we will attack
			UnarmedAttack(target)
		else //Otherwise, we just wipe the target turf 173 was wandering to
			target = null
		return

	if(target || is_fleeing) //dont need to pick a target if we're fleeing or already have one
		move_to_target()
		return

	var/turf/our_turf = get_turf(src)

	switch(LAZYLEN(possible_human_targets))
		if(0)
			if(prob(50)) //If we have no targets, 50% chance we will choose a wander target
				target = pick_turf_in_range(loc, wander_distance, list(/proc/isfloor))

		if(1,2) //If we have a manageable amount of targets, we will pursue or try to break a light
			if(((our_turf.get_lumcount() > 0.1) && prob(30)) && !istype(target, /obj/machinery/light))
				target = get_viable_light_target()
			else
				target = DEFAULTPICK(possible_human_targets, null)

		if(3,INFINITY) //If we have too many targets, we will attempt to flee or break a light
			if((our_turf.get_lumcount() > 0.1) && !istype(target, /obj/machinery/light))
				if(prob(60) && !is_fleeing)
					target = get_viable_flee_target()
					is_fleeing = TRUE
				else
					target = get_viable_light_target()

	move_to_target()
	return

/mob/living/scp_173/proc/move_to_target() //since we need to move 173 multiple times in order to simulate its speed, 173 has its own function for this
	var/turf/step_turf = get_step_towards(src, target)

	for(var/obj/obstacle in step_turf.contents) //we will handle any obstacles, if there are any, instead of moving
		if(istype(obstacle, /obj/machinery/door)) //Break doors
			var/obj/machinery/door/D = obstacle
			if(!D.density)
				continue
			if((get_area(D) == spawn_area))
				continue
			UnarmedAttack(D)
			return
		else if(obstacle.can_climb(src)) //If we can climb it, we should
			obstacle.do_climb(src)
			return
		else if(istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/grille)) //Break windows
			UnarmedAttack(obstacle)
			return

	for(var/move=0, move < tile_move_range, move++)
		step_towards(src, target)

/mob/living/scp_173/proc/get_viable_flee_target()
	var/turf/simulated/floor/flee_target = pick_turf_in_range(loc, flee_distance, list(/proc/isfloor))
	var/count = 0 //dont want the while loop going to infinity

	while(!AStar(loc, flee_target, /turf/proc/AdjacentTurfs, /turf/proc/Distance, max_nodes=25, max_node_depth=7)) //we ignore doors as we can break them
		flee_target = pick_turf_in_range(loc, flee_distance, list(/proc/isfloor))
		count++
		if(count >= 50)
			return

	return flee_target

/mob/living/scp_173/proc/get_viable_light_target() //Gets a viable light bulb target
	for(var/obj/machinery/light/light_in_view in dview(7, src))
		if(get_area(light_in_view) == spawn_area)
			continue
		if(light_in_view.get_status() != LIGHT_OK)
			continue
		if(!AStar(loc, light_in_view.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, max_nodes=25, max_node_depth=7))
			continue
		return light_in_view
	return null

/*
/mob/living/scp_173/proc/AIAttemptAttack()
	var/mob/living/carbon/human/target
	var/list/possible_human_targets = list()
	var/turf/T
	for(var/mob/living/carbon/human/H in view(7, src))
		if(H.SCP)
			continue
		if(H.stat == DEAD)
			continue
		if(!AStar(loc, H.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, max_nodes=25, max_node_depth=7))
			continue // We can't reach this person anyways
		possible_human_targets += H
	if(LAZYLEN(possible_human_targets))
		target = pick(possible_human_targets)
	if(target)
		var/turf/behind_target = get_step(target.loc, turn(target.dir, 180))
		if(isfloor(behind_target) && get_dist(behind_target, loc) <= 7)
			T = behind_target
		else
			var/list/directions = shuffle(GLOB.cardinal)
			for(var/D in directions)
				var/turf/TF = get_step(target, D)
				if(isfloor(T) && get_dist(T, loc) <= 7)
					T = TF
					break
		if(!T) // We couldn't find a spot to go to!
			return
		forceMove(T)
		UnarmedAttack(target)
*/

// 173 Cage

/obj/structure/scp173_cage
	name = "SCP-173 Containment Cage"
	desc = "An empty cage for containing SCP-173."
	icon = 'icons/SCP/cage.dmi'
	icon_state = "open"
	density = TRUE
	layer = MOB_LAYER + 0.05
	var/resist_cooldown
	/// Current damage points of the cage
	var/damage_state = 0
	/// Maximum damage points, upon which cage becomes unusable and 173, if inside, escapes
	var/damage_state_max = 5

/obj/structure/scp173_cage/MouseDrop_T(atom/movable/dropping, mob/user) // When someone drags 173 onto the cage
	if(locate(/mob/living) in contents)
		to_chat(user, SPAN_WARNING("\The [src] is already full!"))
		return FALSE
	if(damage_state >= damage_state_max)
		to_chat(user, SPAN_WARNING("\The [src] is too damaged to operate!"))
		return FALSE
	if(isscp173(dropping))
		visible_message(SPAN_WARNING("[user] starts to put [dropping] into the cage."))
		var/oloc = loc
		if(do_after(user, 10 SECONDS, dropping) && loc == oloc)
			dropping.forceMove(src)
			update_icon()
			visible_message(SPAN_NOTICE("[user] puts [dropping] in the cage."))
			playsound(loc, 'sound/machines/bolts_down.ogg', 50, 1)
			return TRUE
		return FALSE
	if(isliving(dropping))
		to_chat(user, SPAN_WARNING("\The [dropping] won't fit in the cage."))
	return FALSE

/obj/structure/scp173_cage/attack_hand(mob/living/L)
	if(!LAZYLEN(contents))
		return ..()
	visible_message(SPAN_WARNING("[L] attempts to open \the [src]."))
	if(do_after(L, 5 SECONDS, src))
		visible_message(SPAN_DANGER("[L] opens \the [src]!"))
		ReleaseContents()

/obj/structure/scp173_cage/relaymove(mob/living/scp_173/user, direction)
	if(resist_cooldown > world.time)
		return
	resist_cooldown = world.time + 5 SECONDS
	if(user.IsBeingWatched())
		to_chat(user, SPAN_WARNING("Someone is looking at you!"))
		return
	if(!do_after(user, 1 SECONDS, src)) // Some moron suggested putting 173 in a conveyor loop.
		return
	if(user.IsBeingWatched())
		to_chat(user, SPAN_WARNING("Someone is looking at you!"))
		return
	damage_state += 1
	update_icon()
	if(damage_state < damage_state_max)
		visible_message(SPAN_WARNING("[user] damages \the [src]!"))
		playsound(src, 'sound/effects/grillehit.ogg', 35, TRUE)
		return
	visible_message(SPAN_DANGER("[user] opens \the [src] from the inside!"))
	ReleaseContents()

/obj/structure/scp173_cage/examine(mob/user, distance, infix = "", suffix = "")
	. = ..()
	for(var/mob/M in contents)
		to_chat(user, "[icon2html(M, user)] It has [M] inside of it!")
	switch(damage_state)
		if(1, 2)
			to_chat(user, SPAN_NOTICE("It looks slightly damaged."))
		if(3, 4)
			to_chat(user, SPAN_WARNING("It is seriously damaged!"))
		if(5 to INFINITY)
			to_chat(user, SPAN_DANGER("It is completely broken!"))

// Updates icon state and underlays
/obj/structure/scp173_cage/update_icon()
	underlays.Cut()

	if(!LAZYLEN(contents))
		plane = initial(plane)
		icon_state = "open"
	else
		plane = MOB_PLANE
		icon_state = "closed"

	switch(damage_state)
		if(1, 2)
			icon_state = "damage_1"
		if(3, 4)
			icon_state = "damage_2"
		if(5 to INFINITY)
			icon_state = "damage_3"

	for(var/mob/M in contents)
		underlays += image(M)

/obj/structure/scp173_cage/attackby(obj/item/I, mob/user) //Gotta be able to repair the cage
	if(!isWelder(I))
		return
	if(LAZYLEN(contents))
		to_chat(user, SPAN_WARNING("\The [src] must be empty to complete this task!"))
		return
	if(damage_state <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] is not damaged."))
		return

	var/obj/item/weldingtool/WT = I
	if(!WT.isOn())
		to_chat(user, SPAN_WARNING("\The [WT] must be on to complete this task."))
		return
	if(WT.get_fuel() < damage_state)
		to_chat(user, SPAN_WARNING("You will need more fuel to repair [src]."))
		return
	playsound(src, 'sound/items/Welder2.ogg', 30, TRUE)
	user.visible_message(SPAN_NOTICE("\The [user] starts repairing sections of \the [src]."))
	if(!do_after(user, (4 SECONDS) + (damage_state SECONDS), src))
		return FALSE
	if(!WT.remove_fuel(damage_state, user))
		return
	user.visible_message(SPAN_NOTICE("\The [user] successfuly repairs a section of \the [src]."))
	damage_state -= 1
	update_icon()
	if(damage_state <= 0)
		visible_message(SPAN_NOTICE("\The [src] is completely repaired!"))
	playsound(src.loc, 'sound/items/Welder.ogg', 30, 1)
	return TRUE

/obj/structure/scp173_cage/proc/ReleaseContents() //Releases cage contents
	if(!LAZYLEN(contents))
		return FALSE
	playsound(loc, 'sound/machines/bolts_up.ogg', 50, 1)
	for(var/mob/living/L in contents)
		L.forceMove(get_turf(src))
	update_icon()
	return TRUE

/obj/structure/scp173_cage/Destroy()
	ReleaseContents()
	return ..()

/*
 * Acid
 */
 #define ACID_STRONG     2
 #define ACID_MODERATE   1.5
 #define ACID_WEAK       1

/obj/effect/acid
	name = "acid"
	desc = "Burbling corrosive stuff. Probably a bad idea to roll around in it."
	icon_state = "acid"
	icon = 'icons/mob/alien.dmi'

	density = FALSE
	opacity = 0
	anchored = TRUE

	var/atom/target
	var/acid_strength = ACID_WEAK
	var/melt_time = 60 SECONDS
	var/last_melt = 0

/obj/effect/acid/Initialize(loc, supplied_target)
	..(loc)
	target = supplied_target
	melt_time = melt_time / acid_strength
	START_PROCESSING(SSprocessing, src)

/obj/effect/acid/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	target = null
	. = ..()

/obj/effect/acid/Process()
	if(QDELETED(target))
		qdel(src)
	else if(world.time > last_melt + melt_time)
		var/done_melt = target.acid_melt()
		last_melt = world.time
		if(done_melt)
			qdel(src)

/atom/var/acid_melted = 0

/atom/proc/acid_melt()
	. = FALSE
	switch(acid_melted)
		if(0)
			visible_message(SPAN_CLASS("euclid","Acid hits \the [src] with a sizzle!"))
		if(1 to 3)
			visible_message(SPAN_CLASS("euclid","The acid melts \the [src]!"))
		if(4)
			visible_message(SPAN_CLASS("euclid","The acid melts \the [src] away into nothing!"))
			. = TRUE
			qdel(src)
	acid_melted++
