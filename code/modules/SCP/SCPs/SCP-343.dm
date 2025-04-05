/mob/living/carbon/human/scp343
	name = "strange elderly man"
	desc = "A mysterious powerful man. He looks a lot like what you would imagine god to look like."
	icon = 'icons/SCP/scp-343.dmi'
	icon_state = null

	see_invisible = SEE_INVISIBLE_NOLIGHTING
	see_in_dark = 7

	status_flags = CANPUSH|GODMODE

	roundstart_traits = list(TRAIT_ADVANCED_TOOL_USER)

	//Config

	///Cooldown for our phasing wall ability
	var/phase_cooldown = 5 SECONDS
	///Cooldown for regular phasing ability
	var/phase_cooldown_regular = 2 SECONDS
	///How long it takes us to phase
	var/phase_time = 2 SECONDS
	///What alpha level are we when we are invisible
	var/phase_alpha = 20
	///Move speed when we are phased out
	var/phased_move_delay = 1.0

	//Mechanical

	///Cooldow tracker for our phasing wall ability
	var/phase_cooldown_track
	///Cooldown tracker for our phase ability
	var/phase_cooldown_track_regular
	///Our set movespeed
	var/move_speed_delay
	///Set Alpha (to know what to phase back to)
	var/set_alpha

/mob/living/carbon/human/scp343/Initialize(mapload, new_species = "SCP-343")
	. = ..()
	SCP = new /datum/scp(
		src, // Ref to actual SCP atom
		"strange elderly man", //Name (Should not be the scp desg, more like what it can be described as to viewers)
		SCP_SAFE, //Obj Class
		"343", //Numerical Designation
		SCP_PLAYABLE|SCP_ROLEPLAY
	)

	add_language(LANGUAGE_ENGLISH)
	add_language(LANGUAGE_HUMAN_FRENCH)
	add_language(LANGUAGE_HUMAN_GERMAN)
	add_language(LANGUAGE_HUMAN_SPANISH)
	if(!(MUTATION_XRAY in mutations))
		mutations.Add(MUTATION_XRAY)
		update_mutations()
		update_sight()

	add_verb(src, /mob/living/carbon/human/scp343/verb/object_phase)
	add_verb(src, /mob/living/carbon/human/scp343/verb/phase_in_verb)
	add_verb(src, /mob/living/carbon/human/scp343/verb/phase_out_verb)

//Mechanics

/mob/living/carbon/human/scp343/verb/object_phase()
	set name = "Phase Through Object"
	set category = "SCP"
	set desc = "Phase through an object in front of you."

	if((world.time - phase_cooldown_track) < phase_cooldown)
		to_chat(src, SPAN_WARNING("You can't phase again yet."))
		return

	var/obj/target_object = null
	for(var/obj/O in get_step(src, dir))
		// Things that we will ignore
		if(!isstructure(O) && !ismachinery(O))
			continue

		if(!O.density)
			continue

		// Things that will block our phasing
		if(istype(O, /obj/machinery/shieldwall) || istype(O, /obj/machinery/shieldwallgen))
			to_chat(src, SPAN_WARNING("You cannot phase through [O]."))
			return

		// There can be more than one available dense object, but that doesn't matter
		target_object = O

	if(!istype(target_object))
		to_chat(src, SPAN_WARNING("There's nothing to phase through in that direction."))
		return

	var/turf/target_turf = get_step(target_object, dir)
	if(target_turf.density)
		to_chat(src, SPAN_WARNING("\The [target_turf] is preventing us from phasing in that direction."))
		return

	phase_cooldown_track = world.time

	// Mob effects
	var/old_layer = layer
	var/anim_x = 0
	var/anim_y = 0
	layer = OBSERVER_LAYER
	alpha = phase_alpha

	if(dir in list(NORTH, NORTHEAST, NORTHWEST))
		anim_y = 32
	if(dir in list(SOUTH, SOUTHEAST, SOUTHWEST))
		anim_y = -32
	if(dir in list(EAST, NORTHEAST, SOUTHEAST))
		anim_x = 32
	if(dir in list(WEST, NORTHWEST, SOUTHWEST))
		anim_x = -32
	animate(src, pixel_x = anim_x, pixel_y = anim_y, time = phase_time)

	if(do_after(src, phase_time, target_object))
		forceMove(get_step(src, dir))
		visible_message(SPAN_NOTICE("[src] silently phases through [target_object]"))

	layer = old_layer
	pixel_x = 0
	pixel_y = 0
	alpha = set_alpha

/mob/living/carbon/human/scp343/verb/phase_out_verb()
	set name = "Phase Out"
	set category = "SCP"
	set desc = "Become barley visible and incredibly fast."

	if (alpha < 255)
		to_chat(src, SPAN_ALERT("You are already phased out!"))
		return

	if((world.time - phase_cooldown_track_regular) < phase_cooldown_regular)
		to_chat(src, SPAN_WARNING("You can't phase again yet."))
		return

	phase_cooldown_track_regular = world.time

	alpha = phase_alpha
	set_alpha = phase_alpha
	move_speed_delay = phased_move_delay

	visible_message(SPAN_NOTICE("[src] silently phases out of exsistence."), SPAN_NOTICE("You phase out of reality."))

/mob/living/carbon/human/scp343/verb/phase_in_verb()
	set name = "Phase In"
	set category = "SCP"
	set desc = "Become synced with reality again."

	if (alpha == 255)
		to_chat(src, SPAN_ALERT("You are already phased in!"))
		return

	alpha = 255
	set_alpha = 255
	move_speed_delay = 3.0 // Default speed

	visible_message(SPAN_NOTICE("[src] silently phases into exsistence."), SPAN_NOTICE("You phase back into reality."))

//Overrides

/mob/living/carbon/human/scp343/UnarmedAttack(atom/A, proximity)
	if((a_intent == I_HURT) && iscarbon(A))
		to_chat(src, SPAN_WARNING("You know better than to hurt one of your own children."))
		return

	if((a_intent == I_HELP) && ismob(A))
		var/mob/living/target = A
		to_chat(src, SPAN_WARNING("You start to heal [target]'s wounds"))
		visible_message(SPAN_NOTICE("\The [src] starts to heal [target]'s wounds"))
		if(!do_after(src, 12 SECONDS, A, bonus_percentage = 25))
			return
		target.revive()
		visible_message(SPAN_NOTICE("\The [src] has fully healed [target]!"))
		return

	return ..()

/mob/living/carbon/human/scp343/get_pressure_weakness()
	return 0

/mob/living/carbon/human/scp343/handle_breath()
	return 1

/mob/living/carbon/human/scp343/movement_delay(decl/move_intent/using_intent = move_intent)
	return move_speed_delay

//TODO: Change pathing of SCPs to no longer be humans so that we dont have to do this bullshit.
/mob/living/carbon/human/scp343/update_icons()
	return

/mob/living/carbon/human/scp343/on_update_icon()
	if(lying || resting)
		var/matrix/M =  matrix()
		transform = M.Turn(90)
	else
		transform = null
	return
