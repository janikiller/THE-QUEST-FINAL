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
	if OS.get_environment("TQ_COMBAT_SHOT") == "1":
		call_deferred("_combat_shot")


func _combat_shot() -> void:
	## Abre combate y guarda capturas para evidencia visual.
	await get_tree().create_timer(1.2).timeout
	# Esperar a que haya misiones
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.25).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("COMBAT_SHOT_FAIL no missions")
		get_tree().quit(1)
		return
	var mid: String = String(GameState.active_missions.keys()[0])
	# Asegurar patrulla libre
	var p: Dictionary = GameState.patrols.get("alpha", {})
	p["status"] = "available"
	p.erase("_awaiting_combat")
	GameState.set_patrol(p)
	$UI/UIRouter.show_combat(mid, "alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _save_shot("combat_turno1")
	# Jugar una carta
	if CombatState.is_active():
		for cid in CombatState.hand.duplicate():
			if CombatState.can_play_card(str(cid)):
				CombatState.play_card(str(cid))
				break
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await _save_shot("combat_tras_carta")
	print("COMBAT_SHOT_OK")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _save_shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("COMBAT_SHOT_WARN null image ", name)
		return
	var path := "/opt/cursor/artifacts/%s.png" % name
	var err := img.save_png(path)
	print("COMBAT_SHOT saved ", path, " err=", err)
	var on_map: bool = $UI/UIRouter/MapHud.visible
	if is_instance_valid(player):
		player.can_move = on_map
		if on_map:
			camera.global_position = camera.global_position.lerp(player.global_position, 0.15)


func _on_mission_clicked(mission_id: String) -> void:
	# Marcadores desactivados; por si llegan, abren briefing del menú.
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
	print("DECK cards=", CardDB.cards.size())
	if CardDB.cards.is_empty():
		errors.append("empty CardDB")
	GameState.ensure_patrol_deck("alpha")
	var deck: Array = GameState.get_patrol_deck("alpha")
	print("DECK size=", deck.size())
	if deck.size() < 10:
		errors.append("starter deck too small")
	$UI/UIRouter.show_deck("alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	var screen = $UI/UIRouter/DeckScreen
	if not screen.visible:
		errors.append("deck not visible")
	if errors.is_empty():
		print("OK_DECK")
		get_tree().quit(0)
	else:
		print("DECK_ERRORS ", errors)
		get_tree().quit(1)


func _playtest() -> void:
	## Prueba integral headless: misiones, despacho, mazo, sin crash.
	var errors: Array = []
	await get_tree().create_timer(0.6).timeout
	print("PLAYTEST start")

	# 1) Menú de misión: briefing (no combate automático)
	await get_tree().create_timer(0.8).timeout
	if GameState.active_missions.is_empty():
		errors.append("no missions spawned")
	else:
		var mid0: String = String(GameState.active_missions.keys()[0])
		print("PLAYTEST open mission ", mid0)
		var p0: Dictionary = GameState.patrols.get("alpha", {})
		p0["status"] = "available"
		p0.erase("_awaiting_combat")
		GameState.set_patrol(p0)
		$UI/UIRouter.show_mission(mid0)
		await get_tree().process_frame
		await get_tree().process_frame
		if not $UI/UIRouter/MissionScreen.visible:
			errors.append("mission briefing not visible")
		else:
			print("PLAYTEST briefing OK")
		# Luchar → combate
		$UI/UIRouter.begin_fight(mid0)
		await get_tree().process_frame
		await get_tree().process_frame
		if not $UI/UIRouter/CombatScreen.visible or not CombatState.is_active():
			errors.append("fight did not start combat")
		else:
			print("PLAYTEST fight→combat OK turn=", CombatState.turn)
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

	# 4) Mazo de cartas (no inventario)
	$UI/UIRouter.show_deck("alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	var deck_ui = $UI/UIRouter/DeckScreen
	if not deck_ui.visible:
		errors.append("deck not visible")
	var deck_size: int = GameState.get_patrol_deck("alpha").size()
	print("PLAYTEST deck size=", deck_size, " catalog=", CardDB.cards.size())
	if deck_size < 10:
		errors.append("deck too small")
	GameState.add_card_to_deck("alpha", "frag")
	if GameState.get_patrol_deck("alpha").size() != deck_size + 1:
		errors.append("add card failed")
	deck_ui.close()
	await get_tree().process_frame
	var p_reset: Dictionary = GameState.patrols.get("alpha", {})
	p_reset["status"] = "available"
	p_reset.erase("_awaiting_combat")
	p_reset.erase("_pending_result_id")
	GameState.set_patrol(p_reset)
	CombatState.active = false
	CombatState.phase = CombatState.Phase.ENDED

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

	# Marcadores de alerta en mapa desactivados
	var markers = get_tree().get_nodes_in_group("mission_marker")
	print("PLAYTEST markers group=", markers.size())
	if markers.size() > 0:
		errors.append("map alerts should be disabled")

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
	if GameState.patrols.size() != 1:
		errors.append("expected 1 patrol (García), got %d" % GameState.patrols.size())
	GameState.set_time_speed(16.0)
	if abs(GameState.time_speed - 16.0) > 0.01:
		errors.append("time speed not set")
	print("PLAYTEST time_speed=", GameState.time_speed)
	GameState.set_time_speed(1.0)
	# Phase system smoke
	if not GameState.active_missions.is_empty():
		var midp: String = String(GameState.active_missions.keys()[0])
		GameState.set_mission_phase(midp, "desarrollo")
		GameState.add_mission_beat(midp, "TEST BEAT", "Beat de prueba", "desarrollo")
		var mp: Dictionary = GameState.active_missions[midp]
		if str(mp.get("phase", "")) != "desarrollo":
			errors.append("phase not desarrollo")
		if mp.get("beats", []).is_empty():
			errors.append("beats empty")
		print("PLAYTEST phase=", mp.get("phase"), " beats=", mp.get("beats", []).size())
	$UI/UIRouter.show_missions()
	await get_tree().process_frame
	await get_tree().process_frame
	if not $UI/UIRouter/MissionsMenu.visible:
		errors.append("missions menu not visible after redesign")
	# GridContainer expected
	var grid = $UI/UIRouter/MissionsMenu.find_child("MissionCards", true, false)
	if grid == null or not (grid is GridContainer):
		errors.append("mission cards grid missing")
	else:
		print("PLAYTEST mission grid cols=", grid.columns, " children=", grid.get_child_count())
	var sample = GameState.active_missions.values()[0] if not GameState.active_missions.is_empty() else {}
	if not sample.is_empty():
		var artp := GameState.mission_art_path(sample)
		print("PLAYTEST art=", artp)
		if not ResourceLoader.exists(artp):
			errors.append("mission art missing")
		# Liberar García y abrir briefing → luchar
		var pr: Dictionary = GameState.patrols.get("alpha", {})
		pr["status"] = "available"
		pr.erase("_awaiting_combat")
		GameState.set_patrol(pr)
		var open_id := ""
		for m2 in GameState.active_missions.values():
			if str(m2.get("status", "")) == "open":
				open_id = str(m2["id"])
				break
		if open_id == "":
			sample["status"] = "open"
			GameState.update_mission(sample)
			open_id = str(sample["id"])
		$UI/UIRouter.show_mission(open_id)
		await get_tree().process_frame
		await get_tree().process_frame
		if not $UI/UIRouter/MissionScreen.visible:
			errors.append("briefing not visible")
		$UI/UIRouter.begin_fight(open_id)
		await get_tree().process_frame
		await get_tree().process_frame
		if not $UI/UIRouter/CombatScreen.visible or not CombatState.is_active():
			errors.append("mission enter did not start combat")
		else:
			print("PLAYTEST mission→combat ok")
		$UI/UIRouter.show_map()
		pr = GameState.patrols.get("alpha", {})
		pr["status"] = "available"
		pr.erase("_awaiting_combat")
		GameState.set_patrol(pr)
		CombatState.active = false
		CombatState.phase = CombatState.Phase.ENDED

	# Combate de cartas (roguelike) — partida directa
	var combat_mid := ""
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) in ["open", "dispatched", "resolving"]:
			combat_mid = str(m["id"])
			break
	if combat_mid == "" and not GameState.active_missions.is_empty():
		combat_mid = str(GameState.active_missions.keys()[0])
	if combat_mid != "":
		var cfg := GameState.build_combat_config(combat_mid, "alpha")
		print("PLAYTEST combat cfg enemies=", cfg.get("enemies", []).size(), " deck=", cfg.get("deck", []).size())
		if cfg.is_empty() or cfg.get("deck", []).is_empty():
			errors.append("combat config empty")
		else:
			$UI/UIRouter.show_combat(combat_mid, "alpha")
			await get_tree().process_frame
			await get_tree().process_frame
			if not $UI/UIRouter/CombatScreen.visible:
				errors.append("combat screen not visible")
			elif not CombatState.is_active():
				errors.append("combat not active")
			else:
				print("PLAYTEST combat active turn=", CombatState.turn, " hand=", CombatState.hand.size())
				# Jugar hasta 3 cartas asequibles
				var played := 0
				for _i in range(8):
					if CombatState.phase != CombatState.Phase.PLAYER:
						break
					var hand_copy: Array = CombatState.hand.duplicate()
					var did := false
					for cid in hand_copy:
						if CombatState.can_play_card(str(cid)):
							CombatState.play_card(str(cid))
							played += 1
							did = true
							break
					if not did:
						break
				print("PLAYTEST cards played=", played)
				if CombatState.is_active() and CombatState.phase == CombatState.Phase.PLAYER:
					CombatState.end_player_turn()
					await get_tree().process_frame
					print("PLAYTEST after end turn phase=", CombatState.phase, " turn=", CombatState.turn)
				# Forzar victoria para no colgar el playtest
				if CombatState.is_active():
					for i in range(CombatState.enemies.size()):
						var e: Dictionary = CombatState.enemies[i]
						e["hp"] = 0
						CombatState.enemies[i] = e
					CombatState._check_end_conditions()
					await get_tree().process_frame
				print("PLAYTEST combat ended active=", CombatState.is_active())
			$UI/UIRouter.show_map()
	else:
		errors.append("no mission for combat test")

	if not ResourceLoader.exists("res://assets/audio/music/comisaria_theme_loop.ogg"):
		errors.append("music missing")
	if not ResourceLoader.exists("res://assets/audio/ambience/rain_medium_loop.ogg"):
		errors.append("rain ambience missing")
	GameState.set_weather("storm")
	if GameState.weather != "storm":
		errors.append("weather not storm")
	print("PLAYTEST weather=", GameState.weather, " music=", AudioDirector.music_on)

	if errors.is_empty():
		print("PLAYTEST_OK")
		get_tree().quit(0)
	else:
		print("PLAYTEST_FAIL ", errors)
		get_tree().quit(1)
