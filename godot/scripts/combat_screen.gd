extends Control
## Combate: suelo anclado, muerte con caída, escudo, cartas y barras minimalistas.

const PACK_HERO := "res://assets/combat/custom/hero/"
const PACK_FOE := "res://assets/combat/custom/foes/"
const FX_DIR := "res://assets/combat/custom/fx/"
const MAP_DIR := "res://assets/combat/custom/map/"
const PHYSICS_ARENA := "res://assets/combat/custom/map/arena_street_physics.png"
const GROUND_Y := 248.0

@onready var bg: TextureRect = %ArenaBg
@onready var title_label: Label = %TitleLabel
@onready var turn_label: Label = %TurnLabel
@onready var hp_label: Label = %HpLabel
@onready var block_label: Label = %BlockLabel
@onready var location_label: Label = %LocationLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var log_label: Label = %LogLabel
@onready var player_sprite: TextureRect = %PlayerSprite
@onready var player_hp_bar: ProgressBar = %PlayerHpBar
@onready var player_hp_text: Label = %PlayerHpText
@onready var player_marker: Label = %PlayerMarker
@onready var enemies_row: HBoxContainer = %EnemiesRow
@onready var hand_row: HBoxContainer = %HandRow
@onready var deck_count: Label = %DeckCount
@onready var discard_count: Label = %DiscardCount
@onready var energy_row: HBoxContainer = %EnergyRow
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_btn: Button = %ResultBtn

var _fx_layer: Control
var _prev_enemy_hp: Dictionary = {}
var _prev_player_hp: int = -1
var _prev_player_block: int = 0
var _busy: bool = false
var _closing: bool = false
var _hero_pose: String = "idle"
var _hero_pose_until: float = 0.0
var _bob_t: float = 0.0
var _player_shadow: TextureRect
var _player_actor: Control
var _player_base_pos: Vector2 = Vector2.ZERO
var _player_block_bar: ProgressBar
var _player_block_text: Label
var _gone_enemies: Dictionary = {} # index -> true after death fade
var _dying: Dictionary = {}
var _arena_path: String = ""
var _enemy_card_menu: Control
var _enemy_menu_enemy_index: int = -1
var _enemy_hand_row: HBoxContainer
var _enemy_hand_label: Label
var _hand_label: Label


func _hero_tex(name: String) -> Texture2D:
	var anime := CombatRoster.hero_pose(name)
	if anime != "" and (ResourceLoader.exists(anime) or FileAccess.file_exists(anime)):
		return _load_combat_tex(anime)
	var path := PACK_HERO + name + ".png"
	return _load_combat_tex(path)


func _load_combat_tex(path: String) -> Texture2D:
	## Prefer imported resources (export-safe). Raw PNG fallback for editor hot-reload.
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res as Texture2D
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


func _fx_tex(name: String) -> Texture2D:
	var path := FX_DIR + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _hero_pose_key(pose: String) -> String:
	match pose:
		"shoot", "aim":
			return "shoot"
		"hurt":
			return "hurt"
		_:
			return "idle"


func _hero_using_anime(pose_key: String = "") -> bool:
	var key := pose_key if pose_key != "" else _hero_pose_key(_hero_pose)
	var path := CombatRoster.hero_pose(key)
	return path.find("/anime/") >= 0


func _apply_hero_facing() -> void:
	## Anime idle/shoot/hurt ya miran a la DERECHA (hacia enemigos) → sin flip.
	## Custom idle mira a la derecha; custom shoot mira a la izquierda.
	var key := _hero_pose_key(_hero_pose)
	if _hero_using_anime(key):
		player_sprite.flip_h = false
	else:
		player_sprite.flip_h = key == "shoot"


func _apply_hero_pose(pose: String, hold_sec: float = 0.0) -> void:
	_hero_pose = pose
	if hold_sec > 0.0:
		_hero_pose_until = Time.get_ticks_msec() / 1000.0 + hold_sec
	var tex: Texture2D = null
	match pose:
		"shoot", "aim":
			tex = _hero_tex("shoot")
		"hurt":
			tex = _hero_tex("hurt")
		_:
			tex = _hero_tex("idle")
	if tex == null:
		tex = _hero_tex("idle")
	if tex:
		player_sprite.texture = tex
		_apply_hero_facing()
		_plant_hero_sprite()


func _tick_hero_pose() -> void:
	if _hero_pose == "idle":
		return
	if Time.get_ticks_msec() / 1000.0 >= _hero_pose_until:
		_apply_hero_pose("idle")


func _plant_hero_sprite() -> void:
	## Cuerpo completo, pies anclados al borde inferior (sin crop de torso).
	if player_sprite == null:
		return
	var box := Vector2(210.0, GROUND_Y + 6.0)
	_bottom_plant_texture(player_sprite, box)
	if not bool(player_sprite.get_meta("anim_locked", false)):
		# Restaura la base plantada (el bob suma offset encima)
		var planted: Vector2 = player_sprite.get_meta("plant_pos", player_sprite.position)
		player_sprite.position = planted


func _bottom_plant_texture(tex: TextureRect, box: Vector2) -> void:
	## Escala con aspect ratio y pega el borde inferior al suelo del slot.
	if tex == null:
		return
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	var dw := box.x
	var dh := box.y
	if tex.texture != null:
		var tw := float(tex.texture.get_width())
		var th := float(tex.texture.get_height())
		if tw > 1.0 and th > 1.0:
			var sc := minf(box.x / tw, box.y / th)
			dw = tw * sc
			dh = th * sc
	tex.custom_minimum_size = Vector2(dw, dh)
	tex.size = Vector2(dw, dh)
	var planted := Vector2((box.x - dw) * 0.5, box.y - dh)
	tex.position = planted
	tex.set_meta("plant_pos", planted)
	tex.set_meta("plant_box", box)
	tex.pivot_offset = Vector2(dw * 0.5, dh * 0.94)


func _ready() -> void:
	visible = false
	end_turn_btn.pressed.connect(_on_end_turn)
	result_btn.pressed.connect(_on_result_close)
	result_panel.visible = false
	CombatState.combat_updated.connect(_refresh)
	CombatState.combat_ended.connect(_on_combat_ended)
	CombatState.log_message.connect(_on_log)
	_style_end_btn()
	_style_bottom_panel()
	_ensure_enemy_hand_ui()
	_fx_layer = Control.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 80
	add_child(_fx_layer)
	_setup_player_actor()
	_ensure_player_block_bar()
	_ground_arena_layout()
	_ensure_floor_plane()
	set_process(true)


func _ground_arena_layout() -> void:
	## Baja columnas para que los pies toquen el suelo visual del callejón.
	var player_col := get_node_or_null("Arena/PlayerCol")
	if player_col:
		player_col.offset_top = -40.0
		player_col.offset_bottom = 332.0
		player_col.alignment = BoxContainer.ALIGNMENT_END
	if enemies_row:
		enemies_row.offset_top = -60.0
		enemies_row.offset_bottom = 332.0
		enemies_row.alignment = BoxContainer.ALIGNMENT_END
	if player_marker:
		player_marker.visible = true
		player_marker.text = "GARCÍA · U.P.R. 091"
		player_marker.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
		player_marker.add_theme_font_size_override("font_size", 13)


func _setup_player_actor() -> void:
	if player_sprite.get_parent() == null:
		return
	if player_sprite.get_parent().name == "PlayerActor":
		_player_actor = player_sprite.get_parent()
		_player_shadow = _player_actor.get_node_or_null("Shadow")
		_apply_hero_facing()
		_plant_hero_sprite()
		return
	var parent := player_sprite.get_parent()
	var idx := player_sprite.get_index()
	_player_actor = Control.new()
	_player_actor.name = "PlayerActor"
	_player_actor.custom_minimum_size = Vector2(210, GROUND_Y + 8.0)
	_player_actor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_actor.clip_contents = false
	parent.add_child(_player_actor)
	parent.move_child(_player_actor, idx)
	parent.remove_child(player_sprite)
	_player_actor.add_child(player_sprite)
	player_sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_sprite.anchor_right = 0.0
	player_sprite.anchor_bottom = 0.0
	_plant_hero_sprite()
	_apply_hero_facing()
	_player_shadow = TextureRect.new()
	_player_shadow.name = "Shadow"
	_player_shadow.texture = _map_tex("foot_shadow")
	if _player_shadow.texture == null:
		_player_shadow.texture = _fx_tex("shadow")
	_player_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_player_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_shadow.modulate = Color(0, 0, 0, 0.92)
	_player_actor.add_child(_player_shadow)
	_player_actor.move_child(_player_shadow, 0)
	_layout_ground_shadow(_player_shadow, _player_actor, 120.0)
	_player_base_pos = _player_actor.position


func _layout_ground_shadow(shadow: TextureRect, actor: Control, width: float) -> void:
	if shadow == null or actor == null:
		return
	var h := 28.0
	var aw := actor.size.x if actor.size.x > 1.0 else 210.0
	shadow.size = Vector2(width + 20.0, h)
	# Sombra justo bajo la suela (contacto con el asfalto)
	shadow.position = Vector2((aw - width - 20.0) * 0.5, GROUND_Y + 2.0)
	shadow.pivot_offset = Vector2((width + 20.0) * 0.5, h * 0.55)
	shadow.modulate = Color(0.01, 0.01, 0.02, 0.95)


