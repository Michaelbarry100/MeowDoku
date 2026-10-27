# MeowDoku

**Launch campaign: 150 committed, uniquely solvable 5×5 levels.** The original
32 puzzle IDs, boards and saved attempts are preserved. The expanded campaign
contains 38 Easy, 38 Medium, 37 Hard and 37 Expert gardens. Display order follows
the difficulty ramp; existing unlocks carry forward across inserted levels.
Daily puzzles retain their original source pool and remain outside the 150.
See [150-level campaign validation](docs/campaign-150.md).

**Audio is integrated:** original cozy piano/bells, stylized cat voices and
gentle interface/reward sounds. Music and effects default ON; Settings → Cozy
audio saves separate toggles and volumes. All nine requested audio assets exist.
See [audio implementation, licensing and tests](docs/audio-system.md).

**Current default: the premium 2.5D campaign interface.** F5 opens the complete
menu, campaign, daily puzzle, settings and saved-progress flow. Five original
transparent 3D-rendered cats replace the flat illustrations, with pastel
dimensional cells, cream backgrounds, tactile circular tools and soft cards.

See [visual upgrade and validation](docs/premium-visual-upgrade.md) for asset
provenance, exact test commands and remaining limitations. Current captures
are in `artifacts/mobile/` and `artifacts/premium/`.

The genuine 3D courtyard prototype is retained separately. Open
`scenes/three_d/vertical_slice.tscn` and press F6 to run it; its geometry,
raycasting and model sources remain available. See its earlier
[milestone documentation](docs/three-d-vertical-slice.md).

Renamed from Purrfect Regions. The previous desktop user-data directory is kept
as a compatibility path, preserving progress, settings, hint inventory and ad-test
data. Campaign IDs, daily seeds and debug/release profile separation stay stable.

An original offline Godot 4 / GDScript cat logic puzzle foundation for Android
and iOS. Includes the original uniquely solvable 5×5 board, a seeded generated
example, a curated 150-puzzle campaign, offline daily puzzles, polished mobile screens, and original cat
artwork. A UI-independent rules engine,
bounded solver, and reproducible generator validate levels before play.
Optional rewarded hints use a clearly labeled offline development simulator.
There are no third-party assets, accounts, real ad SDKs, network services, or plugins.

## Run in the editor

1. Download **Godot 4.5.1 Standard** (GDScript, not .NET) or a compatible newer
   Godot 4 version from https://godotengine.org/download/ . Godot is portable:
   extract the ZIP; no installer is needed. This project was tested with 4.5.1.
2. Open Godot, click **Import**, select this folder's `project.godot`, and open it.
3. Press **F5** to launch the upgraded campaign interface.
4. Choose **Play** or **Resume puzzle**, then tap cells to place cats or X marks.

A portable engine was downloaded during validation to the Windows temporary
folder. Until that folder is cleaned, this exact PowerShell command launches it
from the project directory:

```powershell
Set-Location 'C:\Users\SURFACE LAPTOP\OneDrive\Documents\ChatGPT\Application'
& "$env:TEMP\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64.exe" --path .
```

To open the editor, add `--editor`. For a permanent setup, extract Godot to a
folder of your choice and replace the executable path in these commands.

## Play

- Each tap cycles **empty → cat → excluded (X) → empty**. Every state change
  counts as one move; exclusions are optional notes and do not affect rules.
- Place exactly one cat in each row, column, and colored region.
- Cats cannot touch, including diagonally.
- Empty cells have a faint dot. Exclusions have an X. Cats with no current
  conflict have a green border and check; conflicting cats have a red border
  and exclamation mark. Both cats in a conflicting pair are flagged.
- A check means the placement is locally legal, not necessarily the solution.
- Completion requires five cats with all rules satisfied. It locks the board.
  **Restart** clears everything, resets the move counter, and unlocks input.
- **Menu** preserves your current board. **Resume puzzle** restores an unfinished
  garden, even after closing/reopening the app. Other saved boards remain intact.
