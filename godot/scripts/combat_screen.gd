extends Control
## Combate: suelo anclado, muerte con caída, escudo, cartas y barras minimalistas.

const PACK_HERO := "res://assets/combat/custom/hero/"
const PACK_FOE := "res://assets/combat/custom/foes/"
const FX_DIR := "res://assets/combat/custom/fx/"
const MAP_DIR := "res://assets/combat/custom/map/"
const PHYSICS_ARENA := "res://assets/combat/custom/map/arena_street_physics.png"
## Altura del slot de actor (pies en el borde inferior).
const GROUND_Y := 318.0
## Línea de bordillo en arena_street_physics.png (y / 1080).
const PHYSICS_CONTACT_RATIO := 756.0 / 1080.0
## Hundir suelas en el bordillo (cierra el hueco visual de ~5–8px).
const PLANT_SINK_PX := 14.0
## Cartas de la mano: tamaño fijo que cabe en el panel inferior sin recorte.
const HAND_CARD_W := 124.0
const HAND_CARD_H := 198.0
const ENEMY_HAND_CARD_W := 98.0
const ENEMY_HAND_CARD_H := 162.0
const BOTTOM_PANEL_H := 292.0
## Barras de vida grandes (llenan el combate, se leen a distancia).
const PLAYER_HP_BAR_W := 280.0
const PLAYER_HP_BAR_H := 40.0
const PLAYER_BLK_BAR_H := 20.0
const ENEMY_HP_BAR_W := 228.0
const ENEMY_HP_BAR_H := 34.0
const BOSS_HP_BAR_W := 260.0
const BOSS_HP_BAR_H := 38.0
const ACTOR_W := 300.0
const BOSS_ACTOR_W := 340.0

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
var _wait_t: float = 0.0
var _hero_fidget_cd: float = 1.6
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
var _hand_deal_token: int = 0
var _enemy_deal_token: int = 0
var _last_hand_sig: String = ""
var _last_enemy_sig: String = ""
var _bg_anim: Control
var _bg_fog: TextureRect
var _bg_fog2: TextureRect
var _bg_neon_pulse: ColorRect
var _bg_siren: ColorRect
var _bg_rain: Array = [] # TextureRect drops
var _bg_glows: Array = [] # TextureRect window pulses
var _bg_cars: Array = [] # TextureRect car lights
var _bg_anim_t: float = 0.0
var _bg_lightning_t: float = -1.0
## Atmósfera del escenario actual (lluvia/neón/niebla…).
var _bg_mood: Dictionary = {}
var _arena_id: String = ""
var _arena_name: String = ""
var _combat_period: String = "night"
var _scenario_banner: Control


func _hero_tex(name: String) -> Texture2D:
	## Kick-Ass: siempre PNG en disco (evita ctex cacheado de García).
	var anime := CombatRoster.hero_pose(name)
	if anime != "" and FileAccess.file_exists(anime):
		var img := Image.load_from_file(ProjectSettings.globalize_path(anime))
		if img:
			return ImageTexture.create_from_image(img)
	var path := PACK_HERO + "kickass_" + name + ".png"
	if FileAccess.file_exists(path):
		var img2 := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img2:
			return ImageTexture.create_from_image(img2)
	# Último recurso: nombres legacy
	return _load_combat_tex(PACK_HERO + name + ".png")


func _load_combat_tex(path: String) -> Texture2D:
	## Prefer imported resources (export-safe). Raw PNG fallback for editor hot-reload.
	if path == "":
		return null
	# Kick-Ass / street enemies: forzar PNG fresco (evita ctex cacheado).
	if (path.find("kickass_") >= 0 or path.find("street_pack/") >= 0 or path.find("/foes/street_") >= 0) and FileAccess.file_exists(path):
		var fresh := Image.load_from_file(ProjectSettings.globalize_path(path))
		if fresh:
			return ImageTexture.create_from_image(fresh)
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
		"punch", "melee":
			return "punch"
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
		"shoot", "aim", "ready":
			tex = _hero_tex("shoot")
		"punch", "melee":
			tex = _hero_tex("punch")
			if tex == null:
				tex = _hero_tex("shoot")
		"hurt":
			tex = _hero_tex("hurt")
		"walk", "step":
			tex = _hero_tex("walk")
			if tex == null:
				tex = _hero_tex("idle")
		_:
			tex = _hero_tex("idle")
	if tex == null:
		tex = _hero_tex("idle")
	if tex:
		player_sprite.texture = tex
		_apply_hero_facing()
		_plant_hero_sprite()


func _is_waiting_for_card() -> bool:
	## Turno del jugador, sin carta en curso: personajes deben moverse.
	if not visible or _busy or _closing:
		return false
	var snap := CombatState.get_snapshot()
	if not bool(snap.get("active", false)):
		return false
	return int(snap.get("phase", -1)) == CombatState.Phase.PLAYER


func _card_is_melee(def: Dictionary) -> bool:
	var id := str(def.get("id", "")).to_lower()
	var name := str(def.get("name", "")).to_lower()
	var blob := id + " " + name
	for k in ["baton", "baston", "bastón", "puño", "punch", "melee", "patada", "kick", "porra"]:
		if blob.find(k) >= 0:
			return true
	return false


