class_name GameServices
extends RefCounted
## Composition root shared by screen adapters; engine/storage have no UI imports.

const RELEASE_SAVE_PATH := "user://release_player_save.json"
# Preserve existing development progress, but never auto-import it into release.
# This also isolates stars/unlocks earned while testing simulated hints.
static var default_save_path: String = PlayerSave.DEFAULT_PATH if OS.is_debug_build() else RELEASE_SAVE_PATH
static var save_path: String = default_save_path
static var progression: ProgressionService
static var catalog_error := ""
static var hints: HintInventory
static var ads: AdService

static func initialize() -> void:
	if ads != null:
		ads.dispose()
	var catalog := LevelCatalog.new()
	var loaded := catalog.load_collection()
	catalog_error = "" if loaded.ok else str(loaded.errors[0])
	var repository := PlayerSave.new(save_path)
	repository.load_file()
	# One-time migration of existing Task 3 preferences into the versioned save.
	if repository.load_status == "missing":
		PlayerPreferences.load_settings(PlayerPreferences.storage_path)
		repository.state.settings.reduced_motion = PlayerPreferences.reduced_motion
		repository.state.settings.haptics = PlayerPreferences.haptics
		repository.state.settings.merge(PlayerPreferences.audio_values(), true)
	progression = ProgressionService.new(catalog, repository)
	hints = HintInventory.new(repository, OS.is_debug_build())
	var gate := AdConsentGate.new()
	gate.development_allowed = repository.state.ad_privacy.choice == "mock"
	var adapter: AdProvider = MockAdProvider.new() if OS.is_debug_build() else AdProvider.new()
	ads = AdService.new(adapter, hints, gate, OS.is_debug_build())
	# No SDK/provider initialization until an explicit opt-in and user request.
	PlayerPreferences.apply_values(repository.state.settings)
	PlayerPreferences.backend_load = func() -> Dictionary: return progression.save.state.settings.duplicate(true)
	PlayerPreferences.backend_save = func(values: Dictionary) -> Error:
		progression.save.state.settings = values.duplicate(true)
		return progression.persist()

static func set_ad_choice(choice: String) -> bool:
	if not choice in ["off", "mock"] or (choice == "mock" and not OS.is_debug_build()):
		return false
	var previous: Dictionary = progression.save.state.ad_privacy.duplicate(true)
	if choice == "off":
		ads.revoke_permission() # Withdrawal takes effect even if storage fails.
	progression.save.state.ad_privacy = {"version": 1, "choice": choice}
	if progression.persist() != OK:
		if choice != "off":
			progression.save.state.ad_privacy = previous
		return false
	if choice == "mock":
		ads.consent.development_allowed = true
	return true
