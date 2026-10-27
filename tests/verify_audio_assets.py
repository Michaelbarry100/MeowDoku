"""Decode and verify real audio payloads and provenance; needs numpy and soundfile."""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'audio/asset_manifest.json').read_text())
assert len(manifest['assets']) == 9
checks = 1
for item in manifest['assets']:
    path = root/item['filename']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256']
    assert item['license'] == 'CC0-1.0' and (root/item['record']).is_file()
    signal, rate = sf.read(path, always_2d=True)
    assert rate == 44100 and len(signal) > rate*.1
    assert np.isfinite(signal).all()
    rms = np.sqrt(np.mean(signal**2))
    peak = np.abs(signal).max()
    assert rms > .002 and peak < .98, (path, rms, peak)
    if item['loop']:
        assert np.max(np.abs(signal[0]-signal[-1])) < .025, 'Loop boundary discontinuity'
        checks += 1
    checks += 5
    print(f'PASS {path.name}: {len(signal)/rate:.2f}s, RMS {rms:.4f}, peak {peak:.4f}')
print(f'RESULT: {checks} decoded audio/manifest checks, 0 failures')