func _ensure_floor_plane() -> void:
	## Cubierta opaca de asfalto + bordillo: los pies apoyan aquí (sin flotar).
	var existing := get_node_or_null("FloorPlane") as Control
	if existing:
		existing.queue_free()
	var floor := Control.new()
	floor.name = "FloorPlane"
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Cubierta alta: tapa el fondo bajo la línea de contacto
	floor.offset_top = -352.0
	floor.offset_bottom = -228.0
	floor.z_index = 3
	add_child(floor)
	move_child(floor, get_node("Bottom").get_index())

	# Base sólida (oculta cualquier “hueco” del BG)
	var solid := ColorRect.new()
	solid.name = "SolidDeck"
	solid.color = Color(0.09, 0.1, 0.12, 1.0)
	solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.add_child(solid)

	var asphalt := TextureRect.new()
	asphalt.name = "Asphalt"
	asphalt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	asphalt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	asphalt.stretch_mode = TextureRect.STRETCH_TILE
	asphalt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	asphalt.texture = _map_tex("floor_asphalt")
	if asphalt.texture == null:
		asphalt.texture = _make_asphalt_tex()
	asphalt.modulate = Color(1, 1, 1, 1)
	floor.add_child(asphalt)

	var curb := TextureRect.new()
	curb.name = "Curb"
	curb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	curb.offset_bottom = 18.0
	curb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	curb.stretch_mode = TextureRect.STRETCH_TILE
	curb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curb.texture = _map_tex("floor_curb")
	if curb.texture == null:
		var rim := ColorRect.new()
		rim.color = Color(0.85, 0.72, 0.2, 0.85)
		rim.set_anchors_preset(Control.PRESET_TOP_WIDE)
		rim.offset_bottom = 8.0
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor.add_child(rim)
	else:
		floor.add_child(curb)

	var gloss := ColorRect.new()
	gloss.name = "WetGloss"
	gloss.color = Color(0.35, 0.55, 0.85, 0.07)
	gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	gloss.offset_top = 20.0
	gloss.offset_bottom = -8.0
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.add_child(gloss)

	var shade := get_node_or_null("GroundShade") as ColorRect
	if shade:
		shade.offset_top = -350.0
		shade.color = Color(0.02, 0.03, 0.05, 0.65)
		shade.z_index = 1


func _map_tex(name: String) -> Texture2D:
	## Carga PNG del mapa (prioriza disco: evita .import rotos).
	var path := MAP_DIR + name + ".png"
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res as Texture2D
	return null


func _make_asphalt_tex() -> Texture2D:
	var img := Image.create(320, 80, false, Image.FORMAT_RGBA8)
	for y in range(80):
		for x in range(320):
			var n := float((x * 17 + y * 31) % 23) / 23.0
			var n2 := float((x * 7 + y * 13) % 11) / 11.0
			var edge := absf(float(y) / 80.0 - 0.48)
			var v := 0.11 + n * 0.08 + n2 * 0.03 - edge * 0.06
			var a := 0.98 - edge * 0.5
			img.set_pixel(x, y, Color(v * 0.82, v * 0.86, v * 0.94, clampf(a, 0.2, 0.98)))
	for x in range(320):
		img.set_pixel(x, 14, Color(0.28, 0.3, 0.34, 0.6))
		img.set_pixel(x, 38, Color(0.07, 0.08, 0.1, 0.75))
		img.set_pixel(x, 62, Color(0.18, 0.2, 0.24, 0.45))
	# Grietas verticales suaves
	for i in range(8):
		var cx := 20 + i * 38
		for y in range(10, 70):
			if (y + i * 3) % 5 == 0:
				img.set_pixel(cx + (y % 3) - 1, y, Color(0.05, 0.05, 0.07, 0.55))
	return ImageTexture.create_from_image(img)


func _ensure_player_block_bar() -> void:
	if _player_block_bar and is_instance_valid(_player_block_bar):
		return
	var parent := player_hp_bar.get_parent()
	if parent == null:
		return
	player_hp_bar.custom_minimum_size = Vector2(0, 10)
	player_hp_text.add_theme_font_size_override("font_size", 11)
	_player_block_bar = ProgressBar.new()
	_player_block_bar.name = "PlayerBlockBar"
	_player_block_bar.custom_minimum_size = Vector2(0, 10)
	_player_block_bar.max_value = 20
	_player_block_bar.value = 0
	_player_block_bar.show_percentage = false
	_player_block_bar.visible = false
	parent.add_child(_player_block_bar)
	_player_block_text = Label.new()
	_player_block_text.name = "PlayerBlockText"
	_player_block_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_block_text.add_theme_font_size_override("font_size", 11)
	_player_block_text.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_player_block_text.visible = false
	parent.add_child(_player_block_text)
	# Orden: barras arriba, sprite abajo (pies al suelo)
	var actor := parent.get_node_or_null("PlayerActor")
	if actor:
		parent.move_child(player_hp_bar, 0)
		parent.move_child(player_hp_text, 1)
		parent.move_child(_player_block_bar, 2)
		parent.move_child(_player_block_text, 3)
		parent.move_child(actor, parent.get_child_count() - 1)


func _process(delta: float) -> void:
	if not visible:
		return
	# Movimiento suave y constante aunque haya acciones (salvo actors bloqueados).
	_bob_t += delta
	if not _busy:
		_tick_hero_pose()
	_idle_bob_player(delta)
	_idle_bob_enemies(delta)


func _idle_bob_player(delta: float = 0.016) -> void:
	if _player_actor == null or not is_instance_valid(_player_actor):
		return
	if bool(player_sprite.get_meta("anim_locked", false)):
		return
	# Solo respiración/lateral; Y fijo en el suelo (cero flotación)
	var sway := cos(_bob_t * 0.9) * 0.6
	var planted: Vector2 = player_sprite.get_meta("plant_pos", Vector2.ZERO)
	var target := planted + Vector2(sway, 0.0)
	player_sprite.position = player_sprite.position.lerp(target, 1.0 - exp(-delta * 8.0))
	var breath := 1.0 + sin(_bob_t * 1.55) * 0.018
	player_sprite.scale = player_sprite.scale.lerp(Vector2(breath, 2.0 - breath), 1.0 - exp(-delta * 6.5))
	if _player_shadow:
		_layout_ground_shadow(_player_shadow, _player_actor, 118.0)
		var squash := 1.0 + sin(_bob_t * 1.55) * 0.05
		_player_shadow.scale = _player_shadow.scale.lerp(Vector2(squash, 1.0), 1.0 - exp(-delta * 6.0))
		_player_shadow.modulate.a = lerpf(_player_shadow.modulate.a, 0.86 + absf(sin(_bob_t * 1.55)) * 0.06, 1.0 - exp(-delta * 5.0))


func _idle_bob_enemies(delta: float = 0.016) -> void:
	var i := 0
	for wrap in enemies_row.get_children():
		if not is_instance_valid(wrap):
			continue
		if bool(wrap.get_meta("fallen", false)):
			continue
		if bool(wrap.get_meta("anim_locked", false)):
			continue
		var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
		var shadow: TextureRect = wrap.find_child("Shadow", true, false)
		if spr == null:
			continue
		var is_boss := bool(wrap.get_meta("is_boss", false))
		var amp := 0.0  # pies clavados al suelo (sin bob vertical)
		var sway := 1.0 if is_boss else 0.7
		var speed := 1.25 if is_boss else 1.55
		var phase := _bob_t * speed + float(i) * 0.95
		var base_pos: Vector2 = wrap.get_meta("sprite_base", Vector2(0, 0))
		var target := base_pos + Vector2(cos(phase * 0.7) * sway, sin(phase) * amp)
		spr.position = spr.position.lerp(target, 1.0 - exp(-delta * 7.0))
		var pulse := 1.0 + sin(phase * 0.55) * (0.02 if is_boss else 0.014)
		var rot := sin(phase * 0.4) * (1.6 if is_boss else 0.9)
		spr.scale = spr.scale.lerp(Vector2(pulse, 2.0 - pulse), 1.0 - exp(-delta * 6.0))
		spr.rotation_degrees = lerpf(spr.rotation_degrees, rot, 1.0 - exp(-delta * 5.5))
		if shadow:
			var squash := 1.0 + sin(phase) * (0.05 if is_boss else 0.035)
			shadow.scale = shadow.scale.lerp(Vector2(squash * (1.1 if is_boss else 1.0), 1.0), 1.0 - exp(-delta * 6.0))
			shadow.modulate.a = lerpf(shadow.modulate.a, 0.72 + absf(sin(phase)) * 0.08, 1.0 - exp(-delta * 5.0))
		i += 1


func open_for_mission(mission_id: String, patrol_id: String = "alpha") -> void:
	var cfg := GameState.build_combat_config(mission_id, patrol_id)
	if cfg.is_empty():
		RadioBus.push("No se pudo iniciar la intervención.", "alert")
		return
	_closing = false
	_busy = false
	_hero_pose = "idle"
	_hero_pose_until = 0.0
	_bob_t = 0.0
	_gone_enemies.clear()
	_dying.clear()
	_arena_path = str(cfg.get("arena_path", ""))
	result_panel.visible = false
	_prev_enemy_hp.clear()
	_prev_player_hp = -1
	_prev_player_block = 0
	visible = true
	CombatState.start_combat(cfg)
	_load_bg()
	_apply_hero_pose("idle")
	_refresh()
	await get_tree().process_frame
	if _player_actor:
		_player_base_pos = _player_actor.position
		_layout_ground_shadow(_player_shadow, _player_actor, 160.0)


func close() -> void:
	visible = false
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _style_bottom_panel() -> void:
	var bottom := get_node_or_null("Bottom") as MarginContainer
	if bottom:
		# Altura normal del menú — no media pantalla
		bottom.offset_top = -260.0
	var arena := get_node_or_null("Arena") as Control
	if arena:
		arena.offset_bottom = -260.0
	var panel := get_node_or_null("Bottom/BottomPanel")
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.05, 0.08, 0.92)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)


