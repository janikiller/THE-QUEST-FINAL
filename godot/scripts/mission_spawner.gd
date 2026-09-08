extends Node
## Genera misiones aleatorias en distritos del mapa.

@export var city_map_path: NodePath
var city_map: Node2D

var _timer: float = 0.0
var _boot_spawned: bool = false


func _ready() -> void:
	city_map = get_node(city_map_path)
	_timer = 2.0


func _process(delta: float) -> void:
	_timer -= delta
	if not _boot_spawned:
		_boot_spawned = true
		_spawn_initial()
	if _timer <= 0.0:
		_timer = float(GameState.station.get("spawn_interval_sec", 18.0))
		_try_spawn()


func _spawn_initial() -> void:
	for i in 3:
		_try_spawn()


func _try_spawn() -> void:
	var max_active := int(GameState.station.get("max_active_missions", 6))
	var open_count := 0
	for m in GameState.active_missions.values():
		if m["status"] in ["open", "dispatched", "resolving"]:
			open_count += 1
	if open_count >= max_active:
		return

	var events: Array = GameState.get_dispatchable_events()
	if events.is_empty():
		return
	var districts: Array = GameState.station.get("districts", [])
	if districts.is_empty():
		return

	var event: Dictionary = events[GameState._rng.randi() % events.size()]
	var district: Dictionary = districts[GameState._rng.randi() % districts.size()]
	var pos: Vector2 = city_map.random_point_in_district(district)
	var mission := GameState.create_mission_from_event(event, district, pos)
	RadioBus.push("Nueva señal: %s en %s." % [mission["title"], mission["district_name"]], "alert")
