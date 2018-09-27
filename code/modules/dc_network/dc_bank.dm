//"The energy liberated by one gram of TNT was arbitrarily defined as a matter of convention to be 4184 J, which is exactly one kilocalorie." -Wikipedia
#define TNTENERGY 4.18e6 //1 Kg TNT = 4.18 MJ,

/////////////////////////////////////////////
// Capacitor banks
/*
 * A modular SMES system for engineers to play with
 * Machines inheriting from here can be connected together into a single network. For fluff and theme, this got named the capacitor network, storing power as DC
 * Going by Skowron's suggestion, I should get it renamed to VRLA network or something, and fluff it as VRLA batteries instead, which are an actual thing rather
 * than using capacitors for storage. Rhaplanca will be happy about that too.
 * Adding banks increases the network's capacity, while converters exchange the capacitor network's charge with the power network's power.
 * Not all capacity is usable however: Past a certain charge the network will suffer damage and machines may lose  capacity, or outright explode.
 * Mainframes raise how close you can get to maximum capacity, creating a weakpoint for traitors to exploit and for general "catastrophic failure" fun.
 *
 * They're pretty much useless as of right now. Plan is to have complex machinery feed from these networks and give an use to all the extra power engineers
 * can produce, but ends up going to waste. Ideas so far:
 *
 *  - Bluespace energy transfer: Imagine an oversized telepad to buy and sell power with. When buying, you get random bursts of beams adding up to the energy bought
 *  - Huge emitter: Both for the supermatter engine and for the "sell power" portion of the bluespace energy transfer idea. Other ideas:
 *    - "Mining laser for away missions" -Skowron
 *  - Large Hadron Collider: "So we can have a singularity engine 2.0 featuring naked singularities. No wait, what if we could use a naked singularity to
 *     compress plasma and get something insane. Can you imagine plasma that is infinitely dense?" --jknpjr on the ivory tower discord
 *  - Plasma Supercooler: "I dont have an issue with 0k plasma, I just think we should have a machine that pushes to it, instead of something lazy like foam.
 *     Wheres that super emitter guy, this is where you could shine." --Anonymous No.228877687 on /vg/ss13g
 *
 * TODO: Re-theme as VRLA Battery banks instead
 */
/obj/machinery/capacitor_bank
	name = "capacitor bank"
	desc = "Entire stacks of capacitors to store power with. You're not entirely sure capacitors work that way"

	//Icons
	icon = 'icons/obj/machines/dc_network.dmi'
	icon_state = "capacitor_bank"
	icon_state_open = "capacitor_bank_open"
	var/icon_state_broken = "capacitor_bank_broken"
	var/icon_state_openb = "capacitor_bank_openb"
	var/icon_state_off = "capacitor_bank"
	var/icon_state_on = "capacitor_bank_on"

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


/obj/machinery/capacitor_bank/New()
	..()
	RefreshParts()
	anchored = 1
	state = 1
	update_icon()

/obj/machinery/capacitor_bank/Destroy()
	if(mDC_node)
		qdel(mDC_node)
	..()


//-- DC network overrides --

/obj/machinery/capacitor_bank/DC_available_dirs()
	return cardinal


//-- Interaction Overrides --

/obj/machinery/capacitor_bank/attackby(var/obj/O, var/mob/user)
	if (istype(O, /obj/item/stack/cable_coil) && !mDC_node && state)
		var/obj/item/stack/cable_coil/CC = O
		if (CC.amount < 1)
			to_chat(user, "<span class=\"warning\">You need 1 length cable coil to wire the [src].</span>") //Should never happen, but who knows
			return

		mDC_node = new /datum/DC_node(src)
		RefreshParts()
		mDC_node.connect()

		CC.use(1)
		to_chat(user, "<span class='notice'>You wire \the [src].</span>")
		update_icon()
		return

	if (istype(O, /obj/item/weapon/wirecutters) && mDC_node)
		if(do_after(user, src, 30))

			qdel(mDC_node)

			getFromPool(/obj/item/stack/cable_coil, get_turf(src), 1)
			to_chat(user, "<span class='notice'>You cut \the [src]'s wires.</span>")
			update_icon()
		return
	..()

/obj/machinery/capacitor_bank/wrenchable()
	if(mDC_node) //Must not be wired
		return 0
	else
		return ..()


//-- Machinery Overrides --

