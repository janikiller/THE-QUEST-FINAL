extends Node
## Mapa jugable a pantalla grande + pantallas de misión aparte.

@onready var city_map: Node2D = $World/CityMap
@onready var camera: Camera2D = $World/Camera2D
@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/PlayerAgent

const ZOOM_MIN := Vector2(0.85, 0.85)
const ZOOM_MAX := Vector2(1.8, 1.8)


func _ready() -> void:
	world.add_to_group("world_root")
	city_map.show_district_overlays = false
	city_map.mission_clicked.connect(_on_mission_clicked)
	camera.zoom = Vector2(1.25, 1.25)
	camera.position = player.global_position
	print("COMISARIA_READY missions=", GameState.active_missions.size(), " patrols=", GameState.patrols.size())
	if OS.get_environment("TQ_SMOKE") == "1":
		call_deferred("_smoke")
	if OS.get_environment("TQ_INV") == "1":
		call_deferred("_inv_check")
	if OS.get_environment("TQ_PLAYTEST") == "1":
		call_deferred("_playtest")


func _process(_delta: float) -> void:
	var on_map: bool = $UI/UIRouter/MapHud.visible
	if is_instance_valid(player):
		player.can_move = on_map
		if on_map:
			camera.global_position = camera.global_position.lerp(player.global_position, 0.15)


func _on_mission_clicked(mission_id: String) -> void:
	# ui_router abre la ficha al cambiar selección; evitamos doble select.
	$UI/UIRouter.show_mission(mission_id)


