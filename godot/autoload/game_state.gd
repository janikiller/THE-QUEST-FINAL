extends Node
## Estado global de la comisaría: tiempo, prestigio, misiones y patrullas.

signal time_changed(label: String)
signal prestige_changed(value: int)
signal mission_added(mission: Dictionary)
signal mission_updated(mission: Dictionary)
signal mission_removed(mission_id: String)
signal patrol_updated(patrol: Dictionary)
signal selection_changed(mission_id: String)

var station: Dictionary = {}
var events_catalog: Array = []
var categories: Dictionary = {}

var hour: int = 21
var minute: int = 0
var prestige: int = 0
var selected_mission_id: String = ""

## mission_id -> mission dict
var active_missions: Dictionary = {}
## patrol_id -> patrol runtime dict
var patrols: Dictionary = {}
## patrol_id -> inventory layout (shared / trunk / agents)
var patrol_inventories: Dictionary = {}

const SHARED_SIZE := 30
const TRUNK_SIZE := 20

var _mission_seq: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	_init_patrols()
	_init_inventories()
	emit_time()
	prestige_changed.emit(prestige)


func _load_data() -> void:
	station = _read_json("res://data/station.json")
	var events_root: Dictionary = _read_json("res://data/events.json")
	events_catalog = events_root.get("events", [])
	var cats: Dictionary = _read_json("res://data/event_categories.json")
	# Support either {categories:[...]} or flat map
	if cats.has("categories"):
		for c in cats["categories"]:
			categories[str(c.get("id", ""))] = c
	else:
		categories = cats
	hour = int(station.get("start_hour", 21))
	minute = int(station.get("start_minute", 0))


func _init_patrols() -> void:
	patrols.clear()
	for p in station.get("patrols", []):
		var hq := Vector2(float(station["hq_pos"][0]), float(station["hq_pos"][1]))
		var runtime := {
			"id": p["id"],
			"callsign": p["callsign"],
			"name": p["name"],
			"portrait": p["portrait"],
			"specialty": p.get("specialty", "general"),
			"speed": float(p.get("speed", 90.0)),
			"agents": p.get("agents", []),
			"status": "available", # available | en_route | on_scene | returning
			"mission_id": "",
			"pos": hq,
			"target": Vector2.ZERO,
			"progress": 0.0,
			"report": "",
		}
		patrols[runtime["id"]] = runtime
	# Snap HQ patrols onto roads once RoadNav is ready (deferred)
	call_deferred("_snap_patrols_to_roads")


func _snap_patrols_to_roads() -> void:
	if not is_instance_valid(RoadNav):
		return
	for pid in patrols.keys():
		var p: Dictionary = patrols[pid]
		p["pos"] = RoadNav.nearest_road(p["pos"])
		patrols[pid] = p
		patrol_updated.emit(p)


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo leer %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func emit_time() -> void:
	time_changed.emit("%02d:%02d" % [hour, minute])


func time_of_day() -> String:
	## day 7-16, dusk 17-19, night 20-6
	if hour >= 7 and hour <= 16:
		return "day"
	if hour >= 17 and hour <= 19:
		return "dusk"
	return "night"


func tick_minutes(amount: int = 1) -> void:
	minute += amount
	while minute >= 60:
		minute -= 60
		hour = (hour + 1) % 24
	emit_time()


func add_prestige(delta: int) -> void:
	prestige = max(0, prestige + delta)
	prestige_changed.emit(prestige)


func select_mission(mission_id: String) -> void:
	if selected_mission_id == mission_id:
		return
	selected_mission_id = mission_id
	selection_changed.emit(mission_id)


func get_selected_mission() -> Dictionary:
	return active_missions.get(selected_mission_id, {})


func available_patrols() -> Array:
	var out: Array = []
	for p in patrols.values():
		if p["status"] == "available":
			out.append(p)
	return out


func get_dispatchable_events() -> Array:
	var out: Array = []
	for e in events_catalog:
		if e.get("weather", false):
			continue
		if e.get("dispatchable", true) == false:
			continue
		# Prefer non-clima for map incidents
		if str(e.get("category", "")) == "clima":
			continue
		out.append(e)
	return out


func create_mission_from_event(event: Dictionary, district: Dictionary, map_pos: Vector2) -> Dictionary:
	_mission_seq += 1
	var mid := "m_%d" % _mission_seq
	var severity := str(event.get("severity", "medium"))
	var mission := {
		"id": mid,
		"event_id": event.get("id", ""),
		"title": event.get("name", "Incidente"),
		"category": event.get("category", "delitos"),
		"severity": severity,
		"district_id": district.get("id", ""),
		"district_name": district.get("name", ""),
		"pos": map_pos,
		"file": event.get("file", ""),
		"xp": int(event.get("xp", 50)),
		"duration_sec": float(event.get("durationSec", 90)),
		"status": "open", # open | dispatched | resolving | resolved | failed
		"assigned_patrol": "",
		"created_at": "%02d:%02d" % [hour, minute],
		"blurb": _blurb_for(event, district),
		"radio_log": [],
	}
	active_missions[mid] = mission
	mission_added.emit(mission)
	return mission


