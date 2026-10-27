# MeowDoku audio

Open `project.godot` in Godot 4.5.1 Standard and press F5. The existing campaign
UI and board remain the default. Music and effects default to ON, with music
at 65% and sound effects/cats at 80%. Settings → Cozy audio provides persistent
toggles and independent sliders. Existing saved choices take precedence.

## Architecture

`AudioManager` is the only audio autoload, implemented by
`scripts/audio_manager.gd`. `default_bus_layout.tres` defines Music, SFX and Cat,
each routed to Master. The manager repairs absent buses without duplicating
them. The sound-effects setting controls both SFX and Cat; music is independent.

The `MeowAudio.instance()` class accessor resolves that same named owner. It
also bootstraps one owner for custom `--script` SceneTree tests, where the
autoload global is unavailable. It does not create a second manager in normal
gameplay. All players are ordinary AudioStreamPlayers: this fixed board and UI
do not benefit from positional attenuation. Cat models and artwork are preserved.

There is one music player, six pooled one-shot players and one cat player.
Repeated events are debounced; saturated bursts are dropped, while important
feedback can replace a lower-priority pooled voice. Cat voices never overlap,
have a four-second cooldown and use pitch variation limited to ±4%. Short UI
sounds vary by ±2%; composed reward melodies retain their pitch.

Music uses OGG looping with smooth explicit play/stop fades. Mute, zero volume,
backgrounding, lost focus and ad presentation gate playback immediately.
Resume preserves the playback position and only continues if music is still
wanted and enabled. Multiple interruption reasons are tracked independently.
`set_interrupted("native_audio", true/false)` is the entry point for a future
native interruption adapter, if device testing shows one is needed.

Idle audio uses a weak reference to the active puzzle. With cats present, an
occasional three-second purr occurs after a 22–38 second initial delay, then
25–45 second intervals. Paused, hidden or completed puzzles do not emit idle
voices. No sound is triggered on every animation frame. Completion emits a
melody and attempts a cooldown-respecting happy chirp; reopening or redrawing
the victory state does not repeat it.

## Events and actual assets

| Event | Asset |
| --- | --- |
| Button, tile selection, X placement/removal, undo | `audio/sfx/ui_soft_pop.wav` |
| Cat placement, confirmed restart | `audio/sfx/tile_place.wav` |
| Invalid placement/action | `audio/sfx/invalid_move.wav` |
| Successful hint, newly unlocked level | `audio/sfx/hint_chime.wav` |
| Puzzle completion | `audio/sfx/level_complete.wav` |
| Placement vocal variation | `audio/cats/cat_meow_01.ogg`, `cat_happy_chirp.ogg` |
| Idle purr | `audio/cats/cat_purr_loop.ogg` |
| Background | `audio/music/bgm_cozy_piano.ogg` |

All nine requested target files exist and decode to non-silent audio. The
76.8-second stereo piano-and-bell composition and every effect are original
synthesis. Cat sounds are intentionally synthetic and may benefit from a
future professionally recorded collection. No silent replacements are used.

Missing or invalid resources return null, generate one diagnostic per missing
path, and leave gameplay working. A failed load never reports successful
playback. Clip resources are cached and shared by the bounded players. The
one-shot and looping flags are set on private resource copies.

## Persistence and compatibility

Audio preferences extend the existing versioned PlayerSave settings dictionary
and PlayerPreferences backend. Old versions 1 and 2 without audio fields receive
ON defaults without losing comfort settings, campaign progress or hint counts.
Invalid values are sanitized and volumes clamped to 0–1. The standalone legacy
ConfigFile preference path also supports audio migration. Save errors are shown
in the existing Settings notice. Temporary master mute and interruption flags
are runtime state; the two user toggles and slider values are persisted.

## Verification

Validated on Windows with Godot 4.5.1:

- 80 headless audio checks and 82 actual rendered/audio-mixer checks passed.
- Actual music playback crossed the loop boundary; fade-in/out, cancellation
  of a stale fade-out, bus independence, mute, reload, both slider values,
  missing clips, 100 rapid taps, voice limits and cat cooldowns were checked.
- Gameplay tests exercised actual buttons/cell actions for selection, cats,
  X placement/removal, conflicts, undo, restart, hint, completion and unlock.
- Application pause/resume notifications and overlapping interruption reasons
  were simulated, including muting while interrupted. These are not device tests.
- 48 independent decoded-file/manifest checks passed: non-silence, bounded peaks,
  finite samples, loop seams, content hashes and license records.
- Existing engine 741, progression/save 357, integration 52, mobile UI 86,
  convenience UI 52, reward inventory 61, rewarded-hint UI 67, artwork 22 and
  retained 3D 249 checks passed. The rendered mobile UI suite passed 103 checks.
  The independent Node project validator passed 466 checks.

Settings, menu, puzzle, pause and victory captures are in `artifacts/mobile/`.
An isolated real mixer capture is `artifacts/audio/verified-mix.wav`; the last
capture contained 28,672 stereo frames with a nonzero peak of about 0.053.
This confirms generated output, not subjective listening quality or device
speaker audibility. The missing-file test intentionally logs a warning for a
nonexistent test path. CLI teardown explicitly drains queued mixer resources.

Exact PowerShell commands from this project folder:

```powershell
$meowEngine = "$env:TEMP\purrfect-godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe"
& $meowEngine --headless --editor --path . --import --quit
& $meowEngine --path .
& $meowEngine --headless --path . --script res://tests/audio_tests.gd
& $meowEngine --path . --script res://tests/audio_tests.gd -- --capture-audio
& $meowEngine --path . --script res://tests/mobile_ui_tests.gd -- --capture
node tests/validate_project.js
```

To regenerate or independently decode the assets, install NumPy and SoundFile
in a development Python environment, then run `tools/generate_audio.py` or
`tests/verify_audio_assets.py`. Reimport the audio in Godot after regeneration.
The generator uses an explicit encoder thread stack for the bundled Windows
Python, avoiding the native encoder failure found during initial generation.
No Python installation is required to run the game. See
`audio/asset_manifest.json`, `audio/ASSET_LICENSES.md` and `audio/LICENSE-CC0.txt`
for provenance, commercial permissions and development-tool license records.

## Required device testing

Android and iPhone exports have not been built or tested in this revision.
Verify app switch/lock/unlock, calls and Siri/assistant interruptions, headphone
and Bluetooth changes, mute switches and platform audio-session policy, rapid
touches, saved settings after process termination, volume balance, loop seams
and battery/thermal behavior on physical devices. OS-specific audio-focus
callbacks that do not produce Godot focus/pause notifications may require a
native adapter connected to `set_interrupted`; that path is not claimed tested.
