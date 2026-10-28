"""Makes Assets/SFX/gust_whoosh.ogg: a very mild whoosh for the wind gust booster (Enrico: soft feedback).
Noise through a band-pass that sweeps up then down (400 → 1400 → 600 Hz), swelling in over 0.12 s and fading
out over the rest, 0.6 s in all; soft, no click.
Run:  python art_src/audio/make_whoosh.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(11)
length = 0.6
n = int(RATE * length)
t = np.arange(n) / RATE
noise = rng.uniform(-1, 1, n)
# The sweep: filter short blocks of the noise, each at its own centre frequency.
out = np.zeros(n)
block = 512
for start in range(0, n, block):
    s = (start + block / 2) / n                       # 0..1 along the sound
    centre = 400 + 1000 * np.sin(np.pi * min(s * 1.4, 1.0)) if s < 0.72 else 600 + 800 * (1 - s) / 0.28 * 0.5
    low, high = centre * 0.6, centre * 1.5
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], "band")
    seg = noise[max(0, start - 2048):start + block]
    filtered = lfilter(b, a, seg)[-min(block, n - start):]
    out[start:start + len(filtered)] = filtered
envelope = np.minimum(t / 0.12, 1.0) * np.clip((length - t) / (length - 0.12), 0, 1) ** 1.5
sound = out * envelope
sound = sound / np.max(np.abs(sound)) * 0.5
path = "/tmp/gust_whoosh.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/gust_whoosh.ogg"], check=True)
print("saved Assets/SFX/gust_whoosh.ogg")
