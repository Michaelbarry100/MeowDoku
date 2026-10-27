class_name PuzzleValidator
extends RefCounted
## Admission gate for both authored and generated puzzles.

static func validate(puzzle: Variant, require_unique: bool = true, max_nodes: int = 100000) -> Dictionary:
	var result := {"valid": false, "errors": [], "classification": "invalid", "search": {}}
	if not puzzle is Dictionary:
		result.errors = ["Puzzle must be an object."]
		return result
	var size: Variant = puzzle.get("size")
	if not PuzzleRules.is_integer(size) or size < 1 or size > PuzzleRules.MAX_SIZE:
		result.errors = ["Puzzle size must be a whole number from 1 to %d." % PuzzleRules.MAX_SIZE]
		return result
	var layout := PuzzleRules.validate_layout(puzzle.get("regions"))
	if not layout.valid:
		result.errors = layout.errors
		return result
	if layout.size != int(size):
		result.errors = ["Puzzle size does not match its region map."]
		return result
	if puzzle.has("solution"):
		var reference: Variant = puzzle.solution
		if not reference is Array or reference.size() != int(size):
			result.errors = ["Reference solution must contain one column per row."]
			return result
		var board := PuzzleRules.empty_board(int(size))
		for row in range(int(size)):
			if not PuzzleRules.is_integer(reference[row]) or reference[row] < 0 or reference[row] >= size:
				result.errors = ["Reference solution has an invalid column."]
				return result
			board[row][int(reference[row])] = PuzzleRules.CellState.CAT
		if not PuzzleRules.evaluate(board, puzzle.regions).complete:
			result.errors = ["Reference solution violates the puzzle rules."]
			return result
	var search := PuzzleSolver.solve(puzzle.regions, 2, null, max_nodes)
	result.search = search
	if not search.errors.is_empty():
		result.errors = search.errors
	elif search.count >= 2:
		result.classification = "multiple"
		result.valid = not require_unique
		if require_unique:
			result.errors = ["Puzzle has multiple solutions; a unique solution is required."]
	elif search.count == 1 and search.exhaustive:
		result.classification = "unique"
		result.valid = true
	elif search.budget_exceeded:
		result.classification = "unproven"
		result.valid = search.count > 0 and not require_unique
		if not result.valid:
			result.errors = ["Search budget exhausted; solvability or uniqueness could not be proven."]
	else:
		result.classification = "unsolvable"
		result.errors = ["Puzzle has no solution."]
	return result
