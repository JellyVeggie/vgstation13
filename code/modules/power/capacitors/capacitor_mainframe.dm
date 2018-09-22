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

	ui_tmpl = "capacitor_bank_mainframe.tmpl" //The .tmpl file used for the UI
	ui_name = "The Capacitor Mainframe" // The name that'll appear on the UI

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
	if (cap_network)
		data["charge"] = cap_network.charge
		data["capacity"] = cap_network.capacity
		data["safeCapacity"] = cap_network.safe_capacity
		data["safeCapacityBonus"] = cap_network.safe_capacity - cap_network.capacity * cap_network.base_safety_limit
		data["networkSafety"] = cap_network.network_safety
		data["nodes"] = cap_network.nodes.len
		data["mainframes"] = cap_network.mainframes
		data["mainframesWanted"] = -round(-cap_network.nodes.len / 10) //Ceiling(cap_network.nodes.len / 10). THis should be replaced with an actual Ceiling() some day
	else
		data["charge"] = 0
		data["capacity"] = 0
		data["safeCapacity"] = 0
		data["safeCapacityBonus"] = 0
		data["networkSafety"] = 0
		data["nodes"] = 0
		data["mainframes"] = 0
		data["mainframesWanted"] = 0

	return data


//--Network

/obj/machinery/power/capacitor_bank/nnui/mainframe/proc/charge_level()
	if(cap_network)
		var/clevel = max(cap_network.charge/(cap_network.safe_capacity ? cap_network.safe_capacity : 0.01), 0)
		return clevel
	else
		return 0

/obj/machinery/power/capacitor_bank/nnui/mainframe/is_mainframe()
	return !(stat & BROKEN)


//--Icon

/obj/machinery/power/capacitor_bank/nnui/mainframe/proc/update_overlay()
	var/clevel = min(-round(-4 * charge_level()), capacitor_bank_mainframe_charge_meter.len)
	overlays.len = 0

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