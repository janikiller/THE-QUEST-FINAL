extends Control
## Combate: suelo anclado, muerte con caída, escudo, cartas y barras minimalistas.

const PACK_HERO := "res://assets/combat/custom/hero/"
const PACK_FOE := "res://assets/combat/custom/foes/"
const FX_DIR := "res://assets/combat/custom/fx/"
const GROUND_Y := 236.0

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


func _hero_tex(name: String) -> Texture2D:
	var path := PACK_HERO + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _fx_tex(name: String) -> Texture2D:
	var path := FX_DIR + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


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


func _tick_hero_pose() -> void:
	if _hero_pose == "idle":
		return
	if Time.get_ticks_msec() / 1000.0 >= _hero_pose_until:
		_apply_hero_pose("idle")


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
	_fx_layer = Control.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 80
	add_child(_fx_layer)
	_setup_player_actor()
	_ensure_player_block_bar()
	_ground_arena_layout()
	set_process(true)


func _ground_arena_layout() -> void:
	## Baja columnas para que los pies toquen el suelo visual del callejón.
	var player_col := get_node_or_null("Arena/PlayerCol")
	if player_col:
		player_col.offset_top = -40.0
		player_col.offset_bottom = 285.0
		player_col.alignment = BoxContainer.ALIGNMENT_END
	if enemies_row:
		enemies_row.offset_top = -60.0
		enemies_row.offset_bottom = 285.0
		enemies_row.alignment = BoxContainer.ALIGNMENT_END
	if player_marker:
		player_marker.visible = false


func _setup_player_actor() -> void:
	if player_sprite.get_parent() == null:
		return
	if player_sprite.get_parent().name == "PlayerActor":
		_player_actor = player_sprite.get_parent()
		_player_shadow = _player_actor.get_node_or_null("Shadow")
		return
	var parent := player_sprite.get_parent()
	var idx := player_sprite.get_index()
	_player_actor = Control.new()
	_player_actor.name = "PlayerActor"
	_player_actor.custom_minimum_size = Vector2(200, 300)
	_player_actor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_player_actor)
	parent.move_child(_player_actor, idx)
	parent.remove_child(player_sprite)
	_player_actor.add_child(player_sprite)
	player_sprite.set_anchors_preset(Control.PRESET_TOP_WIDE)
	player_sprite.anchor_bottom = 0.0
	player_sprite.offset_left = 0
	player_sprite.offset_right = 0
	player_sprite.offset_top = 0
	player_sprite.offset_bottom = GROUND_Y - 8.0
	player_sprite.custom_minimum_size = Vector2(200, GROUND_Y - 8.0)
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.position = Vector2(0, 8)
	_player_shadow = TextureRect.new()
	_player_shadow.name = "Shadow"
	_player_shadow.texture = _fx_tex("shadow")
	_player_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_player_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_shadow.modulate = Color(0, 0, 0, 0.92)
	_player_actor.add_child(_player_shadow)
	_player_actor.move_child(_player_shadow, 0)
	_layout_ground_shadow(_player_shadow, _player_actor, 160.0)
	_player_base_pos = _player_actor.position


func _layout_ground_shadow(shadow: TextureRect, actor: Control, width: float) -> void:
	if shadow == null or actor == null:
		return
	var h := 38.0
	shadow.size = Vector2(width + 24.0, h)
	shadow.position = Vector2((actor.size.x - width - 24.0) * 0.5 if actor.size.x > 0.0 else (200.0 - width) * 0.5, GROUND_Y - 6.0)
	shadow.pivot_offset = Vector2((width + 24.0) * 0.5, h * 0.5)


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
	if not visible or _busy:
		return
	_bob_t += delta
	_tick_hero_pose()
	_idle_bob_player()
	_idle_bob_enemies()


func _idle_bob_player() -> void:
	if _player_actor == null or not is_instance_valid(_player_actor):
		return
	# Solo el sprite respira; la sombra queda fija en el suelo.
	var bob := sin(_bob_t * 2.0) * 1.6
	player_sprite.position.y = bob
	if _player_shadow:
		_layout_ground_shadow(_player_shadow, _player_actor, 160.0)
		var squash := 1.0 + sin(_bob_t * 2.0) * 0.04
		_player_shadow.scale = Vector2(squash, 1.0)
		_player_shadow.modulate.a = 0.62 + absf(sin(_bob_t * 2.0)) * 0.08


