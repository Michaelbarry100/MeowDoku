class_name MeowAudio
extends Node
## One shared audio owner. Settings/storage remain in PlayerPreferences/PlayerSave.
signal sound_played(event: String, bus: String)
signal asset_missing(path: String)
signal preferences_changed

const MUSIC_PATH := "res://audio/music/bgm_cozy_piano.ogg"
const SOUNDS := {
	"ui": "res://audio/sfx/ui_soft_pop.wav",
	"select": "res://audio/sfx/ui_soft_pop.wav",
	"place": "res://audio/sfx/tile_place.wav",
	"mark": "res://audio/sfx/ui_soft_pop.wav",
	"erase": "res://audio/sfx/ui_soft_pop.wav",
	"invalid": "res://audio/sfx/invalid_move.wav",
	"hint": "res://audio/sfx/hint_chime.wav",
	"undo": "res://audio/sfx/ui_soft_pop.wav",
	"restart": "res://audio/sfx/tile_place.wav",
	"complete": "res://audio/sfx/level_complete.wav",
	"unlock": "res://audio/sfx/hint_chime.wav",
	"meow": "res://audio/cats/cat_meow_01.ogg",
	"purr": "res://audio/cats/cat_purr_loop.ogg",
	"chirp": "res://audio/cats/cat_happy_chirp.ogg",
}
const MAX_SFX := 6
const CAT_COOLDOWN := 4.0
var music: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var cat_player: AudioStreamPlayer
var streams: Dictionary = {}
var missing: Dictionary = {}
var last_event: Dictionary = {}
var music_enabled := true
var sfx_enabled := true
var music_volume := 0.65
var sfx_volume := 0.8
var master_muted := false
var music_wanted := false
var blockers: Dictionary = {}
var fade: Tween
var cat_until := 0.0
var last_cat := -100.0
var idle_countdown := 25.0
var cat_context: WeakRef
var rng := RandomNumberGenerator.new()
var played_counts: Dictionary = {}
var dropped := 0
var clock_override := -1.0 # Deterministic cooldown tests; normal playback uses monotonic time.

static func instance() -> MeowAudio:
	# Godot's custom --script SceneTree runners do not register autoload globals.
	# Resolve the same named owner and create it only when that runner omitted it.
	var tree := Engine.get_main_loop() as SceneTree
	var existing := tree.root.get_node_or_null("AudioManager") as MeowAudio
	if existing != null:
		return existing
	var service := MeowAudio.new()
	service.name = "AudioManager"
	tree.root.add_child(service)
	return service

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	music_wanted = false
	cat_context = null
	if fade:
		fade.kill()
	stop_one_shots()
	for voice in effects:
		voice.stream = null
	if music != null:
		music.stop()
		music.stream = null
	if cat_player != null:
		cat_player.stream = null
	streams.clear()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	ensure_buses()
	music = player("CozyMusic", "Music")
	for index in range(MAX_SFX):
		effects.append(player("OneShot%d" % index, "SFX"))
	cat_player = player("CatVoice", "Cat")
	# Read only: standalone scenes honor saved audio choices without initializing progression.
	var saved := PlayerSave.new(GameServices.default_save_path)
	saved.load_file()
	configure(saved.state.settings)
	get_tree().node_added.connect(watch_button)

func player(node_name: String, bus: String) -> AudioStreamPlayer:
	var result := AudioStreamPlayer.new()
	result.name = node_name
	result.bus = bus
	result.volume_db = -4.0
	add_child(result)
	return result

func ensure_buses() -> void:
	for bus in ["Music", "SFX", "Cat"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus), "Master")

func watch_button(node: Node) -> void:
	if node is BaseButton and not node is GridCell:
		# Cell audio follows the validated action, rather than duplicating the generic click.
		var callback := Callable(self, "ui_pressed")
		if not node.pressed.is_connected(callback):
			node.pressed.connect(callback)

func ui_pressed() -> void:
	play_sfx("ui")

