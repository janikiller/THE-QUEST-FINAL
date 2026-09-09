extends Control
## HUD del mapa: barra superior + dock inferior usable (unidad + acciones).

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var radio_toast: Label = %RadioToast
@onready var btn_missions: Button = %BtnMissions
@onready var btn_deck: Button = %BtnInventory
@onready var btn_weather: Button = %BtnWeather
@onready var btn_music: Button = %BtnMusic
@onready var hint: Label = %Hint
@onready var btn_speed_1: Button = %BtnSpeed1
@onready var btn_speed_4: Button = %BtnSpeed4
@onready var btn_speed_16: Button = %BtnSpeed16
@onready var btn_speed_60: Button = %BtnSpeed60

var _speed_group: ButtonGroup
var _selected_patrol_id: String = "alpha"
var _dock: PanelContainer
var _unit_face: TextureRect
var _unit_title: Label
var _unit_sub: Label
var _unit_status: Label
var _lights: TextureRect
var _btn_missions_dock: Button
var _btn_deck_dock: Button
var _btn_alerts: Button
var _period_chip: Label
var _flash_t: float = 0.0


func _ready() -> void:
	GameState.time_changed.connect(func(t):
		time_label.text = t
		_update_tod_hint()
		_refresh_dock()
	)
	GameState.prestige_changed.connect(func(_v): _update_tod_hint())
	GameState.time_speed_changed.connect(func(_s): _sync_speed_buttons())
	GameState.weather_changed.connect(func(_w): _update_tod_hint())
	GameState.patrol_updated.connect(func(_p): _refresh_dock())
	GameState.mission_added.connect(func(_m): _refresh_dock())
	GameState.mission_updated.connect(func(_m): _refresh_dock())
	GameState.mission_removed.connect(func(_id): _refresh_dock())
	GameState.period_changed.connect(func(_p): _refresh_dock())
	RadioBus.radio_message.connect(_on_radio)
	btn_missions.pressed.connect(_open_missions)
	btn_deck.pressed.connect(_open_deck)
	btn_weather.pressed.connect(func(): GameState.cycle_weather())
	btn_music.pressed.connect(func(): AudioDirector.toggle_music())
	AudioDirector.music_toggled.connect(func(on): btn_music.text = "MÚSICA" if on else "MUTE")
	_speed_group = ButtonGroup.new()
	for b in [btn_speed_1, btn_speed_4, btn_speed_16, btn_speed_60]:
		b.button_group = _speed_group
	btn_speed_1.pressed.connect(func(): GameState.set_time_speed(1.0))
	btn_speed_4.pressed.connect(func(): GameState.set_time_speed(4.0))
	btn_speed_16.pressed.connect(func(): GameState.set_time_speed(16.0))
	btn_speed_60.pressed.connect(func(): GameState.set_time_speed(60.0))
	time_label.text = "%02d:%02d" % [GameState.hour, GameState.minute]
	hint.text = "WASD mover · M misiones · I mazo · 1-4 velocidad"
	_build_bottom_dock()
	_update_tod_hint()
	_sync_speed_buttons()
	_refresh_dock()


func _process(delta: float) -> void:
	_flash_t += delta * 6.0
	if _lights and is_instance_valid(_lights):
		var on := sin(_flash_t) >= 0.0
		_lights.modulate = Color(0.7, 0.85, 1.3, 1.0) if on else Color(1.3, 0.75, 0.8, 1.0)