func _blurb_for(event: Dictionary, district: Dictionary) -> String:
	var cat := str(event.get("category", ""))
	var name := str(event.get("name", "Incidente"))
	var zone := str(district.get("name", "la ciudad"))
	match cat:
		"delitos":
			return "Centralita: posible %s en %s. Solicitan unidad visible." % [name.to_lower(), zone]
		"emergencias":
			return "Emergencia en %s: %s. Coordinar y confirmar estado." % [zone, name.to_lower()]
		"trafico":
			return "Tráfico en %s — %s. Revisar y reportar por radio." % [zone, name.to_lower()]
		"civiles":
			return "Aviso civil en %s: %s. Abordaje con calma." % [zone, name.to_lower()]
		"organizado":
			return "Señal de actividad organizada en %s (%s). Discreción." % [zone, name.to_lower()]
		"especiales":
			return "Evento especial en %s: %s. Mantener presencia." % [zone, name.to_lower()]
		_:
			return "Incidente en %s: %s." % [zone, name]


func update_mission(mission: Dictionary) -> void:
	active_missions[mission["id"]] = mission
	mission_updated.emit(mission)


func remove_mission(mission_id: String) -> void:
	if active_missions.has(mission_id):
		active_missions.erase(mission_id)
		if selected_mission_id == mission_id:
			select_mission("")
		mission_removed.emit(mission_id)


func set_patrol(patrol: Dictionary) -> void:
	patrols[patrol["id"]] = patrol
	patrol_updated.emit(patrol)


func texture_path_for_event_file(file_path: String) -> String:
	var clean := file_path.replace("assets/", "")
	var generated := _generated_art_for(clean.to_lower())
	if generated != "" and ResourceLoader.exists(generated):
		return generated
	if clean.begins_with("events/"):
		var p := "res://assets/%s" % clean
		if ResourceLoader.exists(p):
			return p
	return "res://assets/missions/generated/mission_pelea.png"


func mission_art_path(mission: Dictionary) -> String:
	var key := "%s %s %s" % [
		str(mission.get("title", "")),
		str(mission.get("category", "")),
		str(mission.get("file", "")),
	]
	var path := _generated_art_for(key.to_lower())
	if ResourceLoader.exists(path):
		return path
	return texture_path_for_event_file(str(mission.get("file", "")))


func _generated_art_for(key: String) -> String:
	var base := "res://assets/missions/generated/"
	if "secuestr" in key or "rehen" in key or "rehén" in key:
		return base + "mission_secuestro.png"
	if "inunda" in key or "riada" in key:
		return base + "mission_inundacion.png"
	if "accidente" in key or "trafico" in key or "tráfico" in key or "vehiculo" in key or "vehículo" in key:
		return base + "mission_accidente.png"
	if "pelea" in key or "riña" in key or "rina" in key:
		return base + "mission_pelea.png"
	if "contraband" in key or "narco" in key:
		return base + "mission_contrabando.png"
	if "atraco" in key or "banco" in key or "tienda" in key or "robo" in key:
		return base + "mission_atraco.png"
	if "medic" in key or "auxilio" in key or "ambulancia" in key or "herid" in key:
		return base + "mission_medico.png"
	if "organizado" in key or "contraband" in key or "narco" in key:
		return base + "mission_contrabando.png"
	if "emergencia" in key or "inunda" in key:
		return base + "mission_inundacion.png"
	if "especial" in key or "secuestr" in key:
		return base + "mission_secuestro.png"
	if "civil" in key:
		return base + "mission_medico.png"
	return base + "mission_pelea.png"


func _init_inventories() -> void:
	patrol_inventories.clear()
	for pid in patrols.keys():
		ensure_patrol_inventory(str(pid))


