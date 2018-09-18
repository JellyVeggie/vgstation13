var/global/list/capacitor_bank_mainframe_charge_meter = list(
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og1"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og2"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og3"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og4"),
		image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-og5")
	)


/obj/machinery/power/capacitor_bank/mainframe
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


//Helpers

/obj/machinery/power/capacitor_bank/mainframe/proc/charge_level()
	if(cap_network)
		var/clevel = max(cap_network.charge/(cap_network.safe_capacity ? cap_network.safe_capacity : 0.1), 0)
		return clevel
	else
		return 0

/obj/machinery/power/capacitor_bank/mainframe/examine(mob/user)
	..()
	if(cap_network)
		var/clevel = charge_level()
		to_chat(user, "<span class='notice'>The charge meter reads: [round(clevel * 100)]% ([cap_network.charge] J).</span>")

/obj/machinery/power/capacitor_bank/mainframe/proc/update_overlay()
	overlays.len = 0

	var/clevel = round(min(5.5 * charge_level(), capacitor_bank_mainframe_charge_meter.len))
	clevel = round(min(5.5 * charge_level(), capacitor_bank_mainframe_charge_meter.len))
	if(clevel > 0)
		overlays += capacitor_bank_mainframe_charge_meter[clevel]

	if (cap_network)
		if (cap_network.charge > cap_network.safe_capacity)
			overlays += image('icons/obj/machines/capacitor_bank.dmi', "capacitor_mainframe-ow")

/obj/machinery/power/capacitor_bank/mainframe/update_icon()
	..()
	update_overlay()

/obj/machinery/power/capacitor_bank/mainframe/process()
	update_overlay()

/obj/machinery/power/capacitor_bank/mainframe/is_mainframe()
	return !(stat & BROKEN)