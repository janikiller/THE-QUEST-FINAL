extends Control
## Central de operaciones: lista priorizada + briefing del asalto.

@onready var filter_row: HBoxContainer = %FilterRow
@onready var cards: VBoxContainer = %MissionCards
@onready var count_label: Label = %CountLabel
@onready var period_chip: Label = %PeriodChip
@onready var empty_label: Label = %EmptyLabel
@onready var btn_back: Button = %BtnBack
@onready var btn_open: Button = %BtnOpen
@onready var detail_title: Label = %DetailTitle
@onready var detail_meta: Label = %DetailMeta
@onready var detail_blurb: RichTextLabel = %DetailBlurb
@onready var detail_art: TextureRect = %DetailArt
@onready var urgency_badge: Label = %UrgencyBadge
@onready var stats_row: HBoxContainer = %StatsRow
@onready var reward_row: HBoxContainer = %RewardRow
@onready var suspects_row: VBoxContainer = %SuspectsRow

var _filter: String = "todas"
var _selected_id: String = ""
var _ids: Array = []


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	btn_back.pressed.connect(_back)
	btn_open.pressed.connect(_open_selected)
	GameState.mission_added.connect(func(_m): if visible: _refresh())
	GameState.mission_removed.connect(func(_id): if visible: _refresh())
	GameState.mission_updated.connect(func(_m): if visible: _refresh())
	_style_chrome()
	_build_filters()


func _style_chrome() -> void:
	_paint_btn(btn_open, Color(0.18, 0.78, 0.48), Color(0.28, 0.9, 0.58), Color(0.05, 0.12, 0.08))
	_paint_btn(btn_back, Color(0.12, 0.18, 0.26), Color(0.18, 0.28, 0.38), Color(0.85, 0.92, 1.0))
	_style_panel(get_node_or_null("Root/VBox/Body/ListPane") as PanelContainer, Color(0.07, 0.1, 0.15, 0.96))
	_style_panel(get_node_or_null("Root/VBox/Body/DetailPane") as PanelContainer, Color(0.06, 0.09, 0.14, 0.98))
	_style_badge(urgency_badge, Color(0.75, 0.16, 0.2))
	_style_badge(period_chip, Color(0.1, 0.22, 0.34))
	_style_badge(count_label, Color(0.1, 0.16, 0.24))


func _style_panel(panel: PanelContainer, bg: Color) -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.25, 0.4, 0.55, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)


func _style_badge(lab: Label, bg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	lab.add_theme_stylebox_override("normal", sb)


func _paint_btn(btn: Button, col: Color, hover: Color, font_col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate()
	h.bg_color = hover
	btn.add_theme_stylebox_override("hover", h)
	var d := sb.duplicate()
	d.bg_color = Color(0.15, 0.2, 0.25)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.65))


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
		["boss", "BOSS"],
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
		_paint_filter(b, item[0] == _filter)
		b.pressed.connect(_on_filter.bind(item[0]))
		filter_row.add_child(b)


