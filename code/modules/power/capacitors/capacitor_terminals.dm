/obj/machinery/power/capacitor_bank/terminal/

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

/obj/machinery/power/capacitor_bank/terminal/inverter
	name = "power inverter"
	desc = "A motor and generator to turn DC power back into AC. Keep it lubed"

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
		/obj/item/weapon/reagent_containers/glass/beaker
	)

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