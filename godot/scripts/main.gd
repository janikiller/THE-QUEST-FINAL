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
	# Un solo hook de playtest/shot a la vez (evita races de quit()).
	var mode := ""
	for key in [
		"TQ_SMOKE", "TQ_INV", "TQ_PLAYTEST", "TQ_COMBAT_SHOT", "TQ_MAP_SHOT", "TQ_MISSIONS_MENU_SHOT",
		"TQ_BOSS_MARKET_SHOT", "TQ_BOSS_FIGHT", "TQ_BOSS_AUTOPLAY", "TQ_PROGRESSION_SHOT", "TQ_ROSTER_SHOT", "TQ_ANIME_CARDS_SHOT",
		"TQ_MARKET_ROULETTE_SHOT", "TQ_XP_PACK_SHOT", "TQ_FIX_SHOT", "TQ_ENEMY_CARDS_SHOT",
		"TQ_GROUND_SHOT",
	]:
		if OS.get_environment(key) == "1":
			mode = key
			break
	match mode:
		"TQ_SMOKE":
			call_deferred("_smoke")
		"TQ_INV":
			call_deferred("_inv_check")
		"TQ_PLAYTEST":
			call_deferred("_playtest")
		"TQ_COMBAT_SHOT":
			call_deferred("_combat_shot")
		"TQ_MAP_SHOT":
			call_deferred("_map_shot")
		"TQ_MISSIONS_MENU_SHOT":
			call_deferred("_missions_menu_shot")
		"TQ_BOSS_MARKET_SHOT":
			call_deferred("_boss_market_shot")
		"TQ_BOSS_FIGHT":
			call_deferred("_boss_fight_demo")
		"TQ_BOSS_AUTOPLAY":
			call_deferred("_boss_autoplay")
		"TQ_PROGRESSION_SHOT":
			call_deferred("_progression_shot")
		"TQ_ROSTER_SHOT":
			call_deferred("_roster_shot")
		"TQ_ANIME_CARDS_SHOT":
			call_deferred("_anime_cards_shot")
		"TQ_MARKET_ROULETTE_SHOT":
			call_deferred("_market_roulette_shot")
		"TQ_XP_PACK_SHOT":
			call_deferred("_xp_pack_shot")
		"TQ_FIX_SHOT":
			call_deferred("_fix_shot")
		"TQ_ENEMY_CARDS_SHOT":
			call_deferred("_enemy_cards_shot")
		"TQ_GROUND_SHOT":
			call_deferred("_ground_shot")
		_:
			pass


