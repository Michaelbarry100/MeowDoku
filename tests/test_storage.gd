class_name TestStorage
extends RefCounted

static func configure(tag: String) -> void:
	GameServices.save_path = "user://test_" + tag + "_" + str(Time.get_ticks_usec()) + ".json"
	PlayerPreferences.backend_load = Callable()
	PlayerPreferences.backend_save = Callable()
	PlayerPreferences.storage_path = GameServices.save_path + ".cfg"
	PlayerPreferences.apply_values({})

static func cleanup() -> void:
	if GameServices.ads != null:
		GameServices.ads.dispose()
		GameServices.ads = null
	for suffix in ["", ".bak", ".tmp", ".corrupt", ".cfg", ".ad_sandbox", ".ad_sandbox.tmp"]:
		var path: String = GameServices.save_path + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	PlayerPreferences.backend_load = Callable()
	PlayerPreferences.backend_save = Callable()
	PlayerPreferences.storage_path = PlayerPreferences.PATH
	GameServices.save_path = GameServices.default_save_path

static func drain_audio() -> void:
	# Let the mixer release queued playback references before CLI runners quit.
	var tree := Engine.get_main_loop() as SceneTree
	var audio := tree.root.get_node_or_null("AudioManager") as MeowAudio
	if audio != null:
		audio.shutdown()
		await tree.create_timer(0.35).timeout
		audio.queue_free()
		await tree.process_frame
