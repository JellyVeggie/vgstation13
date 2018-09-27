///////////////////////////////////////////////////////////////////////
// CONVERTER
/*
 * These bridge the gap across electric networks, wether dc_networks, powernets, or (usually) a dc_network and a powernet
 *
 */

#define DCINPUT 1
#define ACINPUT 2
#define DCOUTPUT 4
#define ACOUTPUT 8

/obj/machinery/power/converter/
	//Icons
	var/icon_state_broken = ""
	var/icon_state_openb = ""
	var/icon_state_off = ""
	var/icon_state_on = ""

	//UI
	var/ui_tmpl = "capacitor_bank_mainframe.tmpl" //The .tmpl file used for the UI
	var/ui_name = "The Capacitor Mainframe" // The name that'll appear on the UI

	//Machine stuff
	density = 1
	machine_flags = SCREWTOGGLE | CROWDESTROY | FIXED2WORK | WRENCHMOVE

	//Converter stuff
	var/active = 0 // Wether we're transferring power or not

	var/output = 0 // How much we've actually outputted
	var/input = 0  // How much we've actually drawn
	var/target_output = 0 // How much we want to output
	var/target_input = 0  // How much we should draw to meet the output, accounting for efficiency
	var/efficiency = 1

	var/available_modes_flags = 0 //Use DCINPUT, ACINPUT, DCOUTPUT and ACOUTPUT to control wether you can wire it to DC/add terminals
	var/DC_input = 0  // USe these to determine wether you're drawing from/outputting to AC or DC, for when the machine lets you choose
	var/DC_output = 0

/obj/machinery/power/converter/New()
	..()
	RefreshParts()
	anchored = 1
	state = 1
	update_icon()

/obj/machinery/capacitor_bank/Destroy()
	if(mDC_node)
		qdel(mDC_node)
	..()

//-- Helpers --
//Should come handy for playing sounds, animations, or whatever
/obj/machinery/power/converter/proc/toggle_active()
	active = !active

//Checks wether we can proceed with the power_transfer()
/obj/machinery/power/converter/proc/working_input()
	return DC_input && get_DCnet() || !DC_input && terminal

//Checks wether we can proceed with the power_transfer()
/obj/machinery/power/converter/proc/working_output()
	return DC_output && get_DCnet() || !DC_output && get_powernet()


/obj/machinery/power/converter/proc/set_output(var/output)
	target_output = output
	target_input = target_output * (2 - efficiency)


//-- Power network Overrides --
/obj/machinery/power/converter/surplus()
	if(terminal)
		return terminal.surplus()
	return 0

/obj/machinery/power/converter/add_load(var/amount)
	if(terminal)
		terminal.add_load(amount)

//-- Power Transfer --
/obj/machinery/power/converter/proc/get_DC_input(var/input)
	var/datum/DC_network/net = get_DCnet()
	if(net)
		input = Clamp(input, 0, net.charge)
		net.add_charge(-input)
		return input
	return 0


/obj/machinery/power/converter/proc/get_AC_input(var/input)
	var/excess = surplus()
	if(excess > 0)
		input = min(excess, target_input)
		add_load(input)
		return input
	return 0


/obj/machinery/power/converter/proc/do_DC_output(var/output)
	var/datum/DC_network/net = get_DCnet()
	if(net)
		net.add_charge(output)
		return output
	return 0


/obj/machinery/power/converter/proc/do_AC_output(var/output)
	add_avail(output)
	return output


/obj/machinery/power/converter/proc/power_transfer()
	if(!(working_input() && working_output()))
		toggle_active()
		return

	input = (DC_input ? get_DC_input(target_input) : get_AC_input(target_input))
	output = (DC_output ? do_DC_output(input) : do_AC_output(input))


//-- Machine Overrides --
/obj/machinery/power/converter/process()
	if(active)
		power_transfer()
	return


