# BAKE SOUNDS: makes the game's sound files (Assets/SFX/*.ogg) from the HTML prototype's sound code.
#
# It opens bake.html (next to this file) in a headless Chromium (Playwright), renders each sound there with the
# prototype's own Web Audio code, then here:
#   - loops: the extra second at the end is cross-faded onto the start, so the loop has no seam;
#   - all the sounds get the same gain, so the loudest one peaks just under full scale and they keep the
#     prototype's balance between them (the sea quiet, the anchor louder);
#   - each is saved as .ogg (Vorbis, via ffmpeg) in Assets/SFX/.
# Run it from the project folder:  python art_src/audio/bake.py
# (needs: pip install playwright numpy scipy, a Chromium for Playwright, and ffmpeg; CHROMIUM=path picks a Chromium)

import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "Assets", "SFX")
# (sea, rush and wind are in bake.html too, but the game doesn't use them any more: Enrico)
NAMES = ["anchor_down", "anchor_up", "wheel_rub", "wheel_thunk"]
PEAK = 0.89   # the loudest sound peaks here (-1 dB), the others in proportion


def render_all():
    sounds = {}
    with sync_playwright() as p:
        # CHROMIUM (optional): a Chromium to use instead of Playwright's own download
        browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM") or None)
        page = browser.new_page()
        page.goto("file://" + os.path.join(HERE, "bake.html"))
        for name in NAMES:
            data = page.evaluate("name => bake(name)", name)
            audio = np.array(data["chans"], dtype=np.float32)   # channels x samples
            rate = data["rate"]
            if data["loop"]:
                audio = make_loop(audio, int(data["loopSeconds"] * rate))
            sounds[name] = (audio, rate)
            print(name, audio.shape, rate)
        browser.close()
    return sounds


## The loop: keep its first `length` samples, and blend the part rendered past the end onto the start
## (fading the start in as the extra fades out), so the end runs straight into the start.
def make_loop(audio, length):
    extra = audio.shape[1] - length
    loop = audio[:, :length].copy()
    fade = np.linspace(0.0, 1.0, extra, dtype=np.float32)
    loop[:, :extra] = loop[:, :extra] * fade + audio[:, length:length + extra] * (1.0 - fade)
    return loop


def save_all(sounds):
    loudest = max(np.abs(audio).max() for audio, _ in sounds.values())
    gain = PEAK / loudest
    print("gain for all:", round(float(gain), 2))
    os.makedirs(OUT, exist_ok=True)
    for name, (audio, rate) in sounds.items():
        wav = os.path.join(tempfile.gettempdir(), name + ".wav")
        wavfile.write(wav, rate, (audio * gain).T)
        ogg = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
        print("saved", os.path.normpath(ogg), os.path.getsize(ogg) // 1024, "KB")


if __name__ == "__main__":
    save_all(render_all())
