/datum/capacitor_network
	var/charge = 0         // How much power the net holds
	var/capacity = 0       // How much power the net can hold

	var/mainframes = 0     // Mainframes in the net. More mainframes = higher safety limit. 1 out of 10 is ideal
	var/safety_limit = 0.5 // How much power the net can hold before machinery starts failing (as percent of capacity, from 0.5 to 0.9)
	var/safe_capacity = 0

	var/network_safety = 0        // Wether it's safe to disconnect things willy nilly

	var/list/obj/machinery/power/capacitor_bank/nodes = list()

/datum/capacitor_network/proc/add_node(var/obj/machinery/power/capacitor_bank/node)
	node.cap_network = src
	nodes += node
	capacity += node.capacity
	if (node.is_mainframe())
		mainframes += 1

/datum/capacitor_network/proc/remove_node(var/obj/machinery/power/capacitor_bank/node, var/force_safety)
	if (node in nodes)
		nodes -= node
		node.cap_network = null
		capacity -= node.capacity

		if (node.is_mainframe())
			mainframes -= 1

/datum/capacitor_network/proc/merge_network(var/datum/capacitor_network/network)
	if (src == network)
		return

	var/datum/capacitor_network/N1 //The largest network of the two.
	var/datum/capacitor_network/N2 //The smallest of the two, to be absorbed by the largest

	if (nodes.len > network.nodes.len)
		N1 = src
		N2 = network
	else
		N1 = network
		N2 = src

	N1.charge += N2.charge
	N1.capacity += N2.capacity
	N1.mainframes += N2.mainframes
	for (var/obj/machinery/power/capacitor_bank/node in N2.nodes)
		node.cap_network = N1
		node.update_capacity()
	N1.nodes += N2.nodes

	N1.update_charge()
	del N2

/datum/capacitor_network/proc/split_from_network(var/list/obj/machinery/power/capacitor_bank/old_nodes)
	var/datum/capacitor_network/new_network = new /datum/capacitor_network()
	var/old_charge = charge
	var/old_capacity = capacity

	for (var/node in old_nodes)
		remove_node(node, 1)
		new_network.add_node(node)

	update_safety()
	new_network.update_safety()
	charge = old_charge * capacity/old_capacity
	new_network.charge = old_charge * new_network.capacity/old_capacity

/datum/capacitor_network/proc/rebuild_from(var/list/obj/machinery/power/capacitor_bank/seeding_nodes)
	var/list/obj/machinery/power/capacitor_bank/new_network_nodes //Nodes that will spliter off
	var/list/obj/machinery/power/capacitor_bank/frontier //Nodes added to new_network_nodes whose neighbors we are yet to check
	var/obj/machinery/power/capacitor_bank/node //Our index going through all the nodes
	var/list/obj/machinery/power/capacitor_bank/new_neighbors = list() //Our index's neighbors

	while(seeding_nodes.len > 1) //whatever seed node is left will hold all the nodes that didn't splinter off to new networks
		new_network_nodes = list()
		frontier = list()

		node = seeding_nodes[1] //Pick a seed
		seeding_nodes -= node

		frontier += node //Initialize the frontier
		new_network_nodes += node //The seed belongs on the new network

		while (frontier.len > 0 && seeding_nodes.len > 0) //Keep exploring the frontier til it's gone or all seeds left are proven to be part of this network
			node = frontier[1] //Pick a node
			frontier -= node

			for (var/i in node.connected_dirs) //Get the neighbors
				new_neighbors += node.neighbors[i]
			new_neighbors -= new_network_nodes //Neighbors we already know about aren't really new

			frontier += new_neighbors //Expand the network's frontier with the new neighbors
			new_network_nodes += new_neighbors
			seeding_nodes -= new_neighbors //Seeds found while exploring this network are not valid seeds for a different network

		if(seeding_nodes.len > 0)
			split_from_network(new_network_nodes)


/datum/capacitor_network/proc/update_safety()
	safety_limit = 0.5 + 0.4 * Clamp((nodes.len ? 10 * mainframes / nodes.len : 0), 0, 1)
	safe_capacity = capacity * safety_limit


/datum/capacitor_network/proc/update_charge(var/added_charge = 0)
	charge = Clamp(charge, 0, capacity)

	if(charge > safe_capacity && prob(100 * charge/safe_capacity - 95))
		var/obj/machinery/power/capacitor_bank/node/ = pick(nodes)
		node.damage(charge - safe_capacity)

	update_safety()