# Progression, convenience and local saves

Task 4 extends the existing scenes, rules engine and mobile art direction. The
campaign, daily selection, play-session state and file storage are independent
of the UI and work offline.

## Campaign and difficulty

`data/catalog/collection.json` is the versioned campaign manifest. It references
150 committed puzzles in `data/levels/`: **38 Easy, 38 Medium, 37 Hard, 37 Expert**.
All use 5×5 grids so the existing small-phone touch targets remain comfortable.
The original two boards are retained as Easy 01 and Easy 02, with stable campaign
IDs and their existing names. No puzzle is generated at campaign runtime.

The original 32 definitions are retained (only their display order changes).
The remaining 118 were selected deterministically from 136 additional seeded
candidates, starting at seed 2000. Curation rejects invalid/nonunique puzzles
and duplicate normalized region geometry, including rotations/reflections.
After the original two introductory boards, the score never decreases:
`(5 - singleton_region_count) * 100 + exhaustive_solver_nodes`. Later groups
generally have fewer forced singleton regions and more search work. These are
**provisional, metric-based difficulty labels**, not human-calibrated ratings.
All 150 also pass an independent exhaustive JavaScript solver.

`tools/build_collection.gd` records the reproducible curation process. It is a
development tool that rewrites the committed collection, not a normal launch or
export step. Its input snapshot in `tests/fixtures/legacy_campaign_v1.json`
preserves the original boards; fixtures are not counted as production levels.
Keep IDs, committed boards and daily seed stable in shipped builds. On loading an
old save, the progression service fills in newly inserted levels up to its old
unlocked frontier. Existing completed records, stars, hints and sessions remain
keyed by stable IDs and are not re-awarded or deleted.

Only Easy 01 starts unlocked. Completing a level unlocks the next entry in the
manifest, including transitions between groups. The level selector shows group
filters, locked/open buttons, saved-board labels and first-clear stars. The
service enforces locks independently of the buttons.

## Player actions and rewards

- **Undo** restores the last cell change, including cat → X, X → empty and hint
  actions. It reduces the current move count. The most recent 2,000 actions are
  retained and saved. Mistakes and hint usage belong to the attempt and are never
  refunded by undo.
- **Restart** opens a confirmation card. Cancel preserves the board; confirming
  clears cats, X marks, history, moves, mistakes and hints for that attempt.
  Previously earned stars and unlocks remain. Cancel from pause returns to pause.
- **Hint** uses the unique solution computed by the existing solver. It first
  removes a misplaced cat, then on subsequent hints places a missing correct cat,
  replacing an X note if needed. Each hint applies exactly one undoable move and
  explains its row/column. It never adds a cat while a wrong cat could block it.
- A **mistake** is a cat placement that conflicts with an existing cat under an
  actual row, column, region or adjacency rule. A locally legal but ultimately
  wrong placement is not silently counted as a mistake. X notes are not mistakes.
- Optional **mistake limits** are off by default: Easy unlimited, Medium 5, Hard 3,
  Expert 2. Reaching the limit blocks further placement/hints. Undo remains
  available but does not refund the count. Restart or disable limits to continue.
  Settings apply to the current saved board when returning from pause/settings.
- First completion earns **3 stars** for zero mistakes and zero hints; **2 stars**
  for at most two mistakes and at most one hint; otherwise **1 star**. Every clear
  still unlocks the next level. First-clear stars are fixed: replay can improve
  best moves but cannot issue or increase that level's reward again.
- Victory offers **Next Level**, **Replay**, and Main Menu. Replay is a deliberate
  new attempt on a completed board. On the final campaign level, Next is disabled
  and labeled “All gardens complete”. Daily victory can return to campaign play.

## Save format and lifecycle

`PlayerSave` stores `user://player_save.json`. Task 5 upgrades the file to save
format **2**, retaining all Task 4 version 1 progress/settings. The original
progression sections remain:

```text
version
unlocked: [campaign IDs]
completed: { puzzle ID: {stars, best_moves, mistakes, hints} }
sessions: { puzzle ID: {version, signature, board, history, moves, mistakes, hints} }
dailies: { YYYY-MM-DD: validated frozen daily puzzle }
active_id
settings: { reduced_motion, haptics, mistake_limits }
```

Version 2 additionally stores `ad_privacy` and `hint_inventory`. Each garden now
has three persistent free hints; optional extra development hints live outside
the production file. Undo/restart do not replenish inventory. The underlying
`PuzzleSession.use_hint()` still implements the pure move algorithm; the game UI
routes it through `HintInventory` for allowance checks and atomic spending.
See [monetization.md](monetization.md) for schema and rewarded-hint details.