func _ensure_enemy_hand_ui() -> void:
	## Cartas enemigas en el hueco horizontal del menú (junto a TU MANO), sin subir la altura.
	var bottom_row := get_node_or_null("Bottom/BottomPanel/BottomRow") as HBoxContainer
	var hand_col := get_node_or_null("Bottom/BottomPanel/BottomRow/HandCol") as VBoxContainer
	if bottom_row == null:
		return
	# Limpiar layout apilado antiguo dentro de HandCol
	if hand_col:
		for child_name in ["EnemyHandLabel", "EnemyHandRow", "PlayerHandLabel"]:
			var junk := hand_col.get_node_or_null(child_name)
			if junk:
				hand_col.remove_child(junk)
				junk.free()
	var col := bottom_row.get_node_or_null("EnemyHandCol") as VBoxContainer
	if col == null:
		col = VBoxContainer.new()
		col.name = "EnemyHandCol"
		col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_theme_constant_override("separation", 2)
		bottom_row.add_child(col)
		# Entre Piles y HandCol = el hueco vacío de la izquierda
		if hand_col:
			bottom_row.move_child(col, hand_col.get_index())
	_enemy_hand_label = col.get_node_or_null("EnemyHandLabel") as Label
	if _enemy_hand_label == null:
		_enemy_hand_label = Label.new()
		_enemy_hand_label.name = "EnemyHandLabel"
		_enemy_hand_label.text = "ELLOS"
		_enemy_hand_label.add_theme_font_size_override("font_size", 11)
		_enemy_hand_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.38))
		_enemy_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_enemy_hand_label)
	_enemy_hand_row = col.get_node_or_null("EnemyHandRow") as HBoxContainer
	if _enemy_hand_row == null:
		_enemy_hand_row = HBoxContainer.new()
		_enemy_hand_row.name = "EnemyHandRow"
		_enemy_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_enemy_hand_row.add_theme_constant_override("separation", 8)
		_enemy_hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(_enemy_hand_row)
	_hand_label = null


func _style_end_btn() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.45, 0.92)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	end_turn_btn.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate()
	h.bg_color = Color(0.22, 0.55, 1.0)
	end_turn_btn.add_theme_stylebox_override("hover", h)
	end_turn_btn.add_theme_font_size_override("font_size", 14)


func _on_log(text: String) -> void:
	log_label.text = text


func _on_end_turn() -> void:
	if _busy or CombatState.phase != CombatState.Phase.PLAYER:
		return
	_busy = true
	end_turn_btn.disabled = true
	await _play_enemy_attack_sequence()
	CombatState.end_player_turn()
	_busy = false
	_refresh()


func _on_combat_ended(victory: bool) -> void:
	result_panel.visible = true
	if victory:
		var xp := CombatState.combat_xp_gained
		var kills := CombatState.combat_kills
		var levels := CombatState.combat_levels_gained
		if levels > 0:
			result_title.text = "¡NIVEL %d!  +%d XP" % [GameState.hero_level, xp]
		elif xp > 0:
			result_title.text = "ÉXITO  ·  +%d XP (%d bajas)" % [xp, kills]
		else:
			result_title.text = "INTERVENCIÓN EXITOSA"
		result_title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
	else:
		result_title.text = "UNIDAD CAÍDA"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _on_result_close() -> void:
	if _closing:
		return
	_closing = true
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	if dispatch and dispatch.has_method("show_pending_combat_result"):
		dispatch.show_pending_combat_result("alpha")
	else:
		close()


func _refresh() -> void:
	if not visible:
		return
	var snap := CombatState.get_snapshot()
	var p: Dictionary = snap.get("player", {})
	title_label.text = "THE QUEST FINAL"
	turn_label.text = "PATRULLA — TURNO %d" % int(snap.get("turn", 1))
	hp_label.text = "%d/%d" % [int(p.get("hp", 0)), int(p.get("max_hp", 50))]
	block_label.text = str(int(p.get("block", 0)))
	location_label.text = str(snap.get("location", "")).to_upper()
	var xp_bit := "NV.%d  %d/%d XP" % [
		int(snap.get("hero_level", GameState.hero_level)),
		int(snap.get("hero_xp", GameState.hero_xp)),
		int(snap.get("xp_to_next", GameState.xp_to_next_level())),
	]
	if int(snap.get("combat_xp", 0)) > 0:
		xp_bit += "  ·  +%d este combate" % int(snap.get("combat_xp", 0))
	objective_label.text = "OBJETIVO: %s   |   %s" % [str(snap.get("objective", "")), xp_bit]
	log_label.text = str(snap.get("last_log", ""))
	deck_count.text = "MAZO\n%d" % int(snap.get("draw_count", 0))
	discard_count.text = "DESCARTES\n%d" % int(snap.get("discard_count", 0))
	_style_player_bars(p)

	var php := int(p.get("hp", 0))
	if _prev_player_hp >= 0 and php < _prev_player_hp and not _busy:
		_apply_hero_pose("hurt", 0.55)
		_hit_actor(player_sprite, _prev_player_hp - php, false)
		_spawn_blood_burst(player_sprite.global_position + Vector2(50, 90), 1.1)
	_prev_player_hp = php
	_prev_player_block = int(p.get("block", 0))

	_tick_hero_pose()
	if player_sprite.texture == null:
		_apply_hero_pose(_hero_pose)

	_load_bg()
	if not _busy:
		_rebuild_enemies(snap)
	_rebuild_enemy_hand(snap)
	_rebuild_hand(snap)
	_rebuild_energy(snap)

	var can_act: bool = int(snap.get("phase", 0)) == CombatState.Phase.PLAYER and bool(snap.get("active", false)) and not _busy
	end_turn_btn.disabled = not can_act
	end_turn_btn.text = "FINALIZAR TURNO" if can_act else "..."


func _style_bar(bar: ProgressBar, fill_col: Color, h: float = 10.0) -> void:
	bar.custom_minimum_size.y = h
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	var bgb := StyleBoxFlat.new()
	bgb.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	bgb.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bgb)


func _style_player_bars(p: Dictionary) -> void:
	_ensure_player_block_bar()
	player_hp_bar.max_value = float(p.get("max_hp", 50))
	player_hp_bar.value = float(p.get("hp", 0))
	_style_bar(player_hp_bar, Color(0.86, 0.22, 0.28), 10.0)
	player_hp_text.text = "%d / %d" % [int(p.get("hp", 0)), int(p.get("max_hp", 50))]
	var blk := int(p.get("block", 0))
	if _player_block_bar:
		_player_block_bar.visible = blk > 0
		_player_block_bar.max_value = maxf(20.0, float(blk))
		_player_block_bar.value = float(blk)
		_style_bar(_player_block_bar, Color(0.35, 0.72, 1.0), 10.0)
	if _player_block_text:
		_player_block_text.visible = blk > 0
		_player_block_text.text = "ESCUDO  %d" % blk


func _load_bg() -> void:
	# Mapa físico propio primero → misión → roster → clásico
	var candidates: Array = []
	candidates.append(PHYSICS_ARENA)
	if _arena_path != "":
		candidates.append(_arena_path)
	for a in CombatRoster.arenas:
		candidates.append(str(a.get("path", "")))
	candidates.append_array([
		"res://assets/combat/bg/alley_night.jpg",
		"res://assets/combat/bg/alley_night2.jpg",
		"res://assets/combat/bg/combat_arena.jpg",
	])
	for path in candidates:
		if str(path) == "":
			continue
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is Texture2D:
				tex = res
		if tex == null and FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img:
				tex = ImageTexture.create_from_image(img)
		if tex:
			bg.texture = tex
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			return


func _rebuild_enemies(snap: Dictionary) -> void:
	# No destruir paneles mientras hay muerte/hit en curso (rompe tweens).
	if _busy or not _dying.is_empty():
		_sync_enemy_stats(snap)
		return
	for c in enemies_row.get_children():
		c.queue_free()
	var enemies: Array = snap.get("enemies", [])
	var selected := int(snap.get("selected_enemy", 0))
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		var hp_now := int(e.get("hp", 0))
		var prev := int(_prev_enemy_hp.get(i, hp_now))
		if bool(_gone_enemies.get(i, false)):
			enemies_row.add_child(_make_empty_slot(i))
			_prev_enemy_hp[i] = hp_now
			continue
		var panel := _make_enemy_panel(e, i, i == selected)
		enemies_row.add_child(panel)
		if prev > 0 and hp_now <= 0 and not _busy and not bool(_dying.get(i, false)):
			call_deferred("_start_enemy_death", panel, i, prev)
		elif prev > hp_now and hp_now > 0 and not _busy:
			call_deferred("_animate_enemy_hit", panel, prev - hp_now)
		_prev_enemy_hp[i] = hp_now


func _sync_enemy_stats(snap: Dictionary) -> void:
	## Actualiza HP/bloque en paneles existentes sin liberarlos.
	var enemies: Array = snap.get("enemies", [])
	var selected := int(snap.get("selected_enemy", 0))
	for panel in enemies_row.get_children():
		if not (panel is Control):
			continue
		var i := int(panel.get_meta("enemy_index", -1))
		if i < 0 or i >= enemies.size():
			continue
		var e: Dictionary = enemies[i]
		var hp_now := int(e.get("hp", 0))
		var prev := int(_prev_enemy_hp.get(i, hp_now))
		# Conserva prev>0 si acaba de caer a 0, para poder animar muerte al rebuild.
		if not (prev > 0 and hp_now <= 0):
			_prev_enemy_hp[i] = hp_now
		var hp_bar: ProgressBar = panel.find_child("HpBar", true, false) as ProgressBar
		if hp_bar:
			hp_bar.max_value = float(e.get("max_hp", hp_bar.max_value))
			hp_bar.value = float(hp_now)
		var hp_txt: Label = panel.find_child("HpText", true, false) as Label
		if hp_txt:
			hp_txt.text = "%d/%d" % [hp_now, int(e.get("max_hp", hp_now))]
		panel.modulate = Color(1.08, 1.08, 1.0) if i == selected else Color.WHITE
		if bool(e.get("detained", false)) or bool(e.get("fled", false)) or hp_now <= 0:
			panel.modulate = Color(0.55, 0.55, 0.6, 0.75)