func ensure_patrol_inventory(patrol_id: String) -> void:
	if patrol_inventories.has(patrol_id):
		return
	var p: Dictionary = patrols.get(patrol_id, {})
	var agent_count: int = max(1, p.get("agents", []).size())
	var agents: Array = []
	for i in range(agent_count):
		agents.append({
			"casco": "",
			"chaleco": "gear_2" if i == 0 else "gear_4",
			"principal": "pistol_1" if i == 0 else "pistol_3",
			"secundaria": "special_4" if i == 0 else "nonlethal_5",
			"cinturon": ["misc_2", "optic_6", "misc_1", "misc_7", ""],
			"bolsillos": ["misc_16", "misc_15", "", "", ""],
		})
	var shared: Array = _default_shared_for(str(p.get("specialty", "general")))
	while shared.size() < SHARED_SIZE:
		shared.append("")
	var trunk: Array = [
		"misc_5", "misc_8", "misc_10", "melee_5", "gear_5",
		"misc_4", "grenade_3", "misc_9", "", "",
		"", "", "", "", "",
		"", "", "", "", "",
	]
	while trunk.size() < TRUNK_SIZE:
		trunk.append("")
	patrol_inventories[patrol_id] = {
		"shared": shared,
		"trunk": trunk,
		"agents": agents,
	}


func _default_shared_for(specialty: String) -> Array:
	## Armas y equipo utilizable — sin munición.
	var base: Array = [
		"pistol_2", "pistol_4", "pistol_5", "pistol_6",
		"smg_1", "smg_2", "smg_3", "smg_4",
		"shotgun_1", "shotgun_2", "shotgun_3",
		"rifle_1", "rifle_2", "rifle_3", "rifle_4",
		"sniper_1", "sniper_2",
		"lmg_1", "special_1", "special_4",
		"nonlethal_1", "nonlethal_2", "melee_1", "melee_2",
		"grenade_1", "grenade_2", "misc_3", "misc_7",
		"optic_1", "gear_1",
	]
	match specialty:
		"organizado":
			base[0] = "rifle_4"
			base[1] = "smg_1"
			base[2] = "special_2"
			base[3] = "grenade_2"
		"trafico":
			base[0] = "pistol_1"
			base[1] = "nonlethal_1"
			base[2] = "misc_2"
			base[3] = "optic_6"
		"delitos":
			base[0] = "shotgun_3"
			base[1] = "misc_13"
			base[2] = "misc_11"
			base[3] = "grenade_3"
	return base


func get_slot_item(patrol_id: String, path: String, index: int) -> String:
	ensure_patrol_inventory(patrol_id)
	var inv: Dictionary = patrol_inventories[patrol_id]
	if path == "shared":
		var arr: Array = inv["shared"]
		return str(arr[index]) if index >= 0 and index < arr.size() else ""
	if path == "trunk":
		var arr2: Array = inv["trunk"]
		return str(arr2[index]) if index >= 0 and index < arr2.size() else ""
	if path.begins_with("agents/"):
		var parts := path.split("/")
		if parts.size() < 3:
			return ""
		var ai := int(parts[1])
		var kind := parts[2]
		var agents: Array = inv["agents"]
		if ai < 0 or ai >= agents.size():
			return ""
		var agent: Dictionary = agents[ai]
		if kind in ["cinturon", "bolsillos"]:
			var list: Array = agent.get(kind, [])
			return str(list[index]) if index >= 0 and index < list.size() else ""
		return str(agent.get(kind, ""))
	return ""


func set_slot_item(patrol_id: String, path: String, index: int, item_id: String) -> void:
	ensure_patrol_inventory(patrol_id)
	var inv: Dictionary = patrol_inventories[patrol_id]
	if path == "shared":
		var arr: Array = inv["shared"]
		if index >= 0 and index < arr.size():
			arr[index] = item_id
		return
	if path == "trunk":
		var arr2: Array = inv["trunk"]
		if index >= 0 and index < arr2.size():
			arr2[index] = item_id
		return
	if path.begins_with("agents/"):
		var parts := path.split("/")
		if parts.size() < 3:
			return
		var ai := int(parts[1])
		var kind := parts[2]
		var agents: Array = inv["agents"]
		if ai < 0 or ai >= agents.size():
			return
		var agent: Dictionary = agents[ai]
		if kind in ["cinturon", "bolsillos"]:
			var list: Array = agent.get(kind, [])
			while list.size() <= index:
				list.append("")
			list[index] = item_id
			agent[kind] = list
		else:
			agent[kind] = item_id
		agents[ai] = agent


func swap_inventory_slots(patrol_id: String, from_path: String, from_index: int, to_path: String, to_index: int) -> void:
	var a := get_slot_item(patrol_id, from_path, from_index)
	var b := get_slot_item(patrol_id, to_path, to_index)
	set_slot_item(patrol_id, from_path, from_index, b)
	set_slot_item(patrol_id, to_path, to_index, a)


func clear_shared_inventory(patrol_id: String) -> void:
	ensure_patrol_inventory(patrol_id)
	var inv: Dictionary = patrol_inventories[patrol_id]
	var shared: Array = []
	for i in range(SHARED_SIZE):
		shared.append("")
	inv["shared"] = shared
