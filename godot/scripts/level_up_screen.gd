extends Control
## Sobre de nivel: elige 1 de 3 cartas aleatorias.

@onready var title: Label = %Title
@onready var sub: Label = %Sub
@onready var level_label: Label = %LevelLabel
@onready var cards_row: HBoxContainer = %CardsRow
@onready var hint: Label = %Hint
@onready var btn_skip: Button = %BtnSkip

var _patrol_id: String = "alpha"
var _choices: Array[String] = []
var _picked: bool = false


func _ready() -> void:
	visible = false
	btn_skip.pressed.connect(_on_skip)
	_style_skip()


func open(patrol_id: String = "alpha") -> void:
	_patrol_id = patrol_id if patrol_id != "" else "alpha"
	_picked = false
	_choices = GameState.begin_level_pack()
	if _choices.is_empty():
		_finish()
		return
	visible = true
	title.text = "SOBRE DE NIVEL"
	level_label.text = "NIVEL %d" % GameState.hero_level
	sub.text = "Elige 1 de 3 cartas para el mazo de Kick-Ass"
	if GameState.pending_level_packs > 1:
		sub.text += "  ·  %d sobres pendientes" % GameState.pending_level_packs
	hint.text = "Las cartas del sobre son aleatorias según tu nivel."
	_rebuild_cards()


func _style_skip() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	sb.border_color = Color(0.45, 0.5, 0.58)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	btn_skip.add_theme_stylebox_override("normal", sb)


func _rebuild_cards() -> void:
	for c in cards_row.get_children():
		c.queue_free()
	for cid in _choices:
		cards_row.add_child(_make_choice_card(cid))


func _make_choice_card(card_id: String) -> Control:
	var def := CardDB.get_card(card_id)
	var rar := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 340)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	sb.border_color = CardDB.rarity_color(rar)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var rar_l := Label.new()
	rar_l.text = CardDB.rarity_label(rar)
	rar_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar_l.add_theme_font_size_override("font_size", 13)
	rar_l.add_theme_color_override("font_color", CardDB.rarity_color(rar))
	v.add_child(rar_l)

	var art_wrap := Control.new()
	art_wrap.custom_minimum_size = Vector2(0, 140)
	v.add_child(art_wrap)
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 1, 1, 0.35)
	var fp := CardDB.frame_path(rar)
	if ResourceLoader.exists(fp):
		frame.texture = load(fp)
	art_wrap.add_child(frame)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ap := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(ap):
		art.texture = load(ap)
	art_wrap.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", card_id))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 18)
	v.add_child(name_l)

	var cost_l := Label.new()
	cost_l.text = "Coste %d" % int(def.get("cost", 0))
	cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_l.add_theme_font_size_override("font_size", 12)
	cost_l.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	v.add_child(cost_l)

	var fx := Label.new()
	fx.text = CardDB.effect_line(def)
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.add_theme_font_size_override("font_size", 14)
	fx.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	v.add_child(fx)

	var flavor := Label.new()
	flavor.text = CardDB.flavor_line(def)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.add_theme_font_size_override("font_size", 11)
	flavor.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	v.add_child(flavor)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var btn := Button.new()
	btn.text = "ELEGIR"
	btn.custom_minimum_size = Vector2(0, 44)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(CardDB.rarity_color(rar).r * 0.35, CardDB.rarity_color(rar).g * 0.28, CardDB.rarity_color(rar).b * 0.2, 0.96)
	bsb.border_color = CardDB.rarity_color(rar)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", bsb)
	btn.add_theme_stylebox_override("hover", bsb)
	btn.add_theme_stylebox_override("pressed", bsb)
	var pick_id := card_id
	btn.pressed.connect(func(): _pick(pick_id))
	v.add_child(btn)
	return panel


func _pick(card_id: String) -> void:
	if _picked:
		return
	_picked = true
	if GameState.claim_level_pack_card(card_id, _patrol_id):
		_finish()
	else:
		_picked = false


func _on_skip() -> void:
	## Saltar = tomar la primera (no perder el sobre).
	if _choices.is_empty():
		_finish()
		return
	_pick(_choices[0])


func _finish() -> void:
	visible = false
	var router := get_parent()
	if router == null:
		return
	if GameState.has_pending_level_packs() and router.has_method("show_level_up"):
		router.show_level_up(_patrol_id)
	elif router.has_method("show_map"):
		router.show_map()
