extends Node
## Estado global de la comisaría: tiempo, prestigio, misiones y patrullas.

signal time_changed(label: String)
signal prestige_changed(value: int)
signal mission_added(mission: Dictionary)
signal mission_updated(mission: Dictionary)
signal mission_removed(mission_id: String)
signal patrol_updated(patrol: Dictionary)
signal selection_changed(mission_id: String)
signal weather_changed(weather: String)
signal lightning_flash
signal time_speed_changed(speed: float)

var station: Dictionary = {}
var events_catalog: Array = []
var categories: Dictionary = {}

var hour: int = 21
var minute: int = 0
var prestige: int = 0
var selected_mission_id: String = ""
## Multiplicador de velocidad de partida (1, 4, 16, 60). Afecta el reloj del día/noche.
var time_speed: float = 1.0
## Clima actual: clear | drizzle | rain | storm
var weather: String = "clear"
var _last_resolved: Dictionary = {}
var _weather_check_minute: int = -1

## mission_id -> mission dict
var active_missions: Dictionary = {}
## patrol_id -> patrol runtime dict
var patrols: Dictionary = {}
## patrol_id -> inventory layout (legacy, unused)
var patrol_inventories: Dictionary = {}
## patrol_id -> Array of card ids (mazo)
var patrol_decks: Dictionary = {}

const SHARED_SIZE := 30
const TRUNK_SIZE := 20

var _mission_seq: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	_init_patrols()
	_init_decks()
	emit_time()
	prestige_changed.emit(prestige)
	# Arranque con algo de atmósfera
	if time_of_day() == "night":
		set_weather("rain")
	elif time_of_day() == "dusk":
		set_weather("drizzle")
	else:
		set_weather("clear")


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
			"map_icon": p.get("map_icon", p["portrait"]),
			"specialty": p.get("specialty", "general"),
			"speed": float(p.get("speed", 90.0)),
			"agents": p.get("agents", []),
			"agent_portraits": p.get("agent_portraits", []),
			"agent_stats": _stats_for_agents(p.get("agents", []), str(p.get("specialty", "general"))),
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


func _stats_for_agents(agents: Array, specialty: String) -> Array:
	var out: Array = []
	var base := {
		"fuerza": 0.55,
		"resistencia": 0.55,
		"destreza": 0.55,
		"investigacion": 0.55,
		"conduccion": 0.55,
	}
	match specialty:
		"trafico":
			base["conduccion"] = 0.82
			base["destreza"] = 0.62
		"organizado":
			base["fuerza"] = 0.78
			base["resistencia"] = 0.72
			base["investigacion"] = 0.48
		"delitos":
			base["investigacion"] = 0.75
			base["destreza"] = 0.65
	for i in range(agents.size()):
		var name := str(agents[i])
		var h := absi(hash(name))
		var s := base.duplicate()
		s["fuerza"] = clampf(float(s["fuerza"]) + float((h % 17) - 8) * 0.01, 0.25, 0.95)
		s["resistencia"] = clampf(float(s["resistencia"]) + float(((h >> 3) % 17) - 8) * 0.01, 0.25, 0.95)
		s["destreza"] = clampf(float(s["destreza"]) + float(((h >> 6) % 17) - 8) * 0.01, 0.25, 0.95)
		s["investigacion"] = clampf(float(s["investigacion"]) + float(((h >> 9) % 17) - 8) * 0.01, 0.25, 0.95)
		s["conduccion"] = clampf(float(s["conduccion"]) + float(((h >> 12) % 17) - 8) * 0.01, 0.25, 0.95)
		out.append(s)
	return out


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
	_maybe_update_weather()


func set_weather(w: String) -> void:
	if w == weather:
		return
	weather = w
	weather_changed.emit(weather)


func cycle_weather() -> void:
	match weather:
		"clear":
			set_weather("drizzle")
		"drizzle":
			set_weather("rain")
		"rain":
			set_weather("storm")
		"storm":
			set_weather("sandstorm")
		_:
			set_weather("clear")


func weather_label() -> String:
	match weather:
		"drizzle":
			return "LLOVIZNA"
		"rain":
			return "LLUVIA"
		"storm":
			return "TORMENTA"
		"sandstorm":
			return "ARENA"
		_:
			return "DESPEJADO"


func request_lightning_flash() -> void:
	lightning_flash.emit()


func _maybe_update_weather() -> void:
	# Reevaluar clima cada ~20 minutos de juego. Lluvia rara; arena ocasional.
	if minute == _weather_check_minute:
		return
	if minute % 20 != 0:
		return
	_weather_check_minute = minute
	var tod := time_of_day()
	var roll := _rng.randf()
	var next := "clear"
	if tod == "night":
		# Noche: casi siempre despejado; lluvia poco frecuente
		if roll < 0.04:
			next = "storm"
		elif roll < 0.10:
			next = "rain"
		elif roll < 0.18:
			next = "drizzle"
		elif roll < 0.22:
			next = "sandstorm"
	elif tod == "dusk":
		if roll < 0.06:
			next = "rain"
		elif roll < 0.14:
			next = "drizzle"
		elif roll < 0.22:
			next = "sandstorm"
	else:
		# Día: arena más probable que lluvia
		if roll < 0.04:
			next = "rain"
		elif roll < 0.10:
			next = "drizzle"
		elif roll < 0.20:
			next = "sandstorm"
	set_weather(next)


