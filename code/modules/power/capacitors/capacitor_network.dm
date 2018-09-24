var/global/list/DC_wire_underlays = list(NORTH = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_un"),
                                         SOUTH = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_us"),
                                         EAST  = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_ue"),
                                         WEST  = image('icons/obj/machines/capacitor_bank.dmi',icon_state = "wire_uw"))

/////////////////////////////////////////////////////////////////////////////////////
// MACHINERY
/*
 *
 */

/obj/machinery
	/* Do not give the machine a DC node unless it is ready to connect to the DC network (wrenched and welded and whatever)
	 *  To give them a DC node, pass the machine when creating the node, something like
	 * "mDC_node = new /datum/DC_node(src)"
	 */
	var/datum/DC_node/mDC_node = null //machine's DC node

// A list of directions through which other DC machinery could connect to this one.
/obj/machinery/proc/DC_available_dirs()
	// For DC machinery this should usually be "cardinal", though "cardinal - dir" is a common option too
	return list() //Can't connect, by default. You'll have to overwrite this


// Wether this machine helps make DC networks it's connected to safely hold more charge
/obj/machinery/proc/DC_is_mainframe()
	return 0


// How excess power on the DC network this machine is connected to affects the machine
/obj/machinery/proc/DC_damage(var/energy)
	/* Here you get some energy as a rough guideline of severity, do whatever you need to do, and draw
	 *  however much energy you've actually used from the DC network you're connected to. I'd recommend
	 *  you use "mDC_node.network.draw_charge(energy)" for that, rather than manually manipulating the network.
	 *
	 * If your machine's intended for charge storage of any form you should also call "node.do_damage(energy)" with
	 *  however much capacity it should lose
	 */
	return

// Most DC machinery should have a wiring underlay showing what they are connected to. Should your machine have to show a wiring underlay, you
// can implement that like on this example. Replace DC_wire_underlays with whatever list of wires you need
/*
/obj/machinery/.../update_icon()
	uderlays.len = 0
	if(mDC_node)
		for (var/i in mDC_node.connected_dirs)
			underlays += DC_wire_underlays[i]
	..()
*/

/////////////////////////////////////////////////////////////////////////////////////
// DC NODE
/*
 *
 */
/datum/DC_node
	//Capacity
	var/actual_capacity = 0 //How much charge we can hold.
	var/capacity_loss = 0   //How much capacity we've lost to damage
	var/capacity = 0        //actual_capacity - capacity_loss

	//Machine
	var/obj/machinery/machine = null

	//Network
	var/datum/DC_network/network //The network we belong to

	var/list/connected_dirs = list()
	var/list/DC_node/neighbors[8] // Nodes we're connected to, and which direction they're in


/datum/DC_node/New(var/obj/machinery/machine)
	if(!machine) //Can't exist without a host machine!
		del src

	src.machine = machine
	machine.mDC_node = src


/datum/DC_node/Destroy()
	disconnect()
	machine.mDC_node = null
	..()


//-- Network helpers --

/datum/DC_node/proc/is_mainframe()
	return machine.is_mainframe()


/datum/DC_node/proc/available_dirs()
	return (machine.DC_available_dirs() - connected_dirs)


/datum/DC_node/proc/find_neighbors()
	var/list/datum/DC_node/found_neighbors = list()

	for(var/dir in available_dirs())
		var/turf/T = get_step(machine, dir)
		if(!T)
			continue
		for(var/list/obj/machinery/neighboring_machine in T.contents)
			if(neighboring_machine.mDC_node)
				if(reverse_direction(dir) in neighboring_machine.mDC_node.available_dirs())
					found_neighbors += neighboring_machine.mDC_node

	return found_neighbors


//-- Network connect --

/datum/DC_node/proc/connect_to(var/datum/DC_node/neighbor, var/dir)
	if (!dir)
		dir = get_dir_cardinal(src.machine, neighbor.machine)

	neighbors[dir] = neighbor
	connected_dirs += dir
	neighbor.neighbors[reverse_direction(dir)] = src
	neighbor.connected_dirs += reverse_direction(dir)
	neighbor.machine.update_icon()


/datum/DC_node/proc/connect()
	if(!network)
		network = new /datum/DC_network()
		network.add_node(src)

	for(var/datum/DC_node/neighbor in find_neighbors())
		connect_to(neighbor)
		network.merge_network(neighbor.network)
	machine.update_icon()


//-- Network disconnect --

/datum/DC_node/proc/disconnect_from(var/datum/DC_node/neighbor, var/dir)
	if (!dir)
		dir = get_dir_cardinal(src.machine, neighbor.machine)

	neighbors[dir] = null
	connected_dirs -= dir
	neighbor.neighbors[reverse_direction(dir)] = null
	neighbor.connected_dirs -= reverse_direction(dir)
	neighbor.machine.update_icon()


/datum/DC_node/proc/disconnect()
	var/list/DC_node/old_neighbors = list()
	var/datum/DC_network/old_network = network
	network.remove_node(src)

	for(var/dir in connected_dirs)
		old_neighbors += neighbors[dir]
		disconnect_from(neighbors[dir], dir)

	old_network.rebuild_from(old_neighbors)
	machine.update_icon()


//-- Capacity --

