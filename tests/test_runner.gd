extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_runner.gd

var failures := 0
var checks := 0
var level: Dictionary

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("gameplay")
	check(ProjectSettings.get_setting("application/config/name") == "MeowDoku", "Application is named MeowDoku")
	if OS.get_name() in ["Windows", "Linux", "macOS"]:
		check(OS.get_user_data_dir().replace("\\", "/").ends_with("/app_userdata/Purrfect Regions"), "Rename preserves the previous desktop save directory")
	level = LevelData.load_first()
	var empty := LevelData.empty_board(5)
	check(not PuzzleRules.evaluate(empty, level.regions).complete, "Empty board is incomplete")
	check(PuzzleRules.evaluate(empty, level.regions).conflicts.is_empty(), "Empty board has no conflicts")
	var solution := LevelData.empty_board(5)
	for row in range(5):
		solution[row][int(level.solution[row])] = PuzzleRules.CellState.CAT
	check(PuzzleRules.evaluate(solution, level.regions).complete, "Known solution completes")
	solution[0][1] = PuzzleRules.CellState.EXCLUDED
	check(not PuzzleRules.evaluate(solution, level.regions).complete, "Missing cat prevents completion")
	empty[0][0] = PuzzleRules.CellState.EXCLUDED
	check(PuzzleRules.evaluate(empty, level.regions).cat_count == 0, "Exclusions do not count as cats")
	check_pair(Vector2i(0, 0), Vector2i(0, 4), true, "Same row")
	check_pair(Vector2i(0, 0), Vector2i(4, 0), true, "Same column")
	check_pair(Vector2i(2, 2), Vector2i(4, 4), true, "Same region without touching")
	check_pair(Vector2i(0, 0), Vector2i(1, 1), true, "Diagonal contact across regions")
	check_pair(Vector2i(0, 2), Vector2i(0, 3), true, "Horizontal contact")
	check_pair(Vector2i(0, 0), Vector2i(1, 0), true, "Vertical contact")
	check_pair(Vector2i(0, 1), Vector2i(1, 3), false, "Legal partial placement")
	# Exercise real scene instances, signals, touch-equivalent Button presses,
	# state cycling, completion locking, restart, and navigation.
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.current_screen.find_child("PlayButton", true, false) != null, "App starts on menu")
	app.current_screen.find_child("PlayButton", true, false).pressed.emit()
	await process_frame
	var screen: Control = app.current_screen
	check(screen.cells.size() == 25, "Puzzle creates 25 cells")
	for viewport_size in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(768, 1024)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		await process_frame
		var grid: GridContainer = screen.get_node("Content/BoardAspect/Grid")
		var restart_button: Button = screen.get_node("Content/Actions/RestartButton")
		check(absf(grid.size.x - grid.size.y) < 1.0, "Square board at %s" % viewport_size)
		check(screen.cells[0].size.x >= 48 and screen.cells[0].size.y >= 48, "Touch targets at %s" % viewport_size)
		check(restart_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "Actions fit viewport at %s (button %.0f, canvas %.0f)" % [viewport_size, restart_button.get_global_rect().end.y, root.get_visible_rect().size.y])
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(390, 844)
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/first-board.png")
	screen.cells[0].pressed.emit()
	check(screen.board[0][0] == 1 and screen.moves == 1, "First tap places cat and counts move")
	screen.cells[0].pressed.emit()
	check(screen.board[0][0] == 2 and screen.moves == 2, "Second tap excludes")
	screen.cells[0].pressed.emit()
	check(screen.board[0][0] == 0 and screen.moves == 3, "Third tap clears")
	screen.cells[0].pressed.emit()
	screen.cells[1].pressed.emit()
	check(screen.cells[0].invalid and screen.cells[1].invalid, "Both conflicting cats are flagged")
	check(screen.get_node("Content/Status").text.contains("row 1"), "Conflict UI names the violated row immediately")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/conflict-board.png")
	screen.get_node("Content/Actions/RestartButton").pressed.emit()
	app.overlay.find_child("ConfirmRestartButton", true, false).pressed.emit()
	check(screen.moves == 0 and screen.board == LevelData.empty_board(5), "Restart resets all state")
	for row in range(5):
		screen.cells[row * 5 + int(level.solution[row])].pressed.emit()
	check(screen.complete and screen.moves == 5, "Solving through cell signals completes puzzle")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/completed-board.png")
	check(screen.cells[0].disabled, "Completed board locks input")
	screen.on_cell_requested(0, 0)
	check(screen.moves == 5, "Completion ignores further moves")
	screen.get_node("Content/Actions/RestartButton").pressed.emit()
	app.overlay.find_child("ConfirmRestartButton", true, false).pressed.emit()
	check(not screen.complete and not screen.cells[0].disabled, "Restart unlocks completed board")
	screen.on_cell_requested(-1, 0)
	screen.on_cell_requested(5, 0)
	check(screen.moves == 0, "Out-of-bounds input is ignored safely")
	var invalid: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/unsolvable_two.json"))
	check(not screen.open_puzzle(invalid) and screen.cells.is_empty(), "Unsolvable level never becomes playable")
	check(screen.get_node("Content/Actions/RestartButton").disabled and screen.get_node("Content/Status").text.contains("no solution"), "Level failure is explained and restart disabled")
	var ambiguous: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/multiple_four.json"))
	check(not screen.open_puzzle(ambiguous), "Ambiguous level is rejected by default")
	check(screen.open_puzzle(ambiguous, false) and screen.cells.size() == 16, "Explicit nonunique mode accepts solvable 4x4 level")
	var generated := PuzzleGenerator.generate(6, 42)
	check(generated.ok and screen.open_puzzle(generated.puzzle), "Generated level enters game through validation gate")
	check(screen.cells.size() == 36 and screen.get_node("Content/BoardAspect/Grid").columns == 6, "Grid supports configurable size")
	check(screen.get_node("Content/Status").text.contains("6 cats"), "Status uses configured cat count")
	for row in range(6):
		screen.cells[row * 6 + int(generated.puzzle.solution[row])].pressed.emit()
	check(screen.complete and screen.moves == 6, "Generated board completes through real cell signals")
	screen.get_node("Content/Actions/MenuButton").pressed.emit()
	check(app.current_screen.find_child("PlayButton", true, false) != null, "Menu navigation works")
	app.queue_free()
	await process_frame
	TestStorage.cleanup()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	await TestStorage.drain_audio()
	quit(1 if failures else 0)

func check_pair(a: Vector2i, b: Vector2i, expect_conflict: bool, description: String) -> void:
	var board := LevelData.empty_board(5)
	board[a.x][a.y] = PuzzleRules.CellState.CAT
	board[b.x][b.y] = PuzzleRules.CellState.CAT
	var result := PuzzleRules.evaluate(board, level.regions)
	check(result.conflicts.size() == (2 if expect_conflict else 0), description)
	check(not result.complete, description + " remains incomplete")

