/////////////////////////////////////////////
// NNUI
/*
 *  Machines inheriting from this will have a NanoUI
 */

/obj/machinery/power/capacitor_bank/nnui/
	var/ui_tmpl = "" //The .tmpl file used for the UI
	var/ui_name = "The Capacitor Unit" // The name that'll appear on the UI


/obj/machinery/power/capacitor_bank/nnui/proc/get_ui_data()
	var/data[0]
	return data

//--Overrides

/obj/machinery/power/capacitor_bank/nnui/attack_ai(mob/user)
	src.add_hiddenprint(user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/power/capacitor_bank/nnui/attack_hand(mob/user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/power/capacitor_bank/nnui/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)

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


/obj/machinery/power/capacitor_bank/nnui/Topic(href, href_list)
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

/////////////////////////////////////////////
// MAINFRAME

var/global/list/capacitor_bank_mainframe_charge_meter = list(
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og1"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og2"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og3"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og4"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og5")
	)


/obj/machinery/power/capacitor_bank/nnui/mainframe
	name = "capacitor mainframe"
	desc = "Manages and stabilizes any capacitor banks it's been connected to."

	icon_state = "capacitor_bank"
	icon_state_open = "capacitor_mainframe_open"
	icon_state_broken = "capacitor_mainframe_broken"
	icon_state_openb = "capacitor_mainframe_openb"
	icon_state_off = "capacitor_mainframe"
	icon_state_on = "capacitor_mainframe_on"
	icon_state_active = "capacitor_mainframe_on"

	//Machine stuff
	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank/mainframe,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/console_screen
	)

//--UI
/obj/machinery/power/capacitor_bank/nnui/mainframe/get_ui_data()
	var/data[0]
	data["hasNetwork"] = cap_network
	data["charge"] = cap_network.capacity
	data["capacity"] = cap_network.capacity
	data["safeCapacity"] = cap_network.safe_capacity
	data["safeCapacityBonus"] = cap_network.capacity * cap_network.base_safety_limit - cap_network.safe_capacity
	data["networkSafety"] = cap_network.network_safety
	data["nodes"] = cap_network.nodes.len
	data["mainframes"] = cap_network.mainframes
	data["mainframesWanted"] = -round(-cap_network.nodes.len / 10) //Ceiling(cap_network.nodes.len / 10). THis should be replaced with an actual Ceiling() some day

	return data

/obj/machinery/power/capacitor_bank/nnui/mainframe/Topic(href, href_list)
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


//--Network

/obj/machinery/power/capacitor_bank/nnui/mainframe/proc/charge_level()
	if(cap_network)
		var/clevel = max(cap_network.charge/(cap_network.safe_capacity ? cap_network.safe_capacity : 0.1), 0)
		return clevel
	else
		return 0

/obj/machinery/power/capacitor_bank/nnui/mainframe/is_mainframe()
	return !(stat & BROKEN)

//--Icon

/obj/machinery/power/capacitor_bank/nnui/mainframe/proc/update_overlay()
	overlays.len = 0

	var/clevel = round(min(5.5 * charge_level(), capacitor_bank_mainframe_charge_meter.len))
	clevel = round(min(5.5 * charge_level(), capacitor_bank_mainframe_charge_meter.len))
	if(clevel > 0)
		overlays += capacitor_bank_mainframe_charge_meter[clevel]

	if (cap_network)
		if (cap_network.charge > cap_network.safe_capacity)
			overlays += image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-ow")


/obj/machinery/power/capacitor_bank/nnui/mainframe/update_icon()
	..()
	update_overlay()


//--Overrides

/obj/machinery/power/capacitor_bank/nnui/mainframe/process()
	update_overlay()


/obj/machinery/power/capacitor_bank/nnui/mainframe/examine(mob/user)
	..()
	if(cap_network)
		var/clevel = charge_level()
		to_chat(user, "<span class='notice'>The charge meter reads: [round(clevel * 100)]% ([cap_network.charge] J).</span>")