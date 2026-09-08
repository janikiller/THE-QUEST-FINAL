extends Control
## Pantalla de combate por cartas (roguelike táctico).

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

var _enemy_nodes: Array = []
var _energy_pips: Array = []
var _closing: bool = false


func _ready() -> void:
	visible = false
	end_turn_btn.pressed.connect(_on_end_turn)
	result_btn.pressed.connect(_on_result_close)
	result_panel.visible = false
	CombatState.combat_updated.connect(_refresh)
	CombatState.combat_ended.connect(_on_combat_ended)
	CombatState.log_message.connect(_on_log)
	_style_end_btn()


func open_for_mission(mission_id: String, patrol_id: String = "alpha") -> void:
	var cfg := GameState.build_combat_config(mission_id, patrol_id)
	if cfg.is_empty():
		RadioBus.push("No se pudo iniciar la intervención.", "alert")
		return
	_closing = false
	result_panel.visible = false
	visible = true
	CombatState.start_combat(cfg)
	_refresh()


func open_with_config(cfg: Dictionary) -> void:
	_closing = false
	result_panel.visible = false
	visible = true
	CombatState.start_combat(cfg)
	_refresh()


func close() -> void:
	visible = false
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _style_end_btn() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.45, 0.85)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	end_turn_btn.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate()
	h.bg_color = Color(0.2, 0.55, 0.95)
	end_turn_btn.add_theme_stylebox_override("hover", h)


func _on_log(text: String) -> void:
	log_label.text = text


func _on_end_turn() -> void:
	if CombatState.phase == CombatState.Phase.PLAYER:
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
	player_hp_bar.max_value = float(p.get("max_hp", 50))
	player_hp_bar.value = float(p.get("hp", 0))
	player_hp_text.text = "%d/%d" % [int(p.get("hp", 0)), int(p.get("max_hp", 50))]
	player_marker.visible = snap.get("phase", 0) == CombatState.Phase.PLAYER

	var sprite_path := str(p.get("sprite", "res://assets/character/police/police_00.png"))
	if ResourceLoader.exists(sprite_path):
		player_sprite.texture = load(sprite_path)

	_load_bg()
	_rebuild_enemies(snap)
	_rebuild_hand(snap)
	_rebuild_energy(snap)

	var can_act := snap.get("phase", 0) == CombatState.Phase.PLAYER and bool(snap.get("active", false))
	end_turn_btn.disabled = not can_act
	end_turn_btn.text = "FINALIZAR TURNO" if can_act else "..."


func _load_bg() -> void:
	var path := "res://assets/combat/bg/combat_arena.jpg"
	if not ResourceLoader.exists(path):
		path = "res://assets/combat/bg/alley_night.jpg"
	if ResourceLoader.exists(path):
		bg.texture = load(path)


func _rebuild_enemies(snap: Dictionary) -> void:
	for c in enemies_row.get_children():
		c.queue_free()
	_enemy_nodes.clear()
	var enemies: Array = snap.get("enemies", [])
	var selected := int(snap.get("selected_enemy", 0))
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		var panel := _make_enemy_panel(e, i, i == selected)
		enemies_row.add_child(panel)
		_enemy_nodes.append(panel)


