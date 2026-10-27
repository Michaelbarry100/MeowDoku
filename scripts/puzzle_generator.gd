class_name PuzzleGenerator
extends RefCounted
## Version 1: guaranteed-unique pinned regions, then uniqueness-preserving growth.
## RNG is local; no dependence on global random state, UI, or wall-clock time.

const VERSION := 1
const MAX_GENERATED_SIZE := 10

static func generate(size: int, seed_value: int, require_unique: bool = true, max_attempts: int = 250, max_nodes: int = 100000) -> Dictionary:
	var failure := {"ok": false, "puzzle": {}, "attempts": 0, "errors": []}
	if size < 1 or size > MAX_GENERATED_SIZE or size == 2 or size == 3:
		failure.errors = ["Generation supports size 1 or 4 to %d; sizes 2 and 3 cannot satisfy the no-touch rule." % MAX_GENERATED_SIZE]
		return failure
	if max_attempts < 1 or max_nodes < 1:
		failure.errors = ["Generation attempts and search budget must be positive."]
		return failure
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var solution: Array = []
	var budget := {"left": max_nodes}
	if not _placement(size, solution, {}, rng, budget):
		failure.errors = ["Legal placement search exhausted its node budget."]
		return failure
	var regions := PuzzleRules.empty_board(size)
	for row in range(size):
		regions[row].fill(size - 1)
		regions[row][solution[row]] = row
	# N-1 singleton regions force their cats. The last row and column force the
	# remaining cat. Non-touching holes leave the background region connected.
	var puzzle := {"id": "seed_%d_%d" % [size, seed_value], "title": "Pastel Garden", "size": size, "regions": regions, "solution": solution, "seed": str(seed_value), "generator_version": VERSION, "generation_options": {"require_unique": require_unique, "max_attempts": max_attempts, "max_nodes": max_nodes}}
	var initial := PuzzleValidator.validate(puzzle, require_unique, max_nodes)
	if not initial.valid:
		failure.errors = initial.errors
		return failure
	var attempts := 0
	for attempt in range(max_attempts):
		var frontier: Array = []
		for row in range(size):
			for column in range(size):
				if regions[row][column] != size - 1 or (row == size - 1 and column == int(solution[row])):
					continue
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: Vector2i = Vector2i(row, column) + direction
					if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < size and neighbor.y < size and regions[neighbor.x][neighbor.y] != size - 1:
						frontier.append([row, column, regions[neighbor.x][neighbor.y]])
		if frontier.is_empty():
			break
		attempts += 1
		var choice: Array = frontier[rng.randi_range(0, frontier.size() - 1)]
		regions[choice[0]][choice[1]] = choice[2]
		var validation := PuzzleValidator.validate(puzzle, require_unique, max_nodes)
		if not validation.valid:
			regions[choice[0]][choice[1]] = size - 1
	puzzle["growth_attempts"] = attempts
	var final_validation := PuzzleValidator.validate(puzzle, require_unique, max_nodes)
	if not final_validation.valid:
		failure.errors = final_validation.errors
		return failure
	return {"ok": true, "puzzle": puzzle, "attempts": attempts, "errors": [], "validation": final_validation}

static func _placement(size: int, placement: Array, used: Dictionary, rng: RandomNumberGenerator, budget: Dictionary) -> bool:
	if budget.left <= 0:
		return false
	budget.left -= 1
	if placement.size() == size:
		return true
	var candidates: Array = range(size)
	for i in range(size - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary: int = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temporary
	for column in candidates:
		if used.has(column) or (not placement.is_empty() and absi(int(placement.back()) - int(column)) <= 1):
			continue
		placement.append(column)
		used[column] = true
		if _placement(size, placement, used, rng, budget):
			return true
		placement.pop_back()
		used.erase(column)
	return false