func _unhandled_input(event: InputEvent) -> void:
	if not $UI/UIRouter/MapHud.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom = (camera.zoom * 1.08).clamp(ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom = (camera.zoom / 1.08).clamp(ZOOM_MIN, ZOOM_MAX)


func _smoke() -> void:
	await get_tree().create_timer(1.2).timeout
	print("COMISARIA_SMOKE missions=", GameState.active_missions.size())
	if GameState.active_missions.is_empty() or GameState.available_patrols().is_empty():
		push_error("SMOKE_FAIL empty state")
		get_tree().quit(2)
		return
	var mid: String = String(GameState.active_missions.keys()[0])
	var pid: String = String(GameState.available_patrols()[0]["id"])
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	var ok: bool = dispatch.dispatch(mid, pid)
	print("COMISARIA_SMOKE dispatch=", ok)
	await get_tree().create_timer(1.5).timeout
	print("COMISARIA_SMOKE_OK")
	get_tree().quit(0 if ok else 5)


func _inv_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var errors: Array = []
	print("INV items=", ItemDB.items.size())
	if ItemDB.items.is_empty():
		errors.append("empty ItemDB")
	GameState.ensure_patrol_inventory("alpha")
	var before := GameState.get_slot_item("alpha", "shared", 0)
	GameState.swap_inventory_slots("alpha", "shared", 0, "trunk", 0)
	var after := GameState.get_slot_item("alpha", "trunk", 0)
	print("INV swap=", before, "->", after)
	if after != before:
		errors.append("swap failed")
	$UI/UIRouter.show_inventory("alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	var screen = $UI/UIRouter/InventoryScreen
	print("INV slots shared=", screen._shared_slots.size(), " trunk=", screen._trunk_slots.size(), " agents=", screen._agent_slots.size())
	if screen._shared_slots.size() != GameState.SHARED_SIZE:
		errors.append("shared size")
	if screen._trunk_slots.size() != GameState.TRUNK_SIZE:
		errors.append("trunk size")
	if errors.is_empty():
		print("OK_INVENTORY")
		get_tree().quit(0)
	else:
		print("INV_ERRORS ", errors)
		get_tree().quit(1)


func _playtest() -> void:
	## Prueba integral headless: spillover, misiones, despacho, inventario, sin crash.
	var errors: Array = []
	await get_tree().create_timer(0.6).timeout
	print("PLAYTEST start")

	# 1) No stack overflow al seleccionar misión
	await get_tree().create_timer(0.8).timeout
	if GameState.active_missions.is_empty():
		errors.append("no missions spawned")
	else:
		var mid0: String = String(GameState.active_missions.keys()[0])
		print("PLAYTEST open mission ", mid0)
		$UI/UIRouter.show_mission(mid0)
		await get_tree().process_frame
		await get_tree().process_frame
		if not $UI/UIRouter/MissionScreen.visible:
			errors.append("mission screen not visible")
		# Re-select same id must not recurse
		GameState.select_mission(mid0)
		GameState.select_mission(mid0)
		await get_tree().process_frame
		print("PLAYTEST selection ok (no overflow)")

	# 2) Volver al mapa
	$UI/UIRouter.show_map()
	await get_tree().process_frame
	if not $UI/UIRouter/MapHud.visible:
		errors.append("map hud not visible")

	# 3) Lista de misiones
	$UI/UIRouter.show_missions()
	await get_tree().process_frame
	if not $UI/UIRouter/MissionsMenu.visible:
		errors.append("missions menu not visible")
	$UI/UIRouter.show_map()

	# 4) Inventario + drag state
	$UI/UIRouter.show_inventory("alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	var inv = $UI/UIRouter/InventoryScreen
	if not inv.visible:
		errors.append("inventory not visible")
	var a := GameState.get_slot_item("alpha", "shared", 1)
	var b := GameState.get_slot_item("alpha", "agents/0/principal", 0)
	GameState.swap_inventory_slots("alpha", "shared", 1, "agents/0/principal", 0)
	var a2 := GameState.get_slot_item("alpha", "shared", 1)
	var b2 := GameState.get_slot_item("alpha", "agents/0/principal", 0)
	print("PLAYTEST equip swap ", a, "<->", b, " => ", a2, "/", b2)
	if b2 != a:
		errors.append("equip swap failed")
	inv.close()
	await get_tree().process_frame

	# 5) Despacho completo + path por carretera
	if not GameState.active_missions.is_empty() and not GameState.available_patrols().is_empty():
		var mid: String = ""
		for m in GameState.active_missions.values():
			if m.get("status", "") == "open":
				mid = str(m["id"])
				break
		var pid: String = String(GameState.available_patrols()[0]["id"])
		if mid != "":
			var dispatch = get_tree().get_first_node_in_group("dispatch")
			var start_pos: Vector2 = GameState.patrols[pid]["pos"]
			var ok: bool = dispatch.dispatch(mid, pid)
			print("PLAYTEST dispatch ", ok, " ", mid, "->", pid)
			if not ok:
				errors.append("dispatch failed")
			else:
				var path_pts: Array = dispatch._paths.get(pid, {}).get("points", [])
				print("PLAYTEST path points=", path_pts.size())
				if path_pts.size() < 2:
					errors.append("path too short")
				await get_tree().create_timer(1.2).timeout
				var st := str(GameState.patrols[pid].get("status", ""))
				var pos2: Vector2 = GameState.patrols[pid]["pos"]
				print("PLAYTEST patrol status ", st, " moved ", start_pos.distance_to(pos2))
				if st == "available":
					errors.append("patrol did not leave base")
				if start_pos.distance_to(pos2) < 5.0:
					errors.append("patrol barely moved")
				# Most of the path should stay near roads
				var off := 0
				for p in path_pts:
					if not RoadNav.is_road_world(p) and RoadNav.nearest_road(p).distance_to(p) > 24.0:
						off += 1
				print("PLAYTEST offroad waypoints=", off)
				if off > path_pts.size() / 3:
					errors.append("too many offroad waypoints")

	# 6) Movimiento jugador
	var p0: Vector2 = player.global_position
	player.can_move = true
	player.velocity = Vector2(200, 0)
	player.move_and_slide()
	player.global_position += Vector2(40, 0)
	if player.global_position.distance_to(p0) < 1.0:
		errors.append("player did not move")
	print("PLAYTEST player moved ", p0, "->", player.global_position)

	# 7) Mission markers exist and use new script
	var markers = get_tree().get_nodes_in_group("mission_marker")
	print("PLAYTEST markers group=", markers.size())

	# 8) Day/night + mission art
	print("PLAYTEST tod=", GameState.time_of_day())
	GameState.hour = 18
	GameState.emit_time()
	await get_tree().process_frame
	print("PLAYTEST tod dusk=", GameState.time_of_day())
	if GameState.time_of_day() != "dusk":
		errors.append("dusk tod failed")
	GameState.hour = 22
	GameState.emit_time()
	await get_tree().process_frame
	print("PLAYTEST tod night=", GameState.time_of_day())
	if GameState.time_of_day() != "night":
		errors.append("night tod failed")
	$UI/UIRouter.show_missions()
	await get_tree().process_frame
	await get_tree().process_frame
	if not $UI/UIRouter/MissionsMenu.visible:
		errors.append("missions menu not visible after redesign")
	var sample = GameState.active_missions.values()[0] if not GameState.active_missions.is_empty() else {}
	if not sample.is_empty():
		var artp := GameState.mission_art_path(sample)
		print("PLAYTEST art=", artp)
		if not ResourceLoader.exists(artp):
			errors.append("mission art missing")

	if errors.is_empty():
		print("PLAYTEST_OK")
		get_tree().quit(0)
	else:
		print("PLAYTEST_FAIL ", errors)
		get_tree().quit(1)
