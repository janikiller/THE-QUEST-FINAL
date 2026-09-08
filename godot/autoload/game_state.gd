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

var _mission_seq: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	_init_patrols()
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
			"pos": Vector2(float(station["hq_pos"][0]), float(station["hq_pos"][1])),
			"target": Vector2.ZERO,
			"progress": 0.0,
			"report": "",
		}
		patrols[runtime["id"]] = runtime


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
	# events.json uses "events/tiles/..."
	var clean := file_path.replace("assets/", "")
	if clean.begins_with("events/"):
		return "res://assets/%s" % clean
	return "res://assets/events/tiles/delitos/pelea_en_la_calle.png"