Every successful move, undo, hint, confirmed restart and completion is saved.
Screen changes, application backgrounding and normal closing also save. All
boards remain in separate sessions; selecting another puzzle does not erase an
unfinished one. Play becomes **Resume puzzle** when a saved unfinished board is
available, including a daily puzzle from an earlier date. Reopening the app
starts at the menu and Resume loads its board, counters and undo history.

Completion recording, the reward ledger, unlocks and the solved session are part
of the same save state/write. Total stars are derived from the ledger rather
than an increment-only total. Duplicate events, app reloads and replays are
idempotent. Existing Task 3 comfort settings are migrated from `preferences.cfg`
when no versioned save exists; future settings use the versioned repository.

Writes go to a `.tmp` file, are flushed/validated, and renamed into place. The
previous valid primary is copied to `.bak`. On load:

- Missing files create defaults without an error.
- A corrupt primary falls back to the last valid backup.
- If both are corrupt, the app explains the recovery and starts defaults; the
  unreadable primary is preserved as `.corrupt` before a replacement is written.
- An unsupported-version or inaccessible primary/backup is kept read-only so an
  older app cannot overwrite it. Gameplay remains possible in memory, with a
  visible saving warning.
- Malformed optional settings/rewards are sanitized. Boards and undo chains are
  checked again against the current puzzle signature. A broken undo stack is
  dropped while retaining a valid board/counters; an invalid board is restarted
  with an explanatory notice. JSON numeric types are normalized on restoration.

The save has a 32 MiB limit to reject pathological files. A backup can recover
the previous committed state if the latest file is damaged. Local files are not
cloud backups or protected against deliberate editing. The app reports failed
writes instead of claiming that in-memory changes reached disk.

## Stable daily puzzle

`DailyPuzzle.select(date, catalog)` validates an exact Gregorian `YYYY-MM-DD`
date and hashes `date | catalog daily seed | puzzle seed | puzzle ID` for every
entry in the manifest's frozen `daily_pool` (the original 32 IDs). The lowest
hash wins, independently of RNG/global state and
manifest iteration order. The chosen board is cloned under `daily_YYYY-MM-DD`,
keeping its source ID/seed and difficulty. Daily access does not require campaign
unlocks and daily completion never unlocks the source campaign level.

The selected definition is frozen in the save on first access, preserving it
across restarts and later manifest changes. The date comes from the device's local
calendar. No network, account or remote time check is used. Each date has its own
progress and one-time reward key. Different dates may intentionally select the
same source board from the finite collection.

## Code boundaries

| Component | Responsibility |
| --- | --- |
| `LevelCatalog` | Load and uniquely validate all committed campaign puzzles; lookups/order/signatures |
| `DailyPuzzle` | Deterministic date/seed selection and date validation |
| `PuzzleSession` | Board actions, undo, safe hints, attempt statistics, limits, snapshots |
| `PlayerSave` | Versioned JSON parsing, sanitization, temporary writes, backup/recovery |
| `ProgressionService` | Unlock gates, per-puzzle sessions, resume choice and one-time rewards |
| `GameServices` | Compose services and connect the settings adapter |
| Existing screen scripts | Render service state, forward actions, display confirmation and victory |

## Verification

From the project directory with `$engine` set as described in README:

```powershell
& $engine --headless --editor --path . --import --quit
& $engine --headless --path . --script res://tests/engine_tests.gd
& $engine --headless --path . --script res://tests/progression_tests.gd
& $engine --headless --path . --script res://tests/test_runner.gd
& $engine --headless --path . --script res://tests/mobile_ui_tests.gd
& $engine --headless --path . --script res://tests/convenience_ui_tests.gd
node tests/validate_project.js
```

Tests use isolated saves, never the player's normal save. Progression tests cover
the full 150-level unlock path, all reward tiers, duplicate rewards, missing and
corrupt files, backup recovery, future versions, interrupted temporary writes,
undo after JSON reload, safe hints, mistake budgets, settings and daily dates.
Convenience UI tests actually destroy/recreate the app scene and reload from disk
to check Resume, then exercise restart Cancel/Confirm, locks, hints, Next and Replay.

Rendered captures can be refreshed with:

```powershell
& $engine --path . --script res://tests/mobile_ui_tests.gd -- --capture
& $engine --path . --script res://tests/convenience_ui_tests.gd -- --capture
```

New captures are in `artifacts/progression/`. Validation is on Windows/Godot 4.5.1;
mobile devices, signing and hardware haptics still require physical-device tests.
