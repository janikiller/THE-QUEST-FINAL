extends Control
## Pantalla de mazo: ver y filtrar las cartas de la patrulla (roguelike).

@onready var title: Label = %Title
@onready var sub: Label = %Sub
@onready var patrol_list: VBoxContainer = %PatrolList
@onready var filter_row: HBoxContainer = %FilterRow
@onready var cards_grid: GridContainer = %CardsGrid
@onready var count_label: Label = %CountLabel
@onready var detail_name: Label = %DetailName
@onready var detail_meta: Label = %DetailMeta
@onready var detail_art: TextureRect = %DetailArt
@onready var detail_effect: RichTextLabel = %DetailEffect
@onready var detail_desc: Label = %DetailDesc
@onready var btn_close: Button = %BtnClose

var selected_patrol_id: String = "alpha"
var _filter: String = "todos"
var _selected_card_id: String = ""


func _ready() -> void:
	btn_close.pressed.connect(close)
	visibility_changed.connect(func():
		if visible:
			_rebuild_all()
	)


func open(patrol_id: String = "") -> void:
	visible = true
	if patrol_id != "" and GameState.patrols.has(patrol_id):
		selected_patrol_id = patrol_id
	elif not GameState.patrols.is_empty():
		selected_patrol_id = str(GameState.patrols.keys()[0])
	GameState.ensure_patrol_deck(selected_patrol_id)
	_rebuild_all()


func close() -> void:
	visible = false
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _rebuild_all() -> void:
	_rebuild_patrols()
	_rebuild_filters()
	_rebuild_cards()
	_refresh_header()


func _refresh_header() -> void:
	var p: Dictionary = GameState.patrols.get(selected_patrol_id, {})
	title.text = "MAZO  ·  %s" % str(p.get("callsign", "UNIDAD"))
	sub.text = "%s — cartas del enfrentamiento táctico" % str(p.get("name", "Patrulla"))
	var deck: Array = GameState.get_patrol_deck(selected_patrol_id)
	count_label.text = "%d cartas en el mazo" % deck.size()


func _rebuild_patrols() -> void:
	for c in patrol_list.get_children():
		c.queue_free()
	# Una sola unidad protagonista
	var p: Dictionary = GameState.patrols.get(selected_patrol_id, {})
	if p.is_empty() and not GameState.patrols.is_empty():
		selected_patrol_id = str(GameState.patrols.keys()[0])
		p = GameState.patrols[selected_patrol_id]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.14, 0.22)
	sb.border_color = Color(0.25, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var face := str(p.get("portrait", ""))
	if face == "" or not ResourceLoader.exists(face):
		face = "res://assets/character/police/police_00.png"
	if ResourceLoader.exists(face):
		portrait.texture = load(face)
	v.add_child(portrait)
	var name_l := Label.new()
	name_l.text = "%s\n%s\n%d cartas" % [
		p.get("name", "García"),
		p.get("callsign", "U.P.R. 091"),
		GameState.get_patrol_deck(selected_patrol_id).size(),
	]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 13)
	v.add_child(name_l)
	var tip := Label.new()
	tip.text = "Protagonista único\nClic misión = combate"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.6, 0.78, 0.95))
	v.add_child(tip)
	patrol_list.add_child(panel)


func _rebuild_filters() -> void:
	for c in filter_row.get_children():
		c.queue_free()
	for t in CardDB.types:
		var id := str(t.get("id", "todos"))
		var b := Button.new()
		b.text = str(t.get("label", id))
		b.toggle_mode = true
		b.button_pressed = id == _filter
		b.pressed.connect(func():
			_filter = id
			_rebuild_filters()
			_rebuild_cards()
		)
		filter_row.add_child(b)


