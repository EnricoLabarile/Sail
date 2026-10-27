"""Makes two sounds (Enrico's sound pass):
  Assets/SFX/imp_death.ogg   a sea imp killed: a low, falling growl (a buzzy tone sliding down from 110 to 38 Hz,
                             wobbling) under a gurgle of low-passed noise, a little overdriven, about a second long;
  Assets/SFX/bomb_blast.ogg  a bomb going off: a sharp crack of noise, a deep boom falling from 80 to 28 Hz and a
                             long low rumble of noise dying away, about a second and a half.
Run:  python art_src/audio/make_danger_sounds.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(7)          # the same noise every time the script runs


def low_pass(sound, cutoff):
    b, a = butter(2, cutoff / (RATE / 2), "low")
    return lfilter(b, a, sound)


def sweep(f_start, f_end, length, curve=2.0):
    """A tone whose pitch slides from f_start to f_end (quickly at first, then slower); returns its phase."""
    t = np.arange(int(RATE * length)) / RATE
    share = (t / length) ** (1 / curve)
    freq = f_start + (f_end - f_start) * share
    return 2 * np.pi * np.cumsum(freq) / RATE, t


def save(sound, name, loudness=0.6):
    sound = sound / np.max(np.abs(sound)) * loudness
    pcm = (sound * 32767).astype(np.int16)
    path = "/tmp/" + name + ".wav"
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                    "Assets/SFX/" + name + ".ogg"], check=True)
    print("saved Assets/SFX/" + name + ".ogg")


# ---- the imp's death: low, with noise ----
length = 1.1
phase, t = sweep(110, 38, length)
phase += 0.6 * np.sin(2 * np.pi * 9 * t)              # a wobble in the pitch: a throaty growl
growl = np.sign(np.sin(phase)) * 0.5 + np.sin(phase) * 0.5   # buzzy (half square, half sine)
growl = low_pass(growl, 1100)                         # low pitch, but its overtones kept (a phone's speaker
                                                      # can't play 40-110 Hz: the ear hears the bass in them)
noise = low_pass(rng.uniform(-1, 1, t.size), 600)     # the gurgle: low noise…
noise *= 0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)        # …bubbling 14 times a second
envelope = np.minimum(1, t / 0.02) * np.exp(-t / 0.45)
save(np.tanh(2.0 * (growl * 0.8 + noise * 1.6) * envelope), "imp_death")   # tanh: a soft overdrive, for grit


# ---- the bomb: crack, boom, rumble ----
length = 1.6
phase, t = sweep(80, 28, length, 3.0)
boom = np.sin(phase) * np.exp(-t / 0.35)              # the deep thump
crack = low_pass(rng.uniform(-1, 1, t.size), 2500) * np.exp(-t / 0.02)   # the sharp start (very short, not too bright)
rumble = low_pass(rng.uniform(-1, 1, t.size), 450) * np.exp(-t / 0.6) * 3.0   # low noise rolling away
attack = np.minimum(1, t / 0.003)
# tanh: overdriven, so the deep boom gets overtones a phone's small speaker can play
save(np.tanh(2.5 * (boom * 1.2 + crack * 0.5 + rumble) * attack), "bomb_blast", 0.7)
