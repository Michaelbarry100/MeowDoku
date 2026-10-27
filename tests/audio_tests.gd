extends SceneTree
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(4):
		await process_frame

func reset_effects() -> void:
	MeowAudio.instance().stop_one_shots()
	MeowAudio.instance().last_event.clear()
	MeowAudio.instance().last_cat = -100

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("audio")
	MeowAudio.instance().blockers.clear()
	MeowAudio.instance().set_muted(false)
	MeowAudio.instance().configure({})
	MeowAudio.instance().clock_override = 100
	check(MeowAudio.instance().music_enabled and MeowAudio.instance().sfx_enabled, "First-launch music and SFX enabled")
	for bus in ["Music", "SFX", "Cat"]:
		var index := AudioServer.get_bus_index(bus)
		check(index >= 0 and AudioServer.get_bus_send(index) == "Master", bus + " routed to Master")
	var paths: Array = MeowAudio.instance().SOUNDS.values()
	paths.append(MeowAudio.instance().MUSIC_PATH)
	for path in paths:
		var clip: AudioStream = MeowAudio.instance().load_clip(path)
		check(clip != null and clip.get_length() > 0.05, "Actual nonempty imported audio: " + path.get_file())
	check(MeowAudio.instance().load_clip(MeowAudio.instance().MUSIC_PATH).loop, "Music loops")
	check(MeowAudio.instance().load_clip(MeowAudio.instance().SOUNDS.purr).loop, "Purr source loops for bounded playback")
	check(not MeowAudio.instance().load_clip(MeowAudio.instance().SOUNDS.meow).loop, "Meow is one-shot")
	var unavailable := "res://audio/does_not_exist.ogg"
	check(MeowAudio.instance().load_clip(unavailable) == null and MeowAudio.instance().load_clip(unavailable) == null, "Missing asset cached safely without fake playback")
	check(MeowAudio.instance().missing.has(unavailable), "Missing-file diagnostics retained")
	check(not MeowAudio.instance().play_sfx("unknown"), "Unknown event fails safely")
	var original_music: AudioStream = MeowAudio.instance().streams[MeowAudio.instance().MUSIC_PATH]
	MeowAudio.instance().streams[MeowAudio.instance().MUSIC_PATH] = null
	check(not MeowAudio.instance().play_music(0), "Missing music never reports successful playback")
	MeowAudio.instance().streams[MeowAudio.instance().MUSIC_PATH] = original_music
	var original_hint: AudioStream = MeowAudio.instance().streams[MeowAudio.instance().SOUNDS.hint]
	MeowAudio.instance().streams[MeowAudio.instance().SOUNDS.hint] = null
	check(not MeowAudio.instance().play_sfx("hint"), "Missing one-shot never reports successful playback")
	MeowAudio.instance().streams[MeowAudio.instance().SOUNDS.hint] = original_hint
	MeowAudio.instance().stop_music(0)
	MeowAudio.instance().set_music_volume(0.25, false)
	MeowAudio.instance().set_sfx_volume(0.75, false)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.25)), "Independent music gain")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.75)), "Independent SFX gain")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Cat")), linear_to_db(0.75)), "Cat follows sound-effects volume")
	MeowAudio.instance().set_music_volume(-2, false)
	check(MeowAudio.instance().music_volume == 0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Zero volume truly mutes music")
	MeowAudio.instance().set_music_volume(0.65, false)
	MeowAudio.instance().play_music(0.04)
	await create_timer(0.08).timeout
	await settle()
	print("FADE: playing=", MeowAudio.instance().music.playing, "; volume=", MeowAudio.instance().music.volume_db)
	check(MeowAudio.instance().music.playing and absf(MeowAudio.instance().music.volume_db + 4) < 0.1, "Music starts and fades in")
	MeowAudio.instance().stop_music(0.04)
	await create_timer(0.08).timeout
	check(not MeowAudio.instance().music.playing, "Music fades out and stops")
	MeowAudio.instance().play_music(0)
	MeowAudio.instance().stop_music(1)
	MeowAudio.instance().play_music(0)
	await settle()
	check(MeowAudio.instance().music.playing, "Restart during fade-out cancels stale stop callback")
	MeowAudio.instance().music.seek(MeowAudio.instance().music.stream.get_length() - 0.06)
	await create_timer(0.30).timeout
	check(MeowAudio.instance().music.playing and MeowAudio.instance().music.get_playback_position() < 2, "Music actually crosses end and loops")
	reset_effects()
	for event in ["ui", "select", "place", "mark", "erase", "invalid", "hint", "undo", "restart", "complete", "unlock"]:
		reset_effects()
		check(MeowAudio.instance().play_sfx(event), "One-shot event: " + event)
	reset_effects()
	check(MeowAudio.instance().play_cat("meow") and MeowAudio.instance().cat_player.pitch_scale >= 0.96 and MeowAudio.instance().cat_player.pitch_scale <= 1.04, "Meow plays with natural bounded pitch variation")
	check(not MeowAudio.instance().play_cat("chirp"), "Cat cooldown prevents overlapping vocalizations")
	MeowAudio.instance().cat_player.stop()
	MeowAudio.instance().clock_override += 5
	check(MeowAudio.instance().play_cat("chirp"), "Happy chirp after cooldown")
	MeowAudio.instance().cat_player.stop()
	MeowAudio.instance().clock_override += 5
	check(MeowAudio.instance().play_cat("purr"), "Soft purr starts")
	MeowAudio.instance().clock_override += 3.1
	MeowAudio.instance()._process(0)
	check(not MeowAudio.instance().cat_player.playing, "Looping purr is time-bounded")
	reset_effects()
	var accepted := 0
	for tap in range(100):
		if MeowAudio.instance().play_sfx("place"):
			accepted += 1
	check(accepted == 1, "100 same-time taps yield one placement sound")
	reset_effects()
	for event in ["ui", "select", "place", "mark", "erase", "undo"]:
		MeowAudio.instance().play_sfx(event)
	var active := 0
	for voice in MeowAudio.instance().effects:
		active += 1 if voice.playing else 0
	check(active <= MeowAudio.instance().MAX_SFX and not MeowAudio.instance().play_sfx("restart"), "Global voice pool bounds mixed overlapping events")
	check(MeowAudio.instance().play_sfx("complete"), "Completion feedback survives a busy pool")
	var completion_voice: AudioStreamPlayer
	for voice in MeowAudio.instance().effects:
		if int(voice.get_meta("priority", 0)) == 3:
			completion_voice = voice
	MeowAudio.instance().play_sfx("hint")
	check(completion_voice != null and completion_voice.playing and int(completion_voice.get_meta("priority", 0)) == 3, "Hint feedback cannot steal an active completion voice")
	MeowAudio.instance().set_interrupted("background", true)
	check(not MeowAudio.instance().play_sfx("place") and MeowAudio.instance().music.stream_paused, "Background pauses music and suppresses effects")
	MeowAudio.instance().set_interrupted("native_audio", true)
	MeowAudio.instance().set_interrupted("background", false)
	check(MeowAudio.instance().music.stream_paused, "One interruption cannot clear another")
	MeowAudio.instance().set_music_enabled(false, false)
	MeowAudio.instance().set_interrupted("native_audio", false)
	check(MeowAudio.instance().music.stream_paused and not MeowAudio.instance().music_enabled, "Resume never overrides user music mute")
	MeowAudio.instance().notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(MeowAudio.instance().blockers.has("background"), "Application pause notification is connected")
	MeowAudio.instance().notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not MeowAudio.instance().blockers.has("background") and not MeowAudio.instance().music_enabled, "Application resume preserves mute")
	MeowAudio.instance().set_sfx_enabled(false, false)
	check(not MeowAudio.instance().play_sfx("hint") and not MeowAudio.instance().play_cat(), "SFX mute also mutes cats")
	MeowAudio.instance().set_music_enabled(true, false)
	MeowAudio.instance().set_sfx_enabled(true, false)
	MeowAudio.instance().set_muted(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Cat")) and not MeowAudio.instance().play_sfx("ui"), "Master mute gates every owned bus")
	MeowAudio.instance().set_muted(false)
	# Versioned save round trip, including migration from old settings with no audio fields.
	GameServices.initialize()
	MeowAudio.instance().configure(PlayerPreferences.audio_values())
	MeowAudio.instance().set_music_enabled(false)
	MeowAudio.instance().set_sfx_volume(0.35)
	var saved_path := GameServices.save_path
	GameServices.initialize()
	check(not PlayerPreferences.music_enabled and is_equal_approx(PlayerPreferences.sfx_volume, 0.35), "Muted music and volume survive a fresh service load")
	var old := PlayerSave.defaults()
	old.settings = {"reduced_motion": true}
	var fixture := FileAccess.open(saved_path + ".old", FileAccess.WRITE)
	fixture.store_string(JSON.stringify(old))
	fixture.close()
	var migrated := PlayerSave.new(saved_path + ".old")
	migrated.load_file()
	check(migrated.state.settings.music_enabled and migrated.state.settings.sfx_enabled and migrated.state.settings.reduced_motion, "Old saves gain ON defaults without losing comfort settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path + ".old"))
	# Real game hooks: no direct fake calls to announce().
	MeowAudio.instance().configure({})
	reset_effects()
	MeowAudio.instance().played_counts.clear()
	var app := preload("res://scenes/main.tscn").instantiate()
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	root.add_child(app)
	await settle()
	app.current_screen.find_child("PlayButton", true, false).pressed.emit()
	await settle()
	check(MeowAudio.instance().played_counts.get("ui", 0) > 0, "Real menu button emits UI click")
	var screen = app.current_screen
	reset_effects()
	screen.cells[0].pressed.emit()
	check(MeowAudio.instance().played_counts.get("select", 0) > 0 and MeowAudio.instance().played_counts.get("place", 0) > 0, "Actual tile selection and cat placement hooks")
	reset_effects()
	screen.cells[1].pressed.emit()
	check(MeowAudio.instance().played_counts.get("invalid", 0) > 0, "Rule conflict emits invalid feedback")
	reset_effects()
	screen.cells[0].pressed.emit()
	check(MeowAudio.instance().played_counts.get("mark", 0) > 0, "Actual X placement hook")
	reset_effects()
	screen.cells[0].pressed.emit()
	check(MeowAudio.instance().played_counts.get("erase", 0) > 0, "Actual X removal hook")
	reset_effects()
	screen.undo_action()
	check(MeowAudio.instance().played_counts.get("undo", 0) > 0, "Actual undo hook")
	reset_effects()
	screen.restart()
	check(MeowAudio.instance().played_counts.get("restart", 0) > 0, "Actual restart hook")
	reset_effects()
	screen.hint_action()
	check(MeowAudio.instance().played_counts.get("hint", 0) > 0, "Successful saved hint hook")
	reset_effects()
	MeowAudio.instance().idle_countdown = 0
	MeowAudio.instance()._process(0.01)
	check(MeowAudio.instance().cat_player.playing and MeowAudio.instance().cat_until > 0, "Idle cat context emits a bounded purr")
	screen.restart()
	for row in range(int(screen.level.size)):
		reset_effects()
		screen.cells[row * int(screen.level.size) + int(screen.session.solution[row])].pressed.emit()
	check(MeowAudio.instance().played_counts.get("complete", 0) == 1, "Real completion emits celebration once")
	check(MeowAudio.instance().played_counts.get("unlock", 0) == 1, "New progression unlock emits chime once")
	app.close_overlay()
	screen.update_board()
	check(MeowAudio.instance().played_counts.get("complete", 0) == 1 and MeowAudio.instance().played_counts.get("unlock", 0) == 1, "Redraw never repeats completion or unlock audio")
	app.show_page("settings")
	await settle()
	check(app.current_screen.find_child("MusicVolume", true, false) is HSlider and app.current_screen.find_child("SfxVolume", true, false) is HSlider, "Separate touch-friendly volume controls")
	app.current_screen.find_child("MusicEnabled", true, false).button_pressed = false
	check(not MeowAudio.instance().music_enabled and not GameServices.progression.save.state.settings.music_enabled, "Settings toggle applies and persists")
	app.current_screen.find_child("SfxVolume", true, false).value = 0.2
	app.current_screen.find_child("MusicVolume", true, false).value = 0.3
	check(is_equal_approx(MeowAudio.instance().sfx_volume, 0.2) and is_equal_approx(MeowAudio.instance().music_volume, 0.3), "Both settings sliders independently apply volume")
	var settings_reload := PlayerSave.new(GameServices.save_path)
	settings_reload.load_file()
	check(is_equal_approx(settings_reload.state.settings.sfx_volume, 0.2) and is_equal_approx(settings_reload.state.settings.music_volume, 0.3) and not settings_reload.state.settings.music_enabled, "Both slider values and mute persist to disk")
	app.queue_free()
	await process_frame
	if "--capture-audio" in OS.get_cmdline_user_args():
		await capture_mix()
	MeowAudio.instance().stop_music(0)
	MeowAudio.instance().stop_one_shots()
	MeowAudio.instance().clock_override = -1
	MeowAudio.instance().blockers.clear()
	TestStorage.cleanup()
	original_music = null
	original_hint = null
	MeowAudio.instance().shutdown()
	await create_timer(0.35).timeout
	print("RESULT: %d audio checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture_mix() -> void:
	reset_effects()
	MeowAudio.instance().stop_music(0)
	await create_timer(0.1).timeout
	MeowAudio.instance().configure({})
	MeowAudio.instance().set_muted(false)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2
	AudioServer.add_bus_effect(0, capture)
	MeowAudio.instance().play_music(0)
	await create_timer(0.6).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	var pcm := PackedByteArray()
	pcm.resize(frames.size() * 4)
	for index in range(frames.size()):
		peak = maxf(peak, maxf(absf(frames[index].x), absf(frames[index].y)))
		pcm.encode_s16(index * 4, roundi(clampf(frames[index].x, -1, 1) * 32767))
		pcm.encode_s16(index * 4 + 2, roundi(clampf(frames[index].y, -1, 1) * 32767))
	check(frames.size() > 1000 and peak > 0.001, "Actual mixer emits non-silent music frames")
	DirAccess.make_dir_recursive_absolute("res://artifacts/audio")
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = int(AudioServer.get_mix_rate())
	recording.data = pcm
	check(recording.save_to_wav("res://artifacts/audio/verified-mix.wav") == OK, "Saved actual mixed output for inspection")
	print("MIX: %d frames, peak %.4f" % [frames.size(), peak])
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)

