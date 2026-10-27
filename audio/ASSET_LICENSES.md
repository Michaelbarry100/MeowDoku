# MeowDoku audio provenance

All nine playable audio files are original procedural audio authored for this
project. There are no sampled recordings, commercial songs, downloaded sound
packs or third-party melodies. The music is an original 16-bar composition;
cat voices are stylized synthesized sounds, not recordings of animals.

Every asset's filename, creator/source, CC0-1.0 license, attribution requirement,
loop designation and SHA-256 identity is recorded in `asset_manifest.json`.
The dedication and permissions record is `LICENSE-CC0.txt`. These original
assets may be commercially distributed and modified without attribution.
The [CC0 legal instrument](https://creativecommons.org/publicdomain/zero/1.0/legalcode)
is linked in that record.

The synthesis source is `tools/generate_audio.py`, seeded with 72641. Music is
76.8 seconds, 50 BPM, stereo 44.1 kHz OGG Vorbis. Cat voices are mono 44.1 kHz
OGG Vorbis; five interface/reward effects are mono 16-bit 44.1 kHz WAV.

Generation-only dependencies used for this revision:

| Tool | Version | Source | License record |
| --- | --- | --- | --- |
| NumPy | 2.5.4 | https://numpy.org/ | `tools/audio_licenses/NumPy-license-record.txt` |
| SoundFile | 0.14.0 | https://github.com/bastibe/python-soundfile | `tools/audio_licenses/SoundFile-BSD-3-Clause.txt` |
| libsndfile (SoundFile's encoder dependency) | bundled with SoundFile | https://github.com/libsndfile/libsndfile | `tools/audio_licenses/libsndfile-LGPL-2.1.txt` |

These packages were installed outside the project in a temporary build folder.
They are not Godot runtime dependencies and are not shipped as binaries with
the game. Their software licenses apply to the tools, separately from the CC0
generated sound assets. If redistributing the generation environment itself,
retain that environment's complete dependency notices and source obligations.

Include the asset manifest and CC0 record with release source/distribution
records. Godot exports should retain all nine referenced audio resources;
include these non-resource license documents explicitly if packaging them
inside the application rather than alongside release documentation.