/obj/machinery/capacitor_bank/RefreshParts()
	if(mDC_node)
		mDC_node.actual_capacity = 0
		for(var/obj/item/weapon/stock_parts/capacitor/C in component_parts)
			mDC_node.actual_capacity += C.maximum_charge
		mDC_node.update_capacity()


//-- Damage --
//TODO: Damage
/obj/machinery/capacitor_bank/DC_damage(energy)
	update_overlay()
	return


/obj/machinery/capacitor_bank/proc/explode(var/energy=0)
	return


/obj/machinery/capacitor_bank/ex_act(severity)
	switch(severity)
		if(1.0)
			if (prob(25))
				explode(mDC_node.capacity)
			qdel(src)
			return

		if(2.0)
			if (prob(50))
				qdel(src)
			else
				DC_damage(mDC_node.capacity * (rand(3,10)/10))
			return

		if(3.0)
			if (prob(10))
				qdel(src)
			else
				DC_damage(mDC_node.capacity * (rand(0,3)/10))
			return
	return


/obj/machinery/capacitor_bank/emp_act(severity)
	var/node_charge = mDC_node.network.charge * mDC_node.capacity / mDC_node.network.capacity
	DC_damage(node_charge * (rand(1,3)/4))
	..()


//-- Icon --
/obj/machinery/capacitor_bank/proc/update_overlay()
	overlays.len = 0
	if (mDC_node)
		if(mDC_node.capacity_loss > 1)
			overlays += image('icons/obj/machines/dc_network.dmi', "capacitor_bank-ow")


//-- Icon overides --

/obj/machinery/capacitor_bank/examine(mob/user)
	..()
	if (mDC_node)
		to_chat(user, "<span class='notice'>The [src] is wired up and fixed in place.</span>")
	else if(state)
		to_chat(user, "<span class='notice'>The [src] is anchored to the ground, but could use some wiring.</span>")

/obj/machinery/capacitor_bank/update_icon()
	underlays.len = 0
	update_overlay()
	if(mDC_node)
		for (var/i in mDC_node.connected_dirs)
			underlays += DC_wire_underlays[i]

	if(panel_open)
		if (stat & BROKEN)
			icon_state = icon_state_openb
		else
			icon_state = icon_state_open
	else if (stat & BROKEN)
		icon_state = icon_state_broken
	else if (mDC_node)
		icon_state = icon_state_on
	else
		icon_state = icon_state_off

/*
/////////////////////////////////////////////
// NNUI
/*
 *  Machines inheriting from this will have a NanoUI
 */

/obj/machinery/power/capacitor_bank/nnui/
	var/ui_tmpl = "" //The .tmpl file used for the UI
	var/ui_name = "The Capacitor Unit" // The name that'll appear on the UI


/obj/machinery/power/capacitor_bank/nnui/proc/get_ui_data()
	var/data[0]
	return data

//--Overrides

/obj/machinery/power/capacitor_bank/nnui/attack_ai(mob/user)
	src.add_hiddenprint(user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/power/capacitor_bank/nnui/attack_hand(mob/user)
	add_fingerprint(user)
	ui_interact(user)


/obj/machinery/power/capacitor_bank/nnui/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open=NANOUI_FOCUS)

	if(stat & BROKEN || use_power == 0)
		return

	// This is the data which will be sent to the ui
	var/list/data = get_ui_data()

	// Update the ui if it exists, returns null if no ui is passed/found
	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// The ui does not exist, so we'll create a new() one
        // For a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, ui_tmpl, ui_name, 540, 380)
		// When the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// Open the new ui window
		ui.open()
		// Auto update every Master Controller tick
		ui.set_auto_update(1)


/obj/machinery/power/capacitor_bank/nnui/Topic(href, href_list)
	if(..())
		return 1
	if(href_list["close"])
		if(usr.machine == src)
			usr.unset_machine()
		return 1
	if (!isAdminGhost(usr) && (usr.stat || usr.restrained()))
		return
	if (!(istype(usr, /mob/living/carbon/human) || ticker) && ticker.mode.name != "monkey")
		if(!istype(usr, /mob/living/silicon/ai) && !isAdminGhost(usr))
			to_chat(usr, "<span class='warning'>You don't have the dexterity to do this!</span>")
			return
	if (!isturf(src.loc) && !istype(usr, /mob/living/silicon/) && !isAdminGhost(usr))
		return 0 // Do not update ui
*/