func _make_empty_slot(index: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(160, 400)
	wrap.set_meta("enemy_index", index)
	wrap.set_meta("fallen", true)
	return wrap


func _animate_enemy_hit(panel: Control, dmg: int) -> void:
	if not is_instance_valid(panel):
		return
	var spr := panel.find_child("EnemySprite", true, false)
	if spr == null:
		return
	var is_boss := bool(panel.get_meta("is_boss", false))
	var hurt_path := str(panel.get_meta("pose_hurt", ""))
	var idle_tex: Texture2D = spr.texture
	var base: Vector2 = panel.get_meta("sprite_base", spr.position)
	panel.set_meta("anim_locked", true)
	if is_boss and hurt_path != "" and (ResourceLoader.exists(hurt_path) or FileAccess.file_exists(hurt_path)):
		var ht := _load_combat_tex(hurt_path)
		if ht:
			spr.texture = ht
	if is_boss:
		_hit_actor_heavy(spr, dmg, true)
		spr.modulate = Color(2.0, 1.6, 1.6)
		_spawn_fx_at(spr, "impact", Vector2(48, 100), 0.35)
		_spawn_blood_burst(spr.global_position + Vector2(56, 110), 1.25)
		await _screen_pulse(Color(1.0, 0.35, 0.2, 0.28))
		await get_tree().create_timer(0.18).timeout
		if is_instance_valid(spr):
			spr.modulate = Color.WHITE
			spr.position = base
			if idle_tex:
				spr.texture = idle_tex
	else:
		_hit_actor(spr, dmg, true)
		_spawn_fx_at(spr, "impact", Vector2(40, 90), 0.3)
		_spawn_blood_burst(spr.global_position + Vector2(50, 100), 1.15)
		await get_tree().create_timer(0.2).timeout
	if is_instance_valid(panel):
		panel.set_meta("anim_locked", false)


func _start_enemy_death(panel: Control, index: int, last_dmg: int) -> void:
	if not is_instance_valid(panel) or bool(_dying.get(index, false)):
		return
	_dying[index] = true
	await _animate_enemy_death(panel, last_dmg)
	_gone_enemies[index] = true
	_dying.erase(index)
	if is_instance_valid(panel):
		panel.queue_free()
		enemies_row.add_child(_make_empty_slot(index))


func _animate_enemy_death(panel: Control, dmg: int) -> void:
	var actor: Control = panel.get_node_or_null("ActorSlot")
	var spr: TextureRect = panel.find_child("EnemySprite", true, false)
	var shadow: TextureRect = panel.find_child("Shadow", true, false)
	var is_boss := bool(panel.get_meta("is_boss", false))
	var hurt_path := str(panel.get_meta("pose_hurt", ""))
	if spr and is_boss and hurt_path != "" and (ResourceLoader.exists(hurt_path) or FileAccess.file_exists(hurt_path)):
		var ht := _load_combat_tex(hurt_path)
		if ht:
			spr.texture = ht
	if spr:
		_spawn_dmg_number(spr, dmg)
		_spawn_fx_at(spr, "impact", Vector2(40, 90), 0.3)
		_spawn_blood_burst(spr.global_position + Vector2(40, 100), 1.4)
		if is_boss:
			_spawn_blood_burst(spr.global_position + Vector2(70, 80), 1.2)
			_screen_pulse(Color(1.0, 0.2, 0.15, 0.35))
	if actor == null or spr == null:
		await get_tree().create_timer(0.35).timeout
		return
	var tws := create_tween()
	tws.tween_property(spr, "modulate", Color(1.0, 0.25, 0.25), 0.06)
	tws.tween_property(spr, "position", spr.position + Vector2(16, -6), 0.08)
	tws.tween_property(spr, "modulate", Color(0.7, 0.7, 0.7), 0.1)
	await tws.finished
	spr.pivot_offset = Vector2(spr.size.x * 0.5, spr.size.y)
	var twb := create_tween()
	twb.set_parallel(true)
	twb.tween_property(spr, "scale", Vector2(1.12, 0.82), 0.12)
	twb.tween_property(spr, "rotation_degrees", 18.0, 0.12)
	await twb.finished
	var fall_t := 0.62 if is_boss else 0.38
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "rotation_degrees", 92.0, fall_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "position", Vector2(22, 88 if not is_boss else 110), fall_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "scale", Vector2(1.05, 0.7), fall_t)
	tw.tween_property(spr, "modulate", Color(0.45, 0.45, 0.48, 1.0), fall_t * 0.8)
	if shadow:
		tw.tween_property(shadow, "modulate:a", 0.2, fall_t)
		tw.tween_property(shadow, "scale", Vector2(1.5, 0.55), fall_t)
	await tw.finished
	_spawn_fx_world(spr.global_position + Vector2(40, 20), "impact", 0.25, Vector2(0.7, 0.7), Color(0.6, 0.6, 0.6))
	var twr := create_tween()
	twr.tween_property(spr, "position:y", spr.position.y - 8.0, 0.08)
	twr.tween_property(spr, "position:y", spr.position.y, 0.1)
	await twr.finished
	await get_tree().create_timer(0.55 if is_boss else 0.35).timeout
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(panel, "modulate:a", 0.0, 0.65 if is_boss else 0.5)
	if shadow:
		tw2.tween_property(shadow, "modulate:a", 0.0, 0.5)
	await tw2.finished


func _make_enemy_panel(e: Dictionary, index: int, selected: bool) -> Control:
	var is_boss := bool(e.get("is_boss", false))
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(260 if is_boss else 220, 380 if is_boss else 340)
	wrap.alignment = BoxContainer.ALIGNMENT_END
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.set_meta("enemy_index", index)
	wrap.set_meta("is_boss", is_boss)
	wrap.set_meta("pose_attack", str(e.get("pose_attack", "")))
	wrap.set_meta("pose_hurt", str(e.get("pose_hurt", "")))
	wrap.set_meta("idle_sprite", str(e.get("sprite", "")))

	var name_l := Label.new()
	name_l.text = str(e.get("name", "Sospechoso"))
	if is_boss:
		name_l.text = "★ " + name_l.text
		name_l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
		name_l.add_theme_font_size_override("font_size", 16)
	elif selected and int(e.get("hp", 0)) > 0:
		name_l.text = "▸ " + name_l.text
		name_l.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
		name_l.add_theme_font_size_override("font_size", 13)
	else:
		name_l.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
		name_l.add_theme_font_size_override("font_size", 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(name_l)

	var alias := str(e.get("alias", ""))
	if alias != "":
		var alias_l := Label.new()
		alias_l.text = alias
		alias_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alias_l.add_theme_font_size_override("font_size", 10)
		alias_l.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88, 0.9))
		wrap.add_child(alias_l)

	# Barras ENCIMA del cuerpo (no bajo los pies) para no flotar
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(168 if is_boss else 132, 10 if is_boss else 8)
	hp_bar.max_value = float(e.get("max_hp", 1))
	hp_bar.value = float(maxi(0, int(e.get("hp", 0))))
	_style_bar(hp_bar, Color(0.95, 0.35, 0.18) if is_boss else Color(0.86, 0.22, 0.28), 10.0 if is_boss else 8.0)
	bars.add_child(hp_bar)
	var hp_t := Label.new()
	hp_t.name = "HpText"
	hp_t.text = "%d/%d" % [maxi(0, int(e.get("hp", 0))), int(e.get("max_hp", 0))]
	hp_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_t.add_theme_font_size_override("font_size", 11 if is_boss else 10)
	hp_t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55) if is_boss else Color(0.85, 0.88, 0.92))
	bars.add_child(hp_t)
	var blk := int(e.get("block", 0))
	if blk > 0:
		var blk_bar := ProgressBar.new()
		blk_bar.custom_minimum_size = Vector2(168 if is_boss else 132, 6)
		blk_bar.max_value = maxf(12.0, float(blk))
		blk_bar.value = float(blk)
		_style_bar(blk_bar, Color(0.35, 0.72, 1.0), 6.0)
		bars.add_child(blk_bar)
		var blk_t := Label.new()
		blk_t.text = "ESCUDO %d" % blk
		blk_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blk_t.add_theme_font_size_override("font_size", 9)
		blk_t.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		bars.add_child(blk_t)
	wrap.add_child(bars)

	var actor_w := 260.0 if is_boss else 210.0
	var ground_y := GROUND_Y + (18.0 if is_boss else 0.0)
	var actor_h := ground_y + 6.0  # sin hueco bajo los pies
	var actor := Control.new()
	actor.name = "ActorSlot"
	actor.custom_minimum_size = Vector2(actor_w, actor_h)
	actor.clip_contents = false

	var shadow := TextureRect.new()
	shadow.name = "Shadow"
	shadow.texture = _map_tex("foot_shadow")
	if shadow.texture == null:
		shadow.texture = _fx_tex("shadow")
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = Color(0.02, 0.02, 0.04, 0.9)
	shadow.position = Vector2(14, ground_y - 1.0)
	shadow.size = Vector2(actor_w - 28.0, 40 if is_boss else 34)
	shadow.pivot_offset = Vector2((actor_w - 28.0) * 0.5, 18)
	actor.add_child(shadow)

	var btn := Button.new()
	btn.name = "SelectBtn"
	btn.position = Vector2.ZERO
	btn.size = Vector2(actor_w, ground_y)
	btn.flat = true
	btn.clip_contents = false
	var tex := TextureRect.new()
	tex.name = "EnemySprite"
	# Pies anclados al suelo (aspect completo, sin crop COVERED)
	var slot := Vector2(actor_w, ground_y)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Prioridad: sprite propio del enemigo (boss) → pack por índice
	var sp := str(e.get("sprite", ""))
	if sp == "" or not (ResourceLoader.exists(sp) or FileAccess.file_exists(sp)):
		sp = PACK_FOE + "enemy_%d.png" % (index % 7)
	if not (ResourceLoader.exists(sp) or FileAccess.file_exists(sp)):
		sp = PACK_FOE + "enemy_0.png"
	var loaded: Texture2D = _load_combat_tex(sp)
	if loaded:
		tex.texture = loaded
	_bottom_plant_texture(tex, slot)
	# Convención: assets enemigo miran a la IZQUIERDA (hacia García).
	# Si algún enemigo viene con face=right, se espeja.
	tex.flip_h = str(e.get("face", "left")) == "right"
	btn.add_child(tex)
	btn.pressed.connect(func(): CombatState.select_enemy(index))
	actor.add_child(btn)
	wrap.add_child(actor)
	wrap.set_meta("sprite_base", tex.get_meta("plant_pos", tex.position))

	if bool(e.get("detained", false)) or bool(e.get("fled", false)):
		wrap.modulate = Color(0.55, 0.55, 0.58, 0.85)
	return wrap