func _paint_filter(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.42, 0.62) if on else Color(0.1, 0.14, 0.2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate()
	h.bg_color = Color(0.16, 0.5, 0.72)
	b.add_theme_stylebox_override("hover", h)
	var p := sb.duplicate()
	p.bg_color = Color(0.14, 0.48, 0.7)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_font_size_override("font_size", 12)


func _on_filter(cat: String) -> void:
	_filter = cat
	_build_filters()
	_refresh()


func _filtered() -> Array:
	var out: Array = []
	for m in GameState.active_missions.values():
		var cat := str(m.get("category", ""))
		var sev := str(m.get("severity", ""))
		var is_boss := bool(m.get("is_boss", false))
		match _filter:
			"todas":
				out.append(m)
			"urgentes":
				if sev in ["high", "critical"] or is_boss:
					out.append(m)
			"boss":
				if is_boss:
					out.append(m)
			_:
				if cat == _filter:
					out.append(m)
	out.sort_custom(_sort_priority)
	return out


func _sort_priority(a: Dictionary, b: Dictionary) -> bool:
	return _priority_score(a) > _priority_score(b)


func _priority_score(m: Dictionary) -> int:
	var score := 0
	if bool(m.get("is_boss", false)):
		score += 1000
	match str(m.get("severity", "medium")):
		"critical":
			score += 400
		"high":
			score += 300
		"medium":
			score += 200
		"low":
			score += 100
	match str(m.get("period", "")):
		"night":
			score += 40
		"dusk":
			score += 20
	score += int(m.get("xp", 0)) / 10
	return score


func _refresh() -> void:
	for c in cards.get_children():
		c.queue_free()
	_ids.clear()
	var items := _filtered()
	count_label.text = "%d activas" % items.size()
	period_chip.text = _period_chip_text()
	empty_label.visible = items.is_empty()
	for m in items:
		_ids.append(str(m.get("id", "")))
		cards.add_child(_make_row(m))
	if _ids.is_empty():
		_clear_detail()
		return
	if _selected_id == "" or not _ids.has(_selected_id):
		_selected_id = str(_ids[0])
	_show_detail(_selected_id)
	_highlight_rows()


func _period_chip_text() -> String:
	var tod := GameState.time_of_day()
	var label := "DÍA"
	match tod:
		"dusk":
			label = "ATARDECER"
		"night":
			label = "NOCHE %d" % GameState.nights_count
	if GameState.has_method("boss_night_label"):
		return "%s  ·  %s" % [label, GameState.boss_night_label()]
	return label


func _make_row(m: Dictionary) -> Control:
	var mid := str(m.get("id", ""))
	var is_boss := bool(m.get("is_boss", false))
	var sev := str(m.get("severity", "medium"))
	var urgent := sev in ["high", "critical"] or is_boss

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("mission_id", mid)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_selected_id = mid
			_show_detail(mid)
			_highlight_rows()
		if ev is InputEventMouseButton and ev.double_click:
			_selected_id = mid
			_open_selected()
	)

	var accent := _severity_color(sev, is_boss)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.11, 0.16, 0.98)
	sb.border_color = accent
	sb.border_width_left = 4
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(120, 72)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := GameState.mission_art_path(m)
	if ResourceLoader.exists(art):
		thumb.texture = load(art)
	row.add_child(thumb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)

	var title := Label.new()
	title.text = str(m.get("title", "")).to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5) if urgent else Color(0.95, 0.97, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(title)

	var tag := Label.new()
	if is_boss:
		tag.text = "BOSS"
	elif urgent:
		tag.text = "URGENTE"
	else:
		tag.text = _severity_short(sev)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", accent.lightened(0.25))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tag)

	var loc := str(m.get("location_name", m.get("district_name", "Distrito")))
	var meta := Label.new()
	meta.text = "%s  ·  %s  ·  %s  ·  %s" % [
		str(m.get("district_name", "Distrito")),
		loc,
		_category_short(m),
		_period_short(str(m.get("period", ""))),
	]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.62, 0.74, 0.88))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(meta)

	var stats := Label.new()
	var foes := _foe_count(m)
	var coins := GameState.mission_coin_reward(m) if GameState.has_method("mission_coin_reward") else 0
	var mins := _duration_mins(m)
	stats.text = "Riesgo %s  ·  %d sospechosos  ·  ~%d min  ·  +%d XP  ·  +%d monedas" % [
		_risk_dots(m), foes, mins, int(m.get("xp", 50)), coins
	]
	stats.add_theme_font_size_override("font_size", 11)
	stats.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats)

	return panel