func _idle_bob_enemies() -> void:
	var i := 0
	for wrap in enemies_row.get_children():
		if not is_instance_valid(wrap):
			continue
		if bool(wrap.get_meta("fallen", false)):
			continue
		var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
		var shadow: TextureRect = wrap.find_child("Shadow", true, false)
		if spr == null:
			continue
		var is_boss := bool(wrap.get_meta("is_boss", false))
		var amp := 2.8 if is_boss else 1.5
		var sway := 1.4 if is_boss else 0.6
		var speed := 1.55 if is_boss else 1.9
		var phase := _bob_t * speed + float(i) * 0.85
		# Gestos de respiración / amenaza del Capo
		if is_boss:
			var pulse := 1.0 + sin(phase * 0.55) * 0.025
			spr.scale = Vector2(pulse, 2.0 - pulse)
			spr.rotation_degrees = sin(phase * 0.45) * 2.2
		spr.position.y = sin(phase) * amp
		spr.position.x = cos(phase * 0.7) * sway
		if shadow:
			var squash := 1.0 + sin(phase) * (0.055 if is_boss else 0.035)
			shadow.scale = Vector2(squash * (1.15 if is_boss else 1.0), 1.0)
			shadow.modulate.a = 0.6 + absf(sin(phase)) * 0.08
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
	result_panel.visible = false
	_prev_enemy_hp.clear()
	_prev_player_hp = -1
	_prev_player_block = 0
	visible = true
	CombatState.start_combat(cfg)
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
	var panel := get_node_or_null("Bottom/BottomPanel")
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.05, 0.08, 0.88)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)


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
	result_title.text = "INTERVENCIÓN EXITOSA" if victory else "UNIDAD CAÍDA"
	result_title.add_theme_color_override(
		"font_color",
		Color(0.35, 0.9, 0.55) if victory else Color(1.0, 0.4, 0.4)
	)


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
	objective_label.text = "OBJETIVO: %s" % str(snap.get("objective", ""))
	log_label.text = str(snap.get("last_log", ""))
	deck_count.text = "MAZO\n%d" % int(snap.get("draw_count", 0))
	discard_count.text = "DESCARTES\n%d" % int(snap.get("discard_count", 0))
	_style_player_bars(p)

	var php := int(p.get("hp", 0))
	if _prev_player_hp >= 0 and php < _prev_player_hp and not _busy:
		_apply_hero_pose("hurt", 0.55)
		_hit_actor(player_sprite, _prev_player_hp - php, false)
		_spawn_fx_at(player_sprite, "blood", Vector2(40, 80), 0.45)
	_prev_player_hp = php
	_prev_player_block = int(p.get("block", 0))

	_tick_hero_pose()
	if player_sprite.texture == null:
		_apply_hero_pose(_hero_pose)

	_load_bg()
	if not _busy:
		_rebuild_enemies(snap)
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
	for path in [
		"res://assets/combat/bg/alley_night.jpg",
		"res://assets/combat/bg/alley_night2.jpg",
		"res://assets/combat/bg/combat_arena.jpg",
	]:
		if ResourceLoader.exists(path):
			bg.texture = load(path)
			return


func _rebuild_enemies(snap: Dictionary) -> void:
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