func _rebuild_hand(snap: Dictionary) -> void:
	for c in hand_row.get_children():
		c.queue_free()
	var hand: Array = snap.get("hand", [])
	var can_act: bool = int(snap.get("phase", 0)) == CombatState.Phase.PLAYER and bool(snap.get("active", false)) and not _busy
	for card_id in hand:
		var cid := str(card_id)
		hand_row.add_child(_make_card(cid, can_act and CombatState.can_play_card(cid)))


func _rebuild_enemy_hand(snap: Dictionary) -> void:
	_ensure_enemy_hand_ui()
	if _enemy_hand_row == null:
		return
	for c in _enemy_hand_row.get_children():
		c.queue_free()
	var enemies: Array = snap.get("enemies", [])
	var shown := 0
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if int(e.get("hp", 0)) <= 0 or bool(e.get("detained", false)) or bool(e.get("fled", false)):
			continue
		var cid := str(e.get("next_card", ""))
		if cid == "":
			continue
		var def: Dictionary = CardDB.get_enemy_card(cid)
		if def.is_empty():
			def = {
				"id": cid,
				"name": str(e.get("next_card_name", cid)),
				"effect": str(e.get("next_card_effect", "")),
				"kind": "attack",
			}
		_enemy_hand_row.add_child(_make_bottom_enemy_card(def, str(e.get("name", "Sospechoso")), i))
		shown += 1
	if _enemy_hand_label:
		_enemy_hand_label.text = "ELLOS" if shown > 0 else "ELLOS · —"
	if shown == 0:
		var empty := Label.new()
		empty.text = "—"
		empty.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		_enemy_hand_row.add_child(empty)


func _make_bottom_enemy_card(def: Dictionary, owner_name: String, enemy_index: int) -> Control:
	## Carta grande en el panel inferior — mismo lenguaje visual que tu mano.
	var kind := CardDB.enemy_card_intent_kind(def)
	var is_boss := str(def.get("id", "")).begins_with("boss_")
	var accent := _enemy_kind_accent(kind, is_boss)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(104, 168)
	panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.045, 0.05, 0.97)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.95)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	margin.add_child(v)

	var owner_l := Label.new()
	owner_l.text = owner_name
	owner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_l.add_theme_font_size_override("font_size", 9)
	owner_l.add_theme_color_override("font_color", Color(0.85, 0.7, 0.6))
	owner_l.clip_text = true
	v.add_child(owner_l)

	var top := HBoxContainer.new()
	v.add_child(top)
	var badge := Label.new()
	match kind:
		"block":
			badge.text = "◈ DEF"
		"heal":
			badge.text = "+ CURA"
		"flee":
			badge.text = "→ HUIR"
		_:
			badge.text = "● ATK"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", accent)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(badge)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 54)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var aimg := Image.load_from_file(art_path)
		if aimg:
			art.texture = ImageTexture.create_from_image(aimg)
	v.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", "?"))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.clip_text = true
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	v.add_child(name_l)

	var fx := Label.new()
	fx.text = CardDB.enemy_effect_line(def)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.max_lines_visible = 2
	fx.clip_text = true
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.add_theme_font_size_override("font_size", 11)
	fx.add_theme_color_override("font_color", Color(0.8, 0.88, 0.96))
	v.add_child(fx)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.tooltip_text = "Ver mazo completo de %s" % owner_name
	var idx := enemy_index
	btn.pressed.connect(func(): _open_enemy_card_menu(idx))
	panel.add_child(btn)
	return panel


func _type_accent(card_type: String) -> Color:
	match card_type:
		"ataque":
			return Color(0.95, 0.4, 0.35)
		"defensa":
			return Color(0.4, 0.75, 1.0)
		"control", "tactica":
			return Color(0.55, 0.9, 0.65)
		"cura":
			return Color(0.45, 0.95, 0.7)
		"utilidad", "especial":
			return Color(0.95, 0.75, 0.35)
		_:
			return Color(0.55, 0.65, 0.75)


func _refresh_enemy_intent_host(host: Control, e: Dictionary, enemy_index: int = -1) -> void:
	if enemy_index < 0:
		enemy_index = int(host.get_meta("enemy_index", -1))
	else:
		host.set_meta("enemy_index", enemy_index)
	while host.get_child_count() > 0:
		var old := host.get_child(0)
		host.remove_child(old)
		old.free()
	host.add_child(_build_enemy_intent_content(e, enemy_index))


func _build_enemy_intent_content(e: Dictionary, enemy_index: int = -1) -> Control:
	if bool(e.get("detained", false)):
		return _enemy_intent_status("DETENIDO", Color(0.4, 0.9, 0.55))
	if bool(e.get("fled", false)):
		return _enemy_intent_status("HUYÓ", Color(0.8, 0.8, 0.85))
	if int(e.get("hp", 0)) <= 0:
		return _enemy_intent_status("", Color.WHITE)
	var cid := str(e.get("next_card", ""))
	if cid != "":
		return _make_enemy_intent_card(e, enemy_index)
	# Fallback a intent clásico sin carta
	var intent_id := int(e.get("intent", 0))
	var val := int(e.get("intent_value", 0))
	var is_boss := bool(e.get("is_boss", false))
	var txt := CombatState.intent_label(intent_id)
	var col := Color(0.9, 0.92, 0.96)
	if intent_id == CombatState.Intent.ATTACK and val > 0:
		txt = ("◆  %d" % val) if is_boss else ("●  %d" % val)
		col = Color(1.0, 0.38, 0.38)
	elif intent_id == CombatState.Intent.BLOCK and val > 0:
		txt = "◈  %d" % val
		col = Color(0.45, 0.8, 1.0)
	elif intent_id == CombatState.Intent.FLEE:
		txt = "→ HUIR"
		col = Color(1.0, 0.78, 0.35)
	return _enemy_intent_status(txt, col)


func _enemy_intent_status(text: String, col: Color) -> Control:
	var l := Label.new()
	l.name = "IntentLabel"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	l.custom_minimum_size = Vector2(96, 36)
	return l


func _enemy_kind_accent(kind: String, is_boss: bool) -> Color:
	match kind:
		"block":
			return Color(0.42, 0.82, 1.0)
		"heal":
			return Color(0.45, 0.9, 0.55)
		"flee":
			return Color(1.0, 0.78, 0.35)
		"weaken", "vulnerable", "stun", "status":
			return Color(0.95, 0.62, 0.35)
		_:
			return Color(1.0, 0.48, 0.28) if is_boss else Color(1.0, 0.4, 0.36)


func _enemy_kind_frame(kind: String, is_boss: bool) -> String:
	if is_boss:
		return "fuerza" if kind == "attack" else "magica"
	match kind:
		"block", "heal":
			return "magica"
		"flee", "weaken", "vulnerable", "stun", "status":
			return "basica"
		_:
			return "basica"


func _make_enemy_intent_card(e: Dictionary, enemy_index: int = -1) -> Control:
	var cid := str(e.get("next_card", ""))
	var def: Dictionary = CardDB.get_enemy_card(cid)
	if def.is_empty():
		def = {
			"id": cid,
			"name": str(e.get("next_card_name", cid)),
			"effect": str(e.get("next_card_effect", "")),
			"kind": "attack",
		}
	var is_boss := bool(e.get("is_boss", false))
	var kind := CardDB.enemy_card_intent_kind(def)
	var accent := _enemy_kind_accent(kind, is_boss)
	var rarity := _enemy_kind_frame(kind, is_boss)
	var w := 108.0 if is_boss else 100.0
	var h := 158.0 if is_boss else 148.0

	var panel := PanelContainer.new()
	panel.name = "EnemyIntentCard"
	panel.custom_minimum_size = Vector2(w, h)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("card_id", cid)
	panel.tooltip_text = "Clic: ver mazo enemigo"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.045, 0.05, 0.97) if is_boss else Color(0.05, 0.055, 0.08, 0.97)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.95)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", sb)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(w - 4.0, h - 4.0)
	stack.clip_contents = true
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)

	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(accent.r, accent.g, accent.b, 0.55)
	var fp := CardDB.frame_path(rarity)
	if ResourceLoader.exists(fp):
		frame.texture = load(fp)
	elif FileAccess.file_exists(fp):
		var fimg := Image.load_from_file(fp)
		if fimg:
			frame.texture = ImageTexture.create_from_image(fimg)
	stack.add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(22, 22)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.4, 0.95)
	bsb.border_color = accent
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(11)
	badge.add_theme_stylebox_override("panel", bsb)
	top.add_child(badge)
	var badge_l := Label.new()
	match kind:
		"block":
			badge_l.text = "◈"
		"heal":
			badge_l.text = "+"
		"flee":
			badge_l.text = "→"
		_:
			badge_l.text = "◆" if is_boss else "●"
	badge_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_l.add_theme_font_size_override("font_size", 11)
	badge_l.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	badge.add_child(badge_l)

	var next_l := Label.new()
	match kind:
		"block":
			next_l.text = "DEFENSA"
		"heal":
			next_l.text = "CURA"
		"flee":
			next_l.text = "HUIDA"
		"weaken", "vulnerable", "stun", "status":
			next_l.text = "ESTADO"
		_:
			next_l.text = "ATAQUE"
	next_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_l.add_theme_font_size_override("font_size", 9)
	next_l.add_theme_color_override("font_color", accent)
	top.add_child(next_l)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 54 if is_boss else 48)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var aimg := Image.load_from_file(art_path)
		if aimg:
			art.texture = ImageTexture.create_from_image(aimg)
	v.add_child(art)

	var text_box := PanelContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.02, 0.03, 0.05, 0.84)
	tsb.set_corner_radius_all(7)
	tsb.content_margin_left = 4
	tsb.content_margin_right = 4
	tsb.content_margin_top = 3
	tsb.content_margin_bottom = 3
	text_box.add_theme_stylebox_override("panel", tsb)
	v.add_child(text_box)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	text_box.add_child(tv)

	var name_l := Label.new()
	name_l.text = str(def.get("name", e.get("next_card_name", cid)))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", 11 if is_boss else 10)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	tv.add_child(name_l)

	var fx := Label.new()
	var fx_txt := CardDB.enemy_effect_line(def)
	if fx_txt == "":
		fx_txt = str(e.get("next_card_effect", ""))
	fx.text = fx_txt
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.max_lines_visible = 2
	fx.clip_text = true
	fx.add_theme_font_size_override("font_size", 10)
	fx.add_theme_color_override("font_color", Color(accent.r * 0.85 + 0.15, accent.g * 0.85 + 0.15, accent.b * 0.85 + 0.15))
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(fx)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.tooltip_text = "Ver cartas de este enemigo"
	var idx := enemy_index
	btn.pressed.connect(func():
		_open_enemy_card_menu(idx)
	)
	panel.add_child(btn)

	return panel


