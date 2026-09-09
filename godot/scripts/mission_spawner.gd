extends Node
## Genera exactamente 3 misiones por franja (día / atardecer / noche).

@export var city_map_path: NodePath
var city_map: Node2D

var _timer: float = 0.0
var _boot_spawned: bool = false
var _period: String = ""


func _ready() -> void:
	city_map = get_node(city_map_path)
	_timer = 1.2
	_period = GameState.time_of_day()
	if not GameState.period_changed.is_connected(_on_period_changed):
		GameState.period_changed.connect(_on_period_changed)
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)
	if not GameState.boss_available.is_connected(_on_boss_available):
		GameState.boss_available.connect(_on_boss_available)


func _process(delta: float) -> void:
	_timer -= delta
	if not _boot_spawned:
		_boot_spawned = true
		_ensure_period_missions(true)
		if GameState.day_index >= GameState.BOSS_DAY and not GameState.boss_spawned:
			_spawn_boss_if_needed()
	if _timer <= 0.0:
		_timer = float(GameState.station.get("spawn_interval_sec", 20.0))
		_ensure_period_missions(false)


func _on_day_changed(day: int) -> void:
	if day >= GameState.BOSS_DAY:
		_spawn_boss_if_needed()


func _on_boss_available(_mid: String) -> void:
	_spawn_boss_if_needed()


func _spawn_boss_if_needed() -> void:
	if GameState.boss_spawned or GameState.boss_defeated:
		return
	if GameState.day_index < GameState.BOSS_DAY:
		return
	if city_map == null:
		return
	var districts: Array = GameState.station.get("districts", [])
	var district: Dictionary = {}
	for d in districts:
		if str(d.get("id", "")) == "puerto":
			district = d
			break
	if district.is_empty() and not districts.is_empty():
		district = districts[0]
	if district.is_empty():
		return
	var pos: Vector2 = city_map.random_point_in_district(district)
	GameState.create_boss_mission(district, pos)


func _on_period_changed(period: String) -> void:
	_period = period
	_purge_other_period_missions(period)
	_ensure_period_missions(true)
	RadioBus.push(
		"Nueva franja: %s. %d señales en el mapa." % [
			GameState.period_label(period),
			GameState.PERIOD_MISSION_QUOTA
		],
		"alert"
	)


func _purge_other_period_missions(keep_period: String) -> void:
	var to_remove: Array = []
	for mid in GameState.active_missions.keys():
		var m: Dictionary = GameState.active_missions[mid]
		var st := str(m.get("status", ""))
		# Dejar terminar las que ya están en curso
		if st in ["dispatched", "resolving", "resolved", "failed"]:
			continue
		if st != "open":
			continue
		# El boss permanece en el mapa hasta derrotarlo.
		if bool(m.get("is_boss", false)):
			continue
		if str(m.get("period", "")) != keep_period:
			to_remove.append(mid)
	for mid in to_remove:
		GameState.remove_mission(str(mid))


func _count_open_for_period(period: String) -> int:
	var n := 0
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) not in ["open", "dispatched", "resolving"]:
			continue
		# Boss no cuenta para la cuota de 3 señales de la franja.
		if bool(m.get("is_boss", false)):
			continue
		if str(m.get("period", period)) == period:
			n += 1
	return n


func _ensure_period_missions(force_fill: bool) -> void:
	var period := GameState.time_of_day()
	_period = period
	var quota := int(GameState.station.get("max_active_missions", GameState.PERIOD_MISSION_QUOTA))
	quota = mini(quota, GameState.PERIOD_MISSION_QUOTA)
	var open_count := _count_open_for_period(period)
	if open_count >= quota and not force_fill:
		return
	var need := quota - open_count
	if need <= 0:
		return
	for i in need:
		if not _try_spawn_for_period(period):
			break
	_spawn_boss_if_needed()


func _try_spawn_for_period(period: String) -> bool:
	var districts: Array = GameState.station.get("districts", [])
	if districts.is_empty() or city_map == null:
		return false
	var district: Dictionary = districts[GameState._rng.randi() % districts.size()]
	var event := _pick_event_for_period(district, period)
	if event.is_empty():
		return false
	var pos: Vector2 = city_map.random_point_in_district(district)
	var mission := GameState.create_mission_from_event(event, district, pos)
	# create_mission ya marca period actual; forzar por si acaso
	mission["period"] = period
	GameState.update_mission(mission)
	var tag := GameState.period_label(period)
	RadioBus.push(
		"Nueva señal (%s): %s en %s." % [tag, str(mission.get("title", "misión")), str(district.get("name", "?"))],
		"alert"
	)
	return true


func _pick_event_for_period(district: Dictionary, period: String) -> Dictionary:
	var preferred_period: Array = GameState.period_categories(period)
	var preferred_district: Array = district.get("categories", [])
	var pool: Array = []
	var fallback: Array = []
	for e in GameState.get_dispatchable_events():
		var cat := str(e.get("category", ""))
		if cat not in preferred_period:
			continue
		fallback.append(e)
		if preferred_district.is_empty() or cat in preferred_district:
			pool.append(e)
	if pool.is_empty():
		pool = fallback
	if pool.is_empty():
		pool = GameState.get_dispatchable_events()
	if pool.is_empty():
		return {}
	# Noche: sesgar a severidad alta si el evento la trae
	if period == "night":
		var heavy: Array = []
		for e in pool:
			if str(e.get("severity", "")) in ["high", "critical", "medium"]:
				heavy.append(e)
		if not heavy.is_empty():
			pool = heavy
	return pool[GameState._rng.randi() % pool.size()]
