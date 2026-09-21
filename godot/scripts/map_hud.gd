extends Control
## HUD del mapa estilo Dispatch: barra de datos, CRT (scanlines/viñeta) y roster inferior.

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
var _roster_row: HBoxContainer
var _roster_slots: Array = [] # PanelContainer
var _data_left: Label
var _data_right: Label
var _scanlines: ColorRect
var _vignette: ColorRect
var _grid: ColorRect
var _flash_t: float = 0.0

const GREEN := Color(0.35, 0.95, 0.55, 1.0)
const GREEN_DIM := Color(0.2, 0.55, 0.35, 1.0)
const ORANGE := Color(1.0, 0.55, 0.2, 1.0)
const TEAL := Color(0.25, 0.85, 0.85, 1.0)
const PANEL_BG := Color(0.02, 0.06, 0.04, 0.88)


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
	GameState.credits_changed.connect(func(_v): _refresh_dock())
	GameState.xp_changed.connect(func(_xp, _lv, _need): _refresh_dock())
	GameState.leveled_up.connect(func(_lv): _refresh_dock())
	GameState.day_changed.connect(func(_d): _refresh_dock())
	RadioBus.radio_message.connect(_on_radio)
	btn_missions.pressed.connect(_open_missions)
	btn_deck.pressed.connect(_open_deck)
	btn_weather.pressed.connect(func(): GameState.cycle_weather())
	btn_music.pressed.connect(func():
		AudioDirector.play_ui_click()
		AudioDirector.toggle_music())
	AudioDirector.music_toggled.connect(func(on): btn_music.text = "MÚSICA" if on else "MUTE")
	_speed_group = ButtonGroup.new()
	for b in [btn_speed_1, btn_speed_4, btn_speed_16, btn_speed_60]:
		b.button_group = _speed_group
	btn_speed_1.pressed.connect(func(): GameState.set_time_speed(1.0))
	btn_speed_4.pressed.connect(func(): GameState.set_time_speed(4.0))
	btn_speed_16.pressed.connect(func(): GameState.set_time_speed(16.0))
	btn_speed_60.pressed.connect(func(): GameState.set_time_speed(60.0))
	time_label.text = "%02d:%02d" % [GameState.hour, GameState.minute]
	hint.text = "L  TOOLTIPS  ·  WASD  ·  M/I/K"
	_apply_dispatch_chrome()
	_build_crt_fx()
	_build_bottom_roster()
	_update_tod_hint()
	_sync_speed_buttons()
	_refresh_dock()
	set_process(true)


func _process(delta: float) -> void:
	_flash_t += delta
	if _scanlines and is_instance_valid(_scanlines):
		# Ligero parpadeo CRT
		_scanlines.modulate.a = 0.14 + sin(_flash_t * 7.5) * 0.02


func _apply_dispatch_chrome() -> void:
	var top := get_node_or_null("TopBar") as PanelContainer
	if top:
		top.offset_left = 10.0
		top.offset_right = -10.0
		top.offset_top = 8.0
		top.offset_bottom = 58.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.015, 0.05, 0.03, 0.82)
		sb.border_color = Color(0.25, 0.9, 0.5, 0.55)
		sb.border_width_bottom = 2
		sb.border_width_top = 1
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		top.add_theme_stylebox_override("panel", sb)

	# Brand + datos tácticos
	var brand := get_node_or_null("TopBar/Margin/Row/Brand") as Label
	if brand:
		brand.text = "SDN"
		brand.add_theme_font_size_override("font_size", 18)
		brand.add_theme_color_override("font_color", GREEN)

	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))

	prestige_label.add_theme_font_size_override("font_size", 13)
	prestige_label.add_theme_color_override("font_color", GREEN_DIM)

	for b in [btn_missions, btn_deck, btn_weather, btn_music, btn_speed_1, btn_speed_4, btn_speed_16, btn_speed_60]:
		_style_top_btn(b)

	# Insertar chips de datos si faltan
	var row := get_node_or_null("TopBar/Margin/Row") as HBoxContainer
	if row and row.get_node_or_null("DataLeft") == null:
		_data_left = Label.new()
		_data_left.name = "DataLeft"
		_data_left.add_theme_font_size_override("font_size", 12)
		_data_left.add_theme_color_override("font_color", Color(0.55, 0.9, 0.7))
		row.add_child(_data_left)
		row.move_child(_data_left, 2)
		_data_right = Label.new()
		_data_right.name = "DataRight"
		_data_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_data_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_data_right.add_theme_font_size_override("font_size", 12)
		_data_right.add_theme_color_override("font_color", Color(0.7, 0.95, 0.8))
		# Antes de botones de menú
		var weather_i := btn_weather.get_index() if btn_weather else row.get_child_count()
		row.add_child(_data_right)
		row.move_child(_data_right, weather_i)