//-- Interact --
/obj/machinery/power/converter/proc/attackby_Terminal(var/obj/item/weapon/W as obj, var/mob/user as mob)
	if(iscrowbar(W) && terminal)
		to_chat(user, "<span class='warning'>You must first cut the terminal from the [src]!</span>")
		return 1

	if(istype(W, /obj/item/stack/cable_coil) && !terminal)
		var/obj/item/stack/cable_coil/CC = W

		if (CC.amount < 10)
			to_chat(user, "<span class='warning'>You need 10 length cable coil to make a terminal.</span>")
			return

		if(make_terminal(user))
			CC.use(10)
			terminal.connect_to_network()

			user.visible_message(\
				"<span class='warning'>[user.name] made a terminal for the [src].</span>",\
				"You made a terminal for the [src].")
			src.stat = 0
			return 1

	else if(iswirecutter(W) && terminal)
		var/turf/T = get_turf(terminal)
		if(T.intact)
			to_chat(user, "<span class='warning'>You must remove the floor plating above the terminal first.</span>")
			return
		to_chat(user, "You begin to dismantle the [src]'s terminal...")
		playsound(src, 'sound/items/Deconstruct.ogg', 50, 1)
		if (do_after(user, src, 50) && panel_open && terminal && !T.intact)
			if (prob(50) && electrocute_mob(usr, terminal.get_powernet(), terminal))
				spark(src, 5)
				return
			getFromPool(/obj/item/stack/cable_coil, get_turf(src), 10)
			user.visible_message(\
				"<span class='warning'>[user.name] cut the cables and dismantled the power terminal.</span>",\
				"You cut the cables and dismantle the power terminal.")
			qdel(terminal)
			terminal = null


/obj/machinery/power/converter/proc/attackby_DC(var/obj/item/weapon/W as obj, var/mob/user as mob)



//-- Interact Overrides --

/obj/machinery/power/converter/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob) //these can only be moved by being reconstructed, solves having to remake the powernet.
	if(panel_open && available_modes_flags & ACINPUT)
		if(iscrowbar(W) && terminal)
			to_chat(user, "<span class='warning'>You must first cut the terminal from the [src]!</span>")
			return 1

		if(istype(W, /obj/item/stack/cable_coil) && !terminal && state)
			var/obj/item/stack/cable_coil/CC = W

			if (CC.amount < 10)
				to_chat(user, "<span class='warning'>You need 10 length cable coil to make a terminal.</span>")
				return

			if(make_terminal(user))
				CC.use(10)
				terminal.connect_to_network()

				user.visible_message(\
					"<span class='warning'>[user.name] made a terminal for the [src].</span>",\
					"You made a terminal for the [src].")
				src.stat = 0
				return 1

		else if(iswirecutter(W) && terminal)
			var/turf/T = get_turf(terminal)
			if(T.intact)
				to_chat(user, "<span class='warning'>You must remove the floor plating above the terminal first.</span>")
				return
			to_chat(user, "You begin to dismantle the [src]'s terminal...")
			playsound(src, 'sound/items/Deconstruct.ogg', 50, 1)
			if (do_after(user, src, 50) && panel_open && terminal && !T.intact)
				if (prob(50) && electrocute_mob(usr, terminal.get_powernet(), terminal))
					spark(src, 5)
					return
				getFromPool(/obj/item/stack/cable_coil, get_turf(src), 10)
				user.visible_message(\
					"<span class='warning'>[user.name] cut the cables and dismantled the power terminal.</span>",\
					"You cut the cables and dismantle the power terminal.")
				qdel(terminal)
				terminal = null
	if (available_modes_flags & DCINPUT || available_modes_flags & DCOUTPUT)
		if (istype(W, /obj/item/stack/cable_coil) && !mDC_node && state)
			var/obj/item/stack/cable_coil/CC = W
			if (CC.amount < 1)
				to_chat(user, "<span class=\"warning\">You need 1 length cable coil to wire the [src].</span>") //Should never happen, but who knows
				return

			mDC_node = new /datum/DC_node(src)
			RefreshParts()
			mDC_node.connect()

			CC.use(1)
			to_chat(user, "<span class='notice'>You wire \the [src].</span>")
			update_icon()
			return

		if (istype(W, /obj/item/weapon/wirecutters) && mDC_node)
			if(do_after(user, src, 30))
				qdel(mDC_node)

				getFromPool(/obj/item/stack/cable_coil, get_turf(src), 1)
				to_chat(user, "<span class='notice'>You cut \the [src]'s wires.</span>")
				update_icon()
				return
	..()
	return


/obj/machinery/power/converter/wrenchable()
	if(mDC_node || terminal) //Must not be wired
		return 0
	else
		return ..()


//-- Icon Overrides --
/obj/machinery/power/converter/examine(mob/user)
	..()
	if (mDC_node)
		to_chat(user, "<span class='notice'>The [src] is wired up and fixed in place.</span>")
	else if(state && (available_modes_flags & DCINPUT || available_modes_flags & DCOUTPUT))
		to_chat(user, "<span class='notice'>The [src] is anchored to the ground, but could use some wiring.</span>")

