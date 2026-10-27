"""Makes Assets/SFX/talk_blip.ogg: one syllable of the talk box's "voice" (Enrico: like Animal Crossing).
A short voiced blip, ~70 ms: a buzzy tone at 330 Hz (a few harmonics, like a voice) gliding a little down,
shaped through two vowel formants (an "ah"/"oh" between 700 and 1200 Hz), quick attack, quick fade.
The talk box plays it every other letter at a slightly different pitch each time, so a page "babbles".
Run:  python art_src/audio/make_talk_blip.py  (needs numpy, scipy and ffmpeg)."""
import subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

RATE = 44100


def band_pass(sound, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], "band")
    return lfilter(b, a, sound)


length = 0.07
t = np.arange(int(RATE * length)) / RATE
pitch = 330 * (1.0 - 0.12 * t / length)                 # a little glide down, like a spoken syllable
phase = 2 * np.pi * np.cumsum(pitch) / RATE
voice = sum(np.sin(phase * k) / k for k in range(1, 9))  # a buzzy tone: the first eight harmonics
vowel = band_pass(voice, 600, 900) + 0.7 * band_pass(voice, 1000, 1400) + 0.25 * voice
envelope = np.minimum(t / 0.006, 1.0) * np.exp(-np.clip(t - 0.006, 0, None) / 0.025)
sound = np.tanh(1.5 * vowel * envelope)
fade = np.minimum(1.0, (length - t) / 0.01)              # no click at the very end
sound = sound * fade
sound = sound / np.max(np.abs(sound)) * 0.6
path = "/tmp/talk_blip.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/talk_blip.ogg"], check=True)
print("saved Assets/SFX/talk_blip.ogg")
