extends SceneTree

var checks := 0
var failures := 0
var app: Control
var capture := false
var test_path := "user://ui_preferences_test.cfg"
var original_motion := false
var original_haptics := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func press(parent: Node, node_name: String) -> void:
	var button := parent.find_child(node_name, true, false) as BaseButton
	check(button != null, "Control exists: " + node_name)
	if button:
		button.pressed.emit()

func settle() -> void:
	for i in range(4):
		await process_frame

func pointer_click(button: Control) -> void:
	var position := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func snapshot(name: String) -> void:
	if not capture:
		return
	await create_timer(0.30).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/mobile")
	var error := root.get_texture().get_image().save_png("res://artifacts/mobile/" + name + ".png")
	check(error == OK, "Screenshot saved: " + name)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("mobile_ui")
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	PlayerPreferences.load_settings()
	original_motion = PlayerPreferences.reduced_motion
	original_haptics = PlayerPreferences.haptics
	PlayerPreferences.storage_path = test_path
	PlayerPreferences.reduced_motion = false
	PlayerPreferences.haptics = false
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	await snapshot("01-main-menu")
	for name in ["PlayButton", "DailyButton", "SettingsButton", "LevelsButton", "RulesButton"]:
		var button := app.current_screen.find_child(name, true, false) as Button
		check(button != null and button.size.y >= 48, "Comfortable menu target: " + name)
	press(app.current_screen, "SettingsButton")
	await settle()
	check(app.current_screen.name == "Settings", "Menu opens settings")
	var reduced := app.current_screen.find_child("ReducedMotion", true, false) as CheckButton
	var haptics := app.current_screen.find_child("Haptics", true, false) as CheckButton
	reduced.button_pressed = true
	haptics.button_pressed = true
	check(PlayerPreferences.reduced_motion and PlayerPreferences.haptics, "Comfort switches apply immediately")
	PlayerPreferences.reduced_motion = false
	PlayerPreferences.haptics = false
	PlayerPreferences.load_settings()
	check(PlayerPreferences.reduced_motion and PlayerPreferences.haptics, "Comfort settings persist across reload")
	await snapshot("02-settings")
	press(app.current_screen, "BackButton")
	press(app.current_screen, "RulesButton")
	await settle()
	check(app.current_screen.name == "Tutorial", "Menu opens tutorial")
	var demo: Array[Node] = app.current_screen.find_children("PracticeCell*", "Button", true, false)
	check(demo.size() == 3, "Tutorial offers three practice cells")
	if not demo.is_empty():
		demo[0].pressed.emit()
		check(demo[0].state == 1, "Tutorial tap places a cat")
		demo[0].pressed.emit()
		check(demo[0].state == 2, "Tutorial tap marks X")
		check(demo[0].cat_scale == 1.0, "Reduced motion keeps cat still")
	await snapshot("03-tutorial")
	press(app.current_screen, "BackButton")
	press(app.current_screen, "LevelsButton")
	await settle()
	check(app.current_screen.name == "LevelSelection", "Menu opens level selection")
	await snapshot("04-level-selection")
	check(app.current_screen.find_child("Level02Button", true, false).disabled, "Next level starts locked")
	# Earn the unlock through the real game rather than bypassing progression.
	app.show_puzzle("easy_01", true)
	for row in range(5):
		app.current_screen.cells[row * 5 + int(app.current_screen.level.solution[row])].pressed.emit()
	app.show_page("levels")
	press(app.current_screen, "Level02Button")
	await settle()
	check(app.current_screen.level.title == "Cloudberry Path", "Second level opens correctly")
	app.show_menu()
	press(app.current_screen, "DailyButton")
	await settle()
	check(app.current_screen.level.has("daily_date"), "Daily opens a date-seeded puzzle")
	var date: String = app.current_screen.level.daily_date
	var replay: Dictionary = app.daily_puzzle(date)
	check(replay.ok and replay.puzzle.regions == app.current_screen.level.regions, "Daily is reproducible for the same local date")
	await snapshot("05-daily-puzzle")
	app.show_menu()
	app.show_puzzle("easy_01", true)
	await settle()
	var screen: Control = app.current_screen
	screen.cells[0].pressed.emit()
	check(screen.cells[0].selected and screen.cells[0].state == 1, "Tapped cat has distinct selected state")
	screen.cells[1].pressed.emit()
	check(screen.cells[0].invalid and screen.cells[1].invalid, "Invalid cats retain both symbol and border feedback")
	await snapshot("06-puzzle-conflict")
	press(screen, "PauseButton")
	await settle()
	check(app.overlay != null and app.overlay.name == "PauseMenu" and screen.suspended, "Pause opens and suspends gameplay")
	var before: Array = screen.board.duplicate(true)
	screen.on_cell_requested(2, 2)
	check(screen.board == before, "Paused board rejects input")
	await snapshot("07-pause")
	press(app.overlay, "PauseSettingsButton")
	await settle()
	check(app.overlay.find_child("ReducedMotion", true, false) != null, "Pause settings opens above preserved puzzle")
	press(app.overlay, "BackButton")
	await settle()
	check(app.overlay.name == "PauseMenu" and screen.board == before, "Settings back returns to pause preserving moves")
	press(app.overlay, "ResumeButton")
	check(app.overlay == null and not screen.suspended and screen.board == before, "Resume preserves puzzle")
	press(screen, "RulesButton")
	await settle()
	press(app.overlay, "BackButton")
	press(app.overlay, "ResumeButton")
	check(screen.board == before, "In-game rules preserve puzzle")
	press(screen, "RestartButton")
	press(app.overlay, "ConfirmRestartButton")
	check(screen.moves == 0 and screen.selected_cell == Vector2i(-1, -1), "Restart clears selection and progress")
	for row in range(int(screen.level.size)):
		screen.cells[row * int(screen.level.size) + int(screen.level.solution[row])].pressed.emit()
	await settle()
	check(screen.complete and app.overlay != null and app.overlay.name == "Victory", "Winning opens victory screen")
	await snapshot("08-victory")
	press(app.overlay, "ModalRestartButton")
	if app.overlay != null and app.overlay.name == "RestartConfirmation":
		press(app.overlay, "ConfirmRestartButton")
	check(app.overlay == null and not screen.complete and screen.moves == 0, "Victory replay resets game")

	for viewport_size in [Vector2i(320, 568), Vector2i(320, 640), Vector2i(390, 844), Vector2i(430, 932), Vector2i(768, 1024)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await settle()
		var grid: GridContainer = screen.get_node("Content/BoardAspect/Grid")
		check(absf(grid.size.x - grid.size.y) < 1, "Square board at %s" % viewport_size)
		check(screen.cells[0].size.x >= 48 and screen.cells[0].size.y >= 48, "48-unit cells at %s" % viewport_size)
		var restart_button: Button = screen.get_node("Content/Actions/RestartButton")
		check(restart_button.get_global_rect().end.y <= viewport_size.y - 16, "Actions inside safe content at %s" % viewport_size)
		check(grid.get_global_rect().position.x >= 16 and grid.get_global_rect().end.x <= viewport_size.x - 16, "Board fits width at %s" % viewport_size)
		await snapshot("size-%dx%d" % [viewport_size.x, viewport_size.y])

	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app.safe_area.test_insets = Vector4(0, 44, 0, 34)
	app.safe_area.update_insets()
	await settle()
	check(screen.get_global_rect().position.y >= 60, "Notch inset moves content below safe top")
	check(screen.get_global_rect().end.y <= 794, "Home-indicator inset preserves safe bottom")
	await snapshot("09-safe-area")
	app.safe_area.test_insets = Vector4.ZERO
	app.safe_area.update_insets()
	root.size = Vector2i(320, 640)
	root.content_scale_size = root.size
	app.safe_area.test_insets = Vector4(0, 44, 0, 34)
	app.safe_area.update_insets()
	await settle()
	check(screen.get_node("Content/Actions/RestartButton").get_global_rect().end.y <= 590, "Small-phone actions stay above home indicator")
	app.show_pause()
	app.overlay.safe.test_insets = Vector4(0, 44, 0, 34)
	app.overlay.safe.update_insets()
	app.overlay.layout_panel()
	await settle()
	check(app.overlay.panel.get_global_rect().position.y >= 60 and app.overlay.panel.get_global_rect().end.y <= 590, "Pause card respects simulated notch and home indicator")
	app.close_overlay()
	app.safe_area.test_insets = Vector4.ZERO
	app.safe_area.update_insets()
	root.size = Vector2i(320, 568)
	root.content_scale_size = root.size
	await settle()
	app.show_pause()
	await settle()
	check(app.overlay.panel.size.x <= 288 and app.overlay.panel.get_global_rect().end.y <= 552, "Pause card fits smallest phone")
	await snapshot("small-pause")
	app.close_overlay()
	for row in range(int(screen.level.size)):
		screen.cells[row * int(screen.level.size) + int(screen.level.solution[row])].pressed.emit()
	await settle()
	check(app.overlay.panel.size.x <= 288 and app.overlay.panel.get_global_rect().end.y <= 552, "Victory card fits smallest phone")
	await snapshot("small-victory")
	press(app.overlay, "ModalRestartButton")
	app.show_menu()
	await settle()
	var menu_scroll := app.current_screen.get_node("Scroll") as ScrollContainer
	check(menu_scroll.get_child(0).size.x <= menu_scroll.size.x, "Small-phone menu has no horizontal overflow")
	await snapshot("small-main-menu")
	app.show_puzzle()
	screen = app.current_screen
	app.show_pause()
	press(app.overlay, "ModalRestartButton")
	press(app.overlay, "ConfirmRestartButton")
	check(app.overlay == null and screen.moves == 0, "Pause restart works")
	app.show_pause()
	press(app.overlay, "ModalMenuButton")
	check(app.current_screen.find_child("PlayButton", true, false) != null, "Pause returns to main menu")
	PlayerPreferences.reduced_motion = false
	app.show_puzzle()
	await create_timer(0.25).timeout
	check(is_equal_approx(app.current_screen.modulate.a, 1.0), "Normal screen transition finishes")
	app.current_screen.cells[0].pressed.emit()
	await create_timer(0.30).timeout
	check(is_equal_approx(app.current_screen.cells[0].cat_scale, 1.0), "Cat success animation settles")
	PlayerPreferences.reduced_motion = true
	app.show_menu()
	check(app.current_screen.modulate.a == 1, "Reduced motion skips screen fade")
	await settle()
	await pointer_click(app.current_screen.find_child("PlayButton", true, false))
	check(app.current_screen.has_method("on_cell_requested"), "Real pointer event opens puzzle from menu")
	await pointer_click(app.current_screen.find_child("PauseButton", true, false))
	check(app.overlay != null and app.overlay.name == "PauseMenu", "Real pointer event opens pause")
	var resume: Control = app.overlay.find_child("ResumeButton", true, false)
	check(app.overlay.panel.is_ancestor_of(root.gui_get_focus_owner()), "Modal takes keyboard focus")
	await pointer_click(resume)
	check(app.overlay == null and not app.current_screen.suspended, "Real pointer event resumes game")
	app.queue_free()
	await process_frame
	TestStorage.cleanup()
	PlayerPreferences.storage_path = PlayerPreferences.PATH
	PlayerPreferences.reduced_motion = original_motion
	PlayerPreferences.haptics = original_haptics
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: %d mobile UI checks, %d failures" % [checks, failures])
	await TestStorage.drain_audio()
	quit(1 if failures else 0)