func _build_bottom_dock() -> void:
	_dock = PanelContainer.new()
	_dock.name = "BottomDock"
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 18
	_dock.offset_right = -18
	_dock.offset_top = -128
	_dock.offset_bottom = -12
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.1, 0.92)
	sb.border_color = Color(0.25, 0.55, 0.95, 0.55)
	sb.border_width_top = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_dock.add_theme_stylebox_override("panel", sb)
	add_child(_dock)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_dock.add_child(root)

	# --- Unidad (izquierda) ---
	var unit := HBoxContainer.new()
	unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit.add_theme_constant_override("separation", 12)
	root.add_child(unit)

	# Badge circular de luces
	_lights = TextureRect.new()
	_lights.custom_minimum_size = Vector2(64, 64)
	_lights.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lights.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/police_beacon.png"):
		_lights.texture = load("res://assets/ui/police_beacon.png")
	elif ResourceLoader.exists("res://assets/ui/police_lightbar.png"):
		_lights.texture = load("res://assets/ui/police_lightbar.png")
	unit.add_child(_lights)

	_unit_face = TextureRect.new()
	_unit_face.visible = false
	unit.add_child(_unit_face)

	var unit_text := VBoxContainer.new()
	unit_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	unit_text.add_theme_constant_override("separation", 1)
	unit.add_child(unit_text)

	var unit_tag := Label.new()
	unit_tag.text = "UNIDAD ACTIVA"
	unit_tag.add_theme_font_size_override("font_size", 10)
	unit_tag.add_theme_color_override("font_color", Color(0.5, 0.72, 1.0))
	unit_text.add_child(unit_tag)

	_unit_title = Label.new()
	_unit_title.add_theme_font_size_override("font_size", 18)
	_unit_title.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	unit_text.add_child(_unit_title)

	_unit_sub = Label.new()
	_unit_sub.add_theme_font_size_override("font_size", 13)
	_unit_sub.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	unit_text.add_child(_unit_sub)

	_unit_status = Label.new()
	_unit_status.add_theme_font_size_override("font_size", 12)
	_unit_status.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	unit_text.add_child(_unit_status)

	# --- Acciones (centro) ---
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(actions)

	_btn_missions_dock = _make_dock_btn("MISIONES", "Abrir lista", Color(0.15, 0.48, 0.98))
	_btn_missions_dock.pressed.connect(_open_missions)
	actions.add_child(_btn_missions_dock)

	_btn_deck_dock = _make_dock_btn("MAZO", "Cartas · I", Color(0.1, 0.58, 0.72))
	_btn_deck_dock.pressed.connect(_open_deck)
	actions.add_child(_btn_deck_dock)

	_btn_alerts = _make_dock_btn("SEÑALES", "En el mapa", Color(0.88, 0.22, 0.3))
	_btn_alerts.pressed.connect(_open_missions)
	actions.add_child(_btn_alerts)

	# --- Franja (derecha) ---
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(132, 0)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.05, 0.09, 0.14, 0.95)
	rsb.border_color = Color(0.3, 0.5, 0.8, 0.45)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(10)
	rsb.content_margin_left = 10
	rsb.content_margin_right = 10
	rsb.content_margin_top = 8
	rsb.content_margin_bottom = 8
	right.add_theme_stylebox_override("panel", rsb)
	root.add_child(right)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 2)
	right.add_child(right_col)

	var right_title := Label.new()
	right_title.text = "TURNO"
	right_title.add_theme_font_size_override("font_size", 10)
	right_title.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	right_col.add_child(right_title)

	_period_chip = Label.new()
	_period_chip.add_theme_font_size_override("font_size", 20)
	_period_chip.add_theme_color_override("font_color", Color(1, 1, 1))
	right_col.add_child(_period_chip)

	# Toast / hint por encima del dock
	radio_toast.offset_top = -168
	radio_toast.offset_bottom = -128
	hint.offset_top = -28
	hint.offset_bottom = -8
	hint.visible = false


func _make_dock_btn(title: String, subtitle: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, subtitle]
	b.custom_minimum_size = Vector2(128, 74)
	b.focus_mode = Control.FOCUS_NONE
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.05, 0.09, 0.14, 0.98)
	n.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	n.set_border_width_all(2)
	n.set_corner_radius_all(12)
	n.content_margin_left = 12
	n.content_margin_right = 12
	n.content_margin_top = 10
	n.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate()
	h.bg_color = Color(accent.r, accent.g, accent.b, 0.32)
	b.add_theme_stylebox_override("hover", h)
	var p := n.duplicate()
	p.bg_color = Color(accent.r, accent.g, accent.b, 0.5)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	return b


