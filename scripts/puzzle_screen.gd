extends MarginContainer

signal menu_requested
signal pause_requested
signal rules_requested
signal completed(puzzle_title: String, move_count: int)
signal restarted
signal restart_requested
signal progress_changed
signal hint_options_requested

const CELL := preload("res://scenes/grid_cell.tscn")
var level: Dictionary
var board: Array
var cells: Array[GridCell] = []
var moves := 0
var complete := false
var level_ready := false
var suspended := false
var selected_cell := Vector2i(-1, -1)
var session: PuzzleSession
var initial_session: PuzzleSession
var save_warning := ""

func _ready() -> void:
	MeowAudio.instance().set_cat_context(self)
	var tray := Control.new()
	tray.set_script(preload("res://scripts/board_mat.gd"))
	$Content/BoardAspect.add_child(tray)
	$Content/BoardAspect.move_child(tray, 0)
	for spec in [[%UndoButton, "undo"], [%HintButton, "hint"], [%EarnHintButton, "earn"]]:
		spec[0].set_script(preload("res://scripts/tactile_tool.gd"))
		spec[0].prepare(spec[1])
	$Content.move_child($Content/Tools, $Content/Actions.get_index())
	resized.connect(update_compact_layout)
	get_viewport().size_changed.connect(update_compact_layout)
	update_compact_layout()
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%UndoButton.pressed.connect(undo_action)
	%HintButton.pressed.connect(hint_action)
	%EarnHintButton.pressed.connect(func() -> void: hint_options_requested.emit())
	%MenuButton.pressed.connect(func() -> void: menu_requested.emit())
	%PauseButton.pressed.connect(func() -> void: pause_requested.emit())
	%RulesButton.pressed.connect(func() -> void: rules_requested.emit())
	if initial_session != null:
		open_puzzle(initial_session.puzzle, true, initial_session)
		return
	var loaded := LevelData.load_validated(LevelData.FIRST_PUZZLE)
	if not loaded.ok:
		show_level_error(loaded.errors)
		return
	open_puzzle(loaded.puzzle)

func update_compact_layout() -> void:
	var available_height := get_viewport().get_visible_rect().size.y
	var parent_margin := get_parent() as MarginContainer
	if parent_margin != null:
		available_height -= parent_margin.get_theme_constant("margin_top") + parent_margin.get_theme_constant("margin_bottom")
	var compact := available_height < 700
	for action in [%UndoButton, %HintButton, %EarnHintButton]:
		action.compact = compact
		action.custom_minimum_size.y = 52 if compact else 76
		action.queue_redraw()
	$Content/Rules.visible = not compact
	$Content/Instructions.visible = not compact
	%MoveCounter.add_theme_font_size_override("font_size", 12 if compact else 14)
	$Content.add_theme_constant_override("separation", 4 if compact else 8)
	%PuzzleTitle.add_theme_font_size_override("font_size", 21 if compact else 24)
	$Content/Rules.add_theme_font_size_override("font_size", 14 if compact else 15)
	$Content/Instructions.add_theme_font_size_override("font_size", 12 if compact else 13)
	%Status.add_theme_font_size_override("font_size", 14 if compact else 15)
	%Status.custom_minimum_size.y = 40 if compact else 48

func open_puzzle(candidate: Variant, require_unique: bool = true, saved_session: PuzzleSession = null) -> bool:
	# Public admission path also gates generated puzzles and future level selection.
	var admitted := LevelData.admit(candidate, require_unique)
	for cell in cells:
		%Grid.remove_child(cell)
		cell.queue_free()
	cells.clear()
	level_ready = false
	complete = false
	board = []
	level = {}
	if not admitted.ok:
		show_level_error(admitted.errors)
		return false
	level = admitted.puzzle
	session = saved_session
	if session == null:
		session = PuzzleSession.new()
		if not session.begin(level, PlayerPreferences.mistake_limits, require_unique):
			show_level_error(["Could not start this puzzle."])
			return false
	level_ready = true
	%RestartButton.disabled = false
	%PuzzleTitle.text = str(level.get("title", "Pastel Garden"))
	%Grid.columns = int(level["size"])
	for row in range(int(level["size"])):
		for column in range(int(level["size"])):
			var cell := CELL.instantiate() as GridCell
			%Grid.add_child(cell)
			cell.configure(row, column, PurrTheme.region_color(int(level["regions"][row][column]), int(level["size"])))
			cell.region_id = int(level.regions[row][column])
			cell.board_size = int(level.size)
			cell.region_edges = Vector4(1 if column == 0 or level.regions[row][column - 1] != cell.region_id else 0, 1 if row == 0 or level.regions[row - 1][column] != cell.region_id else 0, 1 if column == int(level.size) - 1 or level.regions[row][column + 1] != cell.region_id else 0, 1 if row == int(level.size) - 1 or level.regions[row + 1][column] != cell.region_id else 0)
			cell.cell_requested.connect(on_cell_requested)
			cells.append(cell)
	selected_cell = Vector2i(-1, -1)
	sync_session(false)
	return true

