extends Control
## Pantalla de mazo: cartas de García + catálogo de cartas enemigas (mismo menú grande).

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
## "mazo" = cartas del jugador · "enemigas" = catálogo enemigo
var _mode: String = "mazo"
## En modo enemigas: "todas" | role id | "boss:<id>"
var _enemy_scope: String = "todas"
var _mode_row: HBoxContainer
var _left_title: Label


func _ready() -> void:
	btn_close.pressed.connect(close)
	_ensure_mode_row()
	_left_title = get_node_or_null("Root/Cols/Left/LeftTitle") as Label
	visibility_changed.connect(func():
		if visible:
			_rebuild_all()
	)


func open(patrol_id: String = "", mode: String = "") -> void:
	visible = true
	if mode == "enemigas" or mode == "mazo":
		_mode = mode
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


func _ensure_mode_row() -> void:
	if _mode_row != null and is_instance_valid(_mode_row):
		return
	var main := get_node_or_null("Root/Cols/Main") as VBoxContainer
	if main == null:
		return
	_mode_row = HBoxContainer.new()
	_mode_row.name = "ModeRow"
	_mode_row.add_theme_constant_override("separation", 8)
	# Insertar tras el Header (índice 0)
	main.add_child(_mode_row)
	main.move_child(_mode_row, 1)


func _rebuild_all() -> void:
	_ensure_mode_row()
	_rebuild_mode_tabs()
	_rebuild_side()
	_rebuild_filters()
	_rebuild_cards()
	_refresh_header()


func _rebuild_mode_tabs() -> void:
	if _mode_row == null:
		return
	for c in _mode_row.get_children():
		c.queue_free()
	for entry in [
		{"id": "mazo", "label": "TU MAZO", "hint": "Cartas de Kick-Ass"},
		{"id": "enemigas", "label": "ENEMIGAS", "hint": "Cartas de los sospechosos"},
	]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = str(entry.id) == _mode
		b.text = "%s\n%s" % [entry.label, entry.hint]
		b.custom_minimum_size = Vector2(168, 48)
		b.focus_mode = Control.FOCUS_NONE
		var accent := Color(0.25, 0.85, 1.0) if entry.id == "mazo" else Color(1.0, 0.48, 0.32)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent.r * 0.2, accent.g * 0.18, accent.b * 0.22, 0.95) if b.button_pressed else Color(0.06, 0.09, 0.14, 0.92)
		sb.border_color = accent
		sb.set_border_width_all(2 if b.button_pressed else 1)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_font_size_override("font_size", 12)
		var mid := str(entry.id)
		b.pressed.connect(func():
			if _mode == mid:
				return
			_mode = mid
			_filter = "todos"
			_selected_card_id = ""
			if _mode == "enemigas" and _enemy_scope == "":
				_enemy_scope = "todas"
			_rebuild_all()
		)
		_mode_row.add_child(b)


func _refresh_header() -> void:
	if _mode == "enemigas":
		title.text = "CARTAS ENEMIGAS"
		sub.text = "Catálogo de intents · mismas cartas que usan en combate"
		count_label.text = "%d cartas" % _enemy_ids_for_scope().size()
		if _left_title:
			_left_title.text = "MAZOS ENEMIGOS"
	else:
		var p: Dictionary = GameState.patrols.get(selected_patrol_id, {})
		title.text = "MAZO  ·  %s" % str(p.get("callsign", "UNIDAD"))
		sub.text = "%s — cartas del enfrentamiento táctico" % str(p.get("name", "Patrulla"))
		var deck: Array = GameState.get_patrol_deck(selected_patrol_id)
		count_label.text = "%d cartas en el mazo" % deck.size()
		if _left_title:
			_left_title.text = "PROTAGONISTA"


func _rebuild_side() -> void:
	for c in patrol_list.get_children():
		c.queue_free()
	if _mode == "enemigas":
		_rebuild_enemy_scopes()
	else:
		_rebuild_patrols()


func _rebuild_patrols() -> void:
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
		p.get("name", "Kick-Ass"),
		p.get("callsign", "KICK-ASS"),
		GameState.get_patrol_deck(selected_patrol_id).size(),
	]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 13)
	v.add_child(name_l)
	var tip := Label.new()
	tip.text = "Protagonista único\nPestaña ENEMIGAS →\nver sus cartas"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.6, 0.78, 0.95))
	v.add_child(tip)
	patrol_list.add_child(panel)


