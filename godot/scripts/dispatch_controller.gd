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
	GameState.add_mission_beat(
		mission_id,
		"DESPLIEGUE",
		"%s en ruta hacia %s." % [patrol["callsign"], mission["district_name"]],
		"inicio"
	)
	GameState.set_mission_phase(mission_id, "inicio")
	# Guardar táctica si la pantalla de misión la dejó en el estado
	if mission.get("tactic", "") == "":
		mission["tactic"] = "cautious"
		GameState.update_mission(mission)
	return true


func _process(delta: float) -> void:
	# Velocidad de partida: a 1x ~1 min de juego cada 2.2 s reales.
	var speed: float = maxf(0.0, GameState.time_speed)
	if speed > 0.0:
		_clock_accum += delta * speed
		var step := 2.2
		while _clock_accum >= step:
			_clock_accum -= step
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
	var speed: float = float(patrol.get("speed", 90.0)) * 1.15 * maxf(1.0, GameState.time_speed)
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
		var mid: String = str(patrol.get("mission_id", ""))
		if mid != "":
			GameState.set_mission_phase(mid, "desarrollo")
			GameState.add_mission_beat(
				mid,
				"LLEGADA AL LUGAR",
				"%s en escena. Inicia desarrollo operativo." % patrol["callsign"],
				"desarrollo"
			)
			GameState.add_mission_beat(
				mid,
				"CONTACTO / EVALUACIÓN",
				"Unidad evalúa riesgos y aplica táctica: %s." % _tactic_label(mid),
				"desarrollo"
			)
			# Combate solo si el jugador eligió LUCHAR (flag _awaiting_combat).
			if bool(patrol.get("_awaiting_combat", false)):
				GameState.set_patrol(patrol)
				_start_combat_for(mid, str(patrol["id"]))
	elif next_status == "available":
		patrol["mission_id"] = ""
		patrol["target"] = Vector2.ZERO
		var hq := Vector2(float(GameState.station["hq_pos"][0]), float(GameState.station["hq_pos"][1]))
		patrol["pos"] = RoadNav.nearest_road(hq)


func _start_combat_for(mission_id: String, patrol_id: String) -> void:
	var router = get_tree().get_first_node_in_group("ui_router")
	if router == null:
		router = get_tree().root.find_child("UIRouter", true, false)
	if router and router.has_method("show_combat"):
		router.show_combat(mission_id, patrol_id)
	if not CombatState.combat_ended.is_connected(_on_combat_ended):
		CombatState.combat_ended.connect(_on_combat_ended)


func _on_combat_ended(victory: bool) -> void:
	var mid := CombatState.mission_id
	if mid == "" or not GameState.active_missions.has(mid):
		return
	var mission: Dictionary = GameState.active_missions[mid]
	var pid := str(mission.get("assigned_patrol", "alpha"))
	if not GameState.patrols.has(pid):
		return
	var patrol: Dictionary = GameState.patrols[pid]
	if not bool(patrol.get("_awaiting_combat", false)):
		return

	var report := _make_report(victory, mission)
	mission["status"] = "resolved" if victory else "failed"
	mission["outcome"] = "success" if victory else "fail"
	mission["outcome_report"] = report
	mission["radio_log"].append(report)
	GameState.update_mission(mission)
	GameState.set_mission_phase(mid, "final")
	GameState.add_mission_beat(
		mid,
		"CIERRE OPERATIVO" if victory else "UNIDAD CAÍDA",
		report,
		"final"
	)
	var snapshot: Dictionary = GameState.active_missions[mid].duplicate(true)
	GameState.store_resolved_mission(snapshot)

	RadioBus.announce_resolve(patrol["callsign"], victory, report)
	RadioBus.dispatch_resolved.emit(mid, victory, report)

	if victory:
		var bonus := 1
		if str(patrol.get("specialty", "")) == str(mission.get("category", "")):
			bonus = 2
		GameState.add_prestige(bonus + int(mission.get("xp", 50) / 100))

	GameState.advance_after_mission(mission)

	patrol["status"] = "returning"
	patrol["report"] = report
	patrol.erase("_awaiting_combat")
	patrol.erase("_resolving_lock")
	patrol["_pending_result_id"] = mid
	_paths.erase(pid)
	GameState.set_patrol(patrol)
	_scene_timers.erase(pid)
	# La UI de resultado se muestra al cerrar la pantalla de combate.


func show_pending_combat_result(patrol_id: String = "alpha") -> void:
	var patrol: Dictionary = GameState.patrols.get(patrol_id, {})
	var mid := str(patrol.get("_pending_result_id", CombatState.mission_id))
	if mid == "":
		return
	patrol.erase("_pending_result_id")
	GameState.set_patrol(patrol)
	_show_result_then_clear(mid)


func _tactic_label(mission_id: String) -> String:
	var m: Dictionary = GameState.active_missions.get(mission_id, {})
	match str(m.get("tactic", "cautious")):
		"entry":
			return "entrada inmediata"
		"negotiate":
			return "negociación"
		"block":
			return "bloqueo de fuga"
		_:
			return "acercamiento cauteloso"


func _resolve_scene(patrol: Dictionary, delta: float) -> void:
	# Combate de cartas sustituye el cierre aleatorio mientras espera intervención.
	if bool(patrol.get("_awaiting_combat", false)) or CombatState.is_active():
		return
	var pid: String = patrol["id"]
	_scene_timers[pid] = float(_scene_timers.get(pid, 0.0)) + delta * maxf(1.0, GameState.time_speed)
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
	mission["outcome"] = "success" if success else "fail"
	mission["outcome_report"] = report
	mission["radio_log"].append(report)
	GameState.update_mission(mission)
	GameState.set_mission_phase(mission_id, "final")
	GameState.add_mission_beat(
		mission_id,
		"CIERRE OPERATIVO" if success else "SOSPECHOSO ESCAPA",
		report,
		"final"
	)
	GameState.add_mission_beat(
		mission_id,
		"EVIDENCIA / BALANCE",
		"Zona %s. Prestigio actualizado. Informe archivado." % mission["district_name"],
		"final"
	)
	var snapshot: Dictionary = GameState.active_missions[mission_id].duplicate(true)
	GameState.store_resolved_mission(snapshot)

	RadioBus.announce_resolve(patrol["callsign"], success, report)
	RadioBus.dispatch_resolved.emit(mission_id, success, report)

	if success:
		var bonus := 1
		if str(patrol.get("specialty", "")) == str(mission.get("category", "")):
			bonus = 2
		GameState.add_prestige(bonus + int(mission.get("xp", 50) / 100))

	GameState.advance_after_mission(mission)

	patrol["status"] = "returning"
	patrol["report"] = report
	patrol.erase("_resolving_lock")
	_paths.erase(pid)
	GameState.set_patrol(patrol)
	_scene_timers.erase(pid)
	_show_result_then_clear(mission_id)


func _show_result_then_clear(mission_id: String) -> void:
	var router = get_tree().get_first_node_in_group("ui_router")
	if router == null:
		router = get_tree().root.find_child("UIRouter", true, false)
	if router and router.has_method("show_mission_result"):
		router.show_mission_result(mission_id)
	await get_tree().create_timer(0.4).timeout
	# La pantalla de resultado conserva el snapshot; quitamos del mapa activo
	await get_tree().create_timer(0.2).timeout
	if GameState.active_missions.has(mission_id):
		# No borrar aún si el resultado está abierto; se borra al cerrar resultado
		pass


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
