extends Control
## Combate visual: sprites custom + idle, sombras, lunges y VFX de ataque.

const PACK_HERO := "res://assets/combat/custom/hero/"
const PACK_FOE := "res://assets/combat/custom/foes/"
const FX_DIR := "res://assets/combat/custom/fx/"

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
var _busy: bool = false
var _closing: bool = false
var _hero_pose: String = "idle"
var _hero_pose_until: float = 0.0
var _bob_t: float = 0.0
var _player_shadow: TextureRect
var _player_actor: Control
var _player_base_pos: Vector2 = Vector2.ZERO
var _skip_enemy_rebuild: bool = false


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
	set_process(true)


func _setup_player_actor() -> void:
	## Envuelve el sprite del héroe con sombra movible.
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
	_player_actor.custom_minimum_size = player_sprite.custom_minimum_size
	_player_actor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_player_actor)
	parent.move_child(_player_actor, idx)
	parent.remove_child(player_sprite)
	_player_actor.add_child(player_sprite)
	player_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_sprite.offset_bottom = -18
	_player_shadow = TextureRect.new()
	_player_shadow.name = "Shadow"
	_player_shadow.texture = _fx_tex("shadow")
	_player_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_player_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_shadow.modulate = Color(1, 1, 1, 0.55)
	_player_actor.add_child(_player_shadow)
	_player_actor.move_child(_player_shadow, 0)
	_layout_player_shadow()
	_player_base_pos = _player_actor.position


func _layout_player_shadow() -> void:
	if _player_shadow == null or _player_actor == null:
		return
	var w := maxf(120.0, _player_actor.size.x * 0.72)
	var h := 28.0
	_player_shadow.size = Vector2(w, h)
	_player_shadow.position = Vector2((_player_actor.size.x - w) * 0.5, _player_actor.size.y - h - 2.0)


func _process(delta: float) -> void:
	if not visible or _busy:
		return
	_bob_t += delta
	_tick_hero_pose()
	_idle_bob_player(delta)
	_idle_bob_enemies()


func _idle_bob_player(_delta: float) -> void:
	if _player_actor == null or not is_instance_valid(_player_actor):
		return
	var bob := sin(_bob_t * 2.4) * 3.5
	var sway := sin(_bob_t * 1.7) * 1.5
	_player_actor.position = _player_base_pos + Vector2(sway, bob)
	if _player_shadow:
		_layout_player_shadow()
		var squash := 1.0 + sin(_bob_t * 2.4) * 0.06
		_player_shadow.scale = Vector2(squash, 1.0 / maxf(0.85, squash))
		_player_shadow.modulate.a = 0.45 + absf(sin(_bob_t * 2.4)) * 0.12


func _idle_bob_enemies() -> void:
	var i := 0
	for wrap in enemies_row.get_children():
		if not is_instance_valid(wrap):
			continue
		var actor: Control = wrap.get_node_or_null("ActorSlot")
		if actor == null:
			continue
		var phase := _bob_t * 2.1 + float(i) * 0.9
		var bob := sin(phase) * 3.0
		var sway := cos(phase * 0.85) * 1.2
		actor.position = Vector2(sway, bob)
		var shadow: TextureRect = actor.get_node_or_null("Shadow")
		if shadow:
			var squash := 1.0 + sin(phase) * 0.05
			shadow.scale = Vector2(squash, 1.0)
			shadow.modulate.a = 0.4 + absf(sin(phase)) * 0.1
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
	result_panel.visible = false
	_prev_enemy_hp.clear()
	_prev_player_hp = -1
	visible = true
	CombatState.start_combat(cfg)
	_apply_hero_pose("idle")
	_refresh()
	await get_tree().process_frame
	if _player_actor:
		_player_base_pos = _player_actor.position
		_layout_player_shadow()


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
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.92)
	sb.border_color = Color(0.2, 0.45, 0.75, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)