func _refresh_dock() -> void:
	if _dock == null:
		return
	if not GameState.patrols.has(_selected_patrol_id):
		var keys: Array = GameState.patrols.keys()
		if keys.is_empty():
			return
		_selected_patrol_id = str(keys[0])
	for p in GameState.patrols.values():
		if str(p.get("status", "")) != "available":
			_selected_patrol_id = str(p.get("id", _selected_patrol_id))
			break
	var patrol: Dictionary = GameState.patrols[_selected_patrol_id]
	var agents: Array = patrol.get("agents", [])
	var agent_name := str(agents[0]) if not agents.is_empty() else str(patrol.get("name", "Unidad"))
	_unit_title.text = agent_name.to_upper()
	_unit_sub.text = str(patrol.get("callsign", "U.P.R."))
	var st := str(patrol.get("status", "available"))
	var st_label := "EN BASE"
	var st_col := Color(0.45, 0.85, 0.55)
	match st:
		"en_route":
			st_label = "EN RUTA"
			st_col = Color(0.35, 0.7, 1.0)
		"on_scene":
			st_label = "EN ESCENA"
			st_col = Color(1.0, 0.75, 0.25)
		"returning":
			st_label = "REGRESANDO"
			st_col = Color(0.75, 0.8, 0.9)
	_unit_status.text = st_label
	_unit_status.add_theme_color_override("font_color", st_col)

	var open_n := 0
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) in ["open", "dispatched", "resolving"]:
			open_n += 1
	if _btn_missions_dock:
		_btn_missions_dock.text = "MISIONES\n%d activas" % open_n
	if _btn_alerts:
		_btn_alerts.text = "SEÑALES\n%d en mapa" % open_n
	if _btn_deck_dock:
		_btn_deck_dock.text = "MAZO\nCartas · I"
	btn_missions.text = "MISIONES  (%d)" % open_n

	var period := GameState.period_label()
	if _period_chip:
		_period_chip.text = period
		match GameState.time_of_day():
			"dusk":
				_period_chip.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
			"night":
				_period_chip.add_theme_color_override("font_color", Color(0.55, 0.7, 1.0))
			_:
				_period_chip.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))


func _update_tod_hint() -> void:
	var tod := GameState.time_of_day()
	var label := "DÍA"
	match tod:
		"dusk":
			label = "ATARDECER"
		"night":
			label = "NOCHE"
	prestige_label.text = "★%d  %s  %s  %dx" % [
		GameState.prestige, label, GameState.weather_label(), int(round(GameState.time_speed))
	]
	btn_weather.text = GameState.weather_label()
	_refresh_dock()


func _sync_speed_buttons() -> void:
	var s := int(round(GameState.time_speed))
	btn_speed_1.button_pressed = s == 1
	btn_speed_4.button_pressed = s == 4
	btn_speed_16.button_pressed = s == 16
	btn_speed_60.button_pressed = s == 60


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_missions") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		_open_missions()
	elif event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		_open_deck()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				GameState.set_time_speed(1.0)
			KEY_2:
				GameState.set_time_speed(4.0)
			KEY_3:
				GameState.set_time_speed(16.0)
			KEY_4:
				GameState.set_time_speed(60.0)
			KEY_PERIOD, KEY_EQUAL:
				GameState.cycle_time_speed()
			KEY_C:
				GameState.cycle_weather()
			KEY_N:
				AudioDirector.toggle_music()


func _open_missions() -> void:
	var router := get_parent()
	if router and router.has_method("show_missions"):
		router.show_missions()


func _open_deck() -> void:
	var router := get_parent()
	if router and router.has_method("show_deck"):
		router.show_deck("alpha")


func _on_radio(text: String, kind: String) -> void:
	var prefix := ""
	match kind:
		"alert":
			prefix = "! "
		"dispatch":
			prefix = "> "
		"resolve":
			prefix = "OK "
	radio_toast.text = prefix + text
	radio_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(radio_toast, "modulate:a", 0.0, 0.8)
