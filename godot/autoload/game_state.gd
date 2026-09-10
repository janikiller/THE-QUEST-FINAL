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
signal period_changed(period: String)
signal day_changed(day: int)
signal boss_available(mission_id: String)
signal credits_changed(value: int)
signal xp_changed(xp: int, level: int, xp_to_next: int)
signal leveled_up(new_level: int)
signal level_pack_pending(count: int)

var station: Dictionary = {}
var events_catalog: Array = []
var categories: Dictionary = {}

var hour: int = 21
var minute: int = 0
var prestige: int = 0
## Créditos del mercado de cartas (se ganan con misiones).
var credits: int = 12
## Progresión de García: XP por enemigos derribados.
var hero_xp: int = 0
var hero_level: int = 1
## Cola de sobres pendientes (cada nivel = 1 sobre de 3 cartas).
var pending_level_packs: int = 0
var _active_pack_choices: Array[String] = []
var selected_mission_id: String = ""
## Día de campaña (1 = inicio). El boss aparece el día 2.
var day_index: int = 1
var boss_spawned: bool = false
var boss_defeated: bool = false
var boss_mission_id: String = ""
## IDs de bosses derrotados (progresión de 10 jefes).
var defeated_bosses: Array = []
var active_boss_id: String = ""
## Multiplicador de velocidad de partida (1, 4, 16, 60). Afecta el reloj del día/noche.
var time_speed: float = 1.0
## Clima actual: clear | drizzle | rain | storm
var weather: String = "clear"
var _last_resolved: Dictionary = {}
var _weather_check_minute: int = -1
var _last_period: String = ""
## Cuántas misiones cerradas en el periodo actual (meta: 3 → cambio).
var period_missions_done: int = 0
const PERIOD_MISSION_QUOTA := 3
## Minutos que avanza el reloj al cerrar una misión, por periodo.
const ADVANCE_DAY_MIN := 140 ## ~2h20 → 3 misiones llevan al atardecer
const ADVANCE_DUSK_MIN := 70 ## ~1h10 → 3 misiones llevan a la noche
const ADVANCE_NIGHT_MIN := 220 ## ~3h40 → 3 misiones llevan al día siguiente
const BOSS_DAY := 2

## mission_id -> mission dict
var active_missions: Dictionary = {}
## patrol_id -> patrol runtime dict
var patrols: Dictionary = {}
## patrol_id -> inventory layout (legacy, unused)
var patrol_inventories: Dictionary = {}
## patrol_id -> Array of card ids (mazo)
var patrol_decks: Dictionary = {}
var patrol_deck_gen: Dictionary = {}
const PATROL_DECK_GEN := 5

const SHARED_SIZE := 30
const TRUNK_SIZE := 20

var _mission_seq: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	_init_patrols()
	_init_decks()
	_last_period = time_of_day()
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
			"protagonist": str(p.get("protagonist", p.get("name", "Kick-Ass"))),
			"max_hp": int(p.get("max_hp", 50)),
			"energy_max": int(p.get("energy_max", 3)),
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


func set_clock(h: int, m: int = 0) -> void:
	var prev := time_of_day()
	hour = posmod(h, 24)
	minute = clampi(m, 0, 59)
	emit_time()
	_maybe_update_weather()
	var now := time_of_day()
	if now != prev:
		_on_period_transition(prev, now)


func time_of_day() -> String:
	## day 7-16, dusk 17-19, night 20-6
	if hour >= 7 and hour <= 16:
		return "day"
	if hour >= 17 and hour <= 19:
		return "dusk"
	return "night"


func tick_minutes(amount: int = 1) -> void:
	if amount <= 0:
		return
	var prev_period := time_of_day()
	minute += amount
	while minute >= 60:
		minute -= 60
		hour = (hour + 1) % 24
	emit_time()
	_maybe_update_weather()
	var now_period := time_of_day()
	if now_period != prev_period:
		_on_period_transition(prev_period, now_period)


func _on_period_transition(prev: String, now: String) -> void:
	_last_period = now
	period_missions_done = 0
	# Noche → día: nuevo día de campaña
	if prev == "night" and now == "day":
		day_index += 1
		day_changed.emit(day_index)
		RadioBus.push("Amanece el día %d en la ciudad." % day_index, "dispatch")
		if day_index >= BOSS_DAY:
			call_deferred("request_boss_spawn")
	period_changed.emit(now)