func _screen_shake(amount: float = 8.0, duration: float = 0.22) -> void:
	## Sacudida suave con decay (sin saltos bruscos).
	var target: Control = self
	var base := target.position
	var tw := create_tween()
	var steps := 10
	for i in range(steps):
		var t := float(i + 1) / float(steps)
		var fall := (1.0 - t) * (1.0 - t)
		var off := Vector2(
			randf_range(-amount, amount) * fall,
			randf_range(-amount * 0.45, amount * 0.45) * fall
		)
		tw.tween_property(target, "position", base + off, duration / float(steps)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "position", base, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _tween_actor_to(node: Node, property: String, value: Variant, duration: float, trans: Tween.TransitionType = Tween.TRANS_CUBIC, ease: Tween.EaseType = Tween.EASE_IN_OUT) -> Tween:
	var tw := create_tween()
	tw.tween_property(node, property, value, duration).set_trans(trans).set_ease(ease)
	return tw


func _tick_hero_pose() -> void:
	if _hero_pose == "idle":
		return
	# Fidgets (ready/walk) y poses de combate caducan solos.
	if Time.get_ticks_msec() / 1000.0 >= _hero_pose_until:
		_apply_hero_pose("idle")


func _plant_hero_sprite() -> void:
	## Cuerpo completo, suelas opacas ancladas al suelo del slot.
	if player_sprite == null:
		return
	var box := Vector2(ACTOR_W, GROUND_Y)
	_bottom_plant_texture(player_sprite, box)
	if not bool(player_sprite.get_meta("anim_locked", false)):
		var planted: Vector2 = player_sprite.get_meta("plant_pos", player_sprite.position)
		player_sprite.position = planted


func _texture_sole_pad_px(tex: Texture2D) -> float:
	## Filas transparentes bajo la suela opaca (evita flotar por padding del PNG).
	if tex == null:
		return 0.0
	var img: Image = null
	if tex is ImageTexture:
		img = (tex as ImageTexture).get_image()
	elif tex.resource_path != "" and FileAccess.file_exists(tex.resource_path):
		img = Image.load_from_file(tex.resource_path)
	if img == null:
		return 0.0
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var th := img.get_height()
	var tw := img.get_width()
	var min_opaque := maxi(2, int(tw * 0.015))
	for y in range(th - 1, -1, -1):
		var count := 0
		for x in range(tw):
			var c := img.get_pixel(x, y)
			# Ignora padding y franja magenta/chroma del export anime.
			if c.a <= 0.12:
				continue
			if c.r > 0.45 and c.b > 0.25 and c.g < 0.35 and c.r > c.g + 0.15:
				continue
			count += 1
			if count >= min_opaque:
				return float(th - 1 - y)
	return 0.0


func _bottom_plant_texture(tex: TextureRect, box: Vector2) -> void:
	## Escala con aspect y pega la SUELA OPACA al borde inferior del slot.
	if tex == null:
		return
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	var dw := box.x
	var dh := box.y
	var sole_pad := 0.0
	if tex.texture != null:
		var tw := float(tex.texture.get_width())
		var th := float(tex.texture.get_height())
		if tw > 1.0 and th > 1.0:
			var sc := minf(box.x / tw, box.y / th)
			dw = tw * sc
			dh = th * sc
			sole_pad = _texture_sole_pad_px(tex.texture) * sc
	tex.custom_minimum_size = Vector2(dw, dh)
	tex.size = Vector2(dw, dh)
	# Baja el rect: suela opaca en box.y + sankeo anti-franja/anti-gap.
	var planted := Vector2((box.x - dw) * 0.5, box.y - dh + sole_pad + 3.0)
	tex.position = planted
	tex.set_meta("plant_pos", planted)
	tex.set_meta("plant_box", box)
	tex.set_meta("sole_pad", sole_pad)
	# Pivote en la suela: respiración/ataques no levantan los pies.
	tex.pivot_offset = Vector2(dw * 0.5, dh - sole_pad)


func _ready() -> void:
	visible = false
	end_turn_btn.pressed.connect(_on_end_turn)
	result_btn.pressed.connect(_on_result_close)
	result_panel.visible = false
	CombatState.combat_updated.connect(_refresh)
	CombatState.combat_ended.connect(_on_combat_ended)
	CombatState.log_message.connect(_on_log)
	CombatState.enemy_defeated.connect(_on_enemy_defeated)
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
	_ensure_floor_plane()
	_ground_arena_layout()
	set_process(true)


func _ground_contact_y() -> float:
	## Y de pantalla donde empieza el bordillo / asfalto jugable.
	var h := size.y
	if h < 2.0:
		h = float(get_viewport_rect().size.y)
	return h * PHYSICS_CONTACT_RATIO


func _sync_physics_ground() -> void:
	## Alinea FloorPlane + columnas de actores con la línea de contacto del mapa.
	var contact := _ground_contact_y()
	var sink := contact + PLANT_SINK_PX
	var floor := get_node_or_null("FloorPlane") as Control
	if floor:
		floor.offset_top = -(size.y - contact)
		floor.offset_bottom = -BOTTOM_PANEL_H + 40.0
		floor.z_index = 1
	var shade := get_node_or_null("GroundShade") as ColorRect
	if shade:
		shade.offset_top = -(size.y - contact + 8.0)
		shade.offset_bottom = -BOTTOM_PANEL_H + 8.0
		shade.color = Color(0.02, 0.03, 0.05, 0.55)
		shade.z_index = 1
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arena := get_node_or_null("Arena") as Control
	if arena == null:
		return
	arena.z_index = 5
	# Arena anclada full-rect con offsets; centro vertical en coords de pantalla.
	var arena_mid := arena.offset_top + (size.y - arena.offset_top + arena.offset_bottom) * 0.5
	var col_bottom := sink - arena_mid
	var vw := maxf(size.x, 960.0)
	var player_col := get_node_or_null("Arena/PlayerCol")
	if player_col:
		# Fracciones del ancho: pelea compacta en 1280 y en 1920 (sin vacío enorme).
		var p_left := clampf(vw * 0.18, 140.0, 400.0)
		player_col.offset_left = p_left
		player_col.offset_right = p_left + ACTOR_W + 56.0
		player_col.offset_top = -64.0
		player_col.offset_bottom = col_bottom
		player_col.alignment = BoxContainer.ALIGNMENT_END
	if enemies_row:
		# Empieza cerca del centro (BEGIN): evita el vacío enorme a la izquierda del row.
		var e_right := clampf(vw * 0.03, 24.0, 64.0)
		enemies_row.offset_right = -e_right
		enemies_row.offset_left = -vw * 0.55
		enemies_row.offset_top = -80.0
		enemies_row.offset_bottom = col_bottom
		enemies_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		enemies_row.add_theme_constant_override("separation", 14)


func _ground_arena_layout() -> void:
	## Layout base; la Y exacta la fija `_sync_physics_ground`.
	_sync_physics_ground()
	if player_marker:
		player_marker.visible = true
		player_marker.text = "KICK-ASS"
		player_marker.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
		player_marker.add_theme_font_size_override("font_size", 16)
		player_marker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		player_marker.add_theme_constant_override("outline_size", 4)


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
	_player_actor.custom_minimum_size = Vector2(ACTOR_W, GROUND_Y)
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
	var h := 26.0
	var aw := actor.size.x if actor.size.x > 1.0 else ACTOR_W
	shadow.size = Vector2(width + 24.0, h)
	# Sombra sobre el bordillo, pegada a la suela (no bajo el asfalto).
	shadow.position = Vector2((aw - width - 24.0) * 0.5, GROUND_Y - h + 4.0)
	shadow.pivot_offset = Vector2((width + 24.0) * 0.5, h * 0.55)
	shadow.modulate = Color(0.01, 0.01, 0.02, 0.9)


func _ensure_floor_plane() -> void:
	## Cubierta opaca de asfalto + bordillo: los pies apoyan aquí (sin flotar).
	var existing := get_node_or_null("FloorPlane") as Control
	if existing:
		existing.queue_free()
	var floor := Control.new()
	floor.name = "FloorPlane"
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Valores iniciales; `_sync_physics_ground` ajusta a la línea de contacto.
	floor.offset_top = -(size.y * (1.0 - PHYSICS_CONTACT_RATIO)) if size.y > 2.0 else -324.0
	floor.offset_bottom = -220.0
	floor.z_index = 1
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
	curb.offset_bottom = 28.0
	curb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	curb.stretch_mode = TextureRect.STRETCH_TILE
	curb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curb.texture = _map_tex("floor_curb")
	if curb.texture == null:
		var rim := ColorRect.new()
		rim.color = Color(0.9, 0.74, 0.16, 1.0)
		rim.set_anchors_preset(Control.PRESET_TOP_WIDE)
		rim.offset_bottom = 10.0
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor.add_child(rim)
	else:
		floor.add_child(curb)

	var gloss := ColorRect.new()
	gloss.name = "WetGloss"
	gloss.color = Color(0.35, 0.55, 0.85, 0.07)
	gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	gloss.offset_top = 28.0
	gloss.offset_bottom = -8.0
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.add_child(gloss)


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
	player_hp_bar.custom_minimum_size = Vector2(PLAYER_HP_BAR_W, PLAYER_HP_BAR_H)
	player_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	player_hp_text.add_theme_font_size_override("font_size", 18)
	player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	player_hp_text.add_theme_constant_override("outline_size", 5)
	_player_block_bar = ProgressBar.new()
	_player_block_bar.name = "PlayerBlockBar"
	_player_block_bar.custom_minimum_size = Vector2(PLAYER_HP_BAR_W, PLAYER_BLK_BAR_H)
	_player_block_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_player_block_bar.max_value = 20
	_player_block_bar.value = 0
	_player_block_bar.show_percentage = false
	_player_block_bar.visible = false
	parent.add_child(_player_block_bar)
	_player_block_text = Label.new()
	_player_block_text.name = "PlayerBlockText"
	_player_block_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_block_text.add_theme_font_size_override("font_size", 14)
	_player_block_text.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	_player_block_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_player_block_text.add_theme_constant_override("outline_size", 3)
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
	# Movimiento continuo (idle/fidget) salvo actors bloqueados en ataque.
	_bob_t += delta
	_bg_anim_t += delta
	if not _busy:
		_tick_hero_pose()
		_tick_wait_fidget(delta)
	_idle_bob_player(delta)
	_idle_bob_enemies(delta)
	_tick_animated_bg(delta)


func _tick_wait_fidget(delta: float) -> void:
	## Mientras eliges carta: cambios de pose / amenazas cortas.
	if not _is_waiting_for_card():
		return
	_wait_t += delta
	_hero_fidget_cd -= delta
	if _hero_fidget_cd <= 0.0 and player_sprite and not bool(player_sprite.get_meta("anim_locked", false)):
		# Alterna paso listo / mira apuntando.
		if _hero_pose == "idle" or _hero_pose == "":
			# Preferir mira lista; walk solo a veces (menos brusco).
			var pick := "ready" if randf() < 0.72 else "walk"
			_apply_hero_pose(pick, randf_range(0.55, 0.9))
		_hero_fidget_cd = randf_range(2.2, 3.8)
	# Enemigos: lean + flash de pose de ataque ocasional.
	var i := 0
	for wrap in enemies_row.get_children():
		if not is_instance_valid(wrap):
			continue
		if bool(wrap.get_meta("fallen", false)) or bool(wrap.get_meta("anim_locked", false)):
			continue
		var cd := float(wrap.get_meta("fidget_cd", 1.2 + float(i) * 0.35))
		cd -= delta
		if cd <= 0.0:
			_enemy_wait_fidget(wrap)
			cd = randf_range(1.6, 3.0) + float(i) * 0.2
		wrap.set_meta("fidget_cd", cd)
		i += 1


func _enemy_wait_fidget(wrap: Control) -> void:
	if not is_instance_valid(wrap):
		return
	var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
	if spr == null or not is_instance_valid(spr):
		return
	var base: Vector2 = wrap.get_meta("sprite_base", spr.position)
	wrap.set_meta("anim_locked", true)
	# Amenaza corta: se inclina hacia Kick-Ass.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "position", base + Vector2(-10, 0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "rotation_degrees", -4.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "scale", Vector2(0.98, 1.03), 0.22).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not is_instance_valid(wrap) or not is_instance_valid(spr):
		return
	var attack_path := str(wrap.get_meta("pose_attack", ""))
	var idle_path := str(wrap.get_meta("idle_sprite", ""))
	var plant_box: Vector2 = spr.get_meta("plant_box", Vector2(ACTOR_W, GROUND_Y)) if spr.has_meta("plant_box") else Vector2(ACTOR_W, GROUND_Y)
	var old_tex := spr.texture
	if attack_path != "" and randf() < 0.55:
		var at := _load_combat_tex(attack_path)
		if at and is_instance_valid(spr):
			spr.texture = at
			_bottom_plant_texture(spr, plant_box)
	await get_tree().create_timer(randf_range(0.28, 0.48)).timeout
	if not is_instance_valid(wrap) or not is_instance_valid(spr):
		return
	if idle_path != "":
		var it := _load_combat_tex(idle_path)
		if it:
			spr.texture = it
			_bottom_plant_texture(spr, plant_box)
	elif old_tex:
		spr.texture = old_tex
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(spr, "position", base, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(spr, "rotation_degrees", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(spr, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	if is_instance_valid(wrap):
		wrap.set_meta("anim_locked", false)


func _idle_bob_player(delta: float = 0.016) -> void:
	if _player_actor == null or not is_instance_valid(_player_actor):
		return
	if not is_instance_valid(player_sprite):
		return
	if bool(player_sprite.get_meta("anim_locked", false)):
		return
	var waiting := _is_waiting_for_card()
	# En espera: respiración y cambio de peso bien visibles.
	var sway_amp := 2.4 if waiting else 0.55
	var breath_amp := 0.028 if waiting else 0.008
	var rot_amp := 1.6 if waiting else 0.35
	var sway := cos(_bob_t * (1.05 if waiting else 0.75)) * sway_amp
	var planted: Vector2 = player_sprite.get_meta("plant_pos", Vector2.ZERO)
	var target := planted + Vector2(sway, 0.0)
	player_sprite.position = player_sprite.position.lerp(target, 1.0 - exp(-delta * (6.5 if waiting else 5.0)))
	var breath_x := 1.0 + sin(_bob_t * (1.7 if waiting else 1.25)) * breath_amp
	var breath_y := 1.0 + sin(_bob_t * (1.7 if waiting else 1.25) + 0.6) * (breath_amp * 0.45)
	# Mantener pivote en suela: escala vertical no levanta pies.
	player_sprite.scale = player_sprite.scale.lerp(Vector2(breath_x, maxf(0.97, breath_y)), 1.0 - exp(-delta * 5.0))
	var rot := sin(_bob_t * 0.9) * rot_amp
	player_sprite.rotation_degrees = lerpf(player_sprite.rotation_degrees, rot, 1.0 - exp(-delta * 4.5))
	if _player_actor and waiting:
		var actor_sway := sin(_bob_t * 0.55) * 3.0
		_player_actor.position = _player_actor.position.lerp(_player_base_pos + Vector2(actor_sway, 0.0), 1.0 - exp(-delta * 4.0))
	elif _player_actor and not waiting:
		_player_actor.position = _player_actor.position.lerp(_player_base_pos, 1.0 - exp(-delta * 5.0))
	if _player_shadow:
		_layout_ground_shadow(_player_shadow, _player_actor, 118.0)
		var squash := 1.0 + sin(_bob_t * (1.7 if waiting else 1.25)) * (0.05 if waiting else 0.028)
		_player_shadow.scale = _player_shadow.scale.lerp(Vector2(squash, 1.0), 1.0 - exp(-delta * 4.2))
		_player_shadow.modulate.a = lerpf(_player_shadow.modulate.a, 0.88 + absf(sin(_bob_t * 1.25)) * 0.04, 1.0 - exp(-delta * 4.0))


func _idle_bob_enemies(delta: float = 0.016) -> void:
	var waiting := _is_waiting_for_card()
	var i := 0
	for wrap in enemies_row.get_children():
		if not is_instance_valid(wrap):
			continue
		if bool(wrap.get_meta("fallen", false)):
			continue
		if bool(wrap.get_meta("anim_locked", false)):
			continue
		var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
		if spr == null:
			continue
		var shadow: TextureRect = wrap.find_child("Shadow", true, false)
		var base: Vector2 = wrap.get_meta("sprite_base", spr.position)
		var is_boss := bool(wrap.get_meta("is_boss", false))
		var speed := (0.95 if waiting else 0.7) + float(i % 3) * 0.15
		var phase := _bob_t * speed + float(i) * 0.95
		var sway_amp := (3.2 if waiting else 0.45) * (1.25 if is_boss else 1.0)
		var sway := cos(phase) * sway_amp
		# Empujan un poco hacia el héroe cuando esperan.
		var lean := (-2.5 if waiting else 0.0)
		var target := base + Vector2(sway + lean, 0.0)
		spr.position = spr.position.lerp(target, 1.0 - exp(-delta * (6.0 if waiting else 5.0)))
		var breath := 1.0 + sin(phase * 1.15) * (0.024 if waiting else 0.007)
		spr.scale = spr.scale.lerp(Vector2(breath, 1.0), 1.0 - exp(-delta * 4.5))
		var rot := sin(phase * 0.85) * (2.4 if waiting else 0.4) * (-1.0 if not is_boss else -1.2)
		spr.rotation_degrees = lerpf(spr.rotation_degrees, rot, 1.0 - exp(-delta * 4.2))
		if shadow:
			var squash := 1.0 + sin(phase) * (0.06 if waiting else 0.03)
			shadow.scale = shadow.scale.lerp(Vector2(squash, 1.0), 1.0 - exp(-delta * 4.0))
			shadow.modulate.a = lerpf(shadow.modulate.a, 0.78 + absf(sin(phase)) * 0.08, 1.0 - exp(-delta * 4.0))
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
	_wait_t = 0.0
	_hero_fidget_cd = 1.4
	_gone_enemies.clear()
	_dying.clear()
	_arena_path = str(cfg.get("arena_path", ""))
	_arena_id = str(cfg.get("arena_id", ""))
	_arena_name = str(cfg.get("arena_name", cfg.get("location", "")))
	_combat_period = str(cfg.get("period", "night"))
	_bg_mood = _mood_for_arena(_arena_id, _arena_name, _combat_period)
	result_panel.visible = false
	_prev_enemy_hp.clear()
	_prev_player_hp = -1
	_prev_player_block = 0
	_last_hand_sig = ""
	_last_enemy_sig = ""
	_hand_deal_token += 1
	_enemy_deal_token += 1
	visible = true
	CombatState.start_combat(cfg)
	AudioDirector.start_combat_music()
	AudioDirector.play_sfx("whoosh", 0.9, -4.0)
	_load_bg()
	_ensure_animated_bg()
	_sync_physics_ground()
	_apply_hero_pose("idle")
	_refresh()
	await get_tree().process_frame
	_sync_physics_ground()
	_ensure_animated_bg()
	_plant_hero_sprite()
	if _player_actor:
		_player_base_pos = _player_actor.position
		_layout_ground_shadow(_player_shadow, _player_actor, 160.0)
	_show_scenario_banner()


func close() -> void:
	if AudioDirector.is_in_combat():
		AudioDirector.stop_combat_music(true, false)
	visible = false
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _style_bottom_panel() -> void:
	var bottom := get_node_or_null("Bottom") as MarginContainer
	if bottom:
		# Altura suficiente para cartas completas + labels (sin recortes).
		bottom.offset_top = -BOTTOM_PANEL_H
		bottom.z_index = 50
		bottom.add_theme_constant_override("margin_left", 14)
		bottom.add_theme_constant_override("margin_right", 14)
		bottom.add_theme_constant_override("margin_top", 6)
		bottom.add_theme_constant_override("margin_bottom", 10)
	var arena := get_node_or_null("Arena") as Control
	if arena:
		arena.offset_bottom = -BOTTOM_PANEL_H
	var top := get_node_or_null("TopHud") as Control
	if top:
		top.z_index = 50
	var panel := get_node_or_null("Bottom/BottomPanel")
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.15, 0.22, 0.94)
	sb.border_color = Color(0.55, 0.82, 1.0, 0.5)
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_contents = false
	if deck_count:
		deck_count.add_theme_font_size_override("font_size", 16)
		deck_count.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	if discard_count:
		discard_count.add_theme_font_size_override("font_size", 14)
		discard_count.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	if hand_row:
		hand_row.add_theme_constant_override("separation", 10)
		hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if log_label:
		log_label.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))


func _ensure_enemy_hand_ui() -> void:
	## Cartas enemigas en el hueco horizontal del menú (junto a TU MANO).
	var bottom_row := get_node_or_null("Bottom/BottomPanel/BottomRow") as HBoxContainer
	var hand_col := get_node_or_null("Bottom/BottomPanel/BottomRow/HandCol") as VBoxContainer
	if bottom_row == null:
		return
	# Limpiar layout apilado antiguo dentro de HandCol
	if hand_col:
		for child_name in ["EnemyHandLabel", "EnemyHandRow"]:
			var junk := hand_col.get_node_or_null(child_name)
			if junk:
				hand_col.remove_child(junk)
				junk.free()
		_hand_label = hand_col.get_node_or_null("PlayerHandLabel") as Label
		if _hand_label == null:
			_hand_label = Label.new()
			_hand_label.name = "PlayerHandLabel"
			_hand_label.text = "TU MANO"
			_hand_label.add_theme_font_size_override("font_size", 11)
			_hand_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
			_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hand_col.add_child(_hand_label)
			hand_col.move_child(_hand_label, 0)
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
	AudioDirector.play_sfx("turn_end", 1.0, -2.0)
	AudioDirector.play_ui_click()
	# Si una animación dejó el flag colgado, no bloquear el turno eterno.
	if _busy:
		_busy = false
		_dying.clear()
	if CombatState.phase != CombatState.Phase.PLAYER:
		return
	_busy = true
	end_turn_btn.disabled = true
	await _play_enemy_attack_sequence()
	if CombatState.is_active() and CombatState.phase == CombatState.Phase.PLAYER:
		CombatState.end_player_turn()
	_busy = false
	_refresh()


func _on_combat_ended(victory: bool) -> void:
	AudioDirector.stop_combat_music(victory, true)
	if victory:
		_screen_shake(6.0, 0.16)
	else:
		_screen_shake(14.0, 0.28)
		_apply_hero_pose("hurt", 1.2)
	result_panel.visible = true
	if victory:
		var xp := CombatState.combat_xp_gained
		var kills := CombatState.combat_kills
		var levels := CombatState.combat_levels_gained
		var mid := CombatState.mission_id
		var mission: Dictionary = GameState.active_missions.get(mid, {})
		if mission.is_empty():
			mission = GameState.last_resolved_mission()
		var coins_hint := GameState.mission_coin_reward(mission)
		var hp_bonus := GameState.level_hp_bonus()
		var bits: PackedStringArray = []
		if levels > 0:
			bits.append("¡NIVEL %d!" % GameState.hero_level)
		bits.append(("+%d XP" % xp) if xp > 0 else "ÉXITO")
		bits.append("+%d monedas" % coins_hint)
		if kills > 0:
			bits.append("%d bajas" % kills)
		if hp_bonus > 0:
			bits.append("+%d PV de nivel" % hp_bonus)
		if GameState.pending_level_packs > 0:
			bits.append("SOBRE LISTO")
		result_title.text = "  ·  ".join(bits)
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
	hp_label.add_theme_font_size_override("font_size", 30)
	hp_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hp_label.add_theme_constant_override("outline_size", 4)
	block_label.text = str(int(p.get("block", 0)))
	block_label.add_theme_font_size_override("font_size", 28)
	block_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	block_label.add_theme_constant_override("outline_size", 3)
	var place := str(snap.get("arena_name", snap.get("location", ""))).to_upper()
	var period_bit := _period_label_es(str(snap.get("period", _combat_period)))
	var tag_bit := str(_bg_mood.get("tag", ""))
	if tag_bit != "":
		location_label.text = "%s  ·  %s  ·  %s" % [place, tag_bit, period_bit]
	else:
		location_label.text = "%s  ·  %s" % [place, period_bit]
	var xp_bit := "NV.%d (+%d PV)  %d/%d XP" % [
		int(snap.get("hero_level", GameState.hero_level)),
		GameState.level_hp_bonus(),
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


func _style_bar(bar: ProgressBar, fill_col: Color, h: float = 12.0, w: float = -1.0) -> void:
	## Barra gruesa y legible sobre el asfalto oscuro.
	if w > 0.0:
		bar.custom_minimum_size = Vector2(w, h)
		bar.size = Vector2(w, h)
	else:
		bar.custom_minimum_size.y = h
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(8)
	fill.set_content_margin_all(0)
	fill.border_color = Color(1, 1, 1, 0.35)
	fill.set_border_width_all(2)
	fill.shadow_color = Color(0, 0, 0, 0.55)
	fill.shadow_size = 4
	bar.add_theme_stylebox_override("fill", fill)
	var bgb := StyleBoxFlat.new()
	bgb.bg_color = Color(0.03, 0.04, 0.07, 0.97)
	bgb.set_corner_radius_all(8)
	bgb.set_content_margin_all(0)
	bgb.border_color = Color(1, 1, 1, 0.3)
	bgb.set_border_width_all(2)
	bar.add_theme_stylebox_override("background", bgb)
	bar.add_theme_stylebox_override("background_focus", bgb)


func _style_player_bars(p: Dictionary) -> void:
	_ensure_player_block_bar()
	var hp_now := int(p.get("hp", 0))
	var hp_max := int(p.get("max_hp", 50))
	player_hp_bar.max_value = float(hp_max)
	player_hp_bar.value = float(hp_now)
	# Color por umbral de vida
	var hp_col := Color(0.22, 0.9, 0.42)
	var ratio := float(hp_now) / maxf(1.0, float(hp_max))
	if ratio <= 0.35:
		hp_col = Color(1.0, 0.22, 0.25)
	elif ratio <= 0.65:
		hp_col = Color(1.0, 0.78, 0.2)
	_style_bar(player_hp_bar, hp_col, PLAYER_HP_BAR_H, PLAYER_HP_BAR_W)
	player_hp_text.text = "VIDA %d/%d" % [hp_now, hp_max]
	player_hp_text.add_theme_font_size_override("font_size", 22)
	player_hp_text.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	player_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	player_hp_text.add_theme_constant_override("outline_size", 6)
	var blk := int(p.get("block", 0))
	if _player_block_bar:
		_player_block_bar.visible = blk > 0
		_player_block_bar.max_value = maxf(float(hp_max), float(blk))
		_player_block_bar.value = float(blk)
		_style_bar(_player_block_bar, Color(0.3, 0.82, 1.0), PLAYER_BLK_BAR_H, PLAYER_HP_BAR_W)
	if _player_block_text:
		_player_block_text.visible = blk > 0
		_player_block_text.text = "ESCUDO %d" % blk
		_player_block_text.add_theme_font_size_override("font_size", 14)



func _period_label_es(period: String) -> String:
	match period:
		"day":
			return "DÍA"
		"dusk":
			return "ATARDECER"
		_:
			return "NOCHE"


func _mood_for_arena(arena_id: String, arena_name: String, period: String) -> Dictionary:
	## Perfil visual por escenario: evita que todos los combates se sientan iguales.
	var key := ("%s %s" % [arena_id, arena_name]).to_lower()
	var rain := 0.55
	var fog := 0.55
	var neon := 0.35
	var cars := 0.55
	var siren := 0.35
	var lightning := 0.35
	var wet := 0.55
	var glow := 0.45
	var veil := Color(0.05, 0.08, 0.16, 0.18)
	var tag := "URBANO"

	if period == "day":
		rain = 0.0
		fog = 0.12
		neon = 0.0
		cars = 0.45
		siren = 0.15
		lightning = 0.0
		wet = 0.08
		glow = 0.12
		veil = Color(0.55, 0.62, 0.78, 0.06)
		tag = "DIURNO"
	elif period == "dusk":
		rain = 0.15
		fog = 0.35
		neon = 0.25
		cars = 0.5
		siren = 0.25
		lightning = 0.08
		wet = 0.28
		glow = 0.4
		veil = Color(0.35, 0.18, 0.12, 0.14)
		tag = "ATARDECER"

	if "neon" in key or "farol" in key or "lantern" in key or "market" in key and "plaza" not in key:
		neon = maxf(neon, 0.85)
		glow = maxf(glow, 0.8)
		rain = maxf(rain, 0.35) if period != "day" else rain
		tag = "NEÓN"
		veil = Color(0.12, 0.05, 0.22, 0.16)
	if "rain" in key or "lluvia" in key or "alley" in key or "callejon" in key or "callejón" in key:
		rain = 0.95 if period != "day" else 0.2
		wet = 0.9
		lightning = 0.7 if period == "night" else lightning
		tag = "TORMENTA"
	if "gas" in key or "gasolin" in key:
		glow = maxf(glow, 0.55)
		cars = maxf(cars, 0.7)
		tag = "GASOLINERA"
	if "underpass" in key or "paso" in key or "subway" in key or "metro" in key:
		rain = 0.2
		fog = 0.85
		cars = 0.15
		neon = 0.25
		lightning = 0.0
		tag = "SÓTANO"
		veil = Color(0.04, 0.07, 0.1, 0.28)
	if "train" in key or "vía" in key or "via" in key or "warehouse" in key or "almacén" in key or "almacen" in key:
		fog = maxf(fog, 0.65)
		cars = 0.2
		rain = minf(rain, 0.35)
		tag = "INDUSTRIAL"
	if "pier" in key or "muelle" in key or "harbor" in key or "puerto" in key:
		fog = maxf(fog, 0.7)
		rain = 0.4 if period != "day" else 0.05
		cars = 0.1
		neon = 0.15
		tag = "MUELLE"
		veil = Color(0.08, 0.14, 0.22, 0.2)
	if "plaza" in key or "comisaria" in key or "comisaría" in key or "station" in key and "gas" not in key:
		if period == "day":
			rain = 0.0
			fog = 0.08
			neon = 0.0
			glow = 0.1
			tag = "PLAZA"
			veil = Color(0.7, 0.75, 0.85, 0.05)
		else:
			siren = maxf(siren, 0.55)
			tag = "COMISARÍA"
	if "rooftop" in key or "azotea" in key or "penthouse" in key or "atico" in key or "ático" in key:
		cars = 0.05
		fog = 0.4
		rain = 0.25 if period != "day" else 0.0
		neon = maxf(neon, 0.4)
		tag = "ALTURA"
	if "courtyard" in key or "patio" in key or "parking" in key:
		cars = 0.35
		glow = maxf(glow, 0.35)
		tag = "PATIO"
	if "construction" in key or "obra" in key:
		fog = maxf(fog, 0.5)
		cars = 0.25
		tag = "OBRAS"

	return {
		"rain": rain,
		"fog": fog,
		"neon": neon,
		"cars": cars,
		"siren": siren,
		"lightning": lightning,
		"wet": wet,
		"glow": glow,
		"veil": veil,
		"tag": tag,
	}


func _show_scenario_banner() -> void:
	if _scenario_banner and is_instance_valid(_scenario_banner):
		_scenario_banner.queue_free()
	var place := _arena_name if _arena_name != "" else str(CombatState.arena_name)
	if place == "":
		place = "Zona urbana"
	var period_txt := _period_label_es(_combat_period)
	var tag := str(_bg_mood.get("tag", "URBANO"))

	var banner := Control.new()
	banner.name = "ScenarioBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.z_index = 40
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(banner)
	_scenario_banner = banner

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.88)
	sb.border_color = Color(0.35, 0.75, 0.95, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(size.x * 0.5 - 220, size.y * 0.18)
	panel.custom_minimum_size = Vector2(440, 86)
	banner.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var top := Label.new()
	top.text = "ESCENARIO · %s · %s" % [tag, period_txt]
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_font_size_override("font_size", 13)
	top.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	col.add_child(top)
	var title := Label.new()
	title.text = place.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 4)
	col.add_child(title)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	var banner_ref: WeakRef = weakref(banner)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.55)
	tw.tween_property(panel, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		var b = banner_ref.get_ref()
		if b != null and is_instance_valid(b):
			b.queue_free()
		if _scenario_banner == b:
			_scenario_banner = null
	)
	RadioBus.push("Central: intervención en %s (%s)." % [place, period_txt.to_lower()], "dispatch")