func show_level_error(errors: Array) -> void:
	level_ready = false
	%RestartButton.disabled = true
	%Status.text = "Puzzle unavailable: " + str(errors[0])
	%Status.tooltip_text = "\n".join(errors)
	%Status.add_theme_color_override("font_color", Color("a32c49"))
	%MoveCounter.text = "Choose Menu to return."

func restart() -> void:
	if not level_ready:
		return
	session.restart()
	complete = false
	suspended = false
	selected_cell = Vector2i(-1, -1)
	sync_session()
	restarted.emit()
	MeowAudio.instance().play_sfx("restart")

func on_cell_requested(row: int, column: int) -> void:
	if complete or suspended or not level_ready or row < 0 or column < 0 or row >= board.size() or column >= board.size():
		return
	selected_cell = Vector2i(row, column)
	var applied := session.cycle(row, column)
	if not applied.ok:
		%Status.text = applied.message
		MeowAudio.instance().play_sfx("invalid")
		return
	MeowAudio.instance().play_sfx("select")
	var evaluated := PuzzleRules.evaluate(session.board, level.regions)
	if evaluated.status == "invalid" and int(session.board[row][column]) == PuzzleRules.CellState.CAT:
		MeowAudio.instance().play_sfx("invalid")
	elif int(session.board[row][column]) == PuzzleRules.CellState.CAT:
		MeowAudio.instance().play_sfx("place")
		if not evaluated.complete:
			MeowAudio.instance().play_cat()
	else:
		MeowAudio.instance().play_sfx("mark" if int(session.board[row][column]) == PuzzleRules.CellState.EXCLUDED else "erase")
	sync_session()
	PlayerPreferences.tap_feedback(complete)

func undo_action() -> void:
	if suspended or not level_ready:
		return
	var result := session.undo()
	if result.ok:
		selected_cell = Vector2i(result.row, result.column)
		sync_session()
		MeowAudio.instance().play_sfx("undo")

func hint_action() -> void:
	if suspended or not level_ready:
		return
	if GameServices.hints == null:
		%Status.text = "Run the main scene (F5) to use saved hints."
		return
	var result := GameServices.hints.use_hint(session, GameServices.progression)
	if result.ok:
		selected_cell = Vector2i(result.row, result.column)
		MeowAudio.instance().play_sfx("hint")
		sync_session(false) # Inventory + session + reward ledger were saved together.
	else:
		sync_session(false)
		%Status.text = result.message
		if result.get("needs_hint", false):
			hint_options_requested.emit()

func sync_session(persist: bool = true) -> void:
	board = session.board
	moves = session.moves
	if persist:
		progress_changed.emit()
	update_board()

func update_board() -> void:
	var was_complete := complete
	var result := PuzzleRules.evaluate(board, level["regions"])
	complete = result["complete"]
	for cell in cells:
		cell.selected = selected_cell == Vector2i(cell.row, cell.column)
		cell.refresh(int(board[cell.row][cell.column]), result["conflicts"].has(Vector2i(cell.row, cell.column)))
		var cell_reasons: Array = result.reasons.get(Vector2i(cell.row, cell.column), [])
		if not cell_reasons.is_empty():
			cell.tooltip_text += "\n" + "\n".join(cell_reasons)
		cell.disabled = complete or session.is_exhausted()
	%MoveCounter.text = "Moves: %d  ·  Cats: %d/%d  ·  Mistakes: %s" % [moves, result["cat_count"], int(level["size"]), ("%d/%d" % [session.mistakes, session.mistake_limit()]) if session.mistake_limit() > 0 else str(session.mistakes)]
	%UndoButton.disabled = session.history.is_empty() or complete
	%HintButton.disabled = complete or session.is_exhausted()
	%HintButton.text = "Hint (%d)" % GameServices.hints.balance(str(level.get("id", ""))) if GameServices.hints != null else "Hint"
	%EarnHintButton.disabled = complete or session.is_exhausted()
	%Status.tooltip_text = "\n".join(result.messages)
	if complete:
		%Status.text = "Purrfect! Every cat has a place."
		%Status.add_theme_color_override("font_color", Color("327d65"))
	elif result.status == "invalid":
		%Status.text = "Conflict! " + str(result.messages[0])
		%Status.add_theme_color_override("font_color", Color("a32c49"))
	else:
		%Status.text = "No conflicts so far. Find a home for all %d cats." % int(level["size"])
		%Status.add_theme_color_override("font_color", PurrTheme.INK)
	if not session.last_message.is_empty() and not complete:
		%Status.text = session.last_message
	if session.is_exhausted():
		%Status.text = "Mistake limit reached. Restart or disable limits in Settings."
		%Status.add_theme_color_override("font_color", Color("a32c49"))
	if not save_warning.is_empty():
		%Status.text = save_warning
	if complete and not was_complete:
		MeowAudio.instance().play_sfx("complete")
		MeowAudio.instance().play_cat("chirp")
		completed.emit(str(level.get("title", "Your garden")), moves)

func audio_has_cats() -> bool:
	return level_ready and PuzzleRules.evaluate(board, level.regions).cat_count > 0 and not complete

