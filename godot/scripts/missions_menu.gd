extends Control
## Central de misiones: rejilla cinematográfica 3 columnas (mockup).

@onready var filter_row: HBoxContainer = %FilterRow
@onready var cards: GridContainer = %MissionCards
@onready var count_label: Label = %CountLabel
@onready var btn_back: Button = %BtnBack
@onready var empty_label: Label = %EmptyLabel

var _filter: String = "todas"


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	btn_back.pressed.connect(_back)
	GameState.mission_added.connect(func(_m): if visible: _refresh())
	GameState.mission_removed.connect(func(_id): if visible: _refresh())
	GameState.mission_updated.connect(func(_m): if visible: _refresh())
	_build_filters()


func _on_vis() -> void:
	if visible:
		_refresh()


func _build_filters() -> void:
	for c in filter_row.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for item in [
		["todas", "TODAS"],
		["urgentes", "URGENTES"],
		["delitos", "DELITOS"],
		["trafico", "TRÁFICO"],
		["civiles", "ASISTENCIA"],
		["organizado", "ORGANIZADO"],
		["especiales", "ESPECIALES"],
		["emergencias", "EMERGENCIAS"],
	]:
		var b := Button.new()
		b.text = item[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = item[0] == _filter
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_filter.bind(item[0]))
		filter_row.add_child(b)


func _on_filter(cat: String) -> void:
	_filter = cat
	_refresh()


func _filtered() -> Array:
	var out: Array = []
	for m in GameState.active_missions.values():
		var cat := str(m.get("category", ""))
		var sev := str(m.get("severity", ""))
		match _filter:
			"todas":
				out.append(m)
			"urgentes":
				if sev in ["high", "critical"]:
					out.append(m)
			_:
				if cat == _filter:
					out.append(m)
	return out


func _refresh() -> void:
	for c in cards.get_children():
		c.queue_free()
	var items := _filtered()
	count_label.text = "%d activas" % items.size()
	empty_label.visible = items.is_empty()
	for m in items:
		cards.add_child(_make_card(m))


func _make_card(m: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_mission(str(m["id"]))
	)

	var root := Control.new()
	root.custom_minimum_size = Vector2(360, 220)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := GameState.mission_art_path(m)
	if ResourceLoader.exists(path):
		art.texture = load(path)
	root.add_child(art)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.08, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var text_wrap := MarginContainer.new()
	text_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_wrap.add_theme_constant_override("margin_left", 14)
	text_wrap.add_theme_constant_override("margin_top", 12)
	text_wrap.add_theme_constant_override("margin_right", 12)
	text_wrap.add_theme_constant_override("margin_bottom", 12)
	text_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(text_wrap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_wrap.add_child(row)

	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 64)
	bar.color = Color(0.92, 0.15, 0.2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var tag := Label.new()
	tag.text = "MISIÓN"
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	tag.add_theme_constant_override("outline_size", 4)
	col.add_child(tag)

	var title := Label.new()
	title.text = str(m.get("title", "")).to_upper()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	var meta := Label.new()
	meta.text = _category_label(m)
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	meta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	meta.add_theme_constant_override("outline_size", 4)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(meta)

	if str(m.get("severity", "")) in ["high", "critical"]:
		var urg := Label.new()
		urg.text = "URGENTE"
		urg.add_theme_font_size_override("font_size", 12)
		urg.add_theme_color_override("font_color", Color(1.0, 0.35, 0.38))
		urg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		urg.add_theme_constant_override("outline_size", 4)
		col.add_child(urg)

	var phase := Label.new()
	phase.text = str(m.get("phase_label", "INICIO"))
	phase.add_theme_font_size_override("font_size", 11)
	phase.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	phase.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	phase.add_theme_constant_override("outline_size", 4)
	col.add_child(phase)

	return panel


func _category_label(m: Dictionary) -> String:
	match str(m.get("category", "")):
		"delitos":
			return "DELITOS CONTRA LA PROPIEDAD"
		"trafico":
			return "DELITOS CONTRA LA SEGURIDAD VIAL"
		"civiles":
			return "ASISTENCIA A CIVILES"
		"organizado":
			return "DELITOS CONTRA LA SALUD PÚBLICA"
		"especiales":
			return "REQUISITORIA JUDICIAL"
		"emergencias":
			return "EMERGENCIAS"
		_:
			return str(m.get("category", "")).to_upper()


func _open_mission(mid: String) -> void:
	var router := get_parent()
	if router and router.has_method("begin_intervention"):
		router.begin_intervention(mid)
	elif router and router.has_method("show_mission"):
		router.show_mission(mid)


func _back() -> void:
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()