func _ensure_animated_bg() -> void:
	## Capas vivas según el mood del escenario (no todos los fondos llevan la misma lluvia).
	var existing := get_node_or_null("BgAnimLayer") as Control
	if existing:
		existing.queue_free()
	_bg_rain.clear()
	_bg_glows.clear()
	_bg_cars.clear()
	_bg_anim = Control.new()
	_bg_anim.name = "BgAnimLayer"
	_bg_anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_anim.z_index = 2
	add_child(_bg_anim)
	var bg_idx := bg.get_index() if bg else 0
	move_child(_bg_anim, mini(bg_idx + 1, get_child_count() - 1))

	if _bg_mood.is_empty():
		_bg_mood = _mood_for_arena(_arena_id, _arena_name, _combat_period)

	var rain_w := float(_bg_mood.get("rain", 0.5))
	var fog_w := float(_bg_mood.get("fog", 0.5))
	var neon_w := float(_bg_mood.get("neon", 0.3))
	var cars_w := float(_bg_mood.get("cars", 0.5))
	var siren_w := float(_bg_mood.get("siren", 0.3))
	var glow_w := float(_bg_mood.get("glow", 0.4))
	var veil_col: Color = _bg_mood.get("veil", Color(0.05, 0.08, 0.16, 0.18))

	var veil := ColorRect.new()
	veil.name = "NightVeil"
	veil.color = veil_col
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_anim.add_child(veil)

	if fog_w > 0.05:
		_bg_fog = _make_bg_tex_layer("FogA", "fog_scroll", Color(1, 1, 1, 0.35 + fog_w * 0.45))
		_bg_fog2 = _make_bg_tex_layer("FogB", "fog_scroll", Color(0.85, 0.9, 1.0, 0.18 + fog_w * 0.35))
		if _bg_fog:
			_bg_fog.position = Vector2(0, size.y * 0.22)
			_bg_fog.size = Vector2(size.x * 1.6, size.y * 0.28)
			_bg_fog.set_meta("base_a", _bg_fog.modulate.a)
			_bg_anim.add_child(_bg_fog)
		if _bg_fog2:
			_bg_fog2.position = Vector2(-size.x * 0.3, size.y * 0.35)
			_bg_fog2.size = Vector2(size.x * 1.8, size.y * 0.22)
			_bg_fog2.set_meta("base_a", _bg_fog2.modulate.a)
			_bg_anim.add_child(_bg_fog2)
	else:
		_bg_fog = null
		_bg_fog2 = null

	if glow_w > 0.08:
		var glow_tex := _map_tex("window_glow")
		var spots := [
			Vector2(0.18, 0.22), Vector2(0.32, 0.30), Vector2(0.48, 0.18),
			Vector2(0.62, 0.26), Vector2(0.78, 0.20), Vector2(0.88, 0.33),
			Vector2(0.12, 0.40), Vector2(0.55, 0.36), Vector2(0.70, 0.42),
		]
		var colors := [
			Color(1.0, 0.75, 0.25, 0.55), Color(0.35, 0.75, 1.0, 0.5),
			Color(1.0, 0.35, 0.55, 0.55), Color(0.45, 1.0, 0.7, 0.45),
			Color(1.0, 0.85, 0.35, 0.5),
		]
		var glow_n := int(round(3 + glow_w * 6.0))
		for i in range(mini(glow_n, spots.size())):
			var g := TextureRect.new()
			g.name = "WinGlow%d" % i
			g.texture = glow_tex
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.stretch_mode = TextureRect.STRETCH_SCALE
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sp: Vector2 = spots[i]
			g.position = Vector2(size.x * sp.x, size.y * sp.y)
			g.size = Vector2(70, 70)
			var col: Color = colors[i % colors.size()]
			col.a *= glow_w
			g.modulate = col
			g.set_meta("phase", float(i) * 0.73)
			g.set_meta("base_a", g.modulate.a)
			_bg_anim.add_child(g)
			_bg_glows.append(g)

	_bg_neon_pulse = ColorRect.new()
	_bg_neon_pulse.name = "NeonPulse"
	_bg_neon_pulse.color = Color(0.2, 0.6, 1.0, 0.0)
	_bg_neon_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_neon_pulse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_neon_pulse.set_meta("weight", neon_w)
	_bg_anim.add_child(_bg_neon_pulse)

	_bg_siren = ColorRect.new()
	_bg_siren.name = "SirenFlash"
	_bg_siren.color = Color(1.0, 0.1, 0.15, 0.0)
	_bg_siren.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_siren.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_siren.set_meta("weight", siren_w)
	_bg_anim.add_child(_bg_siren)

	if cars_w > 0.08:
		var car_tex := _map_tex("car_lights")
		var car_n := int(round(1 + cars_w * 2.5))
		for i in range(car_n):
			var car := TextureRect.new()
			car.name = "Car%d" % i
			car.texture = car_tex
			car.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			car.stretch_mode = TextureRect.STRETCH_SCALE
			car.mouse_filter = Control.MOUSE_FILTER_IGNORE
			car.size = Vector2(160, 22)
			car.position = Vector2(-200.0 - i * 420.0, size.y * (0.48 + i * 0.03))
			car.modulate = Color(1, 1, 1, 0.35 + cars_w * 0.35)
			car.set_meta("speed", 55.0 + i * 25.0)
			car.set_meta("lane_y", car.position.y)
			_bg_anim.add_child(car)
			_bg_cars.append(car)

	if rain_w > 0.05:
		var rain_tex := _map_tex("rain_streak")
		var rain_n := int(round(8 + rain_w * 56.0))
		for i in range(rain_n):
			var drop := TextureRect.new()
			drop.name = "Rain%d" % i
			drop.texture = rain_tex
			drop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			drop.stretch_mode = TextureRect.STRETCH_SCALE
			drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drop.size = Vector2(7, 22 + (i % 5) * 4)
			drop.modulate = Color(0.8, 0.9, 1.0, (0.2 + (i % 4) * 0.05) * rain_w)
			drop.position = Vector2(fmod(float(i * 97), maxf(size.x, 64.0)), fmod(float(i * 53), maxf(size.y * 0.7, 64.0)))
			drop.set_meta("speed", 320.0 + float(i % 7) * 40.0 + rain_w * 80.0)
			drop.set_meta("drift", -35.0 - float(i % 5) * 8.0)
			_bg_anim.add_child(drop)
			_bg_rain.append(drop)

	_bg_anim_t = 0.0
	_bg_lightning_t = -1.0


