/datum/capacitor_network
	var/charge = 0         // How much power the net holds
	var/capacity = 0       // How much power the net can hold

	var/mainframes = 0     // Mainframes in the net. More mainframes = higher safety limit. 1 out of 10 is ideal
	var/safety_limit = 0.5 // How much power the net can hold before machinery starts failing (as percent of capacity, from 0.5 to 0.9)

	var/list/obj/machinery/power/capacitor_bank/nodes = list()

/datum/capacitor_network/proc/add_node(var/obj/machinery/power/capacitor_bank/node, var/recursive=0)

/datum/capacitor_network/proc/add_node_stats(var/obj/machinery/power/capacitor_bank/node)

/datum/capacitor_network/proc/remove_node(var/obj/machinery/power/capacitor_bank/node)

/datum/capacitor_network/proc/remove_node_stats(var/obj/machinery/power/capacitor_bank/node)

/datum/capacitor_network/proc/merge_network(var/datum/capacitor_network/network)

/datum/capacitor_network/proc/split_network()

/datum/capacitor_network/proc/update_charge(var/added_charge = 0)
	charge = Clamp(charge + added_charge, 0, capacity)

	if (charge > (capacity * safety_limit))
		var/obj/machinery/power/capacitor_bank/node = pick(nodes)
		node.damage(charge * rand(20,100)/100)

/datum/capacitor_network/proc/update_safety()
	safety_limit = 0.5
	if (nodes.len && mainframes)
		safety_limit += 0.4 * nodes.len / (10 * mainframes)
