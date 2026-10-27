extends SceneTree
## Release gate: every level, every hint, full UI progression and legacy saves.
var checks := 0
var failures := 0
var app: Control
var capture := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(4):
		await process_frame

func shot(name: String) -> void:
	if not capture:
		return
	await create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/campaign")
	check(root.get_texture().get_image().save_png("res://artifacts/campaign/" + name + ".png") == OK, "Capture " + name)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("campaign150")
	capture = "--capture" in OS.get_cmdline_user_args()
	MeowAudio.instance().set_muted(true)
	var catalog := LevelCatalog.new()
	check(catalog.load_collection().ok and catalog.levels.size() == 150, "Exactly 150 validated campaign levels")
	if catalog.levels.size() != 150:
		await finish()
		return
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_campaign_v1.json"))
	var seen: Dictionary = {}
	var last_score := -1
	for index in range(catalog.levels.size()):
		var puzzle: Dictionary = catalog.levels[index]
		var validation := PuzzleValidator.validate(puzzle)
		check(validation.valid and validation.classification == "unique" and validation.search.exhaustive, "Unique proof " + puzzle.id)
		check(int(puzzle.order) == index + 1, "Contiguous campaign order")
		var key := CampaignDifficulty.symmetry_signature(puzzle)
		check(not seen.has(key), "No normalized/rotated/reflected duplicate")
		seen[key] = true
		if index >= 2:
			var metrics := CampaignDifficulty.measure(puzzle)
			check(int(metrics.score) == int(puzzle.curation.score) and int(metrics.singletons) == int(puzzle.curation.singletons) and int(metrics.solver_nodes) == int(puzzle.curation.solver_nodes) and metrics.score >= last_score, "Measured nondecreasing difficulty")
			check(CampaignDifficulty.group_for(metrics.score) == puzzle.difficulty, "Difficulty band")
			last_score = metrics.score
		var session := PuzzleSession.new()
		check(session.begin(puzzle, true), "Each level loads with mistake limits enabled")
		var wrong_column := (int(session.solution[0]) + 1) % int(puzzle.size)
		session.apply_state(0, wrong_column, 1)
		check(session.next_hint().target == 0, "Hint corrects a wrong cat before adding another")
		check(session.use_hint().ok and session.board[0][wrong_column] == 0, "Hint clears wrong cat")
		check(session.undo().ok and session.board[0][wrong_column] == 1, "Hint correction can be undone")
		session.restart()
		session.apply_state(0, int(session.solution[0]), 2)
		check(session.use_hint().ok and session.board[0][int(session.solution[0])] == 1, "Hint safely replaces a solution-cell X")
		check(session.undo().ok and session.board[0][int(session.solution[0])] == 2, "Undo restores an X marker")
		for step in range(int(puzzle.size)):
			var hint := session.next_hint()
			check(hint.ok and hint.target == 1 and hint.column == int(session.solution[hint.row]), "Hint matches the unique solution")
			check(session.use_hint().ok and PuzzleRules.evaluate(session.board, puzzle.regions).status != "invalid", "Each hint preserves every rule")
		check(session.is_complete() and not session.next_hint().ok, "Hints complete each level exactly")
	for old in legacy.levels:
		var current: Dictionary = catalog.get_level(old.id)
		var reference: Dictionary = old.duplicate(true)
		current.erase("order")
		reference.erase("order")
		check(current == reference, "Original data retained except display order: " + str(old.id))
	test_migration(catalog, legacy)
	var old_catalog := LevelCatalog.new()
	old_catalog.levels.assign(legacy.levels)
	old_catalog.daily_pool.assign(legacy.levels)
	old_catalog.daily_seed = legacy.daily_seed
	for month in range(1, 13):
		for day in [1, 10, 20, 28]:
			var date := "2026-%02d-%02d" % [month, day]
			var daily := DailyPuzzle.select(date, catalog)
			check(daily.ok and daily.puzzle.source_id == DailyPuzzle.select(date, old_catalog).puzzle.source_id, "Daily source stable across campaign expansion")
			check(daily.puzzle.id.begins_with("daily_") and catalog.get_level(daily.puzzle.id).is_empty(), "Daily is separate from campaign")
	print("CAMPAIGN: all 150 proof/hint/migration checks finished; failures ", failures)
	if failures > 0:
		await finish()
		return
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.show_page("levels")
	await settle()
	var page: Control = app.current_screen
	var body: VBoxContainer = page.find_child("LevelCards", true, false)
	var displayed: Dictionary = {}
	for group in LevelCatalog.GROUPS:
		page.render_group(group, body)
		await settle()
		var buttons := body.find_children("Level*Button", "Button", true, false)
		check(buttons.size() == CampaignDifficulty.GROUP_COUNTS[group], "Actual level-selection count in " + group)
		for button in buttons:
			displayed[button.name] = true
			check(button.disabled == (button.name != "Level01Button"), "Fresh profile locks all but first level")
		await shot("selection-" + group.to_lower())
	check(displayed.size() == 150, "Every real campaign entry is selectable or locked")
	var previous: Control = app.current_screen
	app.show_puzzle(catalog.levels.back().id)
	check(app.current_screen == previous, "Normal navigation cannot open locked level 150")
	app.show_puzzle("easy_01")
	await settle()
	# Serialize and reopen an unfinished board through the actual app composition.
	app.current_screen.cells[int(app.current_screen.session.solution[0])].pressed.emit()
	var board: Array = app.current_screen.board.duplicate(true)
	app.queue_free()
	await settle()
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var resume: Button = app.current_screen.find_child("PlayButton", true, false)
	check(resume.text.contains("Resume"), "Relaunch offers unfinished puzzle")
	resume.pressed.emit()
	await settle()
	check(app.current_screen.board == board, "Relaunch preserves true board state")
	for index in range(150):
		var screen: Control = app.current_screen
		var puzzle: Dictionary = catalog.levels[index]
		check(screen.level.id == puzzle.id and screen.cells.size() == 25, "Full board loads at campaign level " + str(index + 1))
		for viewport_size in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(430, 932)]:
			root.size = viewport_size
			root.content_scale_size = viewport_size
			await settle()
			var grid: GridContainer = screen.get_node("Content/BoardAspect/Grid")
			check(screen.cells[0].size.x >= 48 and screen.cells[0].size.y >= 48, "48-unit targets on each campaign board")
			check(grid.get_global_rect().position.x >= 16 and grid.get_global_rect().end.x <= viewport_size.x - 16, "Each board fits portrait width")
			check(screen.get_node("Content/Actions/RestartButton").get_global_rect().end.y <= viewport_size.y - 16, "Each board keeps actions inside safe content")
		root.size = Vector2i(390, 844)
		root.content_scale_size = root.size
		await settle()
		if index in [0, 37, 75, 112, 149]:
			await shot("level-%03d" % (index + 1))
		for row in range(5):
			var column := int(screen.session.solution[row])
			if screen.board[row][column] != 1:
				screen.cells[row * 5 + column].pressed.emit()
		await settle()
		check(screen.complete and PuzzleRules.evaluate(screen.board, screen.level.regions).complete, "Every level wins only after every rule passes")
		check(app.overlay != null and app.overlay.name == "Victory", "Victory screen for every level")
		var saved := PlayerSave.new(GameServices.save_path)
		check(saved.load_file().ok and saved.state.completed.size() == index + 1, "Every completion persists")
		if index < 149:
			check(saved.state.unlocked.has(catalog.levels[index + 1].id), "Every next level persists unlocked")
			check(GameServices.progression.unlocked("easy_01"), "Earlier levels remain accessible")
			var next: Button = app.overlay.find_child("NextButton", true, false)
			check(next != null and not next.disabled, "Next Level works through campaign")
			next.pressed.emit()
			await settle()
		else:
			check(app.overlay.find_child("NextButton", true, false).disabled, "Level 150 has no nonexistent next level")
			await shot("level-150-victory")
		if (index + 1) % 25 == 0:
			print("CAMPAIGN_UI: ", index + 1, "/150 completed, saved and unlocked")
	check(GameServices.progression.total_stars() == 450, "All 150 first-clear rewards awarded once")
	var stars := GameServices.progression.total_stars()
	app.persist_current()
	check(GameServices.progression.total_stars() == stars, "Repeated persistence cannot duplicate rewards")
	app.show_page("levels")
	await settle()
	page = app.current_screen
	body = page.find_child("LevelCards", true, false)
	for group in LevelCatalog.GROUPS:
		page.render_group(group, body)
		await settle()
		for button in body.find_children("Level*Button", "Button", true, false):
			check(not button.disabled, "All 150 cleared levels accessible from selection")
	await shot("all-levels-unlocked")
	var last_button: Button = page.find_child("Level150Button", true, false)
	var scroll: ScrollContainer = page.get_node("Scroll")
	scroll.ensure_control_visible(last_button)
	await settle()
	check(scroll.get_global_rect().has_point(last_button.get_global_rect().get_center()), "Level 150 can be reached by scrolling the real selection screen")
	await shot("selection-level-150")
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = last_button.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
	check(app.current_screen.has_method("on_cell_requested") and app.current_screen.level.id == catalog.levels.back().id, "Real pointer opens selected level 150")
	app.queue_free()
	await settle()
	var final_saved := PlayerSave.new(GameServices.save_path)
	final_saved.load_file()
	var final_progress := ProgressionService.new(catalog, final_saved)
	check(final_saved.state.completed.size() == 150 and final_saved.state.unlocked.size() == 150 and final_progress.total_stars() == 450, "Full progression survives restart")
	await finish()