/obj/machinery/power/converter/update_icon()
	underlays.len = 0
	if(mDC_node)
		for (var/i in mDC_node.connected_dirs)
			underlays += DC_wire_underlays[i]

	if(panel_open)
		if (stat & BROKEN)
			icon_state = icon_state_openb
		else
			icon_state = icon_state_open
	else if (stat & BROKEN)
		icon_state = icon_state_broken
	else if (active)
		icon_state = icon_state_on
	else
		icon_state = icon_state_off

//-- UI --
/obj/machinery/power/converter/proc/get_ui_data()
	var/data[0]
	return data


//-- UI Overrides --

/obj/machinery/power/converter/attack_ai(mob/user)
	src.add_hiddenprint(user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/power/converter/attack_hand(mob/user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/power/converter/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)

	if(stat & BROKEN)
		return

	// This is the data which will be sent to the ui
	var/list/data = get_ui_data()

	// Update the ui if it exists, returns null if no ui is passed/found
	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// The ui does not exist, so we'll create a new() one
        // For a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, ui_tmpl, ui_name, 540, 380)
		// When the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// Open the new ui window
		ui.open()
		// Auto update every Master Controller tick
		ui.set_auto_update(1)


/obj/machinery/power/converter/Topic(href, href_list)
	if(..())
		return 1
	if(href_list["close"])
		if(usr.machine == src)
			usr.unset_machine()
		return 1
	if (!isAdminGhost(usr) && (usr.stat || usr.restrained()))
		return
	if (!(istype(usr, /mob/living/carbon/human) || ticker) && ticker.mode.name != "monkey")
		if(!istype(usr, /mob/living/silicon/ai) && !isAdminGhost(usr))
			to_chat(usr, "<span class='warning'>You don't have the dexterity to do this!</span>")
			return
	if (!isturf(src.loc) && !istype(usr, /mob/living/silicon/) && !isAdminGhost(usr))
		return 0 // Do not update ui


///////////////////////////////////////////////////////////////////////
//ROTARY CONVERTER
///////////////////////////////////////////////////////////////////////
/*
 * Two piece converter, consisting of a Motor and a Generator.
 *
 */

///////////////////////////////////////////////////////////////////////
// GENERATOR
/obj/machinery/power/converter/rotaryG
	//Icons
	name = "Universal Generator"
	desc = "Can produce either AC or DC"

	icon = 'icons/obj/machines/dc_network.dmi'
	icon_state = "rotaryG_shaftless"
	icon_state_open = "rotaryG_open"
	icon_state_broken = "rotaryG_broken"
	icon_state_openb = "rotaryG_openb"
	icon_state_off = "rotaryG"
	icon_state_on = "rotaryG_active"

	//Machine
	//TODO: Components and circuit board
	//component_parts = newlist()

	//Converter
	available_modes_flags = DCOUTPUT | ACOUTPUT

	//Generator stuff
	var/obj/machinery/power/converter/rotaryM/motor = null

//-- Connect machines --

/obj/machinery/power/converter/rotaryG/proc/connect_to_M()
	var/turf/T = get_step(src, dir)
	if(!T)
		return
	motor = null
	for(var/list/obj/machinery/power/converter/rotaryM/mot in T.contents) //TODO: There's probably a better way to do this
		motor = mot
	if(motor)
		motor.generator = src

//-- DC network --

/obj/machinery/power/converter/rotaryG/DC_available_dirs()
	return (cardinal - dir)


/obj/machinery/power/converter/rotaryG/process()
	set waitfor = FALSE
	return PROCESS_KILL

/obj/machinery/power/converter/rotaryG/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)
	if(motor)
		motor.ui_interact(user, ui_key, ui, force_open)


//-- Icon --
/obj/machinery/power/converter/rotaryG/update_icon()
	..()
	if(!motor)
		icon_state = "rotaryG_shaftless"

	overlays.len = 0
	if(motor)
		if(motor.flashover)
			overlays += image('icons/effects/effects.dmi', "electricity")


//-- Damage --
/obj/machinery/power/converter/rotaryG/proc/zap()
	var/turf/T = get_turf(src)
	var/turf/U = pick(circlerange(src, 3) - circlerange(src, 1) )
	if (!T || !U)
		return

	var/fire_sound = pick(lightning_sound)
	var/obj/item/projectile/A = new /obj/item/projectile/beam/lightning()

	A.original = U
	A.target = U
	A.current = T
	A.starting = T
	A.yo = U.y - T.y
	A.xo = U.x - T.x
	playsound(T, fire_sound, 50, 1)
	A.OnFired()
	A.process()

	return