func _highlight_rows() -> void:
	for c in cards.get_children():
		var mid := str(c.get_meta("mission_id", ""))
		var selected := mid == _selected_id
		c.modulate = Color(1.05, 1.08, 1.12) if selected else Color(0.92, 0.94, 0.96)
		if c is PanelContainer:
			var sb := (c as PanelContainer).get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
				flat.bg_color = Color(0.1, 0.16, 0.24, 1.0) if selected else Color(0.08, 0.11, 0.16, 0.98)
				(c as PanelContainer).add_theme_stylebox_override("panel", flat)


func _show_detail(mid: String) -> void:
	if GameState.has_method("select_mission"):
		GameState.select_mission(mid)
	var m: Dictionary = {}
	if GameState.active_missions.has(mid):
		m = GameState.active_missions[mid]
	elif GameState.has_method("get_selected_mission"):
		m = GameState.get_selected_mission()
	if m.is_empty():
		_clear_detail()
		return
	_selected_id = mid
	var is_boss := bool(m.get("is_boss", false))
	var sev := str(m.get("severity", "medium"))
	var loc := str(m.get("location_name", "Escenario urbano"))
	detail_title.text = str(m.get("title", "")).to_upper()
	detail_meta.text = "%s  ·  %s  ·  %s  ·  fase %s  ·  aviso %s" % [
		str(m.get("district_name", "")),
		loc,
		_category_label(m),
		str(m.get("phase_label", "INICIO")),
		str(m.get("created_at", "--:--")),
	]
	urgency_badge.visible = true
	if is_boss:
		urgency_badge.text = "BOSS"
		_style_badge(urgency_badge, Color(0.72, 0.2, 0.55))
	elif sev in ["high", "critical"]:
		urgency_badge.text = "URGENTE"
		_style_badge(urgency_badge, Color(0.78, 0.16, 0.22))
	else:
		urgency_badge.text = _severity_short(sev)
		_style_badge(urgency_badge, _severity_color(sev, false).darkened(0.15))

	var path := GameState.mission_art_path(m)
	detail_art.texture = load(path) if ResourceLoader.exists(path) else null

	var foes := _foe_count(m)
	var coins := GameState.mission_coin_reward(m) if GameState.has_method("mission_coin_reward") else 0
	var dist := _distance_text(m)
	var mins := _duration_mins(m)
	var threat := _threat_level(m)
	var intel := _intel_line(m)
	detail_blurb.text = "[b]BRIEFING DEL ASALTO[/b]\n%s\n\n[color=#9ad0ff]%s[/color]\n[color=#c9b27a]%s[/color]" % [
		str(m.get("blurb", "Sin descripción.")),
		"Central pide unidad visible y evaluación táctica inmediata.",
		intel,
	]

	_rebuild_stat_chips([
		["RIESGO", _risk_dots(m)],
		["AMENAZA", threat],
		["SOSPECHOSOS", str(foes)],
		["DISTANCIA", dist],
		["DURACIÓN", "~%d min" % mins],
		["PERIODO", _period_short(str(m.get("period", "")))],
	])
	_rebuild_reward_chips([
		["XP", "+%d" % int(m.get("xp", 50))],
		["MONEDAS", "+%d" % coins],
		["TIPO", _crime_type(m)],
		["ESCENARIO", loc],
		["FASE", str(m.get("phase_label", "INICIO"))],
		["ESTADO", _status_label(str(m.get("status", "open")))],
	])
	_rebuild_suspects(m)
	btn_open.disabled = false
	btn_open.text = "▶  ENFRENTAR AL CAPO" if is_boss else "▶  ABRIR BRIEFING DEL ASALTO"


func _rebuild_stat_chips(items: Array) -> void:
	for c in stats_row.get_children():
		c.queue_free()
	for it in items:
		stats_row.add_child(_chip(str(it[0]), str(it[1]), Color(0.12, 0.18, 0.26)))


func _rebuild_reward_chips(items: Array) -> void:
	for c in reward_row.get_children():
		c.queue_free()
	for it in items:
		reward_row.add_child(_chip(str(it[0]), str(it[1]), Color(0.16, 0.22, 0.14)))


