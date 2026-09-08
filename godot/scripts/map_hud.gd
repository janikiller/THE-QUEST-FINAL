extends Control
## HUD del mapa: barra superior + unidad activa inferior (mockup comisaría).

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var radio_toast: Label = %RadioToast
@onready var btn_missions: Button = %BtnMissions
@onready var btn_inventory: Button = %BtnInventory
@onready var btn_weather: Button = %BtnWeather
@onready var btn_music: Button = %BtnMusic
@onready var hint: Label = %Hint
@onready var btn_speed_1: Button = %BtnSpeed1
@onready var btn_speed_4: Button = %BtnSpeed4
@onready var btn_speed_16: Button = %BtnSpeed16
@onready var btn_speed_60: Button = %BtnSpeed60

var _speed_group: ButtonGroup
var _unit_row: HBoxContainer
var _alerts_btn: Button
var _selected_patrol_id: String = "alpha"


func _ready() -> void:
	GameState.time_changed.connect(func(t):
		time_label.text = t
		_update_tod_hint()
	)
	GameState.prestige_changed.connect(func(_v): _update_tod_hint())
	GameState.time_speed_changed.connect(func(_s): _sync_speed_buttons())
	GameState.weather_changed.connect(func(_w): _update_tod_hint())
	GameState.patrol_updated.connect(func(_p): _rebuild_active_unit())
	GameState.mission_added.connect(func(_m): _update_mission_badge())
	GameState.mission_updated.connect(func(_m): _update_mission_badge())
	RadioBus.radio_message.connect(_on_radio)
	btn_missions.pressed.connect(_open_missions)
	btn_inventory.pressed.connect(_open_inventory)
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
	hint.text = "WASD mover · M misiones · I equipo · C clima · N música · 1-4 velocidad · rueda zoom"
	_build_bottom_bar()
	_update_tod_hint()
	_sync_speed_buttons()
	_rebuild_active_unit()
	_update_mission_badge()


func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "ActiveUnitBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = -188
	bar.offset_bottom = -12
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.14, 0.94)
	sb.border_color = Color(0.2, 0.45, 0.75, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)

	var title := Label.new()
	title.text = "UNIDAD ACTIVA"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	left.add_child(title)

	_unit_row = HBoxContainer.new()
	_unit_row.add_theme_constant_override("separation", 8)
	_unit_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_unit_row)

	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(280, 0)
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)

	var nav_title := Label.new()
	nav_title.text = "COMISARÍA"
	nav_title.add_theme_font_size_override("font_size", 11)
	nav_title.add_theme_color_override("font_color", Color(0.6, 0.72, 0.88))
	nav.add_child(nav_title)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	nav.add_child(nav_row)
	_add_nav_btn(nav_row, "EQUIPO", _open_inventory)
	_add_nav_btn(nav_row, "MISIONES", _open_missions)
	_add_nav_btn(nav_row, "MAPA", func(): pass)

	var nav_row2 := HBoxContainer.new()
	nav_row2.add_theme_constant_override("separation", 6)
	nav.add_child(nav_row2)
	_add_nav_btn(nav_row2, "DESPACHO", _open_missions)
	_add_nav_btn(nav_row2, "DATOS", _open_inventory)

	_alerts_btn = Button.new()
	_alerts_btn.custom_minimum_size = Vector2(0, 40)
	_alerts_btn.text = "ALERTAS  0"
	_alerts_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.45, 0.12, 0.14, 0.95)
	asb.set_corner_radius_all(6)
	_alerts_btn.add_theme_stylebox_override("normal", asb)
	_alerts_btn.pressed.connect(_open_missions)
	nav.add_child(_alerts_btn)

	# Lift toast/hint above the new bar
	radio_toast.offset_top = -250
	radio_toast.offset_bottom = -210
	hint.offset_top = -28
	hint.offset_bottom = -8


func _add_nav_btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	parent.add_child(b)


func _rebuild_active_unit() -> void:
	if _unit_row == null:
		return
	for c in _unit_row.get_children():
		c.queue_free()
	if not GameState.patrols.has(_selected_patrol_id):
		var keys: Array = GameState.patrols.keys()
		if keys.is_empty():
			return
		_selected_patrol_id = str(keys[0])
	# Prefer a busy patrol if any
	for p in GameState.patrols.values():
		if str(p.get("status", "")) != "available":
			_selected_patrol_id = str(p.get("id", _selected_patrol_id))
			break
	var patrol: Dictionary = GameState.patrols[_selected_patrol_id]
	var names: Array = patrol.get("agents", [])
	var portraits: Array = patrol.get("agent_portraits", [])
	var stats_all: Array = patrol.get("agent_stats", [])
	var header := Label.new()
	header.text = "%s  ·  %s" % [patrol.get("name", ""), patrol.get("callsign", "")]
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	# Put callsign as first tiny card label via spacer then agents
	for i in range(names.size()):
		_unit_row.add_child(_make_agent_card(
			str(names[i]),
			str(portraits[i]) if i < portraits.size() else "",
			stats_all[i] if i < stats_all.size() else {},
			i
		))
	# Patrol switcher chips
	for p in GameState.patrols.values():
		var chip := Button.new()
		chip.text = str(p.get("callsign", "?"))
		chip.custom_minimum_size = Vector2(72, 48)
		var pid := str(p.get("id", ""))
		if pid == _selected_patrol_id:
			chip.modulate = Color(0.6, 0.9, 1.0)
		chip.pressed.connect(func():
			_selected_patrol_id = pid
			_rebuild_active_unit()
		)
		_unit_row.add_child(chip)


func _make_agent_card(agent_name: String, portrait_path: String, stats: Dictionary, idx: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 140)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.12, 0.2, 0.98)
	sb.border_color = Color(0.25, 0.55, 0.9, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var name_l := Label.new()
	name_l.text = "%s #%03d" % [agent_name.to_upper(), 10 + idx * 13]
	name_l.add_theme_font_size_override("font_size", 11)
	v.add_child(name_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(52, 68)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(portrait_path):
		face.texture = load(portrait_path)
	row.add_child(face)
	var stats_col := VBoxContainer.new()
	stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_col.add_theme_constant_override("separation", 1)
	row.add_child(stats_col)
	for key in ["fuerza", "resistencia", "destreza", "investigacion", "conduccion"]:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = 1.0
		bar.value = float(stats.get(key, 0.5))
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		match key:
			"fuerza":
				fill.bg_color = Color(0.9, 0.25, 0.3)
			"resistencia":
				fill.bg_color = Color(0.95, 0.55, 0.2)
			"destreza":
				fill.bg_color = Color(0.95, 0.85, 0.25)
			"investigacion":
				fill.bg_color = Color(0.3, 0.65, 1.0)
			_:
				fill.bg_color = Color(0.35, 0.85, 0.95)
		fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.14, 0.2)
		bg.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bg)
		stats_col.add_child(bar)
	return card


func _update_mission_badge() -> void:
	if _alerts_btn == null:
		return
	var open_n := 0
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) in ["open", "dispatched", "resolving"]:
			open_n += 1
	_alerts_btn.text = "ALERTAS  %d" % open_n
	btn_missions.text = "MISIONES (%d)" % open_n


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
		_open_inventory()
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


func _open_inventory() -> void:
	var router := get_parent()
	if router and router.has_method("show_inventory"):
		router.show_inventory(_selected_patrol_id)


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