func now() -> float:
	return clock_override if clock_override >= 0 else Time.get_ticks_msec() / 1000.0

func load_clip(path: String) -> AudioStream:
	if streams.has(path):
		return streams[path]
	if missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		missing[path] = true
		asset_missing.emit(path)
		push_warning("Audio asset unavailable; continuing without it: " + path)
		return null
	var clip := ResourceLoader.load(path) as AudioStream
	if clip == null or clip.get_length() <= 0.01:
		missing[path] = true
		asset_missing.emit(path)
		return null
	# Per-owner duplicate: never change importer/shared resource loop flags globally.
	clip = clip.duplicate()
	if clip is AudioStreamOggVorbis:
		clip.loop = path == MUSIC_PATH or path == SOUNDS.purr
	streams[path] = clip
	return clip

func configure(values: Dictionary) -> void:
	music_enabled = values.get("music_enabled", true) == true
	sfx_enabled = values.get("sfx_enabled", true) == true
	music_volume = safe_volume(values.get("music_volume", 0.65), 0.65)
	sfx_volume = safe_volume(values.get("sfx_volume", 0.8), 0.8)
	update_buses()
	if not sfx_enabled or sfx_volume == 0:
		stop_one_shots()
	refresh_music()
	preferences_changed.emit()

func safe_volume(value: Variant, fallback: float) -> float:
	return clampf(float(value), 0.0, 1.0) if (value is float or value is int) and is_finite(float(value)) else fallback

func update_buses() -> void:
	for spec in [["Music", music_volume, music_enabled], ["SFX", sfx_volume, sfx_enabled], ["Cat", sfx_volume, sfx_enabled]]:
		var index := AudioServer.get_bus_index(spec[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, spec[1])))
		AudioServer.set_bus_mute(index, master_muted or not blockers.is_empty() or not spec[2] or spec[1] == 0)

func set_music_enabled(enabled: bool, persist := true) -> Error:
	music_enabled = enabled
	return commit_preferences(persist)

func set_sfx_enabled(enabled: bool, persist := true) -> Error:
	sfx_enabled = enabled
	return commit_preferences(persist)

func set_music_volume(value: float, persist := true) -> Error:
	music_volume = safe_volume(value, 0.65)
	return commit_preferences(persist)

func set_sfx_volume(value: float, persist := true) -> Error:
	sfx_volume = safe_volume(value, 0.8)
	return commit_preferences(persist)

func commit_preferences(persist: bool) -> Error:
	PlayerPreferences.music_enabled = music_enabled
	PlayerPreferences.sfx_enabled = sfx_enabled
	PlayerPreferences.music_volume = music_volume
	PlayerPreferences.sfx_volume = sfx_volume
	configure(PlayerPreferences.audio_values())
	return PlayerPreferences.save_settings() if persist else OK

func set_muted(muted: bool) -> void:
	master_muted = muted
	if muted:
		stop_one_shots()
	update_buses()
	refresh_music()

func play_music(seconds := 0.8) -> bool:
	music_wanted = true
	return refresh_music(seconds)

func refresh_music(seconds := 0.25) -> bool:
	if music == null:
		return false
	if not music_wanted:
		if fade:
			fade.kill()
		music.stop()
		return false
	if not music_enabled or music_volume == 0 or master_muted or not blockers.is_empty():
		if fade:
			fade.kill()
		music.stream_paused = music.playing
		return false
	if music.playing:
		music.stream_paused = false
		if fade:
			fade.kill()
		fade = create_tween()
		fade.tween_property(music, "volume_db", -4.0, maxf(0.0, seconds))
		return true
	var clip := load_clip(MUSIC_PATH)
	if clip == null:
		return false
	if fade:
		fade.kill()
	music.stream = clip
	music.volume_db = -60.0
	music.stream_paused = false
	music.play()
	fade = create_tween()
	fade.tween_property(music, "volume_db", -4.0, maxf(0.0, seconds))
	return true

