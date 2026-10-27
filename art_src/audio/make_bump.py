"""Makes Assets/SFX/hull_bump.ogg: the boat's wooden hull knocking against a shore or a barrel (Enrico's sound pass):
a dull thud of the hull (a tone sliding down from 150 to 75 Hz, with overtones a phone's speaker can play), a short
woody knock (noise band-passed round 700 Hz) and a little scrape of grit after it; about half a second.
Run:  python art_src/audio/make_bump.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(11)          # the same noise every time the script runs


def band_pass(sound, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], "band")
    return lfilter(b, a, sound)


def low_pass(sound, cutoff):
    b, a = butter(2, cutoff / (RATE / 2), "low")
    return lfilter(b, a, sound)


length = 0.55
t = np.arange(int(RATE * length)) / RATE
# the hull's thud: a tone falling 150 → 75 Hz, dying away quickly
freq = 75 + 75 * np.exp(-t / 0.05)
phase = 2 * np.pi * np.cumsum(freq) / RATE
thud = (np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase)) * np.exp(-t / 0.09)
# the woody knock: a short burst of noise round 700 Hz (the planks)
knock = band_pass(rng.uniform(-1, 1, t.size), 450, 1100) * np.exp(-t / 0.025)
# a little scrape after it: low grainy noise, a bit later and longer
scrape = low_pass(rng.uniform(-1, 1, t.size), 1800) * np.exp(-((t - 0.08) / 0.12) ** 2) * 0.35
attack = np.minimum(1, t / 0.002)
sound = np.tanh(1.8 * (thud * 1.0 + knock * 1.4 + scrape) * attack)   # tanh: a soft overdrive, for body on a phone
sound = sound / np.max(np.abs(sound)) * 0.7
path = "/tmp/hull_bump.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/hull_bump.ogg"], check=True)
print("saved Assets/SFX/hull_bump.ogg")