func set_time_speed(speed: float) -> void:
	time_speed = clampf(speed, 0.0, 120.0)
	time_speed_changed.emit(time_speed)


func cycle_time_speed() -> void:
	match int(round(time_speed)):
		1:
			set_time_speed(4.0)
		4:
			set_time_speed(16.0)
		16:
			set_time_speed(60.0)
		_:
			set_time_speed(1.0)


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
		## Arco narrativo: inicio → desarrollo → final
		"phase": "inicio",
		"phase_label": "INICIO",
		"beats": [],
		"outcome": "", # success | fail
		"outcome_report": "",
		"tactic": "",
		"assigned_patrol": "",
		"suspects": [],
		"created_at": "%02d:%02d" % [hour, minute],
		"blurb": _blurb_for(event, district),
		"radio_log": [],
	}
	_seed_inicio_beat(mission)
	active_missions[mid] = mission
	_attach_suspects(mid)
	mission_added.emit(mission)
	return mission


func _attach_suspects(mission_id: String) -> void:
	if not active_missions.has(mission_id):
		return
	var m: Dictionary = active_missions[mission_id]
	var count := 2
	if str(m.get("severity", "")) in ["high", "critical"]:
		count = 3
	m["suspects"] = CharacterDB.delinquent_thumbs_for_mission(mission_id, count)
	m["suspect_icon"] = CharacterDB.delinquent_icon_for_mission(mission_id)
	var loc: Dictionary = LocationDB.house_for_mission(mission_id)
	m["location_art"] = str(loc.get("path", ""))
	m["location_name"] = str(loc.get("name", "Inmueble"))
	active_missions[mission_id] = m


func _seed_inicio_beat(mission: Dictionary) -> void:
	mission["beats"] = [{
		"n": 1,
		"title": "AVISO INICIAL",
		"time": mission["created_at"],
		"caption": mission["blurb"],
		"kind": "inicio",
	}]


func set_mission_phase(mission_id: String, phase: String) -> void:
	if not active_missions.has(mission_id):
		return
	var m: Dictionary = active_missions[mission_id]
	m["phase"] = phase
	match phase:
		"inicio":
			m["phase_label"] = "INICIO"
		"desarrollo":
			m["phase_label"] = "DESARROLLO"
		"final":
			m["phase_label"] = "FINAL"
		_:
			m["phase_label"] = phase.to_upper()
	update_mission(m)


func add_mission_beat(mission_id: String, title: String, caption: String, kind: String = "desarrollo") -> void:
	if not active_missions.has(mission_id):
		return
	var m: Dictionary = active_missions[mission_id]
	var beats: Array = m.get("beats", [])
	beats.append({
		"n": beats.size() + 1,
		"title": title,
		"time": "%02d:%02d" % [hour, minute],
		"caption": caption,
		"kind": kind,
	})
	m["beats"] = beats
	update_mission(m)


func store_resolved_mission(mission: Dictionary) -> void:
	_last_resolved = mission.duplicate(true)


func last_resolved_mission() -> Dictionary:
	return _last_resolved.duplicate(true)


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
	var cards := "res://assets/missions/cards/"
	var generated := "res://assets/missions/generated/"
	if "atraco" in key or "tienda" in key or "banco" in key:
		return cards + "atraco_tienda.jpg"
	if "desfile" in key or "manifest" in key or "protesta" in key:
		return cards + "desfile.jpg"
	if "vivienda" in key or ("robo" in key and "vehic" not in key and "vehíc" not in key):
		return cards + "robo_vivienda.jpg"
	if "vehic" in key or "vehíc" in key:
		return cards + "robo_vehiculo.jpg"
	if "droga" in key or "narco" in key or "contraband" in key or "salud" in key:
		return cards + "trafico_drogas.jpg"
	if "agres" in key or "pelea" in key or "riña" in key or "rina" in key or "vandal" in key:
		return cards + "agresion_via.jpg"
	if "domesti" in key or "domésti" in key or "violencia" in key:
		return cards + "violencia_domestica.jpg"
	if "arma" in key or "posesi" in key:
		return cards + "posesion_armas.jpg"
	if "accidente" in key or "fuga" in key or "trafico" in key or "tráfico" in key:
		return cards + "accidente_fuga.jpg"
	if "busqued" in key or "búsqued" in key or "deten" in key or "secuestr" in key or "rehen" in key or "rehén" in key:
		return cards + "busqueda_detencion.jpg"
	if "medic" in key or "auxilio" in key or "ambulancia" in key or "herid" in key or "civil" in key:
		return generated + "mission_medico.png"
	if "inunda" in key or "riada" in key or "emergencia" in key:
		return generated + "mission_inundacion.png"
	if "organizado" in key:
		return cards + "trafico_drogas.jpg"
	if "especial" in key:
		return cards + "busqueda_detencion.jpg"
	if ResourceLoader.exists(cards + "atraco_tienda.jpg"):
		return cards + "atraco_tienda.jpg"
	return generated + "mission_pelea.png"


