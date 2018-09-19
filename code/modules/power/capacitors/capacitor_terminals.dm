/////////////////////////////////////////////
// TERMINALS


/obj/machinery/power/capacitor_bank/terminal/
	var/ui_tmpl = "" //The .tmpl file used for the UI
	var/ui_name = "The Terminal Unit" // The name that'll appear on the UI

	var/reagent = 0 //Lube, mercury, or whatever the machine needs to function.

/obj/machinery/power/capacitor_bank/terminal/power_interact()
	return

//--Overrides
/obj/machinery/power/capacitor_bank/terminal/process()
	if(stat & (BROKEN | EMPED))
		last_charge = 0
		return

	if (use_power = 2 && cap_network)
		power_interact()

/obj/machinery/power/capacitor_bank/terminal/attack_ai(mob/user)
	src.add_hiddenprint(user)
	add_fingerprint(user)
	ui_interact(user)

/obj/machinery/power/capacitor_bank/terminal/attack_hand(mob/user)
	add_fingerprint(user)
	ui_interact(user)

/obj/machinery/power/capacitor_bank/terminal/get_ui_data()
	var/data[0]
	return data

/obj/machinery/power/capacitor_bank/terminal/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)

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

/obj/machinery/power/capacitor_bank/terminal/Topic(href, href_list)
	//Shamelessly copied from /obj/machinery/power/battery code
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

	//to_chat(world, "[href] ; [href_list[href]]")

	if (!isturf(src.loc) && !istype(usr, /mob/living/silicon/) && !isAdminGhost(usr))
		return 0 // Do not update ui


	//Override beyond this point
	/*
	if( href_list["cmode"] )
		switch( href_list["cmode"])
			if("auto")
				chargemode = BATTERY_AUTO_CHARGE
			if("manual")
				chargemode = BATTERY_MANUAL_CHARGE
			if("off")
				chargemode = BATTERY_NO_CHARGE
				charging = 0
		update_icon()

	else if( href_list["online"] )
		online = !online
		update_icon()
	else if( href_list["input"] )
		switch( href_list["input"] )
			if("min")
				chargelevel = 0
			if("max")
				chargelevel = max_input		//30000
			if("set")
				chargelevel = input(usr, "Enter new input level (0-[max_input])", "SMES Input Power Control", chargelevel) as num
		chargelevel = max(0, min(max_input, chargelevel))	// clamp to range

	else if( href_list["output"] )
		switch( href_list["output"] )
			if("min")
				output = 0
			if("max")
				output = max_output		//30000
			if("set")
				output = input(usr, "Enter new output level (0-[max_output])", "SMES Output Power Control", output) as num
		output = max(0, min(max_output, output))	// clamp to range

	return 1
	*/




///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////

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