func add_credits(delta: int) -> void:
	credits = maxi(0, credits + delta)
	credits_changed.emit(credits)


func xp_to_next_level(level: int = -1) -> int:
	var lv := level if level > 0 else hero_level
	# Curva suave: Lv1→2 = 40, luego +22 por nivel.
	return 40 + (lv - 1) * 22


func add_combat_xp(amount: int, reason: String = "") -> Dictionary:
	## Otorga XP. Puede subir varios niveles y encolar sobres.
	var gained := maxi(0, amount)
	var levels_up := 0
	if gained <= 0:
		return {"xp": 0, "levels": 0}
	hero_xp += gained
	while hero_xp >= xp_to_next_level():
		hero_xp -= xp_to_next_level()
		hero_level += 1
		levels_up += 1
		pending_level_packs += 1
		leveled_up.emit(hero_level)
		RadioBus.push("¡Nivel %d! Abre un sobre de cartas." % hero_level, "resolve")
	xp_changed.emit(hero_xp, hero_level, xp_to_next_level())
	if levels_up > 0:
		level_pack_pending.emit(pending_level_packs)
	if reason != "":
		RadioBus.push("+%d XP (%s) · Nv.%d" % [gained, reason, hero_level], "resolve")
	return {"xp": gained, "levels": levels_up}


func has_pending_level_packs() -> bool:
	return pending_level_packs > 0 or not _active_pack_choices.is_empty()


func active_pack_open() -> bool:
	return not _active_pack_choices.is_empty()


func peek_pack_choices() -> Array[String]:
	return _active_pack_choices.duplicate()


func begin_level_pack() -> Array[String]:
	## Genera (o reutiliza) 3 cartas aleatorias del sobre actual.
	if not _active_pack_choices.is_empty():
		return _active_pack_choices.duplicate()
	if pending_level_packs <= 0:
		return []
	_active_pack_choices = _roll_pack_choices(3)
	return _active_pack_choices.duplicate()


func _roll_pack_choices(count: int) -> Array[String]:
	var pools := {
		"basica": [],
		"magica": [],
		"fuerza": [],
		"legendaria": [],
	}
	for c in CardDB.all_cards():
		var cid := str(c.get("id", ""))
		if cid == "":
			continue
		var rar := CardDB.normalize_rarity(str(c.get("rarity", "basica")))
		if pools.has(rar):
			pools[rar].append(cid)
	var odds := _pack_odds()
	var picked: Array[String] = []
	var guard := 0
	while picked.size() < count and guard < 80:
		guard += 1
		var rar := _pick_rarity(odds)
		var pool: Array = pools.get(rar, [])
		if pool.is_empty():
			continue
		var cid2 := str(pool[_rng.randi() % pool.size()])
		if cid2 in picked:
			continue
		picked.append(cid2)
	# Relleno si faltan
	if picked.size() < count:
		var all_ids: Array = []
		for c2 in CardDB.all_cards():
			all_ids.append(str(c2.get("id", "")))
		all_ids.shuffle()
		for cid3 in all_ids:
			if picked.size() >= count:
				break
			if cid3 != "" and cid3 not in picked:
				picked.append(str(cid3))
	return picked


func _pack_odds() -> Dictionary:
	## A más nivel, mejores rarezas. Legendarias tras boss o nivel alto.
	var lv := hero_level
	var legend := 0.0
	if boss_defeated or lv >= 6:
		legend = clampf(0.04 + float(lv - 5) * 0.015, 0.04, 0.12)
	var fuerza := clampf(0.12 + float(lv) * 0.02, 0.12, 0.32)
	var magica := clampf(0.28 + float(lv) * 0.01, 0.28, 0.36)
	var basica := maxf(0.15, 1.0 - (magica + fuerza + legend))
	return {"basica": basica, "magica": magica, "fuerza": fuerza, "legendaria": legend}


func _pick_rarity(odds: Dictionary) -> String:
	var roll := _rng.randf()
	var acc := 0.0
	for rar in ["basica", "magica", "fuerza", "legendaria"]:
		acc += float(odds.get(rar, 0.0))
		if roll <= acc:
			return rar
	return "basica"


