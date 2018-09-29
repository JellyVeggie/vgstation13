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
	var/ui_x = 540
	var/ui_y = 380

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
	update_icon()

/obj/machinery/capacitor_bank/Destroy()
	if(mDC_node)
		qdel(mDC_node)
	..()

//-- Helpers --
//Should come handy for playing sounds, animations, or whatever
/obj/machinery/power/converter/proc/activate()
	active = 1

//Should come handy for playing sounds, animations, or whatever
/obj/machinery/power/converter/proc/deactivate()
	active = 0

//Checks wether we can proceed with the power_transfer()
/obj/machinery/power/converter/proc/working_input()
	return DC_input && get_DCnet() || !DC_input && terminal

//Checks wether we can proceed with the power_transfer()
/obj/machinery/power/converter/proc/working_output()
	return DC_output && get_DCnet() || !DC_output && get_powernet()


/obj/machinery/power/converter/proc/set_output(var/t_out)
	target_output = t_out
	target_input = target_output / efficiency


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
		deactivate()
		return

	input = (DC_input ? get_DC_input(target_input) : get_AC_input(target_input))
	if (!input)
		deactivate()
		return

	output = (DC_output ? do_DC_output(input * efficiency) : do_AC_output(input * efficiency))


//-- Machine Overrides --
/obj/machinery/power/converter/process()
	if(state && active && !(stat & BROKEN))
		power_transfer()
	return


//-- Interact Overrides --

/obj/machinery/power/converter/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob) //these can only be moved by being reconstructed, solves having to remake the powernet.
	if(state && panel_open && available_modes_flags & ACINPUT)
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
	if (state && (available_modes_flags & DCINPUT || available_modes_flags & DCOUTPUT))
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
		ui = new(user, src, ui_key, ui_tmpl, ui_name, ui_x, ui_y)
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
/**
 * Two piece converter: A Motor-Generator set, or Rotary Converter.
 * Goes up to 10 GW transfer on whatever AC/DC mixture you need, requiring a noticeable ammount of maintenance.
 * The difference that efficiency plays between input and output is of great importance here:
 *  If this difference is to high, the shaft takes damage until it snaps and the machine breaks.
 *
 * How high the difference can get depends on material used to build the shaft. Assumming efficiency is as high as it gets,
 *  metal shafts can go up to 805MW, and plasteel up to 10.5GW, before the shaft starts taking damage.
 * Damage taken will be recovered from after output goes down, but some will remain, eventually requiring repair if you
 *  keep fucking it up.
 *
 * If you can't improve the shaft, improve efficiency:
 *  - The further your output is from 805MW the lower your efficiency
 *  - The more lube used, the higher your efficiency, with diminishing returns
 *  - The closer your carbon dust is to 60u, the higher your efficiency
 *
 * Carbon dust is produced by the machine itself, and accumulates faster the higher your output (1u per tick at 805MW).
 *  It comes with a drawback however: Past 80u you risk a flash-over, where the air is conductive enough
 *  to be dismissed over the carbon brushes, producing sparks and arcing, and outputting up to 20 times the usual.
 * This could very well damage and break the shaft
 */