func stop_music(seconds := 0.5) -> void:
	music_wanted = false
	if fade:
		fade.kill()
	if seconds <= 0 or not music.playing or music.stream_paused:
		music.stop()
		return
	fade = create_tween()
	fade.tween_property(music, "volume_db", -60.0, seconds)
	fade.tween_callback(music.stop)

func available() -> bool:
	return sfx_enabled and sfx_volume > 0 and not master_muted and blockers.is_empty()

func play_sfx(event: String) -> bool:
	if not available() or not SOUNDS.has(event) or event in ["meow", "purr", "chirp"]:
		return false
	var interval := 0.07 if event in ["ui", "select", "place", "mark", "erase"] else 0.18
	if now() - float(last_event.get(event, -100.0)) < interval:
		dropped += 1
		return false
	var voice: AudioStreamPlayer
	var priority := 3 if event == "complete" else (2 if event in ["hint", "unlock"] else (1 if event == "invalid" else 0))
	for candidate in effects:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		# Critical feedback may replace a quiet UI tick; other bursts are dropped.
		for candidate in effects:
			if int(candidate.get_meta("priority", 0)) < priority and (voice == null or int(candidate.get_meta("priority", 0)) < int(voice.get_meta("priority", 0))):
				voice = candidate
		if voice == null:
			dropped += 1
			return false
		voice.stop()
	var clip := load_clip(SOUNDS[event])
	if clip == null:
		return false
	last_event[event] = now()
	voice.set_meta("priority", priority)
	voice.stream = clip
	voice.pitch_scale = rng.randf_range(0.98, 1.02) if event in ["ui", "select", "place", "mark", "erase"] else 1.0
	voice.play()
	announce(event, "SFX")
	return true

func play_cat(kind := "auto") -> bool:
	if not available() or now() - last_cat < CAT_COOLDOWN or cat_player.playing:
		return false
	if kind == "auto":
		kind = "meow" if rng.randf() < 0.6 else "chirp"
	if kind not in ["meow", "purr", "chirp"]:
		return false
	var clip := load_clip(SOUNDS[kind])
	if clip == null:
		return false
	cat_player.stream = clip
	cat_player.pitch_scale = 1.0 if kind == "purr" else rng.randf_range(0.96, 1.04)
	cat_player.volume_db = -10 if kind == "purr" else -6
	cat_player.play()
	last_cat = now()
	cat_until = now() + 3.0 if kind == "purr" else 0.0
	announce(kind, "Cat")
	return true

func announce(event: String, bus: String) -> void:
	played_counts[event] = int(played_counts.get(event, 0)) + 1
	sound_played.emit(event, bus)

func set_cat_context(owner: Node) -> void:
	cat_context = weakref(owner) if owner != null else null
	idle_countdown = rng.randf_range(22.0, 38.0)
	if owner == null:
		cat_player.stop()

func stop_one_shots() -> void:
	for voice in effects:
		voice.stop()
	if cat_player != null:
		cat_player.stop()
	cat_until = 0

func set_interrupted(reason: String, interrupted: bool) -> void:
	if interrupted:
		blockers[reason] = true
		stop_one_shots()
	else:
		blockers.erase(reason)
	update_buses()
	refresh_music()

func _process(delta: float) -> void:
	if cat_until > 0 and now() >= cat_until:
		cat_player.stop()
		cat_until = 0
	if not available() or cat_context == null:
		return
	var owner: Node = cat_context.get_ref()
	if owner == null:
		cat_context = null
		return
	if owner is CanvasItem and not owner.is_visible_in_tree():
		return
	if owner.get("suspended") == true or owner.get("paused") == true:
		return
	idle_countdown -= delta
	if idle_countdown <= 0:
		idle_countdown = rng.randf_range(25.0, 45.0)
		if owner.has_method("audio_has_cats") and owner.audio_has_cats():
			play_cat("purr")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_interrupted("background", true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		set_interrupted("background", false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_interrupted("focus", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_interrupted("focus", false)
