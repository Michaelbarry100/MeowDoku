extends SceneTree

var checks := 0
var failures := 0
var app: Control
var capture := false

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
	if button != null:
		button.pressed.emit()

func settle() -> void:
	for i in range(4):
		await process_frame

func new_app() -> void:
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()

func close_app() -> void:
	app.queue_free()
	await process_frame

func screenshot(name: String) -> void:
	if not capture:
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/progression")
	check(root.get_texture().get_image().save_png("res://artifacts/progression/" + name + ".png") == OK, "Captured " + name)

func solve_screen() -> void:
	var screen: Control = app.current_screen
	for row in range(int(screen.level.size)):
		screen.cells[row * int(screen.level.size) + int(screen.session.solution[row])].pressed.emit()
	await settle()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("convenience")
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	await new_app()
	press(app.current_screen, "LevelsButton")
	check(not app.current_screen.find_child("Level01Button", true, false).disabled and app.current_screen.find_child("Level02Button", true, false).disabled, "Initial unlocked and locked levels distinguished")
	await screenshot("01-level-selection")
	press(app.current_screen, "HardGroupButton")
	var hard_button := "Level%02dButton" % int(GameServices.progression.catalog.get_level("hard_01").order)
	check(app.current_screen.selected_group == "Hard" and app.current_screen.find_child(hard_button, true, false).disabled, "Difficulty group filters locked hard levels")
	var previous: Control = app.current_screen
	app.show_puzzle("hard_01")
	check(app.current_screen == previous, "Navigation cannot bypass level lock")
	app.show_menu()
	press(app.current_screen, "PlayButton")
	var screen: Control = app.current_screen
	var column := int(screen.session.solution[0])
	screen.cells[column].pressed.emit()
	screen.cells[column].pressed.emit()
	check(screen.board[0][column] == 2, "Player can place X")
	press(screen, "UndoButton")
	check(screen.board[0][column] == 1 and screen.moves == 1, "Undo X restores previous cat")
	press(screen, "UndoButton")
	check(screen.board[0][column] == 0 and screen.moves == 0, "Undo placement restores empty cell")
	screen.cells[column].pressed.emit()
	press(screen, "RestartButton")
	check(app.overlay.name == "RestartConfirmation" and screen.moves == 1, "Restart requires confirmation before clearing")
	await screenshot("02-restart-confirmation")
	press(app.overlay, "CancelRestartButton")
	check(app.overlay == null and screen.board[0][column] == 1, "Cancel keeps exact progress")
	press(screen, "PauseButton")
	press(app.overlay, "ModalRestartButton")
	press(app.overlay, "CancelRestartButton")
	check(app.overlay.name == "PauseMenu", "Cancel from pause returns to pause")
	press(app.overlay, "ResumeButton")
	press(screen, "RestartButton")
	press(app.overlay, "ConfirmRestartButton")
	check(screen.moves == 0 and screen.session.history.is_empty(), "Confirmed restart clears attempt")
	screen.cells[0].pressed.emit()
	press(screen, "HintButton")
	check(screen.board[0][0] == 0 and screen.session.hints_used == 1, "Hint corrects wrong cat safely")
	press(screen, "UndoButton")
	check(screen.board[0][0] == 1 and screen.session.hints_used == 1, "Hint undo preserves usage count")
	screen.cells[6].pressed.emit()
	screen.cells[6].pressed.emit()
	var board: Array = screen.board.duplicate(true)
	var moves: int = screen.moves
	app.show_menu()
	check(app.current_screen.find_child("PlayButton", true, false).text.contains("Resume"), "Menu advertises resumable puzzle")
	await screenshot("03-resume-menu")
	press(app.current_screen, "SettingsButton")
	var reduced := app.current_screen.find_child("ReducedMotion", true, false) as CheckButton
	var limits := app.current_screen.find_child("MistakeLimits", true, false) as CheckButton
	reduced.button_pressed = true
	limits.button_pressed = true
	press(app.current_screen, "BackButton")
	press(app.current_screen, "PlayButton")
	check(app.current_screen.board == board and app.current_screen.moves == moves, "Screen changes preserve cats, X marks and counters")
	await close_app()
	await new_app()
	check(PlayerPreferences.reduced_motion and PlayerPreferences.mistake_limits, "Versioned settings survive app reopening")
	press(app.current_screen, "PlayButton")
	screen = app.current_screen
	check(screen.level.id == "easy_01" and screen.board == board and screen.moves == moves and screen.session.hints_used == 1, "Closing and reopening app resumes exact unfinished puzzle")
	press(screen, "UndoButton")
	check(screen.board[1][1] == 1, "Undo history survives full app reopening")
	press(screen, "RestartButton")
	press(app.overlay, "ConfirmRestartButton")
	await solve_screen()
	check(app.overlay.name == "Victory" and GameServices.progression.total_stars() == 3, "Victory saves first-clear reward")
	check(GameServices.progression.unlocked("easy_02"), "Victory unlocks next campaign level")
	await screenshot("04-rewards-victory")
	press(app.overlay, "NextButton")
	check(app.current_screen.level.id == "easy_02", "Next Level opens next unlocked puzzle")
	app.show_puzzle("easy_01", true)
	await solve_screen()
	check(GameServices.progression.total_stars() == 3, "Replay completion cannot duplicate stars")
	press(app.overlay, "ModalRestartButton")
	check(app.current_screen.moves == 0 and not app.current_screen.complete, "Victory Replay starts fresh attempt")
	app.show_menu()
	press(app.current_screen, "DailyButton")
	var date: String = app.current_screen.level.daily_date
	var source: String = app.current_screen.level.source_id
	app.current_screen.cells[0].pressed.emit()
	await close_app()
	await new_app()
	press(app.current_screen, "PlayButton")
	check(app.current_screen.level.daily_date == date and app.current_screen.level.source_id == source and app.current_screen.board[0][0] == 1, "Daily selection and progress survive app restart")
	check(GameServices.progression.total_stars() == 3, "Reward ledger survives app restart")
	root.size = Vector2i(320, 568)
	root.content_scale_size = root.size
	await settle()
	press(app.current_screen, "HintButton")
	await settle()
	check(app.current_screen.get_node("Content/Actions/RestartButton").get_global_rect().end.y <= 552, "Hint feedback and convenience controls fit smallest phone")
	await screenshot("05-small-phone-hint")
	await close_app()
	TestStorage.cleanup()
	print("RESULT: %d convenience UI checks, %d failures" % [checks, failures])
	await TestStorage.drain_audio()
	quit(1 if failures else 0)

