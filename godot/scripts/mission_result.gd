extends Control
## Informe final de misión (inicio → desarrollo → final).

@onready var title: Label = %ResultTitle
@onready var meta: Label = %ResultMeta
@onready var verdict: Label = %VerdictLabel
@onready var verdict_sub: Label = %VerdictSub
@onready var beats_grid: GridContainer = %BeatsGrid
@onready var summary: RichTextLabel = %SummaryBox
@onready var art: TextureRect = %ResultArt
@onready var btn_close: Button = %BtnClose
@onready var phase_banner: Label = %PhaseBanner

var _mission: Dictionary = {}


func _ready() -> void:
	btn_close.pressed.connect(_close)
	visible = false


func open_for(mission_id: String = "") -> void:
	_mission = GameState.last_resolved_mission()
	if _mission.is_empty() and mission_id != "" and GameState.active_missions.has(mission_id):
		_mission = GameState.active_missions[mission_id].duplicate(true)
	if _mission.is_empty():
		_close()
		return
	visible = true
	_refresh()


func _refresh() -> void:
	var m := _mission
	var ok: bool = str(m.get("outcome", "")) == "success" or str(m.get("status", "")) == "resolved"
	title.text = str(m.get("title", "MISIÓN")).to_upper()
	meta.text = "%s  ·  %s" % [_cat(m), m.get("district_name", "")]
	phase_banner.text = "ARCO  ·  INICIO  →  DESARROLLO  →  FINAL"
	if ok:
		verdict.text = "MISIÓN EXITOSA"
		verdict.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
		verdict_sub.text = str(m.get("outcome_report", "Objetivo cumplido."))
	else:
		verdict.text = "MISIÓN FALLIDA"
		verdict.add_theme_color_override("font_color", Color(1.0, 0.35, 0.38))
		verdict_sub.text = str(m.get("outcome_report", "El sospechoso ha escapado."))
	var path := GameState.mission_art_path(m)
	art.texture = load(path) if ResourceLoader.exists(path) else null
	_rebuild_beats(m, ok)
	summary.text = _summary_bbcode(m, ok)


func _cat(m: Dictionary) -> String:
	match str(m.get("category", "")):
		"delitos":
			return "DELITOS CONTRA LA PROPIEDAD"
		"trafico":
			return "SEGURIDAD VIAL"
		"civiles":
			return "ASISTENCIA"
		"organizado":
			return "SALUD PÚBLICA"
		"especiales":
			return "OPERACIONES ESPECIALES"
		"emergencias":
			return "EMERGENCIAS"
		_:
			return str(m.get("category", "")).to_upper()


func _rebuild_beats(m: Dictionary, ok: bool) -> void:
	for c in beats_grid.get_children():
		c.queue_free()
	var beats: Array = m.get("beats", [])
	# Completar hasta 8 celdas narrativas si faltan
	var filled: Array = beats.duplicate()
	while filled.size() < 8:
		var n := filled.size() + 1
		var phase := "desarrollo"
		var t := "OPERACIÓN"
		var cap := "Unidad mantiene control del perímetro."
		if n <= 2:
			phase = "inicio"
			t = "PREPARACIÓN"
			cap = "Central confirma aviso y recursos."
		elif n >= 7:
			phase = "final"
			t = "CIERRE"
			cap = "Se archiva el parte."
		filled.append({
			"n": n,
			"title": t,
			"time": m.get("created_at", "00:00"),
			"caption": cap,
			"kind": phase,
		})
	for i in range(mini(8, filled.size())):
		beats_grid.add_child(_beat_card(filled[i], ok))
	# Celda 9: resumen
	beats_grid.add_child(_summary_card(m, ok))


func _beat_card(beat: Dictionary, _ok: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	pad.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var num := Label.new()
	num.text = "%02d" % int(beat.get("n", 1))
	num.add_theme_font_size_override("font_size", 16)
	num.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	head.add_child(num)
	var t := Label.new()
	t.text = str(beat.get("title", "")).to_upper()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 13)
	head.add_child(t)
	var tm := Label.new()
	tm.text = str(beat.get("time", ""))
	tm.add_theme_font_size_override("font_size", 11)
	tm.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	head.add_child(tm)
	var kind := Label.new()
	kind.text = str(beat.get("kind", "")).to_upper()
	kind.add_theme_font_size_override("font_size", 10)
	kind.add_theme_color_override("font_color", Color(0.7, 0.8, 0.92))
	col.add_child(kind)
	var cap := Label.new()
	cap.text = str(beat.get("caption", ""))
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", Color(0.85, 0.9, 0.96))
	col.add_child(cap)
	return panel


func _summary_card(m: Dictionary, ok: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.1) if not ok else Color(0.08, 0.14, 0.12)
	sb.border_color = Color(0.95, 0.25, 0.3) if not ok else Color(0.3, 0.85, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(pad)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.text = _summary_bbcode(m, ok)
	pad.add_child(rtl)
	return panel


func _summary_bbcode(m: Dictionary, ok: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("[b]09  BALANCE FINAL[/b]")
	if ok:
		lines.append("[color=#5be07a]✓ Objetivo principal[/color]")
		lines.append("[color=#5be07a]✓ Unidades sin bajas[/color]")
		lines.append("[color=#5be07a]✓ Evidencia asegurada[/color]")
	else:
		lines.append("[color=#ff5a5a]✗ Objetivo principal[/color]")
		lines.append("[color=#ff5a5a]✗ Sospechoso localizado[/color]")
		lines.append("[color=#5be07a]✓ Unidades sin bajas[/color]")
		lines.append("[color=#ffcc66]~ Evidencia parcial[/color]")
	lines.append("")
	lines.append("[color=#f0c45a]García Nv.%d — %d/%d XP[/color]" % [
		GameState.hero_level, GameState.hero_xp, GameState.xp_to_next_level()
	])
	if CombatState.combat_xp_gained > 0:
		lines.append("[color=#9ad0ff]+%d XP este combate (%d bajas)[/color]" % [
			CombatState.combat_xp_gained, CombatState.combat_kills
		])
	if GameState.pending_level_packs > 0:
		lines.append("[color=#ffd27a]¡Sobre de nivel pendiente! Elige cartas al cerrar.[/color]")
	lines.append("")
	lines.append(str(m.get("outcome_report", "")))
	return "\n".join(lines)


func _close() -> void:
	visible = false
	var mid := str(_mission.get("id", ""))
	if mid != "" and GameState.active_missions.has(mid):
		GameState.remove_mission(mid)
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()
