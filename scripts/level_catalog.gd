class_name LevelCatalog
extends RefCounted

const PATH := "res://data/catalog/collection.json"
const GROUPS := ["Easy", "Medium", "Hard", "Expert"]
const CAMPAIGN_SIZE := 150
var levels: Array[Dictionary] = []
var daily_seed := ""
var daily_pool: Array[Dictionary] = []

func load_collection(path: String = PATH) -> Dictionary:
	levels.clear()
	daily_pool.clear()
	daily_seed = ""
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["Level collection is missing."]}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "errors": ["Level collection JSON is invalid."]}
	var raw: Variant = parser.data
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("levels") is Array or not raw.get("daily_seed") is String:
		return {"ok": false, "errors": ["Invalid level collection manifest."]}
	var ids: Dictionary = {}
	var geometries: Dictionary = {}
	var counts := {"Easy": 0, "Medium": 0, "Hard": 0, "Expert": 0}
	var candidates: Array[Dictionary] = []
	for entry in raw.levels:
		if not entry is Dictionary or not entry.get("path") is String:
			return {"ok": false, "errors": ["Invalid collection entry."]}
		var loaded := LevelData.load_validated(entry.path)
		if not loaded.ok:
			return loaded
		var puzzle: Dictionary = loaded.puzzle
		var id: String = str(puzzle.get("id", ""))
		var group: String = str(puzzle.get("difficulty", ""))
		var symmetry := CampaignDifficulty.symmetry_signature(puzzle)
		if id.is_empty() or ids.has(id) or geometries.has(symmetry) or not GROUPS.has(group) or not puzzle.get("seed") is String or not PuzzleRules.is_integer(puzzle.get("order")) or int(puzzle.order) != candidates.size() + 1:
			return {"ok": false, "errors": ["Duplicate or invalid curated level metadata."]}
		ids[id] = true
		geometries[symmetry] = true
		counts[group] += 1
		candidates.append(puzzle)
	if candidates.size() != CAMPAIGN_SIZE or counts != CampaignDifficulty.GROUP_COUNTS:
		return {"ok": false, "errors": ["Campaign requires exactly 150 puzzles in the declared difficulty groups."]}
	if not raw.get("daily_pool") is Array or raw.daily_pool.is_empty():
		return {"ok": false, "errors": ["Daily puzzle pool is missing."]}
	var daily_ids: Dictionary = {}
	for id in raw.daily_pool:
		if not id is String or not ids.has(id) or daily_ids.has(id):
			return {"ok": false, "errors": ["Invalid daily puzzle source."]}
		daily_ids[id] = true
		for puzzle in candidates:
			if puzzle.id == id:
				daily_pool.append(puzzle)
	levels = candidates
	daily_seed = raw.daily_seed
	return {"ok": true, "errors": []}

static func signature(puzzle: Dictionary) -> String:
	# Normalize arbitrary region numbering and JSON number types.
	var ids: Dictionary = {}
	var values := str(int(puzzle.size)) + ":"
	for row in puzzle.regions:
		for value in row:
			var id := int(value)
			if not ids.has(id):
				ids[id] = ids.size()
			values += str(ids[id]) + ","
	return values.sha256_text()

func get_level(id: String) -> Dictionary:
	for puzzle in levels:
		if puzzle.id == id:
			return puzzle.duplicate(true)
	return {}

func next_id(id: String) -> String:
	for i in range(levels.size() - 1):
		if levels[i].id == id:
			return levels[i + 1].id
	return ""
