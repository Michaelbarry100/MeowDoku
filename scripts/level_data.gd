class_name LevelData
extends RefCounted

const FIRST_PUZZLE := "res://data/first_puzzle.json"

static func load_first() -> Dictionary:
	var loaded := load_validated(FIRST_PUZZLE)
	if not loaded.ok:
		return {}
	return loaded.puzzle

static func load_validated(path: String, require_unique: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "puzzle": {}, "errors": ["Puzzle file was not found: " + path]}
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		return {"ok": false, "puzzle": {}, "errors": ["Puzzle JSON is invalid at line %d: %s" % [json.get_error_line(), json.get_error_message()]]}
	return admit(json.data, require_unique)

static func admit(puzzle: Variant, require_unique: bool = true) -> Dictionary:
	var validation := PuzzleValidator.validate(puzzle, require_unique)
	return {"ok": validation.valid, "puzzle": puzzle.duplicate(true) if validation.valid else {}, "errors": validation.errors, "validation": validation}

static func empty_board(size: int) -> Array:
	return PuzzleRules.empty_board(size)
