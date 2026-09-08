extends Control
## Pantalla de misión — central táctica (mockup operativo).

@onready var title: Label = %MissionTitle
@onready var meta: Label = %MissionMeta
@onready var urgency: Label = %UrgencyBadge
@onready var timer_label: Label = %TimerLabel
@onready var clock_label: Label = %ClockLabel
@onready var art: TextureRect = %MissionArt
@onready var mini_map: TextureRect = %MiniMap
@onready var blurb: RichTextLabel = %MissionBlurb
@onready var location_label: Label = %LocationLabel
@onready var risk_label: Label = %RiskLabel
@onready var crime_type: Label = %CrimeTypeLabel
@onready var units_label: Label = %UnitsLabel
@onready var distance_label: Label = %DistanceLabel
@onready var witnesses: Label = %WitnessesLabel
@onready var suspects_row: HBoxContainer = %SuspectsRow
@onready var step_active: Label = %StepActiveTitle
@onready var step_address: Label = %StepAddress
@onready var patrol_list: ItemList = %PatrolList
@onready var back_btn: Button = %BackButton
@onready var confirm_btn: Button = %ConfirmActions
@onready var action_cautious: Button = %ActionCautious
@onready var action_entry: Button = %ActionEntry
@onready var action_negotiate: Button = %ActionNegotiate
@onready var action_block: Button = %ActionBlock
@onready var support_check: CheckBox = %SupportCheck
@onready var step_label: Label = %StepLabel

var _patrol_ids: Array = []
var _action: String = "cautious"
var _elapsed: float = 0.0


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	back_btn.pressed.connect(_back)
	confirm_btn.pressed.connect(_confirm)
	action_cautious.pressed.connect(func(): _set_action("cautious"))
	action_entry.pressed.connect(func(): _set_action("entry"))
	action_negotiate.pressed.connect(func(): _set_action("negotiate"))
	action_block.pressed.connect(func(): _set_action("block"))
	_style_confirm()
	_set_action("cautious")
	_load_minimap()


func _style_confirm() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.78, 0.42)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	confirm_btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.3, 0.88, 0.5)
	confirm_btn.add_theme_stylebox_override("hover", sb_h)
	var sb_d := sb.duplicate()
	sb_d.bg_color = Color(0.18, 0.35, 0.25)
	confirm_btn.add_theme_stylebox_override("disabled", sb_d)


func _load_minimap() -> void:
	var tod := GameState.time_of_day()
	var path := "res://assets/map/tod/day.jpg"
	if tod == "night":
		path = "res://assets/map/tod/night.jpg"
	elif tod == "dusk":
		path = "res://assets/map/tod/dusk.jpg"
	if ResourceLoader.exists(path):
		mini_map.texture = load(path)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	var m := int(_elapsed)
	timer_label.text = "%02d:%02d" % [m / 60, m % 60]
	clock_label.text = "%s  |  %02d:%02d" % [_weekday(), GameState.hour, GameState.minute]


func _weekday() -> String:
	# Día sintético a partir de la hora de juego (ciclo continuo).
	var names := ["LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB", "DOM"]
	var idx := int((GameState.hour + GameState.minute / 60.0) / 3.4) % 7
	return names[idx]


func _on_vis() -> void:
	if visible:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		return
	var t := str(m["title"]).to_upper()
	title.text = t
	meta.text = _category_label(m)
	location_label.text = "%s — %s" % [m.get("district_name", ""), _fake_address(m)]
	step_active.text = "!  %s  ·  %s" % [t, str(m.get("phase_label", "INICIO"))]
	step_address.text = location_label.text
	blurb.text = "[b]DESCRIPCIÓN DE LA SITUACIÓN[/b]  ·  [color=#7eb6ff]%s[/color]\n\n%s\n\nCentral solicita unidad visible y evaluación táctica inmediata." % [
		str(m.get("phase_label", "INICIO")),
		m["blurb"],
	]
	urgency.visible = str(m.get("severity", "")) in ["high", "critical"]
	urgency.text = "  URGENTE  "
	var rank := _risk(m)
	risk_label.text = "RIESGO  " + "●".repeat(rank) + "○".repeat(maxi(0, 5 - rank))
	crime_type.text = "TIPO DE DELITO: %s" % _crime_type(m)
	units_label.text = "UNIDADES EN CAMINO: %s" % _units_text(m)
	distance_label.text = "DISTANCIA: %s" % _distance_text(m)
	witnesses.text = "%d testigos en la zona (esperando a la policía)" % (2 + rank % 3)
	step_label.text = _phase_steps(m)
	var path := GameState.mission_art_path(m)
	art.texture = load(path) if ResourceLoader.exists(path) else null
	_load_minimap()
	_rebuild_suspects(m)
	_refresh_patrols()
	confirm_btn.disabled = m.get("status", "") != "open" or GameState.available_patrols().is_empty()


