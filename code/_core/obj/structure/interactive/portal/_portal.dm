/obj/structure/interactive/portal
	name = "strange portal"
	id = null
	desc = "What is inside?"
	icon = 'icons/obj/effects/effects.dmi'
	icon_state = "anom"

/obj/structure/interactive/portal/Crossed(var/atom/movable/O)

	if(!id)
		return ..()

	for(var/obj/structure/interactive/portal/P in world)
		if(P == src)
			continue
		if(P.id == src.id)
			var/turf/T = get_step(P,O.move_dir)
			O.force_move(T)
			O.move_delay = 10
			if(is_living(O))
				var/mob/living/L = O
				L.add_paralyze(10)
			break

	return ..()


/obj/structure/interactive/portal/clown
	id = "clown"