func _make_bg_tex_layer(p_name: String, tex_name: String, modulate: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = p_name
	tr.texture = _map_tex(tex_name)
	if tr.texture == null:
		return null
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = modulate
	return tr


func _tick_animated_bg(delta: float) -> void:
	if _bg_anim == null or not is_instance_valid(_bg_anim):
		return
	if size.x < 32.0 or size.y < 32.0:
		return
	var w := size.x
	var h := size.y
	# Parallax suave del fondo
	if bg:
		var pan := sin(_bg_anim_t * 0.08) * 10.0
		bg.position.x = pan
		bg.size = Vector2(w + 24.0, h)
		# Micro pulso de exposición
		var pulse := 1.0 + sin(_bg_anim_t * 0.7) * 0.015
		bg.modulate = Color(pulse, pulse, 1.0 + sin(_bg_anim_t * 0.5) * 0.02, 1.0)

	# Niebla
	if _bg_fog and is_instance_valid(_bg_fog):
		var fog_base := float(_bg_fog.get_meta("base_a", 0.4))
		_bg_fog.position.x = fmod(_bg_anim_t * 18.0, w * 0.5) - w * 0.15
		_bg_fog.modulate.a = fog_base * (0.85 + sin(_bg_anim_t * 0.35) * 0.15)
	if _bg_fog2 and is_instance_valid(_bg_fog2):
		var fog2_base := float(_bg_fog2.get_meta("base_a", 0.25))
		_bg_fog2.position.x = fmod(-_bg_anim_t * 12.0, w * 0.6) - w * 0.2
		_bg_fog2.modulate.a = fog2_base * (0.85 + cos(_bg_anim_t * 0.28) * 0.15)

	# Ventanas / neones
	for g in _bg_glows:
		if not is_instance_valid(g):
			continue
		var phase := float(g.get_meta("phase", 0.0))
		var base_a := float(g.get_meta("base_a", 0.5))
		var flicker := 0.65 + 0.35 * absf(sin(_bg_anim_t * (1.3 + phase * 0.2) + phase))
		# Parpadeo irregular
		if fmod(_bg_anim_t * 7.0 + phase * 10.0, 11.0) < 0.15:
			flicker *= 0.25
		g.modulate.a = base_a * flicker
		g.scale = Vector2.ONE * (0.9 + flicker * 0.25)

	# Pulso neón cyan/magenta
	if _bg_neon_pulse and is_instance_valid(_bg_neon_pulse):
		var neon_w2 := float(_bg_neon_pulse.get_meta("weight", float(_bg_mood.get("neon", 0.3))))
		var n := (sin(_bg_anim_t * 1.1) * 0.5 + 0.5)
		_bg_neon_pulse.color = Color(0.25 + n * 0.4, 0.35, 0.85, (0.02 + n * 0.08) * neon_w2)

	# Sirenas
	if _bg_siren and is_instance_valid(_bg_siren):
		var siren_w2 := float(_bg_siren.get_meta("weight", float(_bg_mood.get("siren", 0.3))))
		var s := sin(_bg_anim_t * 6.5)
		if s > 0.0:
			_bg_siren.color = Color(1.0, 0.12, 0.18, s * 0.12 * siren_w2)
		else:
			_bg_siren.color = Color(0.15, 0.35, 1.0, (-s) * 0.10 * siren_w2)

	# Coches
	for car in _bg_cars:
		if not is_instance_valid(car):
			continue
		var speed := float(car.get_meta("speed", 60.0))
		car.position.x += speed * delta
		car.position.y = float(car.get_meta("lane_y", car.position.y)) + sin(_bg_anim_t * 2.0 + speed) * 1.5
		if car.position.x > w + 80.0:
			car.position.x = -220.0 - fmod(speed, 90.0)
		car.modulate.a = 0.4 + 0.2 * absf(sin(_bg_anim_t * 3.0 + speed))

	# Lluvia
	var ground_y := _ground_contact_y()
	for drop in _bg_rain:
		if not is_instance_valid(drop):
			continue
		var spd := float(drop.get_meta("speed", 400.0))
		var drift := float(drop.get_meta("drift", -30.0))
		drop.position.y += spd * delta
		drop.position.x += drift * delta
		if drop.position.y > ground_y - 8.0 or drop.position.x < -20.0:
			drop.position.y = -randf() * 80.0
			drop.position.x = randf() * w

	# Relámpago ocasional (solo si el mood lo admite)
	var lightning_w := float(_bg_mood.get("lightning", 0.35))
	if _bg_lightning_t < 0.0 and lightning_w > 0.05 and randf() < delta * (0.02 + lightning_w * 0.12):
		_bg_lightning_t = 0.18
	if _bg_lightning_t >= 0.0:
		_bg_lightning_t -= delta
		if bg:
			var flash := clampf(_bg_lightning_t / 0.18, 0.0, 1.0)
			bg.modulate = Color(1.0 + flash * 0.35, 1.0 + flash * 0.35, 1.0 + flash * 0.5, 1.0)

	# Brillo mojado del FloorPlane
	var floor := get_node_or_null("FloorPlane/WetGloss") as ColorRect
	if floor:
		var wet_w := float(_bg_mood.get("wet", 0.5))
		floor.color.a = (0.03 + absf(sin(_bg_anim_t * 1.4)) * 0.06) * wet_w


func _load_bg() -> void:
	# Prioridad: arena de la misión → resto del catálogo → mapa físico → clásicos.
	var candidates: Array = []
	if _arena_path != "":
		candidates.append(_arena_path)
	for a in CombatRoster.arenas:
		var p := str(a.get("path", ""))
		if p != "" and p != _arena_path:
			candidates.append(p)
	candidates.append(PHYSICS_ARENA)
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
			_ensure_animated_bg()
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
		var hp_max := int(e.get("max_hp", hp_now))
		var hp_bar: ProgressBar = panel.find_child("HpBar", true, false) as ProgressBar
		if hp_bar:
			hp_bar.max_value = float(hp_max)
			hp_bar.value = float(hp_now)
			var ratio := float(hp_now) / maxf(1.0, float(hp_max))
			var is_boss := bool(panel.get_meta("is_boss", false))
			var hp_col := Color(0.95, 0.4, 0.2) if is_boss else Color(0.3, 0.82, 0.4)
			if not is_boss:
				if ratio <= 0.35:
					hp_col = Color(0.95, 0.22, 0.22)
				elif ratio <= 0.65:
					hp_col = Color(0.95, 0.7, 0.22)
			_style_bar(hp_bar, hp_col, BOSS_HP_BAR_H if is_boss else ENEMY_HP_BAR_H, BOSS_HP_BAR_W if is_boss else ENEMY_HP_BAR_W)
		var hp_txt: Label = panel.find_child("HpText", true, false) as Label
		if hp_txt:
			hp_txt.text = "VIDA %d/%d" % [hp_now, hp_max]
			hp_txt.add_theme_font_size_override("font_size", 18 if bool(panel.get_meta("is_boss", false)) else 16)
			hp_txt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			hp_txt.add_theme_constant_override("outline_size", 5)
		var blk_now := int(e.get("block", 0))
		var blk_bar: ProgressBar = panel.find_child("BlockBar", true, false) as ProgressBar
		if blk_bar:
			blk_bar.visible = blk_now > 0
			blk_bar.max_value = maxf(float(hp_max), float(maxi(blk_now, 1)))
			blk_bar.value = float(blk_now)
		var blk_txt: Label = panel.find_child("BlockText", true, false) as Label
		if blk_txt:
			blk_txt.visible = blk_now > 0
			blk_txt.text = "ESCUDO %d" % blk_now
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
	if hurt_path != "" and (ResourceLoader.exists(hurt_path) or FileAccess.file_exists(hurt_path)):
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
		if is_instance_valid(spr) and idle_tex:
			spr.texture = idle_tex
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
	AudioDirector.play_sfx("death_thud", randf_range(0.9, 1.08), -1.0)
	_screen_shake(8.0 if bool(panel.get_meta("is_boss", false)) else 5.0, 0.2)
	var actor: Control = panel.get_node_or_null("ActorSlot")
	var spr: TextureRect = panel.find_child("EnemySprite", true, false)
	var shadow: TextureRect = panel.find_child("Shadow", true, false)
	var is_boss := bool(panel.get_meta("is_boss", false))
	var hurt_path := str(panel.get_meta("pose_hurt", ""))
	if spr and hurt_path != "" and (ResourceLoader.exists(hurt_path) or FileAccess.file_exists(hurt_path)):
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
	tw.tween_property(spr, "rotation_degrees", 92.0, fall_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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
	wrap.custom_minimum_size = Vector2(BOSS_ACTOR_W if is_boss else ACTOR_W + 12.0, 420 if is_boss else 380)
	wrap.alignment = BoxContainer.ALIGNMENT_END
	# No expandir: evita barras de vida estiradas a todo el ancho.
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_theme_constant_override("separation", 5)
	wrap.set_meta("enemy_index", index)
	wrap.set_meta("is_boss", is_boss)
	wrap.set_meta("pose_attack", str(e.get("pose_attack", "")))
	wrap.set_meta("pose_hurt", str(e.get("pose_hurt", "")))
	wrap.set_meta("idle_sprite", str(e.get("sprite", "")))

	var name_l := Label.new()
	name_l.text = str(e.get("name", "Sospechoso"))
	if is_boss:
		name_l.text = "★ " + name_l.text
		name_l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		name_l.add_theme_font_size_override("font_size", 18)
	elif selected and int(e.get("hp", 0)) > 0:
		name_l.text = "▸ " + name_l.text
		name_l.add_theme_color_override("font_color", Color(0.7, 0.96, 1.0))
		name_l.add_theme_font_size_override("font_size", 15)
	else:
		name_l.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		name_l.add_theme_font_size_override("font_size", 14)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.add_theme_constant_override("outline_size", 3)
	wrap.add_child(name_l)

	var alias := str(e.get("alias", ""))
	if alias != "":
		var alias_l := Label.new()
		alias_l.text = alias
		alias_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alias_l.add_theme_font_size_override("font_size", 11)
		alias_l.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 0.95))
		wrap.add_child(alias_l)

	# Barras ENCIMA del cuerpo, ancho fijo y centradas — bien visibles.
	var bars := VBoxContainer.new()
	bars.name = "Bars"
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 3)
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bar_w := BOSS_HP_BAR_W if is_boss else ENEMY_HP_BAR_W
	var bar_h := BOSS_HP_BAR_H if is_boss else ENEMY_HP_BAR_H
	var hp_now := maxi(0, int(e.get("hp", 0)))
	var hp_max := int(e.get("max_hp", 1))
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.max_value = float(hp_max)
	hp_bar.value = float(hp_now)
	var hp_col := Color(0.95, 0.4, 0.2) if is_boss else Color(0.9, 0.28, 0.3)
	var ratio := float(hp_now) / maxf(1.0, float(hp_max))
	if not is_boss:
		if ratio <= 0.35:
			hp_col = Color(0.95, 0.22, 0.22)
		elif ratio <= 0.65:
			hp_col = Color(0.95, 0.7, 0.22)
		else:
			hp_col = Color(0.28, 0.88, 0.4)
	_style_bar(hp_bar, hp_col, bar_h, bar_w)
	bars.add_child(hp_bar)
	var hp_t := Label.new()
	hp_t.name = "HpText"
	hp_t.text = "VIDA %d/%d" % [hp_now, hp_max]
	hp_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_t.add_theme_font_size_override("font_size", 18 if is_boss else 16)
	hp_t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55) if is_boss else Color(1.0, 0.97, 0.92))
	hp_t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	hp_t.add_theme_constant_override("outline_size", 5)
	bars.add_child(hp_t)
	var blk := int(e.get("block", 0))
	var blk_bar := ProgressBar.new()
	blk_bar.name = "BlockBar"
	blk_bar.max_value = maxf(float(hp_max), float(maxi(blk, 1)))
	blk_bar.value = float(blk)
	blk_bar.visible = blk > 0
	_style_bar(blk_bar, Color(0.3, 0.82, 1.0), 14.0 if is_boss else 12.0, bar_w)
	bars.add_child(blk_bar)
	var blk_t := Label.new()
	blk_t.name = "BlockText"
	blk_t.text = "ESCUDO %d" % blk
	blk_t.visible = blk > 0
	blk_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blk_t.add_theme_font_size_override("font_size", 12)
	blk_t.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	blk_t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	blk_t.add_theme_constant_override("outline_size", 3)
	bars.add_child(blk_t)
	wrap.add_child(bars)

	var actor_w := BOSS_ACTOR_W if is_boss else ACTOR_W
	var ground_y := GROUND_Y + (18.0 if is_boss else 0.0)
	var actor_h := ground_y  # sin hueco bajo los pies
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
	shadow.modulate = Color(0.02, 0.02, 0.04, 0.92)
	shadow.position = Vector2(14, ground_y - 22.0)
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
	wrap.set_meta("idle_sprite", sp)
	wrap.set_meta("fidget_cd", 1.0 + float(index) * 0.4)

	if bool(e.get("detained", false)) or bool(e.get("fled", false)):
		wrap.modulate = Color(0.55, 0.55, 0.58, 0.85)
	return wrap