func test_migration(catalog: LevelCatalog, legacy: Dictionary) -> void:
	var path := GameServices.save_path + ".migration"
	var repository := PlayerSave.new(path)
	for index in range(12):
		var old: Dictionary = legacy.levels[index]
		repository.state.unlocked.append(old.id)
		if index < 11:
			repository.state.completed[old.id] = {"stars": 3, "best_moves": 5, "mistakes": 0, "hints": 0}
	var active: Dictionary = legacy.levels[11]
	var session := PuzzleSession.new()
	session.begin(active)
	session.apply_state(0, int(session.solution[0]), 1)
	session.apply_state(0, (int(session.solution[0]) + 1) % 5, 2)
	repository.state.sessions[active.id] = session.snapshot()
	repository.state.active_id = active.id
	repository.state.settings.music_enabled = false
	repository.state.hint_inventory.free_used[active.id] = 2
	check(repository.commit() == OK, "Legacy-shaped save written in isolated test storage")
	var loaded := PlayerSave.new(path)
	loaded.load_file()
	var progress := ProgressionService.new(catalog, loaded)
	var frontier := int(catalog.get_level(active.id).order)
	for index in range(frontier):
		check(progress.unlocked(catalog.levels[index].id), "Expansion preserves old frontier including inserted earlier levels")
	var resumed := progress.open_session(active.id)
	check(resumed != null and resumed.board == session.board and resumed.history.size() == session.history.size(), "Old board and X/undo history survive changed display order")
	if resumed != null:
		for index in range(resumed.history.size()):
			for field in ["row", "column", "before", "after"]:
				check(int(resumed.history[index][field]) == int(session.history[index][field]), "Old undo entry has identical meaning after JSON reload")
	check(progress.total_stars() == 33 and not loaded.state.settings.music_enabled and loaded.state.hint_inventory.free_used[active.id] == 2, "Existing rewards, audio choice and hint allowance preserved")
	check(resumed.undo().ok and resumed.board[0][(int(resumed.solution[0]) + 1) % 5] == 0, "Old undo stack remains usable")
	progress.persist()
	var again := PlayerSave.new(path)
	again.load_file()
	check(again.state.unlocked.size() == loaded.state.unlocked.size(), "Migrated unlocks persist")
	# A player who cleared the original 32 keeps all earned rewards and old access.
	var full := PlayerSave.new(GameServices.save_path + ".fulllegacy")
	for old in legacy.levels:
		full.state.unlocked.append(old.id)
		full.state.completed[old.id] = {"stars": 3, "best_moves": 5, "mistakes": 0, "hints": 0}
	var upgraded := ProgressionService.new(catalog, full)
	for old in legacy.levels:
		check(upgraded.unlocked(old.id), "Every formerly unlocked ID remains accessible")
	check(upgraded.total_stars() == 96 and full.state.completed.size() == 32 and not full.state.completed.has(upgraded.next_playable()), "Expansion never invents completion rewards for new content")
	for suffix in [".migration", ".migration.bak", ".migration.tmp"]:
		if FileAccess.file_exists(GameServices.save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GameServices.save_path + suffix))

func finish() -> void:
	TestStorage.cleanup()
	await TestStorage.drain_audio()
	print("RESULT: %d campaign checks, %d failures; 150 levels tested" % [checks, failures])
	quit(1 if failures else 0)
