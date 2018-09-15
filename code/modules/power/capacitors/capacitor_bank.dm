/datum/capacitor_network
	var/charge = 0         // How much power the net holds
	var/capacity = 0       // How much power the net can hold

	var/list/obj/machinery/power/capacitor_bank/nodes = list()
	var/list/obj/machinery/power/capacitor_bank/processors = list()

	var/obj/machinery/power/capacitor_bank/processor = null
	var/mainframes = 0     // Mainframes in the net. More mainframes = higher safety limit. 1 out of 10 is ideal

	var/safety_limit = 0.5 // How much power the net can hold before machinery starts failing (as percent of capacity, from 0.5 to 0.9)



/datum/capacitor_network/proc/update_safety()
	safety_limit = 0.5
	if (nodes.len && mainframes)
		safety_limit += 0.4 * nodes.len / (10 * mainframes)


/datum/capacitor_network/proc/add_node(node as var/obj/machinery/power/capacitor_bank/, var/recursive = 0)
	if (!(node in nodes))
		if (node.cap_network)
			// Merge networks
			for (i in node.cap_network.nodes)
				i.cap_network = .
				nodes += i
			node.cap_network.nodes.len = 0

			node.cap_network.processor.is_processor = 0
			node.cap_network.processor = null

			charge += node.cap_network.charge
			capacity += node.cap_network.capacity
			processors += node.cap_network.processors
			mainframes += node.cap_network.mainframes
			update_safety()

			node.cap_network.Del()

		else
			// Add the orphan in
			node.cap_network = .
			capacity += node.capacity
			if(node.is_mainframe())
				mainframes += 1

			node.is_processor = 0
			if(node.can_process())
				processors += node

			node.get_neighbors()

			// Add nearby orphans too, recursively
			for (i in node.neighbors)
				if (neighbor.cap_network != .)
					add_node(i, 1)

		if (!recursive)
			update_safety()
			if (!processor)
				if (processors.len)
					processor = pick(processors)
					processor.is_processor = 1
				else
					processor = pick(nodes)
					processor.make_processor()
					processor.is_processor = 1


/datum/capacitor_network/proc/remove_node(node as var/obj/machinery/power/capacitor_bank/)
	if (node in nodes)
		nodes -= node
		capacity -= node.capacity
		if (node.is_mainframe())
			mainframes -= 1

		var/discharge = (min(capacity, charge))
		charge -= discharge
		if (!node.safe)
			node.damage(discharge)

		if(node == processor)
			node.is_processor = null

		for (var/i in node.neighbors)
			var/list/obj/machinery/power/capacitor_bank/neighbors = i
			i.neighbors -= node
			i.update_icon()

		if (node.neighbors.len > 1) //2 or more neighbors -> we might have split the network
			//PANIC
			var/list/datum/capacitor_network/networks = list()
			for (i in nodes)
				// Everyone's and orphan now, aka adding them in will recursively add everyone
				cap_network = null

			for (i in neighbors)
				i.cap_network = new cap_network()
				i.cap_network.add_node(i) //We've gone through all nodes adjacent to this neighbor, mapping a new network
				networks += i.cap_network

			for (i in networks) //Share our charge among however many networks there are now
				i.charge = charge * i.capacity / capacity //Everyone gets their fair share, no less


/datum/capacitor_network/proc/update_charge(var/added_charge = 0)
	charge = clamp(charge + added_charge, 0, capacity)

	if (charge > (capacity * safety))
		var/discharge = charge * rand(5,20)/100
		pick(nodes).damage(discharge)
		charge -= discharge




/obj/machinery/power/capacitor_bank
	name = "Capacitor bank"
	desc = "Entire stacks of capacitors to store power with."
	icon = "icons/obj/machines/capacitor_bank.dmi"
	icon_state = "capacitor_bank"

	var/datum/capacitor_network/cap_network
	var/capacity = 0
	var/safe = 0
	var/list/obj/machinery/power/capacitor_bank/neighbors
	var/processor = 0

/obj/machinery/power/capacitor_bank/proc/is_mainframe()
	return 0

/obj/machinery/power/capacitor_bank/proc/damage(var/energy)

/obj/machinery/power/capacitor_bank/proc/get_neighbors()

/obj/machinery/power/capacitor_bank/proc/can_process()
	return 0
