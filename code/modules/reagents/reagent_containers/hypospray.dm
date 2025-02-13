////////////////////////////////////////////////////////////////////////////////
/// HYPOSPRAY
////////////////////////////////////////////////////////////////////////////////

/obj/item/reagent_containers/hypospray //obsolete, use hypospray/vial for the actual hypospray item
	name = "hypospray"
	desc = "The DeForest Medical Corporation, a subsidiary of Zeng-Hu Pharmaceuticals, hypospray is a sterile, air-needle autoinjector for rapid administration of drugs to patients."
	icon = 'icons/obj/syringe.dmi'
	item_state = "hypo"
	icon_state = "hypo"
	origin_tech = list(TECH_MATERIAL = 4, TECH_BIO = 5)
	amount_per_transfer_from_this = 5
	acid_resistance = -1
	volume = 30
	possible_transfer_amounts = null
	atom_flags = ATOM_FLAG_OPEN_CONTAINER
	slot_flags = SLOT_BELT

	// autoinjectors takes less time than a normal syringe (overriden for hypospray).
	// This delay is only applied when injecting concious mobs, and is not applied for self-injection
	// The 1.9 factor scales it so it takes the following number of seconds:
	// NONE   1.47
	// BASIC  1.00
	// ADEPT  0.68
	// EXPERT 0.53
	// PROF   0.39
	var/time = (1 SECONDS) / 1.9
	var/single_use = TRUE // autoinjectors are not refillable (overriden for hypospray)

/obj/item/reagent_containers/hypospray/attack(mob/living/M, mob/user)
	if(!reagents.total_volume)
		to_chat(user, SPAN_WARNING("[src] is empty."))
		return
	if (!istype(M))
		return

	var/allow = M.can_inject(user, check_zone(user.zone_sel.selecting))
	if(!allow)
		return

	if (allow == INJECTION_PORT)
		if(M != user)
			user.visible_message(SPAN_WARNING("\The [user] begins hunting for an injection port on \the [M]'s suit!"))
		else
			to_chat(user, SPAN_NOTICE("You begin hunting for an injection port on your suit."))
		if(!user.do_skilled(INJECTION_PORT_DELAY, SKILL_MEDICAL, M))
			return

	user.setClickCooldown(CLICK_CD_QUICK)
	user.do_attack_animation(M)

	if(user != M && !M.incapacitated() && time) // you're injecting someone else who is concious, so apply the device's intrisic delay
		to_chat(user, SPAN_WARNING("\The [user] is trying to inject \the [M] with \the [name]."))
		if(!user.do_skilled(time, SKILL_MEDICAL, M))
			return

	if(single_use && reagents.total_volume <= 0) // currently only applies to autoinjectors
		atom_flags &= ~ATOM_FLAG_OPEN_CONTAINER // Prevents autoinjectors to be refilled.

	to_chat(user, SPAN_NOTICE("You inject [M] with [src]."))
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		H.custom_pain(SPAN_WARNING("You feel a tiny prick!"), 1, TRUE, H.get_organ(user.zone_sel.selecting))

	playsound(src, 'sounds/effects/hypospray.ogg',25)
	user.visible_message(SPAN_WARNING("[user] injects [M] with [src]."))

	if(M.reagents)
		var/should_admin_log = reagents.should_admin_log()
		var/contained = reagentlist()
		var/trans = reagents.trans_to_mob(M, amount_per_transfer_from_this, CHEM_BLOOD)
		if (should_admin_log)
			admin_inject_log(user, M, src, contained, trans)
		to_chat(user, SPAN_NOTICE("[trans] units injected. [reagents.total_volume] units remaining in \the [src]."))

	return

/obj/item/reagent_containers/hypospray/vial
	name = "hypospray"
	item_state = "autoinjector"
	desc = "The DeForest Medical Corporation, a subsidiary of Zeng-Hu Pharmaceuticals, hypospray is a sterile, air-needle autoinjector for rapid administration of drugs to patients. Uses a replacable 30u vial."
	var/obj/item/reagent_containers/glass/beaker/vial/loaded_vial
	possible_transfer_amounts = "1;2;5;10;15;20;30"
	amount_per_transfer_from_this = 5
	volume = 0
	time = 0 // hyposprays are instant for conscious people
	single_use = FALSE

/obj/item/reagent_containers/hypospray/vial/New()
	..()
	loaded_vial = new /obj/item/reagent_containers/glass/beaker/vial(src)
	volume = loaded_vial.volume
	reagents.maximum_volume = loaded_vial.reagents.maximum_volume

/obj/item/reagent_containers/hypospray/vial/proc/remove_vial(mob/user, swap_mode)
	if(!loaded_vial)
		return
	reagents.trans_to_holder(loaded_vial.reagents,volume)
	reagents.maximum_volume = 0
	loaded_vial.update_icon()
	user.put_in_hands(loaded_vial)
	loaded_vial = null
	if (swap_mode != "swap") // if swapping vials, we will print a different message in another proc
		to_chat(user, "You remove the vial from the [src].")

/obj/item/reagent_containers/hypospray/vial/attack_hand(mob/user)
	if(user.get_inactive_hand() == src)
		if(!loaded_vial)
			to_chat(user, SPAN_NOTICE("There is no vial loaded in the [src]."))
			return
		remove_vial(user)
		update_icon()
		playsound(loc, 'sounds/weapons/flipblade.ogg', 50, 1)
		return
	return ..()

