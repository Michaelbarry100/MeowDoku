"""Original MeowDoku synthesis. No recordings, samples, third-party melodies, or network calls.
Run with numpy and soundfile installed. Seeded, reproducible composition and sound design.
"""
from pathlib import Path
import hashlib
import json
import threading
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
RNG = np.random.default_rng(72641)


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def voice(midi, length=2.4, bell=False):
    t = np.arange(round(length * RATE)) / RATE
    f = note(midi)
    attack = 1 - np.exp(-t / (0.012 if bell else 0.008))
    x = np.zeros_like(t)
    for harmonic, amplitude in enumerate([1, .32, .13, .055, .022], 1):
        ratio = harmonic + (.003 * harmonic**2 if bell else 0)
        x += amplitude * np.sin(2*np.pi*f*ratio*t) * np.exp(-t*(1.0 + .7*harmonic)/(1.8 if bell else 1))
    x *= attack * np.minimum(1, (length-t)/.06)
    return x * (.20 if bell else .24)


def add(buffer, sound, at, gain=1, pan=0):
    start = round(at*RATE)
    for channel, g in enumerate([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)]):
        # Wrap reverberant tails around the loop boundary, preserving continuity.
        indices = (np.arange(len(sound)) + start) % len(buffer)
        np.add.at(buffer[:, channel], indices, sound*gain*g)


def save(relative, samples, loop=False):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = np.max(np.abs(samples))
    if peak > .87:
        samples = samples * (.87/peak)
    sf.write(path, samples, RATE, subtype='VORBIS' if path.suffix == '.ogg' else 'PCM_16')
    print(relative, f'{len(samples)/RATE:.2f}s', f'peak={np.max(np.abs(samples)):.3f}')
    return {'filename': relative, 'creator': 'Original MeowDoku procedural composition and synthesis',
            'source': 'tools/generate_audio.py', 'license': 'CC0-1.0', 'attribution_required': False,
            'record': 'audio/LICENSE-CC0.txt', 'loop': loop,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def envelope(t, duration, attack=.025, release=.08):
    return np.minimum(1, t/attack) * np.minimum(1, (duration-t)/release)


def cat_sound(kind):
    duration = {'meow': .79, 'chirp': .46, 'purr': 3.0}[kind]
    t = np.arange(round(duration*RATE))/RATE
    if kind == 'purr':
        # Periodic modulation; integer cycles ensure a seamless loop.
        x = (.075*np.sin(2*np.pi*110*t) + .035*np.sin(2*np.pi*220*t)) * (.55+.45*np.sin(2*np.pi*25*t))
        x += .014*np.sin(2*np.pi*330*t) * (.5+.5*np.sin(2*np.pi*4*t))
        return x
    u = t/duration
    frequency = (460+210*np.sin(np.pi*u)-250*u) if kind == 'meow' else (610+210*np.sin(np.pi*u)+70*u)
    frequency *= 1+.012*np.sin(2*np.pi*7*t)
    phase = 2*np.pi*np.cumsum(frequency)/RATE
    # Formant-weighted harmonics, a deliberately stylized vowel rather than a recording.
    x = sum(np.sin(phase*h) * np.exp(-((frequency*h-(1150-380*u))/1000)**2)/h for h in range(1,7))
    return x * envelope(t,duration,.04,.12) * .21


def main():
    manifest = []
    # Original 16-bar, 76.8-second composition; 50 BPM, 4 beats per bar.
    music = np.zeros((round(76.8*RATE), 2))
    chords = [(48,55,60,64),(45,52,57,60),(41,48,53,57),(43,50,55,59)]
    melody = [72,76,79,76,74,72,69,72,77,76,72,69,71,74,79,74]
    for bar in range(16):
        chord = chords[bar%4]
        for step in range(8):
            pitch = chord[[0,2,1,3,1,2,3,1][step]]
            at = bar*4.8+step*.6
            add(music, voice(pitch,3), at, .53, -.24)
        add(music, voice(melody[bar],3.5), bar*4.8+.6, .62, .18)
        add(music, voice(melody[(bar+1)%16],2.8), bar*4.8+3, .40, .12)
        if bar%2 == 0:
            add(music, voice(melody[bar]+12,4.0,True), bar*4.8+1.8, .16, .36)
    # Very quiet stereo echoes, rolled so reverb tails remain continuous at the loop.
    music += np.roll(music,round(.19*RATE),axis=0)*.15 + np.roll(music,round(.37*RATE),axis=0)*.07
    music -= music.mean(axis=0)
    manifest.append(save('audio/music/bgm_cozy_piano.ogg',music,True))
    for name, kind in [('cat_meow_01','meow'),('cat_purr_loop','purr'),('cat_happy_chirp','chirp')]:
        manifest.append(save('audio/cats/'+name+'.ogg',cat_sound(kind),kind=='purr'))
    for name, pitches in [('ui_soft_pop',[79]),('tile_place',[72,79]),('hint_chime',[79,83,86]),('level_complete',[72,76,79,84,83,79,84]),('invalid_move',[55,53])]:
        duration = {'ui_soft_pop':.14,'tile_place':.24,'hint_chime':.80,'level_complete':2.1,'invalid_move':.30}[name]
        sound = np.zeros(round(duration*RATE))
        for i,pitch in enumerate(pitches):
            start = round(i*(.16 if name=='level_complete' else .075)*RATE)
            if start>=len(sound):
                continue
            tone = voice(pitch,duration-start/RATE,bell=name in ['hint_chime','level_complete'])
            sound[start:start+len(tone)] += tone * (.65 if name=='invalid_move' else .8)
        sound *= envelope(np.arange(len(sound))/RATE,duration,.004,.05)
        manifest.append(save('audio/sfx/'+name+'.wav',sound))
    (ROOT/'audio/asset_manifest.json').write_text(json.dumps({'version':1,'assets':manifest},indent=2)+'\n')


if __name__ == '__main__':
    # The bundled Windows Python has a small native main-thread stack. Vorbis
    # encoding needs more; use an explicit worker stack rather than silent failure.
    threading.stack_size(16 * 1024 * 1024)
    errors = []
    def worker():
        try:
            main()
        except BaseException as error:
            errors.append(error)
    job = threading.Thread(target=worker)
    job.start()
    job.join()
    if errors:
        raise errors[0]
