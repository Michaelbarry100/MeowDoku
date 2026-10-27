# Puzzle engine (generation version 1)

The engine uses only RefCounted objects, arrays and dictionaries. It does not
depend on scenes, nodes, colors, player input, or a rendering backend.
`LevelData` connects file loading to the engine; `PuzzleScreen` connects its
results to the existing controls.

## Data contract

A puzzle dictionary requires `size` (whole number 1–32) and `regions` (an N×N
array of IDs 0 through N−1). Every ID must occur and each region must be connected
along shared cell edges. Integer-valued JSON floats are accepted; booleans,
fractional IDs, out-of-range IDs, ragged arrays, and disconnected regions are
rejected. The upper bound limits accidental allocation of enormous levels.

`id` and `title` are optional display metadata. Optional `solution` is an array
of N column indices, one for each row. A supplied solution must pass the real
rules, and never bypasses solution counting. It is not used to decide victory.

Boards are N×N arrays with `PuzzleRules.CellState.EMPTY = 0`, `CAT = 1`, and
`EXCLUDED = 2`. Invalid dimensions/states yield a structured invalid result.
Exclusions are player notes for normal rule evaluation. When explicitly passing
a partial board to the solver, they restrict the search to the remaining cells.
The solver never changes its input arrays.

## Rules and immediate feedback

```gdscript
var board := PuzzleRules.empty_board(5)
var result := PuzzleRules.evaluate(board, puzzle.regions)
```

The result contains:

- `status`: `incomplete`, `invalid`, or `complete`.
- `complete`: true only when all four rules pass and every row/column/region
  is covered. N cats alone is insufficient.
- `cat_count`, `conflicts`: all cats and conflicting `Vector2i(row, column)` keys.
- `reasons`: a dictionary of per-cell explanations for both cats in each conflict.
- `messages`: distinct human-readable rule violations; `errors`: malformed data.

An incomplete board is locally legal, not necessarily extendable to a solution.
The game reevaluates after every state change, displays the first specific
violation, flags all conflicting cells, and attaches all reasons to tooltips.
No solver work is needed per tap. This preserves responsive placement feedback.

## Bounded backtracking solver

```gdscript
var search := PuzzleSolver.solve(puzzle.regions, 2)
var partial_search := PuzzleSolver.solve(puzzle.regions, 10, board, 100000)
```

Arguments: region map, positive solution limit (default 2), optional partial
board, and positive node budget (default 100,000).

The solver places one cat per row, tracks used columns and regions, and rejects
adjacent columns in consecutive rows. Rows farther apart cannot touch. Forward
checking ensures each remaining row and region still has a candidate.

Result fields: `count`, `solutions` (column arrays), `nodes`, `errors`,
`limit_reached`, `budget_exceeded`, and `exhaustive`. The count is a lower bound
unless exhaustive. Reaching even a limit of 1 does not prove uniqueness. A
budget-exceeded result is never presented as proof of no solution or uniqueness.
Conflicting partial givens produce an exhaustive zero count; malformed input
produces errors. Exclusions constrain only explicitly supplied partial boards.

## Admission before play

```gdscript
var admission := PuzzleValidator.validate(puzzle, true, 100000)
var loaded := LevelData.load_validated("res://data/generated_seed_42.json")
if loaded.ok:
    puzzle_screen.open_puzzle(loaded.puzzle)
```

The validator checks schema/connectivity, any reference solution, then counts up
to two solutions. It returns `valid`, `errors`, `search`, and `classification`:
`invalid`, `unsolvable`, `multiple`, `unique`, or `unproven`.

Uniqueness is required by default. With `require_unique = false`, a known
solvable multiple-solution puzzle may be admitted. An unfinished search can only
be admitted in that mode if at least one solution was actually found.

All existing and generated levels go through this gate before cells are created.
Admission copies the data, preventing later mutation of caller-owned arrays.
Failed admission clears the board, disables restart, explains why, and leaves
menu navigation available. Missing files and broken JSON are handled safely.

## Reproducible generation

```gdscript
var generated := PuzzleGenerator.generate(6, 42, true, 250, 100000)
if generated.ok:
    puzzle_screen.open_puzzle(generated.puzzle)
```

Arguments: size, integer seed, require uniqueness, maximum region-growth trials,
and per-search node budget. Supported generation sizes are 1 and 4–10; sizes 2
and 3 are impossible under these rules. Larger engine-supported boards can be
authored separately and admitted under the same budgets.

The local RNG creates a legal cat permutation. N−1 singleton regions initially
force their cats, with a connected background region holding the remaining cat.
Random boundary growth expands the pinned regions into that background. Each
trial is retained only if the complete validator still accepts the puzzle.
The last background seed is never removed. A final admission check is mandatory.
Small budgets can fail explicitly; partial or unproven puzzles are not returned
as successful unique generations.

No difficulty rating is promised; some generated boards retain singleton
regions. This task guarantees correctness and reproducibility, not a particular
difficulty or region-size balance. Generation and admission are synchronous and
bounded; generate ahead of gameplay for larger boards rather than on each tap.

Each generated JSON stores `seed` as a decimal string (avoiding JSON floating
point precision loss), `generator_version`, `generation_options`,
`growth_attempts`, `solution`, and the full region map. To replay a saved level:

```gdscript
var options: Dictionary = saved.generation_options
var replay := PuzzleGenerator.generate(
    int(saved.size), int(saved.seed), options.require_unique,
    int(options.max_attempts), int(options.max_nodes))
```

Use the same generator version, options, and Godot RNG implementation for
identical generation. Godot 4.5.1 is the verified engine. Across future engine/RNG
changes, the stored region map remains the authoritative playable level.

The CLI in `tools/generate_level.gd` saves only new files under `res://data/`,
refuses overwrites, flushes the output, reloads it and verifies unique admission.
The campaign now uses the frozen collection in `data/catalog/collection.json`;
its first board preserves the original `first_puzzle.json`. See `progression.md`.

## Tests

Fixtures stay in `tests/fixtures/`, separate from production levels in `data/`.
`engine_tests.gd` tests rules, victory, malformed input, solver counts/limits,
partial-board restrictions, admission, persistence, and 21 seed/size combinations.
Independent oracles verify fixture counts and small generated boards. Every one
of 256 N-cat row assignments on each 4×4 fixture is checked for correct victory.
`test_runner.gd` exercises real menu/cell/restart signals and level admission.
`validate_project.js` independently solves every production level and the test
fixtures, checks connectivity, and verifies static resource dependencies.
