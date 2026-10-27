# MeowDoku premium 2.5D presentation

F5 launches `scenes/main.tscn`, including the existing campaign, daily puzzles,
undo, hints, restart confirmation, saves, progression and reward abstraction.
No rule, solver, save schema, campaign identifier or reward logic was rewritten.
The former fully 3D prototype is retained at `scenes/three_d/vertical_slice.tscn`
(open that scene and press F6).

## Art and reusable components

Five original 512×512 transparent PNGs in `assets/cats/` depict a tuxedo, cream,
orange tabby, gray and rose fantasy cat. They are rendered from the project's
original procedural 3D model with smooth geometry, cheek tufts, muzzle pads,
oversized eyes, paws, physical whiskers and tail. The tabby has additional
geometric stripes. A shared upper-left warm key, cool fill and ambient light
keep all coats consistent. No external artwork, emoji cats or paid assets are
used. The earlier screenshot reference was not accessible in this chat; the
written brief guided the visual design.

- `tools/render_cat_collection.gd`: reproducible offline asset baker. Higher
  mesh tessellation is used only for baking, not mobile runtime rendering.
- `scripts/cat_artwork.gd`: shared textures, diffuse contact shadows and original
  star motif; reused by board cells, portrait groups and hint medallions.
- `scripts/cat_portrait.gd`: menu, pause, tutorial, settings, optional-hint and
  celebration artwork. Victory has a gentle reduced-motion-aware bounce.
- `scripts/tactile_tool.gd`: circular Undo, Hint and optional extra-hint controls,
  with separate text labels and native accessible Button text/signals.
- `scripts/board_mat.gd`: softly elevated cream tray behind the existing grid.
- `scripts/cozy_backdrop.gd`: lightweight cream gradient and ambient pastel wash.
- `resources/purr_theme.tres` and `scripts/ui_components.gd`: reusable rounded
  cards, softer buttons, highlights, spacing and diffuse shadows.

Each region maps consistently to a coat. Region numbers, boundary strokes,
check/exclamation symbols and written conflict feedback preserve readability
beyond color. Art keeps square proportions and fits inside each tile. Cat
placement, X marks, selection, hints and celebration use small animations;
the existing reduced-motion setting skips them. Hint placements reuse the
same placement and selection animations rather than obscuring the board.

Five texture payloads total roughly 358 KiB on disk and approximately 5 MiB
decoded RGBA before engine overhead. The campaign has no runtime 3D viewports,
character lights or mesh rendering. Textures are shared, lossless UI assets;
the baker is a development tool, not part of gameplay initialization.

## Launch and validation

Use Godot 4.5.1 Standard or a compatible Godot 4 version. Import `project.godot`
and press F5. From this workspace in PowerShell:

```powershell
$meowEngine = "$env:TEMP\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe"
& $meowEngine --path .
& $meowEngine --headless --path . --script res://tests/premium_art_tests.gd
& $meowEngine --path . --script res://tests/premium_art_tests.gd -- --capture
& $meowEngine --path . --script res://tests/mobile_ui_tests.gd -- --capture
# Rebuild the original artwork, then reimport changed PNGs:
& $meowEngine --path . --script res://tools/render_cat_collection.gd
& $meowEngine --headless --editor --path . --import --quit
```

Validation on 2026-10-26: 22 headless and 24 rendered artwork checks; 86 headless and 103 rendered mobile
UI checks; 741 engine checks; 357 progression/save checks; 52 integration checks;
52 convenience UI checks; 61 reward/inventory checks; 67 rewarded-hint UI checks;
249 retained 3D checks; 465 independent Node project checks. All passed after
fixing small-phone button padding and the asset-test hashing call. Rendered
captures cover menu, puzzle, settings, tutorial, level selection, pause, victory,
five portrait sizes from 320×568 through 768×1024 and simulated safe insets.

## Remaining limitations

The cat collection is original procedural artwork, with modeled tufts rather
than detailed fur textures or an authored character rig. Pose/expression variety
is limited: sleepy/celebration screens use shared poses and composition changes.
Typography uses Godot's bundled font. The vector app icon and star symbols remain
intentional simple artwork; no emoji cats remain in the upgraded interface.

Android/iPhone device rendering, texture import behavior, thermal performance,
physical touch/haptics and store builds have not been tested. Desktop captures
and simulated safe areas do not establish mobile hardware performance. Rewarded
advertising remains the existing optional development simulator, not a live SDK.
