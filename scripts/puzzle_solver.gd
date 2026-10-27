class_name PuzzleSolver
extends RefCounted
## Bounded backtracking, one row at a time. No scene or reference-solution use.
## Results never claim uniqueness unless the search was exhaustive.

static func solve(regions: Variant, limit: int = 2, board: Variant = null, max_nodes: int = 100000) -> Dictionary:
	var result := {"count": 0, "solutions": [], "limit_reached": false, "budget_exceeded": false, "exhaustive": false, "nodes": 0, "errors": []}
	var layout := PuzzleRules.validate_layout(regions)
	if not layout.valid:
		result.errors = layout.errors
		return result
	if limit < 1 or max_nodes < 1:
		result.errors = ["Solution limit and search budget must be positive."]
		return result
	var size: int = layout.size
	var working: Array = PuzzleRules.empty_board(size) if board == null else board
	var evaluation := PuzzleRules.evaluate(working, regions)
	if not evaluation.errors.is_empty():
		result.errors = evaluation.errors
		return result
	if evaluation.status == "invalid":
		result.exhaustive = true
		return result
	var candidates: Array = []
	for row in range(size):
		var columns: Array = []
		var fixed := -1
		for column in range(size):
			if working[row][column] == PuzzleRules.CellState.CAT:
				fixed = column
			elif working[row][column] == PuzzleRules.CellState.EMPTY:
				columns.append(column)
		candidates.append([fixed] if fixed >= 0 else columns)
	_search(regions, candidates, [], {}, {}, limit, max_nodes, result)
	result.exhaustive = not result.limit_reached and not result.budget_exceeded
	return result

static func _search(regions: Array, candidates: Array, placement: Array, columns: Dictionary, used_regions: Dictionary, limit: int, budget: int, result: Dictionary) -> void:
	if result.limit_reached or result.budget_exceeded:
		return
	if result.nodes >= budget:
		result.budget_exceeded = true
		return
	result.nodes += 1
	var row := placement.size()
	if row == regions.size():
		result.count += 1
		result.solutions.append(placement.duplicate())
		result.limit_reached = result.count >= limit
		return
	# Forward-check both remaining rows and remaining regions. In particular,
	# never pass the only available cell of an unfilled singleton region.
	var available_regions: Dictionary = {}
	for future_row in range(row, regions.size()):
		var has_candidate := false
		for candidate in candidates[future_row]:
			var id := int(regions[future_row][candidate])
			if columns.has(candidate) or used_regions.has(id):
				continue
			if future_row == row and row > 0 and absi(int(placement[row - 1]) - int(candidate)) <= 1:
				continue
			has_candidate = true
			available_regions[id] = true
		if not has_candidate:
			return
	if available_regions.size() != regions.size() - used_regions.size():
		return
	for column in candidates[row]:
		var region := int(regions[row][column])
		if columns.has(column) or used_regions.has(region):
			continue
		if row > 0 and absi(int(placement[row - 1]) - int(column)) <= 1:
			continue
		placement.append(column)
		columns[column] = true
		used_regions[region] = true
		_search(regions, candidates, placement, columns, used_regions, limit, budget, result)
		placement.pop_back()
		columns.erase(column)
		used_regions.erase(region)
		if result.limit_reached or result.budget_exceeded:
			return