func _phase_steps(m: Dictionary) -> String:
	var phase := str(m.get("phase", "inicio"))
	var a := "●" if phase == "inicio" else "○"
	var b := "●" if phase == "desarrollo" else "○"
	var c := "●" if phase == "final" else "○"
	# Subpasos del informe táctico
	var s1 := "●" if phase in ["inicio", "desarrollo", "final"] else "○"
	var s2 := "●" if phase in ["desarrollo", "final"] else "○"
	var s3 := "●" if phase == "final" else "○"
	var s4 := "●" if phase == "final" else "○"
	return "%s  Informe Inicial  [%s INICIO]\n%s  Inteligencia\n%s  Posibles Escenarios  [%s DESARROLLO]\n%s  Tomar Decisión / Cierre  [%s FINAL]" % [
		s1, a, s2, s3, b, s4, c
	]


func _category_label(m: Dictionary) -> String:
	match str(m.get("category", "")):
		"delitos":
			return "DELITOS CONTRA LA PROPIEDAD"
		"trafico":
			return "SEGURIDAD VIAL"
		"civiles":
			return "ASISTENCIA A CIVILES"
		"organizado":
			return "CRIMEN ORGANIZADO"
		"especiales":
			return "OPERACIONES ESPECIALES"
		"emergencias":
			return "EMERGENCIAS"
		_:
			return str(m.get("category", "")).to_upper()


func _crime_type(m: Dictionary) -> String:
	var title := str(m.get("title", "")).to_lower()
	if "atraco" in title or "robo" in title:
		return "Robo a mano armada"
	if "secuestr" in title:
		return "Secuestro / retención"
	if "pelea" in title or "riña" in title:
		return "Altercado público"
	if "accidente" in title:
		return "Accidente de tráfico"
	if "contraband" in title:
		return "Tráfico ilícito"
	return str(m.get("category", "Incidente")).capitalize()


func _units_text(m: Dictionary) -> String:
	var assigned := str(m.get("assigned_patrol", ""))
	if assigned != "" and GameState.patrols.has(assigned):
		var p: Dictionary = GameState.patrols[assigned]
		return "%s — %s" % [p.get("name", ""), p.get("callsign", "")]
	return "Sin despachar · elegir abajo"


func _distance_text(m: Dictionary) -> String:
	var pos: Vector2 = m.get("world_pos", Vector2(640, 360))
	var km := clampf(pos.distance_to(Vector2(640, 360)) / 180.0, 0.8, 8.0)
	var mins := int(round(km * 2.0))
	return "%.1f km (~%d min)" % [km, mins]


func _fake_address(m: Dictionary) -> String:
	var district := str(m.get("district_name", "Centro"))
	var n: int = 80 + (absi(hash(str(m.get("id", "")))) % 140)
	return "Av. %s %d" % [district, n]


