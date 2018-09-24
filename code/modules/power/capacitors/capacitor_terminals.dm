/////////////////////////////////////////////
// CONVERTER
/*
 * These will exchange charge and power between the capacitor network and the power network
 * Per Wikipedia: "Rotary converters were made obsolete by mercury arc rectifiers in the 1930s and later on by semiconductor rectifiers in the 1960s"
 * Rotary converters can exchange the most power, but they're big, require decent ammounts of lube to improve their efficiency, break if pushed too
 *  far, and only control how much goes in or out
 * Mercury arc converters exchange less, but are still better than an SMES. They only need a small ammount of mercury to work, and let you set a maximum charge,
 *  but are susceptible to the effects of excess charge and consume APC power to operate
 * Semiconductor converters need no maintenance or power and let you set a maximum charge, but exchange less power than an SMES and are susceptible to the
 *  effects of excess charge. They're boring as fuck, too
 *
 */

/obj/machinery/power/capacitor_bank/nnui/converter
	//var/reagent = 0 //Lube, mercury, or whatever the machine needs to function.

/obj/machinery/power/capacitor_bank/nnui/converter/power_interact()
	return


/obj/machinery/power/capacitor_bank/nnui/converter/capacitor_interact()
	return


//--Overrides
/obj/machinery/power/capacitor_bank/nnui/converter/process()
	if (use_power = 2 && cap_network && !(stat & (BROKEN | EMPED)))
		power_interact()


/obj/machinery/power/capacitor_bank/nnui/converter/damage(damage)
	return


/obj/machinery/power/capacitor_bank/nnui/converter/explode(var/damage=0)
	if(cap_network)
		disconnect()
	stat |= BROKEN
	use_power = 0
	update_icon()
	return


/obj/machinery/power/capacitor_bank/nnui/converter/ex_act(severity)
	switch(severity)
		if(1.0)
			if (prob(25))
				explode()
			qdel(src)
			return

		if(2.0)
			if (prob(50))
				qdel(src)
			else if (prob(50))
				explode()
			return

		if(3.0)
			if (prob(50))
				explode()
			else if (prob(20))
				qdel(src)
			return
	return

///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
//ROTARY CONVERTER

/obj/machinery/power/capacitor_bank/nnui/converter/rotary
	name = "Rotary Universal Motor"
	desc = "Can use either AC or DC to drive the shaft"

	icon_state = "rotaryM"
	icon_state_open = "rotaryM_open"
	icon_state_broken = "rotaryM_broken"
	icon_state_openb = "rotaryM_openb"
	icon_state_off = "rotaryM"
	icon_state_on = "rotaryM_on"
	icon_state_active = "rotaryM_active"

	var/target_output = 0 // How many watts we want the generator to produce. Governs pretty much everything else
	var/target_input = 0  // Given an output and efficiency, how many watts we should consume to produce the desired output
	var/input = 0         // Current energy consumption, smotthly rising to target_input
	var/output = 0        // Current energy ouput, as calculated from efficiency and current input

	var/const/frequency = 50       // I'm choosing a 50Hz frequency so that the torque figures look nicer
	var/torque_input = 0           // Torque produced by input on the motor, measured in Nm
	var/torque = 0                 // Torque required by output on the generator, measured in Nm
	var/torque_diff = 0            // torque_input - torque. This is what friction and the shaft ate up along the way
	var/torque_max_diff = 14000000 // The shaft can only take so much excess torque before it suffers from it, causing stress
	                               //  This effectively limits the maximum output. TODO: Balance

	var/stress = 0            // Current stress suffered from torque_diff, as a percent
	var/stress_cumulative = 0 // Accumulated stress from previous stressful episodes, as a percent
	var/stress_total = 0      // stress + stress_cumulative. If this reaches 100% the rotary will break

	var/efficiency = 0         // Determines target_input, input and torque_diff
	var/base_efficiency = 0.75 // Efficiency before applying lube or whatever magic reagent
	var/min_efficiency = 0.50  // Higher torque -> Lower efficiency
	var/max_efficiency = 0.95  // Hogher lube rate -> Hogher efficiency

	var/datum/reagents/reagents = new /datum/reagents(100) // Holds lube, ethanol, and whatever else you feed it
	var/lube_rate = 0         // How much lube we consume every tick
	var/carbon_dust = 0       // Carbon dust percent. Higher than 50% and you'll have a (carbon - 50)% probability of
	                          //  flash-overs, which cause input spikes. Clean it out with ethanol
	var/carbon_per_torque = 0 // Carbon produced per torque Nm. Carbon comes from the carbon brushes on the generator, .
	var/carbon_per_lube = 0   //

	var/DC_mode = 0 // Connect to DC (capacitor) networks. If not, connects to AC (powernet)

	//Machine stuff
	//TODO: Circuit board
	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank/mainframe,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/console_screen,
		/obj/item/weapon/reagent_containers/glass/beaker
	)
