"""Makes Assets/SFX/boat_hurt.ogg: the boat losing hearts (Enrico: one sound for every kind of damage; boat.gd
take_damage plays it through Sfx.boat_hurt). It must not sound like the hull's bump (hull_bump.ogg): a sharp CRACK
of splintering wood (a few very short bursts of bright noise, 1.5-5 kHz, close together, like planks giving way), on
a low heavy THUD (a tone falling 110 -> 55 Hz, with overtones a phone's speaker can play), and a short creak after
(a band of noise sliding down 900 -> 400 Hz); about 0.4 s.
Run:  python art_src/audio/make_boat_hurt.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(23)          # the same noise every time the script runs


def band_pass(sound, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], "band")
    return lfilter(b, a, sound)


length = 0.42
t = np.arange(int(RATE * length)) / RATE
# the thud: a heavy tone falling 110 -> 55 Hz, with overtones
freq = 55 + 55 * np.exp(-t / 0.06)
phase = 2 * np.pi * np.cumsum(freq) / RATE
thud = (np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase)) * np.exp(-t / 0.12)
# the crack: 4 tiny bursts of bright noise in the first 60 ms, each dying in a few milliseconds (splinters)
crack = np.zeros(t.size)
bright = band_pass(rng.uniform(-1, 1, t.size), 1500, 5000)
for start in (0.0, 0.012, 0.027, 0.05):
    shifted = np.clip(t - start, 0, None)
    crack += bright * np.exp(-shifted / 0.006) * (t >= start) * rng.uniform(0.6, 1.0)
# the creak: noise whose band slides down, a little later and quieter
creak = np.zeros(t.size)
noise = rng.uniform(-1, 1, t.size)
pieces = 8
for i in range(pieces):                   # the band moves down in 8 steps, each blended over its slice
    low = 900 - 500 * i / pieces
    part = band_pass(noise, low * 0.8, low * 1.2)
    window = np.exp(-((t - (0.08 + 0.03 * i)) / 0.03) ** 2)
    creak += part * window
creak *= 0.5
attack = np.minimum(1, t / 0.001)
sound = np.tanh(1.6 * (thud * 1.0 + crack * 1.6 + creak) * attack)   # a soft overdrive, for body on a phone
fade = np.minimum(1.0, (length - t) / 0.03)                           # no click at the end
sound = sound * fade
sound = sound / np.max(np.abs(sound)) * 0.75
path = "/tmp/boat_hurt.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/boat_hurt.ogg"], check=True)
print("saved Assets/SFX/boat_hurt.ogg")
