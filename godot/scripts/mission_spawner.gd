extends Node
## Genera misiones en distritos del mapa real.

@export var city_map_path: NodePath
var city_map: Node2D

var _timer: float = 0.0
var _boot_spawned: bool = false


func _ready() -> void:
	city_map = get_node(city_map_path)
	_timer = 1.5


func _process(delta: float) -> void:
	_timer -= delta
	if not _boot_spawned:
		_boot_spawned = true
		_spawn_initial()
	if _timer <= 0.0:
		_timer = float(GameState.station.get("spawn_interval_sec", 16.0))
		_try_spawn()


func _spawn_initial() -> void:
	for i in 4:
		_try_spawn()


func _try_spawn() -> void:
	var max_active := int(GameState.station.get("max_active_missions", 8))
	var open_count := 0
	for m in GameState.active_missions.values():
		if m["status"] in ["open", "dispatched", "resolving"]:
			open_count += 1
	if open_count >= max_active:
		return

	var districts: Array = GameState.station.get("districts", [])
	if districts.is_empty():
		return
	var district: Dictionary = districts[GameState._rng.randi() % districts.size()]
	var event := _pick_event_for_district(district)
	if event.is_empty():
		return
	var pos: Vector2 = city_map.random_point_in_district(district)
	var mission := GameState.create_mission_from_event(event, district, pos)
	RadioBus.push("Nueva señal: %s en %s." % [str(mission.get("title", "misión")), str(district.get("name", "?"))], "alert")


func _pick_event_for_district(district: Dictionary) -> Dictionary:
	var preferred: Array = district.get("categories", [])
	var pool: Array = []
	for e in GameState.get_dispatchable_events():
		if preferred.is_empty() or str(e.get("category", "")) in preferred:
			pool.append(e)
	if pool.is_empty():
		pool = GameState.get_dispatchable_events()
	if pool.is_empty():
		return {}
	return pool[GameState._rng.randi() % pool.size()]