func _rebuild_suspects(m: Dictionary) -> void:
	for c in suspects_row.get_children():
		c.queue_free()
	var suspects: Array = m.get("suspects", [])
	if suspects.is_empty() and is_instance_valid(CharacterDB):
		suspects = CharacterDB.delinquent_thumbs_for_mission(str(m.get("id", "")), 3)
	var fallback := ["SOSPECHOSO 1", "SOSPECHOSO 2", "POSIBLE 3º"]
	for i in range(3):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(0, 96)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label_txt: String = fallback[i]
		var alias_txt: String = "Sin ID confirmada"
		if i < suspects.size():
			var s: Dictionary = suspects[i]
			var path := str(s.get("thumb", ""))
			if ResourceLoader.exists(path):
				face.texture = load(path)
			label_txt = str(s.get("name", fallback[i]))
			alias_txt = "Alias: %s" % str(s.get("alias", "—"))
		col.add_child(face)
		var name_l := Label.new()
		name_l.text = label_txt
		name_l.add_theme_font_size_override("font_size", 11)
		name_l.add_theme_color_override("font_color", Color(0.92, 0.78, 0.78))
		col.add_child(name_l)
		var desc := Label.new()
		desc.text = alias_txt
		desc.add_theme_font_size_override("font_size", 9)
		desc.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
		suspects_row.add_child(col)
	if str(m.get("severity", "")) == "critical":
		witnesses.modulate = Color(1.0, 0.75, 0.75)


func _risk(m: Dictionary) -> int:
	match str(m.get("severity", "")):
		"critical":
			return 5
		"high":
			return 4
		"medium":
			return 3
		_:
			return 2


func _refresh_patrols() -> void:
	patrol_list.clear()
	_patrol_ids.clear()
	for p in GameState.patrols.values():
		_patrol_ids.append(p["id"])
		var line: String = "%s — %s (%s)" % [p["name"], p["callsign"], _status(p["status"])]
		patrol_list.add_item(line)
		var idx: int = patrol_list.item_count - 1
		if p["status"] != "available":
			patrol_list.set_item_disabled(idx, true)
			patrol_list.set_item_custom_fg_color(idx, Color(0.6, 0.65, 0.75))
	for i in range(_patrol_ids.size()):
		if not patrol_list.is_item_disabled(i):
			patrol_list.select(i)
			break


func _status(st: String) -> String:
	match st:
		"available":
			return "EN BASE"
		"en_route":
			return "EN RUTA"
		"on_scene":
			return "EN SERVICIO"
		"returning":
			return "REGRESO"
		_:
			return st


func _set_action(action: String) -> void:
	_action = action
	_paint(action_cautious, action == "cautious", Color(0.35, 0.62, 1.0))
	_paint(action_entry, action == "entry", Color(1.0, 0.35, 0.35))
	_paint(action_negotiate, action == "negotiate", Color(1.0, 0.82, 0.3))
	_paint(action_block, action == "block", Color(0.4, 0.55, 0.9))


func _paint(btn: Button, on: bool, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.28, 1.0) if on else Color(0.08, 0.12, 0.18)
	sb.border_color = col if on else Color(0.25, 0.35, 0.48)
	sb.set_border_width_all(2 if on else 1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0) if on else Color(0.7, 0.76, 0.85))


func _confirm() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty() or m.get("status", "") != "open":
		return
	if not patrol_list.is_anything_selected():
		RadioBus.push("Elige una patrulla disponible.", "alert")
		return
	var idx: int = patrol_list.get_selected_items()[0]
	var pid: String = String(_patrol_ids[idx])
	# Guardar táctica elegida en la misión
	m["tactic"] = _action
	GameState.update_mission(m)
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	var ok: bool = dispatch.dispatch(m["id"], pid)
	if ok:
		var extra := " + apoyo extra" if support_check.button_pressed else ""
		RadioBus.push("Táctica: %s%s" % [_action_name(_action), extra], "dispatch")
		_back_to_map()
	else:
		RadioBus.push("No se pudo confirmar el despacho.", "alert")


func _action_name(a: String) -> String:
	match a:
		"cautious":
			return "acercamiento cauteloso"
		"entry":
			return "entrada inmediata"
		"negotiate":
			return "negociación"
		"block":
			return "bloqueo de fuga"
		_:
			return a


func _back() -> void:
	var router := get_parent()
	if router and router.has_method("show_missions"):
		router.show_missions()


func _back_to_map() -> void:
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()
