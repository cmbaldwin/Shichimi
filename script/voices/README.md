# Voice and SFX generation

Clips are committed in `public/audio/`; regenerate only when phrases, exercises or voices change.

```bash
brew install espeak-ng ffmpeg
uv venv -p 3.12 /tmp/tts && VIRTUAL_ENV=/tmp/tts uv pip install kokoro soundfile pyyaml pip
export ESPEAK_DATA_PATH=/opt/homebrew/share/espeak-ng-data PHONEMIZER_ESPEAK_LIBRARY=/opt/homebrew/lib/libespeak-ng.dylib VIRTUAL_ENV=/tmp/tts
/tmp/tts/bin/python script/voices/generate.py          # new phrases/exercises only; --force re-renders all
script/voices/sfx.sh <unzipped kenney_interfaceSounds dir>
```

- Cue keys in `CUES` must match the `say([...])` keys in `player_controller.js`; exercise clips are named by slug.
- Python 3.12 (Kokoro/torch wheels). Kokoro's espeak loader needs the two env vars above on macOS.
- Sources and licences: `public/audio/CREDITS.md`.