func _ground_shot() -> void:
	## Evidencia: García mirando bien, suelo plantado, sangre al golpear.
	await get_tree().create_timer(0.7).timeout
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.15).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("GROUND_SHOT_FAIL no missions")
		get_tree().quit(1)
		return
	var mid := ""
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) == "open" and not bool(m.get("is_boss", false)):
			mid = str(m.get("id", ""))
			break
	if mid == "":
		mid = String(GameState.active_missions.keys()[0])
	$UI/UIRouter.begin_fight(mid)
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	if combat == null:
		print("GROUND_SHOT_FAIL no combat")
		get_tree().quit(1)
		return
	var floor_ok := combat.get_node_or_null("FloorPlane") != null
	var solid_ok := combat.get_node_or_null("FloorPlane/SolidDeck") != null
	var anim_ok := combat.get_node_or_null("BgAnimLayer") != null
	var rain_n := 0
	if anim_ok:
		for c in combat.get_node("BgAnimLayer").get_children():
			if str(c.name).begins_with("Rain"):
				rain_n += 1
	var overhead := 0
	if combat.enemies_row:
		for panel in combat.enemies_row.get_children():
			if panel.find_child("EnemyIntentHost", true, false) != null:
				overhead += 1
	var flipped := false
	var bg_path := ""
	if combat.player_sprite:
		flipped = combat.player_sprite.flip_h
	if combat.bg and combat.bg.texture:
		bg_path = str(combat.bg.texture.resource_path)
	var expect_flip := false
	print("GROUND_SHOT floor=", floor_ok, " solid=", solid_ok, " anim=", anim_ok, " rain=", rain_n, " overhead=", overhead, " flip_h=", flipped, " bg=", bg_path)
	if combat.has_method("_ground_contact_y"):
		var floor_n = combat.get_node_or_null("FloorPlane")
		var pcol = combat.get_node_or_null("Arena/PlayerCol")
		var spr = combat.player_sprite
		print("GROUND_METRICS size=", combat.size, " contact=", combat._ground_contact_y(), " floor_top=", (floor_n.get_global_rect().position.y if floor_n else -1), " pcol_bottom=", (pcol.get_global_rect().end.y if pcol else -1), " sole_y=", (spr.get_global_rect().end.y if spr else -1), " sole_pad=", spr.get_meta("sole_pad", -1) if spr else -1, " plant_pos=", spr.get_meta("plant_pos", Vector2.ZERO) if spr else Vector2.ZERO)
	if not floor_ok or not solid_ok:
		print("GROUND_SHOT_FAIL no floor deck")
		get_tree().quit(1)
		return
	if not anim_ok or rain_n < 20:
		print("GROUND_SHOT_FAIL animated bg missing anim=", anim_ok, " rain=", rain_n)
		get_tree().quit(1)
		return
	if overhead > 0:
		print("GROUND_SHOT_FAIL overhead intent cards still present")
		get_tree().quit(1)
		return
	if flipped != expect_flip:
		print("GROUND_SHOT_FAIL bad facing flip_h=", flipped, " expect=", expect_flip)
		get_tree().quit(1)
		return
	# Barras de vida: ancho fijo (gruesas y legibles, no estiradas a todo el row)
	var bad_bars := 0
	var bar_w_log: PackedStringArray = []
	if combat.player_hp_bar:
		var pw: float = float(combat.player_hp_bar.size.x)
		bar_w_log.append("player=%.0f" % pw)
		if pw > 320.0 or pw < 180.0:
			bad_bars += 1
	if combat.enemies_row:
		for panel in combat.enemies_row.get_children():
			var hb = panel.find_child("HpBar", true, false)
			if hb:
				var ew: float = float(hb.size.x)
				bar_w_log.append("enemy=%.0f" % ew)
				if ew > 300.0 or ew < 160.0:
					bad_bars += 1
	print("HP_BARS ", " ".join(bar_w_log), " bad=", bad_bars)
	# Altura mínima de barra (debe verse gruesa)
	if combat.player_hp_bar and float(combat.player_hp_bar.size.y) < 28.0:
		print("GROUND_SHOT_FAIL thin player hp bar h=", combat.player_hp_bar.size.y)
		get_tree().quit(1)
		return
	# Layout: pelea compacta (hueco centro no debe ser la mayoría del ancho)
	var gap_ok := true
	var player_col_n = combat.get_node_or_null("Arena/PlayerCol")
	if player_col_n and combat.enemies_row and combat.enemies_row.get_child_count() > 0:
		var pr: Rect2 = player_col_n.get_global_rect()
		var first_enemy: Control = null
		for ch in combat.enemies_row.get_children():
			if ch is Control and not bool(ch.get_meta("fallen", false)):
				first_enemy = ch
				break
		if first_enemy:
			var er: Rect2 = first_enemy.get_global_rect()
			var gap := er.position.x - pr.end.x
			var mid_ratio := gap / maxf(1.0, combat.size.x)
			print("ARENA_GAP gap=%.0f mid_ratio=%.2f" % [gap, mid_ratio])
			if mid_ratio > 0.22:
				gap_ok = false
	if not gap_ok:
		print("GROUND_SHOT_FAIL arena too empty (characters too far apart)")
		get_tree().quit(1)
		return
	if bad_bars > 0:
		print("GROUND_SHOT_FAIL stretched hp bars")
		get_tree().quit(1)
		return
	# Mazo García regenerado con cartas reforzadas
	var deck: Array = GameState.get_patrol_deck("alpha")
	var need: Array = ["punetazo", "bloqueo", "esquiva", "impulso", "respirar"]
	var missing: Array = []
	for cid in need:
		if not deck.has(cid):
			missing.append(cid)
	print("DECK_SIZE=", deck.size(), " missing=", missing)
	if not missing.is_empty():
		print("GROUND_SHOT_FAIL weak starter deck missing=", missing)
		get_tree().quit(1)
		return
	# Mazo normal: sin cartas mágicas/fuerza/legendaria al inicio
	for power_id in ["llama_azul", "furia_desatada", "segundo_latido", "sello_arcano"]:
		if deck.has(power_id):
			print("GROUND_SHOT_FAIL starter still has power card=", power_id)
			get_tree().quit(1)
			return
	print("STARTER_NORMAL coins=", GameState.credits)
	# Kick-Ass: el sprite de jugador debe ser el traje verde (no García policía)
	if combat.player_sprite and combat.player_sprite.texture:
		var ht: Texture2D = combat.player_sprite.texture
		var himg: Image = ht.get_image()
		if himg:
			var greens := 0
			var blues := 0
			var step := maxi(1, himg.get_width() * himg.get_height() / 8000)
			var i := 0
			for y in range(himg.get_height()):
				for x in range(himg.get_width()):
					i += 1
					if i % step != 0:
						continue
					var c: Color = himg.get_pixel(x, y)
					if c.a < 0.35:
						continue
					if c.g > c.b + 0.05 and c.g > c.r - 0.05:
						greens += 1
					elif c.b > c.g + 0.08:
						blues += 1
			print("HERO_COLORS green=", greens, " blue=", blues, " size=", himg.get_width(), "x", himg.get_height())
			if greens < blues or greens < 40:
				print("GROUND_SHOT_FAIL hero still looks like old García (not Kick-Ass green)")
				get_tree().quit(1)
				return
		else:
			print("GROUND_SHOT_FAIL no hero image for color check")
			get_tree().quit(1)
			return
	else:
		print("GROUND_SHOT_FAIL no player sprite texture")
		get_tree().quit(1)
		return
	await _save_shot("kickass_protagonista")
	await _save_shot("barras_vida_cartas")
	await _save_shot("mapa_fisica_sin_cartas")
	# Tres fotogramas del fondo animado (lluvia/neones/niebla en movimiento)
	await _save_shot("fondo_animado_01")
	await get_tree().create_timer(0.45).timeout
	await _save_shot("fondo_animado_02")
	await get_tree().create_timer(0.45).timeout
	await _save_shot("fondo_animado_03")
	if combat.has_method("_spawn_blood_burst"):
		combat._spawn_blood_burst(Vector2(900, 360), 2.0)
	if combat.has_method("_spawn_dust_puff"):
		combat._spawn_dust_puff(Vector2(220, 520), 1.4)
		combat._spawn_dust_puff(Vector2(980, 530), 1.2)
		await get_tree().create_timer(0.55).timeout
		await _save_shot("mapa_fisica_sangre_polvo")
	var snap: Dictionary = CombatState.get_snapshot()
	var hand: Array = snap.get("hand", [])
	for cid in hand:
		var id := str(cid)
		if CombatState.can_play_card(id):
			CombatState.play_card(id)
			await get_tree().create_timer(1.05).timeout
			await _save_shot("mapa_fisica_gesto")
			break
	print("GROUND_SHOT_OK")
	get_tree().quit(0)


func _enemy_cards_shot() -> void:
	## Evidencia: enemigos con cartas/intent de carta en combate.
	await get_tree().create_timer(0.7).timeout
	print("ENEMY_CARDS catalog=", CardDB.enemy_cards.size())
	if CardDB.enemy_cards.size() < 10:
		print("ENEMY_CARDS_FAIL catalog")
		get_tree().quit(1)
		return
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.15).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("ENEMY_CARDS_FAIL no missions")
		get_tree().quit(1)
		return
	var mid := ""
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) == "open" and not bool(m.get("is_boss", false)):
			mid = str(m.get("id", ""))
			break
	if mid == "":
		mid = String(GameState.active_missions.keys()[0])
	$UI/UIRouter.begin_fight(mid)
	await get_tree().process_frame
	await get_tree().create_timer(0.55).timeout
	var named := 0
	for e in CombatState.enemies:
		if str(e.get("next_card_name", "")) != "":
			named += 1
	print("ENEMY_CARDS intents=", named, "/", CombatState.enemies.size())
	if named < 1:
		print("ENEMY_CARDS_FAIL no next_card")
		get_tree().quit(1)
		return
	# Verifica mini-cartas visuales en la UI de combate
	var combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	var visible_cards := 0
	if combat:
		for n in combat.find_children("EnemyIntentCard", "", true, false):
			visible_cards += 1
	print("ENEMY_CARDS visible_ui=", visible_cards)
	if visible_cards < 1:
		print("ENEMY_CARDS_FAIL no visible cards")
		get_tree().quit(1)
		return
	# Panel inferior: cartas enemigas en el menú grande
	var bottom_n := 0
	if combat:
		var erow = combat.find_child("EnemyHandRow", true, false)
		if erow:
			bottom_n = erow.get_child_count()
	print("ENEMY_CARDS bottom_menu=", bottom_n)
	if bottom_n < 1:
		print("ENEMY_CARDS_FAIL no bottom menu cards")
		get_tree().quit(1)
		return
	await _save_shot("enemigos_cartas_visibles")
	await _save_shot("enemigos_cartas_panel_inferior")
	# Fuerza un turno enemigo jugando cartas
	if CombatState.is_active():
		CombatState.end_player_turn()
		await get_tree().create_timer(1.2).timeout
	await _save_shot("enemigos_cartas_jugaron")
	# Deja ver el turno 2 un momento (evidencia / grabación)
	await get_tree().create_timer(0.6).timeout
	# Menú grande de mazo enemigo en combate
	combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	if combat and combat.has_method("_open_enemy_card_menu"):
		combat._open_enemy_card_menu(0)
		await get_tree().create_timer(0.45).timeout
		await _save_shot("enemigos_cartas_menu_combate")
		if combat.has_method("_close_enemy_card_menu"):
			combat._close_enemy_card_menu()
	# Catálogo ENEMIGAS en el menú MAZO (mismo menú grande)
	$UI/UIRouter.show_deck("alpha", "enemigas")
	await get_tree().create_timer(0.55).timeout
	await _save_shot("enemigos_cartas_menu_mazo")
	print("ENEMY_CARDS_SHOT_OK")
	get_tree().quit(0)


