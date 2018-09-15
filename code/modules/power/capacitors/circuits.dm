//////////////////////////////////////
// Basic capacitor banks

/obj/item/weapon/circuitboard/capacitor_bank
	name = "Circuit board (Capacitor bank)"
	desc = "A simple circuitboard controlling the capacitor stacks on a capacitor bank. You could vastly improve it using a solder"
	icon_state = "cyborg_upgrade2"
	build_path = /obj/machinery/power/capacitor_bank
	origin_tech =  Tc_PROGRAMMING + "=2;" + Tc_ENGINEERING + "=2;" + Tc_POWERSTORAGE + "=3"
	board_type = MACHINE

//////////////////////////////////////
// Capacitor Mainframes

/obj/item/weapon/circuitboard/capacitor_bank/mainframe
	name = "Circuit board (Capacitor mainframe)"
	desc = "A not so simple circuitboard controlling the capacitor banks on a capacitor network"
	icon_state = "mainboard"
	build_path = /obj/machinery/power/capacitor_bank
	origin_tech =  Tc_PROGRAMMING + "=4;" + Tc_ENGINEERING + "=2;" + Tc_POWERSTORAGE + "=3"
	board_type = MACHINE

// Getting the board
/obj/item/weapon/circuitboard/capacitor_bank/solder_improve(mob/user as mob)
	to_chat(user, "<span class='notice'>You unfold the board and rewire the extra parts.</span>")
	var/obj/item/weapon/circuitboard/capacitor_bank/mainframe/A = new /obj/item/weapon/circuitboard/capacitor_bank/mainframe(src.loc)
	user.put_in_hands(A)
	qdel(src)
	return

//////////////////////////////////////
// Capacitor Power Input

/obj/item/weapon/circuitboard/capacitor_bank/rectifier
	name = "Circuit board (Capacitor rectifier)"
	desc = "A mercury arc rectifier circuitboard to convert from AC to DC with"
	icon_state = "power_mod"
	build_path = /obj/machinery/power/capacitor_bank
	origin_tech =  Tc_PROGRAMMING + "=2;" + Tc_ENGINEERING + "=3;" + Tc_POWERSTORAGE + "=4"
	board_type = MACHINE

//////////////////////////////////////
// Capacitor Power Output

/obj/item/weapon/circuitboard/capacitor_bank/inverter
	name = "Circuit board (Capacitor inverter)"
	desc = "An inverter circuitboard to convert from DC to AC with"
	icon_state = "power_mod"
	build_path = /obj/machinery/power/capacitor_bank
	origin_tech =  Tc_PROGRAMMING + "=2;" + Tc_ENGINEERING + "=3;" + Tc_POWERSTORAGE + "=4"
	board_type = MACHINE

//////////////////////////////////////
// Capacitor Power Exchange

/obj/item/weapon/circuitboard/capacitor_bank/adapter
	name = "Circuit board (Capacitor adapter)"
	desc = "A circuitboard for pasing DC power to and from complex, power-hungry machinery"
	icon_state = "power_mod"
	build_path = /obj/machinery/power/capacitor_bank
	origin_tech =  Tc_PROGRAMMING + "=3;" + Tc_ENGINEERING + "=3;" + Tc_POWERSTORAGE + "=3"
	board_type = MACHINE