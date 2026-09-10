extends Node
## Música HQ + combate, ambiente (lluvia / noche) y SFX de combate/UI.

signal music_toggled(on: bool)

const MUSIC := "res://assets/audio/music/comisaria_theme_loop.ogg"
const COMBAT_MUSIC := "res://assets/audio/music/combat_tension_loop.ogg"
const NIGHT := "res://assets/audio/ambience/urban_night_loop.ogg"
const RAIN_LIGHT := "res://assets/audio/ambience/rain_light_loop.ogg"
const RAIN_MED := "res://assets/audio/ambience/rain_medium_loop.ogg"
const RAIN_HEAVY := "res://assets/audio/ambience/rain_heavy_loop.ogg"
const THUNDER := "res://assets/audio/sfx/thunder_close.ogg"

const SFX := {
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"card_play": "res://assets/audio/sfx/card_play.ogg",
	"gunshot": "res://assets/audio/sfx/gunshot.ogg",
	"punch": "res://assets/audio/sfx/punch.ogg",
	"hit_impact": "res://assets/audio/sfx/hit_impact.ogg",
	"block": "res://assets/audio/sfx/block.ogg",
	"foot_plant": "res://assets/audio/sfx/foot_plant.ogg",
	"death_thud": "res://assets/audio/sfx/death_thud.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
	"turn_end": "res://assets/audio/sfx/turn_end.ogg",
	"whoosh": "res://assets/audio/sfx/whoosh.ogg",
	"thunder": THUNDER,
}

var music_on: bool = true
var ambience_on: bool = true
var sfx_on: bool = true

var _music: AudioStreamPlayer
var _combat_music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _thunder_cd: float = 0.0
var _in_combat: bool = false
var _hq_music_db: float = -14.0
var _cache: Dictionary = {}


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Master"
	_music.volume_db = _hq_music_db
	add_child(_music)
	_combat_music = AudioStreamPlayer.new()
	_combat_music.name = "CombatMusic"
	_combat_music.bus = "Master"
	_combat_music.volume_db = -11.0
	add_child(_combat_music)
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
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool%d" % i
		p.volume_db = -5.0
		add_child(p)
		_sfx_pool.append(p)
	_load_stream(_music, MUSIC, true)
	_load_stream(_combat_music, COMBAT_MUSIC, true)
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
	if GameState.weather == "storm" and _thunder_cd <= 0.0 and ambience_on and not _in_combat:
		if GameState._rng.randf() < 0.015:
			_play_thunder()
			_thunder_cd = GameState._rng.randf_range(6.0, 16.0)


func _load_stream(player: AudioStreamPlayer, path: String, loop: bool) -> void:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		)
	player.stream = stream


func _stream(path: String) -> AudioStream:
	if path == "" or (not ResourceLoader.exists(path) and not FileAccess.file_exists(path)):
		return null
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = load(path)
	if stream:
		_cache[path] = stream
	return stream


func toggle_music() -> void:
	music_on = not music_on
	if music_on:
		if _in_combat:
			if _combat_music.stream and not _combat_music.playing:
				_combat_music.play()
		elif _music.stream and not _music.playing:
			_music.play()
	else:
		_music.stop()
		_combat_music.stop()
	music_toggled.emit(music_on)


func set_music_volume_db(db: float) -> void:
	_hq_music_db = db
	if not _in_combat:
		_music.volume_db = db


func play_sfx(id: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx_on:
		return
	var path := str(SFX.get(id, ""))
	if path == "":
		return
	var stream := _stream(path)
	if stream == null:
		return
	var player := _free_sfx_player()
	player.stream = stream
	player.pitch_scale = clampf(pitch_scale, 0.7, 1.4)
	player.volume_db = -5.0 + volume_db
	player.play()


func play_ui_click() -> void:
	play_sfx("ui_click", randf_range(0.95, 1.08), -2.0)


func start_combat_music() -> void:
	_in_combat = true
	if not music_on:
		return
	# Baja la comisaría y sube tensión de combate
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 0.45)
	tw.tween_callback(func() -> void:
		if _music.playing:
			_music.stop()
	)
	if _combat_music.stream == null:
		_load_stream(_combat_music, COMBAT_MUSIC, true)
	if _combat_music.stream and music_on:
		_combat_music.volume_db = -28.0
		if not _combat_music.playing:
			_combat_music.play()
		var tw2 := create_tween()
		tw2.tween_property(_combat_music, "volume_db", -11.0, 0.55)


func is_in_combat() -> bool:
	return _in_combat


func stop_combat_music(victory: bool = true, play_sting: bool = true) -> void:
	var was := _in_combat
	_in_combat = false
	if _combat_music.playing:
		var tw := create_tween()
		tw.tween_property(_combat_music, "volume_db", -40.0, 0.4)
		tw.tween_callback(func() -> void:
			_combat_music.stop()
		)
	if was and play_sting:
		play_sfx("victory" if victory else "defeat", 1.0, -1.0)
	if music_on and _music.stream:
		_music.volume_db = -32.0
		if not _music.playing:
			_music.play()
		var tw2 := create_tween()
		tw2.tween_property(_music, "volume_db", _hq_music_db, 0.8)


func _free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# Steal first if all busy
	return _sfx_pool[0]


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
	play_sfx("thunder", randf_range(0.9, 1.05), -1.0)
	GameState.request_lightning_flash()