func _rebuild_cards() -> void:
	for c in cards_grid.get_children():
		c.queue_free()
	var deck: Array = GameState.get_patrol_deck(selected_patrol_id)
	# Count duplicates
	var counts: Dictionary = {}
	for cid in deck:
		var id := str(cid)
		counts[id] = int(counts.get(id, 0)) + 1
	var shown := 0
	for cid in counts.keys():
		var def: Dictionary = CardDB.get_card(str(cid))
		if def.is_empty():
			continue
		var rar := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
		var typ := str(def.get("type", ""))
		if _filter in ["basica", "magica", "fuerza", "legendaria"]:
			if rar != _filter:
				continue
		elif _filter != "todos" and typ != _filter:
			continue
		var card := _make_card_widget(def, int(counts[cid]))
		cards_grid.add_child(card)
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "Sin cartas en este filtro."
		empty.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		cards_grid.add_child(empty)
	# Auto-select first
	if _selected_card_id == "" or not counts.has(_selected_card_id):
		if not counts.is_empty():
			_select_card(str(counts.keys()[0]))
		else:
			_clear_detail()
	else:
		_select_card(_selected_card_id)


func _make_card_widget(def: Dictionary, copies: int) -> Control:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(168, 236)
	var rarity := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.98)
	sb.border_color = CardDB.rarity_color(rarity)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	wrap.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	wrap.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var cost := Label.new()
	cost.text = str(int(def.get("cost", 0)))
	cost.add_theme_font_size_override("font_size", 18)
	cost.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	top.add_child(cost)
	var type_l := Label.new()
	type_l.text = "%s · %s" % [CardDB.rarity_label(rarity), str(def.get("type", "")).to_upper()]
	type_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_l.add_theme_font_size_override("font_size", 9)
	type_l.add_theme_color_override("font_color", CardDB.rarity_color(rarity))
	top.add_child(type_l)

	var art_wrap := Control.new()
	art_wrap.custom_minimum_size = Vector2(0, 96)
	v.add_child(art_wrap)
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 1, 1, 0.28)
	var fp := CardDB.frame_path(rarity)
	if ResourceLoader.exists(fp):
		frame.texture = load(fp)
	art_wrap.add_child(frame)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var img := Image.load_from_file(art_path)
		if img:
			art.texture = ImageTexture.create_from_image(img)
	art_wrap.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", "?"))
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.clip_text = true
	v.add_child(name_l)

	var effect := Label.new()
	effect.text = CardDB.effect_line(def)
	effect.add_theme_font_size_override("font_size", 11)
	effect.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	effect.clip_text = true
	v.add_child(effect)

	if copies > 1:
		var n := Label.new()
		n.text = "x%d" % copies
		n.add_theme_font_size_override("font_size", 11)
		n.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		v.add_child(n)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _select_card(str(def.get("id", ""))))
	wrap.add_child(btn)
	return wrap


func _select_card(card_id: String) -> void:
	_selected_card_id = card_id
	var def: Dictionary = CardDB.get_card(card_id)
	if def.is_empty():
		_clear_detail()
		return
	detail_name.text = str(def.get("name", ""))
	detail_meta.text = "Coste %s  ·  %s  ·  %s" % [
		str(def.get("cost", 0)),
		str(def.get("type", "")).to_upper(),
		CardDB.rarity_label(str(def.get("rarity", "basica"))),
	]
	detail_meta.add_theme_color_override("font_color", CardDB.rarity_color(str(def.get("rarity", "basica"))))
	var art_path := str(def.get("art", ""))
	if ResourceLoader.exists(art_path):
		detail_art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var dimg := Image.load_from_file(art_path)
		detail_art.texture = ImageTexture.create_from_image(dimg) if dimg else null
	else:
		detail_art.texture = null
	detail_effect.text = "[b]%s[/b]" % CardDB.effect_line(def)
	detail_desc.text = CardDB.flavor_line(def)


func _clear_detail() -> void:
	detail_name.text = "Selecciona una carta"
	detail_meta.text = ""
	detail_art.texture = null
	detail_effect.text = ""
	detail_desc.text = ""