func _rebuild_enemy_scopes() -> void:
	var scopes: Array = [{"id": "todas", "label": "TODAS", "sub": "%d cartas" % CardDB.enemy_cards.size()}]
	for role in CardDB.enemy_role_pools.keys():
		var pool: Array = CardDB.enemy_role_pools[role]
		scopes.append({
			"id": "role:%s" % role,
			"label": str(role).to_upper(),
			"sub": "rol · %d" % pool.size(),
		})
	for boss_id in CardDB.enemy_boss_pools.keys():
		if str(boss_id) == "default":
			continue
		var bpool: Array = CardDB.enemy_boss_pools[boss_id]
		scopes.append({
			"id": "boss:%s" % boss_id,
			"label": str(boss_id).replace("boss_", "").replace("_", " ").to_upper(),
			"sub": "jefe · %d" % bpool.size(),
		})
	for entry in scopes:
		var sid := str(entry.id)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = sid == _enemy_scope
		b.text = "%s\n%s" % [entry.label, entry.sub]
		b.custom_minimum_size = Vector2(0, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var accent := Color(1.0, 0.48, 0.32) if b.button_pressed else Color(0.55, 0.62, 0.72)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.07, 0.08, 0.95) if b.button_pressed else Color(0.06, 0.08, 0.12, 0.9)
		sb.border_color = accent
		sb.set_border_width_all(2 if b.button_pressed else 1)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(func():
			_enemy_scope = sid
			_selected_card_id = ""
			_rebuild_all()
		)
		patrol_list.add_child(b)


func _rebuild_filters() -> void:
	for c in filter_row.get_children():
		c.queue_free()
	var filters: Array = []
	if _mode == "enemigas":
		filters = [
			{"id": "todos", "label": "Todas"},
			{"id": "attack", "label": "Ataque"},
			{"id": "block", "label": "Defensa"},
			{"id": "heal", "label": "Cura"},
			{"id": "flee", "label": "Huida"},
			{"id": "status", "label": "Estado"},
			{"id": "boss", "label": "Jefe"},
		]
	else:
		for t in CardDB.types:
			filters.append({"id": str(t.get("id", "todos")), "label": str(t.get("label", ""))})
	for t in filters:
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


func _enemy_ids_for_scope() -> Array:
	var ids: Array = []
	if _enemy_scope == "todas" or _enemy_scope == "":
		for cid in CardDB.enemy_cards.keys():
			ids.append(str(cid))
	elif _enemy_scope.begins_with("role:"):
		var role := _enemy_scope.substr(5)
		ids = CardDB.enemy_pool_for_role(role)
	elif _enemy_scope.begins_with("boss:"):
		var bid := _enemy_scope.substr(5)
		ids = CardDB.enemy_pool_for_boss(bid)
	# unique
	var seen: Dictionary = {}
	var out: Array = []
	for cid in ids:
		var s := str(cid)
		if seen.has(s):
			continue
		seen[s] = true
		out.append(s)
	out.sort()
	return out


func _enemy_kind_filter_ok(def: Dictionary) -> bool:
	if _filter == "todos":
		return true
	var kind := CardDB.enemy_card_intent_kind(def)
	var cid := str(def.get("id", ""))
	match _filter:
		"attack", "block", "heal", "flee":
			return kind == _filter
		"status":
			return kind in ["weaken", "vulnerable", "stun", "status"] or int(def.get("weaken", 0)) > 0 or int(def.get("vulnerable", 0)) > 0 or int(def.get("stun", 0)) > 0
		"boss":
			return cid.begins_with("boss_")
		_:
			return true


func _rebuild_cards() -> void:
	for c in cards_grid.get_children():
		c.queue_free()
	if _mode == "enemigas":
		_rebuild_enemy_cards()
	else:
		_rebuild_player_cards()


func _rebuild_player_cards() -> void:
	var deck: Array = GameState.get_patrol_deck(selected_patrol_id)
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
		var card := _make_card_widget(def, int(counts[cid]), false)
		cards_grid.add_child(card)
		shown += 1
	if shown == 0:
		_add_empty_label("Sin cartas en este filtro.")
	if _selected_card_id == "" or not counts.has(_selected_card_id):
		if not counts.is_empty():
			_select_card(str(counts.keys()[0]))
		else:
			_clear_detail()
	else:
		_select_card(_selected_card_id)


func _rebuild_enemy_cards() -> void:
	var ids := _enemy_ids_for_scope()
	var shown := 0
	var first := ""
	for cid in ids:
		var def: Dictionary = CardDB.get_enemy_card(str(cid))
		if def.is_empty():
			continue
		if not _enemy_kind_filter_ok(def):
			continue
		if first == "":
			first = str(cid)
		var card := _make_card_widget(def, 1, true)
		cards_grid.add_child(card)
		shown += 1
	if shown == 0:
		_add_empty_label("Sin cartas enemigas en este filtro.")
	if _selected_card_id == "" or CardDB.get_enemy_card(_selected_card_id).is_empty():
		if first != "":
			_select_card(first)
		else:
			_clear_detail()
	else:
		_select_card(_selected_card_id)


