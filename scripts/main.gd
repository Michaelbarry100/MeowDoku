extends Control

const MENU := preload("res://scenes/main_menu.tscn")
const PUZZLE := preload("res://scenes/puzzle_screen.tscn")
const PAGES := {
	"settings": preload("res://scenes/settings.tscn"),
	"tutorial": preload("res://scenes/tutorial.tscn"),
	"levels": preload("res://scenes/level_selection.tscn"),
	"privacy": preload("res://scenes/privacy.tscn"),
}
var current_screen: Control
var safe_area: MobileSafeArea
var overlay: Control
var restart_returns_to_pause := false

func _ready() -> void:
	GameServices.initialize()
	MeowAudio.instance().configure(PlayerPreferences.audio_values())
	MeowAudio.instance().play_music()
	GameServices.ads.presentation_changed.connect(on_ad_presentation)
	theme = PurrTheme.create()
	var backdrop := Control.new()
	backdrop.set_script(preload("res://scripts/cozy_backdrop.gd"))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	safe_area = MobileSafeArea.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_area)
	show_menu()

func replace_screen(scene: PackedScene) -> Control:
	persist_current()
	close_overlay()
	if is_instance_valid(current_screen):
		safe_area.remove_child(current_screen)
		current_screen.queue_free()
	current_screen = scene.instantiate()
	safe_area.add_child(current_screen)
	PurrUI.fade_in(current_screen)
	return current_screen

func show_menu() -> void:
	var menu := replace_screen(MENU)
	menu.play_requested.connect(show_puzzle)
	menu.action_requested.connect(handle_action)

func show_puzzle(id: String = "", replay: bool = false) -> void:
	var target := GameServices.progression.next_playable() if id.is_empty() else id
	var play := GameServices.progression.open_session(target, replay)
	if play == null:
		return
	persist_current()
	close_overlay()
	if is_instance_valid(current_screen):
		safe_area.remove_child(current_screen)
		current_screen.queue_free()
	var puzzle: Control = PUZZLE.instantiate()
	puzzle.initial_session = play
	current_screen = puzzle
	safe_area.add_child(puzzle)
	PurrUI.fade_in(puzzle)
	puzzle.menu_requested.connect(show_menu)
	puzzle.pause_requested.connect(show_pause)
	puzzle.rules_requested.connect(func() -> void: show_info_overlay("tutorial"))
	puzzle.completed.connect(show_victory)
	puzzle.restarted.connect(close_overlay)
	puzzle.restart_requested.connect(show_restart_confirmation)
	puzzle.progress_changed.connect(persist_current)
	puzzle.hint_options_requested.connect(show_hint_options)
	persist_current()
	puzzle.update_board()
	if play.is_complete():
		show_victory(str(play.puzzle.title), play.moves)

func persist_current() -> void:
	if GameServices.progression == null or not is_instance_valid(current_screen) or not current_screen.has_method("on_cell_requested") or not current_screen.level_ready:
		return
	if GameServices.progression.puzzle_for(str(current_screen.level.get("id", ""))).is_empty():
		return # Standalone developer/test boards are not campaign progress.
	var unlocked_before: int = GameServices.progression.save.state.unlocked.size()
	var result := GameServices.progression.record(current_screen.session)
	if GameServices.progression.save.state.unlocked.size() > unlocked_before:
		MeowAudio.instance().play_sfx("unlock")
	current_screen.save_warning = "" if result.ok else "Saving failed. Changes are held in memory; check device storage."

func show_page(kind: String) -> void:
	var page := replace_screen(PAGES[kind])
	page.action_requested.connect(func(action: String) -> void:
		if action == "back" and kind == "privacy":
			show_page("settings")
		else:
			handle_action(action))

func handle_action(action: String) -> void:
	if action.begins_with("level:"):
		show_puzzle(action.trim_prefix("level:"))
		return
	match action:
		"play": show_puzzle()
		"level_01": show_puzzle("easy_01")
		"daily": start_daily()
		"level_02":
			show_puzzle("easy_02")
		"settings", "tutorial", "levels", "privacy": show_page(action)
		_: show_menu()

func daily_puzzle(date: String) -> Dictionary:
	return GameServices.progression.daily(date)

func start_daily() -> void:
	var generated := daily_puzzle(Time.get_date_string_from_system())
	if generated.ok:
		show_puzzle(generated.puzzle.id)

func close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null
	if is_instance_valid(current_screen) and current_screen.has_method("on_cell_requested"):
		current_screen.visible = true
		current_screen.suspended = false
		if current_screen.level_ready:
			current_screen.session.limits_enabled = PlayerPreferences.mistake_limits
			current_screen.update_board()

func show_pause() -> void:
	if is_instance_valid(overlay) or not current_screen.has_method("on_cell_requested") or current_screen.complete:
		return
	current_screen.suspended = true
	overlay = preload("res://scenes/pause_menu.tscn").instantiate()
	add_child(overlay)
	overlay.action_requested.connect(handle_modal_action)

