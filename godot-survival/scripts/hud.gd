extends CanvasLayer
class_name HUD

@onready var root_ui: Control = $Root
@onready var toast_label: Label = $Root/Toast
@onready var top_label: Label = $Root/Top
@onready var bars_label: Label = $Root/Bars
@onready var hotbar_label: Label = $Root/Hotbar
@onready var equip_label: Label = $Root/Equip
@onready var banner_label: Label = $Root/Banner
@onready var death_panel: ColorRect = $Root/Death
@onready var death_label: Label = $Root/Death/Reason
@onready var restart_btn: Button = $Root/Death/Restart

var player: Player

func _ready() -> void:
	GameState.toast_changed.connect(_on_toast)
	GameState.wave_banner.connect(_on_banner)
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	death_panel.visible = false
	banner_label.visible = false

func setup(p: Player) -> void:
	player = p
	player.inventory_changed.connect(_refresh)
	player.died.connect(_on_death)
	_refresh()

func _process(_dt: float) -> void:
	# Compensa CanvasModulate para que el HUD se lea de noche.
	var a := GameState.ambient
	root_ui.modulate = Color(1.0 / maxf(a.r, 0.25), 1.0 / maxf(a.g, 0.25), 1.0 / maxf(a.b, 0.25), 1.0)
	if player:
		_refresh()
	toast_label.visible = GameState.toast_t > 0.0 and GameState.toast != ""

func _refresh() -> void:
	if player == null: return
	var phase := GameState.day_phase()
	top_label.text = "%s · %s · Niebla Norte\n%d bajas · %s" % [phase.name, phase.weather_label, GameState.kills, GameState.wave_status_text()]
	bars_label.text = "Vida %d/%d\nHambre %d\nSed %d\nFuerza %d\nCarga %.1f/%.0f" % [
		int(player.health), int(player.max_health), int(player.hunger), int(player.thirst), int(player.stamina),
		player.inv_used(), player.inv_capacity()]
	var lines: PackedStringArray = []
	for s in player.hotbar():
		if s.empty: lines.append("%d ·" % (s.index + 1))
		else:
			var ammo := (" %d" % s.ammo) if s.ammo != null else ""
			lines.append("%s%d %s %s%s" % [">" if s.active else " ", s.index + 1, s.icon, s.label, ammo])
	hotbar_label.text = "\n".join(lines)
	equip_label.text = "Primaria: %s\nRopa: %s\nMochila: %s\nLuz: %s\n%s" % [
		ItemDB.label_of(str(player.equip.hand)) if player.equip.hand else "—",
		ItemDB.label_of(str(player.equip.body)) if player.equip.body else "—",
		ItemDB.label_of(str(player.equip.bag)) if player.equip.bag else "—",
		ItemDB.label_of(str(player.equip.light)) if player.equip.light else "—",
		("Build: " + GameState.build_mode) if GameState.build_mode != "" else "B construir · T equipo · Enter coloca"]

func _on_toast(text: String) -> void:
	toast_label.text = text

func _on_banner(text: String) -> void:
	banner_label.text = text; banner_label.visible = true
	get_tree().create_timer(2.2).timeout.connect(func(): banner_label.visible = false)

func _on_death(reason: String) -> void:
	death_panel.visible = true; death_label.text = reason
