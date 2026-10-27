class_name ProgressionService
extends RefCounted

var catalog: LevelCatalog
var save: PlayerSave
var notice := ""

func _init(levels: LevelCatalog, repository: PlayerSave) -> void:
	catalog = levels
	save = repository
	if not catalog.levels.is_empty() and not save.state.unlocked.has(catalog.levels[0].id):
		save.state.unlocked.append(catalog.levels[0].id)
	# Repair unlocks derived from valid completed records, without deleting saves.
	for id in save.state.completed:
		var next := catalog.next_id(id)
		if not next.is_empty() and not save.state.unlocked.has(next):
			save.state.unlocked.append(next)
	# Campaign expansion inserts new boards between stable old IDs. Preserve the
	# player's unlocked frontier, including all newly inserted earlier levels.
	var frontier := 0
	for index in range(catalog.levels.size()):
		if save.state.unlocked.has(catalog.levels[index].id):
			frontier = maxi(frontier, index)
	for index in range(mini(frontier + 1, catalog.levels.size())):
		var id: String = catalog.levels[index].id
		if not save.state.unlocked.has(id):
			save.state.unlocked.append(id)
	if save.load_status == "recovered":
		notice = "Recovered your last backup."
	elif save.load_status == "corrupt":
		notice = "Save could not be read. A fresh local save is ready."
	elif save.read_only:
		notice = "Save is unavailable or from a newer version. Playing without overwriting it."

func unlocked(id: String) -> bool:
	return not catalog.get_level(id).is_empty() and save.state.unlocked.has(id)

func daily(date: String) -> Dictionary:
	if save.state.dailies.has(date):
		var cached: Dictionary = save.state.dailies[date]
		if cached.get("daily_date") == date and cached.get("id") == "daily_" + date and PuzzleValidator.validate(cached).valid:
			return {"ok": true, "puzzle": cached.duplicate(true), "errors": []}
	var selected := DailyPuzzle.select(date, catalog)
	if selected.ok:
		save.state.dailies[date] = selected.puzzle.duplicate(true)
		persist()
	return selected

func puzzle_for(id: String) -> Dictionary:
	var authored := catalog.get_level(id)
	if not authored.is_empty():
		return authored
	if id.begins_with("daily_"):
		var date := id.trim_prefix("daily_")
		if DailyPuzzle.valid_date(date):
			var selected := daily(date)
			return selected.puzzle if selected.ok else {}
	return {}

func open_session(id: String, replay: bool = false) -> PuzzleSession:
	var puzzle := puzzle_for(id)
	if puzzle.is_empty() or (not id.begins_with("daily_") and not unlocked(id)):
		return null
	var session := PuzzleSession.new()
	if not session.begin(puzzle, save.state.settings.mistake_limits):
		return null
	if not replay and save.state.sessions.has(id):
		if not session.restore(save.state.sessions[id]):
			notice = "That saved board could not be restored; its puzzle is ready to restart."
			session.last_message = notice
	save.state.active_id = id
	return session

func resume_id() -> String:
	var active: String = save.state.active_id
	var ids: Array = [active]
	ids.append_array(save.state.sessions.keys())
	for id in ids:
		if not id is String or not save.state.sessions.has(id):
			continue
		var puzzle := puzzle_for(id)
		if puzzle.is_empty() or (not id.begins_with("daily_") and not unlocked(id)):
			continue
		var session := PuzzleSession.new()
		if session.begin(puzzle) and session.restore(save.state.sessions[id]) and (session.moves > 0 or session.mistakes > 0 or session.hints_used > 0) and not session.is_complete():
			return id
	return ""

func next_playable() -> String:
	var resume := resume_id()
	if not resume.is_empty():
		return resume
	for puzzle in catalog.levels:
		if unlocked(puzzle.id) and not save.state.completed.has(puzzle.id):
			return puzzle.id
	return catalog.levels[0].id if not catalog.levels.is_empty() else ""

func record(session: PuzzleSession) -> Dictionary:
	var id: String = str(session.puzzle.id)
	var canonical := puzzle_for(id)
	if canonical.is_empty() or LevelCatalog.signature(canonical) != LevelCatalog.signature(session.puzzle) or (not id.begins_with("daily_") and not unlocked(id)):
		return {"ok": false, "awarded": false, "stars": 0}
	save.state.sessions[id] = session.snapshot()
	save.state.active_id = id
	var awarded := false
	var stars := 0
	if session.is_complete():
		if not save.state.completed.has(id):
			stars = 3 if session.mistakes == 0 and session.hints_used == 0 else (2 if session.mistakes <= 2 and session.hints_used <= 1 else 1)
			save.state.completed[id] = {"stars": stars, "best_moves": session.moves, "mistakes": session.mistakes, "hints": session.hints_used}
			awarded = true
		else:
			stars = int(save.state.completed[id].stars)
			save.state.completed[id].best_moves = mini(int(save.state.completed[id].best_moves), session.moves)
		var next := catalog.next_id(id)
		if not next.is_empty() and not save.state.unlocked.has(next):
			save.state.unlocked.append(next)
	return {"ok": persist() == OK, "awarded": awarded, "stars": stars}

func total_stars() -> int:
	var total := 0
	for reward in save.state.completed.values():
		total += int(reward.stars)
	return total

func persist() -> Error:
	var error := save.commit()
	if error != OK:
		notice = "Changes are in memory. Saving failed; check device storage."
	elif notice.begins_with("Changes are in memory."):
		notice = ""
	return error
