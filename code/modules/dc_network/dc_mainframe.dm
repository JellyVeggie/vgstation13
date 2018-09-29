/////////////////////////////////////////////
// MAINFRAME

var/global/list/DC_mainframe_charge_meter = list(
		image('icons/obj/machines/dc_network.dmi', "capacitor_mainframe-og1"),
		image('icons/obj/machines/dc_network.dmi', "capacitor_mainframe-og2"),
		image('icons/obj/machines/dc_network.dmi', "capacitor_mainframe-og3"),
		image('icons/obj/machines/dc_network.dmi', "capacitor_mainframe-og4"),
		image('icons/obj/machines/dc_network.dmi', "capacitor_mainframe-og5")
	)


/obj/machinery/capacitor_bank/mainframe
	name = "capacitor mainframe"
	desc = "Manages and stabilizes any capacitor banks it's been connected to."

	var/ui_tmpl = "capacitor_bank_mainframe.tmpl" //The .tmpl file used for the UI
	var/ui_name = "The Capacitor Mainframe" // The name that'll appear on the UI

	icon_state = "capacitor_mainframe"
	icon_state_open = "capacitor_mainframe_open"
	icon_state_broken = "capacitor_mainframe_broken"
	icon_state_openb = "capacitor_mainframe_openb"
	icon_state_off = "capacitor_mainframe"
	icon_state_on = "capacitor_mainframe_on"

	//Machine stuff
	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank/mainframe,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/console_screen
	)

//-- UI --
/obj/machinery/capacitor_bank/mainframe/proc/get_ui_data()
	var/data[0]
	var/datum/DC_network/net = get_DCnet()
	if(net)
		data["hasNetwork"] = 1
		data["charge"] = list("num" = net.charge, "text" = "[format_units(net.charge)]J")
		data["chargeLevel"] = round(charge_level() * 100,0.1)
		data["capacity"] = list("num" = net.capacity, "text" = "[format_units(net.capacity)]J")
		data["safeCapacity"] = list("num" = net.safe_capacity, "text" = "[format_units(net.safe_capacity)]J")
		var/safe_bonus = net.safe_capacity - net.capacity * net.base_safety_limit
		data["safeCapacityBonus"] =  list("num" = safe_bonus, "text" = "[format_units(safe_bonus)]J")
		data["nodes"] = net.nodes.len
		data["mainframes"] = net.mainframes
		data["mainframesWanted"] = -round(net.nodes.len / -10) //Ceiling(mDC_node.network.nodes.len / 10). THis should be replaced with an actual Ceiling() some day
	else
		data["hasNetwork"] = 0
		data["charge"] = 0
		data["capacity"] = 0
		data["chargeLevel"] = 0
		data["safeCapacity"] = 0
		data["safeCapacityBonus"] = 0
		data["nodes"] = 0
		data["mainframes"] = 0
		data["mainframesWanted"] = 0

	return data


//-- UI Overrides --

/obj/machinery/capacitor_bank/mainframe/attack_ai(mob/user)
	src.add_hiddenprint(user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/capacitor_bank/mainframe/attack_hand(mob/user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/capacitor_bank/mainframe/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)

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


/obj/machinery/capacitor_bank/mainframe/Topic(href, href_list)
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


//-- Network --

/obj/machinery/capacitor_bank/mainframe/proc/charge_level()
	var/datum/DC_network/net = get_DCnet()
	if(net)
		return max(net.charge/(net.safe_capacity ? net.safe_capacity : 0.01), 0)
	return 0


//-- Network Overrides --
/obj/machinery/capacitor_bank/mainframe/DC_is_mainframe()
	return !(stat & BROKEN)


//-- Icon OVerrides --
/obj/machinery/capacitor_bank/mainframe/update_overlay()
	..()

	var/clevel = min(-round(-4 * charge_level()), DC_mainframe_charge_meter.len)

	if(clevel > 0)
		overlays += DC_mainframe_charge_meter[clevel]


/obj/machinery/capacitor_bank/mainframe/examine(mob/user)
	..()
	var/datum/DC_network/net = get_DCnet()
	if(net)
		to_chat(user, "<span class='notice'>The charge meter reads: [round(charge_level() * 100,0.1)]% (format_units([net.charge])J).</span>")


//-- Machine Overrides

//TODO: Kinda wasteful, should tie it to events and stuff at some point
/obj/machinery/capacitor_bank/mainframe/process()
	update_overlay()