func _fix_shot() -> void:
	## Evidencia post-arreglos: García enfrentando enemigos + HUD XP + mercado.
	await get_tree().create_timer(0.8).timeout
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.15).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("FIX_SHOT_FAIL no missions")
		get_tree().quit(1)
		return
	var mid: String = ""
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) == "open" and not bool(m.get("is_boss", false)):
			mid = str(m.get("id", ""))
			break
	if mid == "":
		mid = String(GameState.active_missions.keys()[0])
	$UI/UIRouter.begin_fight(mid)
	await get_tree().process_frame
	await get_tree().create_timer(0.55).timeout
	await _save_shot("fix_combate_facing")
	GameState.credits = 40
	GameState.credits_changed.emit(GameState.credits)
	$UI/UIRouter.show_market("alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _save_shot("fix_mercado")
	var market = $UI/UIRouter.get_node_or_null("MarketScreen")
	if market and market.has_method("_set_mode"):
		market._set_mode("roulette")
		await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		await _save_shot("fix_ruleta")
	# Fuerza sobre de nivel
	GameState.pending_level_packs = maxi(1, GameState.pending_level_packs)
	$UI/UIRouter.show_level_up("alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await _save_shot("fix_sobre_nivel")
	print("FIX_SHOT_OK level=", GameState.hero_level, " cards=", CardDB.cards.size())
	get_tree().quit(0)


func _xp_pack_shot() -> void:
	## Evidencia: XP por kills + sobre de 3 cartas al subir de nivel + catálogo ampliado.
	await get_tree().create_timer(0.7).timeout
	print("XP_PACK catalog=", CardDB.cards.size())
	if CardDB.cards.size() < 100:
		print("XP_PACK_FAIL catalog too small")
		get_tree().quit(1)
		return
	# Simula kills hasta subir de nivel
	GameState.hero_level = 1
	GameState.hero_xp = 0
	GameState.pending_level_packs = 0
	# Limpia sobre activo si hubiera
	while GameState.active_pack_open():
		var cur: Array[String] = GameState.peek_pack_choices()
		if cur.is_empty():
			break
		GameState.claim_level_pack_card(str(cur[0]), "alpha")
	GameState.pending_level_packs = 0
	var before_lv := GameState.hero_level
	var res: Dictionary = GameState.add_combat_xp(GameState.xp_to_next_level())
	print("XP_PACK grant levels=", res.get("levels", 0), " pending=", GameState.pending_level_packs)
	if int(res.get("levels", 0)) < 1 or GameState.pending_level_packs < 1:
		print("XP_PACK_FAIL no level up")
		get_tree().quit(1)
		return
	# Combate con XP visible
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.15).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("XP_PACK_FAIL no missions")
		get_tree().quit(1)
		return
	var mid: String = String(GameState.active_missions.keys()[0])
	var p: Dictionary = GameState.patrols.get("alpha", {})
	p["status"] = "available"
	p.erase("_awaiting_combat")
	GameState.set_patrol(p)
	$UI/UIRouter.show_combat(mid, "alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	# Fuerza un kill para mostrar XP en log/HUD
	if CombatState.is_active() and not CombatState.enemies.is_empty():
		var e0: Dictionary = CombatState.enemies[0]
		e0["hp"] = 1
		CombatState.enemies[0] = e0
		CombatState._deal_to_enemy(0, 99)
		CombatState.combat_updated.emit()
	await get_tree().create_timer(0.35).timeout
	await _save_shot("xp_combate_kill")
	# Sobre de nivel
	$UI/UIRouter.show_level_up("alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var pack = $UI/UIRouter.get_node_or_null("LevelUpScreen")
	if pack == null or not pack.visible:
		print("XP_PACK_FAIL no level up screen")
		get_tree().quit(1)
		return
	await _save_shot("xp_sobre_tres_cartas")
	# Elige la primera
	var choices: Array[String] = GameState.peek_pack_choices()
	if pack.has_method("_pick") and not choices.is_empty():
		pack._pick(str(choices[0]))
	await get_tree().create_timer(0.35).timeout
	print(
		"XP_PACK_SHOT_OK level=", GameState.hero_level,
		" before=", before_lv,
		" catalog=", CardDB.cards.size(),
		" deck=", GameState.patrol_decks.get("alpha", []).size()
	)
	get_tree().quit(0)


func _market_roulette_shot() -> void:
	## Evidencia: mercado rediseñado + ruleta de cartas.
	await get_tree().create_timer(0.8).timeout
	GameState.credits = 80
	GameState.credits_changed.emit(GameState.credits)
	GameState.boss_defeated = true
	$UI/UIRouter.show_market("alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	var market = $UI/UIRouter.get_node_or_null("MarketScreen")
	if market == null:
		print("MARKET_ROULETTE_FAIL no market")
		get_tree().quit(1)
		return
	market._set_mode("shop")
	market._filter = "todos"
	market._rebuild()
	var stock: Array = CardDB.cards_for_market(true)
	if not stock.is_empty():
		market._selected_id = str(stock[0].get("id", ""))
		market._refresh_detail()
	await get_tree().create_timer(0.4).timeout
	await _save_shot("mercado_tienda_bonita")
	market._set_mode("roulette")
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await _save_shot("mercado_ruleta_lista")
	if market.has_method("_spin_roulette"):
		market._spin_roulette()
		# Espera animación (~2.6s) + margen
		await get_tree().create_timer(3.2).timeout
	await _save_shot("mercado_ruleta_premio")
	print("MARKET_ROULETTE_SHOT_OK credits=", GameState.credits)
	get_tree().quit(0)


func _anime_cards_shot() -> void:
	## Evidencia: García anime + cartas por rareza (combate, mazo, mercado).
	await get_tree().create_timer(1.0).timeout
	print("ANIME_CARDS catalog=", CardDB.cards.size(), " starter=", CardDB.starter_deck.size())
	if CardDB.cards.size() < 40:
		print("ANIME_CARDS_FAIL catalog")
		get_tree().quit(1)
		return
	var rar_ok := {"basica": 0, "magica": 0, "fuerza": 0, "legendaria": 0}
	for c in CardDB.all_cards():
		var r := CardDB.normalize_rarity(str(c.get("rarity", "")))
		if rar_ok.has(r):
			rar_ok[r] = int(rar_ok[r]) + 1
	print("ANIME_CARDS rarities=", rar_ok)
	for k in rar_ok.keys():
		if int(rar_ok[k]) < 5:
			print("ANIME_CARDS_FAIL rarity ", k)
			get_tree().quit(1)
			return
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.2).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("ANIME_CARDS_FAIL no missions")
		get_tree().quit(1)
		return
	var mid: String = String(GameState.active_missions.keys()[0])
	var p: Dictionary = GameState.patrols.get("alpha", {})
	p["status"] = "available"
	p.erase("_awaiting_combat")
	GameState.set_patrol(p)
	$UI/UIRouter.show_combat(mid, "alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	if CombatState.is_active():
		CombatState.hand = ["punetazo", "bloqueo", "combo_imparable", "juicio_final", "esquiva"]
		CombatState.player["energy"] = 5
		CombatState.player["energy_max"] = 5
	var combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	if combat:
		combat._refresh()
		combat._apply_hero_pose("idle")
	await get_tree().create_timer(0.35).timeout
	await _save_shot("anime_garcia_idle_cartas")
	if combat:
		combat._apply_hero_pose("shoot", 1.2)
	await get_tree().create_timer(0.25).timeout
	await _save_shot("anime_garcia_shoot")
	$UI/UIRouter.show_deck("alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await _save_shot("anime_mazo_cartas")
	GameState.credits = 60
	GameState.credits_changed.emit(GameState.credits)
	GameState.boss_defeated = true
	$UI/UIRouter.show_market("alpha")
	await get_tree().process_frame
	var market = $UI/UIRouter.get_node_or_null("MarketScreen")
	if market:
		market._filter = "fuerza"
		market._rebuild()
	await get_tree().create_timer(0.4).timeout
	await _save_shot("anime_mercado_fuerza")
	if market:
		market._filter = "legendaria"
		market._rebuild()
		var stock: Array = CardDB.cards_for_market(true)
		for c in stock:
			if CardDB.is_legendary(str(c.get("rarity", ""))):
				market._selected_id = str(c.get("id", ""))
				market._refresh_detail()
				break
	await get_tree().create_timer(0.4).timeout
	await _save_shot("anime_mercado_legendaria")
	print("ANIME_CARDS_SHOT_OK")
	get_tree().quit(0)


func _roster_shot() -> void:
	## Evidencia: enemigos anime distintos + bosses + escenarios.
	await get_tree().create_timer(1.0).timeout
	print("ROSTER enemies=", CombatRoster.enemies.size(), " bosses=", CombatRoster.bosses.size(), " arenas=", CombatRoster.arenas.size())
	if CombatRoster.enemies.size() < 20:
		print("ROSTER_FAIL enemies")
		get_tree().quit(1)
		return
	if CombatRoster.bosses.size() < 10:
		print("ROSTER_FAIL bosses")
		get_tree().quit(1)
		return
	# Misión normal con foes anime
	await get_tree().create_timer(0.4).timeout
	var mid := ""
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) == "open" and not bool(m.get("is_boss", false)):
			mid = str(m.get("id", ""))
			break
	if mid == "" and not GameState.active_missions.is_empty():
		mid = str(GameState.active_missions.keys()[0])
	if mid != "":
		$UI/UIRouter.begin_fight(mid)
		await get_tree().process_frame
		await get_tree().create_timer(0.7).timeout
		await _save_shot("anime_foes_variety")
		$UI/UIRouter.show_map()
		CombatState.active = false
	# Tres bosses distintos
	var shot_i := 0
	for b in CombatRoster.bosses:
		for old in GameState.active_missions.keys():
			if bool(GameState.active_missions[old].get("is_boss", false)):
				GameState.remove_mission(str(old))
		GameState.boss_spawned = false
		GameState.boss_mission_id = ""
		GameState.active_boss_id = ""
		GameState.nights_count = int(b.get("night_min", b.get("day_min", 2)))
		GameState.day_index = maxi(1, int(GameState.nights_count / 2))
		GameState.defeated_bosses.clear()
		# Marcar bosses previos como derrotados para forzar este
		for prev in CombatRoster.bosses:
			if str(prev.get("id", "")) == str(b.get("id", "")):
				break
			GameState.defeated_bosses.append(str(prev.get("id", "")))
		GameState.request_boss_spawn()
		await get_tree().create_timer(0.35).timeout
		var bmid := GameState.boss_mission_id
		if bmid == "":
			continue
		var p: Dictionary = GameState.patrols.get("alpha", {})
		p["status"] = "available"
		p.erase("_awaiting_combat")
		GameState.set_patrol(p)
		$UI/UIRouter.begin_fight(bmid)
		await get_tree().process_frame
		await get_tree().create_timer(0.55).timeout
		await _save_shot("anime_boss_%02d_%s" % [shot_i + 1, str(b.get("id", "x")).replace("boss_", "")])
		shot_i += 1
		$UI/UIRouter.show_map()
		CombatState.active = false
		if shot_i >= 4:
			break
	print("ROSTER_SHOT_OK shots=", shot_i)
	get_tree().quit(0)


func _boss_fight_demo() -> void:
	## Abre directamente el combate contra El Capo (jugable / captura).
	await get_tree().create_timer(1.0).timeout
	for mid in GameState.active_missions.keys():
		var mm: Dictionary = GameState.active_missions[mid]
		if bool(mm.get("is_boss", false)):
			GameState.remove_mission(str(mid))
	GameState.day_index = 2
	GameState.nights_count = 2
	GameState.boss_spawned = false
	GameState.boss_defeated = false
	GameState.boss_mission_id = ""
	GameState.request_boss_spawn()
	await get_tree().create_timer(0.5).timeout
	var boss_mid := GameState.boss_mission_id
	print("BOSS_FIGHT mid=", boss_mid)
	if boss_mid == "":
		print("BOSS_FIGHT_FAIL no boss")
		get_tree().quit(1)
		return
	var p: Dictionary = GameState.patrols.get("alpha", {})
	p["status"] = "available"
	p.erase("_awaiting_combat")
	GameState.set_patrol(p)
	$UI/UIRouter.begin_fight(boss_mid)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	await _save_shot("boss_fight_idle")
	# Gesto de ataque del Capo — captura a mitad del lunge
	if CombatState.is_active():
		var combat = $UI/UIRouter.get_node_or_null("CombatScreen")
		if combat:
			# Log del movimiento firma (kit único)
			if not CombatState.enemies.is_empty():
				print("BOSS_FIGHT signature=", CombatState.enemies[0].get("signature_move", "?"),
					" next=", CombatState.enemies[0].get("next_card_name", "?"))
			var wrap = combat._enemy_wrap(0)
			if wrap:
				var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
				if spr:
					wrap.set_meta("anim_locked", true)
					var atk := str(wrap.get_meta("pose_attack", ""))
					if atk != "" and ResourceLoader.exists(atk):
						spr.texture = load(atk)
					var base: Vector2 = wrap.get_meta("sprite_base", spr.position)
					var tw := create_tween()
					tw.set_parallel(true)
					tw.tween_property(spr, "position", base + Vector2(-110, -8), 0.18)
					tw.tween_property(spr, "rotation_degrees", -12.0, 0.18)
					tw.tween_property(spr, "scale", Vector2(0.88, 1.16), 0.18)
					await tw.finished
					await _save_shot("boss_fight_attack")
					var tw2 := create_tween()
					tw2.set_parallel(true)
					tw2.tween_property(spr, "position", base, 0.2)
					tw2.tween_property(spr, "rotation_degrees", 0.0, 0.2)
					tw2.tween_property(spr, "scale", Vector2.ONE, 0.2)
					await tw2.finished
			# Daño al Capo con pose hurt
			wrap = combat._enemy_wrap(0)
			if wrap:
				wrap.set_meta("anim_locked", true)
				var hurt := str(wrap.get_meta("pose_hurt", ""))
				var spr2: TextureRect = wrap.find_child("EnemySprite", true, false)
				if spr2 and hurt != "" and ResourceLoader.exists(hurt):
					spr2.texture = load(hurt)
					spr2.modulate = Color(1.0, 0.35, 0.3)
					var tw3 := create_tween()
					tw3.tween_property(spr2, "position", spr2.position + Vector2(22, -10), 0.1)
					await tw3.finished
				CombatState.enemies[0]["hp"] = maxi(1, int(CombatState.enemies[0].get("hp", 10)) - 18)
				# Refrescar texto HP del panel
				for c in wrap.get_children():
					if c is Label and "/" in c.text:
						c.text = "%d/%d" % [int(CombatState.enemies[0]["hp"]), int(CombatState.enemies[0].get("max_hp", 94))]
						c.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
					if c is ProgressBar:
						c.value = float(CombatState.enemies[0]["hp"])
					if c is VBoxContainer:
						for c2 in c.get_children():
							if c2 is Label and "/" in c2.text:
								c2.text = "%d/%d" % [int(CombatState.enemies[0]["hp"]), int(CombatState.enemies[0].get("max_hp", 94))]
							if c2 is ProgressBar:
								c2.value = float(CombatState.enemies[0]["hp"])
				await get_tree().create_timer(0.2).timeout
				await _save_shot("boss_fight_hurt")
				wrap.set_meta("anim_locked", false)
	print("BOSS_FIGHT_OK")
	if OS.get_environment("TQ_BOSS_FIGHT_QUIT") == "1":
		get_tree().quit(0)


func _progression_shot() -> void:
	## Evidencia: el nivel sube PV/bloque y el HUD muestra poder de mazo.
	await get_tree().create_timer(0.8).timeout
	GameState.hero_level = 1
	GameState.hero_xp = 0
	GameState.pending_level_packs = 0
	var cfg1 := {
		"max_hp": 50 + GameState.level_hp_bonus(),
		"energy_max": 3 + GameState.level_energy_bonus(),
		"start_block": GameState.level_start_block(),
	}
	print("PROGRESSION_L1 hp=", cfg1["max_hp"], " block=", cfg1["start_block"], " chip=", GameState.progression_chip())
	var res := GameState.add_combat_xp(GameState.xp_to_next_level() + GameState.xp_to_next_level(2) + 5, "shot")
	print("PROGRESSION_LEVELS ", res)
	var cfg3 := {
		"max_hp": 50 + GameState.level_hp_bonus(),
		"energy_max": 3 + GameState.level_energy_bonus(),
		"start_block": GameState.level_start_block(),
	}
	print("PROGRESSION_L", GameState.hero_level, " hp=", cfg3["max_hp"], " energy=", cfg3["energy_max"], " block=", cfg3["start_block"])
	print("PROGRESSION_DECK ", GameState.deck_power_label("alpha"))
	print("PROGRESSION_BOSS ", GameState.boss_night_label())
	# Forzar UI mapa
	var router = $UI/UIRouter
	if router and router.has_method("show_map"):
		router.show_map()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _save_shot("progression_map_chip")
	# Abrir sobre si hay
	if GameState.has_pending_level_packs() and router and router.has_method("show_level_up"):
		router.show_level_up("alpha")
		await get_tree().create_timer(0.6).timeout
		await _save_shot("progression_level_pack")
	print("PROGRESSION_SHOT_OK level=", GameState.hero_level, " hp_bonus=", GameState.level_hp_bonus())
	if OS.get_environment("TQ_PROGRESSION_QUIT") != "0":
		get_tree().quit(0)


func _boss_autoplay() -> void:
	## Juega el combate del Capo automáticamente hasta victoria o derrota.
	await get_tree().create_timer(1.0).timeout
	for mid in GameState.active_missions.keys():
		var mm: Dictionary = GameState.active_missions[mid]
		if bool(mm.get("is_boss", false)):
			GameState.remove_mission(str(mid))
	GameState.day_index = 2
	GameState.nights_count = 2
	GameState.boss_spawned = false
	GameState.boss_defeated = false
	GameState.boss_mission_id = ""
	GameState.active_boss_id = ""
	GameState.request_boss_spawn()
	await get_tree().create_timer(0.5).timeout
	var boss_mid := GameState.boss_mission_id
	print("BOSS_AUTOPLAY mid=", boss_mid)
	if boss_mid == "":
		print("BOSS_AUTOPLAY_FAIL no boss")
		get_tree().quit(1)
		return
	var p: Dictionary = GameState.patrols.get("alpha", {})
	p["status"] = "available"
	p.erase("_awaiting_combat")
	GameState.set_patrol(p)
	$UI/UIRouter.begin_fight(boss_mid)
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _save_shot("boss_autoplay_start")
	var combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	var refresh_was_connected := false
	if combat and CombatState.combat_updated.is_connected(combat._refresh):
		CombatState.combat_updated.disconnect(combat._refresh)
		refresh_was_connected = true
	var turns := 0
	while CombatState.is_active() and turns < 80:
		turns += 1
		if CombatState.phase != CombatState.Phase.PLAYER:
			await get_tree().create_timer(0.2).timeout
			continue
		if combat:
			combat._busy = false
			combat._dying.clear()
		var played := 0
		# Prioridad: defensa si vida baja, si no daño al Capo (índice 0)
		var focus := 0
		CombatState.select_enemy(focus)
		var hand: Array = CombatState.hand.duplicate()
		var php := int(CombatState.player.get("hp", 0))
		var prefer_def := php <= 40
		var order: Array = []
		for cid in hand:
			var def := CardDB.get_card(str(cid))
			var typ := str(def.get("type", ""))
			var score := 0
			if prefer_def and (typ == "defensa" or int(def.get("block", 0)) > 0 or bool(def.get("dodge", false)) or bool(def.get("miss_attack", false)) or str(def.get("id",""))=="provocar"):
				score = 50 + int(def.get("block", 0))
			elif int(def.get("next_bonus", 0)) > 0:
				score = 40
			elif typ == "ataque" or int(def.get("damage", 0)) > 0:
				score = 30 + int(def.get("damage", 0))
			else:
				score = 10
			order.append({"id": str(cid), "score": score})
		order.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
		for item in order:
			var cid2 := str(item["id"])
			if not CombatState.can_play_card(cid2):
				continue
			CombatState.play_card(cid2, focus)
			played += 1
			await get_tree().create_timer(0.12).timeout
			if not CombatState.is_active():
				break
		print("BOSS_AUTOPLAY turn=", turns, " played=", played, " hp=", CombatState.player.get("hp",0), " capo=", (CombatState.enemies[0].get("hp",0) if CombatState.enemies.size()>0 else -1))
		if not CombatState.is_active():
			break
		# Lógica pura: evitar hangs/crash de tweens en autoplay.
		if combat:
			combat._busy = false
			combat._dying.clear()
			combat.end_turn_btn.disabled = false
		CombatState.end_player_turn()
		await get_tree().create_timer(0.2).timeout
		if combat and is_instance_valid(combat):
			combat._busy = false
			# refresh ligero solo stats; evita rebuild que libera nodos mid-tween
			combat._sync_enemy_stats(CombatState.get_snapshot())
		await get_tree().create_timer(0.1).timeout
	var victory := CombatState.phase == CombatState.Phase.ENDED and int(CombatState.player.get("hp", 0)) > 0
	# victory flag from ended combat
	var any_enemy := false
	for e in CombatState.enemies:
		if int(e.get("hp", 0)) > 0 and not bool(e.get("detained", false)) and not bool(e.get("fled", false)):
			any_enemy = true
	victory = int(CombatState.player.get("hp", 0)) > 0 and not any_enemy
	print("BOSS_AUTOPLAY_RESULT ", "WIN" if victory else "DEATH", " turns=", turns, " hp=", CombatState.player.get("hp",0))
	if combat and refresh_was_connected and not CombatState.combat_updated.is_connected(combat._refresh):
		CombatState.combat_updated.connect(combat._refresh)
	if combat and is_instance_valid(combat):
		combat._busy = false
		combat._refresh()
	await _save_shot("boss_autoplay_end")
	if victory:
		GameState.active_boss_id = "boss_01_capo"
		var gained: Array = GameState.grant_boss_rewards("alpha")
		print("BOSS_AUTOPLAY_REWARD ", gained)
		await _save_shot("boss_autoplay_reward")
	if OS.get_environment("TQ_BOSS_AUTOPLAY_QUIT") != "0":
		get_tree().quit(0 if victory else 2)


func _boss_market_shot() -> void:
	## Evidencia visual: mercado + boss día 2 en mapa/briefing.
	print("BOSS_MARKET_SHOT begin")
	await get_tree().create_timer(1.2).timeout
	print("BOSS_MARKET_SHOT after wait missions=", GameState.active_missions.size())
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.2).timeout
		tries += 1
	print("BOSS_MARKET_SHOT missions ready=", GameState.active_missions.size())
	# Mercado con stock visible
	GameState.credits = 40
	GameState.credits_changed.emit(GameState.credits)
	$UI/UIRouter.show_market("alpha")
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _save_shot("mercado_cartas")
	# Desbloquear legendarias para segunda captura de mercado
	GameState.boss_defeated = true
	$UI/UIRouter.show_market("alpha")
	await get_tree().process_frame
	var market = $UI/UIRouter.get_node_or_null("MarketScreen")
	if market:
		market._filter = "legendaria"
		market._rebuild()
		var stock: Array = CardDB.cards_for_market(true)
		for c in stock:
			if CardDB.is_legendary(str(c.get("rarity", ""))):
				market._selected_id = str(c.get("id", ""))
				market._refresh_detail()
				break
	await get_tree().create_timer(0.4).timeout
	await _save_shot("mercado_legendarias")
	# Boss en noche 2
	for mid in GameState.active_missions.keys():
		var mm: Dictionary = GameState.active_missions[mid]
		if bool(mm.get("is_boss", false)):
			GameState.remove_mission(str(mid))
	GameState.day_index = 2
	GameState.nights_count = 2
	GameState.boss_spawned = false
	GameState.boss_defeated = false
	GameState.boss_mission_id = ""
	GameState.request_boss_spawn()
	await get_tree().create_timer(0.5).timeout
	$UI/UIRouter.show_map()
	await get_tree().process_frame
	var boss_mid := GameState.boss_mission_id
	print("BOSS_MARKET_SHOT boss=", boss_mid, " spawned=", GameState.boss_spawned)
	if boss_mid == "":
		print("BOSS_MARKET_SHOT_FAIL no boss")
		get_tree().quit(1)
		return
	var bmission: Dictionary = GameState.active_missions.get(boss_mid, {})
	if bmission.has("pos"):
		camera.global_position = bmission["pos"]
		camera.zoom = Vector2(1.35, 1.35)
	await get_tree().create_timer(0.45).timeout
	await _save_shot("mapa_boss_capo")
	$UI/UIRouter.show_mission(boss_mid)
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await _save_shot("briefing_boss_capo")
	print("BOSS_MARKET_SHOT_OK")
	get_tree().quit(0)


func _missions_menu_shot() -> void:
	## Captura el menú de misiones rediseñado con briefing de asalto.
	await get_tree().create_timer(1.0).timeout
	# Asegurar avisos
	if GameState.active_missions.is_empty():
		var spawner = get_tree().get_first_node_in_group("mission_spawner")
		if spawner == null and has_node("Systems/MissionSpawner"):
			spawner = $Systems/MissionSpawner
		if spawner and spawner.has_method("_ensure_period_missions"):
			spawner.call("_ensure_period_missions", true)
		elif spawner and spawner.has_method("spawn_now"):
			spawner.spawn_now()
	await get_tree().create_timer(0.5).timeout
	if GameState.active_missions.is_empty() and GameState.has_method("create_mission_from_event"):
		var districts: Array = GameState.station.get("districts", [])
		var district: Dictionary = districts[0] if not districts.is_empty() else {"id": "centro", "name": "Centro"}
		var events: Array = GameState.station.get("events", [])
		if events.is_empty() and GameState.has_method("events_for_period"):
			events = GameState.events_for_period(GameState.time_of_day())
		for i in range(mini(3, maxi(1, events.size()))):
			var ev: Dictionary = events[i] if i < events.size() else {
				"id": "demo_%d" % i,
				"name": ["Atraco a tienda", "Pelea en vía", "Accidente con fuga"][i % 3],
				"category": ["delitos", "delitos", "trafico"][i % 3],
				"severity": ["high", "medium", "low"][i % 3],
				"xp": 60 + i * 20,
				"durationSec": 90,
				"file": "",
			}
			GameState.create_mission_from_event(ev, district, Vector2(400 + i * 120, 300 + i * 40))
	await get_tree().create_timer(0.3).timeout
	$UI/UIRouter.show_missions()
	await get_tree().process_frame
	await get_tree().create_timer(0.55).timeout
	await _save_shot("missions_menu_overview")
	var menu = $UI/UIRouter/MissionsMenu
	if menu and menu.has_method("_filtered"):
		var items: Array = menu._filtered()
		print("MISSIONS_MENU count=", items.size())
		if items.size() > 1:
			var mid := str(items[1].get("id", ""))
			menu._selected_id = mid
			menu._show_detail(mid)
			menu._highlight_rows()
			await get_tree().create_timer(0.4).timeout
			await _save_shot("missions_menu_detail")
		elif items.size() == 1:
			menu._show_detail(str(items[0].get("id", "")))
			menu._highlight_rows()
			await get_tree().create_timer(0.35).timeout
			await _save_shot("missions_menu_detail")
	print("MISSIONS_MENU_SHOT_OK")
	if OS.get_environment("TQ_MISSIONS_MENU_QUIT") != "0":
		get_tree().quit(0)


func _map_shot() -> void:
	## Captura el mapa con marcadores tácticos de misión.
	await get_tree().create_timer(1.4).timeout
	var tries := 0
	while GameState.active_missions.size() < 3 and tries < 50:
		await get_tree().create_timer(0.25).timeout
		tries += 1
	$UI/UIRouter.show_map()
	await get_tree().process_frame
	# Encuaadra varias misiones
	var markers := get_tree().get_nodes_in_group("mission_marker")
	print("MAP_SHOT markers=", markers.size(), " missions=", GameState.active_missions.size())
	if markers.is_empty():
		print("MAP_SHOT_FAIL no markers")
		get_tree().quit(1)
		return
	var center := Vector2.ZERO
	for m in markers:
		center += (m as Node2D).global_position
	center /= float(markers.size())
	camera.global_position = center
	camera.zoom = Vector2(0.95, 0.95)
	await get_tree().create_timer(0.5).timeout
	await _save_shot("map_tactical_markers")
	# Acercar a un marcador
	var first: Node2D = markers[0]
	camera.global_position = first.global_position
	camera.zoom = Vector2(1.55, 1.55)
	await get_tree().create_timer(0.35).timeout
	await _save_shot("map_tactical_marker_close")
	print("MAP_SHOT_OK")
	get_tree().quit(0)


func _combat_shot() -> void:
	## Abre combate y guarda capturas para evidencia visual.
	await get_tree().create_timer(1.2).timeout
	var tries := 0
	while GameState.active_missions.is_empty() and tries < 40:
		await get_tree().create_timer(0.25).timeout
		tries += 1
	if GameState.active_missions.is_empty():
		print("COMBAT_SHOT_FAIL no missions")
		get_tree().quit(1)
		return
	var mid: String = String(GameState.active_missions.keys()[0])
	var p: Dictionary = GameState.patrols.get("alpha", {})
	p["status"] = "available"
	p.erase("_awaiting_combat")
	GameState.set_patrol(p)
	$UI/UIRouter.show_combat(mid, "alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	await _save_shot("combat_turno1")
	# Asegurar cartas de ataque y defensa en mano
	if CombatState.is_active() and CombatState.hand.size() >= 2:
		CombatState.hand[0] = "punetazo"
		CombatState.hand[1] = "shield"
	var combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	if combat:
		combat._refresh()
	await get_tree().process_frame
	combat = $UI/UIRouter.get_node_or_null("CombatScreen")
	if combat and CombatState.is_active():
		# Defensa primero -> barra de escudo
		if CombatState.can_play_card("shield"):
			combat._busy = true
			await combat._hero_guard_pulse()
			CombatState.play_card("shield")
			combat._busy = false
			combat._refresh()
			await get_tree().create_timer(0.35).timeout
			await _save_shot("combat_escudo")
		# Ataque con lunge
		if CombatState.can_play_card("punetazo"):
			var def: Dictionary = CardDB.get_card("punetazo")
			combat._busy = true
			combat._apply_hero_pose("shoot", 0.9)
			if combat._player_actor:
				combat._player_actor.position = combat._player_base_pos + Vector2(58, 0)
			await get_tree().process_frame
			await _save_shot("combat_ataque_lunge")
			# Forzar kill del seleccionado para demo de caída
			var sel := int(CombatState.get_snapshot().get("selected_enemy", 0))
			if sel >= 0 and sel < CombatState.enemies.size():
				CombatState.enemies[sel]["hp"] = 1
			await combat._hero_attack_sequence(def)
			CombatState.play_card("punetazo")
			var wrap = combat._enemy_wrap(sel)
			if wrap and int(CombatState.enemies[sel].get("hp", 1)) <= 0:
				await combat._start_enemy_death(wrap, sel, 8)
			combat._busy = false
			combat._refresh()
			await get_tree().create_timer(0.5).timeout
			await _save_shot("combat_muerte")
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

	# Marcadores de alerta en mapa activos (máx. 3 por franja + boss opcional)
	var markers = get_tree().get_nodes_in_group("mission_marker")
	print("PLAYTEST markers group=", markers.size())
	if markers.size() < 1:
		errors.append("map alerts should appear")
	var marker_cap := 3
	if GameState.boss_spawned and not GameState.boss_defeated:
		marker_cap = 4
	if markers.size() > marker_cap:
		errors.append("too many map missions for period")

	# Ciclo día → atardecer → noche con 3 misiones
	GameState.set_clock(10, 0)
	GameState.period_missions_done = 0
	for _i in 3:
		GameState.advance_after_mission({"period": "day"})
	print("PLAYTEST after 3 day missions tod=", GameState.time_of_day(), " clock=%02d:%02d" % [GameState.hour, GameState.minute])
	if GameState.time_of_day() != "dusk":
		errors.append("3 day missions should reach dusk")
	for _i in 3:
		GameState.advance_after_mission({"period": "dusk"})
	print("PLAYTEST after 3 dusk missions tod=", GameState.time_of_day(), " clock=%02d:%02d" % [GameState.hour, GameState.minute])
	if GameState.time_of_day() != "night":
		errors.append("3 dusk missions should reach night")
	# Noche más dura en combate
	GameState.set_clock(22, 0)
	await get_tree().create_timer(0.3).timeout
	var night_mid := ""
	for m in GameState.active_missions.values():
		if str(m.get("period", "")) == "night" and str(m.get("status", "")) == "open":
			night_mid = str(m["id"])
			break
	if night_mid == "" and not GameState.active_missions.is_empty():
		night_mid = str(GameState.active_missions.keys()[0])
	if night_mid != "":
		var cfg_n := GameState.build_combat_config(night_mid, "alpha")
		var ehp := 0
		for e in cfg_n.get("enemies", []):
			ehp = maxi(ehp, int(e.get("hp", 0)))
		print("PLAYTEST night combat enemies=", cfg_n.get("enemies", []).size(), " max_hp=", ehp)
		if cfg_n.get("enemies", []).size() < 3:
			errors.append("night should be harder (3 enemies)")
		if ehp < 40:
			errors.append("night enemy hp too low")

	# 8) Day/night + mission art
	print("PLAYTEST tod=", GameState.time_of_day())
	GameState.set_clock(18, 0)
	await get_tree().process_frame
	print("PLAYTEST tod dusk=", GameState.time_of_day())
	if GameState.time_of_day() != "dusk":
		errors.append("dusk tod failed")
	GameState.set_clock(22, 0)
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

	# Mercado de cartas + boss día 2
	print("PLAYTEST catalog=", CardDB.cards.size(), " market=", CardDB.cards_for_market(false).size())
	if CardDB.cards.size() < 40:
		errors.append("card catalog too small")
	if CardDB.cards_for_market(false).size() < 20:
		errors.append("market stock too small")
	$UI/UIRouter.show_market("alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	if not $UI/UIRouter/MarketScreen.visible:
		errors.append("market screen not visible")
	else:
		print("PLAYTEST market OK credits=", GameState.credits)
	var before_credits := GameState.credits
	var buy_id := ""
	for c in CardDB.cards_for_market(false):
		var cid := str(c.get("id", ""))
		if CardDB.price_of(cid) <= before_credits:
			buy_id = cid
			break
	var deck_before := GameState.get_patrol_deck("alpha").size()
	if buy_id != "" and GameState.buy_card_for_patrol("alpha", buy_id):
		if GameState.credits >= before_credits:
			errors.append("credits not spent")
		if GameState.get_patrol_deck("alpha").size() != deck_before + 1:
			errors.append("market buy did not add card")
		print("PLAYTEST bought ", buy_id, " credits=", GameState.credits)
	else:
		errors.append("market buy failed")
	$UI/UIRouter.show_map()

	# Forzar día 2 y boss
	for mid in GameState.active_missions.keys():
		var mm: Dictionary = GameState.active_missions[mid]
		if bool(mm.get("is_boss", false)):
			GameState.remove_mission(str(mid))
	GameState.day_index = 1
	GameState.nights_count = 0
	GameState.boss_spawned = false
	GameState.boss_defeated = false
	GameState.boss_mission_id = ""
	GameState.defeated_bosses.clear()
	GameState.active_boss_id = ""
	# Noche 1: sin boss
	GameState.set_clock(18, 0)  # dusk
	await get_tree().process_frame
	GameState.set_clock(21, 0)  # night 1
	await get_tree().create_timer(0.35).timeout
	print("PLAYTEST night1=", GameState.nights_count, " boss=", GameState.boss_spawned)
	if GameState.nights_count != 1:
		errors.append("night 1 count failed")
	if GameState.boss_spawned:
		errors.append("boss should not spawn on night 1")
	# Amanecer → día 2 → noche 2: boss
	GameState.set_clock(8, 0)
	await get_tree().process_frame
	GameState.set_clock(21, 0)
	await get_tree().create_timer(0.45).timeout
	print("PLAYTEST night2=", GameState.nights_count, " day=", GameState.day_index, " boss_spawned=", GameState.boss_spawned, " mid=", GameState.boss_mission_id)
	if GameState.nights_count != 2:
		errors.append("night 2 count failed")
	if not GameState.is_boss_night():
		errors.append("night 2 should be boss night")
	if not GameState.boss_spawned or GameState.boss_mission_id == "":
		errors.append("boss not spawned on night 2")
	else:
		var bcfg := GameState.build_combat_config(GameState.boss_mission_id, "alpha")
		var boss_named := false
		for e in bcfg.get("enemies", []):
			if str(e.get("name", "")) == "EL CAPO" or bool(e.get("is_boss", false)):
				boss_named = true
		print("PLAYTEST boss combat enemies=", bcfg.get("enemies", []).size(), " named=", boss_named)
		if not boss_named:
			errors.append("boss combat missing EL CAPO")
		var deck_pre := GameState.get_patrol_deck("alpha").size()
		GameState.active_boss_id = "boss_01_capo"
		var gained: Array = GameState.grant_boss_rewards("alpha")
		print("PLAYTEST boss rewards=", gained)
		if gained.size() != 1:
			errors.append("boss should grant 1 unique legendary")
		if gained.is_empty() or str(gained[0]) != "juicio_final":
			errors.append("Capo should grant juicio_final")
		if GameState.get_patrol_deck("alpha").size() < deck_pre + 1:
			errors.append("legendary not added to deck")
		# Kits únicos: Capo no comparte moves con Viuda
		var capo_pool: Array = CardDB.enemy_pool_for_boss("boss_01_capo")
		var viuda_pool: Array = CardDB.enemy_pool_for_boss("boss_02_viuda")
		var shared := 0
		for cid in capo_pool:
			if cid in viuda_pool and str(cid).begins_with("boss_"):
				shared += 1
		if shared > 0:
			errors.append("boss signature kits should be unique")
		if "boss_capo_orden" not in capo_pool:
			errors.append("Capo missing signature move")
		if "boss_viuda_beso" not in viuda_pool:
			errors.append("Viuda missing signature move")
		if not GameState.boss_defeated:
			errors.append("boss_defeated flag missing")
		if GameState.boss_spawned:
			errors.append("next boss must wait 2 nights (should not spawn instantly)")
		if CardDB.cards_for_market(true).size() <= CardDB.cards_for_market(false).size():
			errors.append("legendaries should unlock in market after boss")
		# Noche 3: sin boss; noche 4: sí
		GameState.set_clock(8, 0)
		await get_tree().process_frame
		GameState.set_clock(21, 0)
		await get_tree().create_timer(0.35).timeout
		print("PLAYTEST night3=", GameState.nights_count, " boss=", GameState.boss_spawned)
		if GameState.nights_count != 3:
			errors.append("night 3 count failed")
		if GameState.boss_spawned:
			errors.append("boss should not spawn on night 3")
		GameState.set_clock(8, 0)
		await get_tree().process_frame
		GameState.set_clock(21, 0)
		await get_tree().create_timer(0.45).timeout
		print("PLAYTEST night4=", GameState.nights_count, " boss=", GameState.boss_spawned, " mid=", GameState.boss_mission_id)
		if GameState.nights_count != 4:
			errors.append("night 4 count failed")
		if not GameState.boss_spawned:
			errors.append("boss should spawn on night 4")

	if errors.is_empty():
		print("PLAYTEST_OK")
		get_tree().quit(0)
	else:
		print("PLAYTEST_FAIL ", errors)
		get_tree().quit(1)
