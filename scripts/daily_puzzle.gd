class_name DailyPuzzle
extends RefCounted

static func valid_date(date: String) -> bool:
	var parts := date.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part in parts:
		for character in part:
			if character < "0" or character > "9":
				return false
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1 or month < 1 or month > 12:
		return false
	var days := [31, 29 if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day >= 1 and day <= days[month - 1]

static func select(date: String, catalog: LevelCatalog) -> Dictionary:
	if not valid_date(date) or catalog.levels.is_empty() or catalog.daily_pool.is_empty():
		return {"ok": false, "errors": ["Daily date or collection is invalid."]}
	var best := "~"
	var chosen: Dictionary = {}
	for puzzle in catalog.daily_pool:
		var score := (date + "|" + catalog.daily_seed + "|" + str(puzzle.seed) + "|" + str(puzzle.id)).sha256_text()
		if score < best:
			best = score
			chosen = puzzle.duplicate(true)
	chosen.source_id = chosen.id
	chosen.id = "daily_" + date
	chosen.title = "Daily Garden"
	chosen.daily_date = date
	return {"ok": true, "puzzle": chosen, "errors": []}
