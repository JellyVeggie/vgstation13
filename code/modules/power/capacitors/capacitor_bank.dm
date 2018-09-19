//"The energy liberated by one gram of TNT was arbitrarily defined as a matter of convention to be 4184 J, which is exactly one kilocalorie."
#define TNTENERGY 4.18e6 //1 Kg TNT = 4.18 MJ,

/obj/machinery/power/capacitor_bank
	name = "capacitor bank"
	desc = "Entire stacks of capacitors to store power with. You're not entirely sure capacitors work that way"

	//Icons
	icon = 'icons/obj/machines/capacitor_bank.dmi'
	icon_state = "capacitor_bank"
	icon_state_open = "capacitor_bank_open"
	var/icon_state_broken = "capacitor_bank_broken"
	var/icon_state_openb = "capacitor_bank_openb"
	var/icon_state_off = "capacitor_bank"
	var/icon_state_on = "capacitor_bank_on"
	var/icon_state_active = "capacitor_bank_on"

	//Machine stuff
	density = 1
	machine_flags = SCREWTOGGLE | CROWDESTROY | FIXED2WORK | WRENCHMOVE

	component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor
	)

	//Capacity

	var/actual_capacity = 0 //How much charge we can hold.
	var/capacity_loss = 0   //How much capacity we've lost to damage
	var/capacity = 0        //Actual - loss

	//Network
	var/datum/capacitor_network/cap_network //The network we belong to

	var/list/connected_dirs = list()
	var/list/neighbors[8]

	var/list/wire_underlays[8]

/obj/machinery/power/capacitor_bank/New()
	..()
	wire_underlays[NORTH] = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_un")
	wire_underlays[SOUTH] = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_us")
	wire_underlays[EAST]  = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_ue")
	wire_underlays[WEST]  = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_uw")
	RefreshParts()
	state = 1
	update_icon()

/obj/machinery/power/capacitor_bank/Destroy()
	disconnect()
	..()

//--Network stuff
/obj/machinery/power/capacitor_bank/proc/available_dirs()
	return (cardinal - connected_dirs)


/obj/machinery/power/capacitor_bank/proc/find_neighbors()
	var/list/obj/machinery/power/capacitor_bank/found_neighbors = list()
	for(var/dir in available_dirs())
		var/turf/T = get_step(src, dir)
		if(!T)
			continue
		for(var/obj/machinery/power/capacitor_bank/neighbor in T.contents)
			if(neighbor.cap_network)
				found_neighbors += neighbor
	return found_neighbors


/obj/machinery/power/capacitor_bank/proc/connect_to(var/obj/machinery/power/capacitor_bank/neighbor, var/dir = null)
	if(!dir)
		dir = get_dir_cardinal(src, neighbor)

	neighbors[dir] = neighbor
	connected_dirs += dir
	neighbor.neighbors[reverse_direction(dir)] = src
	neighbor.connected_dirs += reverse_direction(dir)
	neighbor.update_icon()


/obj/machinery/power/capacitor_bank/proc/connect()
	if(!cap_network)
		cap_network = new /datum/capacitor_network()
		cap_network.add_node(src)

	if (!use_power)
		use_power = 1

	for(var/obj/machinery/power/capacitor_bank/neighbor in find_neighbors())
		connect_to(neighbor)
		cap_network.merge_network(neighbor.cap_network)
	update_icon()


/obj/machinery/power/capacitor_bank/proc/disconnect_from(var/obj/machinery/power/capacitor_bank/neighbor, var/dir = null)
	if(!dir)
		dir = get_dir_cardinal(src, neighbor)

	neighbors[dir] = null
	connected_dirs -= dir
	neighbor.neighbors[reverse_direction(dir)] = null
	neighbor.connected_dirs -= reverse_direction(dir)
	neighbor.update_icon()


/obj/machinery/power/capacitor_bank/proc/disconnect()
	var/list/obj/machinery/power/capacitor_bank/old_neighbors = list()
	var/datum/capacitor_network/old_network = cap_network
	use_power = 0
	cap_network.remove_node(src)

	for(var/dir in connected_dirs)
		old_neighbors += neighbors[dir]
		disconnect_from(neighbors[dir], dir)

	old_network.rebuild_from(old_neighbors)
	update_icon()


/obj/machinery/power/capacitor_bank/proc/is_mainframe()
	return 0

//--Capacity suff

