#!/usr/bin/env python3
"""Generates the game sound effects as small mono 16-bit 44.1 kHz WAV files.

Python 3 standard library only. The output is deterministic (fixed random
seed), so running the script twice yields byte-identical files.

Usage: python3 tool/generate_sounds.py
Writes assets/audio/<name>.wav relative to the repository root.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 10 ** (-3 / 20)  # about -3 dBFS


def envelope(n, attack=0.006, release=0.03):
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    out = []
    for i in range(n):
        gain = 1.0
        if i < a:
            gain = i / a
        if i > n - r:
            gain = min(gain, (n - i) / r)
        out.append(gain)
    return out


def tone(freq, dur, end_freq=None, shape="sine", decay=4.0, harmonic=0.0):
    """One note with optional pitch glide, exponential decay and 2nd harmonic."""
    n = int(dur * RATE)
    env = envelope(n)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq if end_freq is None else freq + (end_freq - freq) * t
        phase += 2 * math.pi * f / RATE
        if shape == "triangle":
            v = (2 / math.pi) * math.asin(math.sin(phase))
        else:
            v = math.sin(phase)
        if harmonic:
            v += harmonic * math.sin(2 * phase)
        samples.append(v * env[i] * math.exp(-decay * t))
    return samples


def noise(dur, decay=6.0, seed=1, smooth=0.6):
    rng = random.Random(seed)
    n = int(dur * RATE)
    env = envelope(n, attack=0.004, release=0.04)
    out = []
    last = 0.0
    for i in range(n):
        last = smooth * last + (1 - smooth) * rng.uniform(-1, 1)
        out.append(last * env[i] * math.exp(-decay * i / n))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.extend(p)
        out.extend([0.0] * int(gap * RATE))
    return out


def write(path, samples):
    peak = max(abs(v) for v in samples) or 1.0
    scale = PEAK / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767))
        for v in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


# ---------------------------------------------------------------------------
# Game specific sounds (SOUNDS_BEGIN)


def build():
    return {
        # A short airy swish: filtered noise with a soft low tone.
        "slide": mix(
            [0.35 * v for v in noise(0.1, decay=3.0, seed=3, smooth=0.85)],
            tone(300, 0.1, 380, decay=4.0),
        ),
        # A bright two-note chime when tiles merge.
        "merge": seq(
            tone(660, 0.07, decay=3.0, harmonic=0.3),
            tone(990, 0.14, decay=4.0, harmonic=0.3),
        ),
        # A falling glide for undo.
        "undo": tone(540, 0.13, 330, decay=3.5, harmonic=0.15),
        # A slow descending triad when no moves are left.
        "game_over": seq(
            tone(392.0, 0.12, decay=2.5, shape="triangle"),
            tone(311.13, 0.12, decay=2.5, shape="triangle"),
            tone(233.08, 0.2, decay=3.5, shape="triangle"),
        ),
    }


# (SOUNDS_END)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, samples in build().items():
        write(os.path.join(out_dir, name + ".wav"), samples)


if __name__ == "__main__":
    main()