func _add_empty_label(txt: String) -> void:
	var empty := Label.new()
	empty.text = txt
	empty.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	cards_grid.add_child(empty)


func _make_card_widget(def: Dictionary, copies: int, enemy: bool) -> Control:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(168, 236)
	var rarity := "fuerza" if enemy and str(def.get("id", "")).begins_with("boss_") else ("basica" if enemy else CardDB.normalize_rarity(str(def.get("rarity", "basica"))))
	if enemy:
		var kind := CardDB.enemy_card_intent_kind(def)
		match kind:
			"block", "heal":
				rarity = "magica"
			"flee", "weaken", "vulnerable", "stun", "status":
				rarity = "basica"
			_:
				rarity = "fuerza" if str(def.get("id", "")).begins_with("boss_") else "basica"
	var accent := Color(1.0, 0.48, 0.32) if enemy else CardDB.rarity_color(rarity)
	if enemy:
		match CardDB.enemy_card_intent_kind(def):
			"block":
				accent = Color(0.42, 0.82, 1.0)
			"heal":
				accent = Color(0.45, 0.9, 0.55)
			"flee":
				accent = Color(1.0, 0.78, 0.35)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.06, 0.98) if enemy else Color(0.05, 0.08, 0.14, 0.98)
	sb.border_color = accent
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
	if enemy:
		var kind := CardDB.enemy_card_intent_kind(def)
		match kind:
			"block":
				cost.text = "◈"
			"heal":
				cost.text = "+"
			"flee":
				cost.text = "→"
			_:
				cost.text = "●"
	else:
		cost.text = str(int(def.get("cost", 0)))
	cost.add_theme_font_size_override("font_size", 18)
	cost.add_theme_color_override("font_color", accent if enemy else Color(0.95, 0.9, 0.55))
	top.add_child(cost)
	var type_l := Label.new()
	if enemy:
		type_l.text = "ENEMIGA · %s" % CardDB.enemy_card_intent_kind(def).to_upper()
	else:
		type_l.text = "%s · %s" % [CardDB.rarity_label(rarity), str(def.get("type", "")).to_upper()]
	type_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_l.add_theme_font_size_override("font_size", 9)
	type_l.add_theme_color_override("font_color", accent)
	top.add_child(type_l)

	var art_wrap := Control.new()
	art_wrap.custom_minimum_size = Vector2(0, 96)
	v.add_child(art_wrap)
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(accent.r, accent.g, accent.b, 0.35)
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
	effect.text = CardDB.enemy_effect_line(def) if enemy else CardDB.effect_line(def)
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
	var def: Dictionary = CardDB.get_any_card(card_id)
	if def.is_empty():
		_clear_detail()
		return
	var enemy := _mode == "enemigas" or (CardDB.get_card(card_id).is_empty() and not CardDB.get_enemy_card(card_id).is_empty())
	detail_name.text = str(def.get("name", ""))
	if enemy:
		var kind := CardDB.enemy_card_intent_kind(def)
		detail_meta.text = "ENEMIGA  ·  %s  ·  %s" % [kind.to_upper(), str(def.get("id", ""))]
		detail_meta.add_theme_color_override("font_color", Color(1.0, 0.55, 0.38))
		detail_effect.text = "[b]%s[/b]" % CardDB.enemy_effect_line(def)
	else:
		detail_meta.text = "Coste %s  ·  %s  ·  %s" % [
			str(def.get("cost", 0)),
			str(def.get("type", "")).to_upper(),
			CardDB.rarity_label(str(def.get("rarity", "basica"))),
		]
		detail_meta.add_theme_color_override("font_color", CardDB.rarity_color(str(def.get("rarity", "basica"))))
		detail_effect.text = "[b]%s[/b]" % CardDB.effect_line(def)
	var art_path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(art_path):
		detail_art.texture = load(art_path)
	elif FileAccess.file_exists(art_path):
		var dimg := Image.load_from_file(art_path)
		detail_art.texture = ImageTexture.create_from_image(dimg) if dimg else null
	else:
		detail_art.texture = null
	detail_desc.text = str(def.get("description", CardDB.flavor_line(def)))


func _clear_detail() -> void:
	detail_name.text = "Selecciona una carta"
	detail_meta.text = ""
	detail_art.texture = null
	detail_effect.text = ""
	detail_desc.text = ""
