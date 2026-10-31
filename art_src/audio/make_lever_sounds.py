"""Makes the lever's sounds (Enrico):
  Assets/SFX/lever_hook.ogg   the boat hooked to a lever: a low, full click (a latch closing): a dull knock of low-passed
                              noise and a short tone falling 160 -> 110 Hz with its overtones, 0.18 s.
  Assets/SFX/lever_drag.ogg   the handle being dragged out: a LOOP, 2 s, of rough friction and a taut rope (noise
                              band-passed round 500 Hz with an uneven grainy flutter, plus soft low creaks); the game sets
                              its loudness and pitch from how fast the handle comes out (lever.gd, Sfx.lever_drag).
  Assets/SFX/lever_done.ogg   the lever pulled all the way: a dry, higher click, a snap (two sharp ticks 25 ms apart and a
                              short bright ring at 1.6 kHz), 0.2 s.
Run:  python art_src/audio/make_lever_sounds.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(21)


def times(length):
    return np.arange(int(RATE * length)) / RATE


def band(signal, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], btype="band")
    return lfilter(b, a, signal)


def lowpass(signal, cutoff):
    b, a = butter(2, cutoff / (RATE / 2))
    return lfilter(b, a, signal)


def save(sound, name, peak, fade_end=True):
    if fade_end:
        sound = sound * np.minimum(1.0, (len(sound) / RATE - np.arange(len(sound)) / RATE) / 0.005)
    sound = sound / np.max(np.abs(sound)) * peak
    path = "/tmp/" + name + ".wav"
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                    "Assets/SFX/" + name + ".ogg"], check=True)
    print("saved Assets/SFX/" + name + ".ogg")


# 1. Hooked: a low, full click.
t = times(0.18)
knock = lowpass(rng.standard_normal(len(t)), 900) * np.exp(-t / 0.012) * 2.0
frequency = 110 + 50 * np.exp(-t / 0.03)
phase = 2 * np.pi * np.cumsum(frequency) / RATE
tone = (np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.25 * np.sin(3 * phase)) * np.exp(-t / 0.045)
tick = band(rng.standard_normal(len(t)), 1200, 3000) * np.exp(-t / 0.002) * 0.6
save(knock + tone + tick, "lever_hook", 0.75)

# 2. The drag: a seamless 2 s loop (made 2.5 s long, the extra half second cross-faded onto the start).
length, overlap = 2.0, 0.5
t = times(length + overlap)
friction = band(rng.standard_normal(len(t)), 300, 800)
grain = 0.55 + 0.45 * np.abs(band(rng.standard_normal(len(t)), 8, 30)) / 0.3     # an uneven, grainy flutter
friction *= np.clip(grain, 0.2, 1.6)
creaks = np.zeros_like(t)
for start in rng.uniform(0, length, 5):                                          # a few soft low creaks
    ct = np.clip(t - start, 0, None)
    frequency = rng.uniform(140, 220)
    creak = np.sin(2 * np.pi * frequency * ct + 3 * np.sin(2 * np.pi * 30 * ct)) * np.exp(-ct / 0.08)
    creak[t < start] = 0.0
    creaks += creak * 0.35
drag = friction + creaks
n, k = int(RATE * length), int(RATE * overlap)
loop = drag[:n].copy()
ramp = np.linspace(0.0, 1.0, k)
loop[:k] = loop[:k] * ramp + drag[n:n + k] * (1.0 - ramp)                         # the tail fades into the start
save(loop, "lever_drag", 0.6, fade_end=False)

# 3. Done: a dry, higher click, a snap.
t = times(0.2)
def tick_at(at, loud):
    s = band(rng.standard_normal(len(t)), 2500, 8000) * np.exp(-np.clip(t - at, 0, None) / 0.002)
    s[t < at] = 0.0
    return s * loud
rt = np.clip(t - 0.025, 0, None)
ring = np.sin(2 * np.pi * 1600 * rt) * np.exp(-rt / 0.03) * 0.3
ring[t < 0.025] = 0.0
body = band(rng.standard_normal(len(t)), 500, 1400) * np.exp(-np.clip(t - 0.025, 0, None) / 0.01) * 0.5
body[t < 0.025] = 0.0
save(tick_at(0.0, 0.7) + tick_at(0.025, 1.0) + ring + body, "lever_done", 0.7)