func _open_enemy_card_menu(enemy_index: int) -> void:
	var snap := CombatState.get_snapshot()
	var enemies: Array = snap.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var e: Dictionary = enemies[enemy_index]
	_enemy_menu_enemy_index = enemy_index
	if _enemy_card_menu and is_instance_valid(_enemy_card_menu):
		_enemy_card_menu.queue_free()
	_enemy_card_menu = Control.new()
	_enemy_card_menu.name = "EnemyCardMenu"
	_enemy_card_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_card_menu.z_index = 80
	_enemy_card_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_enemy_card_menu)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_enemy_card_menu.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(920, 520)
	panel.position = Vector2(180, 80)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	psb.border_color = Color(1.0, 0.48, 0.32, 0.9)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 16
	psb.content_margin_right = 16
	psb.content_margin_top = 14
	psb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", psb)
	_enemy_card_menu.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "MAZO ENEMIGO  ·  %s" % str(e.get("name", "Sospechoso"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.55))
	head.add_child(title)
	var next_hint := Label.new()
	next_hint.text = "Siguiente: %s" % str(e.get("next_card_name", "—"))
	next_hint.add_theme_font_size_override("font_size", 13)
	next_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	head.add_child(next_hint)
	var close_b := Button.new()
	close_b.text = "CERRAR"
	close_b.custom_minimum_size = Vector2(100, 36)
	close_b.pressed.connect(_close_enemy_card_menu)
	head.add_child(close_b)

	var sub := Label.new()
	sub.text = "Cartas que puede jugar este sospechoso (mismo tamaño que tu mazo)."
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	root.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	root.add_child(scroll)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	scroll.add_child(grid)

	var pool: Array = e.get("card_pool", [])
	if pool.is_empty():
		pool = [str(e.get("next_card", ""))]
	var seen: Dictionary = {}
	for cid_v in pool:
		var cid := str(cid_v)
		if cid == "" or seen.has(cid):
			continue
		seen[cid] = true
		var def: Dictionary = CardDB.get_enemy_card(cid)
		if def.is_empty():
			continue
		var is_next := cid == str(e.get("next_card", ""))
		grid.add_child(_make_enemy_menu_card(def, is_next))

	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_enemy_card_menu()
	)


func _close_enemy_card_menu() -> void:
	if _enemy_card_menu and is_instance_valid(_enemy_card_menu):
		_enemy_card_menu.queue_free()
	_enemy_card_menu = null
	_enemy_menu_enemy_index = -1


func _make_enemy_menu_card(def: Dictionary, is_next: bool) -> Control:
	## Carta grande estilo mazo del jugador, dentro del menú de combate.
	var kind := CardDB.enemy_card_intent_kind(def)
	var accent := _enemy_kind_accent(kind, str(def.get("id", "")).begins_with("boss_"))
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(168, 248)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.06, 0.98)
	sb.border_color = accent if not is_next else Color(1.0, 0.85, 0.35)
	sb.set_border_width_all(3 if is_next else 2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	wrap.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	wrap.add_child(v)
	if is_next:
		var badge := Label.new()
		badge.text = "▶ SIGUIENTE"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		v.add_child(badge)
	var top := HBoxContainer.new()
	v.add_child(top)
	var kind_l := Label.new()
	kind_l.text = kind.to_upper()
	kind_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_l.add_theme_font_size_override("font_size", 11)
	kind_l.add_theme_color_override("font_color", accent)
	top.add_child(kind_l)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 100)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var img := Image.load_from_file(art_path)
		if img:
			art.texture = ImageTexture.create_from_image(img)
	v.add_child(art)
	var name_l := Label.new()
	name_l.text = str(def.get("name", "?"))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var fx := Label.new()
	fx.text = CardDB.enemy_effect_line(def)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.max_lines_visible = 3
	fx.add_theme_font_size_override("font_size", 12)
	fx.add_theme_color_override("font_color", Color(0.8, 0.88, 0.96))
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fx)
	var desc := Label.new()
	desc.text = str(def.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 3
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	v.add_child(desc)
	return wrap


func _make_card(card_id: String, playable: bool) -> Control:
	var def := CardDB.get_card(card_id)
	var card_type := str(def.get("type", ""))
	var rarity := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var accent := CardDB.rarity_color(rarity)
	var type_col := _type_accent(card_type)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(128, 200)
	panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.06, 0.09, 0.97)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.92 if playable else 0.3)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", sb)
	if not playable:
		panel.modulate = Color(0.62, 0.62, 0.66, 0.78)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(148, 232)
	stack.clip_contents = true
	panel.add_child(stack)

	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(accent.r, accent.g, accent.b, 0.5)
	var fp := CardDB.frame_path(rarity)
	if ResourceLoader.exists(fp):
		frame.texture = load(fp)
	elif FileAccess.file_exists(fp):
		var fimg := Image.load_from_file(fp)
		if fimg:
			frame.texture = ImageTexture.create_from_image(fimg)
	stack.add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)

	var cost_bg := PanelContainer.new()
	cost_bg.custom_minimum_size = Vector2(26, 26)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(type_col.r * 0.35, type_col.g * 0.35, type_col.b * 0.4, 0.95)
	csb.border_color = accent
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(13)
	cost_bg.add_theme_stylebox_override("panel", csb)
	top.add_child(cost_bg)
	var cost := Label.new()
	cost.text = str(int(def.get("cost", 0)))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	cost_bg.add_child(cost)

	var rar_l := Label.new()
	rar_l.text = CardDB.rarity_label(rarity)
	rar_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rar_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rar_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rar_l.add_theme_font_size_override("font_size", 10)
	rar_l.add_theme_color_override("font_color", accent)
	top.add_child(rar_l)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 86)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var aimg := Image.load_from_file(art_path)
		if aimg:
			art.texture = ImageTexture.create_from_image(aimg)
	v.add_child(art)

	var text_box := PanelContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.custom_minimum_size = Vector2(0, 62)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.02, 0.035, 0.055, 0.82)
	tsb.set_corner_radius_all(8)
	tsb.content_margin_left = 6
	tsb.content_margin_right = 6
	tsb.content_margin_top = 5
	tsb.content_margin_bottom = 5
	text_box.add_theme_stylebox_override("panel", tsb)
	v.add_child(text_box)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	text_box.add_child(tv)

	var name_l := Label.new()
	name_l.text = str(def.get("name", card_id))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	name_l.custom_minimum_size = Vector2(0, 28)
	tv.add_child(name_l)

	var fx := Label.new()
	fx.text = CardDB.effect_line(def)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.max_lines_visible = 2
	fx.clip_text = true
	fx.add_theme_font_size_override("font_size", 12)
	fx.add_theme_color_override("font_color", Color(0.8, 0.9, 0.98))
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.custom_minimum_size = Vector2(0, 20)
	tv.add_child(fx)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _try_play_card(card_id, panel))
	panel.add_child(btn)
	return panel


func _try_play_card(card_id: String, panel: Control) -> void:
	if _busy or not CombatState.can_play_card(card_id):
		return
	_busy = true
	await _play_card_fx(panel, card_id)
	var before_hp: Dictionary = {}
	var snap0 := CombatState.get_snapshot()
	for i in range(snap0.get("enemies", []).size()):
		before_hp[i] = int(snap0["enemies"][i].get("hp", 0))
	CombatState.play_card(card_id)
	# Animar muertes antes del rebuild limpio
	var snap1 := CombatState.get_snapshot()
	var enemies: Array = snap1.get("enemies", [])
	for i in range(enemies.size()):
		var now := int(enemies[i].get("hp", 0))
		var prev := int(before_hp.get(i, now))
		if prev > 0 and now <= 0 and not bool(_gone_enemies.get(i, false)):
			var wrap := _enemy_wrap(i)
			if wrap:
				await _start_enemy_death(wrap, i, prev)
	_busy = false
	_refresh()


func _play_card_fx(panel: Control, card_id: String) -> void:
	if not is_instance_valid(panel):
		await get_tree().process_frame
		return
	var def := CardDB.get_card(card_id)
	var card_type := str(def.get("type", ""))
	var is_attack := card_type == "ataque" or int(def.get("damage", 0)) > 0
	var is_block := card_type == "defensa" or int(def.get("block", 0)) > 0

	var ghost := panel.duplicate()
	_fx_layer.add_child(ghost)
	ghost.global_position = panel.global_position
	var target := get_viewport_rect().size * Vector2(0.5, 0.4) - Vector2(66, 99)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", target, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.18, 1.18), 0.26)
	await tw.finished

	if is_attack:
		await _hero_attack_sequence(def)
	elif is_block:
		_apply_hero_pose("aim", 0.45)
		await _hero_guard_pulse()
	else:
		_apply_hero_pose("aim", 0.28)
		await _screen_pulse(Color(0.4, 0.85, 1.0, 0.22))

	var tw2 := create_tween()
	tw2.tween_property(ghost, "modulate:a", 0.0, 0.16)
	await tw2.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	log_label.text = "Activada: %s" % str(def.get("name", card_id))