func _rebuild_hand(snap: Dictionary) -> void:
	_hand_deal_token += 1
	var token := _hand_deal_token
	for c in hand_row.get_children():
		c.queue_free()
	var hand: Array = snap.get("hand", [])
	var can_act: bool = int(snap.get("phase", 0)) == CombatState.Phase.PLAYER and bool(snap.get("active", false)) and not _busy
	var sig_parts: PackedStringArray = []
	for card_id in hand:
		sig_parts.append(str(card_id))
	var sig := ",".join(sig_parts)
	var should_deal := sig != _last_hand_sig
	_last_hand_sig = sig
	var wraps: Array = []
	for card_id in hand:
		var cid := str(card_id)
		var playable := can_act and CombatState.can_play_card(cid)
		var wrap := _make_card(cid, playable, should_deal)
		hand_row.add_child(wrap)
		wraps.append(wrap)
	if _hand_label:
		_hand_label.text = "TU MANO · %d" % wraps.size()
	if should_deal and wraps.size() > 0:
		_animate_hand_deal(wraps, token)


func _rebuild_enemy_hand(snap: Dictionary) -> void:
	_ensure_enemy_hand_ui()
	if _enemy_hand_row == null:
		return
	_enemy_deal_token += 1
	var token := _enemy_deal_token
	for c in _enemy_hand_row.get_children():
		c.queue_free()
	var enemies: Array = snap.get("enemies", [])
	var shown := 0
	var wraps: Array = []
	var sig_parts: PackedStringArray = []
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if int(e.get("hp", 0)) <= 0 or bool(e.get("detained", false)) or bool(e.get("fled", false)):
			continue
		var cid := str(e.get("next_card", ""))
		if cid == "":
			continue
		sig_parts.append("%d:%s" % [i, cid])
		var def: Dictionary = CardDB.get_enemy_card(cid)
		if def.is_empty():
			def = {
				"id": cid,
				"name": str(e.get("next_card_name", cid)),
				"effect": str(e.get("next_card_effect", "")),
				"kind": "attack",
			}
		wraps.append({"def": def, "name": str(e.get("name", "Sospechoso")), "index": i})
		shown += 1
	var sig := ",".join(sig_parts)
	var should_deal := sig != _last_enemy_sig
	_last_enemy_sig = sig
	var built: Array = []
	for item in wraps:
		var wrap := _make_bottom_enemy_card(item["def"], item["name"], int(item["index"]), should_deal)
		_enemy_hand_row.add_child(wrap)
		built.append(wrap)
	if _enemy_hand_label:
		_enemy_hand_label.text = ("ELLOS · %d" % shown) if shown > 0 else "ELLOS · —"
	if shown == 0:
		var empty := Label.new()
		empty.text = "—"
		empty.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		_enemy_hand_row.add_child(empty)
	elif should_deal:
		_animate_enemy_hand_deal(built, token)


