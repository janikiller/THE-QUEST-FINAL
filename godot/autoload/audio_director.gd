extends Node
## Música de comisaría / combate + ambiente (lluvia / noche) + SFX.

signal music_toggled(on: bool)

const MUSIC_HQ := "res://assets/audio/music/comisaria_theme_loop.ogg"
const MUSIC_COMBAT := "res://assets/audio/music/combat_theme_loop.ogg"
const NIGHT := "res://assets/audio/ambience/urban_night_loop.ogg"
const RAIN_LIGHT := "res://assets/audio/ambience/rain_light_loop.ogg"
const RAIN_MED := "res://assets/audio/ambience/rain_medium_loop.ogg"
const RAIN_HEAVY := "res://assets/audio/ambience/rain_heavy_loop.ogg"
const THUNDER := "res://assets/audio/sfx/thunder_close.ogg"
const SFX_SHOTGUN := "res://assets/audio/sfx/shotgun_shot.ogg"
const SFX_PISTOL := "res://assets/audio/sfx/pistol_shot.ogg"
const SFX_SHIELD := "res://assets/audio/sfx/shield_deploy.ogg"
const SFX_HIT := "res://assets/audio/sfx/hit_impact.ogg"

var music_on: bool = true
var ambience_on: bool = true

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _thunder_cd: float = 0.0
var _in_combat: bool = false
var _hq_vol_db: float = -14.0
var _combat_vol_db: float = -10.0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Master"
	_music.volume_db = _hq_vol_db
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.volume_db = -18.0
	add_child(_ambience)
	_rain = AudioStreamPlayer.new()
	_rain.name = "Rain"
	_rain.volume_db = -8.0
	add_child(_rain)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool%d" % i
		p.volume_db = -4.0
		add_child(p)
		_sfx_pool.append(p)
	_load_stream(_music, MUSIC_HQ, true)
	_load_stream(_ambience, NIGHT, true)
	_load_stream(_rain, RAIN_MED, true)
	if music_on and ResourceLoader.exists(MUSIC_HQ):
		_music.play()
	GameState.weather_changed.connect(_on_weather)
	GameState.time_changed.connect(_on_time)
	_on_weather(GameState.weather)
	_on_time("%02d:%02d" % [GameState.hour, GameState.minute])


func _process(delta: float) -> void:
	_thunder_cd = maxf(0.0, _thunder_cd - delta)
	if GameState.weather == "storm" and _thunder_cd <= 0.0 and ambience_on and not _in_combat:
		if GameState._rng.randf() < 0.015:
			_play_thunder()
			_thunder_cd = GameState._rng.randf_range(6.0, 16.0)


func _load_stream(player: AudioStreamPlayer, path: String, loop: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	player.stream = stream


func toggle_music() -> void:
	music_on = not music_on
	if music_on:
		if _music.stream and not _music.playing:
			_music.play()
	else:
		_music.stop()
	music_toggled.emit(music_on)


func set_music_volume_db(db: float) -> void:
	if _in_combat:
		_combat_vol_db = db
	else:
		_hq_vol_db = db
	_music.volume_db = db


func enter_combat() -> void:
	_in_combat = true
	if not music_on:
		return
	_swap_music(MUSIC_COMBAT, _combat_vol_db)
	# Baja ambiente un poco para que se oiga la acción
	if _ambience.playing:
		_ambience.volume_db = minf(_ambience.volume_db, -26.0)
	if _rain.playing:
		_rain.volume_db = minf(_rain.volume_db, -14.0)


func exit_combat() -> void:
	_in_combat = false
	if music_on:
		_swap_music(MUSIC_HQ, _hq_vol_db)
	_on_weather(GameState.weather)
	_on_time("%02d:%02d" % [GameState.hour, GameState.minute])


func play_sfx(path: String, volume_db: float = -4.0, pitch: float = 1.0) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var player := _next_sfx_player()
	player.stop()
	player.stream = load(path)
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.7, 1.35)
	player.play()


func play_shotgun(pitch: float = 1.0) -> void:
	play_sfx(SFX_SHOTGUN, -2.0, pitch)


func play_pistol(pitch: float = 1.0) -> void:
	play_sfx(SFX_PISTOL, -3.0, pitch)


func play_gunshot(card_id: String = "", def: Dictionary = {}) -> void:
	# Disparos de combate: escopeta (con pitch según tipo de carta)
	var cid := card_id
	var art := str(def.get("art", ""))
	var pitch := 1.0
	if cid == "burst" or art.find("rifle") >= 0:
		pitch = 1.1
	elif cid in ["strike"] or art.find("pistol") >= 0:
		pitch = 1.14
	elif cid in ["impact", "breach"] or art.find("shotgun") >= 0:
		pitch = 0.96
	play_shotgun(pitch)


func play_shield() -> void:
	play_sfx(SFX_SHIELD, -3.5, 1.0)


func play_hit() -> void:
	play_sfx(SFX_HIT, -5.0, 1.0)


func _next_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# Todos ocupados: reutiliza el primero
	return _sfx_pool[0] if not _sfx_pool.is_empty() else _sfx


func _swap_music(path: String, vol: float) -> void:
	if not ResourceLoader.exists(path):
		return
	if _music.playing:
		_music.stop()
	_load_stream(_music, path, true)
	_music.volume_db = vol
	if music_on:
		_music.play()


func _on_time(_label: String) -> void:
	var tod := GameState.time_of_day()
	if not ambience_on:
		_ambience.stop()
		return
	if tod == "night" or tod == "dusk":
		if _ambience.stream and not _ambience.playing:
			_ambience.play()
		_ambience.volume_db = (-20.0 if _in_combat else -16.0) if tod == "night" else (-24.0 if _in_combat else -22.0)
	else:
		# Día: ambiente más bajo
		if _ambience.playing:
			_ambience.volume_db = -30.0 if _in_combat else -28.0


func _on_weather(weather: String) -> void:
	if not ambience_on:
		_rain.stop()
		return
	match weather:
		"clear":
			_rain.stop()
		"drizzle":
			_swap_rain(RAIN_LIGHT, -16.0 if _in_combat else -12.0)
		"rain":
			_swap_rain(RAIN_MED, -12.0 if _in_combat else -8.0)
		"storm":
			_swap_rain(RAIN_HEAVY, -8.0 if _in_combat else -4.0)
		"sandstorm":
			# Sin lluvia: ambiente nocturno más alto como viento seco
			_rain.stop()
			if _ambience.stream and not _ambience.playing:
				_ambience.play()
			_ambience.volume_db = -18.0 if _in_combat else -14.0
		_:
			_rain.stop()


func _swap_rain(path: String, vol: float) -> void:
	var was := _rain.playing
	_load_stream(_rain, path, true)
	_rain.volume_db = vol
	if not was:
		_rain.play()
	elif not _rain.playing:
		_rain.play()


func _play_thunder() -> void:
	if not ResourceLoader.exists(THUNDER):
		return
	play_sfx(THUNDER, -6.0, 1.0)
	GameState.request_lightning_flash()