func _style_end_btn() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.42, 0.88)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	end_turn_btn.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate()
	h.bg_color = Color(0.2, 0.55, 1.0)
	end_turn_btn.add_theme_stylebox_override("hover", h)


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
	_style_player_bar(p)
	player_marker.visible = int(snap.get("phase", 0)) == CombatState.Phase.PLAYER

	var php := int(p.get("hp", 0))
	if _prev_player_hp >= 0 and php < _prev_player_hp and not _busy:
		_apply_hero_pose("hurt", 0.55)
		_hit_actor(player_sprite, _prev_player_hp - php, false)
		_spawn_fx_at(player_sprite, "blood", Vector2(40, 80), 0.45)
	_prev_player_hp = php

	_tick_hero_pose()
	if player_sprite.texture == null:
		_apply_hero_pose(_hero_pose)

	_load_bg()
	if not _skip_enemy_rebuild:
		_rebuild_enemies(snap)
	_rebuild_hand(snap)
	_rebuild_energy(snap)

	var can_act: bool = int(snap.get("phase", 0)) == CombatState.Phase.PLAYER and bool(snap.get("active", false)) and not _busy
	end_turn_btn.disabled = not can_act
	end_turn_btn.text = "FINALIZAR TURNO" if can_act else "..."


func _style_player_bar(p: Dictionary) -> void:
	player_hp_bar.max_value = float(p.get("max_hp", 50))
	player_hp_bar.value = float(p.get("hp", 0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.18, 0.22)
	fill.set_corner_radius_all(5)
	player_hp_bar.add_theme_stylebox_override("fill", fill)
	var bgb := StyleBoxFlat.new()
	bgb.bg_color = Color(0.06, 0.08, 0.12)
	bgb.set_corner_radius_all(5)
	player_hp_bar.add_theme_stylebox_override("background", bgb)
	player_hp_text.text = "%d/%d" % [int(p.get("hp", 0)), int(p.get("max_hp", 50))]


func _load_bg() -> void:
	var candidates := [
		"res://assets/combat/bg/alley_night.jpg",
		"res://assets/combat/bg/alley_night2.jpg",
		"res://assets/combat/bg/combat_arena.jpg",
	]
	for path in candidates:
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
		var panel := _make_enemy_panel(e, i, i == selected)
		enemies_row.add_child(panel)
		if prev > hp_now and not _busy:
			call_deferred("_animate_enemy_hit", panel, prev - hp_now)
		_prev_enemy_hp[i] = hp_now


func _animate_enemy_hit(panel: Control, dmg: int) -> void:
	if not is_instance_valid(panel):
		return
	var spr := panel.find_child("EnemySprite", true, false)
	if spr:
		_hit_actor(spr, dmg, true)
		_spawn_fx_at(spr, "impact", Vector2(40, 70), 0.35)
		_spawn_fx_at(spr, "blood", Vector2(50, 90), 0.4)


func _make_enemy_panel(e: Dictionary, index: int, selected: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(180, 360)
	wrap.alignment = BoxContainer.ALIGNMENT_END
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.set_meta("enemy_index", index)

	var intent := Label.new()
	var intent_id := int(e.get("intent", 0))
	var intent_txt := CombatState.intent_label(intent_id)
	var val := int(e.get("intent_value", 0))
	if intent_id == CombatState.Intent.ATTACK and val > 0:
		intent.text = "DISPARAR  %d" % val
	elif intent_id == CombatState.Intent.BLOCK and val > 0:
		intent.text = "CUBRIRSE  %d" % val
	elif intent_id == CombatState.Intent.FLEE:
		intent.text = "HUIR"
	else:
		intent.text = intent_txt
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.add_theme_font_size_override("font_size", 15)
	var icol := Color(1.0, 0.32, 0.32)
	if intent_id == CombatState.Intent.BLOCK:
		icol = Color(0.4, 0.78, 1.0)
	elif intent_id == CombatState.Intent.FLEE:
		icol = Color(1.0, 0.78, 0.3)
	intent.add_theme_color_override("font_color", icol)
	if bool(e.get("detained", false)):
		intent.text = "DETENIDO"
		intent.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif bool(e.get("fled", false)):
		intent.text = "HUYÓ"
	elif int(e.get("hp", 0)) <= 0:
		intent.text = "DERRIBADO"
	wrap.add_child(intent)

	var name_l := Label.new()
	name_l.text = str(e.get("name", "Sospechoso"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 13)
	wrap.add_child(name_l)

	var actor := Control.new()
	actor.name = "ActorSlot"
	actor.custom_minimum_size = Vector2(160, 250)
	actor.clip_contents = false

	var shadow := TextureRect.new()
	shadow.name = "Shadow"
	shadow.texture = _fx_tex("shadow")
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = Color(1, 1, 1, 0.5)
	shadow.position = Vector2(20, 220)
	shadow.size = Vector2(120, 26)
	actor.add_child(shadow)

	var btn := Button.new()
	btn.name = "SelectBtn"
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.clip_contents = false
	var tex := TextureRect.new()
	tex.name = "EnemySprite"
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_bottom = -16
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := PACK_FOE + "enemy_%d.png" % (index % 7)
	if not ResourceLoader.exists(sp):
		sp = PACK_FOE + "enemy_0.png"
	if ResourceLoader.exists(sp):
		tex.texture = load(sp)
	elif ResourceLoader.exists(str(e.get("sprite", ""))):
		tex.texture = load(str(e.get("sprite", "")))
	btn.add_child(tex)
	if selected:
		var border := ColorRect.new()
		border.color = Color(0.25, 0.85, 1.0, 0.18)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(border)
	btn.pressed.connect(func(): CombatState.select_enemy(index))
	actor.add_child(btn)
	wrap.add_child(actor)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 16)
	bar.max_value = float(e.get("max_hp", 1))
	bar.value = float(maxi(0, int(e.get("hp", 0))))
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.18, 0.22)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var bgb := StyleBoxFlat.new()
	bgb.bg_color = Color(0.06, 0.08, 0.12)
	bgb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bgb)
	wrap.add_child(bar)

	var hp_t := Label.new()
	hp_t.text = "%d/%d" % [maxi(0, int(e.get("hp", 0))), int(e.get("max_hp", 0))]
	if int(e.get("block", 0)) > 0:
		hp_t.text += "  DEF %d" % int(e.get("block", 0))
	hp_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_t.add_theme_font_size_override("font_size", 12)
	wrap.add_child(hp_t)

	var mod := 1.0
	if bool(e.get("detained", false)) or bool(e.get("fled", false)) or int(e.get("hp", 0)) <= 0:
		mod = 0.4
	wrap.modulate = Color(mod, mod, mod, 1.0)
	return wrap


