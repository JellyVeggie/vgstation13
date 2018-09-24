/////////////////////////////////////////////
// MAINFRAME

var/global/list/DC_mainframe_charge_meter = list(
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og1"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og2"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og3"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og4"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og5")
	)


/obj/machinery/capacitor_bank/mainframe
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
/obj/machinery/capacitor_bank/mainframe/proc/get_ui_data()
	var/data[0]
	data["hasNetwork"] = mDC_node.network
	if (cap_network)
		data["charge"] = mDC_node.network.charge
		data["chargeLevel"] = round(charge_level() * 100,0.1)
		data["capacity"] = mDC_node.network.capacity
		data["safeCapacity"] = mDC_node.network.safe_capacity
		data["safeCapacityBonus"] = mDC_node.network.safe_capacity - mDC_node.network.capacity * mDC_node.network.base_safety_limit
		data["nodes"] = mDC_node.network.nodes.len
		data["mainframes"] = mDC_node.network.mainframes
		data["mainframesWanted"] = -round(mDC_node.network.nodes.len / -10) //Ceiling(mDC_node.network.nodes.len / 10). THis should be replaced with an actual Ceiling() some day
	else
		data["charge"] = 0
		data["capacity"] = 0
		data["chargeLevel"] = 0
		data["safeCapacity"] = 0
		data["safeCapacityBonus"] = 0
		data["nodes"] = 0
		data["mainframes"] = 0
		data["mainframesWanted"] = 0

	return data


//--Network

/obj/machinery/capacitor_bank/mainframe/proc/charge_level()
	if(mDC_node.network)
		var/clevel = max(mDC_node.network.charge/(mDC_node.network.safe_capacity ? mDC_node.network.safe_capacity : 0.01), 0)
		return clevel
	else
		return 0


/obj/machinery/capacitor_bank/mainframe/is_mainframe()
	return !(stat & BROKEN)

//--Icon

/obj/machinery/capacitor_bank/mainframe/proc/update_overlay()
	var/clevel = min(-round(-4 * charge_level()), DC_mainframe_charge_meter.len)
	overlays.len = 0

	if(clevel > 0)
		overlays += DC_mainframe_charge_meter[clevel]

	if (clevel > 1)
		overlays += image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-ow")


/obj/machinery/capacitor_bank/mainframe/update_icon()
	..()
	update_overlay()


//--Overrides

//TODO: Kinda wasteful, should tie it to events and stuff at some point
/obj/machinery/capacitor_bank/mainframe/process()
	update_overlay()


/obj/machinery/capacitor_bank/mainframe/examine(mob/user)
	..()
	if(mDC_node.network)
		to_chat(user, "<span class='notice'>The charge meter reads: [round(charge_level() * 100,0.1)]% ([network.charge] J).</span>")