- **Pause** preserves your board while opening Rules or Settings. Victory opens
  a celebration card with replay and level selection. The menu also offers
  Daily Puzzle, four difficulty groups with 150 locked/unlocked levels, tutorial
  practice, and saved comfort/mistake-limit settings.
- **Undo** restores cats and X marks. **Hint** applies one safe solution-based
  correction/placement. **Restart** requires confirmation and clears this attempt.
- Each garden has **3 free hints**. **+ Hint** opens optional rewarded-hint choices.
  Development builds can enable local ad simulations in Privacy & optional ads.
  Only a verified simulated completion earns one test hint; opens, skips and
  failures never reward. Release builds keep real advertising disabled.
- Mistakes count conflicting cat placements. Optional limits are Easy unlimited,
  Medium 5, Hard 3, Expert 2. Undo does not refund mistakes or hint usage.
- First clears earn 1–3 stars and unlock the next level. Victory offers **Next
  Level** and **Replay**; replay never duplicates first-clear rewards.
- Mouse, touch (emulated mouse events), and keyboard Button focus/activation
  are supported. No double-tap timing or long press is required.

## Architecture and files

| File | Purpose |
| --- | --- |
| `project.godot` | Main scene, portrait viewport, responsive canvas stretch, compatibility renderer |
| `scenes/main.tscn`, `scripts/main.gd` | Theme ownership and screen navigation |
| `scenes/main_menu.tscn`, `scripts/main_menu.gd` | Menu and play action |
| `scenes/puzzle_screen.tscn`, `scripts/puzzle_screen.gd` | Container layout, board state, move count, restart, completion feedback |
| `scenes/grid_cell.tscn`, `scripts/grid_cell.gd` | Reusable Button; procedural cat, exclusion and conflict artwork |
| `scripts/puzzle_rules.gd` | Pure pairwise rule validation, independent of scene nodes |
| `scripts/puzzle_solver.gd` | Bounded backtracking with row/region forward checking and partial-board support |
| `scripts/puzzle_validator.gd` | Schema, connectivity, reference solution, solvability and uniqueness admission |
| `scripts/puzzle_generator.gd` | Local seeded RNG, connected region growth that preserves uniqueness |
| `scripts/level_data.gd`, `data/first_puzzle.json` | Level loading, board creation, region map and reference solution |
| `data/catalog/collection.json`, `data/levels/*.json`, `scripts/level_catalog.gd` | Frozen 150-puzzle, four-group validated campaign |
| `scripts/puzzle_session.gd`, `scripts/progression_service.gd` | Actions, undo, hints, mistake budgets, resume, unlocks and stars |
| `scripts/player_save.gd`, `scripts/game_services.gd`, `scripts/daily_puzzle.gd` | Versioned backup/recovery storage, service composition and deterministic daily selection |
| `scripts/ads/` | Ad provider contract, mock, consent gate, receipt state machine, allowance and isolated development wallet |
| `scenes/privacy.tscn`, `scenes/rewarded_hint.tscn` | Local privacy choice, optional hint choices and full-screen simulator |
| `data/generated_seed_42.json` | Reproducible unique example; original menu level stays unchanged |
| `scripts/ui_theme.gd` | Shared pastel palette, typography, button and focus styles |
| `resources/purr_theme.tres`, `scripts/ui_components.gd` | Editable theme, rounded cards/buttons, scroll layouts and transitions |
| `scenes/settings.tscn`, `scenes/tutorial.tscn`, `scenes/level_selection.tscn` | Settings, rules/practice and level-selection screens |
| `scenes/pause_menu.tscn`, `scenes/victory.tscn` | Modal pause and victory flows |
| `scripts/mobile_safe_area.gd`, `scripts/player_preferences.gd` | Mobile safe insets and saved motion/haptic preferences |
| `scenes/components/cat_portrait.tscn`, `scripts/cat_portrait.gd`, `assets/app_icon.svg` | Original cat portraits, expressions and vector icon |
| `tests/test_runner.gd` | Actual Godot rules and scene integration tests |
| `tests/engine_tests.gd`, `tests/fixtures/` | Engine regression tests and separate positive/negative fixtures |
| `tests/mobile_ui_tests.gd` | Screen flows, pointer input, focus, comfort preferences and small-phone/safe-area checks |
| `tests/progression_tests.gd`, `tests/convenience_ui_tests.gd`, `tests/test_storage.gd` | Isolated saving/recovery, progression, undo/hints and full app reopening tests |
| `tests/ads_tests.gd`, `tests/ads_ui_tests.gd` | Reward verification, duplicates, suspension, consent, allowance, release isolation and optional UI |
| `tests/validate_project.js` | Independent exhaustive solver, connectivity and resource checks |
| `tests/campaign_tests.gd`, `scripts/campaign_difficulty.gd` | All 150 boards, hint proofs, monotone difficulty, old-save migration, actual UI completion and portrait release gate |
| `tools/generate_level.gd` | CLI for generating, saving and revalidating unique JSON levels |
| `artifacts/*.png` | Screenshots from the rendered integration test |

