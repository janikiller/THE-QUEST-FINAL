extends Node
## Música de comisaría + ambiente (lluvia / noche).

signal music_toggled(on: bool)

const MUSIC := "res://assets/audio/music/comisaria_theme_loop.ogg"
const NIGHT := "res://assets/audio/ambience/urban_night_loop.ogg"
const RAIN_LIGHT := "res://assets/audio/ambience/rain_light_loop.ogg"
const RAIN_MED := "res://assets/audio/ambience/rain_medium_loop.ogg"
const RAIN_HEAVY := "res://assets/audio/ambience/rain_heavy_loop.ogg"
const THUNDER := "res://assets/audio/sfx/thunder_close.ogg"

var music_on: bool = true
var ambience_on: bool = true

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _thunder_cd: float = 0.0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Master"
	_music.volume_db = -14.0
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
	_load_stream(_music, MUSIC, true)
	_load_stream(_ambience, NIGHT, true)
	_load_stream(_rain, RAIN_MED, true)
	if music_on and ResourceLoader.exists(MUSIC):
		_music.play()
	GameState.weather_changed.connect(_on_weather)
	GameState.time_changed.connect(_on_time)
	_on_weather(GameState.weather)
	_on_time("%02d:%02d" % [GameState.hour, GameState.minute])


func _process(delta: float) -> void:
	_thunder_cd = maxf(0.0, _thunder_cd - delta)
	if GameState.weather == "storm" and _thunder_cd <= 0.0 and ambience_on:
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
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
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
	_music.volume_db = db


func _on_time(_label: String) -> void:
	var tod := GameState.time_of_day()
	if not ambience_on:
		_ambience.stop()
		return
	if tod == "night" or tod == "dusk":
		if _ambience.stream and not _ambience.playing:
			_ambience.play()
		_ambience.volume_db = -16.0 if tod == "night" else -22.0
	else:
		# Día: ambiente más bajo
		if _ambience.playing:
			_ambience.volume_db = -28.0


func _on_weather(weather: String) -> void:
	if not ambience_on:
		_rain.stop()
		return
	match weather:
		"clear":
			_rain.stop()
		"drizzle":
			_swap_rain(RAIN_LIGHT, -12.0)
		"rain":
			_swap_rain(RAIN_MED, -8.0)
		"storm":
			_swap_rain(RAIN_HEAVY, -4.0)
		"sandstorm":
			# Sin lluvia: ambiente nocturno más alto como viento seco
			_rain.stop()
			if _ambience.stream and not _ambience.playing:
				_ambience.play()
			_ambience.volume_db = -14.0
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
	_sfx.stream = load(THUNDER)
	_sfx.play()
	# Visual cue via GameState
	GameState.request_lightning_flash()