//--Power



//--UI

/obj/machinery/power/capacitor_bank/nnui/converter/rotary/proc/get_ui_data()
	var/data[0]
	data["input"] = input
	data["output"] = output
	data["efficiency"] = efficiency
	data["active"] = use_power == 2
	data["tinput"] = torque_input
	data["toutput"] = torque
	data["tdiff"] = torque_diff
	data["maxtdiff"] = torque_max_diff
	data["stress"] = round(min(stress + stress_cumulative, 1) * 100)
	data["carbon"] = round(carbon * 100)
	data["reagents"] = reagents.reaget_list
	data["lubeRate"] = lube_rate
	data["lubeMinutes"] = 0
	return data

//--Overrides

/obj/machinery/power/capacitor_bank/nnui/converter/rotary/available_dirs()
	if(DC_mode)
		return ..() - dir
	else
		return list()


/obj/machinery/power/capacitor_bank/nnui/converter/rotary/proc/can_attach_terminal(mob/user)
	return user.loc != src.loc && (get_dir(user, src) in (cardinal - dir)) && !terminal


/obj/machinery/power/capacitor_bank/nnui/converter/rotary/process()
	if (use_power = 2 && !(stat & (BROKEN)))
		if(DC_mode && cap_network)
			capacitor_interact()
		else if()
			power_interact()


/obj/machinery/power/capacitor_bank/nnui/converter/rotary/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
	if(panel_open && !DC_mode)
		//Deconstruct
		//Shamelessly copy pasted from SMES code (Last PR was #19741 at the time)
		if(iscrowbar(W) && terminal)
			to_chat(user, "<span class='warning'>You must first cut the terminal from the [src]!</span>")
			return 1

		//Add Terminal
		//(Shamelessly copy pasted from SMES code, too (Last PR was #19741 at the time))
		if(istype(W, /obj/item/stack/cable_coil) && !terminal)
			var/obj/item/stack/cable_coil/CC = W

			if (CC.amount < 10)
				to_chat(user, "<span class=\"warning\">You need 10 length cable coil to make a terminal.</span>")
				return

			if(make_terminal(user))
				CC.use(10)
				terminal.connect_to_network()

				user.visible_message(\
					"<span class='warning'>[user.name] made a terminal for the [src].</span>",\
					"You made a terminal for the [src].")
				src.stat = 0
				return 1

		// Remove Terminal
		//(Shamelessly copy pasted from SMES code, again (Last PR was #19741 at the time))
		else if(iswirecutter(W) && terminal)
			var/turf/T = get_turf(terminal)

			if(T.intact)
				to_chat(user, "<span class='warning'>You must remove the floor plating in front of the SMES first.</span>")
				return
			to_chat(user, "You begin to dismantle the [src] terminal...")
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

	// Repair
	if(stat | BROKEN && iswelder(W))
		var/obj/item/weapon/weldingtool/WT = W
		if(!WT.remove_fuel(0, user))
			to_chat(user, "<span class='notice'>You need more welding fuel to complete this task.</span>")
			return

		user.visible_message(\
			"<span class='notice'>[user.name] starts repairing the [src].</span>",\
			"You start repairing the [src].")
			playsound(src, 'sound/items/Welder.ogg', 50, 1)
		if (do_after(user, src, 50))
			user.visible_message(\
				playsound(src, 'sound/items/Welder2.ogg', 50, 1)
				"<span class='notice'>[user.name] has repaired the [src].</span>",\
				"You have repaired the [src].")
		return

	return ..()


/obj/machinery/power/capacitor_bank/nnui/converter/rotary/can_attach_terminal(mob/user)
	return ..(user) && panel_open



