"""Makes Assets/SFX/button_press.ogg: the sound of pressing a button (Enrico: a very mild, low-pitched press; for now
the wheel's hub, the anchor button, whenever a finger goes down on it: in a talk, to drop or to weigh the anchor).
A soft, short "tock", 70 ms: a round tone falling a little, 170 -> 130 Hz (with a touch of its 2nd harmonic, so a
phone's small speaker still plays something of it), plus a tiny muffled tick of low-passed noise at the very start,
like a plastic key going down. Quick attack, quick fade.
Run:  python art_src/audio/make_button_press.py  (needs numpy and ffmpeg)."""
import subprocess, wave
import numpy as np

RATE = 44100
length = 0.07
t = np.arange(int(RATE * length)) / RATE
frequency = 130 + 40 * np.exp(-t / 0.02)                  # 170 Hz falling to 130 Hz
phase = 2 * np.pi * np.cumsum(frequency) / RATE
tone = np.sin(phase) + 0.35 * np.sin(2 * phase)
tone_envelope = np.minimum(t / 0.003, 1.0) * np.exp(-np.clip(t - 0.003, 0, None) / 0.022)
rng = np.random.default_rng(3)
noise = rng.standard_normal(len(t))
for _ in range(3):                                        # a simple low-pass, three times over: muffled
    noise = np.convolve(noise, np.ones(12) / 12, mode="same")
tick = noise * np.exp(-t / 0.004) * 2.0
fade = np.minimum(1.0, (length - t) / 0.01)               # no click at the very end
sound = (tone * tone_envelope + tick) * fade
sound = sound / np.max(np.abs(sound)) * 0.6
path = "/tmp/button_press.wav"
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((sound * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/button_press.ogg"], check=True)
print("saved Assets/SFX/button_press.ogg")