///////////////////////////////////////////////////////////////////////
// MOTOR
/**
 * Holds most of the info, calling rotaryG when necessary
 *
 *
 */
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
	available_modes_flags = 0

	//Rotary stuff
	var/obj/machinery/power/converter/rotaryG/generator = null


	//Efficiency
	efficiency = 0.75
	var/const/base_efficiency = 0.75
	var/const/min_efficiency = 0.50
	var/const/max_efficiency = 0.95

	var/const/efficiency_torque_factor = -0.25 // These mark how much each variable affects efficiency.
	var/const/efficiency_carbon_factor = 0.15  // Torque should go down to minimum from base, carbon and lube should add up to maximum
	var/const/efficiency_lube_factor = 0.25

	var/efficiency_torque = 0 // Torque output closer to metal shaft strength -> least efficiency detriment
	var/efficiency_carbon = 0 // Carbon closer to 60 -> highest efficiency bonus
	var/efficiency_lube = 0   // More lube -> higher efficiency bonus, with diminishing returns

	//Mechanics
	var/const/max_output = 10e9  // This is how high the settings will let you go, but you can still reach flashover_peak * max_output during a flashover
	var/const/frequency = 50     // A 50Hz frequency makes the torque figures look nicer. Change at will if that rustles your jimmies I guess
	var/torque_input = 0         // Torque produced by the input on the motor to match the frequency, measured in Nm
	var/torque_output = 0        // Torque required by the output on the generator to match the frequency, measured in Nm
	var/torque_max_diff = 0      // Due to efficiency, there's a differenece in torque between the Motor and generator. The shaft can only take so much
	                             //  excess torque before it suffers from it, causing stress. Metal used in construction affects strength. TODO: Balance
	var/stress = 0               // Current stress suffered from the difference in motor and generator torques, as a percent
	var/stress_cumulative = 0    // Accumulated stress from previous stressful episodes, as a percent
	var/const/stress_limit = 0.8 // Past this point you'll have a (stress + stress_cumulative - limit)% probability of breaking.

	var/list/shaft_strength = list("metal"            = 805e6                          * (2 - max_efficiency) / frequency,
	                               "plasteel"         = 10.5e9                         * (2 - max_efficiency) / frequency)
	                             //"[sheet.name]      = [max output at max efficiency] * (2 - max_efficiency) / frequency)"

	//Reagents
	var/const/carbon_dust_optimal = 60 // You'll feel the full effects of efficiency_carbon at this point
	var/const/carbon_dust_limit = 80   // Past this point you'll have a (carbon - limit)% probability of flash-overs.
	var/const/carbon_dust_max = 100
	var/datum/reagents/carbon_dust = new /datum/reagents(carbon_dust_max) // Carbon dust. Clean it out with ethanol
	// Carbon produced per torque Nm by wearing down the brushes. TODO: Balance. 100 ticks at max torque on a metal shaft for now
	var/const/carbon_per_torque = 1 / (805e6 * (2 - max_efficiency) / frequency)

	var/lube_rate = 0             // How much lube we consume every tick
	var/const/lube_max_rate = 100
	var/ethanol_rate = 0          // How much ethanol we consume every tick
	var/const/ethanol_max_rate = 100

	var/flashover = 0             // How severe the flash-over currently is. Replaces target_input during the flash-over
	var/flashover_start = 0       // How severe the flash-over was when it started. Stores the original target_input
	var/const/flashover_peak = 20 // How bad the flash-over can get, aka flashover_start * flashover_peak.
	                              //  From a 1926 article: http://nzetc.victoria.ac.nz/tm/scholarly/tei-Gov01_05Rail-t1-body-d23.html
	                              //  "...it may be stated that a flash-over [...] will be in the region of 20 times the output of the generator"
	                              //  It's an interesting read, so give it a go.

	reagents = new /datum/reagents(100) //TODO: Yet another thing to balance


/obj/machinery/power/converter/rotaryM/Destroy()

	reagents = null
	qdel(reagents)

//-- Connect Machines --
/obj/machinery/power/converter/rotaryM/proc/connect_to_G()
	var/turf/T = get_step(src, dir)
	if(!T)
		return
	generator = null
	for(var/list/obj/machinery/power/converter/rotaryG/gen in T.contents) //TODO: There's probably a better way to do this
		generator = gen
	if(generator)
		generator.motor = src
		available_modes_flags = DCINPUT | ACINPUT
		generator.available_modes_flags = DCOUTPUT | ACOUTPUT
		update_icon()
		generator.update_icon
		return 1
	return 0


/obj/machinery/power/converter/rotaryM/proc/disconnect_from_G()
	active = 0
	available_modes_flags = 0
	generator.active = 0
	generator.available_modes_flags = 0
	generator.motor = null
	generator.update_icon()
	generator = null
	update_icon()


//-- DC network --

/obj/machinery/power/converter/rotaryM/DC_available_dirs()
	return (cardinal - dir)


//--Power Transfer Overrides
/obj/machinery/power/converter/rotaryM/activate()
	if(generator)
		active = 1
		generator.active = active
		update_icon()
		generator.update_icon()
		//TODO: Replace this with a sound of it's own I guess?
		playsound(src, 'sound/mecha/powerup.ogg', 100, 1)

/obj/machinery/power/converter/rotaryM/deactivate()
	if(generator)
		active = !active
		generator.active = active
		update_icon()
		generator.update_icon()
		playsound(src, 'sound/machines/click.ogg', 50, 1)


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
		//else
		//	generator.zap()
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