func _rebuild_hand(snap: Dictionary) -> void:
	for c in hand_row.get_children():
		c.queue_free()
	var hand: Array = snap.get("hand", [])
	var can_act: bool = int(snap.get("phase", 0)) == CombatState.Phase.PLAYER and bool(snap.get("active", false)) and not _busy
	for card_id in hand:
		var cid := str(card_id)
		hand_row.add_child(_make_card(cid, can_act and CombatState.can_play_card(cid)))


func _make_card(card_id: String, playable: bool) -> Control:
	var def := CardDB.get_card(card_id)
	var rarity := str(def.get("rarity", "common"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(148, 210)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.15, 0.96)
	sb.border_color = CardDB.rarity_color(rarity)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	if not playable:
		panel.modulate = Color(0.55, 0.55, 0.6, 0.85)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var cost := Label.new()
	cost.text = str(int(def.get("cost", 0)))
	cost.add_theme_font_size_override("font_size", 22)
	cost.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	v.add_child(cost)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 78)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	v.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", card_id)).to_upper()
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)

	var fx := Label.new()
	fx.text = str(def.get("effect", ""))
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD
	fx.add_theme_font_size_override("font_size", 10)
	fx.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))
	fx.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fx)

	var tag := Label.new()
	tag.text = str(def.get("type", "")).to_upper()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", CardDB.rarity_color(rarity))
	v.add_child(tag)

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
	_skip_enemy_rebuild = false
	CombatState.play_card(card_id)
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

	# Carta vuela al centro
	var ghost := panel.duplicate()
	ghost.modulate = Color(1, 1, 1, 1)
	_fx_layer.add_child(ghost)
	ghost.global_position = panel.global_position
	var target := get_viewport_rect().size * Vector2(0.5, 0.42) - Vector2(74, 105)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", target, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.3, 1.3), 0.28)
	await tw.finished

	if is_attack:
		await _hero_attack_sequence(def)
	elif is_block:
		_apply_hero_pose("aim", 0.4)
		await _hero_guard_pulse()
	else:
		_apply_hero_pose("aim", 0.3)
		await _screen_pulse(Color(0.4, 0.85, 1.0, 0.28))

	var tw2 := create_tween()
	tw2.tween_property(ghost, "modulate:a", 0.0, 0.18)
	await tw2.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	log_label.text = "Activada: %s" % str(def.get("name", card_id))


