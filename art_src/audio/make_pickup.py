"""Makes Assets/SFX/pickup.ogg: a short, snappy two-note blip for taking a thing at the floating shop.
Two quick rising notes (a soft square wave, filtered a little) with a fast attack and a quick fall, plus a tiny
click at the start so it feels snappy. Run:  python art_src/audio/make_pickup.py  (needs numpy and ffmpeg)."""
import subprocess, wave
import numpy as np

RATE = 44100

def note(freq, length, start_gain=1.0):
    t = np.arange(int(RATE * length)) / RATE
    # a square wave softened by mixing in its sine (less harsh than a pure square)
    wave_ = 0.55 * np.sign(np.sin(2 * np.pi * freq * t)) + 0.45 * np.sin(2 * np.pi * freq * t)
    attack = np.minimum(1.0, t / 0.004)                  # 4 ms in
    fall = np.exp(-t / (length * 0.35))                  # quick fall
    return wave_ * attack * fall * start_gain

first = note(988, 0.07)          # B5
second = note(1480, 0.16, 0.9)   # F#6, a fifth above
sound = np.concatenate([first, second])
click = np.zeros_like(sound)
click[:60] = np.linspace(1, 0, 60) * 0.6                # a tiny click at the very start
sound = sound + click
# a gentle low-pass (a running average over 3 samples) to take the edge off the square wave
sound = np.convolve(sound, np.ones(3) / 3, mode="same")
sound = sound / np.max(np.abs(sound)) * 0.5              # half of full scale: the other sounds are about there

pcm = (sound * 32767).astype(np.int16)
with wave.open("/tmp/pickup.wav", "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(pcm.tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/pickup.wav", "-c:a", "libvorbis", "-q:a", "5",
                "Assets/SFX/pickup.ogg"], check=True)
print("saved Assets/SFX/pickup.ogg")