/obj/machinery/power/converter/rotaryM/proc/explode(animate=0)
	if (animate)
		sleep(rand(2,5))

		if(torque_input - torque_output > shaft_strength["metal"] * 10)
			//Input tends towards 10 times the original during flashover, peaking at 20.
			// I figure that's a good point for deciding whether to go extra loud
			playsound(src, 'sound/effects/immovablerod_clong.ogg', 100, 1)
			explosion(src, 0, 0, 2, 0) //Mostly shrapnel. Should hurt anyone nearby, but not cause any breaches by itself
		else
			playsound(src, 'sound/effects/bang.ogg', 100, 1, 1)

		for(var/atom/A in view(3, get_turf(src)))
			if( A == src )
				continue
			src.reagents.reaction(A, 1, 10)

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
/obj/machinery/power/converter/rotaryM/proc/update_efficiency()
	var/n = 0
	efficiency = base_efficiency

	/* 0 >= n >= 1
	 * The graph here does a sinewave's "peak to bottom" portion from 0 to the maximum torque a metal shaft allows
	 * Then it goes back up, from a metal shaft's maximum torque to a plasteel's shaft, and stays at maximum beyond there.
	 */
	var/m = shaft_strength["metal"] / (2 - max_efficiency)
	var/p = shaft_strength["plasteel"] / (2 - max_efficiency)
	if(torque_output <= m)
		n = 0.5 * sin(torque_output * pi / m + 0.5 * pi) + 0.5
	else if (torque_output <= p)
		n = 0.5 * sin(torque_output * pi/(p - m) - m - 0.5 * pi) + 0.5
	else
		n = 1

	efficiency -= 0.25*n

	n = 0.5 * sin(carbon_dust * pi/50 + 0.5*pi) + 0.5



/obj/machinery/power/converter/rotaryM/process()
	if(state)
		..()
		if(flashover || (active && prob(max(100 * (carbon_dust - carbon_dust_limit), 0))))//Start (or continue) a flashover
			flashover()

		if(active)
			//Get torque. TODO: effects of lube
			torque_input = input / frequency
			torque_output = output / frequency
			carbon_dust = min(carbon_dust + carbon_per_torque * torque_output, 1)

			if(torque_input - torque_output > torque_max_diff)//Get stressed
				if (prob(25))
					playsound(src, 'sound/effects/clang.ogg', 50, 1, 1)
				stress += 1 //balance
			else if(stress > 0)
				stress = max(stress - 0.5, 0)
				stress_cumulative += 0.05

			if(active && prob(100 * min(stress + stress_cumulative - stress_limit, 0)))//Break if there's too much stress
				explode(input)
			else if (prob(25))
				playsound(src, 'sound/effects/clang.ogg', 50, 1, 1)


//-- Interact Overrides --
/obj/machinery/power/converter/rotaryM/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
	if(istype(W, /obj/item/stack/sheet/ && W.name in shaft_strength))
		var/obj/item/stack/sheet/M = W

		if (M.amount < 10)
			to_chat(user, "<span class='warning'>You need 10 [M.name] to build a shaft.</span>")
			return

		if(connect_to_G())
			M.use(10)
			user.visible_message(\
				"<span class='warning'>[user.name] has built the [src] and [generator] a shaft made out of [M.name].</span>",\
				"You have built the [src] and [generator] a shaft made out of [M.name].")
			torque_max_diff = shaft_strength[M.name] //TODO: I'd use mat_type instead but plasteel has none of it's own?

			return 1

	if(iswelder(W) && stat & BROKEN)
		var/obj/item/weapon/weldingtool/WT = W
		if (WT.do_weld(user, src,20, 0))
			stat = ~(~stat & BROKEN)
			if(generator)
				generator.stat = stat
				disconnect_from_G()
			else
				update_icon()
			return 1
		else
			to_chat(user, "<span class='rose'>You need more welding fuel to complete this task.</span>")
			return
	..()

/obj/machinery/power/converter/rotaryM/wrenchable()
	if(generator)
		return 0
	else
		return ..()

//-- Icon Overrides --

/obj/machinery/power/converter/rotaryM/update_icon()
	..()
	if(!generator)
		icon_state = "rotaryM_shaftless"

//--UI Overrides

