# MeowDoku: genuine 3D vertical slice

This records the earlier 3D milestone. Following the premium 2.5D visual upgrade,
F5 launches the campaign UI. Open the scene below and press F6 for the retained
3D prototype; the rest of this document describes that separate milestone.

Open `project.godot` in Godot 4.5.1 Standard. The 3D scene is
`scenes/three_d/vertical_slice.tscn`, whose root is Node3D. No downloaded assets,
textures, emoji, sprites, rendered character images or paid plugins are used.
The previous game remains available as `scenes/main.tscn` (open it and press F6).
Its save directory and identifiers are preserved.

## Implemented

- A uniquely solvable, seeded production 4×4 level in `data/three_d_garden.json`.
  Existing LevelData, PuzzleValidator, PuzzleSolver, PuzzleRules and PuzzleSession
  admit the level and manage state; rendering does not decide victory.
- Sixteen individually collidable, thick, rounded and beveled ArrayMesh tiles,
  a ceramic base, floor, plant and pebbles. Shared StandardMaterial3D resources
  provide pastel regions and lit cat surfaces.
- Reusable original tuxedo cat geometry: rounded body/head, geometric markings,
  four paws, solid ears, eyes/pupils/glints, nose, mouth, whiskers and curved tail.
  Each cat has 5,792 triangles across seven material surfaces, shared between
  instances. Meshes are indexed and component surfaces merged by material.
- Orthographic Camera3D, one shadow-casting DirectionalLight3D and ambient
  WorldEnvironment. A camera close-up in the captures shows actual model depth.
- Physics raycasts select tiles or their cat volumes. Mouse and native touch
  work; drags, duplicate emulated mouse events and suspended input are rejected.
- State follows PuzzleSession: real cat placement, raised selection, geometric
  X notes, check/exclamation marks, conflict explanations, moves/mistakes, undo,
  restart and rule-checked completion. Completed boards lock further placement.
- A safe-area container HUD and responsive camera fit. Five portrait sizes from
  320×568 to 768×1024 were tested; projected tile targets remain at least 48
  logical units in each dimension. Text and symbols supplement state colors.
- Cat appearance bounce, gentle idle and blink; motion can be disabled. Low
  quality disables shadows, 2× MSAA and idle movement. Balanced enables them.

## Run and test on Windows

From the project directory, replace this portable engine path if necessary:

```powershell
$godot3d = "$env:TEMP\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe"
& $godot3d --headless --editor --path . --import --quit
& $godot3d --path .
& $godot3d --headless --path . --script res://tests/three_d_tests.gd
& $godot3d --path . --script res://tests/three_d_tests.gd -- --capture
```

The rendered suite checks actual physics selection, native touch events,
conflicts, undo, model geometry, completion, quality toggles, suspension and
portrait sizing. Ten PNG captures are saved under `artifacts/three_d/`.
`--profile` enables an optional diagnostic HUD during normal play.

Validation completed on 2026-10-26 with zero failures:

| Suite | Checks |
| --- | ---: |
| 3D, headless | 249 |
| 3D, actual OpenGL rendering and captures | 259 |
| Existing rules/solver/generation | 741 |
| Progression/save/session | 357 |
| Existing game integration | 52 |
| Existing mobile UI | 86 |
| Existing convenience UI | 52 |
| Rewarded-ad/inventory abstraction | 61 |
| Existing rewarded-hint UI | 67 |
| Node project/independent puzzle validation | 456 |

Editor import and a separate default-scene rendered launch also exited cleanly.
During visual QA, overexposed lighting and incorrectly scaled rotated whisker
and check-mark geometry were found and corrected before these final results.

## Scope and limitations

This milestone is a playable vertical slice, not the completed store game.
The prior menus, campaign, save/resume, daily puzzles and mock rewarded ads are
retained separately, pending their integration after this 3D milestone. The
prototype itself does not save attempts or grant campaign rewards. Its Restart
is immediate. No real ad SDK or store export was added.

All models are procedural prototype assets. The cat uses rigid mesh parts and
simple procedural animation, not an authored skeletal rig. The steep camera
angle prioritizes touch readability; model-detail screenshots use a lower
camera angle. Region identity is primarily its pastel color, supplemented by
the boundaries between separated tiles; color-vision accessibility can improve.

Compatibility rendering supports OpenGL ES 3 mobile targets. SSAO is deliberately
not enabled because it is unavailable in this renderer; the scene uses real
directional shadows. See the official [renderer comparison](https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html).
The tile and mesh implementation uses Godot's documented
[clockwise face winding](https://docs.godotengine.org/en/4.5/classes/class_surfacetool.html).

Verified with Godot 4.5.1 on desktop Intel UHD Graphics/OpenGL 3.3. One completed
board capture reported 162 draw calls and 74,980 rendered primitives, including
shadow passes. These are desktop observations, not mobile performance claims.
Android/iPhone hardware, thermal behavior, device cutouts, real suspension and
store exports remain untested. Shadows are intentionally optional; mobile GPU
profiling and further draw-call reduction are required before release.