///////////////////////////////////////////////////////////////////////
// MOTOR
/obj/machinery/power/converter/rotaryM
	//Icons
	name = "Universal Motor"
	desc = "Can use either AC or DC to drive it's shaft"

	icon = 'icons/obj/machines/dc_network.dmi'
	icon_state = "rotaryM_shaftless"
	icon_state_open = "rotaryM_open"
	icon_state_broken = "rotaryM_broken"
	icon_state_openb = "rotaryM_openb"
	icon_state_off = "rotaryM"
	icon_state_on = "rotaryM_active"

	//UI
	ui_tmpl = "rotary_converter.tmpl" //The .tmpl file used for the UI
	ui_name = "The Rotary Converter" // The name that'll appear on the UI

	//Machine
	//TODO: Components and circuit board
	//component_parts = newlist()

	//Converter
	available_modes_flags = DCINPUT | ACINPUT

	//Rotary stuff
	var/obj/machinery/power/converter/rotaryG/generator = null

	var/const/frequency = 50             // I'm choosing a 50Hz frequency so that the torque figures look nicer
	var/torque_input = 0                 // Torque produced by the input on the motor to match the frequency, measured in Nm
	var/torque_output = 0                // Torque required by the output on the generator to match the frequency, measured in Nm
	var/const/torque_max_diff = 14000000 // Due to efficiency, there's a differenece in torque between the Motor and generator. The shaft can only take so much
	                                     //  excess torque before it suffers from it, causing stress
	                                     //  This effectively limits the maximum output. TODO: I've pulled these figures out my ass, balance later

	var/stress = 0            // Current stress suffered from the difference in motor and generator torques, as a percent
	var/stress_cumulative = 0 // Accumulated stress from previous stressful episodes, as a percent

	efficiency = 0.95
	var/base_efficiency = 0.75 // Efficiency before applying lube or whatever magic thing I end up using. TODO: Research. Skowron told me about generators using carbon dust, but seems like dust's actually bad and causes flash-overs
	var/min_efficiency = 0.50  // Higher torque -> Lower efficiency
	var/max_efficiency = 0.95  // Higher lube rate -> Higher efficiency

	var/lube_rate = 0         // How much lube we consume every tick
	var/carbon_dust = 0         // Carbon dust percent. Clean it out with ethanol TODO: research how cleaning works irl
	var/carbon_dust_limit = 0.8 // Past this point you'll have a (carbon - limit)% probability of flash-overs.
	var/const/carbon_per_torque = 0.001 / torque_max_diff // Carbon produced per torque Nm by wearing down thebrushes. TODO: Balance. 1000 process() at max torque diff for now

	var/flashover = 0             // How severe the flash-over currently is. Replaces target_input during the flash-over
	var/flashover_start = 0       // How severe the flash-over was when it started. Stores the original target_input
	var/const/flashover_peak = 20 // How bad the flash-over can get, aka flashover_start * flashover_peak.
	                              //  From a 1926 article: http://nzetc.victoria.ac.nz/tm/scholarly/tei-Gov01_05Rail-t1-body-d23.html
	                              //  "...it may be stated that a flash-over [...] will be in the region of 20 times the output of the generator"
	                              //  It's an interesting read, so give it a go.

	reagents = new /datum/reagents(100) //TODO: Yet another thing to balance




//-- DC network --

/obj/machinery/power/converter/rotaryM/DC_available_dirs()
	return (cardinal - dir)


//--Power Transfer Overrides
/obj/machinery/power/converter/rotaryM/toggle_active()
	if(generator)
		active = !active
		generator.active = active
		update_icon()
		generator.update_icon()
		if(active)
			//TODO: Replace this with a sound of it's own I guess
			playsound(src, 'sound/mecha/powerup.ogg', 50, 1)


/obj/machinery/power/converter/rotaryM/working_output()
	if(generator)
		return DC_output && generator.get_DCnet() || !DC_output && generator.get_powernet()
	return 0


/obj/machinery/power/converter/rotaryM/do_DC_output(var/output)
	return generator.do_DC_output(output)


/obj/machinery/power/converter/rotaryM/do_AC_output(var/output)
	return generator.do_AC_output(output)

//-- Damage --

