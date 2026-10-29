"""Makes Assets/SFX/book_open.ogg and Assets/SFX/book_close.ogg: the logbook's page turn (Enrico: like turning a
page, both when it opens and when it closes; as the prototype's Sfx.book: a paper flutter, and on closing the
cover's soft thump).
The flutter: noise band-passed round 2.5 kHz (paper), its loudness flickering quickly (the sheet rippling as it
turns: a few uneven little bursts) under a swell that rises and falls over ~0.3 s, plus a softer, lower rustle
under it. Closing: a flutter as the cover folds, then a muffled thump of the cover landing (a low sine 110 -> 70 Hz and some
low-passed noise), quiet.
Run:  python art_src/audio/make_page_turn.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
rng = np.random.default_rng(7)


def band(noise, low, high):
    return sosfilt(butter(2, [low, high], btype="band", fs=RATE, output="sos"), noise)


def lowpass(noise, cut):
    return sosfilt(butter(2, cut, btype="low", fs=RATE, output="sos"), noise)


def flutter(length):
    """A sheet of paper turning: bright rustle in quick uneven bursts, under a rise-and-fall swell."""
    n = int(RATE * length)
    t = np.arange(n) / RATE
    bright = band(rng.standard_normal(n), 1500, 4500)
    soft = band(rng.standard_normal(n), 400, 1400) * 0.5
    swell = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.5          # 0 -> 1 -> 0 over the whole sound
    ripple = lowpass(np.abs(rng.standard_normal(n)), 30)               # slow random flicker (the sheet rippling)
    ripple = 0.4 + ripple / np.max(ripple)
    return (bright + soft) * swell * ripple


def thump(length):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    frequency = 70 + 40 * np.exp(-t / 0.03)
    tone = np.sin(2 * np.pi * np.cumsum(frequency) / RATE) + 0.3 * np.sin(4 * np.pi * np.cumsum(frequency) / RATE)
    knock = lowpass(rng.standard_normal(n), 600) * 2.0
    envelope = np.minimum(t / 0.003, 1.0) * np.exp(-t / 0.05)
    return (tone + knock) * envelope


def save(sound, name):
    fade = np.minimum(1.0, (len(sound) - np.arange(len(sound))) / (RATE * 0.01))   # no click at the end
    sound = sound * fade
    sound = sound / np.max(np.abs(sound)) * 0.6
    path = "/tmp/" + name + ".wav"
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                    "Assets/SFX/" + name + ".ogg"], check=True)
    print("saved Assets/SFX/" + name + ".ogg")


# Opening: one page turning, 0.35 s.
save(flutter(0.35), "book_open")

# Closing: the flutter while the cover folds (0.3 s), and the cover's thump as it lands, at 0.3 s (the logbook's
# fold takes 0.33 s: logbook.gd UNFOLD_TIME), quieter than the paper.
paper = flutter(0.3)
cover = thump(0.18)
start = int(RATE * 0.3)
close = np.zeros(start + len(cover))
close[:len(paper)] += paper / np.max(np.abs(paper))
close[start:] += cover / np.max(np.abs(cover)) * 0.45
save(close, "book_close")
