extends Control
## Central de misiones: tarjetas con arte + panel táctico.

@onready var filter_row: HBoxContainer = %FilterRow
@onready var cards: VBoxContainer = %MissionCards
@onready var detail_title: Label = %DetailTitle
@onready var detail_meta: Label = %DetailMeta
@onready var detail_blurb: RichTextLabel = %DetailBlurb
@onready var detail_art: TextureRect = %DetailArt
@onready var urgency: Label = %Urgency
@onready var btn_open: Button = %BtnOpen
@onready var btn_back: Button = %BtnBack
@onready var count_label: Label = %CountLabel

var _ids: Array = []
var _filter: String = "todas"
var _selected_id: String = ""


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	btn_open.pressed.connect(_open_selected)
	btn_back.pressed.connect(_back)
	GameState.mission_added.connect(func(_m): if visible: _refresh())
	GameState.mission_removed.connect(func(_id): if visible: _refresh())
	GameState.mission_updated.connect(func(_m): if visible: _refresh())
	_style_open_btn()
	_build_filters()


func _style_open_btn() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.78, 0.42)
	sb.set_corner_radius_all(6)
	btn_open.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.3, 0.88, 0.5)
	btn_open.add_theme_stylebox_override("hover", sb_h)
	var sb_d := sb.duplicate()
	sb_d.bg_color = Color(0.18, 0.35, 0.25)
	btn_open.add_theme_stylebox_override("disabled", sb_d)


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
		b.custom_minimum_size = Vector2(0, 36)
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
	_ids.clear()
	var items := _filtered()
	count_label.text = "%d activas" % items.size()
	for m in items:
		_ids.append(m["id"])
		cards.add_child(_make_card(m))
	if _ids.is_empty():
		_clear_detail()
		return
	if _selected_id == "" or not _ids.has(_selected_id):
		_selected_id = str(_ids[0])
	_show_detail(_selected_id)
	_highlight_cards()


func _make_card(m: Dictionary) -> Control:
	var urgent: bool = str(m.get("severity", "")) in ["high", "critical"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 108)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_selected_id = str(m["id"])
			_show_detail(_selected_id)
			_highlight_cards()
		if ev is InputEventMouseButton and ev.double_click:
			_selected_id = str(m["id"])
			_open_selected()
	)
	panel.set_meta("mission_id", m["id"])

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(140, 84)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art := GameState.mission_art_path(m)
	if ResourceLoader.exists(art):
		thumb.texture = load(art)
	row.add_child(thumb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	var title := Label.new()
	title.text = str(m.get("title", "")).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	if urgent:
		title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	col.add_child(title)

	var meta := Label.new()
	var tag := "URGENTE" if urgent else str(m.get("category", "")).to_upper()
	meta.text = "%s  ·  %s  ·  %s" % [m.get("district_name", ""), tag, m.get("created_at", "")]
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", Color(0.65, 0.74, 0.86))
	col.add_child(meta)

	var blurb := Label.new()
	blurb.text = str(m.get("blurb", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.add_theme_font_size_override("font_size", 12)
	blurb.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	col.add_child(blurb)

	return panel


func _highlight_cards() -> void:
	for c in cards.get_children():
		var mid := str(c.get_meta("mission_id", ""))
		c.modulate = Color(0.55, 0.85, 1.0) if mid == _selected_id else Color.WHITE


func _show_detail(mid: String) -> void:
	GameState.select_mission(mid)
	var m := GameState.get_selected_mission()
	if m.is_empty():
		_clear_detail()
		return
	_selected_id = mid
	detail_title.text = str(m["title"]).to_upper()
	detail_meta.text = "%s · %s · %s" % [m["district_name"], str(m["category"]).to_upper(), m["created_at"]]
	detail_blurb.text = "[b]SITUACIÓN[/b]\n%s" % m["blurb"]
	urgency.visible = str(m.get("severity", "")) in ["high", "critical"]
	var path := GameState.mission_art_path(m)
	detail_art.texture = load(path) if ResourceLoader.exists(path) else null
	btn_open.disabled = false


func _clear_detail() -> void:
	detail_title.text = "Sin misiones activas"
	detail_meta.text = ""
	detail_blurb.text = "Cuando entren avisos por radio, aparecerán aquí con su informe."
	detail_art.texture = null
	urgency.visible = false
	btn_open.disabled = true
	_selected_id = ""


func _open_selected() -> void:
	if _selected_id == "":
		return
	var router := get_parent()
	if router and router.has_method("show_mission"):
		router.show_mission(_selected_id)


func _back() -> void:
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()