/obj/machinery/power/converter/rotaryM/proc/flashover()
	if(!input || !(target_input || flashover_start)) //No input? Stop any flash-over and return
		if(flashover_start)
			target_input = flashover_start
			flashover_start = 0
		return

	if(!flashover_start) //Start a flash-over
		playsound(src, 'sound/effects/engine_alert2.ogg', 50, 1) //UH OH!
		generator.update_icon()
		flashover_start = target_input
		flashover = flashover_start

	if(prob(max(100 * (flashover / (flashover_start * flashover_peak)) - 20, 0)))
		//The worse the flash-over gets, the higher the chance it might finally stop
		flashover -= flashover/rand(1,10)
		if(prob(75))
			playsound(src, 'sound/effects/eleczap.ogg', 50, 1, 1)
		else
			generator.zap()
	else
		//Otherwise, steadily worsen
		if(prob(50))
			if(prob(50))
				spark(generator)
			else
				playsound(src, 'sound/effects/electricity_short_disruption.ogg', 50, 1, 1)

		flashover = min(flashover * 1.2, (flashover_start * flashover_peak))

	if(flashover)//Increase input, and with it torque difference, stress, and capacitor charge on the output if applicable.
	             // Something's bound to explode at some point
		target_input = flashover
	else
		//Flash-over dies down? Return to normal
		target_input = flashover_start
		flashover_start = 0
		generator.update_icon()

/obj/machinery/power/converter/rotaryM/proc/explode()
	var/loops = rand(0,5)
	for(var/i = 0; i < loops; i++)
		playsound(src, 'sound/effects/bang.ogg', 50, 1, 1) //GET AWAY
		sleep(rand(0,2))

	sleep(rand(2,5))
	//TODO: Balance, I guess
	if(input > 100000)
		playsound(src, 'sound/effects/immovablerod_clong.ogg', 100, 1)

	else
		playsound(src, 'sound/effects/bang.ogg', 100, 1, 1)

	stat |= BROKEN
	generator.stat |= BROKEN
	active = 0
	generator.active = 0
	update_icon()
	generator.update_icon()

/obj/machinery/power/converter/rotaryM/DC_damage(var/charge)
	if(!flashover)
		flashover = target_input * flashover_peak / 3
		flashover()
		var/datum/DC_network/net = get_DCnet()
		net.add_charge(-flashover)

//-- Process --


/obj/machinery/power/converter/rotaryM/proc/connect_to_G()
	var/turf/T = get_step(src, dir)
	if(!T)
		return
	generator = null
	for(var/list/obj/machinery/power/converter/rotaryG/gen in T.contents) //TODO: There's probably a better way to do this
		generator = gen
	if(generator)
		generator.motor = src


/obj/machinery/power/converter/rotaryM/proc/disconnect_from_G()
	generator.motor = null
	generator.update_icon()
	generator = null
	update_icon()


/obj/machinery/power/converter/rotaryM/process()
	if(state)
		..()
		if(flashover || (active && prob(max(100 * carbon_dust - 80, 0))))//Start (or continue) a flashover
			flashover()

		//Get torque. TODO: effects of lube
		torque_input = input / frequency
		torque_output = output / frequency
		carbon_dust += carbon_per_torque * torque_output

		if(torque_input - torque_output > torque_max_diff)//Get stressed
			stress += 1 //balance
		else if(stress > 0)
			stress = max(stress - 0.5, 0)
			stress_cumulative += 0.05

		if(active && prob((100 * (stress + stress_cumulative) > 50 ? 10 : 0)))//Break if there's too much stress
			explode(input)


//-- Icon Overrides --

/obj/machinery/power/converter/rotaryM/update_icon()
	..()
	if(!generator)
		icon_state = "rotaryM_shaftless"

//--UI Overrides

/obj/machinery/power/converter/rotaryM/get_ui_data()
	var/data[0]

	data["active"] = active
	data["can_activate"] = working_input() && working_output()

	data["input_modes_available"] = list(terminal ? terminal.get_powernet() != null : 0, get_DCnet() != null)
	data["input_mode"] = DC_input
	data["output_modes_available"] = generator ? list(generator.get_powernet() != null, generator.get_DCnet()!= null) : list(0, 0)
	data["output_mode"] = DC_output

	data["input"] = input
	data["output"] = output
	data["target_input"] = flashover ? flashover_start : target_input
	data["target_output"] = target_output

	data["efficiency"] = efficiency * 100

	data["torque_input"] = torque_input
	data["target_torque_input"] = target_input / frequency

	data["torque_output"] = torque_output
	data["target_torque_output"] = target_output / frequency


	data["target_torque_diff"] = (target_input - target_output / frequency)
	data["torque_diff"] = torque_input - torque_output
	data["torque_maxdiff"] = torque_max_diff


	data["stress"] = stress + stress_cumulative

	data["carbon"] = carbon_dust * 100

	var/list/r_list
	for (var/datum/reagent/R in reagents.reagent_list)
		r_list["[R.name]"] = R.volume
	data["reagents"] = list("total_volume" = reagents.total_volume, "maximum_volume" = reagents.maximum_volume, "reagent_list" = r_list)
	data["reagentRate"] = 0

	return data

/obj/machinery/power/converter/Topic(href, href_list)
	..()