Layouts use anchors, margin/VBox/HBox/grid/aspect containers, expanding cells,
and minimum 48-unit cell targets. There are no fixed desktop cell positions.
The five regions are connected. The runtime validates actual rules; it does
not compare player input with the stored reference solution.

## Validation

From the project directory, substitute your installed engine path if needed:

```powershell
$engine = "$env:TEMP\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe"
& $engine --headless --editor --path . --import --quit
& $engine --headless --path . --script res://tests/engine_tests.gd
& $engine --headless --path . --script res://tests/progression_tests.gd
& $engine --headless --path . --script res://tests/campaign_tests.gd
& $engine --headless --path . --script res://tests/test_runner.gd
& $engine --headless --path . --script res://tests/mobile_ui_tests.gd
& $engine --headless --path . --script res://tests/convenience_ui_tests.gd
& $engine --headless --path . --script res://tests/ads_tests.gd
& $engine --headless --path . --script res://tests/ads_ui_tests.gd
node tests/validate_project.js
```

Run import first on a fresh checkout so Godot registers the script classes.
Node.js is only needed for the independent validation, not to play the game.
For a rendered test with screenshots:

```powershell
& $engine --path . --script res://tests/test_runner.gd -- --capture
```

Verified on Windows with Godot **4.5.1**, OpenGL Compatibility / Intel UHD:

- Full 150-level campaign: **6,235 headless / 6,247 rendered checks passed**,
  including all completions, saved unlocks, old-profile migration, safe hints,
  portrait sizes and scrolling/pointer selection of level 150. Twelve rendered
  captures are in `artifacts/campaign/`. Rebuilding reproduced all 151 hashes.
- Engine import: passed, exit code 0.
- Engine rules/solver/generator: **741 checks passed**, exit code 0. Includes
  independent exhaustive victory comparisons for all 256 row assignments on
  each of two 4×4 fixtures, no/multiple solutions, budgets, malformed input,
  admission, and reproducible generation at sizes 1, 4, 5, 6, 7, 8 and 10.
- Godot rules/scene/layout integration: **52 checks passed**, exit code 0.
  Covers all conflict types, incomplete and complete boards, exclusions, state
  cycling, move counting, restart, completion lock, and menu navigation.
- Layout checks: square cells, minimum touch size, visible action buttons at
  logical canvas sizes 320×640, 390×844, and 768×1024.
- Save/session/progression: **1,301 checks passed**, covering all 150 campaign levels,
  undo/hints, mistake limits, reward tiers, reloads, corruption, backups and dates.
- Convenience UI: **52 headless / 57 rendered checks**, including app scene
  close/reopen with exact progress, persisted undo/settings, restart confirmation,
  locks, hints, Next Level, Replay and stable daily progress.
- Mobile UI: **86 headless checks / 103 rendered checks including 17 screenshots**.
  Includes menu → puzzle → pause → resume → victory → replay, real pointer
  events, modal keyboard focus, tutorial, settings persistence, daily seeds,
  five canvas sizes from 320×568 to 768×1024, and simulated notch/home insets.
- Node validation: **2,696 checks passed**. Independently checks both original boards,
  all 150 curated levels, positive/negative fixtures, connected regions, resource paths and
  exhaustive solution counts.