func claim_level_pack_card(card_id: String, patrol_id: String = "alpha") -> bool:
	if card_id == "" or card_id not in _active_pack_choices:
		return false
	if CardDB.get_card(card_id).is_empty():
		return false
	add_card_to_deck(patrol_id, card_id)
	_active_pack_choices.clear()
	pending_level_packs = maxi(0, pending_level_packs - 1)
	var def := CardDB.get_card(card_id)
	RadioBus.push("Sobre Nv.%d: «%s» al mazo." % [hero_level, str(def.get("name", card_id))], "resolve")
	level_pack_pending.emit(pending_level_packs)
	return true


func spend_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true


func buy_card_for_patrol(patrol_id: String, card_id: String) -> bool:
	var price := CardDB.price_of(card_id)
	if CardDB.get_card(card_id).is_empty():
		return false
	if not spend_credits(price):
		return false
	add_card_to_deck(patrol_id, card_id)
	RadioBus.push("Mercado: adquirida «%s» (−%d ★)." % [str(CardDB.get_card(card_id).get("name", card_id)), price], "resolve")
	return true


func grant_boss_rewards(patrol_id: String = "alpha") -> Array:
	## Otorga 2 cartas legendarias al derrotar al boss activo.
	var pool: Array = CardDB.boss_rewards.duplicate()
	if pool.is_empty():
		for c in CardDB.all_cards():
			if CardDB.is_legendary(str(c.get("rarity", ""))):
				pool.append(str(c.get("id", "")))
	pool.shuffle()
	var gained: Array = []
	for i in mini(2, pool.size()):
		var cid := str(pool[i])
		add_card_to_deck(patrol_id, cid)
		gained.append(cid)
	add_credits(18)
	add_prestige(5)
	if active_boss_id != "" and active_boss_id not in defeated_bosses:
		defeated_bosses.append(active_boss_id)
	# Tras el primer boss: legendarias en mercado. La cacería de jefes sigue.
	boss_defeated = true
	boss_spawned = false
	boss_mission_id = ""
	var done_id := active_boss_id
	active_boss_id = ""
	RadioBus.push("Boss derrotado (%s). Jefes restantes: %d." % [
		done_id if done_id != "" else "?",
		maxi(0, CombatRoster.bosses.size() - defeated_bosses.size())
	], "resolve")
	# Preparar siguiente boss si el día lo permite
	call_deferred("request_boss_spawn")
	return gained


func request_boss_spawn() -> void:
	if boss_spawned:
		return
	if CombatRoster.next_boss(day_index, defeated_bosses).is_empty():
		return
	boss_available.emit("")


func create_boss_mission(district: Dictionary, map_pos: Vector2) -> Dictionary:
	## Uno de los 10 bosses anime, segúnado por día y progresión.
	if boss_spawned:
		return {}
	var boss_def: Dictionary = CombatRoster.next_boss(day_index, defeated_bosses)
	if boss_def.is_empty():
		return {}
	_mission_seq += 1
	var mid := "m_boss_%d" % _mission_seq
	var bname := str(boss_def.get("name", "BOSS"))
	var alias := str(boss_def.get("alias", bname))
	var arena: Dictionary = CombatRoster.pick_arena_for_mission({"id": mid, "period": time_of_day()}, boss_def)
	var mission := {
		"id": mid,
		"event_id": str(boss_def.get("id", "boss")),
		"title": bname,
		"category": "organizado",
		"severity": "critical",
		"period": time_of_day(),
		"is_boss": true,
		"boss_id": str(boss_def.get("id", "")),
		"arena_id": str(arena.get("id", "")),
		"arena_path": str(arena.get("path", "")),
		"district_id": district.get("id", "puerto"),
		"district_name": district.get("name", "Puerto"),
		"pos": map_pos,
		"file": "events/tiles/organizado/laboratorio_ilegal.png",
		"xp": 220,
		"duration_sec": 180.0,
		"status": "open",
		"phase": "inicio",
		"phase_label": "INICIO",
		"beats": [],
		"outcome": "",
		"outcome_report": "",
		"tactic": "",
		"assigned_patrol": "",
		"suspects": [],
		"created_at": "%02d:%02d" % [hour, minute],
		"blurb": "DÍA %d — ¡BOSS! %s en %s. Escenario: %s." % [
			day_index, alias, str(district.get("name", "la ciudad")), str(arena.get("name", "zona crítica"))
		],
		"radio_log": [],
	}
	_seed_inicio_beat(mission)
	# Boss + escoltas del catálogo anime
	var escorts: Array = CombatRoster.pick_enemies_for_mission(mid + ":escort", 2)
	var suspects: Array = []
	suspects.append({
		"id": str(boss_def.get("id", "boss")),
		"name": bname,
		"alias": alias,
		"full": str(boss_def.get("sprite", "")),
		"thumb": str(boss_def.get("portrait", "")),
		"is_boss": true,
		"pose_attack": str(boss_def.get("pose_attack", "")),
		"pose_hurt": str(boss_def.get("pose_hurt", "")),
		"hp_bonus": int(boss_def.get("hp", 100)),
		"damage": int(boss_def.get("damage", 14)),
	})
	for e in escorts:
		suspects.append({
			"id": str(e.get("id", "")),
			"name": str(e.get("name", "Escolta")),
			"alias": str(e.get("alias", e.get("name", "Escolta"))),
			"full": str(e.get("sprite", "")),
			"thumb": str(e.get("portrait", "")),
			"hp_bonus": int(e.get("hp", 26)),
		})
	mission["suspects"] = suspects
	mission["suspect_icon"] = str(boss_def.get("portrait", ""))
	var loc: Dictionary = LocationDB.house_for_mission(mid)
	mission["location_art"] = str(loc.get("path", ""))
	mission["location_name"] = str(arena.get("name", loc.get("name", "Zona del boss")))
	active_missions[mid] = mission
	boss_spawned = true
	boss_mission_id = mid
	active_boss_id = str(boss_def.get("id", ""))
	mission_added.emit(mission)
	boss_available.emit(mid)
	RadioBus.push("¡ALERTA DÍA %d! Boss en el mapa: %s." % [day_index, bname], "alert")
	return mission