func _hero_guard_pulse() -> void:
	if _player_actor == null:
		await get_tree().create_timer(0.2).timeout
		return
	var base := _player_base_pos
	var tw0 := create_tween()
	tw0.tween_property(player_sprite, "scale", Vector2(1.05, 0.92), 0.08)
	if _player_shadow:
		tw0.parallel().tween_property(_player_shadow, "scale", Vector2(1.15, 0.88), 0.08)
	await tw0.finished
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_player_actor, "position", base + Vector2(-28, 0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_sprite, "modulate", Color(0.55, 0.88, 1.0), 0.12)
	tw.tween_property(player_sprite, "scale", Vector2(0.98, 1.04), 0.18)
	await tw.finished
	_spawn_fx_at(player_sprite, "impact", Vector2(70, 110), 0.35, Color(0.45, 0.85, 1.0))
	_spawn_fx_at(player_sprite, "impact", Vector2(50, 140), 0.4, Color(0.7, 0.95, 1.0))
	await _screen_pulse(Color(0.35, 0.75, 1.0, 0.28))
	var shield := ColorRect.new()
	shield.color = Color(0.35, 0.75, 1.0, 0.35)
	shield.size = Vector2(40, 40)
	shield.pivot_offset = Vector2(20, 20)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.z_index = 92
	_fx_layer.add_child(shield)
	shield.global_position = player_sprite.global_position + Vector2(60, 80)
	var tws := create_tween()
	tws.set_parallel(true)
	tws.tween_property(shield, "scale", Vector2(4.2, 5.0), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tws.tween_property(shield, "modulate:a", 0.0, 0.32)
	await tws.finished
	if is_instance_valid(shield):
		shield.queue_free()
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_player_actor, "position", base, 0.22).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(player_sprite, "modulate", Color.WHITE, 0.22)
	tw2.tween_property(player_sprite, "scale", Vector2.ONE, 0.22)
	if _player_shadow:
		tw2.tween_property(_player_shadow, "scale", Vector2.ONE, 0.22)
	await tw2.finished


func _hero_attack_sequence(def: Dictionary) -> void:
	_apply_hero_pose("shoot", 0.9)
	if _player_actor == null:
		await get_tree().create_timer(0.25).timeout
		return
	player_sprite.set_meta("anim_locked", true)
	var base := _player_base_pos
	# Wind-up: carga el hombro / arma (pies en suelo)
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(_player_actor, "position", base + Vector2(-28, 4), 0.12).set_trans(Tween.TRANS_CUBIC)
	tw0.tween_property(player_sprite, "rotation_degrees", -10.0, 0.12)
	tw0.tween_property(player_sprite, "scale", Vector2(1.12, 0.88), 0.12)
	if _player_shadow:
		tw0.tween_property(_player_shadow, "scale", Vector2(1.22, 0.82), 0.12)
	await tw0.finished
	# Lunge hacia el enemigo (poca elevación)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_player_actor, "position", base + Vector2(108, 2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_sprite, "rotation_degrees", 8.0, 0.15)
	tw.tween_property(player_sprite, "scale", Vector2(0.92, 1.1), 0.15)
	if _player_shadow:
		tw.tween_property(_player_shadow, "scale", Vector2(1.4, 0.7), 0.15)
	await tw.finished
	# Polvo al plantar el pie en el lunge (física visual)
	var foot := player_sprite.global_position + Vector2(player_sprite.size.x * 0.5, player_sprite.size.y - 4.0)
	_spawn_dust_puff(foot, 1.1)
	var muzzle_pos := player_sprite.global_position + Vector2(player_sprite.size.x * 0.72, player_sprite.size.y * 0.42)
	_spawn_fx_world(muzzle_pos, "muzzle", 0.18, Vector2(1.55, 1.55))
	await get_tree().create_timer(0.03).timeout
	_spawn_fx_world(muzzle_pos + Vector2(10, -5), "muzzle", 0.14, Vector2(1.05, 1.05))
	await _screen_pulse(Color(1.0, 0.72, 0.22, 0.3))
	var enemy_node := _selected_enemy_sprite()
	var hit_pos := get_viewport_rect().size * Vector2(0.72, 0.48)
	if enemy_node and is_instance_valid(enemy_node):
		hit_pos = enemy_node.global_position + Vector2(enemy_node.size.x * 0.45, enemy_node.size.y * 0.48)
	await _fly_tracer(muzzle_pos, hit_pos)
	_spawn_fx_world(hit_pos, "impact", 0.3, Vector2(1.7, 1.7))
	_spawn_blood_burst(hit_pos, 1.55)
	if enemy_node and is_instance_valid(enemy_node):
		_spawn_dust_puff(enemy_node.global_position + Vector2(enemy_node.size.x * 0.5, enemy_node.size.y - 2.0), 1.2)
		await _hit_actor_heavy(enemy_node, maxi(1, int(def.get("damage", 8))), true)
	# Recoil
	var twr := create_tween()
	twr.set_parallel(true)
	twr.tween_property(_player_actor, "position", base + Vector2(42, 3), 0.1)
	twr.tween_property(player_sprite, "rotation_degrees", -6.0, 0.1)
	twr.tween_property(player_sprite, "scale", Vector2(1.05, 0.94), 0.1)
	await twr.finished
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_player_actor, "position", base, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player_sprite, "rotation_degrees", 0.0, 0.24)
	tw2.tween_property(player_sprite, "scale", Vector2.ONE, 0.24)
	if _player_shadow:
		tw2.tween_property(_player_shadow, "scale", Vector2.ONE, 0.24)
	await tw2.finished
	player_sprite.set_meta("anim_locked", false)


func _play_enemy_attack_sequence() -> void:
	var snap := CombatState.get_snapshot()
	var enemies: Array = snap.get("enemies", [])
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if int(e.get("hp", 0)) <= 0 or bool(e.get("detained", false)) or bool(e.get("fled", false)):
			continue
		if bool(_gone_enemies.get(i, false)):
			continue
		if int(e.get("intent", 0)) != CombatState.Intent.ATTACK:
			continue
		await _enemy_lunge_attack(i)
	await get_tree().create_timer(0.06).timeout


func _enemy_lunge_attack(index: int) -> void:
	var wrap := _enemy_wrap(index)
	if wrap == null:
		return
	var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
	var shadow: TextureRect = wrap.find_child("Shadow", true, false)
	if spr == null:
		return
	var is_boss := bool(wrap.get_meta("is_boss", false))
	var attack_path := str(wrap.get_meta("pose_attack", ""))
	var idle_tex: Texture2D = spr.texture
	var base: Vector2 = wrap.get_meta("sprite_base", spr.position)
	wrap.set_meta("anim_locked", true)
	if is_boss and attack_path != "" and (ResourceLoader.exists(attack_path) or FileAccess.file_exists(attack_path)):
		var at := _load_combat_tex(attack_path)
		if at:
			spr.texture = at
	var wind := Vector2(18, 3) if is_boss else Vector2(10, 2)
	var lunge := Vector2(-150, -8) if is_boss else Vector2(-98, -2)
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(spr, "position", base + wind, 0.14 if is_boss else 0.1)
	tw0.tween_property(spr, "rotation_degrees", 8.0 if is_boss else 5.0, 0.14 if is_boss else 0.1)
	tw0.tween_property(spr, "scale", Vector2(1.1, 0.88) if is_boss else Vector2(1.06, 0.92), 0.14 if is_boss else 0.1)
	await tw0.finished
	if is_boss:
		var twp := create_tween()
		twp.tween_property(spr, "position", base + wind + Vector2(8, 0), 0.06)
		twp.tween_property(spr, "position", base + wind + Vector2(-4, 0), 0.08)
		await twp.finished
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "position", base + lunge, 0.18 if is_boss else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "rotation_degrees", -12.0 if is_boss else -7.0, 0.18 if is_boss else 0.14)
	tw.tween_property(spr, "scale", Vector2(0.88, 1.16) if is_boss else Vector2(0.94, 1.08), 0.18 if is_boss else 0.14)
	if shadow:
		tw.tween_property(shadow, "scale", Vector2(1.45, 0.72) if is_boss else Vector2(1.3, 0.78), 0.14)
	await tw.finished
	if is_boss:
		await _screen_pulse(Color(1.0, 0.55, 0.2, 0.32))
	var muzzle := spr.global_position + Vector2(24, spr.size.y * 0.48)
	_spawn_fx_world(muzzle, "muzzle", 0.18 if is_boss else 0.16, Vector2(1.45, 1.45) if is_boss else Vector2(1.2, 1.2))
	await get_tree().create_timer(0.03).timeout
	_spawn_fx_world(muzzle + Vector2(-6, 3), "muzzle", 0.12, Vector2(0.9, 0.9) if is_boss else Vector2(0.8, 0.8))
	if is_boss:
		_spawn_fx_world(muzzle + Vector2(-14, -4), "muzzle", 0.1, Vector2(0.7, 0.7))
	var target := player_sprite.global_position + Vector2(90, player_sprite.size.y * 0.55)
	await _fly_tracer(muzzle, target)
	_spawn_fx_world(target, "impact", 0.3 if is_boss else 0.26, Vector2(1.55, 1.55) if is_boss else Vector2(1.35, 1.35))
	_spawn_blood_burst(target, 1.5 if is_boss else 1.15)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(spr, "position", base, 0.26 if is_boss else 0.2).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(spr, "rotation_degrees", 0.0, 0.26 if is_boss else 0.2)
	tw2.tween_property(spr, "scale", Vector2.ONE, 0.26 if is_boss else 0.2)
	if shadow:
		tw2.tween_property(shadow, "scale", Vector2.ONE, 0.2)
	await tw2.finished
	if is_instance_valid(spr) and idle_tex:
		spr.texture = idle_tex
	if is_instance_valid(wrap):
		wrap.set_meta("anim_locked", false)