/datum/DC_node/proc/update_capacity()
	if (network)
		network.capacity -= capacity
	capacity = max(actual_capacity - capacity_loss, 0)
	if (network)
		network.capacity += capacity


//-- Damage --

/datum/DC_node/proc/damage(var/damage)
	machine.DC_can_damage()

/datum/DC_node/proc/do_damage(var/damage)
	capacity_loss = min(capacity_loss + damage)
	update_capacity()


/////////////////////////////////////////////////////////////////////////////////////
// DC NETWORK
/*
 *
 */
/datum/DC_network
	var/charge = 0         // How much power the net holds
	var/capacity = 0       // How much power the net can hold

	var/mainframes = 0 // Mainframes in the net. More mainframes = higher safety limit. 1 out of 10 is ideal
	var/safety_limit = 0 // How much power the net can hold before machinery starts failing (as percent of capacity, from 0.5 to 0.9)
	var/safe_capacity = 0
	var/const/base_safety_limit = 0.5
	var/const/max_safety_limit = 0.9

	var/network_safety = 0 // Wether it's safe to disconnect things willy nilly. TODO: Have network damage actually work

	var/list/obj/machinery/power/capacitor_bank/nodes = list()

/datum/DC_network/New(var/datum/DC_node/node)
	if(node)
		add_node(node)

/datum/DC_network/Destroy()
	for (var/datum/DC_node/node in nodes)
		node.disconnect()

//-- Node operations --

/datum/DC_network/proc/add_node(var/obj/machinery/power/capacitor_bank/node)
	node.network = src
	nodes += node
	capacity += node.capacity
	if (node.is_mainframe())
		mainframes += 1
	update_safety()


/datum/DC_network/proc/remove_node(var/obj/machinery/power/capacitor_bank/node)
	if (node in nodes)
		nodes -= node
		node.network = null
		capacity -= node.capacity

		if (node.is_mainframe())
			mainframes -= 1
		update_safety()


//-- Network operations --

/datum/DC_network/proc/merge_network(var/datum/DC_network/network)
	if (src == network)
		return

	var/datum/DC_network/N1 //The largest network of the two.
	var/datum/DC_network/N2 //The smallest of the two, to be absorbed by the largest

	if (nodes.len > network.nodes.len)
		N1 = src
		N2 = network
	else
		N1 = network
		N2 = src

	N1.charge += N2.charge
	for (var/datum/DC_node/node in N2.nodes)
		N2.remove_node(node)
		N1.add_node(node)

	del N2


/datum/DC_network/proc/split_from_network(var/list/datum/DC_node/old_nodes)
	var/datum/DC_network/new_network = new /datum/DC_network()
	var/old_charge = charge
	var/old_capacity = capacity

	for (var/datum/DC_node/node in old_nodes)
		remove_node(node)
		new_network.add_node(node)

	update_safety()
	new_network.update_safety()

	charge = old_charge * capacity/old_capacity
	new_network.charge = old_charge * new_network.capacity/old_capacity


/datum/DC_network/proc/rebuild_from(var/list/datum/DC_node/seeding_nodes)
	var/list/datum/DC_node/new_network_nodes //Nodes that will spliter off
	var/list/datum/DC_node/frontier //Nodes added to new_network_nodes whose neighbors we are yet to check
	var/datum/DC_node/node //Our index going through all the nodes
	var/list/datum/DC_node/new_neighbors = list() //Our index's neighbors

	while(seeding_nodes.len > 1) //whatever seed node is left will hold all the nodes that didn't splinter off to new networks
		new_network_nodes = list()
		frontier = list()

		node = seeding_nodes[1] //Pick a seed
		seeding_nodes -= node

		frontier += node //Seed the frontier with a "beachhead"
		new_network_nodes += node //The seed belongs on the new network

		while (frontier.len > 0 && seeding_nodes.len > 0) //Keep exploring the frontier til it's gone or all seeds left are proven to be part of this network
			node = frontier[1] //Pick a node
			frontier -= node

			new_neighbors.len = 0
			for (var/i in node.connected_dirs) //Get the neighbors
				new_neighbors += node.neighbors[i]
			new_neighbors -= new_network_nodes //Neighbors we already know about aren't really new

			frontier += new_neighbors //Expand the network's frontier with the new neighbors
			new_network_nodes += new_neighbors
			seeding_nodes -= new_neighbors //Seeds found while exploring this network are not valid seeds for a different network

		if(seeding_nodes.len > 0)
			split_from_network(new_network_nodes)


//-- Update --

/datum/DC_network/proc/update_safety()
	safety_limit = base_safety_limit + (max_safety_limit - base_safety_limit) * Clamp((nodes.len ? 10 * mainframes / nodes.len : 0), 0, 1)
	safe_capacity = capacity * safety_limit


/datum/DC_network/proc/update_charge()
	if(charge > safe_capacity && prob(100 * charge / safe_capacity - 95))
		var/datum/DC_node = pick(nodes)
		var/damage_multiplier = pick(1;0.1,5;0.2,20;0.3,40;0.4,50;0.5,40;0.6,20;0.7,5;0.8,1;0.9)

		node.machine.DC_damage(charge * damage_multiplier)
	update_safety()

/datum/DC_network/proc/add_charge(var/energy)
	charge = Clamp(charge + energy, 0, capacity)