func advance_after_mission(mission: Dictionary = {}) -> void:
	## Tras cerrar una misión: avanzan horas según el periodo (3 misiones ≈ cambio).
	var period := str(mission.get("period", time_of_day()))
	if period == "":
		period = time_of_day()
	var mins := ADVANCE_DAY_MIN
	match period:
		"dusk":
			mins = ADVANCE_DUSK_MIN
		"night":
			mins = ADVANCE_NIGHT_MIN
		_:
			mins = ADVANCE_DAY_MIN
	period_missions_done += 1
	var before := time_of_day()
	tick_minutes(mins)
	var after := time_of_day()
	var label := "%02d:%02d" % [hour, minute]
	if after != before:
		RadioBus.push("El reloj marca %s — %s." % [label, period_label(after)], "dispatch")
	else:
		RadioBus.push("Han pasado horas en la ciudad. Reloj: %s." % label, "info")


func period_label(period: String = "") -> String:
	var p := period if period != "" else time_of_day()
	match p:
		"day":
			return "DÍA"
		"dusk":
			return "ATARDECER"
		"night":
			return "NOCHE"
		_:
			return p.to_upper()


func period_categories(period: String = "") -> Array:
	## Categorías típicas de cada franja (noche = más peligrosa).
	var p := period if period != "" else time_of_day()
	match p:
		"day":
			return ["civiles", "trafico", "especiales", "delitos"]
		"dusk":
			return ["delitos", "trafico", "emergencias", "organizado"]
		"night":
			return ["organizado", "delitos", "emergencias"]
		_:
			return ["delitos", "civiles"]