func _chip(title: String, value: String, bg: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.35, 0.5, 0.65, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	panel.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 10)
	t.add_theme_color_override("font_color", Color(0.65, 0.78, 0.92))
	col.add_child(t)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	col.add_child(v)
	return panel


func _rebuild_suspects(m: Dictionary) -> void:
	for c in suspects_row.get_children():
		c.queue_free()
	var suspects: Array = m.get("suspects", [])
	if suspects.is_empty():
		var empty := Label.new()
		empty.text = "Sin fichas aún"
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
		suspects_row.add_child(empty)
		return
	for i in range(mini(4, suspects.size())):
		var s: Dictionary = suspects[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(48, 48)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var spath := str(s.get("thumb", s.get("full", s.get("portrait", ""))))
		if ResourceLoader.exists(spath):
			face.texture = load(spath)
		row.add_child(face)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		var name_l := Label.new()
		name_l.text = str(s.get("name", "Sospechoso"))
		name_l.add_theme_font_size_override("font_size", 12)
		col.add_child(name_l)
		var alias_l := Label.new()
		var role := str(s.get("role", "")).capitalize()
		var alias := str(s.get("alias", "Sin alias"))
		alias_l.text = ("%s · %s" % [alias, role]) if role != "" else alias
		alias_l.add_theme_font_size_override("font_size", 10)
		alias_l.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
		col.add_child(alias_l)
		var hp_l := Label.new()
		var hp := int(s.get("hp_bonus", 0))
		hp_l.text = ("PV est. %d" % hp) if hp > 0 else "Ficha abierta"
		hp_l.add_theme_font_size_override("font_size", 10)
		hp_l.add_theme_color_override("font_color", Color(0.9, 0.72, 0.55))
		col.add_child(hp_l)
		row.add_child(col)
		suspects_row.add_child(row)


func _clear_detail() -> void:
	detail_title.text = "Sin avisos activos"
	detail_meta.text = ""
	detail_blurb.text = "Cuando entre una llamada por radio, el briefing del asalto aparecerá aquí."
	detail_art.texture = null
	urgency_badge.visible = false
	btn_open.disabled = true
	_selected_id = ""
	for c in stats_row.get_children():
		c.queue_free()
	for c in reward_row.get_children():
		c.queue_free()
	for c in suspects_row.get_children():
		c.queue_free()


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


func _foe_count(m: Dictionary) -> int:
	var suspects: Array = m.get("suspects", [])
	if not suspects.is_empty():
		return suspects.size()
	var period := str(m.get("period", ""))
	if bool(m.get("is_boss", false)) or period == "night" or str(m.get("severity", "")) in ["high", "critical"]:
		return 3
	if period == "day" and str(m.get("severity", "")) == "low":
		return 1
	return 2


func _risk_dots(m: Dictionary) -> String:
	var rank := 2
	match str(m.get("severity", "medium")):
		"low":
			rank = 1
		"high":
			rank = 4
		"critical":
			rank = 5
	if bool(m.get("is_boss", false)):
		rank = 5
	elif str(m.get("period", "")) == "night":
		rank = mini(5, rank + 1)
	return "●".repeat(rank) + "○".repeat(maxi(0, 5 - rank))


func _severity_color(sev: String, is_boss: bool) -> Color:
	if is_boss:
		return Color(0.85, 0.35, 0.7)
	match sev:
		"critical":
			return Color(0.95, 0.25, 0.28)
		"high":
			return Color(1.0, 0.55, 0.25)
		"low":
			return Color(0.35, 0.75, 0.55)
		_:
			return Color(0.35, 0.65, 0.95)


func _severity_short(sev: String) -> String:
	match sev:
		"critical":
			return "CRÍTICA"
		"high":
			return "ALTA"
		"low":
			return "BAJA"
		_:
			return "MEDIA"


func _period_short(period: String) -> String:
	match period:
		"night":
			return "NOCHE"
		"dusk":
			return "ATARDECER"
		_:
			return "DÍA"


func _period_label(period: String) -> String:
	match period:
		"night":
			return "operación nocturna"
		"dusk":
			return "atardecer"
		_:
			return "turno de día"


func _category_short(m: Dictionary) -> String:
	match str(m.get("category", "")):
		"delitos":
			return "DELITOS"
		"trafico":
			return "TRÁFICO"
		"civiles":
			return "ASISTENCIA"
		"organizado":
			return "ORGANIZADO"
		"especiales":
			return "ESPECIALES"
		"emergencias":
			return "EMERGENCIAS"
		_:
			return str(m.get("category", "")).to_upper()


func _category_label(m: Dictionary) -> String:
	match str(m.get("category", "")):
		"delitos":
			return "Delitos contra la propiedad"
		"trafico":
			return "Seguridad vial"
		"civiles":
			return "Asistencia a civiles"
		"organizado":
			return "Crimen organizado"
		"especiales":
			return "Operaciones especiales"
		"emergencias":
			return "Emergencias"
		_:
			return str(m.get("category", "")).capitalize()


func _crime_type(m: Dictionary) -> String:
	var title := str(m.get("title", "")).to_lower()
	if bool(m.get("is_boss", false)):
		return "Boss"
	if "atraco" in title or "robo" in title:
		return "Atraco"
	if "secuestr" in title:
		return "Secuestro"
	if "pelea" in title or "riña" in title:
		return "Altercado"
	if "accidente" in title:
		return "Accidente"
	if "contraband" in title or "narco" in title:
		return "Tráfico"
	return _category_short(m)


func _distance_text(m: Dictionary) -> String:
	var pos: Vector2 = m.get("pos", m.get("world_pos", Vector2(640, 360)))
	if typeof(pos) != TYPE_VECTOR2:
		pos = Vector2(640, 360)
	var km := clampf(pos.distance_to(Vector2(640, 360)) / 180.0, 0.8, 8.0)
	var mins := int(round(km * 2.0))
	return "%.1f km (~%d min)" % [km, mins]


func _duration_mins(m: Dictionary) -> int:
	var sec := float(m.get("duration_sec", 90.0))
	return maxi(1, int(round(sec / 60.0)))


func _threat_level(m: Dictionary) -> String:
	var score := 0
	match str(m.get("severity", "medium")):
		"critical":
			score += 4
		"high":
			score += 3
		"medium":
			score += 2
		_:
			score += 1
	if bool(m.get("is_boss", false)):
		score += 3
	if str(m.get("period", "")) == "night":
		score += 1
	score += mini(2, _foe_count(m) - 1)
	if score >= 7:
		return "EXTREMA"
	if score >= 5:
		return "ALTA"
	if score >= 3:
		return "MEDIA"
	return "BAJA"


func _status_label(status: String) -> String:
	match status:
		"open":
			return "ABIERTA"
		"dispatched":
			return "EN RUTA"
		"resolving":
			return "EN CURSO"
		"resolved":
			return "RESUELTA"
		"failed":
			return "FALLIDA"
		_:
			return status.to_upper()


func _intel_line(m: Dictionary) -> String:
	var loc := str(m.get("location_name", "zona urbana"))
	var foes := _foe_count(m)
	var roles: Array = []
	for s in m.get("suspects", []):
		var role := str(s.get("role", "")).strip_edges()
		if role != "" and not roles.has(role):
			roles.append(role)
	var role_txt := "sin roles confirmados"
	if not roles.is_empty():
		role_txt = ", ".join(PackedStringArray(roles))
	if bool(m.get("is_boss", false)):
		return "INTEL · Escenario %s · amenaza de capo · %d hostiles (%s)." % [loc, foes, role_txt]
	return "INTEL · Escenario %s · %d hostiles (%s) · ventana ~%d min." % [
		loc, foes, role_txt, _duration_mins(m)
	]
