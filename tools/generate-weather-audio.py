#!/usr/bin/env python3
"""Generate original, deterministic Kagundi weather audio. Requires numpy.

No recordings, downloaded samples, asset IDs, or third-party audio are used.
Run from any directory: python3 tools/generate-weather-audio.py
"""

from pathlib import Path
import hashlib
import json
import wave

import numpy as np


SAMPLE_RATE = 22050
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def noise(rng, length, response):
    frequencies = np.fft.rfftfreq(length, 1 / SAMPLE_RATE)
    spectrum = np.fft.rfft(rng.standard_normal(length))
    spectrum *= response(frequencies)
    spectrum[0] = 0
    signal = np.fft.irfft(spectrum, n=length)
    return signal / np.std(signal)


def rain():
    rng = np.random.default_rng(681982)
    length = 10 * SAMPLE_RATE
    t = np.arange(length) / SAMPLE_RATE
    signal = noise(
        rng,
        length,
        lambda f: (f / (f + 180)) ** 1.5 / (1 + (f / 6300) ** 3),
    )
    # Smooth periodic movement in the bed; no obvious individual drop rhythm.
    signal *= 0.12 * (
        0.94 + 0.035 * np.cos(2 * np.pi * t / 10) + 0.025 * np.sin(6 * np.pi * t / 10)
    )
    for _ in range(90):
        start = int(rng.integers(length))
        duration = int(rng.uniform(0.012, 0.045) * SAMPLE_RATE)
        dt = np.arange(duration) / SAMPLE_RATE
        carrier = rng.standard_normal(duration)
        # Soft, brief splashes, not tonal drops. Wrap every splash across the loop.
        envelope = (1 - np.exp(-dt / 0.0015)) * np.exp(-dt / rng.uniform(0.003, 0.009))
        splash = carrier * envelope * rng.uniform(0.035, 0.12)
        signal[(start + np.arange(duration)) % length] += splash
    signal -= np.mean(signal)
    signal *= 0.62 / np.max(np.abs(signal))
    # Move the loop boundary to a quiet, locally smooth crossing. This retains
    # the original sound (no faded gap on every repetition).
    step = np.abs(signal - np.roll(signal, 1))
    curvature = np.abs(signal - 2 * np.roll(signal, 1) + np.roll(signal, 2))
    seam = int(np.argmin(step + curvature + 0.1 * np.abs(signal)))
    signal = np.roll(signal, -seam)
    return signal


def thunder():
    rng = np.random.default_rng(1251982)
    length = 6 * SAMPLE_RATE
    t = np.arange(length) / SAMPLE_RATE
    rumble = noise(
        rng,
        length,
        lambda f: (f / (f + 27)) ** 3 / (1 + (f / 165) ** 4),
    )
    envelope = (1 - np.exp(-t / 0.07)) * np.exp(-t / 1.6)
    envelope += 0.26 * np.exp(-((t - 0.9) / 0.31) ** 2)
    envelope += 0.13 * np.exp(-((t - 1.8) / 0.46) ** 2)
    signal = rumble * envelope
    crack = noise(
        rng,
        length,
        lambda f: (f / (f + 100)) ** 2 / (1 + (f / 2500) ** 4),
    )
    signal += 0.22 * crack * (1 - np.exp(-t / 0.012)) * np.exp(-t / 0.13)
    # Both ends settle to zero; distant rumble does not cut off abruptly.
    signal *= np.clip(t / 0.015, 0, 1) * np.clip((6 - t) / 0.6, 0, 1)
    signal -= np.mean(signal)
    signal *= np.minimum(1, t / 0.015) * np.minimum(1, (6 - t) / 0.02)
    signal *= 0.72 / np.max(np.abs(signal))
    signal[0] = signal[-1] = 0
    return signal


def write(name, signal, loop=False):
    path = OUTPUT / name
    pcm = np.rint(signal * 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SAMPLE_RATE)
        out.writeframes(pcm.tobytes())
    with wave.open(str(path), "rb") as source:
        assert source.getnchannels() == 1
        assert source.getsampwidth() == 2
        assert source.getframerate() == SAMPLE_RATE
        assert source.getnframes() == len(pcm)
    peak = int(np.max(np.abs(pcm.astype(np.int32))))
    assert 0 < peak < 32767, "clipping or empty audio"
    seam_step = abs(int(pcm[0]) - int(pcm[-1]))
    if loop:
        assert seam_step < 100, f"loop seam too large: {seam_step}"
    return {
        "file": name,
        "seconds": len(pcm) / SAMPLE_RATE,
        "channels": 1,
        "sample_rate": SAMPLE_RATE,
        "peak_pcm": peak,
        "seam_step_pcm": seam_step,
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    results = [write("kagundi-rain-loop.wav", rain(), loop=True), write("kagundi-thunder.wav", thunder())]
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