func _init_decks() -> void:
	patrol_decks.clear()
	for pid in patrols.keys():
		ensure_patrol_deck(str(pid))


func ensure_patrol_deck(patrol_id: String) -> void:
	if patrol_decks.has(patrol_id):
		return
	var deck: Array = []
	for cid in CardDB.starter_deck:
		deck.append(str(cid))
	# Especialidad: cartas extra
	var specialty := str(patrols.get(patrol_id, {}).get("specialty", "general"))
	match specialty:
		"organizado":
			deck.append("frag")
			deck.append("breach")
			deck.append("sticky")
		"trafico":
			deck.append("tear")
			deck.append("smoke")
		"delitos":
			deck.append("flash")
			deck.append("impact")
	patrol_decks[patrol_id] = deck


func get_patrol_deck(patrol_id: String) -> Array:
	ensure_patrol_deck(patrol_id)
	return patrol_decks.get(patrol_id, [])


## Config para CombatState a partir de misión + patrulla protagonista.
func build_combat_config(mission_id: String, patrol_id: String = "alpha") -> Dictionary:
	var mission: Dictionary = active_missions.get(mission_id, {})
	if mission.is_empty():
		var last := last_resolved_mission()
		if str(last.get("id", "")) == mission_id:
			mission = last
	if mission.is_empty():
		return {}

	var patrol: Dictionary = patrols.get(patrol_id, {})
	if patrol.is_empty() and not patrols.is_empty():
		patrol = patrols.values()[0]
		patrol_id = str(patrol.get("id", "alpha"))

	ensure_patrol_deck(patrol_id)
	var deck: Array = get_patrol_deck(patrol_id).duplicate()

	var hero_name := str(patrol.get("protagonist", "García"))
	var hero := CharacterDB.police_by_name(hero_name)
	var sprite := str(hero.get("full", patrol.get("portrait", "res://assets/character/police/police_00.png")))
	var portrait := str(hero.get("thumb", ""))

	var enemies: Array = []
	var suspects: Array = mission.get("suspects", [])
	if suspects.is_empty():
		suspects = CharacterDB.delinquent_thumbs_for_mission(mission_id, 3)
	var base_hp := 26
	match str(mission.get("severity", "medium")):
		"low":
			base_hp = 22
		"high":
			base_hp = 32
		"critical":
			base_hp = 38
	for i in range(mini(3, suspects.size())):
		var s: Dictionary = suspects[i]
		enemies.append({
			"id": str(s.get("id", "e%d" % i)),
			"name": str(s.get("alias", s.get("name", "Sospechoso"))),
			"hp": base_hp + i * 3,
			"portrait": str(s.get("thumb", "")),
			"sprite": str(s.get("full", "res://assets/character/delinquents/delinq_00.png")),
		})
	if enemies.is_empty():
		for i in range(3):
			enemies.append({
				"id": "e%d" % i,
				"name": "Sospechoso %d" % (i + 1),
				"hp": base_hp + i * 3,
				"sprite": "res://assets/character/delinquents/delinq_%02d.png" % i,
			})

	return {
		"mission_id": mission_id,
		"location": str(mission.get("title", mission.get("district_name", "Intervención"))),
		"objective": "Detener a los sospechosos",
		"hero_name": hero_name,
		"max_hp": int(patrol.get("max_hp", 50)),
		"energy_max": int(patrol.get("energy_max", 3)),
		"portrait": portrait,
		"sprite": sprite,
		"deck": deck,
		"enemies": enemies,
		"patrol_id": patrol_id,
	}


func add_card_to_deck(patrol_id: String, card_id: String) -> void:
	ensure_patrol_deck(patrol_id)
	if CardDB.get_card(card_id).is_empty():
		return
	var deck: Array = patrol_decks[patrol_id]
	deck.append(card_id)
	patrol_decks[patrol_id] = deck


func remove_card_from_deck(patrol_id: String, card_id: String) -> void:
	ensure_patrol_deck(patrol_id)
	var deck: Array = patrol_decks[patrol_id]
	var idx := deck.find(card_id)
	if idx >= 0:
		deck.remove_at(idx)
	patrol_decks[patrol_id] = deck


# --- Legacy inventory stubs (compat) ---
func ensure_patrol_inventory(_patrol_id: String) -> void:
	pass


func get_slot_item(_patrol_id: String, _path: String, _index: int) -> String:
	return ""


func set_slot_item(_patrol_id: String, _path: String, _index: int, _item_id: String) -> void:
	pass


func swap_inventory_slots(_patrol_id: String, _a: String, _b: int, _c: String, _d: int) -> void:
	pass


func clear_shared_inventory(_patrol_id: String) -> void:
	pass
