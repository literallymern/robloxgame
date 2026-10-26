# Kagundi weather audio

Original procedural audio generated for Ro-Nation with
[`tools/generate-weather-audio.py`](../../tools/generate-weather-audio.py).
No recordings, external samples or downloaded audio were used. The generated
audio is dedicated to the public domain under **CC0 1.0**; attribution is optional.

| File | Format | Use |
| --- | --- | --- |
| `kagundi-rain-loop.wav` | 10 s, mono, 22,050 Hz, 16-bit PCM | Seamless rain bed; runtime loops it |
| `kagundi-thunder.wav` | 6 s, mono, 22,050 Hz, 16-bit PCM | One distant thunder crack and rolling decay |

To enable sounds, upload both WAV files as audio through the Roblox Creator
Dashboard under the experience's owning group. Grant this experience permission
to use each uploaded audio asset. Then enter the returned IDs in
`src/shared/Config/Environment.luau`:

```lua
Effects = {
    -- Keep the other existing effect settings.
    Audio = {
        Rain = "rbxassetid://YOUR_UPLOADED_RAIN_ID",
        Thunder = "rbxassetid://YOUR_UPLOADED_THUNDER_ID",
    },
},
```

The checked-in IDs are empty. The weather system remains silent until these
project-owned assets have been uploaded and permitted. No upload or Roblox
playback validation has been performed in the cloud environment.

Regenerate with Python 3 and NumPy:

```sh
python3 tools/generate-weather-audio.py
```

The script checks WAV metadata, clipping and the rain loop boundary, and prints
the file hashes. It uses fixed random seeds for repeatable output. Audition the
uploaded sounds in Studio and adjust the runtime audio levels for your mix.
