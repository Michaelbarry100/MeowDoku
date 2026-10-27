extends SceneTree

var checks := 0
var failures := 0
var prefix := "user://task4_tests/"
var catalog := LevelCatalog.new()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func fresh(name: String) -> PlayerSave:
	var path := prefix + name + ".json"
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var repository := PlayerSave.new(path)
	repository.load_file()
	return repository

func solve(session: PuzzleSession) -> void:
	for row in range(session.board.size()):
		if session.board[row][int(session.solution[row])] != 1:
			check(session.apply_state(row, int(session.solution[row]), 1).ok, "Solution placement accepted")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(prefix)
	check(catalog.load_collection().ok and catalog.levels.size() == LevelCatalog.CAMPAIGN_SIZE, "Exactly 150 curated puzzles admitted")
	for group in LevelCatalog.GROUPS:
		var count := 0
		for puzzle in catalog.levels:
			if puzzle.difficulty == group:
				count += 1
		check(count == CampaignDifficulty.GROUP_COUNTS[group], "Declared level count in " + group)
	var signatures: Dictionary = {}
	for puzzle in catalog.levels:
		check(PuzzleValidator.validate(puzzle).classification == "unique", "Every curated puzzle is uniquely solvable")
		signatures[LevelCatalog.signature(puzzle)] = true
	check(signatures.size() == LevelCatalog.CAMPAIGN_SIZE, "Collection has no duplicate normalized geometries")
	var repository := fresh("repository")
	check(repository.load_status == "missing" and repository.state.completed.is_empty(), "Missing save starts safely")
	repository.state.settings.haptics = true
	check(repository.commit() == OK, "Initial save succeeds")
	repository.state.active_id = "easy_01"
	check(repository.commit() == OK, "Atomic replacement succeeds")
	check(FileAccess.file_exists(repository.path + ".bak"), "Previous valid save retained as backup")
	var loaded := PlayerSave.new(repository.path)
	check(loaded.load_file().ok and loaded.state.active_id == "easy_01" and loaded.state.settings.haptics, "Versioned settings/state round trip")
	write(repository.path + ".tmp", "partial write")
	check(loaded.load_file().ok and loaded.state.active_id == "easy_01", "Interrupted temporary file does not replace primary")
	write(repository.path, "{broken")
	check(loaded.load_file().status == "recovered" and loaded.state.settings.haptics, "Corrupted primary recovers backup")
	check(loaded.commit() == OK and FileAccess.file_exists(repository.path + ".corrupt"), "Corrupt source preserved before replacement")
	write(repository.path, "bad")
	write(repository.path + ".bak", "bad")
	check(loaded.load_file().status == "corrupt" and loaded.state.sessions.is_empty(), "Both corrupt files fall back safely")
	check(loaded.commit() == OK, "Fresh save after corruption is possible")
	write(repository.path, JSON.stringify({"version": 999, "precious_future_data": true}))
	var before := FileAccess.get_file_as_string(repository.path)
	check(loaded.load_file().read_only and loaded.commit() != OK, "Unknown future version is read-only")
	check(FileAccess.get_file_as_string(repository.path) == before, "Future save is never overwritten")
	var future_backup := fresh("future_backup")
	write(future_backup.path + ".bak", JSON.stringify({"version": 999}))
	check(future_backup.load_file().read_only and future_backup.commit() != OK, "Future-version backup is also preserved")
	write(repository.path, JSON.stringify({"version": 1, "sessions": []}))
	check(not loaded.decode(repository.path).ok, "Wrong save section type rejected")
	write(repository.path, JSON.stringify({"version": 1, "settings": {"haptics": "true"}, "completed": {"fake": {"stars": 99}}, "unlocked": ["easy_01", 9, "easy_01"]}))
	var sanitized := loaded.decode(repository.path)
	check(sanitized.ok and not sanitized.state.settings.haptics and sanitized.state.completed.is_empty() and sanitized.state.unlocked.size() == 1, "Malformed optional values sanitized")

	var puzzle := catalog.get_level("easy_01")
	var session := PuzzleSession.new()
	check(session.begin(puzzle), "Independent session begins validated puzzle")
	check(not session.undo().ok, "Undo empty history is safe")
	check(not session.cycle(-1, 0).ok, "Session boundaries enforced")
	check(session.cycle(0, 0).ok and session.board[0][0] == 1, "Cat action recorded")
	check(session.cycle(0, 0).ok and session.board[0][0] == 2, "X action recorded")
	check(session.undo().ok and session.board[0][0] == 1 and session.moves == 1, "Undo X restores cat")
	check(session.undo().ok and session.board[0][0] == 0 and session.moves == 0, "Undo cat restores empty")
	session.cycle(0, 0)
	session.cycle(0, 1)
	check(session.mistakes == 1, "Conflicting cat increments mistake count once")
	session.undo()
	check(session.mistakes == 1, "Undo does not refund mistake")
	var hint := session.next_hint()
	check(hint.ok and hint.target == 0 and hint.row == 0 and hint.column == 0, "Hint identifies wrong cat before placing safe cat")
	check(session.use_hint().ok and session.board[0][0] == 0 and session.hints_used == 1, "Hint correction applied")
	session.undo()
	check(session.board[0][0] == 1 and session.hints_used == 1, "Undo hint restores board without refund")
	session.restart()
	session.cycle(0, int(session.solution[0]))
	session.cycle(0, int(session.solution[0]))
	check(session.board[0][int(session.solution[0])] == 2, "Correct solution cell may be marked X")
	check(session.use_hint().ok and session.board[0][int(session.solution[0])] == 1, "Hint safely replaces X with solution cat")
	while not session.is_complete():
		check(session.use_hint().ok, "Successive hints safely complete puzzle")
	check(not session.next_hint().ok and not session.undo().ok, "Completed session rejects further hints and undo")
	session.restart()
	check(session.moves == 0 and session.mistakes == 0 and session.hints_used == 0 and session.history.is_empty(), "Restart clears attempt counters/history")
	session.cycle(0, 0)
	session.cycle(1, 2)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.snapshot()))
	var restored := PuzzleSession.new()
	restored.begin(puzzle)
	check(restored.restore(snapshot) and restored.board == session.board and restored.history.size() == 2, "JSON session reload preserves board and undo")
	check(restored.undo().ok and restored.board[1][2] == 0, "Undo works after reload")
	var broken := snapshot.duplicate(true)
	broken.signature = "wrong"
	check(not restored.restore(broken), "Changed puzzle definition cannot reuse saved board")
	broken = snapshot.duplicate(true)
	broken.history[0].after = 2
	check(restored.restore(broken) and restored.history.is_empty(), "Damaged undo stack discarded while preserving board")
	broken.board = [[0]]
	check(not restored.restore(broken), "Malformed saved board rejected")
	var hard := catalog.get_level("hard_01")
	session.begin(hard, true)
	check(session.mistake_limit() == 3, "Hard optional mistake budget")
	for attempt in range(3):
		session.apply_state(0, 0, 1)
		session.apply_state(0, 1, 1)
		session.undo()
		session.undo()
	check(session.mistakes == 3 and session.is_exhausted() and not session.cycle(0, 0).ok, "Budget persists through undo and blocks new actions")
	session.limits_enabled = false
	check(session.cycle(0, 0).ok, "Disabling limits allows continuing same board")
	for group in LevelCatalog.GROUPS:
		var candidate := puzzle.duplicate(true)
		candidate.difficulty = group
		session.begin(candidate, true)
		check(session.mistake_limit() == PuzzleSession.LIMITS[group], "Difficulty-based limit: " + group)

	var progress_save := fresh("progress")
	var progress := ProgressionService.new(catalog, progress_save)
	check(progress.unlocked("easy_01") and not progress.unlocked("easy_02"), "Only first campaign level unlocked initially")
	check(progress.open_session("easy_02") == null and progress.open_session("unknown") == null, "Locked and unknown IDs cannot open")
	var play := progress.open_session("easy_01")
	play.cycle(0, 0)
	check(progress.record(play).ok and progress.resume_id() == "easy_01", "Unfinished session saved and resumable")
	var reopened_save := PlayerSave.new(progress_save.path)
	reopened_save.load_file()
	var reopened := ProgressionService.new(catalog, reopened_save)
	var resumed := reopened.open_session(reopened.resume_id())
	check(resumed != null and resumed.board[0][0] == 1 and resumed.history.size() == 1, "New repository/service resumes after app reopening")
	check(resumed.undo().ok, "Reloaded campaign session can undo")
	resumed.restart()
	solve(resumed)
	var first_reward := reopened.record(resumed)
	check(first_reward.ok and first_reward.awarded and first_reward.stars == 3, "First clean completion awards three stars")
	check(reopened.unlocked("easy_02") and reopened.total_stars() == 3, "Completion unlocks next level")
	check(not reopened.record(resumed).awarded and reopened.total_stars() == 3, "Repeated completion signal never duplicates reward")
	var replay := reopened.open_session("easy_01", true)
	solve(replay)
	check(not reopened.record(replay).awarded and reopened.total_stars() == 3, "Replay never awards same level again")
	var reward_save := fresh("rewards")
	var rewards := ProgressionService.new(catalog, reward_save)
	var assisted := rewards.open_session("easy_01")
	assisted.use_hint()
	assisted.undo()
	rewards.record(assisted)
	check(rewards.resume_id() == "easy_01" and assisted.moves == 0 and assisted.hints_used == 1, "Zero-move attempt with hint history remains resumable")
	assisted.restart()
	assisted.use_hint()
	solve(assisted)
	check(rewards.record(assisted).stars == 2, "One hint gives two first-clear stars")
	var cleaner := rewards.open_session("easy_01", true)
	solve(cleaner)
	check(not rewards.record(cleaner).awarded and rewards.total_stars() == 2, "Better replay cannot increase first-clear reward")
	var heavily_assisted := rewards.open_session("easy_02")
	while not heavily_assisted.is_complete():
		heavily_assisted.use_hint()
	check(rewards.record(heavily_assisted).stars == 1, "Repeated hints give one first-clear star")
	var saved_first := reopened.open_session("easy_02")
	saved_first.cycle(1, 2)
	reopened.record(saved_first)
	var another := reopened.open_session("easy_01", true)
	another.cycle(2, 0)
	reopened.record(another)
	check(reopened.open_session("easy_02").board[1][2] == 1, "Switching puzzles retains both boards")
	for i in range(1, catalog.levels.size()):
		var id: String = catalog.levels[i].id
		var next := reopened.open_session(id, true)
		check(next != null, "Sequentially unlocked level is playable")
		solve(next)
		check(reopened.record(next).awarded, "Each level awards once")
	check(reopened.total_stars() == 3 * LevelCatalog.CAMPAIGN_SIZE and catalog.next_id(catalog.levels.back().id).is_empty(), "All 150 campaign levels progress to final completion")
	var date := "2026-10-26"
	var daily := reopened.daily(date)
	var fresh_daily := DailyPuzzle.select(date, catalog)
	check(daily.ok and daily.puzzle.source_id == fresh_daily.puzzle.source_id, "Daily selected from date and stored puzzle/catalog seeds")
	check(daily.puzzle == reopened.daily(date).puzzle, "Repeated daily selection stable")
	var after_restart := PlayerSave.new(progress_save.path)
	after_restart.load_file()
	var daily_progress := ProgressionService.new(catalog, after_restart)
	check(daily_progress.daily(date).puzzle.source_id == daily.puzzle.source_id, "Daily selection stable after file reload")
	var daily_session := daily_progress.open_session("daily_" + date)
	daily_session.cycle(0, 0)
	daily_progress.record(daily_session)
	check(daily_progress.open_session("daily_" + date).board[0][0] == 1, "Daily progress resumes")
	daily_session.restart()
	solve(daily_session)
	check(daily_progress.record(daily_session).awarded, "Daily completion earns its own reward")
	var total := daily_progress.total_stars()
	check(not daily_progress.record(daily_session).awarded and daily_progress.total_stars() == total, "Daily reward cannot be farmed")
	for invalid_date in ["", "2026-2-03", "2026-02-30", "2026-13-01", "2025-02-29", "abcd-10-26", "+026-01-01", "2026-+1-01"]:
		check(not DailyPuzzle.select(invalid_date, catalog).ok, "Invalid daily date rejected")
	check(DailyPuzzle.valid_date("2024-02-29") and not DailyPuzzle.valid_date("1900-02-29"), "Leap-year date handling")
	var variants: Dictionary = {}
	for day in range(1, 29):
		variants[DailyPuzzle.select("2026-10-%02d" % day, catalog).puzzle.source_id] = true
	check(variants.size() > 1, "Daily puzzle varies across dates")
	print("RESULT: %d progression/save/session checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
