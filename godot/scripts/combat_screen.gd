extends Control
## Combate visual: assets vectoriales del pack (héroe / delincuentes / UI).

const PACK_HERO := "res://assets/combat/pack/combat/hero/"
const PACK_FOE := "res://assets/combat/pack/combat/foes/"
const PACK_UI := "res://assets/combat/pack/combat/ui/"

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


func _hero_tex(name: String) -> Texture2D:
	var path := PACK_HERO + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _apply_hero_pose(pose: String, hold_sec: float = 0.0) -> void:
	_hero_pose = pose
	if hold_sec > 0.0:
		_hero_pose_until = Time.get_ticks_msec() / 1000.0 + hold_sec
	var tex: Texture2D = null
	match pose:
		"shoot":
			tex = _hero_tex("shoot")
			if tex == null:
				tex = _hero_tex("combat_idle")
		"hurt":
			tex = _hero_tex("hurt_body")
			if tex == null:
				tex = _hero_tex("hurt")
		"aim":
			tex = _hero_tex("aim")
		_:
			tex = _hero_tex("combat_idle")
			if tex == null:
				tex = _hero_tex("idle_side")
			if tex == null:
				tex = _hero_tex("idle_front")
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


func open_for_mission(mission_id: String, patrol_id: String = "alpha") -> void:
	var cfg := GameState.build_combat_config(mission_id, patrol_id)
	if cfg.is_empty():
		RadioBus.push("No se pudo iniciar la intervención.", "alert")
		return
	_closing = false
	_busy = false
	_hero_pose = "idle"
	_hero_pose_until = 0.0
	result_panel.visible = false
	_prev_enemy_hp.clear()
	_prev_player_hp = -1
	visible = true
	CombatState.start_combat(cfg)
	_apply_hero_pose("idle")
	_refresh()


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
	CombatState.end_player_turn()


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
	if _prev_player_hp >= 0 and php < _prev_player_hp:
		_apply_hero_pose("hurt", 0.55)
		_hit_actor(player_sprite, _prev_player_hp - php, false)
	_prev_player_hp = php

	_tick_hero_pose()
	if player_sprite.texture == null:
		_apply_hero_pose(_hero_pose)

	_load_bg()
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
		if prev > hp_now:
			call_deferred("_animate_enemy_hit", panel, prev - hp_now)
		_prev_enemy_hp[i] = hp_now


func _animate_enemy_hit(panel: Control, dmg: int) -> void:
	if not is_instance_valid(panel):
		return
	var spr := panel.find_child("EnemySprite", true, false)
	if spr:
		_hit_actor(spr, dmg, true)


func _make_enemy_panel(e: Dictionary, index: int, selected: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(180, 360)
	wrap.alignment = BoxContainer.ALIGNMENT_END
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 250)
	btn.flat = true
	btn.clip_contents = true
	var tex := TextureRect.new()
	tex.name = "EnemySprite"
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		border.color = Color(0.25, 0.85, 1.0, 0.2)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(border)
	btn.pressed.connect(func(): CombatState.select_enemy(index))
	wrap.add_child(btn)

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
	CombatState.play_card(card_id)
	_busy = false
	_refresh()


func _play_card_fx(panel: Control, card_id: String) -> void:
	if not is_instance_valid(panel):
		await get_tree().process_frame
		return
	var def := CardDB.get_card(card_id)
	var card_type := str(def.get("type", ""))
	if card_type == "ataque" or int(def.get("damage", 0)) > 0:
		_apply_hero_pose("shoot", 0.45)
	elif card_type == "defensa" or int(def.get("block", 0)) > 0:
		_apply_hero_pose("aim", 0.35)
	var ghost := panel.duplicate()
	ghost.modulate = Color(1, 1, 1, 1)
	_fx_layer.add_child(ghost)
	ghost.global_position = panel.global_position
	var target := get_viewport_rect().size * Vector2(0.5, 0.42) - Vector2(74, 105)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.35, 1.35), 0.32)
	await tw.finished
	var flash := ColorRect.new()
	flash.color = Color(0.45, 0.9, 1.0, 0.4)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(flash)
	var tw2 := create_tween()
	tw2.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw2.parallel().tween_property(ghost, "modulate:a", 0.0, 0.25)
	await tw2.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	if is_instance_valid(flash):
		flash.queue_free()
	log_label.text = "Activada: %s" % str(def.get("name", card_id))


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
