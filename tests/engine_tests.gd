extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/" + name + ".json"))

func _initialize() -> void:
	call_deferred("run")

func pair(regions: Array, a: Vector2i, b: Vector2i) -> Dictionary:
	var board := PuzzleRules.empty_board(regions.size())
	board[a.x][a.y] = 1
	board[b.x][b.y] = 1
	return PuzzleRules.evaluate(board, regions)

func run() -> void:
	var unique := fixture("unique_four")
	var multiple := fixture("multiple_four")
	var impossible := fixture("unsolvable_two")
	var single := fixture("single")
	var regions: Array = unique.regions
	check(PuzzleRules.evaluate(PuzzleRules.empty_board(4), regions).status == "incomplete", "Empty is incomplete")
	check(pair(regions, Vector2i(0, 1), Vector2i(1, 3)).status == "incomplete", "Legal rows are incomplete")
	var same_row := pair(regions, Vector2i(0, 0), Vector2i(0, 3))
	check(same_row.status == "invalid" and same_row.messages.has("Cats share row 1."), "Same row has specific feedback")
	check(same_row.reasons.size() == 2, "Both cats receive explanations")
	check(pair(regions, Vector2i(0, 0), Vector2i(3, 0)).messages.has("Cats share column 1."), "Column conflict")
	check(pair(regions, Vector2i(0, 2), Vector2i(3, 1)).messages.has("Cats share colored region 2."), "Region conflict without shared row/column or touching")
	var diagonal := pair(regions, Vector2i(0, 0), Vector2i(1, 1))
	check(diagonal.status == "invalid" and str(diagonal.messages).contains("diagonals count"), "Diagonal conflict across regions")
	check(pair(regions, Vector2i(0, 0), Vector2i(0, 1)).status == "invalid", "Horizontal adjacency")
	check(pair(regions, Vector2i(0, 0), Vector2i(1, 0)).status == "invalid", "Vertical adjacency")
	check(pair(regions, Vector2i(0, 0), Vector2i(3, 3)).status == "incomplete", "Opposite corners do not wrap")
	check(pair(regions, Vector2i(2, 2), Vector2i(3, 3)).status == "invalid", "Bottom-right diagonal boundary")
	var board := PuzzleRules.empty_board(4)
	for row in range(4):
		board[row][int(unique.solution[row])] = 1
	check(PuzzleRules.evaluate(board, regions).status == "complete", "All rules pass for victory")
	board[0][1] = 2
	check(PuzzleRules.evaluate(board, regions).status == "incomplete", "Exclusion cannot replace a winning cat")
	board[0][1] = 1
	board[0][0] = 1
	check(not PuzzleRules.evaluate(board, regions).complete, "Too many cats cannot win")
	board = PuzzleRules.empty_board(4)
	for row in range(4):
		board[row][row] = 1
	check(PuzzleRules.evaluate(board, regions).status == "invalid", "Exactly N cats violating adjacency cannot win")
	board = PuzzleRules.empty_board(4)
	board[0].fill(1)
	check(PuzzleRules.evaluate(board, regions).status == "invalid", "Exactly N cats in one row cannot win")
	board = PuzzleRules.empty_board(4)
	board[0][0] = 2
	check(PuzzleRules.evaluate(board, regions).cat_count == 0, "Excluded cells are notes")
	check(PuzzleRules.evaluate([[1]], [[0]]).complete, "1x1 boundary victory")
	check(PuzzleRules.evaluate([[0]], [[0]]).status == "incomplete", "1x1 empty")
	for malformed in [null, [], [[0]], [[0, 1], [0]], [[0, 4], [0, 1]], [[0, 0], [0, 0]], [[0, 0.5], [0, 1]], [[0, "1"], [0, 1]], [[0, true], [0, 1]], [[0, 1], [1, 0]]]:
		# [[0]] is a valid layout, but mismatches this 4x4 board.
		check(PuzzleRules.evaluate(PuzzleRules.empty_board(4), malformed).status == "invalid", "Malformed/mismatching layout is safely rejected: %s" % str(malformed))
	for malformed_board in [null, [], [[0]], [[0, 0, 0, 0]], [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 3]]]:
		check(PuzzleRules.evaluate(malformed_board, regions).status == "invalid", "Malformed board is rejected")
	check(not PuzzleRules.validate_layout([[0, 1], [1, 0]]).valid, "Disconnected regions are rejected")
	check(PuzzleRules.validate_layout(regions).valid, "Connected regions accepted")
	check(not PuzzleRules.validate_layout(PuzzleRules.empty_board(33)).valid, "Oversized layouts rejected")

	var solved := PuzzleSolver.solve(regions)
	check(solved.count == 1 and solved.exhaustive and solved.solutions[0] == unique.solution.map(func(value: Variant) -> int: return int(value)), "Unique fixture solved exhaustively")
	var none := PuzzleSolver.solve(impossible.regions)
	check(none.count == 0 and none.exhaustive, "Unsolvable fixture proven unsolvable")
	var two := PuzzleSolver.solve(multiple.regions, 2)
	check(two.count == 2 and two.limit_reached and not two.exhaustive, "Counting stops at configurable limit")
	var all := PuzzleSolver.solve(multiple.regions, 10)
	check(all.count == 2 and all.exhaustive, "Full count on multiple fixture")
	var one := PuzzleSolver.solve(multiple.regions, 1)
	check(one.count == 1 and one.limit_reached and not one.exhaustive, "Limit one does not prove uniqueness")
	check(PuzzleSolver.solve(single.regions).count == 1, "1x1 solver")
	check(not PuzzleSolver.solve(regions, 0).errors.is_empty(), "Reject zero solution limit")
	check(not PuzzleSolver.solve(regions, -1).errors.is_empty(), "Reject negative solution limit")
	check(not PuzzleSolver.solve(regions, 2, null, 0).errors.is_empty(), "Reject zero search budget")
	check(not PuzzleSolver.solve([]).errors.is_empty(), "Solver rejects invalid regions")
	var bounded := PuzzleSolver.solve(regions, 2, null, 1)
	check(bounded.budget_exceeded and not bounded.exhaustive and bounded.nodes == 1, "Search budget is explicit and bounded")
	check(PuzzleValidator.validate(unique, true, 1).classification == "unproven", "Budget exhaustion is not unsolvability")
	check(not PuzzleValidator.validate(unique, true, 1).valid, "Unproven puzzles cannot pass unique admission")
	board = PuzzleRules.empty_board(4)
	board[0][1] = 1
	var snapshot := board.duplicate(true)
	check(PuzzleSolver.solve(regions, 2, board).count == 1 and board == snapshot, "Partial solving preserves input")
	board[0][1] = 2
	check(PuzzleSolver.solve(regions, 2, board).count == 0, "Solver honors exclusions as search restrictions")
	board = PuzzleRules.empty_board(4)
	board[0][0] = 1
	board[0][3] = 1
	check(PuzzleSolver.solve(regions, 2, board).count == 0, "Solver rejects conflicting givens")
	check(not PuzzleSolver.solve(regions, 2, []).errors.is_empty(), "Solver rejects malformed givens")
	for input in [unique, single]:
		check(PuzzleValidator.validate(input).classification == "unique", "Unique puzzle admission")
	check(not PuzzleValidator.validate(impossible).valid, "Reject unsolvable puzzle")
	check(not PuzzleValidator.validate(multiple).valid, "Reject ambiguity when uniqueness required")
	check(PuzzleValidator.validate(multiple, false).valid, "Allow ambiguity only when requested")
	for input in [null, {}, {"size": 0}, {"size": 2.5}, {"size": true}, {"size": 33}, {"size": 4, "regions": [[0]]}, fixture("malformed")]:
		check(not PuzzleValidator.validate(input).valid, "Reject malformed puzzle metadata")
	var bad_reference := unique.duplicate(true)
	bad_reference.solution = [0, 1, 2, 3]
	check(not PuzzleValidator.validate(bad_reference).valid, "Reject illegal stored solution")
	bad_reference.solution = [1.5, 3, 0, 2]
	check(not PuzzleValidator.validate(bad_reference).valid, "Reject fractional solution column")
	check(not LevelData.load_validated("res://tests/fixtures/broken_json.txt").ok, "Reject malformed JSON")
	check(not LevelData.load_validated("res://tests/fixtures/missing.json").ok, "Reject missing file")
	check(not LevelData.load_validated("res://tests/fixtures/malformed.json").ok, "Reject malformed loaded level")
	check(not LevelData.admit(impossible).ok, "Admission rejects no-solution puzzle")
	var admitted := LevelData.admit(unique)
	admitted.puzzle.regions[0][0] = 3
	check(unique.regions[0][0] == 0, "Admission copies level data to isolate mutations")
	var partial_count_found := false
	for budget_limit in range(1, 100):
		var partial := PuzzleSolver.solve(multiple.regions, 2, null, budget_limit)
		if partial.count == 1 and partial.budget_exceeded:
			partial_count_found = true
			var unproven := PuzzleValidator.validate(multiple, true, budget_limit)
			check(not unproven.valid and unproven.classification == "unproven", "One found solution with unfinished search never implies uniqueness")
			break
	check(partial_count_found, "Budget-limited single-solution branch exercised")
	for input in [unique, multiple]:
		check_all_assignments(input.regions, [])

	# Exhaustively compare every row assignment on fixture boards with a simple
	# independent oracle, including all N-cat losing configurations.
	for input in [unique, multiple, impossible, single]:
		var expected: Array = []
		oracle(input.regions, [], expected)
		var counted := PuzzleSolver.solve(input.regions, 1000)
		check(counted.exhaustive and counted.count == expected.size(), "Solver matches independent exhaustive oracle")
		for placement in counted.solutions:
			check(expected.has(placement), "Solver solution belongs to independent oracle")

	print("Engine rules/solver tests complete; generating seeded boards...")
	for size in [1, 4, 5, 6, 7, 8, 10]:
		for seed_value in [0, 42, -17]:
			var generated := PuzzleGenerator.generate(size, seed_value)
			check(generated.ok, "Generation succeeds N=%d seed=%d: %s" % [size, seed_value, str(generated.errors)])
			if not generated.ok:
				continue
			var puzzle: Dictionary = generated.puzzle
			check(PuzzleValidator.validate(puzzle).valid, "Generated puzzle passes independent admission")
			check(PuzzleRules.validate_layout(puzzle.regions).valid, "Generated regions are connected and complete")
			check(puzzle.seed == str(seed_value) and puzzle.generator_version == 1, "Seed and algorithm version stored")
			var replay := PuzzleGenerator.generate(size, int(puzzle.seed))
			check(replay.ok and replay.puzzle == puzzle, "Seed reproduces entire generated puzzle")
			if size <= 6:
				var expected: Array = []
				oracle(puzzle.regions, [], expected)
				check(expected.size() == 1 and expected[0] == puzzle.solution, "Generated uniqueness verified by independent oracle")
	for size in [0, -1, 2, 3, 11]:
		check(not PuzzleGenerator.generate(size, 42).ok, "Unsupported/impossible size rejected")
	check(not PuzzleGenerator.generate(5, 42, true, 0).ok, "Attempt limit validated")
	check(not PuzzleGenerator.generate(5, 42, true, 2, 1).ok, "Exhausted generation budget fails explicitly")
	check(PuzzleGenerator.generate(5, 42, false).ok, "Nonunique generation mode still admits only solvable puzzles")
	var first := PuzzleGenerator.generate(5, 42)
	var other := PuzzleGenerator.generate(5, 43)
	check(first.ok and other.ok and first.puzzle.regions != other.puzzle.regions, "Different seeds can produce different region maps")
	check(LevelData.load_validated(LevelData.FIRST_PUZZLE).ok, "Existing production puzzle still admitted")
	var saved := LevelData.load_validated("res://data/generated_seed_42.json")
	check(saved.ok, "Saved generated example passes file admission")
	if saved.ok:
		var options: Dictionary = saved.puzzle.generation_options
		var regenerated := PuzzleGenerator.generate(int(saved.puzzle.size), int(saved.puzzle.seed), options.require_unique, int(options.max_attempts), int(options.max_nodes))
		# Godot parses JSON numbers as floats; normalize both through JSON before
		# comparing data rather than comparing integer/float formatting.
		check(regenerated.ok and JSON.parse_string(JSON.stringify(regenerated.puzzle)) == saved.puzzle, "Stored seed/options reproduce serialized example")
	print("RESULT: %d engine checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_all_assignments(regions: Array, placement: Array) -> void:
	var size := regions.size()
	if placement.size() < size:
		for column in range(size):
			placement.append(column)
			check_all_assignments(regions, placement)
			placement.pop_back()
		return
	var legal := true
	for a in range(size):
		for b in range(a + 1, size):
			if placement[a] == placement[b] or regions[a][placement[a]] == regions[b][placement[b]] or (b == a + 1 and absi(int(placement[a]) - int(placement[b])) <= 1):
				legal = false
	var board := PuzzleRules.empty_board(size)
	for row in range(size):
		board[row][placement[row]] = 1
	check(PuzzleRules.evaluate(board, regions).complete == legal, "Victory agrees with independent oracle for every N-cat assignment")

func oracle(regions: Array, placement: Array, solutions: Array) -> void:
	var size := regions.size()
	if placement.size() == size:
		var used_regions: Array = []
		for row in range(size):
			var region := int(regions[row][placement[row]])
			if used_regions.has(region):
				return
			used_regions.append(region)
		solutions.append(placement.duplicate())
		var board := PuzzleRules.empty_board(size)
		for row in range(size):
			board[row][placement[row]] = 1
		check(PuzzleRules.evaluate(board, regions).complete, "Independent oracle solution wins")
		return
	for column in range(size):
		if placement.has(column) or (not placement.is_empty() and absi(column - int(placement.back())) <= 1):
			continue
		placement.append(column)
		oracle(regions, placement, solutions)
		placement.pop_back()
