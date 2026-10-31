"""Makes Assets/SFX/booster.ogg: the boat taking a booster orb (Enrico: a power-up), 0.55 s.
A rising whoosh (noise band-passed, its band sweeping up 400 -> 3000 Hz) under a quick bright arpeggio of three notes
going up (E5, B5, E6: 659, 988, 1319 Hz, 60 ms apart, each a soft square-ish tone with a fast fade), the last one
ringing a little longer, and a low thump at the start (110 -> 70 Hz) so it feels like a push.
Run:  python art_src/audio/make_booster_sound.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
length = 0.55
t = np.arange(int(RATE * length)) / RATE
rng = np.random.default_rng(5)

# 1. The whoosh: noise through a band that slides up, done in short blocks.
noise = rng.standard_normal(len(t))
whoosh = np.zeros_like(noise)
block = 512
for i in range(0, len(t), block):
    share = min(1.0, i / RATE / 0.35)
    middle = 400 * (3000 / 400) ** share
    b, a = butter(2, [middle * 0.7 / (RATE / 2), min(0.99, middle * 1.4 / (RATE / 2))], btype="band")
    whoosh[i:i + block] = lfilter(b, a, noise[i:i + block])
whoosh *= np.sin(np.pi * np.clip(t / 0.4, 0, 1)) * 0.5          # swells and dies away over 0.4 s

# 2. The arpeggio: three notes going up.
def note(frequency, start, ring):
    nt = np.clip(t - start, 0, None)
    tone = np.sin(2 * np.pi * frequency * nt) + 0.3 * np.sin(2 * np.pi * 3 * frequency * nt)
    env = np.minimum(nt / 0.004, 1.0) * np.exp(-nt / ring)
    env[t < start] = 0.0
    return tone * env
arpeggio = note(659, 0.0, 0.05) + note(988, 0.06, 0.05) + note(1319, 0.12, 0.12)

# 3. The push: a low thump at the start.
frequency = 70 + 40 * np.exp(-t / 0.04)
phase = 2 * np.pi * np.cumsum(frequency) / RATE
thump = (np.sin(phase) + 0.4 * np.sin(2 * phase)) * np.exp(-t / 0.06) * 0.8

sound = whoosh + arpeggio * 0.45 + thump
sound *= np.minimum(1.0, (length - t) / 0.02)                    # no click at the end
sound = sound / np.max(np.abs(sound)) * 0.7
path = "/tmp/booster.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/booster.ogg"], check=True)
print("saved Assets/SFX/booster.ogg")
