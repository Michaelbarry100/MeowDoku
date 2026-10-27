class_name PlayerPreferences
extends RefCounted

static var reduced_motion := false
static var haptics := false
static var mistake_limits := false
static var music_enabled := true
static var sfx_enabled := true
static var music_volume := 0.65
static var sfx_volume := 0.8
static var backend_load: Callable
static var backend_save: Callable
static var last_error := OK
const PATH := "user://preferences.cfg"
static var storage_path := PATH

static func load_settings(path: String = "") -> void:
	if path.is_empty() and backend_load.is_valid():
		apply_values(backend_load.call())
		return
	var config := ConfigFile.new()
	if config.load(storage_path if path.is_empty() else path) == OK:
		reduced_motion = config.get_value("comfort", "reduced_motion", false) == true
		haptics = config.get_value("comfort", "haptics", false) == true
		mistake_limits = config.get_value("comfort", "mistake_limits", false) == true
		apply_audio({"music_enabled": config.get_value("audio", "music_enabled", true), "sfx_enabled": config.get_value("audio", "sfx_enabled", true), "music_volume": config.get_value("audio", "music_volume", 0.65), "sfx_volume": config.get_value("audio", "sfx_volume", 0.8)})
	else:
		apply_values({})

static func apply_values(values: Dictionary) -> void:
	reduced_motion = values.get("reduced_motion", false) == true
	haptics = values.get("haptics", false) == true
	mistake_limits = values.get("mistake_limits", false) == true
	apply_audio(values)

static func apply_audio(values: Dictionary) -> void:
	music_enabled = values.get("music_enabled", true) if values.get("music_enabled", true) is bool else true
	sfx_enabled = values.get("sfx_enabled", true) if values.get("sfx_enabled", true) is bool else true
	music_volume = volume(values.get("music_volume", 0.65), 0.65)
	sfx_volume = volume(values.get("sfx_volume", 0.8), 0.8)

static func volume(value: Variant, fallback: float) -> float:
	return clampf(float(value), 0.0, 1.0) if (value is int or value is float) and is_finite(float(value)) else fallback

static func audio_values() -> Dictionary:
	return {"music_enabled": music_enabled, "sfx_enabled": sfx_enabled, "music_volume": music_volume, "sfx_volume": sfx_volume}

static func save_settings(path: String = "") -> Error:
	if path.is_empty() and backend_save.is_valid():
		var values := audio_values()
		values.merge({"reduced_motion": reduced_motion, "haptics": haptics, "mistake_limits": mistake_limits})
		last_error = backend_save.call(values)
		return last_error
	var config := ConfigFile.new()
	config.set_value("comfort", "reduced_motion", reduced_motion)
	config.set_value("comfort", "haptics", haptics)
	config.set_value("comfort", "mistake_limits", mistake_limits)
	for setting in audio_values():
		config.set_value("audio", setting, audio_values()[setting])
	last_error = config.save(storage_path if path.is_empty() else path)
	return last_error

static func tap_feedback(success: bool = false) -> void:
	if haptics and OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(35 if success else 15)
