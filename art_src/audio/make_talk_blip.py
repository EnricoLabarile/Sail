"""Makes Assets/SFX/talk_blip.ogg: one syllable of the talk box's "voice" (Enrico: like Animal Crossing).
Second version (Enrico: the first was whiny, too much change of pitch): a plain little "dot" of sound, 50 ms,
a round tone at 240 Hz that holds its pitch (no glide), with just a touch of its 2nd and 3rd harmonics so it
isn't a bare beep; quick attack, quick fade. The talk box plays it every other letter, and sfx.gd changes its pitch
only a little each time (talk_pitch_min / talk_pitch_max).
Run:  python art_src/audio/make_talk_blip.py  (needs numpy and ffmpeg)."""
import subprocess, wave
import numpy as np

RATE = 44100
length = 0.05
t = np.arange(int(RATE * length)) / RATE
phase = 2 * np.pi * 240 * t
tone = np.sin(phase) + 0.3 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
envelope = np.minimum(t / 0.004, 1.0) * np.exp(-np.clip(t - 0.004, 0, None) / 0.018)
fade = np.minimum(1.0, (length - t) / 0.008)              # no click at the very end
sound = tone * envelope * fade
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