func severity_for_period(base: String, period: String = "") -> String:
	var p := period if period != "" else time_of_day()
	var order := ["low", "medium", "high", "critical"]
	var idx := order.find(base)
	if idx < 0:
		idx = 1
	match p:
		"day":
			# Día más calmado: no subir por encima de medium salvo que ya sea high
			return order[mini(idx, 1)] if base != "high" else "medium"
		"dusk":
			return order[mini(idx + 1, 3)]
		"night":
			# Noche: siempre peligrosa
			return order[clampi(idx + 1, 2, 3)]
		_:
			return base


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
	var period := time_of_day()
	var severity := severity_for_period(str(event.get("severity", "medium")), period)
	var mission := {
		"id": mid,
		"event_id": event.get("id", ""),
		"title": event.get("name", "Incidente"),
		"category": event.get("category", "delitos"),
		"severity": severity,
		"period": period,
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
	# Noche: más sospechosos / más xp
	if period == "night":
		mission["xp"] = int(mission["xp"]) + 40
	elif period == "dusk":
		mission["xp"] = int(mission["xp"]) + 15
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
	var period := str(m.get("period", time_of_day()))
	if period == "day" and str(m.get("severity", "")) == "low":
		count = 1
	elif str(m.get("severity", "")) in ["high", "critical"] or period == "night":
		count = 3
	elif period == "dusk":
		count = 2
	# Catálogo anime (20+ enemigos distintos)
	var roster_foes: Array = CombatRoster.pick_enemies_for_mission(mission_id, count)
	var suspects: Array = []
	for e in roster_foes:
		suspects.append({
			"id": str(e.get("id", "")),
			"name": str(e.get("name", "Sospechoso")),
			"alias": str(e.get("alias", e.get("name", "Sospechoso"))),
			"full": str(e.get("sprite", "")),
			"thumb": str(e.get("portrait", "")),
			"pose_attack": str(e.get("pose_attack", "")),
			"pose_hurt": str(e.get("pose_hurt", "")),
			"hp_bonus": int(e.get("hp", 26)),
			"role": str(e.get("role", "ataque")),
			"card_pool": e.get("card_pool", []),
		})
	if suspects.is_empty():
		suspects = CharacterDB.delinquent_thumbs_for_mission(mission_id, count)
	m["suspects"] = suspects
	m["suspect_icon"] = str(suspects[0].get("thumb", "")) if not suspects.is_empty() else CharacterDB.delinquent_icon_for_mission(mission_id)
	var arena: Dictionary = CombatRoster.pick_arena_for_mission(m)
	if not arena.is_empty():
		m["arena_id"] = str(arena.get("id", ""))
		m["arena_path"] = str(arena.get("path", ""))
	var loc: Dictionary = LocationDB.house_for_mission(mission_id)
	m["location_art"] = str(loc.get("path", ""))
	m["location_name"] = str(arena.get("name", loc.get("name", "Inmueble")))
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
	## Regenera el mazo si cambia la generación (mejoras del mazo de García).
	if patrol_decks.has(patrol_id) and int(patrol_deck_gen.get(patrol_id, 0)) == PATROL_DECK_GEN:
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
		"general":
			# García U.P.R.: kit policial reforzado + firmas
			deck.append("placa_reforzada")
			deck.append("cacheo_duro")
			deck.append("veredicto")
			deck.append("fenix_azul")
	patrol_decks[patrol_id] = deck
	patrol_deck_gen[patrol_id] = PATROL_DECK_GEN


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

	var hero_name := str(patrol.get("protagonist", "Kick-Ass"))
	var hero := CharacterDB.police_by_name(hero_name)
	var sprite := CombatRoster.hero_pose("idle")
	var portrait := str(hero.get("thumb", ""))

	var enemies: Array = []
	var suspects: Array = mission.get("suspects", [])
	var period := str(mission.get("period", time_of_day()))
	var is_boss := bool(mission.get("is_boss", false))
	var want := 2
	if is_boss or period == "night" or str(mission.get("severity", "")) in ["high", "critical"]:
		want = 3
	elif period == "day" and str(mission.get("severity", "")) == "low":
		want = 1
	if suspects.size() < want:
		var fill: Array = CombatRoster.pick_enemies_for_mission(mission_id, want)
		for e in fill:
			suspects.append({
				"id": str(e.get("id", "")),
				"name": str(e.get("name", "Sospechoso")),
				"alias": str(e.get("alias", "")),
				"full": str(e.get("sprite", "")),
				"thumb": str(e.get("portrait", "")),
				"hp_bonus": int(e.get("hp", 26)),
			})
	var base_hp := 26
	match str(mission.get("severity", "medium")):
		"low":
			base_hp = 20
		"high":
			base_hp = 32
		"critical":
			base_hp = 40
	if period == "night":
		base_hp += 10
	elif period == "dusk":
		base_hp += 4
	for i in range(mini(want, maxi(1, suspects.size()))):
		var s: Dictionary = suspects[i]
		var e_is_boss := is_boss and (i == 0 or bool(s.get("is_boss", false)))
		var ehp := int(s.get("hp_bonus", 0))
		if e_is_boss:
			if ehp <= 0:
				ehp = base_hp + 40
		else:
			if ehp <= 0:
				ehp = base_hp + i * 3
			if period == "night":
				ehp += 14
			elif period == "dusk":
				ehp += 4
			else:
				ehp += i * 2
		var ename := str(s.get("name", s.get("alias", "Sospechoso")))
		var spr := str(s.get("full", ""))
		var thumb := str(s.get("thumb", ""))
		var pose_atk := str(s.get("pose_attack", ""))
		var pose_hurt := str(s.get("pose_hurt", ""))
		# Completar poses desde roster (street pack) si faltan
		var eid := str(s.get("id", ""))
		if eid != "" and (pose_atk == "" or pose_hurt == "" or spr == ""):
			var edef := CombatRoster.enemy_by_id(eid)
			if not edef.is_empty():
				if spr == "":
					spr = str(edef.get("sprite", spr))
				if pose_atk == "":
					pose_atk = str(edef.get("pose_attack", ""))
				if pose_hurt == "":
					pose_hurt = str(edef.get("pose_hurt", ""))
				if thumb == "":
					thumb = str(edef.get("portrait", thumb))
		if e_is_boss:
			# Completar poses desde roster si faltan
			var bid := str(mission.get("boss_id", s.get("id", "")))
			var bdef := CombatRoster.boss_by_id(bid)
			if not bdef.is_empty():
				ename = str(bdef.get("name", ename))
				spr = str(bdef.get("sprite", spr))
				pose_atk = str(bdef.get("pose_attack", pose_atk))
				pose_hurt = str(bdef.get("pose_hurt", pose_hurt))
				thumb = str(bdef.get("portrait", thumb))
				if int(s.get("hp_bonus", 0)) > 0:
					ehp = int(s.get("hp_bonus", ehp))
		if spr == "" or not (ResourceLoader.exists(spr) or FileAccess.file_exists(spr)):
			var fallback: Array = CombatRoster.pick_enemies_for_mission(mission_id + ":%d" % i, 1)
			if not fallback.is_empty():
				spr = str(fallback[0].get("sprite", ""))
				if pose_atk == "":
					pose_atk = str(fallback[0].get("pose_attack", ""))
				if pose_hurt == "":
					pose_hurt = str(fallback[0].get("pose_hurt", ""))
				if ename == "Sospechoso":
					ename = str(fallback[0].get("name", ename))
		enemies.append({
			"id": str(s.get("id", "e%d" % i)),
			"name": ename,
			"alias": str(s.get("alias", "")),
			"hp": ehp,
			"portrait": thumb,
			"sprite": spr,
			"pose_attack": pose_atk,
			"pose_hurt": pose_hurt,
			"is_boss": e_is_boss,
			"role": str(s.get("role", s.get("archetype", "ataque"))),
			"boss_id": str(s.get("boss_id", s.get("id", ""))),
			"card_pool": s.get("card_pool", []),
		})
	if enemies.is_empty():
		for e in CombatRoster.pick_enemies_for_mission(mission_id, want):
			enemies.append({
				"id": str(e.get("id", "")),
				"name": str(e.get("name", "Sospechoso")),
				"alias": str(e.get("alias", "")),
				"hp": int(e.get("hp", base_hp)),
				"sprite": str(e.get("sprite", "")),
				"role": str(e.get("role", "ataque")),
				"card_pool": e.get("card_pool", []),
			})

	var objective := "Detener a los sospechosos"
	if is_boss:
		objective = "BOSS: derrota a %s y su escolta" % str(enemies[0].get("name", "el jefe") if not enemies.is_empty() else "el jefe")
	else:
		match period:
			"day":
				objective = "Intervenir con control — turno de día"
			"dusk":
				objective = "Contener la amenaza al atardecer"
			"night":
				objective = "NOCHE: neutralizar amenaza de alto riesgo"

	var arena_path := str(mission.get("arena_path", ""))
	if arena_path == "":
		var arena: Dictionary = CombatRoster.pick_arena_for_mission(mission)
		arena_path = str(arena.get("path", ""))

	return {
		"mission_id": mission_id,
		"location": str(mission.get("title", mission.get("district_name", "Intervención"))),
		"objective": objective,
		"hero_name": hero_name,
		"max_hp": int(patrol.get("max_hp", 50)) + (14 if is_boss else 0),
		"energy_max": int(patrol.get("energy_max", 3)) + (1 if is_boss else 0),
		"portrait": portrait,
		"sprite": sprite,
		"deck": deck,
		"enemies": enemies,
		"patrol_id": patrol_id,
		"period": period,
		"is_boss": is_boss,
		"arena_path": arena_path,
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