/*
/obj/machinery/power/capacitor_bank/terminal/rectifier
	name = "mercury arc rectifier"
	desc = "Turns AC power into DC power"

	icon_state = "inverter"
	icon_state_open = "inverter_open"
	icon_state_broken = "inverter_broken"
	icon_state_openb = "inverter_openb"
	icon_state_off = "inverter"
	icon_state_on = "inverter_on"
	icon_state_active = "inverter_active"

	//Machine stuff
	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank/mainframe,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/console_screen,
		/obj/item/weapon/reagent_containers/glass/beaker,
		/obj/item/weapon/reagent_containers/glass/beaker,
		/obj/item/weapon/reagent_containers/glass/beaker
	)

/////////////////////////////////////////////
// POWER INVERTER
/*
 *	A DC motor and AC generator, gets power off the capacitors and into the power grid.
 *	Higher output requires higher torque, at less efficiency.
 *	Torque and friction will cause stress, breaking the inverter. This places a lmit on torque, and thus output.
 *	Lowering torque will have the machine recover from most of it's stress, but some will stay. Repair may be needed eventually.
 *	Lube can be added to the machine, reducing friction and raising the limit on torque.
 *
 *	Doing some research, actual inverters are actually electronics based, but didn't find out until long after I had the sprites
 *	and general idea worked, so fuck it.
 */


/obj/machinery/power/capacitor_bank/terminal/inverter
	name = "power inverter"
	desc = "Transforms DC power into AC power. You're pretty sure it's actually an M-G set."

	icon_state = "inverter"
	icon_state_open = "inverter_open"
	icon_state_broken = "inverter_broken"
	icon_state_openb = "inverter_openb"
	icon_state_off = "inverter"
	icon_state_on = "inverter_on"
	icon_state_active = "inverter_active"

	var/output = 0 // How much power we aim to generate
	var/input = 0 // How much power we're drawing to generate the ouput
	var/torque = 0 // Torque required to generate the given output at the given rpm

	var/max_torque = 0 // How much torque the machine can take before taking stress
	var/base_max_torque = 0 // max_torque before taking friction into account. This is how strong we could get if perfectly lubed

	var/efficiency = 0 //Rises with lube.

	var/stress = 0 // Stress suffered due to excessive torque
	var/fatigue = 0 // Stress accumulated after current stress subsides

	var/const/frequency = 50 // Determines torque required for the output
	var/const/max_torque_per_manipulator = 100e6 / frequency // Better manipulators increase the base_max_torque. Balanced for maxing at 100MW each
	var/const/base_efficiency = 0.5 //Efficiency before taking lube into account
	var/const/max_stress = 100

	//Machine stuff
	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank/mainframe,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/console_screen,
		/obj/item/weapon/reagent_containers/glass/beaker
	)

/obj/machinery/power/capacitor_bank/terminal/update()
	max_torque = base_max_torque * efficiency
	torque = output / frequency
	input = output / efficiency

/obj/machinery/power/capacitor_bank/terminal/power_interact()
	if (reagents)
		reagents = max(0, reagents - 1)
		efficiency = base_efficiency + reagents ? 0.45 : 0

	if(torque > max_torque)
		stress += (torque - max_torque) / max_torque
	else if(stress > 0)
		stress = max(0, stress - 2.5)
		fatigue += 0.5

	if(stress + fatigue > max_stress)
		disconnect()
		explode(TNTENERGY) //Just enough for a (1,0,0) dev explosion
		return

	// Output
	if (get_powernet())
		var/out = Clamp(cap_network.charge * friction, 0, output)
		cap_network.charge -= out / friction
		add_avail(out) // Add output to powernet

		if (cap_network.charge < 0.0001)
			use_power = 1

/obj/machinery/power/capacitor_bank/RefreshParts()
	actual_capacity = 0
	base_max_torque = 0
	for(var/obj/item/weapon/stock_parts/SP in component_parts)
		if(istype(SP, /obj/item/weapon/stock_parts/capacitor))
			actual_capacity += C.maximum_charge
		if(istype(SP, /obj/item/weapon/stock_parts/manipulator))
			base_max_torque += SP.rating * max_torque_per_manipulator




///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
/obj/machinery/power/capacitor_bank/adapter
	name = "adapter"
	desc = "Passes DC power to and from complex, power-hungry machinery."

	icon_state = "inverter"
	icon_state_open = "inverter_open"
	icon_state_broken = "inverter_broken"
	icon_state_openb = "inverter_openb"
	icon_state_off = "inverter"
	icon_state_on = "inverter_on"
	icon_state_active = "inverter_on"
	var/icon_state_in = "inverter_in"
	var/icon_state_out = "inverter_out"

	var//obj/machinery/power/capacitor_bank/adapter/consumer = null //Whoever we're giving energy to or taking from

	var/const/IDLE = 0
	var/const/GIVE   = 1
	var/const/TAKE = 2
	var/charge_flow = 0 //Wether we're taking or giving energy

	//Machine stuff
	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank/mainframe,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor
	)

/obj/machinery/power/capacitor_bank/adapter/update_icon()

*/