/obj/item/reagent_containers/hypospray/vial/attackby(obj/item/W, mob/user)
	var/usermessage = ""
	if(istype(W, /obj/item/reagent_containers/glass/beaker/vial))
		if(!do_after(user, 1 SECOND, bonus_percentage = 100) || !(W in user))
			return 0
		if(!user.unEquip(W, src))
			return
		if(loaded_vial)
			remove_vial(user, "swap")
			usermessage = "You load \the [W] into \the [src] as you remove the old one."
		else
			usermessage = "You load \the [W] into \the [src]."
		if(W.is_open_container())
			W.atom_flags ^= ATOM_FLAG_OPEN_CONTAINER
			W.update_icon()
		loaded_vial = W
		reagents.maximum_volume = loaded_vial.reagents.maximum_volume
		loaded_vial.reagents.trans_to_holder(reagents,volume)
		user.visible_message(SPAN_NOTICE("[user] has loaded [W] into \the [src]."),SPAN_NOTICE("[usermessage]"))
		update_icon()
		playsound(src.loc, 'sounds/weapons/empty.ogg', 50, 1)
		return
	..()

/obj/item/reagent_containers/hypospray/vial/afterattack(obj/target, mob/user, proximity) // hyposprays can be dumped into, why not out? uses standard_pour_into helper checks.
	if(!proximity)
		return
	if (!reagents.total_volume && istype(target, /obj/item/reagent_containers/glass))
		var/good_target = is_type_in_list(target, list(
			/obj/item/reagent_containers/glass/beaker,
			/obj/item/reagent_containers/glass/bottle
		))
		if (!good_target)
			return
		if (!target.is_open_container())
			to_chat(user, SPAN_ITALIC("\The [target] is closed."))
			return
		if (!target.reagents?.total_volume)
			to_chat(user, SPAN_ITALIC("\The [target] is empty."))
			return
		var/trans = target.reagents.trans_to_obj(src, amount_per_transfer_from_this)
		to_chat(user, SPAN_NOTICE("You fill \the [src] with [trans] units of the solution."))
		return
	standard_pour_into(user, target)

/obj/item/reagent_containers/hypospray/autoinjector
	name = "autoinjector"
	desc = "A rapid and safe way to administer small amounts of drugs by untrained or trained personnel."
	icon_state = "injector"
	item_state = "autoinjector"
	amount_per_transfer_from_this = 5
	volume = 5
	origin_tech = list(TECH_MATERIAL = 2, TECH_BIO = 2)
	slot_flags = SLOT_BELT | SLOT_EARS
	w_class = ITEM_SIZE_TINY
	var/list/starts_with = list(/datum/reagent/medicine/inaprovaline = 5)
	var/band_color = COLOR_CYAN

/obj/item/reagent_containers/hypospray/autoinjector/New()
	..()
	for(var/T in starts_with)
		reagents.add_reagent(T, starts_with[T])
	update_icon()
	return

/obj/item/reagent_containers/hypospray/autoinjector/attack(mob/M as mob, mob/user as mob)
	..()
	update_icon()

/obj/item/reagent_containers/hypospray/autoinjector/on_update_icon()
	cut_overlays()
	if(reagents.total_volume > 0)
		icon_state = "[initial(icon_state)]1"
	else
		icon_state = "[initial(icon_state)]0"
	add_overlay(overlay_image(icon,"injector_band",band_color,RESET_COLOR))

/obj/item/reagent_containers/hypospray/autoinjector/examine(mob/user)
	. = ..(user)
	if(reagents && reagents.reagent_list.len)
		to_chat(user, SPAN_NOTICE("It is currently loaded."))
	else
		to_chat(user, SPAN_NOTICE("It is spent."))

/obj/item/reagent_containers/hypospray/autoinjector/detox
	name = "autoinjector (antitox)"
	band_color = COLOR_GREEN
	starts_with = list(/datum/reagent/medicine/dylovene = 5)

/obj/item/reagent_containers/hypospray/autoinjector/pain
	name = "autoinjector (painkiller)"
	band_color = COLOR_PURPLE
	starts_with = list(/datum/reagent/medicine/painkiller/tramadol = 5)

/obj/item/reagent_containers/hypospray/autoinjector/combatpain
	name = "autoinjector (oxycodone)"
	band_color = COLOR_DARK_GRAY
	starts_with = list(/datum/reagent/medicine/painkiller/tramadol/oxycodone = 5)

/obj/item/reagent_containers/hypospray/autoinjector/antirad
	name = "autoinjector (anti-rad)"
	band_color = COLOR_AMBER
	starts_with = list(/datum/reagent/medicine/hyronalin = 5)

/obj/item/reagent_containers/hypospray/autoinjector/mindbreaker
	name = "autoinjector"
	band_color = COLOR_DARK_GRAY
	starts_with = list(/datum/reagent/mindbreaker_toxin = 5)

/obj/item/reagent_containers/hypospray/autoinjector/empty
	name = "autoinjector"
	band_color = COLOR_WHITE
	starts_with = list()
	matter = list(MATERIAL_PLASTIC = 150, MATERIAL_GLASS = 50)