func _hit_actor_heavy(node: CanvasItem, dmg: int, knock_right: bool) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.position
	var dir := 1.0 if knock_right else -1.0
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1.0, 0.2, 0.2), 0.04)
	tw.parallel().tween_property(node, "rotation_degrees", 8.0 * dir, 0.08)
	tw.tween_property(node, "position", base + Vector2(28 * dir, -14), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "position", base + Vector2(-10 * dir, 4), 0.1)
	tw.parallel().tween_property(node, "rotation_degrees", -3.0 * dir, 0.1)
	tw.tween_property(node, "position", base, 0.14)
	tw.parallel().tween_property(node, "rotation_degrees", 0.0, 0.14)
	tw.parallel().tween_property(node, "modulate", Color.WHITE, 0.14)
	_spawn_dmg_number(node, dmg)
	await tw.finished


func _enemy_wrap(index: int) -> Control:
	for c in enemies_row.get_children():
		if int(c.get_meta("enemy_index", -1)) == index:
			return c
	return null


func _selected_enemy_sprite() -> TextureRect:
	var snap := CombatState.get_snapshot()
	var idx := int(snap.get("selected_enemy", 0))
	var wrap := _enemy_wrap(idx)
	if wrap == null:
		return null
	return wrap.find_child("EnemySprite", true, false)


func _fly_tracer(from: Vector2, to: Vector2) -> void:
	var tracer := TextureRect.new()
	tracer.texture = _fx_tex("tracer")
	tracer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tracer.stretch_mode = TextureRect.STRETCH_SCALE
	tracer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracer.z_index = 95
	_fx_layer.add_child(tracer)
	var dist := from.distance_to(to)
	tracer.size = Vector2(maxi(24, int(dist * 0.32)), 8)
	tracer.pivot_offset = Vector2(0, 4)
	tracer.global_position = from
	tracer.rotation = from.angle_to_point(to)
	var tw := create_tween()
	tw.tween_property(tracer, "global_position", to - Vector2(6, 4), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tracer, "modulate:a", 0.0, 0.1)
	await tw.finished
	if is_instance_valid(tracer):
		tracer.queue_free()


func _spawn_fx_at(node: CanvasItem, fx_name: String, offset: Vector2, life: float, tint: Color = Color.WHITE) -> void:
	if not is_instance_valid(node):
		return
	_spawn_fx_world(node.global_position + offset, fx_name, life, Vector2.ONE, tint)



func _spawn_dust_puff(pos: Vector2, power: float = 1.0) -> void:
	## Polvo con caída (física visual) al plantar pie / impactar suelo.
	if _fx_layer == null:
		return
	var tex := _map_tex("dust_puff")
	var n := clampi(int(3.0 + power * 2.0), 3, 7)
	for i in range(n):
		var fx: Control
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(28, 28) * randf_range(0.7, 1.4) * power
			fx = tr
		else:
			var blob := ColorRect.new()
			blob.color = Color(0.65, 0.6, 0.5, 0.7)
			blob.size = Vector2(10, 10) * power
			fx = blob
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.z_index = 70
		fx.modulate = Color(1, 1, 1, 0.85)
		fx.pivot_offset = fx.size * 0.5
		_fx_layer.add_child(fx)
		var start := pos + Vector2(randf_range(-18, 18), randf_range(-6, 2))
		fx.global_position = start - fx.size * 0.5
		var rise := start + Vector2(randf_range(-10, 10), randf_range(-22, -10))
		var fall := start + Vector2(randf_range(-24, 24), randf_range(28, 55))  # gravedad
		var life := randf_range(0.35, 0.55)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(fx, "global_position", rise - fx.size * 0.5, life * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(fx, "scale", Vector2.ONE * 1.35, life * 0.35)
		tw.chain()
		tw.set_parallel(true)
		tw.tween_property(fx, "global_position", fall - fx.size * 0.5, life * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(fx, "modulate:a", 0.0, life * 0.65)
		tw.chain().tween_callback(fx.queue_free)


func _spawn_blood_burst(pos: Vector2, power: float = 1.0) -> void:
	## Salpicadura gruesa + gotas con gravedad hacia el suelo.
	var n := clampi(int(5.0 + power * 3.0), 5, 11)
	for i in range(n):
		var off := Vector2(randf_range(-34.0, 38.0), randf_range(-26.0, 16.0)) * power
		var sc := randf_range(1.05, 2.15) * power
		var life := randf_range(0.55, 0.95)
		var tint := Color(randf_range(0.75, 1.1), randf_range(0.02, 0.12), randf_range(0.02, 0.1), 1.0)
		_spawn_blood_drop(pos + off, sc, life, tint)
	# Mancha base en el impacto
	_spawn_blood_stain(pos, 1.15 * power)
	_spawn_fx_world(pos, "impact", 0.28, Vector2(1.45, 1.45) * power, Color(1.0, 0.25, 0.18))


func _spawn_blood_stain(pos: Vector2, sc: float) -> void:
	## Mancha suave (sin rectángulo duro).
	var tex := _fx_tex("blood")
	var stain: Control
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(86, 48) * sc
		stain = tr
	else:
		var blob := ColorRect.new()
		blob.color = Color(0.55, 0.02, 0.05, 0.55)
		blob.size = Vector2(36, 16) * sc
		stain = blob
	stain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stain.z_index = 96
	stain.modulate = Color(0.85, 0.05, 0.08, 0.85)
	stain.pivot_offset = stain.size * 0.5
	stain.rotation_degrees = randf_range(-30, 30)
	stain.scale = Vector2(1.2, 0.55)
	_fx_layer.add_child(stain)
	stain.global_position = pos - stain.size * 0.5 + Vector2(0, 10)
	var tw := create_tween()
	tw.tween_property(stain, "scale", Vector2(1.55, 0.7), 0.14)
	tw.tween_property(stain, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(stain.queue_free)


func _spawn_blood_drop(pos: Vector2, sc: float, life: float, tint: Color) -> void:
	var tex := _fx_tex("blood")
	var fx: Control
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(70, 70) * sc
		fx = tr
	else:
		var blob := ColorRect.new()
		blob.color = Color(0.7, 0.05, 0.08, 0.95)
		blob.size = Vector2(18, 22) * sc
		fx = blob
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 97
	fx.modulate = tint
	fx.pivot_offset = fx.size * 0.5
	_fx_layer.add_child(fx)
	fx.global_position = pos - fx.size * 0.5
	var rise := pos + Vector2(randf_range(-18, 18), randf_range(-42, -18)) * sc
	var fall := pos + Vector2(randf_range(-28, 30), randf_range(55, 110)) * sc
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "global_position", rise - fx.size * 0.5, life * 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "scale", Vector2.ONE * (1.0 + 0.45 * sc), life * 0.22)
	tw.chain()
	tw.set_parallel(true)
	tw.tween_property(fx, "global_position", fall - fx.size * 0.5, life * 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(fx, "modulate:a", 0.0, life * 0.78)
	tw.tween_property(fx, "rotation_degrees", randf_range(-55, 55), life * 0.78)
	tw.chain().tween_callback(fx.queue_free)


func _spawn_fx_world(pos: Vector2, fx_name: String, life: float, sc: Vector2 = Vector2.ONE, tint: Color = Color.WHITE) -> void:
	var tex := _fx_tex(fx_name)
	if tex == null:
		return
	var fx := TextureRect.new()
	fx.texture = tex
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 96
	fx.modulate = tint
	fx.size = Vector2(68, 68) * sc
	fx.pivot_offset = fx.size * 0.5
	_fx_layer.add_child(fx)
	fx.global_position = pos - fx.size * 0.5
	var tw := create_tween()
	tw.tween_property(fx, "scale", sc * 1.35, life * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, life * 0.6)
	tw.tween_callback(fx.queue_free)


func _screen_pulse(color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 70
	_fx_layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.16)
	await tw.finished
	if is_instance_valid(flash):
		flash.queue_free()


func _hit_actor(node: CanvasItem, dmg: int, knock_right: bool) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.position
	var dir := 1.0 if knock_right else -1.0
	var tw := create_tween()
	tw.tween_property(node, "position", base + Vector2(16 * dir, -4), 0.07).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "modulate", Color(1.0, 0.35, 0.35), 0.04)
	tw.tween_property(node, "position", base + Vector2(-8 * dir, 2), 0.07)
	tw.tween_property(node, "position", base, 0.1)
	tw.parallel().tween_property(node, "modulate", Color.WHITE, 0.14)
	_spawn_dmg_number(node, dmg)


func _spawn_dmg_number(node: CanvasItem, dmg: int) -> void:
	if dmg <= 0 or not is_instance_valid(node):
		return
	var lab := Label.new()
	lab.text = "-%d" % dmg
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	lab.z_index = 90
	_fx_layer.add_child(lab)
	lab.global_position = node.global_position + Vector2(40, 20)
	var tw := create_tween()
	tw.tween_property(lab, "global_position:y", lab.global_position.y - 56, 0.5)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lab.queue_free)


func _rebuild_energy(snap: Dictionary) -> void:
	for c in energy_row.get_children():
		c.queue_free()
	var p: Dictionary = snap.get("player", {})
	var cur := int(p.get("energy", 0))
	var mx := int(p.get("energy_max", 3))
	for i in range(mx):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(18, 18)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.35, 0.82, 1.0) if i < cur else Color(0.12, 0.16, 0.22)
		sb.set_corner_radius_all(9)
		pip.add_theme_stylebox_override("panel", sb)
		energy_row.add_child(pip)