func show_victory(puzzle_title: String, move_count: int) -> void:
	close_overlay()
	current_screen.suspended = true
	overlay = preload("res://scenes/victory.tscn").instantiate()
	var reward: Dictionary = GameServices.progression.save.state.completed.get(str(current_screen.level.id), {})
	var stars := int(reward.get("stars", 0))
	var save_note := "First-clear stars are saved once." if GameServices.progression.save.last_error == OK else "Saving unavailable. Progress is in memory only."
	overlay.detail = "%s\n%s\n%d moves · %d mistakes · %d hints\n%s" % [puzzle_title, "★".repeat(stars) + "☆".repeat(3 - stars), move_count, current_screen.session.mistakes, current_screen.session.hints_used, save_note]
	overlay.next_available = not GameServices.progression.catalog.next_id(str(current_screen.level.id)).is_empty() or str(current_screen.level.id).begins_with("daily_")
	add_child(overlay)
	overlay.action_requested.connect(handle_modal_action)

func handle_modal_action(action: String) -> void:
	match action:
		"resume": close_overlay()
		"restart": show_restart_confirmation()
		"confirm_restart", "replay":
			close_overlay()
			current_screen.restart()
		"cancel_restart":
			close_overlay()
			if restart_returns_to_pause:
				show_pause()
		"next":
			var next := GameServices.progression.catalog.next_id(str(current_screen.level.id))
			show_puzzle(GameServices.progression.next_playable() if next.is_empty() else next)
		"settings", "tutorial": show_info_overlay(action)
		"levels": show_page("levels")
		_: show_menu()

func show_restart_confirmation() -> void:
	restart_returns_to_pause = is_instance_valid(overlay) and overlay.name == "PauseMenu"
	close_overlay()
	current_screen.suspended = true
	overlay = preload("res://scenes/pause_menu.tscn").instantiate()
	overlay.name = "RestartConfirmation"
	overlay.mode = "confirm_restart"
	add_child(overlay)
	overlay.action_requested.connect(handle_modal_action)

func show_info_overlay(kind: String, back_to: String = "pause") -> void:
	close_overlay()
	current_screen.suspended = true
	overlay = Control.new()
	overlay.name = "InfoOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color("faf5ef")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var margin := MobileSafeArea.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(margin)
	var page: Control = PAGES[kind].instantiate()
	margin.add_child(page)
	page.action_requested.connect(func(action: String) -> void:
		if action == "privacy":
			show_info_overlay("privacy", "settings")
			return
		close_overlay()
		if action == "play":
			return
		if back_to == "settings":
			show_info_overlay("settings")
		elif back_to == "hints":
			show_hint_options()
		else:
			show_pause())
	PurrUI.fade_in(page)

func show_hint_options() -> void:
	if not current_screen.has_method("on_cell_requested") or not current_screen.level_ready or current_screen.complete:
		return
	close_overlay()
	current_screen.suspended = true
	GameServices.ads.prepare()
	overlay = preload("res://scenes/rewarded_hint.tscn").instantiate()
	overlay.puzzle_id = str(current_screen.level.id)
	add_child(overlay)
	overlay.action_requested.connect(handle_hint_action)

func handle_hint_action(action: String) -> void:
	match action:
		"watch":
			GameServices.ads.request_rewarded()
		"privacy": show_info_overlay("privacy", "hints")
		"mock_success", "mock_skip", "mock_failed":
			if OS.is_debug_build() and GameServices.ads.provider is MockAdProvider:
				GameServices.ads.provider.finish(action.trim_prefix("mock_"))
		_: 
			GameServices.ads.cancel()
			close_overlay()

func on_ad_presentation(visible: bool) -> void:
	MeowAudio.instance().set_interrupted("ad", visible)
	if not visible:
		return # The result screen stays until the player chooses Back to puzzle.
	if not OS.is_debug_build() or not GameServices.ads.provider.is_simulated():
		return
	close_overlay()
	current_screen.suspended = true
	current_screen.visible = false
	overlay = preload("res://scenes/rewarded_hint.tscn").instantiate()
	overlay.mode = "simulation"
	overlay.puzzle_id = str(current_screen.level.id)
	add_child(overlay)
	overlay.action_requested.connect(handle_hint_action)

func _process(delta: float) -> void:
	if GameServices.ads != null:
		GameServices.ads.tick(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(current_screen):
		GameServices.ads.set_application_suspended(true)
		persist_current()
		show_pause()
	elif what == NOTIFICATION_APPLICATION_RESUMED and GameServices.ads != null:
		GameServices.ads.set_application_suspended(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist_current()

func _exit_tree() -> void:
	persist_current()
	if GameServices.ads != null:
		GameServices.ads.dispose()

func handle_back() -> void:
	if is_instance_valid(overlay):
		if overlay.name == "RewardedHintPage":
			GameServices.ads.cancel()
			close_overlay()
		elif overlay.name == "InfoOverlay":
			close_overlay()
			show_pause()
		elif overlay.name == "Victory":
			show_menu()
		elif overlay.name == "RestartConfirmation":
			handle_modal_action("cancel_restart")
		else:
			close_overlay()
	elif current_screen.has_method("on_cell_requested"):
		show_pause()
	else:
		show_menu()
