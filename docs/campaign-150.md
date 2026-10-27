# MeowDoku 150-level campaign

The release campaign is `data/catalog/collection.json`, with exactly 150
committed JSON definitions in `data/levels/`. Orders 1–150 are consecutive.
There are 38 Easy, 38 Medium, 37 Hard and 37 Expert levels, all 5×5. The separate
4×4 prototype, two earlier duplicate demo files, test fixtures and date-based
daily copies are not included in that count.

## Preservation and curation

All original 32 IDs, region maps, solutions, seeds, titles and metadata are kept;
only their `order` field changes to interleave the additional boards. The first
two original introductory boards retain positions 1 and 2. A frozen original
snapshot is kept under `tests/fixtures/legacy_campaign_v1.json` for regression
checks and reproducible offline builds.

`tools/build_collection.gd` preserves that baseline and selects 118 additional
unique puzzles from seeded candidates 2000 onward. This build examined 136
candidates. It uses the existing generator, validator and solver without changing
row, column, region or diagonal/edge no-touching rules. Definitions must have
five connected nonempty regions and exactly one solution. Deduplication ignores
arbitrary region numbering and rejects rotations and reflections of existing
boards. No levels are generated or downloaded during normal campaign play.

The difficulty proxy remains `(5 - singleton_regions) * 100 + solver_nodes`.
After the retained introductory pair, scores are nondecreasing: Easy below 411,
Medium 411–416, Hard 417–423 and Expert 424 or more. Every recorded metric is
recomputed independently. This is a transparent, testable difficulty ramp;
human playtesting is still needed to calibrate subjective difficulty.

The runtime catalog requires exactly 150 valid definitions, consecutive order,
the declared group counts, unique IDs and unique geometry. Missing, malformed,
nonunique or contradictory puzzles fail admission rather than becoming playable.

## Existing saves and daily puzzles

Save version 2 is retained. Sessions, stars, first-clear rewards, hint allowance
and settings remain keyed by their existing IDs. Board signatures exclude
display order, so saved cats, X marks and undo stacks remain usable. Previously
unlocked levels stay accessible; inserted earlier levels are unlocked up to the
player's old frontier. This grants access, not completion rewards. A new profile
still begins with only level 1 unlocked.

The original daily seed and source IDs are frozen in `daily_pool`, so adding
campaign content does not change the puzzle selected for an established date.
Daily progress/rewards use date IDs and do not count toward the 150 campaign
levels or unlock source campaign levels.

Level selection reads the actual catalog size and entries. It preserves the
existing group filters, scrolling cards, lock enforcement and saved-board labels.
No visual redesign or audio/model replacement is part of this change.

## Release validation commands

Files added or changed for this campaign expansion:

- `data/levels/`: 118 new definitions; original 32 retain everything except order.
- `data/catalog/collection.json`: actual 150-entry order, counts and frozen daily pool.
- `scripts/campaign_difficulty.gd`: new shared effort metric and symmetry signatures.
- `scripts/level_catalog.gd`: strict release admission, ordering and daily sources.
- `scripts/progression_service.gd`: preserve old unlocked frontier after insertion.
- `scripts/daily_puzzle.gd`: use the stable daily pool.
- `scripts/info_page.gd`: derive visible counts and board size from actual data.
- `tools/build_collection.gd`: deterministic 150-level offline curation.
- `tests/campaign_tests.gd` and `tests/fixtures/legacy_campaign_v1.json`: new full
  campaign release gate and original-content snapshot.
- `tests/validate_project.js`, `tests/progression_tests.gd` and
  `tests/convenience_ui_tests.gd`: updated independent proofs and count/order tests.
- `README.md`, `docs/progression.md` and this document: current launch instructions
  and validation report. Core rules, solver, session logic, art and audio remain intact.

Import `project.godot` in Godot 4.5.1 Standard and press F5 to play. From the
project directory in PowerShell, with the portable engine used for validation:

```powershell
$meowEngine = 'C:\Users\SURFACE LAPTOP\AppData\Local\Temp\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
& $meowEngine --headless --editor --path . --import --quit
node tests/validate_project.js
& $meowEngine --headless --path . --script res://tests/campaign_tests.gd
& $meowEngine --path . --script res://tests/campaign_tests.gd -- --capture
& $meowEngine --headless --path . --script res://tests/progression_tests.gd
# Development-only deterministic rebuild; rewrites committed campaign output:
& $meowEngine --headless --path . --script res://tools/build_collection.gd
```

`campaign_tests.gd` proves uniqueness and validates every hint/undo path for all
150 boards, verifies original content and old-save migration, traverses all 150
levels through the real cell signals/Victory/Next Level UI, reloads saved state,
and tests each board at 320×568, 390×844 and 430×932. Every tile must retain a
48-unit target and fit within safe content. It also scrolls to and pointer-clicks
level 150 in the actual selection screen. Optional captures are written to
`artifacts/campaign/`. Tests use isolated saves and never write player profiles.

The independent Node validator exhaustively enumerates solutions, checks
connectivity/solutions/IDs/files/difficulty metrics/symmetry duplicates and
confirms all original fields except order remain unchanged. The existing solver,
progression, mobile UI, convenience, audio, ad abstraction, artwork and retained
3D suites remain part of regression verification.

Final results on 2026-10-27, Godot 4.5.1 / Windows Compatibility renderer:

| Check | Result |
| --- | --- |
| Full campaign, headless | 6,235 checks, zero failures |
| Full campaign, rendered with 12 captures | 6,247 checks, zero failures |
| Independent Node validator | 2,696 checks, zero failures |
| Save/session/progression | 1,301 checks, zero failures |
| Rules/solver/generator | 741 checks, zero failures |
| Existing game integration | 52 checks, zero failures |
| Existing mobile UI | 86 checks, zero failures |
| Existing convenience UI | 52 checks, zero failures |
| Reward inventory / rewarded-hint UI | 61 / 67 checks, zero failures |
| Artwork / retained 3D / audio | 22 / 249 / 80 checks, zero failures |
| Deterministic rebuild | All 151 file hashes identical (manifest + 150 definitions) |

The initial new campaign test compared GDScript integer dictionaries directly
with JSON floating-point dictionaries. That test-only mismatch was fixed by
comparing numeric field values; the final full runs above passed. The original
32 data records were checked against the frozen fixture, ignoring only order.
The rendered run reached and pointer-clicked level 150 after scrolling, and
captured its final victory screen with Next Level correctly disabled.

Android/iPhone device testing and store exports remain outside this desktop
validation. The level count and mathematical proofs do not establish mobile
hardware performance or human difficulty ratings.