func _animate_hand_deal(wraps: Array, token: int) -> void:
	## Cartas salen del mazo hacia la mano (stagger).
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _hand_deal_token or not is_inside_tree():
		return
	var deck_origin := deck_count.global_position + deck_count.size * 0.5
	if wraps.size() > 0:
		AudioDirector.play_sfx("whoosh", 1.15, -8.0)
	for i in range(wraps.size()):
		if token != _hand_deal_token:
			return
		var wrap: Control = wraps[i]
		if not is_instance_valid(wrap):
			continue
		var panel: Control = wrap.get_meta("card_panel", wrap) as Control
		if panel == null:
			continue
		wrap.set_meta("dealing", true)
		panel.set_meta("dealing", true)
		# Liberar anchors para animar en coords locales del wrapper.
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.size = Vector2(HAND_CARD_W, HAND_CARD_H)
		var inv := wrap.get_global_transform_with_canvas().affine_inverse()
		var local_from: Vector2 = inv * deck_origin - Vector2(HAND_CARD_W, HAND_CARD_H) * 0.5
		panel.position = local_from
		panel.pivot_offset = Vector2(HAND_CARD_W, HAND_CARD_H) * 0.5
		panel.rotation_degrees = randf_range(-14.0, 14.0)
		panel.scale = Vector2(0.42, 0.42)
		panel.modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "position", Vector2.ZERO, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "rotation_degrees", 0.0, 0.3)
		var final_a := 0.82 if bool(wrap.get_meta("dimmed", false)) else 1.0
		var final_mod := Color(0.7, 0.7, 0.74, final_a) if bool(wrap.get_meta("dimmed", false)) else Color(1, 1, 1, 1)
		tw.tween_property(panel, "modulate", final_mod, 0.18)
		AudioDirector.play_sfx("card_play", randf_range(0.95, 1.12), -6.0)
		await get_tree().create_timer(0.045).timeout
		# Al terminar cada tween, re-anclar (en paralelo al stagger).
		tw.finished.connect(func():
			if is_instance_valid(panel):
				# Top-left fijo: permite hover lift (position.y) sin pelear con anchors.
				panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				panel.size = Vector2(HAND_CARD_W, HAND_CARD_H)
				panel.position = Vector2.ZERO
				panel.scale = Vector2.ONE
				panel.rotation_degrees = 0.0
				panel.set_meta("dealing", false)
			if is_instance_valid(wrap):
				wrap.set_meta("dealing", false)
		)


