#!/usr/bin/env python3
"""Render Shichimi's spoken cues with Kokoro-82M (Apache-2.0) into public/audio/voice/<voice>/<key>.m4a.

Usage (from repo root, inside a venv with `pip install kokoro soundfile pyyaml`, plus espeak-ng and ffmpeg):
    python script/voices/generate.py            # all voices, all phrases
    python script/voices/generate.py --force    # re-render existing files
"""
import argparse
import pathlib
import subprocess
import tempfile
import numpy as np
import soundfile as sf
import yaml
from kokoro import KPipeline

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "public/audio/voice"
VOICES = {"female": "af_heart", "male": "am_michael"}  # VOICES.md grades: A / C+ (best US pair)

# Keys must match say() calls in app/javascript/controllers/player_controller.js.
CUES = {"get_ready": "Get ready.", "rest": "Rest.", "next": "Next up:", "last_one": "Last one!",
        "switch_sides": "Switch sides.", "halfway": "Halfway there.", "done": "Done. Great work!"}


def phrases():
    exercises = yaml.safe_load((ROOT / "config/catalog/exercises.yml").read_text())
    return {**CUES, **{e["slug"]: e["name"] for e in exercises}}


def encode(wav, dest):
    # trim leading/trailing silence, normalize to -16 LUFS, mono AAC 48 kbps
    trim = "silenceremove=start_periods=1:start_threshold=-50dB,areverse," \
           "silenceremove=start_periods=1:start_threshold=-50dB,areverse"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                    "-af", f"{trim},loudnorm=I=-16:TP=-1.5:LRA=11",
                    "-ar", "24000", "-ac", "1", "-c:a", "aac", "-b:a", "48k", str(dest)], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    pipe = KPipeline(lang_code="a")
    items = phrases()
    for name, voice in VOICES.items():
        (OUT / name).mkdir(parents=True, exist_ok=True)
        for key, text in items.items():
            dest = OUT / name / f"{key}.m4a"
            if dest.exists() and not args.force:
                continue
            audio = [a.numpy() for _, _, a in pipe(text, voice=voice) if a is not None]
            with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
                sf.write(tmp.name, np.concatenate(audio), 24000)
                encode(tmp.name, dest)
            print(dest.relative_to(ROOT))


if __name__ == "__main__":
    main()