/obj/machinery/power/capacitor_bank/proc/update_capacity()
	if (cap_network)
		cap_network.capacity -= capacity
	capacity = actual_capacity - capacity_loss
	if (cap_network)
		cap_network.capacity += capacity

//--Damage
//Increase capacity_loss, discharge some energy, spawn some sparks and possibly explode
/obj/machinery/power/capacitor_bank/proc/damage(var/base_damage, var/no_explosions=0)
	var/damage_percent = pick(20;1.1,40;0.8,40;0.4)

	if (!cap_network)
		return

	var/damage = Clamp(base_damage * damage_percent, 0, min(cap_network.charge, capacity))

	if (!damage)
		return

	cap_network.charge = max(cap_network.charge - damage, 0)

	if (!no_explosions && prob(max(100 * (1 + (-6 * TNTENERGY / (damage + 5 * TNTENERGY))), 0))) //1 Kg TNT = 4.18 MJ
		explode(damage)
		capacity_loss = actual_capacity
	else
		capacity_loss = Clamp(capacity_loss + damage, 0, actual_capacity)
		spark(src)

	update_capacity()

	if (capacity_loss == actual_capacity)
		stat |= BROKEN
		disconnect()
		update_icon()


/obj/machinery/power/capacitor_bank/proc/explode(var/damage)
	//Pulled these out of my as, don't use them as the basis for a "TNT equivalent" scale
	var/heavy = round(max(3 * (1 + (-6 * TNTENERGY / (damage + 5 * TNTENERGY))), 0))
	var/light = 1 + round(max(5 * (1 + (-6 * TNTENERGY / (damage + 5 * TNTENERGY))), 0))

	spark(src, 6)
	explosion(src, 0, heavy, light, 0)
	stat |= BROKEN


//--Overrides

/obj/machinery/power/capacitor_bank/attackby(var/obj/O, var/mob/user)
	..()
	if (istype(O, /obj/item/stack/cable_coil) && !cap_network && state)
		connect()
		to_chat(user, "<span class='notice'>You wire \the [src][neighbors.len ? " and connect it to adjacent machines" : ""].</span>")

	if (istype(O, /obj/item/weapon/wirecutters) && cap_network)
		if(do_after(user, src, 30))
			disconnect()
			to_chat(user, "<span class='notice'>You cut \the [src]'s wires.</span>")

/obj/machinery/power/capacitor_bank/wrenchable()
	var/list/obj/machinery/power/capacitor_bank/other_machines = list()
	for (var/obj/machinery/power/capacitor_bank/other in src.loc.contents)
		other_machines += other
	other_machines -= src

	if(cap_network || other_machines.len > 0) //must not be wired and there must not be another capacitor machine on the same tile (wire nodes)
		return 0
	else
		return ..()

/obj/machinery/power/capacitor_bank/ex_act(severity)
	switch(severity)
		if(1.0)
			if (prob(25))
				explode(capacity)
			qdel(src)
			return

		if(2.0)
			if (prob(50))
				qdel(src)
			else if (prob(20)) //10% chance chain reaction (assumming enough charge and damage
				damage(capacity*(rand(3,10)/10), 0)
			else
				damage(capacity*(rand(3,10)/10), 1)
			return

		if(3.0)
			if (prob(10))
				qdel(src)
			else
				damage(capacity*(rand(1,3)/10), 1)
			return
	return

/obj/machinery/power/capacitor_bank/emp_act(severity)
	damage(capacity/2)
	..()

/obj/machinery/power/capacitor_bank/RefreshParts()
	actual_capacity = 0
	for(var/obj/item/weapon/stock_parts/capacitor/C in component_parts)
		actual_capacity += C.maximum_charge

/obj/machinery/power/capacitor_bank/examine(mob/user)
	..()
	if (cap_network)
		to_chat(user, "<span class='notice'>The [src] is wired up and fixed in place.</span>")
	else if(state)
		to_chat(user, "<span class='notice'>The [src] is anchored to the ground, but could use some wiring.</span>")

/obj/machinery/power/capacitor_bank/update_icon()
	underlays.len = 0

	for (var/i in connected_dirs)
		underlays += wire_underlays[i]

	if(panel_open)
		if (stat & BROKEN)
			icon_state = icon_state_openb
		else
			icon_state = icon_state_open
	else if (stat & BROKEN)
		icon_state = icon_state_broken
	else if (use_power == 1)
		icon_state = icon_state_on
	else if (use_power == 2)
		icon_state = icon_state_active
	else
		icon_state = icon_state_off