"""Makes Assets/SFX/equip_bomb.ogg: the bomb being equipped (Enrico: snappy, like loading a gun, or a click):
two dry metallic clicks 70 ms apart, the first short and bright (a latch), the second a little lower and fuller
with a small thump under it (the slide going home). About a quarter of a second.
Run:  python art_src/audio/make_equip.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(5)          # the same noise every time the script runs


def band_pass(sound, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], "band")
    return lfilter(b, a, sound)


def click(t, start, low, high, decay, ring_hz):
    """A click starting at `start` seconds: a burst of band-passed noise plus a short metallic ring."""
    local = np.clip(t - start, 0, None)
    on = (t >= start).astype(float)
    noise = band_pass(rng.uniform(-1, 1, t.size), low, high) * np.exp(-local / decay) * on
    ring = np.sin(2 * np.pi * ring_hz * local) * np.exp(-local / (decay * 1.5)) * on
    return noise + 0.35 * ring


length = 0.26
t = np.arange(int(RATE * length)) / RATE
latch = click(t, 0.0, 3000, 7000, 0.006, 4200)                  # the first click: short and bright
slide = click(t, 0.07, 1500, 4500, 0.012, 2600) * 1.2           # the second: lower and fuller
local = np.clip(t - 0.07, 0, None)
thump = np.sin(2 * np.pi * 180 * local) * np.exp(-local / 0.03) * (t >= 0.07) * 0.5   # the slide home
sound = np.tanh(2.0 * (latch + slide + thump))
sound = sound / np.max(np.abs(sound)) * 0.7
path = "/tmp/equip_bomb.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/equip_bomb.ogg"], check=True)
print("saved Assets/SFX/equip_bomb.ogg")
