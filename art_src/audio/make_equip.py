"""Makes the sounds of things being put in hand (Enrico: each thing its own, so they can be told apart), in Assets/SFX/:
  equip_bomb.ogg        the bomb: two dry metallic clicks 70 ms apart, the first short and bright (a latch), the second
                        a little lower and fuller with a small thump under it (the slide going home). ~0.25 s.
  equip_trap.ogg        the trap: a steel spring winding tight (a rising creak) and the jaws snapping shut. ~0.35 s.
  equip_hook.ogg        the hook: a short rattle of chain links and a ringing metal clang. ~0.4 s.
  equip_harpoon.ogg     the harpoon: a taut line's rising "zing" and the catch locking with a click. ~0.35 s.
  equip_aeolus_jar.ogg  the Aeolus jar: a cork pulled (a hollow "pop") and a soft breath of wind after it. ~0.5 s.
Each .tres in Assets/Inventory/items/ points at its sound (`equip_sound`), Sfx.equip plays it.
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


def save(sound, name):
    """Writes `sound` (numbers -1..1) as Assets/SFX/<name>.ogg (a wav first, then ffmpeg to Vorbis)."""
    path = "/tmp/" + name + ".wav"
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                    "Assets/SFX/" + name + ".ogg"], check=True)
    print("saved Assets/SFX/" + name + ".ogg")


def finish(sound, drive=2.0, level=0.7):
    """A little overdrive to make it snappy, then scaled to the same loudness as the others."""
    sound = np.tanh(drive * sound)
    return sound / np.max(np.abs(sound)) * level


def envelope(t, start, attack, decay):
    """0 before `start`, rising over `attack` seconds, then dying away with `decay`."""
    local = t - start
    rise = np.clip(local / attack, 0, 1)
    return rise * np.exp(-np.clip(local - attack, 0, None) / decay) * (local >= 0)


save(sound, "equip_bomb")

# The trap: a steel spring winding tight (a creak rising 500 -> 1400 Hz, rough with noise) and the jaws snapping shut.
length = 0.36
t = np.arange(int(RATE * length)) / RATE
wind = np.clip(t / 0.2, 0, 1)
creak_hz = 500 + 900 * wind
creak = np.sin(2 * np.pi * np.cumsum(creak_hz) / RATE) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 60 * t)))
creak = creak * envelope(t, 0.0, 0.05, 0.12) * (t < 0.2) * 0.5
snap = click(t, 0.2, 2000, 6000, 0.008, 3300) * 1.3
local = np.clip(t - 0.2, 0, None)
jaws = np.sin(2 * np.pi * 140 * local) * np.exp(-local / 0.04) * (t >= 0.2) * 0.7       # the heavy jaws meeting
save(finish(creak + snap + jaws), "equip_trap")

# The hook: a short rattle of chain links (four quick little clicks) and a ringing metal clang (inharmonic partials).
length = 0.42
t = np.arange(int(RATE * length)) / RATE
rattle = sum(click(t, 0.02 + i * 0.035, 2500, 6500, 0.004, 3800 + i * 250) * (0.5 + 0.1 * i) for i in range(4))
clang_start = 0.17
local = np.clip(t - clang_start, 0, None)
on = (t >= clang_start)
clang = sum(np.sin(2 * np.pi * hz * local) * np.exp(-local / d) * a
            for hz, d, a in [(620, 0.18, 1.0), (1530, 0.10, 0.6), (2710, 0.06, 0.4)]) * on
clang = clang + click(t, clang_start, 1500, 5000, 0.01, 900) * 0.8
save(finish(rattle + 0.8 * clang, 1.6), "equip_hook")

# The harpoon: a taut line's "zing" (a tone sliding up 700 -> 2200 Hz with a little shimmer) and the catch locking.
length = 0.36
t = np.arange(int(RATE * length)) / RATE
zing_hz = 700 + 1500 * np.clip(t / 0.18, 0, 1) ** 0.7
zing = np.sin(2 * np.pi * np.cumsum(zing_hz) / RATE) * (1 + 0.3 * np.sin(2 * np.pi * 35 * t))
zing = zing * envelope(t, 0.0, 0.02, 0.09) * 0.5
lock = click(t, 0.19, 2500, 7000, 0.006, 4600) + click(t, 0.215, 1500, 4000, 0.01, 2400) * 0.9
save(finish(zing + lock), "equip_harpoon")

# The Aeolus jar: a cork pulled (a hollow pop: a short tone falling 900 -> 350 Hz) and a soft breath of wind after it.
length = 0.5
t = np.arange(int(RATE * length)) / RATE
pop_hz = 900 - 550 * np.clip(t / 0.03, 0, 1)
pop = np.sin(2 * np.pi * np.cumsum(pop_hz) / RATE) * envelope(t, 0.0, 0.002, 0.025)
pop = pop + click(t, 0.0, 800, 3000, 0.006, 600) * 0.6
breath = band_pass(rng.uniform(-1, 1, t.size), 600, 2500) * envelope(t, 0.04, 0.12, 0.15) * 0.45
save(finish(pop + breath, 1.8), "equip_aeolus_jar")