func _animate_enemy_hand_deal(wraps: Array, token: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _enemy_deal_token or not is_inside_tree():
		return
	for i in range(wraps.size()):
		if token != _enemy_deal_token:
			return
		var wrap: Control = wraps[i]
		if not is_instance_valid(wrap):
			continue
		var panel: Control = wrap.get_meta("card_panel", wrap) as Control
		if panel == null:
			continue
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.size = Vector2(ENEMY_HAND_CARD_W, ENEMY_HAND_CARD_H)
		panel.pivot_offset = panel.size * 0.5
		panel.position = Vector2(0, 36)
		panel.scale = Vector2(0.7, 0.7)
		panel.modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "position", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.24)
		tw.tween_property(panel, "modulate:a", 1.0, 0.16)
		tw.finished.connect(func():
			if is_instance_valid(panel):
				panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				panel.position = Vector2.ZERO
				panel.scale = Vector2.ONE
		)
		await get_tree().create_timer(0.04).timeout


func _card_hover(panel: Control, enter: bool) -> void:
	if not is_instance_valid(panel) or _busy:
		return
	if bool(panel.get_meta("dealing", false)):
		return
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	if enter:
		AudioDirector.play_sfx("ui_click", 1.4, -14.0)
		tw.tween_property(panel, "scale", Vector2(1.07, 1.07), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "position:y", -12.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _make_bottom_enemy_card(def: Dictionary, owner_name: String, enemy_index: int, animate: bool = true) -> Control:
	## Carta en el panel inferior — mismo lenguaje visual que tu mano.
	var kind := CardDB.enemy_card_intent_kind(def)
	var is_boss := str(def.get("id", "")).begins_with("boss_")
	var accent := _enemy_kind_accent(kind, is_boss)

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(ENEMY_HAND_CARD_W, ENEMY_HAND_CARD_H)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(ENEMY_HAND_CARD_W, ENEMY_HAND_CARD_H)
	panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.09, 0.1, 1.0)
	sb.border_color = Color(accent.r, accent.g, accent.b, 1.0)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	if animate:
		panel.modulate.a = 0.0
	wrap.add_child(panel)
	wrap.set_meta("card_panel", panel)

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
	owner_l.add_theme_color_override("font_color", Color(0.9, 0.75, 0.65))
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
	art.custom_minimum_size = Vector2(0, 48)
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
	fx.add_theme_color_override("font_color", Color(0.82, 0.9, 0.98))
	v.add_child(fx)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.tooltip_text = "Ver mazo completo de %s" % owner_name
	var idx := enemy_index
	btn.pressed.connect(func(): _open_enemy_card_menu(idx))
	panel.add_child(btn)
	return wrap


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


func _make_card(card_id: String, playable: bool, animate: bool = true) -> Control:
	var def := CardDB.get_card(card_id)
	var card_type := str(def.get("type", ""))
	var rarity := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var accent := CardDB.rarity_color(rarity)
	var type_col := _type_accent(card_type)

	# Wrapper fijo: el panel animado vive dentro sin romper el HBox.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(HAND_CARD_W, HAND_CARD_H)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.clip_contents = false

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(HAND_CARD_W, HAND_CARD_H)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.18, 0.26, 1.0)
	sb.border_color = Color(accent.r, accent.g, accent.b, 1.0 if playable else 0.45)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", sb)
	if animate:
		if not playable:
			panel.modulate = Color(0.75, 0.75, 0.78, 0.0)
		else:
			panel.modulate.a = 0.0
	elif not playable:
		panel.modulate = Color(0.75, 0.75, 0.78, 0.88)
	wrap.add_child(panel)
	wrap.set_meta("card_panel", panel)
	wrap.set_meta("card_id", card_id)
	wrap.set_meta("dealing", animate)
	wrap.set_meta("dimmed", not playable)
	panel.set_meta("dealing", animate)

	var stack := Control.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
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
	art.custom_minimum_size = Vector2(0, 72)
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
	text_box.custom_minimum_size = Vector2(0, 56)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.05, 0.08, 0.12, 0.92)
	tsb.set_corner_radius_all(8)
	tsb.content_margin_left = 5
	tsb.content_margin_right = 5
	tsb.content_margin_top = 4
	tsb.content_margin_bottom = 4
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
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	name_l.custom_minimum_size = Vector2(0, 26)
	tv.add_child(name_l)

	var fx := Label.new()
	fx.text = CardDB.effect_line(def)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.max_lines_visible = 2
	fx.clip_text = true
	fx.add_theme_font_size_override("font_size", 11)
	fx.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.custom_minimum_size = Vector2(0, 18)
	tv.add_child(fx)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.mouse_entered.connect(func(): _card_hover(panel, true))
	btn.mouse_exited.connect(func(): _card_hover(panel, false))
	btn.pressed.connect(func(): _try_play_card(card_id, wrap))
	panel.add_child(btn)
	return wrap


func _try_play_card(card_id: String, wrap: Control) -> void:
	if _busy or not CombatState.can_play_card(card_id):
		return
	_busy = true
	var panel: Control = wrap
	if is_instance_valid(wrap) and wrap.has_meta("card_panel"):
		panel = wrap.get_meta("card_panel") as Control
	await _play_card_fx(panel if panel else wrap, card_id)
	if not CombatState.is_active() or CombatState.phase != CombatState.Phase.PLAYER:
		_busy = false
		_refresh()
		return
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
			var ewrap := _enemy_wrap(i)
			if ewrap:
				await _start_enemy_death(ewrap, i, prev)
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
	AudioDirector.play_sfx("card_play", randf_range(0.94, 1.08), -1.0)

	var ghost := panel.duplicate()
	_fx_layer.add_child(ghost)
	ghost.global_position = panel.global_position
	ghost.pivot_offset = ghost.size * 0.5
	# Oculta la carta original mientras vuela el fantasma.
	panel.modulate.a = 0.15
	var target := get_viewport_rect().size * Vector2(0.5, 0.38) - Vector2(HAND_CARD_W * 0.5, HAND_CARD_H * 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.22, 1.22), 0.28)
	tw.tween_property(ghost, "rotation_degrees", randf_range(-6.0, 6.0), 0.28)
	await tw.finished

	if is_attack:
		await _hero_attack_sequence(def)
	elif is_block:
		_apply_hero_pose("aim", 0.45)
		await _hero_guard_pulse()
	else:
		_apply_hero_pose("aim", 0.28)
		AudioDirector.play_sfx("whoosh", 1.1, -3.0)
		await _screen_pulse(Color(0.4, 0.85, 1.0, 0.22))

	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tw2.tween_property(ghost, "scale", Vector2(1.35, 1.35), 0.16)
	await tw2.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	log_label.text = "Activada: %s" % str(def.get("name", card_id))