/obj/machinery/power/converter/rotaryM/get_ui_data()
	var/data[0]
	var/holder = 0

	data["active"] = active
	data["can_activate"] = working_input() && working_output()

	data["input_modes_available"] = list(terminal ? terminal.get_powernet() != null : 0, get_DCnet() != null)
	data["input_mode"] = DC_input
	data["output_modes_available"] = generator ? list(generator.get_powernet() != null, generator.get_DCnet() != null) : list(0, 0)
	data["output_mode"] = DC_output

	data["input"] = list("num" = input, "text" = "[format_units(input)]W")
	data["output"] = list("num" = output, "text" = "[format_units(output)]W")
	holder = flashover ? flashover_start : target_input
	data["target_input"] = list("num" = holder, "text" = "[format_units(holder)]W")
	data["target_output"] = list("num" = target_output, "text" = "[format_units(target_output)]W")

	data["efficiency"] = round(efficiency * 100, 0.1)

	data["torque_input"] = list("num" = torque_input, "text" = "[format_units(torque_input)] Nm")
	holder = target_input / frequency
	data["target_torque_input"] = list("num" = holder, "text" = "[format_units(holder)] Nm")

	data["torque_output"] = list("num" = torque_output, "text" = "[format_units(torque_output)] Nm")
	holder = target_output / frequency
	data["target_torque_output"] = list("num" = holder, "text" = "[format_units(holder)] Nm")

	holder = (target_input - target_output) / frequency
	data["target_torque_diff"] = list("num" = holder, "text" = "[format_units(holder)] Nm")
	holder = torque_input - torque_output
	data["torque_diff"] = list("num" = holder, "text" = "[format_units(holder)] Nm")
	data["torque_maxdiff"] = list("num" = torque_max_diff, "text" = "[format_units(torque_max_diff)] Nm")

	data["stress"] = stress + stress_cumulative
	data["stress_limit"] = stress_limit

	data["carbon"] = list("num" = carbon.volume, "text" = "[format_units(carbon.volume)]")
	data["carbon_limit"] = carbon_dust_limit
	data["carbon_optimal"] = carbon_dust_optimal
	data["carbon_max"] = carbon_dust_max

	var/list/r_list
	for (var/datum/reagent/R in reagents.reagent_list)
		r_list["[R.name]"] = R.volume
	data["reagents"] = list("total_volume" = reagents.total_volume, "maximum_volume" = reagents.maximum_volume, "reagent_list" = r_list)
	data["reagentRate"] = 0

	return data

/obj/machinery/power/converter/rotaryM/Topic(href, href_list)
	..()
	var/holder = null
	if(href_list["active"] != null)
		holder = text2num(href_list["active"])
		if(holder != null && active != holder)
			activate()

	else if(href_list["DC_input"] != null)
		holder = text2num(href_list["DC_input"])
		DC_input = holder != null ? holder : DC_input

	else if(href_list["DC_output"] != null)
		holder = text2num(href_list["DC_output"])
		DC_output = holder != null ? holder : DC_output

	else if(href_list["set_output"] != null)
		switch( href_list["set_output"])
			if("min")
				set_output(0)
			if("max")
				set_output(max_output)
			if("set")
				var/o = input(usr, "Enter new output level (0-[format_units(max_output)]W)", ui_name, target_output) as num
				o = Clamp(o, 0, max_output)
				set_output(o)

	return 1

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
	available_modes_flags = 0

	//Generator stuff
	var/obj/machinery/power/converter/rotaryM/motor = null

//-- Connect to motor --

/obj/machinery/power/converter/rotaryG/proc/connect_to_M()
	var/turf/T = get_step(src, dir)
	if(!T)
		return
	motor = null
	for(var/list/obj/machinery/power/converter/rotaryM/mot in T.contents) //TODO: There's probably a better way to do this
		motor = mot
	if(motor)
		motor.generator = src
		motor.available_modes_flags = DCINPUT | ACINPUT
		available_modes_flags = DCOUTPUT | ACOUTPUT
		update_icon()
		motor.update_icon()
		return 1
	return 0

//-- Deflect to motor --

/obj/machinery/power/converter/rotaryG/process()
	set waitfor = FALSE
	return PROCESS_KILL

/obj/machinery/power/converter/rotaryG/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)
	if(motor)
		motor.ui_interact(user, ui_key, ui, force_open)

/obj/machinery/power/converter/rotaryG/proc/disconnect_from_M()
	return motor.disconnect_from_G()


//-- DC network --

/obj/machinery/power/converter/rotaryG/DC_available_dirs()
	return (cardinal - dir)

//-- Interact Overrides --

/obj/machinery/power/converter/rotaryG/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
	if(istype(W, /obj/item/stack/sheet/metal) || istype(W, /obj/item/stack/sheet/plasteel))
		var/obj/item/stack/sheet/M = W

		if (M.amount < 10)
			to_chat(user, "<span class='warning'>You need 10 [M.name] sheets to build a shaft.</span>")
			return

		if(connect_to_M())
			M.use(10)
			user.visible_message(\
				"<span class='warning'>[user.name] has built the [motor] and [src] a shaft made out of [M.name].</span>",\
				"You have built the [motor] and [src] a shaft made out of [M.name].")
			motor.torque_max_diff = motor.shaft_strength[M.name] //TODO: I'd use mat_type instead but plasteel has none of it's own?

			return 1

	if(iswelder(W) && stat & BROKEN)
		var/obj/item/weapon/weldingtool/WT = W
		if (WT.do_weld(user, src,20, 0))
			stat = ~(~stat & BROKEN)
			if(motor)
				motor.stat = stat
				disconnect_from_M()
			else
				update_icon()
			return 1
		else
			to_chat(user, "<span class='rose'>You need more welding fuel to complete this task.</span>")
			return
	..()

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