- Rendered screenshots visually inspected for board layout and cat feedback.
- Rewarded ads/inventory: **61 checks passed**. Reward callback validation,
  success/skip/unavailable/failure, duplicate and late callbacks, suspension,
  privacy withdrawal, save rollback, v1 → v2 migration and mock/live isolation.
- Rewarded-hint UI: **67 headless / 72 rendered checks**, including 5 screenshots.
  The board remains playable after decline/failure, never receives forced ads,
  and is hidden behind a separate screen during explicitly requested simulation.

Generation starts unique and accepts only validated growth steps. The UI tests
caught and fixed compact-phone overflow and stale deferred focus requests.
All final checks pass. Screenshots were visually inspected.

## Progression and saving

See [docs/progression.md](docs/progression.md) for the campaign curation method,
unlock/reward rules, undo/hint/mistake behavior, save format/recovery, deterministic
daily selection and tests. Difficulty labels are based on measured structural
complexity and remain provisional pending player testing. All 150 committed boards
have exactly one solution and distinct normalized region geometry.

Progress is saved locally in versioned `user://player_save.json` after each action,
with `.bak` recovery. Core gameplay never requires an account or network.

## Optional rewarded hints and privacy

See [docs/monetization.md](docs/monetization.md) for the adapter architecture,
development sandbox, hint allowance, consent/audience gates, researched SDK,
Android/iOS setup and current Google Play/Apple privacy requirements with sources.

The game now writes **save version 2**, migrating version 1 progress/settings
without erasing them. Mock rewards stay in a separate `.ad_sandbox` file and
cannot become production credits. Real ads/CMP/native SDK verification remain
disabled and unverified until supported-device integration is complete.
Release exports use a separate `release_player_save.json` profile, so mock-assisted
development progress is never imported into release automatically. The existing
development `player_save.json` and version 1 migration remain supported.

To try the offline simulator, run **F5** in a debug/editor build, choose Settings
→ Privacy & optional ads → Allow local ad simulations, then open a puzzle and
choose **+ Hint → Test rewarded ad · +1 hint**. Complete/Skip/Fail exercise mock
callbacks only. Normal play and free hints work with this option off.

```powershell
& $engine --path . --script res://tests/ads_ui_tests.gd -- --capture
```

## Mobile UI

See [docs/mobile-ui.md](docs/mobile-ui.md) for the screen flows, reusable
components, comfort settings, safe-area implementation, asset status and
screenshot gallery. Run the rendered UI suite to refresh the captures:

```powershell
& $engine --path . --script res://tests/mobile_ui_tests.gd -- --capture
```

## Puzzle engine and level generation

See [docs/puzzle-engine.md](docs/puzzle-engine.md) for the API, data contract,
solver result semantics, generation algorithm, budgets and integration examples.
The engine supports sizes 1–32; bounded generation supports 1 and 4–10.
Sizes 2 and 3 have no possible non-touching permutation.

Generate a new unique level from the project directory (choose a new filename;
the tool refuses to overwrite files):

```powershell
$engine = "$env:TEMP\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe"
& $engine --headless --path . --script res://tools/generate_level.gd -- --size=5 --seed=123 --output=res://data/generated_seed_123.json
```

The saved JSON stores the seed as a string, algorithm version, generation options,
region map, and solution. Generating a file does not change the menu's default
puzzle. `PuzzleScreen.open_puzzle(puzzle)` admits and displays generated levels
through the same validation gate as authored levels. Add campaign entries through
the frozen catalog rather than replacing a live player's saved puzzle definition.

## Mobile export status

Portrait settings and touch input are configured, but **no APK, AAB, or iOS build
has been produced or tested on a physical device**. This is a desktop-verified
first playable project. Mobile safe areas, hardware touch behavior, signing,
and store packaging still require device testing.

For Android, install matching Godot export templates and the Android SDK/JDK
required by your engine version, then add an Android preset in Project → Export.
For iOS, use matching export templates and a macOS machine with Xcode and signing
credentials. Choose portrait orientation in the export configuration as well.

