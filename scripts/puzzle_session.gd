class_name PuzzleSession
extends RefCounted
## Serializable gameplay state only; no UI, file access, or progression rewards.

const LIMITS := {"Easy": 0, "Medium": 5, "Hard": 3, "Expert": 2}
const HISTORY_LIMIT := 2000
var puzzle: Dictionary
var board: Array
var solution: Array
var history: Array = []
var moves := 0
var mistakes := 0
var hints_used := 0
var limits_enabled := false
var last_message := ""

func begin(candidate: Dictionary, use_limits: bool = false, require_unique: bool = true) -> bool:
	if not PuzzleValidator.validate(candidate, require_unique).valid:
		return false
	puzzle = candidate.duplicate(true)
	board = PuzzleRules.empty_board(int(puzzle.size))
	solution = PuzzleSolver.solve(puzzle.regions, 1).solutions[0].duplicate()
	limits_enabled = use_limits
	history.clear()
	moves = 0
	mistakes = 0
	hints_used = 0
	return true

func is_complete() -> bool:
	return PuzzleRules.evaluate(board, puzzle.regions).complete

func mistake_limit() -> int:
	return int(LIMITS.get(puzzle.get("difficulty", "Easy"), 0)) if limits_enabled else 0

func is_exhausted() -> bool:
	return mistake_limit() > 0 and mistakes >= mistake_limit() and not is_complete()

func cycle(row: int, column: int) -> Dictionary:
	if not inside(row, column):
		return {"ok": false, "message": "Cell is outside this puzzle."}
	return apply_state(row, column, (int(board[row][column]) + 1) % 3)

func inside(row: int, column: int) -> bool:
	return row >= 0 and column >= 0 and row < board.size() and column < board.size()

func apply_state(row: int, column: int, target: int, hint_action: bool = false) -> Dictionary:
	if not inside(row, column) or target < 0 or target > 2 or is_complete() or is_exhausted():
		return {"ok": false, "message": "Restart or turn off mistake limits to keep playing." if is_exhausted() else "Action is unavailable."}
	var previous := int(board[row][column])
	if previous == target:
		return {"ok": false, "message": "Cell is already in that state."}
	history.append({"row": row, "column": column, "before": previous, "after": target})
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	board[row][column] = target
	moves += 1
	var result := PuzzleRules.evaluate(board, puzzle.regions)
	if target == PuzzleRules.CellState.CAT and result.conflicts.has(Vector2i(row, column)):
		mistakes += 1
	if hint_action:
		hints_used += 1
	last_message = ""
	return {"ok": true, "row": row, "column": column}

func undo() -> Dictionary:
	if history.is_empty() or is_complete():
		return {"ok": false, "message": "No move to undo."}
	var action: Dictionary = history.pop_back()
	board[int(action.row)][int(action.column)] = int(action.before)
	moves = maxi(0, moves - 1)
	# Mistakes and hints belong to the attempt, and cannot be refunded by undo.
	last_message = "Previous cell change undone."
	return {"ok": true, "row": int(action.row), "column": int(action.column)}

func next_hint() -> Dictionary:
	if is_complete() or is_exhausted():
		return {"ok": false, "message": "Restart or disable mistake limits before asking for a hint."}
	# Correct wrong cats before adding a solution cat, so a hint never introduces
	# a collision with an existing placement. X notes may be safely replaced.
	for row in range(board.size()):
		for column in range(board.size()):
			if board[row][column] == 1 and column != int(solution[row]):
				return {"ok": true, "row": row, "column": column, "target": 0, "message": "Clear the cat at row %d, column %d; it blocks the solution." % [row + 1, column + 1]}
	for row in range(board.size()):
		var column := int(solution[row])
		if board[row][column] != 1:
			return {"ok": true, "row": row, "column": column, "target": 1, "message": "A safe home: row %d, column %d." % [row + 1, column + 1]}
	return {"ok": false, "message": "Every cat is home."}

func use_hint() -> Dictionary:
	var hint := next_hint()
	if not hint.ok:
		return hint
	var applied := apply_state(hint.row, hint.column, hint.target, true)
	if applied.ok:
		last_message = hint.message
		hint["applied"] = true
	return hint if applied.ok else applied

func restart() -> void:
	board = PuzzleRules.empty_board(int(puzzle.size))
	history.clear()
	moves = 0
	mistakes = 0
	hints_used = 0
	last_message = "A fresh garden."

func snapshot() -> Dictionary:
	return {"version": 1, "signature": LevelCatalog.signature(puzzle), "board": board.duplicate(true), "history": history.duplicate(true), "moves": moves, "mistakes": mistakes, "hints": hints_used}

func restore(saved: Variant) -> bool:
	if not saved is Dictionary or saved.get("version") != 1 or saved.get("signature") != LevelCatalog.signature(puzzle):
		return false
	if not PuzzleRules.validate_board(saved.get("board"), int(puzzle.size)).is_empty():
		return false
	for key in ["moves", "mistakes", "hints"]:
		if not PuzzleRules.is_integer(saved.get(key)) or saved[key] < 0 or saved[key] > 1000000:
			return false
	board = saved.board.duplicate(true)
	for row in range(board.size()):
		for column in range(board.size()):
			board[row][column] = int(board[row][column])
	moves = int(saved.moves)
	mistakes = int(saved.mistakes)
	hints_used = int(saved.hints)
	history.clear()
	if not saved.get("history") is Array or saved.history.size() > HISTORY_LIMIT or saved.history.size() > moves:
		return true # Preserve board/counters even if undo metadata is damaged.
	var scratch := board.duplicate(true)
	for i in range(saved.history.size() - 1, -1, -1):
		var action: Variant = saved.history[i]
		if not action is Dictionary:
			return true
		for key in ["row", "column", "before", "after"]:
			if not PuzzleRules.is_integer(action.get(key)):
				return true
		if not inside(int(action.row), int(action.column)) or action.before < 0 or action.before > 2 or action.after < 0 or action.after > 2 or action.before == action.after or scratch[int(action.row)][int(action.column)] != action.after:
			return true
		scratch[int(action.row)][int(action.column)] = int(action.before)
	if saved.history.size() == moves and scratch != PuzzleRules.empty_board(int(puzzle.size)):
		return true
	history = saved.history.duplicate(true)
	return true