func _style_top_btn(b: Button) -> void:
	if b == null:
		return
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.03, 0.1, 0.06, 0.9)
	n.border_color = Color(0.3, 0.85, 0.5, 0.7)
	n.set_border_width_all(1)
	n.set_corner_radius_all(2)
	n.content_margin_left = 8
	n.content_margin_right = 8
	n.content_margin_top = 4
	n.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate()
	h.bg_color = Color(0.12, 0.35, 0.2, 0.95)
	h.border_color = GREEN
	b.add_theme_stylebox_override("hover", h)
	var p := n.duplicate()
	p.bg_color = Color(0.2, 0.55, 0.3, 0.95)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE


func _build_crt_fx() -> void:
	# Viñeta
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0, 0, 0, 0.0)
	_vignette.z_index = 40
	# Gradiente simulado con 4 bordes
	add_child(_vignette)
	_add_edge_vignette("VTop", true, true)
	_add_edge_vignette("VBottom", true, false)
	_add_edge_vignette("VLeft", false, true)
	_add_edge_vignette("VRight", false, false)

	# Scanlines (textura procedural vía ColorRect + shader simple)
	_scanlines = ColorRect.new()
	_scanlines.name = "Scanlines"
	_scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanlines.z_index = 41
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float y = FRAGCOORD.y;
	float line = step(0.55, fract(y * 0.5));
	COLOR = vec4(0.0, 0.08, 0.04, line * 0.22);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_scanlines.material = mat
	_scanlines.color = Color(1, 1, 1, 1)
	add_child(_scanlines)

	# Grid sutil sobre el mapa (solo zona central)
	_grid = ColorRect.new()
	_grid.name = "HudGrid"
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.offset_top = 64.0
	_grid.offset_bottom = -150.0
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.z_index = 5
	var gsh := Shader.new()
	gsh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float gx = step(0.97, fract(uv.x * 28.0));
	float gy = step(0.97, fract(uv.y * 16.0));
	float g = max(gx, gy);
	COLOR = vec4(0.2, 0.9, 0.45, g * 0.08);
}
"""
	var gmat := ShaderMaterial.new()
	gmat.shader = gsh
	_grid.material = gmat
	add_child(_grid)

	radio_toast.add_theme_color_override("font_color", GREEN)
	radio_toast.offset_top = -190.0
	radio_toast.offset_bottom = -155.0
	hint.add_theme_color_override("font_color", GREEN_DIM)
	hint.offset_top = -32.0
	hint.offset_bottom = -10.0
	hint.visible = true


func _add_edge_vignette(nm: String, horizontal: bool, start: bool) -> void:
	var edge := ColorRect.new()
	edge.name = nm
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.z_index = 39
	edge.color = Color(0.0, 0.02, 0.01, 0.72)
	if horizontal:
		edge.set_anchors_preset(Control.PRESET_TOP_WIDE if start else Control.PRESET_BOTTOM_WIDE)
		if start:
			edge.offset_bottom = 90.0
		else:
			edge.offset_top = -160.0
	else:
		edge.set_anchors_preset(Control.PRESET_LEFT_WIDE if start else Control.PRESET_RIGHT_WIDE)
		if start:
			edge.offset_right = 70.0
		else:
			edge.offset_left = -70.0
	add_child(edge)


func _build_bottom_roster() -> void:
	_dock = PanelContainer.new()
	_dock.name = "BottomDock"
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 12.0
	_dock.offset_right = -12.0
	_dock.offset_top = -148.0
	_dock.offset_bottom = -8.0
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.z_index = 20
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.3, 0.9, 0.5, 0.65)
	sb.border_width_top = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_dock.add_theme_stylebox_override("panel", sb)
	add_child(_dock)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_dock.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var hdr := Label.new()
	hdr.text = "UNIDADES DISPONIBLES"
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", GREEN_DIM)
	header.add_child(hdr)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var btn_m := _make_link_btn("MISIONES", ORANGE)
	btn_m.pressed.connect(_open_missions)
	header.add_child(btn_m)
	var btn_d := _make_link_btn("MAZO", TEAL)
	btn_d.pressed.connect(_open_deck)
	header.add_child(btn_d)
	var btn_k := _make_link_btn("MERCADO", Color(0.95, 0.75, 0.25))
	btn_k.pressed.connect(_open_market)
	header.add_child(btn_k)

	_roster_row = HBoxContainer.new()
	_roster_row.name = "RosterRow"
	_roster_row.add_theme_constant_override("separation", 8)
	_roster_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_roster_row)

	_roster_slots.clear()
	var police: Array = CharacterDB.police if CharacterDB else []
	var count := mini(8, police.size()) if not police.is_empty() else 8
	for i in range(count):
		var slot := _make_roster_slot(i, police[i] if i < police.size() else {})
		_roster_row.add_child(slot)
		_roster_slots.append(slot)


func _make_link_btn(txt: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 26)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.04, 0.1, 0.07, 0.95)
	n.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	n.set_border_width_all(1)
	n.set_corner_radius_all(2)
	n.content_margin_left = 8
	n.content_margin_right = 8
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate()
	h.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(0.9, 1.0, 0.92))
	return b


func _make_roster_slot(index: int, agent: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % index
	panel.custom_minimum_size = Vector2(118, 96)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("agent_id", str(agent.get("id", "")))
	panel.set_meta("agent_name", str(agent.get("name", "UNIDAD")))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.08, 0.05, 0.95)
	sb.border_color = Color(0.3, 0.75, 0.45, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", TEAL)
	status.text = "EN BASE"
	v.add_child(status)

	var face := TextureRect.new()
	face.name = "Face"
	face.custom_minimum_size = Vector2(0, 52)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var thumb := str(agent.get("thumb", agent.get("full", "")))
	if thumb != "" and (ResourceLoader.exists(thumb) or FileAccess.file_exists(thumb)):
		if ResourceLoader.exists(thumb):
			face.texture = load(thumb)
		else:
			var img := Image.load_from_file(thumb)
			if img:
				face.texture = ImageTexture.create_from_image(img)
	v.add_child(face)

	var nm := Label.new()
	nm.name = "Name"
	nm.text = str(agent.get("name", "UNIDAD")).to_upper()
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 11)
	nm.add_theme_color_override("font_color", Color(0.92, 1.0, 0.95))
	nm.clip_text = true
	v.add_child(nm)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _on_roster_pressed(str(agent.get("name", "")), panel))
	panel.add_child(btn)
	return panel


func _on_roster_pressed(agent_name: String, panel: PanelContainer) -> void:
	AudioDirector.play_ui_click()
	# Selecciona patrulla que contenga al agente, o alpha por defecto
	for p in GameState.patrols.values():
		var agents: Array = p.get("agents", [])
		if agent_name in agents or agents.is_empty():
			_selected_patrol_id = str(p.get("id", "alpha"))
			break
	for s in _roster_slots:
		if s is PanelContainer:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.03, 0.08, 0.05, 0.95)
			sb.border_color = Color(0.3, 0.75, 0.45, 0.7) if s != panel else GREEN
			sb.set_border_width_all(2 if s == panel else 1)
			sb.set_corner_radius_all(2)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			s.add_theme_stylebox_override("panel", sb)
	_refresh_dock()


func _refresh_dock() -> void:
	if _dock == null:
		return
	# Datos top
	if _data_left:
		_data_left.text = "%d cs · NV.%d · %d/%d XP" % [
			GameState.credits,
			GameState.hero_level,
			GameState.hero_xp,
			GameState.xp_to_next_level(),
		]
	if _data_right:
		var weather := GameState.weather_label()
		_data_right.text = "%s  ·  %s  ·  D%d  ·  %s" % [
			weather,
			GameState.period_label(),
			GameState.day_index,
			GameState.time_of_day().to_upper(),
		]

	var open_n := 0
	for m in GameState.active_missions.values():
		if str(m.get("status", "")) in ["open", "dispatched", "resolving"]:
			open_n += 1
	btn_missions.text = "MISIONES (%d)" % open_n

	# Estados del roster según patrullas / misiones
	var active_names: Dictionary = {} # name -> status label/color
	for p in GameState.patrols.values():
		var st := str(p.get("status", "available"))
		var st_label := "EN BASE"
		var st_col := TEAL
		match st:
			"en_route":
				st_label = "EN RUTA"
				st_col = ORANGE
			"on_scene":
				st_label = "EN ESCENA"
				st_col = Color(1.0, 0.35, 0.3)
			"returning":
				st_label = "REGRESANDO"
				st_col = ORANGE
			"available":
				st_label = "EN BASE"
				st_col = TEAL
			_:
				st_label = st.to_upper()
		for a in p.get("agents", []):
			active_names[str(a)] = {"label": st_label, "color": st_col}

	for slot in _roster_slots:
		if not (slot is PanelContainer):
			continue
		var aname := str(slot.get_meta("agent_name", ""))
		var status_l: Label = slot.find_child("Status", true, false) as Label
		if status_l == null:
			continue
		if active_names.has(aname):
			status_l.text = str(active_names[aname]["label"])
			status_l.add_theme_color_override("font_color", active_names[aname]["color"])
		else:
			# Resto del catálogo: descanso / listo
			var idx := int(str(slot.name).replace("Slot", ""))
			if idx % 5 == 2:
				status_l.text = "DESCANSO"
				status_l.add_theme_color_override("font_color", TEAL)
			elif idx % 5 == 4:
				status_l.text = "STANDBY"
				status_l.add_theme_color_override("font_color", GREEN_DIM)
			else:
				status_l.text = "LISTO"
				status_l.add_theme_color_override("font_color", GREEN)


func _update_tod_hint() -> void:
	var tod := GameState.time_of_day()
	var label := "DÍA"
	match tod:
		"dusk":
			label = "ATARDECER"
		"night":
			label = "NOCHE"
	prestige_label.text = "★%d  %s  %dx" % [
		GameState.prestige, label, int(round(GameState.time_speed))
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
			KEY_K:
				_open_market()
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


func _open_market() -> void:
	var router := get_parent()
	if router and router.has_method("show_market"):
		router.show_market("alpha")


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