func _make_enemy_panel(e: Dictionary, index: int, selected: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(160, 280)
	wrap.alignment = BoxContainer.ALIGNMENT_END
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var intent := Label.new()
	var intent_id := int(e.get("intent", 0))
	var intent_txt := CombatState.intent_label(intent_id)
	var val := int(e.get("intent_value", 0))
	if intent_id == CombatState.Intent.ATTACK and val > 0:
		intent.text = "%s %d" % [intent_txt, val]
	elif intent_id == CombatState.Intent.BLOCK and val > 0:
		intent.text = "%s %d" % [intent_txt, val]
	else:
		intent.text = intent_txt
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.add_theme_font_size_override("font_size", 13)
	var icol := Color(1.0, 0.35, 0.35)
	if intent_id == CombatState.Intent.BLOCK:
		icol = Color(0.4, 0.75, 1.0)
	elif intent_id == CombatState.Intent.FLEE:
		icol = Color(1.0, 0.75, 0.3)
	intent.add_theme_color_override("font_color", icol)
	if bool(e.get("detained", false)):
		intent.text = "DETENIDO"
		intent.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif bool(e.get("fled", false)):
		intent.text = "HUYÓ"
	elif int(e.get("hp", 0)) <= 0:
		intent.text = "DERRIBADO"
		intent.add_theme_color_override("font_color", Color(0.85, 0.85, 0.5))
	wrap.add_child(intent)

	var name_l := Label.new()
	name_l.text = str(e.get("name", "Sospechoso"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	wrap.add_child(name_l)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 180)
	btn.flat = true
	btn.clip_contents = true
	var tex := TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := str(e.get("sprite", ""))
	if ResourceLoader.exists(sp):
		tex.texture = load(sp)
	btn.add_child(tex)
	if selected:
		var border := ColorRect.new()
		border.color = Color(0.2, 0.85, 1.0, 0.25)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(border)
	btn.pressed.connect(func(): CombatState.select_enemy(index))
	wrap.add_child(btn)

	var hp_row := HBoxContainer.new()
	hp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.max_value = float(e.get("max_hp", 1))
	bar.value = float(maxi(0, int(e.get("hp", 0))))
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.25)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var bgb := StyleBoxFlat.new()
	bgb.bg_color = Color(0.1, 0.12, 0.16)
	bgb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bgb)
	hp_row.add_child(bar)
	wrap.add_child(hp_row)

	var hp_t := Label.new()
	hp_t.text = "%d/%d" % [maxi(0, int(e.get("hp", 0))), int(e.get("max_hp", 0))]
	if int(e.get("block", 0)) > 0:
		hp_t.text += "  DEF %d" % int(e.get("block", 0))
	hp_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_t.add_theme_font_size_override("font_size", 11)
	wrap.add_child(hp_t)

	var mod := 1.0
	if bool(e.get("detained", false)) or bool(e.get("fled", false)) or int(e.get("hp", 0)) <= 0:
		mod = 0.45
	wrap.modulate = Color(mod, mod, mod, 1.0)
	return wrap


func _rebuild_hand(snap: Dictionary) -> void:
	for c in hand_row.get_children():
		c.queue_free()
	var hand: Array = snap.get("hand", [])
	var can_act := snap.get("phase", 0) == CombatState.Phase.PLAYER and bool(snap.get("active", false))
	for card_id in hand:
		var cid := str(card_id)
		hand_row.add_child(_make_card(cid, can_act and CombatState.can_play_card(cid)))


func _make_card(card_id: String, playable: bool) -> Control:
	var def := CardDB.get_card(card_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(128, 188)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	var rarity := str(def.get("rarity", "common"))
	sb.border_color = CardDB.rarity_color(rarity)
	sb.set_border_width_all(2 if rarity != "common" else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	if not playable:
		panel.modulate = Color(0.55, 0.55, 0.6, 0.85)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var top := HBoxContainer.new()
	var cost := Label.new()
	cost.text = str(int(def.get("cost", 0)))
	cost.add_theme_font_size_override("font_size", 18)
	cost.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	top.add_child(cost)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	v.add_child(top)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 64)
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
	fx.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
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
	btn.pressed.connect(func():
		if CombatState.can_play_card(card_id):
			CombatState.play_card(card_id)
	)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(btn)
	return panel


func _rebuild_energy(snap: Dictionary) -> void:
	for c in energy_row.get_children():
		c.queue_free()
	var p: Dictionary = snap.get("player", {})
	var cur := int(p.get("energy", 0))
	var mx := int(p.get("energy_max", 3))
	for i in range(mx):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 18)
		pip.color = Color(0.25, 0.75, 1.0) if i < cur else Color(0.15, 0.22, 0.32)
		energy_row.add_child(pip)