func _hero_guard_pulse() -> void:
	if _player_actor == null:
		await get_tree().create_timer(0.2).timeout
		return
	AudioDirector.play_sfx("block", randf_range(0.95, 1.08), -1.0)
	var base := _player_base_pos
	player_sprite.set_meta("anim_locked", true)
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(player_sprite, "scale", Vector2(1.04, 0.94), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _player_shadow:
		tw0.tween_property(_player_shadow, "scale", Vector2(1.12, 0.9), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw0.finished
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_player_actor, "position", base + Vector2(-22, 0), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_sprite, "modulate", Color(0.55, 0.88, 1.0), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player_sprite, "scale", Vector2(0.98, 1.03), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_spawn_fx_at(player_sprite, "impact", Vector2(70, 110), 0.35, Color(0.45, 0.85, 1.0))
	_spawn_fx_at(player_sprite, "impact", Vector2(50, 140), 0.4, Color(0.7, 0.95, 1.0))
	_screen_shake(3.0, 0.16)
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
	tws.tween_property(shield, "scale", Vector2(4.2, 5.0), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tws.tween_property(shield, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE)
	await tws.finished
	if is_instance_valid(shield):
		shield.queue_free()
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_player_actor, "position", base, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player_sprite, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(player_sprite, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _player_shadow:
		tw2.tween_property(_player_shadow, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	player_sprite.set_meta("anim_locked", false)


func _hero_attack_sequence(def: Dictionary) -> void:
	var melee := _card_is_melee(def)
	_apply_hero_pose("punch" if melee else "shoot", 1.05)
	AudioDirector.play_sfx("whoosh", randf_range(0.92, 1.1), -2.0)
	if _player_actor == null:
		await get_tree().create_timer(0.25).timeout
		return
	player_sprite.set_meta("anim_locked", true)
	var base := _player_base_pos
	# Wind-up suave
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(_player_actor, "position", base + Vector2(-34, 2), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw0.tween_property(player_sprite, "rotation_degrees", -8.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw0.tween_property(player_sprite, "scale", Vector2(1.08, 0.92), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _player_shadow:
		tw0.tween_property(_player_shadow, "scale", Vector2(1.16, 0.88), 0.22).set_trans(Tween.TRANS_SINE)
	await tw0.finished
	# Lunge fluido
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_player_actor, "position", base + Vector2(96, 1), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player_sprite, "rotation_degrees", 6.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player_sprite, "scale", Vector2(0.95, 1.06), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _player_shadow:
		tw.tween_property(_player_shadow, "scale", Vector2(1.28, 0.78), 0.26).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var foot := player_sprite.global_position + Vector2(player_sprite.size.x * 0.5, player_sprite.size.y - 4.0)
	_spawn_dust_puff(foot, 1.1)
	AudioDirector.play_sfx("foot_plant", randf_range(0.9, 1.15), -2.0)
	var muzzle_pos := player_sprite.global_position + Vector2(player_sprite.size.x * 0.72, player_sprite.size.y * 0.42)
	if melee:
		AudioDirector.play_sfx("punch", randf_range(0.92, 1.1), 0.0)
		_spawn_fx_world(muzzle_pos, "impact", 0.22, Vector2(1.35, 1.35))
	else:
		AudioDirector.play_sfx("gunshot", randf_range(0.94, 1.06), 0.0)
		_spawn_fx_world(muzzle_pos, "muzzle", 0.2, Vector2(1.45, 1.45))
		await get_tree().create_timer(0.04).timeout
		_spawn_fx_world(muzzle_pos + Vector2(10, -5), "muzzle", 0.16, Vector2(1.0, 1.0))
	await _screen_pulse(Color(1.0, 0.72, 0.22, 0.26))
	_screen_shake(5.5 if melee else 7.0, 0.2)
	var enemy_node := _selected_enemy_sprite()
	var hit_pos := get_viewport_rect().size * Vector2(0.72, 0.48)
	if enemy_node and is_instance_valid(enemy_node):
		hit_pos = enemy_node.global_position + Vector2(enemy_node.size.x * 0.45, enemy_node.size.y * 0.48)
	if not melee:
		await _fly_tracer(muzzle_pos, hit_pos)
	else:
		await get_tree().create_timer(0.05).timeout
	_spawn_fx_world(hit_pos, "impact", 0.32, Vector2(1.55, 1.55))
	_spawn_blood_burst(hit_pos, 1.45)
	AudioDirector.play_sfx("hit_impact", randf_range(0.9, 1.12), -1.0)
	if enemy_node and is_instance_valid(enemy_node):
		_spawn_dust_puff(enemy_node.global_position + Vector2(enemy_node.size.x * 0.5, enemy_node.size.y - 2.0), 1.2)
		await _hit_actor_heavy(enemy_node, maxi(1, int(def.get("damage", 8))), true)
	# Recoil + retorno suave
	var twr := create_tween()
	twr.set_parallel(true)
	twr.tween_property(_player_actor, "position", base + Vector2(36, 2), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	twr.tween_property(player_sprite, "rotation_degrees", -4.0, 0.16).set_trans(Tween.TRANS_SINE)
	twr.tween_property(player_sprite, "scale", Vector2(1.03, 0.97), 0.16).set_trans(Tween.TRANS_SINE)
	await twr.finished
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_player_actor, "position", base, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player_sprite, "rotation_degrees", 0.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player_sprite, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _player_shadow:
		tw2.tween_property(_player_shadow, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_SINE)
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
	AudioDirector.play_sfx("whoosh", randf_range(0.85, 1.05), -1.0)
	if attack_path != "" and (ResourceLoader.exists(attack_path) or FileAccess.file_exists(attack_path)):
		var at := _load_combat_tex(attack_path)
		if at:
			spr.texture = at
	var wind := Vector2(16, 2) if is_boss else Vector2(10, 1)
	var lunge := Vector2(-132, -4) if is_boss else Vector2(-86, -1)
	var wind_t := 0.22 if is_boss else 0.18
	var lunge_t := 0.3 if is_boss else 0.24
	var ret_t := 0.36 if is_boss else 0.3
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(spr, "position", base + wind, wind_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw0.tween_property(spr, "rotation_degrees", 6.0 if is_boss else 4.0, wind_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw0.tween_property(spr, "scale", Vector2(1.06, 0.92) if is_boss else Vector2(1.04, 0.94), wind_t).set_trans(Tween.TRANS_SINE)
	await tw0.finished
	if is_boss:
		var twp := create_tween()
		twp.tween_property(spr, "position", base + wind + Vector2(6, 0), 0.1).set_trans(Tween.TRANS_SINE)
		twp.tween_property(spr, "position", base + wind + Vector2(-3, 0), 0.12).set_trans(Tween.TRANS_SINE)
		await twp.finished
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "position", base + lunge, lunge_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "rotation_degrees", -9.0 if is_boss else -5.0, lunge_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "scale", Vector2(0.92, 1.1) if is_boss else Vector2(0.96, 1.05), lunge_t).set_trans(Tween.TRANS_SINE)
	if shadow:
		tw.tween_property(shadow, "scale", Vector2(1.35, 0.78) if is_boss else Vector2(1.22, 0.84), lunge_t).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if is_boss:
		await _screen_pulse(Color(1.0, 0.55, 0.2, 0.28))
	var muzzle := spr.global_position + Vector2(24, spr.size.y * 0.48)
	AudioDirector.play_sfx("gunshot", randf_range(0.88, 1.05), -1.5 if not is_boss else 0.0)
	_spawn_fx_world(muzzle, "muzzle", 0.2 if is_boss else 0.18, Vector2(1.4, 1.4) if is_boss else Vector2(1.15, 1.15))
	await get_tree().create_timer(0.04).timeout
	_spawn_fx_world(muzzle + Vector2(-6, 3), "muzzle", 0.14, Vector2(0.9, 0.9) if is_boss else Vector2(0.8, 0.8))
	if is_boss:
		_spawn_fx_world(muzzle + Vector2(-14, -4), "muzzle", 0.12, Vector2(0.7, 0.7))
	var target := player_sprite.global_position + Vector2(90, player_sprite.size.y * 0.55)
	await _fly_tracer(muzzle, target)
	AudioDirector.play_sfx("hit_impact", randf_range(0.9, 1.1), -1.0)
	_screen_shake(7.5 if is_boss else 4.5, 0.22 if is_boss else 0.18)
	_apply_hero_pose("hurt", 0.4)
	_spawn_fx_world(target, "impact", 0.32 if is_boss else 0.28, Vector2(1.45, 1.45) if is_boss else Vector2(1.25, 1.25))
	_spawn_blood_burst(target, 1.45 if is_boss else 1.1)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(spr, "position", base, ret_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(spr, "rotation_degrees", 0.0, ret_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(spr, "scale", Vector2.ONE, ret_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if shadow:
		tw2.tween_property(shadow, "scale", Vector2.ONE, ret_t).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	if idle_tex:
		spr.texture = idle_tex
	if is_instance_valid(wrap):
		wrap.set_meta("anim_locked", false)


func _hit_actor_heavy(node: CanvasItem, dmg: int, knock_right: bool) -> void:
	if not is_instance_valid(node):
		await get_tree().process_frame
		return
	AudioDirector.play_sfx("hit_impact", randf_range(0.92, 1.1), -2.0)
	_screen_shake(4.0 + minf(6.0, float(dmg) * 0.28), 0.18)
	var base: Vector2 = node.position
	var dir := 1.0 if knock_right else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate", Color(1.0, 0.35, 0.35), 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation_degrees", 6.0 * dir, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", base + Vector2(22 * dir, -8), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_instance_valid(node):
		return
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(node, "position", base + Vector2(-6 * dir, 2), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(node, "rotation_degrees", -2.0 * dir, 0.14).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	if not is_instance_valid(node):
		return
	var tw3 := create_tween()
	tw3.set_parallel(true)
	tw3.tween_property(node, "position", base, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw3.tween_property(node, "rotation_degrees", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw3.tween_property(node, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_SINE)
	_spawn_dmg_number(node, dmg)
	await tw3.finished


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
	tw.set_parallel(true)
	tw.tween_property(tracer, "global_position", to - Vector2(6, 4), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(tracer, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(tracer):
		tracer.queue_free()


func _spawn_fx_at(node: CanvasItem, fx_name: String, offset: Vector2, life: float, tint: Color = Color.WHITE) -> void:
	if not is_instance_valid(node):
		return
	_spawn_fx_world(node.global_position + offset, fx_name, life, Vector2.ONE, tint)



func _spawn_dust_puff(pos: Vector2, power: float = 1.0) -> void:
	## Polvo con caída (física visual) al plantar pie / impactar suelo.
	if power >= 1.0:
		AudioDirector.play_sfx("foot_plant", randf_range(0.88, 1.2), -6.0)
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
	tw.tween_property(fx, "scale", sc * 1.28, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	tw.set_parallel(true)
	tw.tween_property(node, "position", base + Vector2(14 * dir, -3), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate", Color(1.0, 0.4, 0.4), 0.08).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(node, "position", base + Vector2(-5 * dir, 1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	var tw3 := create_tween()
	tw3.set_parallel(true)
	tw3.tween_property(node, "position", base, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw3.tween_property(node, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_SINE)
	_spawn_dmg_number(node, dmg)
	await tw3.finished


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


func _on_enemy_defeated(enemy_index: int, xp_gained: int) -> void:
	## Feedback inmediato de progresión al matar.
	if xp_gained <= 0:
		return
	var wrap := _enemy_wrap(enemy_index)
	var pos := Vector2(size.x * 0.72, size.y * 0.35)
	if wrap and is_instance_valid(wrap):
		var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
		if spr:
			pos = spr.global_position + Vector2(spr.size.x * 0.35, 8)
		else:
			pos = wrap.global_position + Vector2(40, 20)
	_spawn_float_label(pos, "+%d XP" % xp_gained, Color(0.55, 0.9, 1.0))
	if CombatState.combat_levels_gained > 0 or GameState.pending_level_packs > 0:
		_spawn_float_label(pos + Vector2(0, 28), "¡NIVEL!", Color(1.0, 0.85, 0.35))
	# Pulso del chip de XP en HUD
	if is_instance_valid(location_label):
		var tw := create_tween()
		tw.tween_property(location_label, "modulate", Color(0.5, 1.0, 1.0), 0.08)
		tw.tween_property(location_label, "modulate", Color.WHITE, 0.25)


func _spawn_float_label(global_pos: Vector2, text: String, col: Color) -> void:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 26)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 5)
	lab.z_index = 120
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fx_layer:
		_fx_layer.add_child(lab)
	else:
		add_child(lab)
	lab.global_position = global_pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "global_position", global_pos + Vector2(0, -54), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lab, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tw.chain().tween_callback(lab.queue_free)