func _make_empty_slot(index: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(160, 320)
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
	if is_boss and hurt_path != "" and ResourceLoader.exists(hurt_path):
		spr.texture = load(hurt_path)
	if is_boss:
		_hit_actor_heavy(spr, dmg, true)
		spr.modulate = Color(2.0, 1.6, 1.6)
		_spawn_fx_at(spr, "impact", Vector2(48, 100), 0.35)
		_spawn_fx_at(spr, "blood", Vector2(56, 110), 0.4)
		_screen_pulse(Color(1.0, 0.35, 0.2, 0.28))
		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(spr):
			spr.modulate = Color.WHITE
			if idle_tex:
				spr.texture = idle_tex
	else:
		_hit_actor(spr, dmg, true)
		_spawn_fx_at(spr, "impact", Vector2(40, 90), 0.3)
		_spawn_fx_at(spr, "blood", Vector2(50, 100), 0.35)


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
	if spr and is_boss and hurt_path != "" and ResourceLoader.exists(hurt_path):
		spr.texture = load(hurt_path)
	if spr:
		_spawn_dmg_number(spr, dmg)
		_spawn_fx_at(spr, "impact", Vector2(40, 90), 0.3)
		_spawn_fx_at(spr, "blood", Vector2(40, 100), 0.55)
		if is_boss:
			_spawn_fx_at(spr, "blood", Vector2(70, 80), 0.6)
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
	wrap.custom_minimum_size = Vector2(210 if is_boss else 168, 380 if is_boss else 340)
	wrap.alignment = BoxContainer.ALIGNMENT_END
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.set_meta("enemy_index", index)
	wrap.set_meta("is_boss", is_boss)
	wrap.set_meta("pose_attack", str(e.get("pose_attack", "")))
	wrap.set_meta("pose_hurt", str(e.get("pose_hurt", "")))
	wrap.set_meta("idle_sprite", str(e.get("sprite", "")))

	var intent := Label.new()
	var intent_id := int(e.get("intent", 0))
	var val := int(e.get("intent_value", 0))
	if bool(e.get("detained", false)):
		intent.text = "DETENIDO"
		intent.add_theme_color_override("font_color", Color(0.4, 0.9, 0.55))
	elif bool(e.get("fled", false)):
		intent.text = "HUYÓ"
		intent.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	elif int(e.get("hp", 0)) <= 0:
		intent.text = ""
	elif intent_id == CombatState.Intent.ATTACK and val > 0:
		intent.text = ("◆  %d" % val) if is_boss else ("●  %d" % val)
		intent.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	elif intent_id == CombatState.Intent.BLOCK and val > 0:
		intent.text = "◈  %d" % val
		intent.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0))
	elif intent_id == CombatState.Intent.FLEE:
		intent.text = "→ HUIR"
		intent.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	else:
		intent.text = CombatState.intent_label(intent_id)
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.add_theme_font_size_override("font_size", 16 if is_boss else 14)
	wrap.add_child(intent)

	var name_l := Label.new()
	name_l.text = str(e.get("name", "Sospechoso"))
	if is_boss:
		name_l.text = "★ " + name_l.text
		name_l.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
		name_l.add_theme_font_size_override("font_size", 15)
	elif selected and int(e.get("hp", 0)) > 0:
		name_l.text = "▸ " + name_l.text
		name_l.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		name_l.add_theme_font_size_override("font_size", 12)
	else:
		name_l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		name_l.add_theme_font_size_override("font_size", 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(name_l)

	# Barras ENCIMA del cuerpo (no bajo los pies) para no flotar
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(168 if is_boss else 132, 10 if is_boss else 8)
	hp_bar.max_value = float(e.get("max_hp", 1))
	hp_bar.value = float(maxi(0, int(e.get("hp", 0))))
	_style_bar(hp_bar, Color(0.95, 0.35, 0.18) if is_boss else Color(0.86, 0.22, 0.28), 10.0 if is_boss else 8.0)
	bars.add_child(hp_bar)
	var hp_t := Label.new()
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

	var actor_w := 196.0 if is_boss else 160.0
	var actor_h := 290.0 if is_boss else 250.0
	var actor := Control.new()
	actor.name = "ActorSlot"
	actor.custom_minimum_size = Vector2(actor_w, actor_h)
	actor.clip_contents = false

	var shadow := TextureRect.new()
	shadow.name = "Shadow"
	shadow.texture = _fx_tex("shadow")
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = Color(0, 0, 0, 0.9)
	shadow.position = Vector2(8, GROUND_Y - 6.0)
	shadow.size = Vector2(actor_w - 16.0, 36 if not is_boss else 42)
	shadow.pivot_offset = Vector2((actor_w - 16.0) * 0.5, 18)
	actor.add_child(shadow)

	var btn := Button.new()
	btn.name = "SelectBtn"
	btn.position = Vector2.ZERO
	btn.size = Vector2(actor_w, GROUND_Y)
	btn.flat = true
	btn.clip_contents = false
	var tex := TextureRect.new()
	tex.name = "EnemySprite"
	tex.position = Vector2(0, 8 if is_boss else 18)
	tex.size = Vector2(actor_w, GROUND_Y - (6.0 if is_boss else 14.0))
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.pivot_offset = Vector2(actor_w * 0.5, (GROUND_Y - 14.0) * 0.7)
	# Prioridad: sprite propio del enemigo (boss) → pack por índice
	var sp := str(e.get("sprite", ""))
	if sp == "" or not ResourceLoader.exists(sp):
		sp = PACK_FOE + "enemy_%d.png" % (index % 7)
	if not ResourceLoader.exists(sp):
		sp = PACK_FOE + "enemy_0.png"
	if ResourceLoader.exists(sp):
		tex.texture = load(sp)
	btn.add_child(tex)
	btn.pressed.connect(func(): CombatState.select_enemy(index))
	actor.add_child(btn)
	wrap.add_child(actor)

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


func _type_accent(card_type: String) -> Color:
	match card_type:
		"ataque":
			return Color(0.95, 0.4, 0.35)
		"defensa":
			return Color(0.4, 0.75, 1.0)
		"tactica":
			return Color(0.55, 0.9, 0.65)
		"especial":
			return Color(0.95, 0.75, 0.35)
		_:
			return Color(0.55, 0.65, 0.75)


func _make_card(card_id: String, playable: bool) -> Control:
	var def := CardDB.get_card(card_id)
	var card_type := str(def.get("type", ""))
	var accent := _type_accent(card_type)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 198)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11, 0.94)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55 if playable else 0.22)
	sb.border_width_left = 1
	sb.border_width_top = 3
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	if not playable:
		panel.modulate = Color(0.6, 0.6, 0.65, 0.75)

	var root := Control.new()
	root.custom_minimum_size = Vector2(112, 178)
	panel.add_child(root)

	# Cost badge
	var cost_bg := Panel.new()
	cost_bg.position = Vector2(0, 0)
	cost_bg.size = Vector2(28, 28)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.1, 0.35, 0.55, 0.95)
	csb.set_corner_radius_all(14)
	cost_bg.add_theme_stylebox_override("panel", csb)
	root.add_child(cost_bg)
	var cost := Label.new()
	cost.text = str(int(def.get("cost", 0)))
	cost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 15)
	cost.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	cost_bg.add_child(cost)

	var art := TextureRect.new()
	art.position = Vector2(16, 34)
	art.size = Vector2(80, 70)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	root.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", card_id))
	name_l.position = Vector2(0, 108)
	name_l.size = Vector2(112, 34)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	root.add_child(name_l)

	var fx := Label.new()
	fx.text = str(def.get("effect", ""))
	fx.position = Vector2(0, 142)
	fx.size = Vector2(112, 36)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD
	fx.add_theme_font_size_override("font_size", 10)
	fx.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(fx)

	var btn := Button.new()
	btn.flat = true
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
	var base := _player_base_pos
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(_player_actor, "position", base + Vector2(-18, 3), 0.12).set_trans(Tween.TRANS_CUBIC)
	tw0.tween_property(player_sprite, "rotation_degrees", -4.0, 0.12)
	tw0.tween_property(player_sprite, "scale", Vector2(1.08, 0.9), 0.12)
	if _player_shadow:
		tw0.tween_property(_player_shadow, "scale", Vector2(1.18, 0.85), 0.12)
	await tw0.finished
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_player_actor, "position", base + Vector2(78, -2), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_sprite, "rotation_degrees", 6.0, 0.14)
	tw.tween_property(player_sprite, "scale", Vector2(0.95, 1.08), 0.14)
	if _player_shadow:
		tw.tween_property(_player_shadow, "scale", Vector2(1.35, 0.75), 0.14)
	await tw.finished
	var muzzle_pos := player_sprite.global_position + Vector2(135, 115)
	_spawn_fx_world(muzzle_pos, "muzzle", 0.16, Vector2(1.35, 1.35))
	await get_tree().create_timer(0.04).timeout
	_spawn_fx_world(muzzle_pos + Vector2(8, -4), "muzzle", 0.14, Vector2(0.9, 0.9))
	await _screen_pulse(Color(1.0, 0.82, 0.3, 0.26))
	var enemy_node := _selected_enemy_sprite()
	var hit_pos := get_viewport_rect().size * Vector2(0.72, 0.48)
	if enemy_node and is_instance_valid(enemy_node):
		hit_pos = enemy_node.global_position + Vector2(70, enemy_node.size.y * 0.55)
	await _fly_tracer(muzzle_pos, hit_pos)
	_spawn_fx_world(hit_pos, "impact", 0.28, Vector2(1.55, 1.55))
	_spawn_fx_world(hit_pos + Vector2(12, -8), "impact", 0.22, Vector2(0.85, 0.85))
	_spawn_fx_world(hit_pos + Vector2(6, 10), "blood", 0.4, Vector2(1.25, 1.25))
	if enemy_node and is_instance_valid(enemy_node):
		await _hit_actor_heavy(enemy_node, maxi(1, int(def.get("damage", 8))), true)
	var twr := create_tween()
	twr.set_parallel(true)
	twr.tween_property(_player_actor, "position", base + Vector2(40, 0), 0.08)
	twr.tween_property(player_sprite, "rotation_degrees", -2.0, 0.08)
	await twr.finished
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_player_actor, "position", base, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player_sprite, "rotation_degrees", 0.0, 0.24)
	tw2.tween_property(player_sprite, "scale", Vector2.ONE, 0.24)
	if _player_shadow:
		tw2.tween_property(_player_shadow, "scale", Vector2.ONE, 0.24)
	await tw2.finished


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
	var actor: Control = wrap.get_node_or_null("ActorSlot")
	var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
	var shadow: TextureRect = wrap.find_child("Shadow", true, false)
	if actor == null or spr == null:
		return
	var is_boss := bool(wrap.get_meta("is_boss", false))
	var attack_path := str(wrap.get_meta("pose_attack", ""))
	var idle_tex: Texture2D = spr.texture
	if is_boss and attack_path != "" and ResourceLoader.exists(attack_path):
		spr.texture = load(attack_path)
	var base := actor.position
	var wind := Vector2(18, 3) if is_boss else Vector2(14, 2)
	var lunge := Vector2(-96, -6) if is_boss else Vector2(-62, -2)
	var tw0 := create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(actor, "position", base + wind, 0.14 if is_boss else 0.1)
	tw0.tween_property(spr, "rotation_degrees", 8.0 if is_boss else 5.0, 0.14 if is_boss else 0.1)
	tw0.tween_property(spr, "scale", Vector2(1.1, 0.88) if is_boss else Vector2(1.06, 0.92), 0.14 if is_boss else 0.1)
	await tw0.finished
	# Gesto de pump / amenaza del Capo
	if is_boss:
		var twp := create_tween()
		twp.tween_property(spr, "position:x", spr.position.x + 6.0, 0.06)
		twp.tween_property(spr, "position:x", spr.position.x - 2.0, 0.08)
		await twp.finished
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(actor, "position", base + lunge, 0.18 if is_boss else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "rotation_degrees", -10.0 if is_boss else -7.0, 0.18 if is_boss else 0.14)
	tw.tween_property(spr, "scale", Vector2(0.9, 1.14) if is_boss else Vector2(0.94, 1.08), 0.18 if is_boss else 0.14)
	if shadow:
		tw.tween_property(shadow, "scale", Vector2(1.45, 0.72) if is_boss else Vector2(1.3, 0.78), 0.14)
	await tw.finished
	if is_boss:
		_screen_pulse(Color(1.0, 0.55, 0.2, 0.32))
	var muzzle := spr.global_position + Vector2(24, spr.size.y * 0.48)
	_spawn_fx_world(muzzle, "muzzle", 0.18 if is_boss else 0.16, Vector2(1.45, 1.45) if is_boss else Vector2(1.2, 1.2))
	await get_tree().create_timer(0.03).timeout
	_spawn_fx_world(muzzle + Vector2(-6, 3), "muzzle", 0.12, Vector2(0.9, 0.9) if is_boss else Vector2(0.8, 0.8))
	if is_boss:
		_spawn_fx_world(muzzle + Vector2(-14, -4), "muzzle", 0.1, Vector2(0.7, 0.7))
	var target := player_sprite.global_position + Vector2(90, player_sprite.size.y * 0.55)
	await _fly_tracer(muzzle, target)
	_spawn_fx_world(target, "impact", 0.3 if is_boss else 0.26, Vector2(1.55, 1.55) if is_boss else Vector2(1.35, 1.35))
	_spawn_fx_world(target + Vector2(8, 6), "blood", 0.35 if is_boss else 0.3)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(actor, "position", base, 0.26 if is_boss else 0.2).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(spr, "rotation_degrees", 0.0, 0.26 if is_boss else 0.2)
	tw2.tween_property(spr, "scale", Vector2.ONE, 0.26 if is_boss else 0.2)
	if shadow:
		tw2.tween_property(shadow, "scale", Vector2.ONE, 0.2)
	await tw2.finished
	if is_instance_valid(spr) and idle_tex:
		spr.texture = idle_tex


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
