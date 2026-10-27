class_name CampaignDifficulty
extends RefCounted
## Reproducible difficulty proxy, not a claim of human playtest calibration.
const INTRO_IDS := ["easy_01", "easy_02"]
const GROUP_COUNTS := {"Easy": 38, "Medium": 38, "Hard": 37, "Expert": 37}

static func measure(puzzle: Dictionary) -> Dictionary:
	var areas: Array = []
	areas.resize(int(puzzle.size))
	areas.fill(0)
	for row in puzzle.regions:
		for id in row:
			areas[int(id)] += 1
	var nodes: int = PuzzleSolver.solve(puzzle.regions, 2).nodes
	var singletons := areas.count(1)
	return {"singletons": singletons, "solver_nodes": nodes, "score": (int(puzzle.size) - singletons) * 100 + nodes}

static func group_for(score: int) -> String:
	if score < 411:
		return "Easy"
	if score < 417:
		return "Medium"
	if score < 424:
		return "Hard"
	return "Expert"

static func symmetry_signature(puzzle: Dictionary) -> String:
	var grid: Array = puzzle.regions.duplicate(true)
	var candidates: Array[String] = []
	var n := int(puzzle.size)
	for turn in range(4):
		candidates.append(LevelCatalog.signature({"size": n, "regions": grid}))
		var reflected: Array = []
		for row in grid:
			var reversed: Array = row.duplicate()
			reversed.reverse()
			reflected.append(reversed)
		candidates.append(LevelCatalog.signature({"size": n, "regions": reflected}))
		var rotated := PuzzleRules.empty_board(n)
		for row in range(n):
			for column in range(n):
				rotated[row][column] = grid[n - 1 - column][row]
		grid = rotated
	candidates.sort()
	return candidates[0]
