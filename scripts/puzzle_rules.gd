class_name PuzzleRules
extends RefCounted
## Pure rules: no nodes or UI dependencies. Exclusions are player notes only.

enum CellState { EMPTY, CAT, EXCLUDED }

const MAX_SIZE := 32

static func empty_board(size: int) -> Array:
	var board: Array = []
	for row in range(size):
		var cells: Array = []
		cells.resize(size)
		cells.fill(CellState.EMPTY)
		board.append(cells)
	return board

static func is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func validate_layout(regions: Variant) -> Dictionary:
	if not regions is Array or regions.is_empty() or regions.size() > MAX_SIZE:
		return {"valid": false, "errors": ["Regions must be a square array with 1 to %d rows." % MAX_SIZE]}
	var size: int = regions.size()
	var members: Array = []
	for id in range(size):
		members.append([])
	for row in range(size):
		if not regions[row] is Array or regions[row].size() != size:
			return {"valid": false, "errors": ["Region row %d must contain %d cells." % [row + 1, size]]}
		for column in range(size):
			var id: Variant = regions[row][column]
			if not is_integer(id) or id < 0 or id >= size:
				return {"valid": false, "errors": ["Region IDs must be whole numbers from 0 to %d." % (size - 1)]}
			members[int(id)].append(Vector2i(row, column))
	for id in range(size):
		if members[id].is_empty():
			return {"valid": false, "errors": ["Region %d is missing; exactly %d regions are required." % [id + 1, size]]}
		var visited: Dictionary = {members[id][0]: true}
		var queue: Array = [members[id][0]]
		var cursor := 0
		while cursor < queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = cell + direction
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size or neighbor.y >= size:
					continue
				if int(regions[neighbor.x][neighbor.y]) == id and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		if visited.size() != members[id].size():
			return {"valid": false, "errors": ["Region %d must be connected along cell edges." % (id + 1)]}
	return {"valid": true, "size": size, "errors": []}

static func validate_board(board: Variant, size: int) -> Array[String]:
	var errors: Array[String] = []
	if not board is Array or board.size() != size:
		errors.append("Board must have %d rows." % size)
		return errors
	for row in range(size):
		if not board[row] is Array or board[row].size() != size:
			errors.append("Board row %d must have %d cells." % [row + 1, size])
			return errors
		for state in board[row]:
			if not is_integer(state) or state < CellState.EMPTY or state > CellState.EXCLUDED:
				errors.append("Cell state must be empty (0), cat (1), or excluded (2).")
				return errors
	return errors

static func evaluate(board: Variant, regions: Variant) -> Dictionary:
	var layout := validate_layout(regions)
	var errors: Array = layout.errors.duplicate()
	if layout.valid:
		errors.append_array(validate_board(board, layout.size))
	if not errors.is_empty():
		return {"status": "invalid", "complete": false, "conflicts": {}, "reasons": {}, "cat_count": 0, "errors": errors, "messages": errors}
	var size: int = layout.size
	var cats: Array[Vector2i] = []
	var conflicts: Dictionary = {}
	var reasons: Dictionary = {}
	var messages: Array[String] = []
	for row in range(size):
		for column in range(size):
			if board[row][column] == CellState.CAT:
				cats.append(Vector2i(row, column))
	for i in range(cats.size()):
		for j in range(i + 1, cats.size()):
			var a := cats[i]
			var b := cats[j]
			var same_row := a.x == b.x
			var same_column := a.y == b.y
			var same_region: bool = regions[a.x][a.y] == regions[b.x][b.y]
			var touching := absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1
			var pair_reasons: Array[String] = []
			if same_row:
				pair_reasons.append("Cats share row %d." % (a.x + 1))
			if same_column:
				pair_reasons.append("Cats share column %d." % (a.y + 1))
			if same_region:
				pair_reasons.append("Cats share colored region %d." % (int(regions[a.x][a.y]) + 1))
			if touching:
				pair_reasons.append("Cats at row %d, column %d and row %d, column %d touch; diagonals count." % [a.x + 1, a.y + 1, b.x + 1, b.y + 1])
			if not pair_reasons.is_empty():
				conflicts[a] = true
				conflicts[b] = true
				for cell in [a, b]:
					if not reasons.has(cell):
						reasons[cell] = []
					for reason in pair_reasons:
						if not reasons[cell].has(reason):
							reasons[cell].append(reason)
				for reason in pair_reasons:
					if not messages.has(reason):
						messages.append(reason)
	# Schema validation proves there are exactly N nonempty regions. Thus N
	# pairwise legal cats cover every row, column and region exactly once.
	var complete := cats.size() == size and conflicts.is_empty()
	return {
		"status": "complete" if complete else ("invalid" if not conflicts.is_empty() else "incomplete"),
		"conflicts": conflicts,
		"reasons": reasons,
		"messages": messages,
		"errors": [],
		"cat_count": cats.size(),
		"complete": complete,
	}
