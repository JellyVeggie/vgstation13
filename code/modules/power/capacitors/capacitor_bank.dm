/obj/machinery/power/capacitor_bank
	name = "Capacitor bank"
	desc = "Entire stacks of capacitors to store power with."

	icon = 'icons/obj/machines/capacitor_bank.dmi'
	icon_state = "capacitor_bank_simple"
	icon_state_open = "capacitor_bank_simple_open"
	var/icon_state_broken = "capacitor_bank_simple_broken"
	var/icon_state_off = "capacitor_bank_simple"
	var/icon_state_on = "capacitor_bank_simple"

	density = 1

	machine_flags = SCREWTOGGLE | CROWDESTROY | FIXED2WORK | WRENCHMOVE

	var/datum/capacitor_network/cap_network //The network we belong to

	var/actual_capacity = 0 //How much charge we can hold. 125e4 J per capacitor, see update_parts()
	var/capacity_loss = 0   //How much capacity we've lost to damage
	var/capacity = 0

	var/list/neighbor_dirs = list(1, 2, 4, 8)                          //Directions we can look for neighbors in
	var/list/obj/machinery/power/capacitor_bank/neighbors = list() //Neighbors we're connected to, and where they are relative to us

		component_parts = newlist(
		/obj/item/weapon/circuitboard/capacitor_bank,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor,
	)


/obj/machinery/power/capacitor_bank/New()
	update_capacity()
	find_neighbors()
	update_icon()

/obj/machinery/power/capacitor_bank/Destroy()
	cap_network.remove_node(.)
	..()


//--Capacity suff
/obj/machinery/power/capacitor_bank/RefreshParts()
	//Shamelessly stolen from SMES code
	var/capcount = 0
	for(var/obj/item/weapon/stock_parts/SP in component_parts)
		if(istype(SP, /obj/item/weapon/stock_parts/capacitor))
			capcount += SP.rating

	actual_capacity = capcount*125e4

/obj/machinery/power/capacitor_bank/proc/update_capacity()
	RefreshParts()
	capacity = actual_capacity - capacity_loss


//--Damage

//Increase capacity_loss, discharge some energy, spawn some sparks and possibly explode
/obj/machinery/power/capacitor_bank/proc/damage(var/damage, var/no_explosions=0)
	if (!damage)
		return

	damage = min(damage, cap_network.charge, capacity)
	cap_network.charge -= damage * rand(5,10)/10

	if (!no_explosions && prob(max(100 * (1 + (-6*4.18e6 / (damage + 5*4.18e6))), 0))) //4.18e6 J = 1 Kg TNT. Takes 1Kg to maybe explode, takes 25Kg for an 80% chance
		explode(damage)
		capacity_loss = actual_capacity
	else
		capacity_loss = Clamp(capacity_loss + damage, 0, actual_capacity)
		spark(src)

	update_capacity()
	if (capacity_loss == actual_capacity)
		stat |= BROKEN

/obj/machinery/power/capacitor_bank/proc/explode(var/damage)
	var/heavy = round(max(3 * (1 + (-6 / (damage + 5))), 0))
	var/light = 1 + round(max(5 * (1 + (-6 / (damage + 5))), 0))

	spark(src,6)
	explosion(src, 0, heavy, light, 0)
	stat |= BROKEN

/obj/machinery/power/capacitor_bank/ex_act(severity)
	switch(severity)
		if(1.0)
			if (prob(25))
				explode(capacity)
			qdel(src)
			return

		if(2.0)
			damage(capacity*(rand(3,10)/10))
			if (prob(50))
				qdel(src)
			return

		if(3.0)
			damage(capacity*(rand(0,3)/10))
			if (prob(10))
				qdel(src)
			return
	return

/obj/machinery/power/capacitor_bank/emp_act(severity)
	damage(capacity/2)
	..()

//--Helpers
/obj/machinery/power/capacitor_bank/proc/find_neighbors()
	for(var/direction in neighbor_dirs)
		var/turf/T = get_step(src, direction)
		if(!T)
			continue
		for(var/obj/machinery/power/capacitor_bank/neighbor in T.contents)
			if(neighbor && !(neighbor in neighbors))
				neighbors["[direction]"] = neighbor

/obj/machinery/power/capacitor_bank/update_icon()
	underlays.len = 0
	for (var/i in neighbors)
		var/image/wire = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_underlay")
		wire.dir = i
		underlays += wire

	if(panel_open)
		icon_state = icon_state_open
	else if (broken)
		icon_state = icon_state_broken
	else if ()
		icon_state = icon_state_on
	else
		icon_state = icon_state_off