func _hero_guard_pulse() -> void:
	if _player_actor == null:
		await get_tree().create_timer(0.2).timeout
		return
	var base := _player_base_pos
	var tw := create_tween()
	tw.tween_property(_player_actor, "position", base + Vector2(-18, 0), 0.12)
	tw.tween_property(_player_actor, "modulate", Color(0.55, 0.85, 1.0), 0.08)
	_spawn_fx_at(player_sprite, "impact", Vector2(60, 100), 0.3, Color(0.5, 0.85, 1.0))
	tw.tween_property(_player_actor, "position", base, 0.18)
	tw.parallel().tween_property(_player_actor, "modulate", Color.WHITE, 0.18)
	await tw.finished


func _hero_attack_sequence(def: Dictionary) -> void:
	_apply_hero_pose("shoot", 0.7)
	if _player_actor == null:
		await get_tree().create_timer(0.25).timeout
		return
	var base := _player_base_pos
	var lunge := base + Vector2(70, -8)
	var tw := create_tween()
	tw.tween_property(_player_actor, "position", lunge, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _player_shadow:
		tw.parallel().tween_property(_player_shadow, "scale", Vector2(1.25, 0.85), 0.14)
	await tw.finished

	# Boca de cañón + proyectil hacia enemigo seleccionado
	var muzzle_pos := player_sprite.global_position + Vector2(140, 110)
	_spawn_fx_world(muzzle_pos, "muzzle", 0.22, Vector2(1.2, 1.2))
	await _screen_pulse(Color(1.0, 0.85, 0.35, 0.22))

	var enemy_node := _selected_enemy_sprite()
	var hit_pos := get_viewport_rect().size * Vector2(0.72, 0.42)
	if enemy_node and is_instance_valid(enemy_node):
		hit_pos = enemy_node.global_position + Vector2(60, 90)
	await _fly_tracer(muzzle_pos, hit_pos)

	_spawn_fx_world(hit_pos, "impact", 0.3, Vector2(1.4, 1.4))
	_spawn_fx_world(hit_pos + Vector2(10, 8), "blood", 0.4, Vector2(1.1, 1.1))
	if enemy_node and is_instance_valid(enemy_node):
		_hit_actor(enemy_node, maxi(1, int(def.get("damage", 8))), true)

	var tw2 := create_tween()
	tw2.tween_property(_player_actor, "position", base, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _player_shadow:
		tw2.parallel().tween_property(_player_shadow, "scale", Vector2.ONE, 0.2)
	await tw2.finished


func _play_enemy_attack_sequence() -> void:
	var snap := CombatState.get_snapshot()
	var enemies: Array = snap.get("enemies", [])
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if int(e.get("hp", 0)) <= 0 or bool(e.get("detained", false)) or bool(e.get("fled", false)):
			continue
		if int(e.get("intent", 0)) != CombatState.Intent.ATTACK:
			continue
		await _enemy_lunge_attack(i)
	# Pequeña pausa antes de resolver daño real
	await get_tree().create_timer(0.08).timeout


func _enemy_lunge_attack(index: int) -> void:
	var wrap := _enemy_wrap(index)
	if wrap == null:
		return
	var actor: Control = wrap.get_node_or_null("ActorSlot")
	var spr: TextureRect = wrap.find_child("EnemySprite", true, false)
	if actor == null or spr == null:
		return
	var base := actor.position
	var tw := create_tween()
	tw.tween_property(actor, "position", base + Vector2(-55, -6), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shadow: TextureRect = actor.get_node_or_null("Shadow")
	if shadow:
		tw.parallel().tween_property(shadow, "scale", Vector2(1.2, 0.85), 0.14)
	await tw.finished

	var muzzle := spr.global_position + Vector2(20, 100)
	_spawn_fx_world(muzzle, "muzzle", 0.2, Vector2(1.0, 1.0))
	var target := player_sprite.global_position + Vector2(90, 100)
	await _fly_tracer(muzzle, target)
	_spawn_fx_world(target, "impact", 0.28, Vector2(1.2, 1.2))

	var tw2 := create_tween()
	tw2.tween_property(actor, "position", base, 0.18)
	if shadow:
		tw2.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.18)
	await tw2.finished


func _enemy_wrap(index: int) -> Control:
	for c in enemies_row.get_children():
		if int(c.get_meta("enemy_index", -1)) == index:
			return c
	if index >= 0 and index < enemies_row.get_child_count():
		return enemies_row.get_child(index)
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
	tracer.size = Vector2(maxi(24, int(dist * 0.35)), 10)
	tracer.pivot_offset = Vector2(0, 5)
	tracer.global_position = from
	tracer.rotation = from.angle_to_point(to)
	var tw := create_tween()
	tw.tween_property(tracer, "global_position", to - Vector2(8, 5), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tracer, "modulate:a", 0.0, 0.12)
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
	fx.size = Vector2(72, 72) * sc
	fx.pivot_offset = fx.size * 0.5
	_fx_layer.add_child(fx)
	fx.global_position = pos - fx.size * 0.5
	var tw := create_tween()
	tw.tween_property(fx, "scale", sc * 1.45, life * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, life * 0.55)
	tw.tween_callback(fx.queue_free)


func _screen_pulse(color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 70
	_fx_layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.18)
	await tw.finished
	if is_instance_valid(flash):
		flash.queue_free()


func _hit_actor(node: CanvasItem, dmg: int, knock_right: bool) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.position
	var dir := 1.0 if knock_right else -1.0
	var tw := create_tween()
	tw.tween_property(node, "position", base + Vector2(22 * dir, -10), 0.08)
	tw.tween_property(node, "modulate", Color(1.0, 0.3, 0.3), 0.05)
	tw.tween_property(node, "position", base + Vector2(-12 * dir, 4), 0.08)
	tw.tween_property(node, "position", base, 0.12)
	tw.parallel().tween_property(node, "modulate", Color.WHITE, 0.18)
	_spawn_dmg_number(node, dmg)


func _spawn_dmg_number(node: CanvasItem, dmg: int) -> void:
	if dmg <= 0 or not is_instance_valid(node):
		return
	var lab := Label.new()
	lab.text = "-%d" % dmg
	lab.add_theme_font_size_override("font_size", 34)
	lab.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	lab.z_index = 90
	_fx_layer.add_child(lab)
	lab.global_position = node.global_position + Vector2(50, 30)
	var tw := create_tween()
	tw.tween_property(lab, "global_position:y", lab.global_position.y - 70, 0.6)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lab.queue_free)


func _rebuild_energy(snap: Dictionary) -> void:
	for c in energy_row.get_children():
		c.queue_free()
	var p: Dictionary = snap.get("player", {})
	var cur := int(p.get("energy", 0))
	var mx := int(p.get("energy_max", 3))
	for i in range(mx):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(24, 24)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.8, 1.0) if i < cur else Color(0.12, 0.18, 0.28)
		sb.set_corner_radius_all(12)
		sb.border_color = Color(0.55, 0.9, 1.0) if i < cur else Color(0.2, 0.28, 0.38)
		sb.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", sb)
		energy_row.add_child(pip)
