extends Node
## Estado global.

signal toast_changed(text: String)
signal wave_banner(text: String)

const MAX_HEALTH := 160.0
const DAY_LEN := 160.0
const BASE_CAPACITY := 12.0
const TILE_PX := 48.0

var time_of_day := 0.52 * DAY_LEN
var kills := 0
var dead := false
var death_reason := ""

var toast := ""
var toast_t := 0.0
var shake := 0.0
var noise_pulse := 0.0
var muzzle_flash := 0.0

var wave := 0
var wave_phase := "countdown"
var wave_timer := 16.0
var wave_quota := 0
var wave_spawned := 0

var weather_kind := "rain"
var weather_label := "Lluvia"
var weather_intensity := 0.55
var weather_next := 20.0
var thunder := 0.0

var build_mode := ""
var ambient := Color(1, 1, 1, 1)

func reset_run() -> void:
	time_of_day = 0.52 * DAY_LEN
	kills = 0
	dead = false
	death_reason = ""
	toast = ""
	toast_t = 0.0
	shake = 0.0
	noise_pulse = 0.0
	muzzle_flash = 0.0
	wave = 0
	wave_phase = "countdown"
	wave_timer = 16.0
	wave_quota = 0
	wave_spawned = 0
	weather_kind = "rain"
	weather_label = "Lluvia"
	weather_intensity = 0.55
	weather_next = 20.0
	thunder = 0.0
	build_mode = ""
	ambient = Color(1, 1, 1, 1)

func set_toast(msg: String, dur := 2.4) -> void:
	toast = msg
	toast_t = dur
	toast_changed.emit(msg)

func show_wave_banner(msg: String) -> void:
	wave_banner.emit(msg)

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)

func day_phase() -> Dictionary:
	var t := fmod(time_of_day, DAY_LEN) / DAY_LEN
	var phase := {}
	if t < 0.18:
		phase = {"name": "Amanecer", "light": 0.45 + t * 2.8, "night": false}
	elif t < 0.48:
		phase = {"name": "Día", "light": 1.0, "night": false}
	elif t < 0.6:
		phase = {"name": "Atardecer", "light": 0.78 - (t - 0.48) * 1.5, "night": false}
	elif t < 0.72:
		phase = {"name": "Anochecer", "light": 0.52 - (t - 0.6) * 1.2, "night": true}
	else:
		phase = {"name": "Noche", "light": 0.42, "night": true}
	match weather_kind:
		"cloudy": phase.light *= 0.94
		"rain": phase.light *= 0.88
		"storm": phase.light *= 0.78
	if thunder > 0.0:
		phase.light = minf(1.0, float(phase.light) + thunder * 0.85)
	phase.weather_label = weather_label
	phase.rain = weather_intensity
	phase.thunder = thunder
	return phase

func wave_status_text() -> String:
	match wave_phase:
		"countdown":
			var n := maxi(1, int(ceil(wave_timer)))
			return ("Oleada 1 en %ds" % n) if wave == 0 else ("Oleada %d en %ds" % [wave + 1, n])
		"spawning":
			return "Oleada %d: %d/%d" % [wave, wave_spawned, wave_quota]
		"fighting":
			return "Oleada %d en curso" % wave
		_:
			return "Oleada %d limpia" % wave

func tick(dt: float) -> void:
	if dead:
		return
	time_of_day += dt
	toast_t = maxf(0.0, toast_t - dt)
	if toast_t <= 0.0:
		toast = ""
	shake = maxf(0.0, shake - dt * 4.0)
	noise_pulse = maxf(0.0, noise_pulse - dt)
	muzzle_flash = maxf(0.0, muzzle_flash - dt)
	thunder = maxf(0.0, thunder - dt * 3.2)
	_tick_weather(dt)

func _tick_weather(dt: float) -> void:
	weather_next -= dt
	if weather_kind == "storm" and thunder <= 0.0 and randf() < dt * 0.35:
		thunder = 0.18 + randf() * 0.22
	var target := 0.0
	match weather_kind:
		"clear": target = 0.0
		"cloudy": target = 0.25
		"rain": target = 0.7
		"storm": target = 1.0
	weather_intensity = lerpf(weather_intensity, target, minf(1.0, dt * 1.4))
	if weather_next > 0.0:
		return
	weather_next = 18.0 + randf() * 28.0
	var night := (fmod(time_of_day, DAY_LEN) / DAY_LEN) >= 0.6
	var roll := randf()
	var next := weather_kind
	match weather_kind:
		"clear":
			next = "cloudy" if roll < (0.7 if night else 0.5) else "clear"
		"cloudy":
			if roll < (0.55 if night else 0.35): next = "rain"
			elif roll < 0.75: next = "cloudy"
			else: next = "clear"
		"rain":
			if roll < (0.55 if night else 0.3): next = "storm"
			elif roll < 0.7: next = "rain"
			else: next = "cloudy"
		_:
			next = "rain" if roll < 0.45 else "cloudy"
	weather_kind = next
	match next:
		"clear": weather_label = "Despejado"
		"cloudy": weather_label = "Nublado"
		"rain": weather_label = "Lluvia"
		"storm": weather_label = "Tormenta"
	if next == "storm":
		set_toast("La tormenta cae sobre Niebla Norte.")
	elif next == "rain":
		set_toast("Empieza a llover sobre el asfalto.")
