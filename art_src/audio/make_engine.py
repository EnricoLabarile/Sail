"""Makes Assets/SFX/engine_loop.ogg: the paddle steamer's engine (Enrico, Nov 2026: "revving when she moves").
A seamless 2 s LOOP of a steam engine's "chuff-chuff": 8 puffs of steam (4 a second), strong and weak in turn like
a two-cylinder engine, each a burst of hissing noise band-passed round 400-2500 Hz that dies away quickly, with a
short woody knock of the piston under it. Played round and round by sfx.gd (Sfx.engine): its pitch_scale speeds the
whole loop up or slows it down, so the puffs come quicker and higher as she goes faster (the revving).
Kept above ~200 Hz on purpose: a phone's speaker can't play the deep part.
Run:  python art_src/audio/make_engine.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
LENGTH = 2.0            # seconds of the loop
PUFFS = 8               # puffs in it (a whole number, so the loop joins up evenly)
rng = np.random.default_rng(7)          # the same noise every time the script runs


def band_pass(sound, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], "band")
    return lfilter(b, a, sound)


n = int(RATE * LENGTH)
loop = np.zeros(n)
period = n // PUFFS
for i in range(PUFFS):
    strong = i % 2 == 0                                    # strong and weak in turn, like two cylinders
    size = int(RATE * 0.35)                                 # a puff with its tail (it may run past the loop's end)
    t = np.arange(size) / RATE
    hiss = band_pass(rng.uniform(-1, 1, size), 400, 2500)  # the steam
    puff = hiss * np.exp(-t / (0.07 if strong else 0.05)) * np.minimum(1, t / 0.006)
    knock = band_pass(rng.uniform(-1, 1, size), 220, 600) * np.exp(-t / 0.018)   # the piston's knock
    puff = puff * (1.0 if strong else 0.6) + knock * (0.8 if strong else 0.5)
    start = i * period + int(rng.uniform(-0.004, 0.004) * RATE) % n               # a hair of unevenness
    for k in range(size):                                   # added round the loop: a tail past the end wraps to the start
        loop[(start + k) % n] += puff[k]

sound = np.tanh(1.5 * loop / np.max(np.abs(loop)))         # tanh: a soft overdrive, for body on a phone
sound = sound / np.max(np.abs(sound)) * 0.7
path = "/tmp/engine_loop.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/engine_loop.ogg"], check=True)
print("saved Assets/SFX/engine_loop.ogg")
