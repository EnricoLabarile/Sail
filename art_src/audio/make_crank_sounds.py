"""Makes the paddles' and the crank's sounds (Enrico):
  Assets/SFX/crank_click.ogg    one tooth of the crank's gear going past the pawl: a dry, short clack (a sharp tick of
                                bright noise and a little woody knock at ~900 Hz), 60 ms. The game plays it 16 times a
                                turn, each a little higher, an octave up by the end of the turn (crank.gd, Sfx.crank_click).
  Assets/SFX/paddle_splash.ogg  a paddle of the wheels dipping into the water, the HTML prototype's Sfx.paddle: a low,
                                soft splash (noise low-passed, its cutoff falling 340 -> 120 Hz, attack 35 ms, 0.2 s) and
                                a soft thud (a sine falling 75 -> 48 Hz, attack 25 ms, 0.14 s). Its overtones are kept
                                a little (a phone's speaker can't play 50 Hz).
  Assets/SFX/crank_unlock.ogg   the crank free again: a snappy mechanical unlock, a latch's double click (two sharp
                                metallic ticks 45 ms apart, the second louder) and a short bright ring of a spring
                                (2.1 kHz, fading in 0.15 s), 0.25 s.
Run:  python art_src/audio/make_crank_sounds.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100
rng = np.random.default_rng(11)


def times(length):
    return np.arange(int(RATE * length)) / RATE


def band(signal, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], btype="band")
    return lfilter(b, a, signal)


def lowpass_falling(signal, start, end, length):
    """A low-pass whose cutoff slides from start to end Hz over `length` seconds (done in short blocks)."""
    out = np.zeros_like(signal)
    block = 256
    state = None
    for i in range(0, len(signal), block):
        t = i / RATE
        cutoff = start * (end / start) ** min(1.0, t / length)
        b, a = butter(2, cutoff / (RATE / 2))
        if state is None:
            state = np.zeros(max(len(a), len(b)) - 1)
        out[i:i + block], state = lfilter(b, a, signal[i:i + block], zi=state)
    return out


def envelope(t, attack, decay_to, length):
    """Up in `attack` seconds, then down exponentially to `decay_to` (a share) by `length`."""
    rise = np.minimum(t / attack, 1.0)
    fall = np.exp(np.log(decay_to) * np.clip(t - attack, 0, None) / (length - attack))
    return rise * fall


def save(sound, name, peak):
    sound = sound * np.minimum(1.0, (len(sound) / RATE - np.arange(len(sound)) / RATE) / 0.005)   # no click at the end
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


# 1. The crank's click: a sharp tick and a woody knock.
t = times(0.06)
tick = band(rng.standard_normal(len(t)), 2500, 7000) * np.exp(-t / 0.003)
knock = band(rng.standard_normal(len(t)), 600, 1300) * np.exp(-t / 0.012) * 1.4
body = np.sin(2 * np.pi * 900 * t) * np.exp(-t / 0.01) * 0.5
save(tick + knock + body, "crank_click", 0.7)

# 2. The paddle's splash (the prototype's Sfx.paddle).
t = times(0.22)
splash = lowpass_falling(rng.standard_normal(len(t)), 340, 120, 0.16) * envelope(t, 0.035, 0.001, 0.2) * 1.0
frequency = 48 + 27 * np.exp(-t / 0.04)                       # 75 Hz falling to 48 Hz
phase = 2 * np.pi * np.cumsum(frequency) / RATE
thud = (np.sin(phase) + 0.4 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase)) * envelope(t, 0.025, 0.001, 0.14) * 0.6
thud[t > 0.15] = 0.0
save(splash * 4.0 + thud, "paddle_splash", 0.8)

# 3. The crank unlocked: a latch's double click and a spring's ring.
t = times(0.25)
def latch(at, loud):
    s = band(rng.standard_normal(len(t)), 3000, 9000) * np.exp(-np.clip(t - at, 0, None) / 0.0025)
    s[t < at] = 0.0
    return s * loud
ring_t = np.clip(t - 0.045, 0, None)
ring = (np.sin(2 * np.pi * 2100 * ring_t) + 0.5 * np.sin(2 * np.pi * 3150 * ring_t)) * np.exp(-ring_t / 0.05) * 0.35
ring[t < 0.045] = 0.0
clunk = band(rng.standard_normal(len(t)), 300, 900) * np.exp(-np.clip(t - 0.045, 0, None) / 0.015) * 0.6
clunk[t < 0.045] = 0.0
save(latch(0.0, 0.6) + latch(0.045, 1.0) + ring + clunk, "crank_unlock", 0.7)
