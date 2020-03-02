/savedata/client/mob/proc/apply_blend_data(var/obj/O, var/list/blend_data)
	for(var/id in blend_data)
		var/list/blend_list = blend_data[id]
		var/desired_id = value_or_null(blend_list,"id")
		var/desired_icon = value_or_null(blend_list,"icon")
		var/desired_icon_state = value_or_null(blend_list,"icon_state")
		var/desired_color = value_or_null(blend_list,"color")
		var/desired_blend = value_or_null(blend_list,"blend")
		var/desired_type = value_or_null(blend_list,"type")
		O.add_blend(desired_id,desired_icon,desired_icon_state,desired_color,desired_blend,desired_type,1)

/savedata/client/mob/proc/get_proper_id_from_filepath(var/file_string)
	var/file_name = get_filename(file_string)
	return replacetext(replacetext(file_name,"character_",""),".json","")

/savedata/client/mob/proc/get_proper_id_from_filename(var/file_string)
	return replacetext(replacetext(file_string,"character_",""),".json","")

/savedata/client/mob/proc/load_most_recent_character()
	var/list/file_paths = get_files()

	var/best_date = 0
	var/best_time = 0
	var/list/best_data

	for(var/v in file_paths)
		v = get_proper_id_from_filename(v)
		var/list/new_loaded_data = load_json_data_from_id(v)
		if(!best_time || time_x_newer_than_y(new_loaded_data["last_saved_date"],new_loaded_data["last_saved_time"],best_date,best_time))
			best_time = new_loaded_data["last_saved_time"]
			best_date = new_loaded_data["last_saved_date"]
			best_data = new_loaded_data

	return best_data

/savedata/client/mob/proc/check_if_no_characters()
	if(has_files())
		return FALSE
	else
		return create_new_character("01")

/savedata/client/mob/proc/get_next_character_id()

	var/list/file_numbers = list()

	for(var/v in get_files())
		file_numbers += text2num(get_proper_id_from_filename(v))

	var/best_number = 0
	for(var/i=1,i<=99,i++)
		if(!(i in file_numbers))
			best_number = i
			break

	if(best_number == 0)
		return FALSE
	else if(best_number < 10)
		return "0[best_number]"
	else
		return "[best_number]"

/savedata/client/mob/proc/load_json_data_from_id(var/character_id)

	var/filename = get_file(character_id)
	var/data = file2text(filename)

	if(!data)
		LOG_ERROR("FATAL ERROR: NO DATA FOUND FOR [filename] for [bot_controlled ? "BOT" : owner.ckey].")
		return FALSE

	return json_decode(data)

/savedata/client/mob/proc/write_json_data_to_id(var/character_id,var/json_data)

	json_data["id"] = character_id
	json_data["last_saved_date"] = get_date()
	json_data["last_saved_time"] = get_time()
	var/desired_file = get_file(character_id)
	var/data = json_encode(json_data)
	if(data)
		fdel(desired_file)
	return text2file(data,desired_file)

/savedata/client/mob/proc/create_new_character(var/character_id)

	if(!owner)
		return FALSE

	if(text2num(character_id) > MAX_CHARACTERS)
		owner.mob.to_chat(span("warning","You exceed the maximum allocated characters! ([text2num(character_id)-1]/[MAX_CHARACTERS])"))
		return FALSE
	reset_data()
	owner.save_slot = character_id

	return TRUE

/savedata/client/mob/proc/save_current_character(var/save_inventory = TRUE)

	if(!owner)
		return FALSE
	if(!owner.save_slot)
		return
	if(!owner.mob)
		return FALSE
	if(!is_advanced(owner.mob))
		return FALSE

	var/mob/living/advanced/player/A = owner.mob

	//Basic Information
	loaded_data["name"] = A.real_name
	loaded_data["id"] = owner.save_slot
	loaded_data["currency"] = A.currency
	loaded_data["species"] = A.species
	loaded_data["gender"] = A.gender
	loaded_data["sex"] = A.sex

	var/final_organ_list = list()
	for(var/id in A.labeled_organs)
		var/obj/item/organ/O = A.labeled_organs[id]
		final_organ_list[id] = get_item_data(O,save_inventory)

	loaded_data["organs"] = final_organ_list

	//Skills
	var/list/final_skill_list = list()
	for(var/id in A.skills)
		var/experience/skill/S = A.skills[id]
		final_skill_list[id] = S.experience
	loaded_data["skills"] = final_skill_list

	//Attributes
	var/list/final_attribute_list = list()
	for(var/id in A.attributes)
		var/experience/attribute/B = A.attributes[id]
		final_attribute_list[id] = B.experience
	loaded_data["attributes"] = final_attribute_list

	if(write_json_data_to_id(owner.save_slot,loaded_data))
		owner.to_chat(span("notice","Sucessfully saved character [A.name]."))
	else
		owner.to_chat(span("warning","Save failed. Please contact the server owner."))

/savedata/client/mob/proc/apply_data_to_mob(var/mob/living/advanced/player/A,var/do_teleport = TRUE)

	//Name
	A.real_name = loaded_data["name"]
	A.sex = loaded_data["sex"]
	A.gender = loaded_data["gender"]
	A.currency = loaded_data["currency"]
	A.species = loaded_data["species"]

	//Organs
	for(var/id in loaded_data["organs"]) //This does not use load_and_create object as organs are special
		var/o_type = loaded_data["organs"][id]["type"]
		var/obj/item/organ/O = A.add_organ(o_type)
		if(loaded_data["organs"][id]["blend_data"])
			apply_blend_data(O, loaded_data["organs"][id]["blend_data"])
		if(loaded_data["organs"][id]["inventories"])
			for(var/i=1,i<=length(loaded_data["organs"][id]["inventories"]),i++)
				apply_inventory_data(O,loaded_data["organs"][id]["inventories"][i])
		O.update_icon()

	//Skills
	for(var/id in loaded_data["skills"])
		var/xp = loaded_data["skills"][id]
		var/experience/skill/S = A.get_skill(id)
		if(S)
			S.Initialize(xp)
		else
			LOG_ERROR("Warning! Skill of ID [id] is invalid!")

	//Attributes
	for(var/id in loaded_data["attributes"])
		var/xp = loaded_data["attributes"][id]
		var/experience/attribute/S = A.get_attribute(id)
		if(S)
			S.Initialize(xp)
		else
			LOG_ERROR("Warning! Skill of ID [id] is invalid!")

	if(do_teleport)
		var/obj/marker/dev/D = locate() in world
		if(D)
			A.force_move(get_turf(D))
		else
			var/obj/structure/interactive/bed/sleeper/C = length(cryo_spawnpoints) ? pick(cryo_spawnpoints) : pick(backup_spawnpoints)
			A.force_move(get_turf(C))
			C.buckle(A,silent=TRUE)

	A.update_icon()