extends Node
## Mueve patrullas por carreteras, resuelve misiones y genera informes de radio.

var _clock_accum: float = 0.0
var _scene_timers: Dictionary = {}
## patrol_id -> {points: Array[Vector2], index: int}
var _paths: Dictionary = {}


func dispatch(mission_id: String, patrol_id: String) -> bool:
	if not GameState.active_missions.has(mission_id):
		return false
	if not GameState.patrols.has(patrol_id):
		return false
	var mission: Dictionary = GameState.active_missions[mission_id]
	var patrol: Dictionary = GameState.patrols[patrol_id]
	if mission["status"] != "open":
		return false
	if patrol["status"] != "available":
		return false

	var dest: Vector2 = RoadNav.nearest_road(mission["pos"])
	mission["pos"] = dest
	mission["status"] = "dispatched"
	mission["assigned_patrol"] = patrol_id
	mission["radio_log"].append("Despacho a %s" % patrol["callsign"])
	GameState.update_mission(mission)

	patrol["status"] = "en_route"
	patrol["mission_id"] = mission_id
	patrol["target"] = dest
	patrol["progress"] = 0.0
	patrol["report"] = ""
	patrol["pos"] = RoadNav.nearest_road(patrol["pos"])
	_paths[patrol_id] = {
		"points": RoadNav.find_path(patrol["pos"], dest),
		"index": 0,
	}
	GameState.set_patrol(patrol)

	RadioBus.announce_dispatch(patrol["callsign"], mission["title"], mission["district_name"])
	RadioBus.dispatch_started.emit(mission_id, patrol_id)
	return true


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum >= 4.0:
		_clock_accum = 0.0
		GameState.tick_minutes(1)

	for pid in GameState.patrols.keys():
		var patrol: Dictionary = GameState.patrols[pid]
		match str(patrol["status"]):
			"en_route":
				_follow_path(patrol, delta, "on_scene")
			"on_scene":
				_resolve_scene(patrol, delta)
			"returning":
				_ensure_return_path(patrol)
				_follow_path(patrol, delta, "available")


func _ensure_return_path(patrol: Dictionary) -> void:
	var pid: String = patrol["id"]
	if _paths.has(pid) and not _paths[pid]["points"].is_empty():
		return
	var hq := Vector2(float(GameState.station["hq_pos"][0]), float(GameState.station["hq_pos"][1]))
	hq = RoadNav.nearest_road(hq)
	patrol["target"] = hq
	patrol["pos"] = RoadNav.nearest_road(patrol["pos"])
	_paths[pid] = {
		"points": RoadNav.find_path(patrol["pos"], hq),
		"index": 0,
	}


func _follow_path(patrol: Dictionary, delta: float, next_status: String) -> void:
	var pid: String = patrol["id"]
	var speed: float = float(patrol.get("speed", 90.0)) * 1.15
	if not _paths.has(pid):
		_paths[pid] = {"points": [patrol.get("target", patrol["pos"])], "index": 0}

	var path: Dictionary = _paths[pid]
	var points: Array = path["points"]
	var idx: int = int(path["index"])
	if points.is_empty():
		patrol["status"] = next_status
		_on_arrive(patrol, next_status)
		GameState.set_patrol(patrol)
		return

	var target: Vector2 = points[mini(idx, points.size() - 1)]
	var pos: Vector2 = patrol["pos"]
	var dir := target - pos
	var dist := dir.length()
	var step := speed * delta

	if dist <= step + 1.5:
		patrol["pos"] = target
		path["index"] = idx + 1
		if path["index"] >= points.size():
			patrol["status"] = next_status
			_paths.erase(pid)
			_on_arrive(patrol, next_status)
		GameState.set_patrol(patrol)
		return

	patrol["pos"] = pos + dir.normalized() * step
	GameState.set_patrol(patrol)


func _on_arrive(patrol: Dictionary, next_status: String) -> void:
	if next_status == "on_scene":
		RadioBus.announce_on_scene(patrol["callsign"])
		_scene_timers[patrol["id"]] = 0.0
	elif next_status == "available":
		patrol["mission_id"] = ""
		patrol["target"] = Vector2.ZERO
		var hq := Vector2(float(GameState.station["hq_pos"][0]), float(GameState.station["hq_pos"][1]))
		patrol["pos"] = RoadNav.nearest_road(hq)


func _resolve_scene(patrol: Dictionary, delta: float) -> void:
	var pid: String = patrol["id"]
	_scene_timers[pid] = float(_scene_timers.get(pid, 0.0)) + delta
	var mission_id: String = patrol["mission_id"]
	if not GameState.active_missions.has(mission_id):
		patrol["status"] = "returning"
		GameState.set_patrol(patrol)
		return
	var mission: Dictionary = GameState.active_missions[mission_id]
	var need := clampf(float(mission.get("duration_sec", 90.0)) * 0.08, 4.0, 14.0)
	if mission["status"] != "resolving":
		mission["status"] = "resolving"
		GameState.update_mission(mission)
	if _scene_timers[pid] < need:
		return

	if patrol.get("_resolving_lock", false):
		return
	patrol["_resolving_lock"] = true

	var success := _roll_success(patrol, mission)
	var report := _make_report(success, mission)
	mission["status"] = "resolved" if success else "failed"
	mission["radio_log"].append(report)
	GameState.update_mission(mission)

	RadioBus.announce_resolve(patrol["callsign"], success, report)
	RadioBus.dispatch_resolved.emit(mission_id, success, report)

	if success:
		var bonus := 1
		if str(patrol.get("specialty", "")) == str(mission.get("category", "")):
			bonus = 2
		GameState.add_prestige(bonus + int(mission.get("xp", 50) / 100))

	patrol["status"] = "returning"
	patrol["report"] = report
	patrol.erase("_resolving_lock")
	_paths.erase(pid)
	GameState.set_patrol(patrol)
	_scene_timers.erase(pid)
	_clear_mission_later(mission_id)


func _clear_mission_later(mission_id: String) -> void:
	await get_tree().create_timer(2.2).timeout
	if GameState.active_missions.has(mission_id):
		GameState.remove_mission(mission_id)


func _roll_success(patrol: Dictionary, mission: Dictionary) -> bool:
	var base := 0.62
	match str(mission.get("severity", "medium")):
		"low":
			base = 0.8
		"medium":
			base = 0.68
		"high":
			base = 0.55
		"critical":
			base = 0.42
	if str(patrol.get("specialty", "")) == str(mission.get("category", "")):
		base += 0.18
	return GameState._rng.randf() <= clampf(base, 0.15, 0.95)


func _make_report(success: bool, mission: Dictionary) -> String:
	if success:
		return "Confirmado %s. Zona %s estable." % [mission["title"].to_lower(), mission["district_name"]]
	return "No se controló %s a tiempo. Quedan restos en %s." % [mission["title"].to_lower(), mission["district_name"]]
