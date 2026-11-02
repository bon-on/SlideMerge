#!/usr/bin/env python3
"""Generates the game sound effects and the background music loop.

Effects are small mono 16-bit 44.1 kHz WAV files. The music loop
(music_loop.wav) is mono 16-bit 16 kHz so a 23 s loop stays under 1 MB; it is
rendered on a circular timeline (note tails wrap around the end, filters and
echoes run over two tiled periods with the second kept), so it loops without
a click.

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


def bubble(freq, dur):
    """Water-drop blip: a sine that glides up quickly and fades."""
    return tone(freq, dur, freq * 1.9, decay=5.0)


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
        # Combo: three quick rising bubbly blips.
        "combo": seq(
            bubble(520, 0.06),
            bubble(700, 0.06),
            mix(bubble(940, 0.16), tone(1880, 0.16, decay=6.0)),
            gap=0.012,
        ),
        # New creature discovered: sparkly bell arpeggio with a shimmer.
        "discover": mix(
            seq(
                tone(784, 0.07, decay=3.0, harmonic=0.35),
                tone(988, 0.07, decay=3.0, harmonic=0.35),
                tone(1175, 0.07, decay=3.0, harmonic=0.35),
                tone(1568, 0.2, decay=4.5, harmonic=0.4),
            ),
            [0.0] * int(0.1 * RATE)
            + [0.25 * v for v in tone(3136, 0.3, decay=7.0)],
        ),
        # Mission complete: warm two-note chime.
        "mission": seq(
            tone(587, 0.09, decay=2.5, harmonic=0.25, shape="triangle"),
            tone(880, 0.24, decay=3.5, harmonic=0.25, shape="triangle"),
        ),
        # Level up: cheerful rising fanfare.
        "level_up": seq(
            tone(523, 0.07, decay=2.0, harmonic=0.3, shape="triangle"),
            tone(659, 0.07, decay=2.0, harmonic=0.3, shape="triangle"),
            tone(784, 0.07, decay=2.0, harmonic=0.3, shape="triangle"),
            mix(
                tone(1047, 0.2, decay=3.0, harmonic=0.3, shape="triangle"),
                tone(1319, 0.2, decay=3.5, harmonic=0.2),
            ),
        ),
        # A slow descending triad when no moves are left.
        "game_over": seq(
            tone(392.0, 0.12, decay=2.5, shape="triangle"),
            tone(311.13, 0.12, decay=2.5, shape="triangle"),
            tone(233.08, 0.2, decay=3.5, shape="triangle"),
        ),
    }


# (SOUNDS_END)


# ---------------------------------------------------------------------------
# Music: calm, bubbly underwater loop (16 kHz)

MUSIC_RATE = 16000
MUSIC_PEAK = 0.251  # about -12 dBFS
TAU = 2.0 * math.pi
BPM = 84
BARS = 8
EIGHTH = 60.0 / BPM / 2.0


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def lowpass(x, cutoff, rate):
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    return [v - l for v, l in zip(x, lowpass(x, cutoff, rate))]


def feedback_delay(x, delay, feedback, damp_hz, rate):
    """Echo tail only: y[n] = feedback * lowpass(wet[n - delay])."""
    a = 1.0 - math.exp(-TAU * damp_hz / rate)
    wet = [0.0] * len(x)
    out = [0.0] * len(x)
    lp = 0.0
    for i in range(len(x)):
        if i >= delay:
            lp += a * (wet[i - delay] - lp)
            out[i] = feedback * lp
        wet[i] = x[i] + out[i]
    return out


def circular(effect, x, *args):
    """Run a stateful effect over two tiled periods and keep the second."""
    n = len(x)
    return effect(x + x, *args)[n:]


def mix_into(buf, sig, start, gain=1.0):
    n = len(buf)
    for i, v in enumerate(sig):
        buf[(start + i) % n] += gain * v


def marimba(freq, dur, rate):
    """Soft mallet: fundamental plus a quickly fading 4th partial."""
    n = int(dur * rate)
    out = []
    w1 = TAU * freq / rate
    w4 = TAU * freq * 3.9 / rate
    a = int(0.004 * rate)
    for i in range(n):
        t = i / rate
        v = math.sin(w1 * i) * math.exp(-4.2 * t)
        v += 0.35 * math.sin(w4 * i) * math.exp(-18.0 * t)
        if i < a:
            v *= i / a
        out.append(v)
    return out


def pad_voice(notes, dur, rate):
    n = int(dur * rate)
    out = [0.0] * n
    for note in notes:
        f = midi_hz(note)
        for detune, amp in ((0.997, 0.5), (1.003, 0.5)):
            w = TAU * f * detune / rate
            w2 = 2 * w
            for i in range(n):
                out[i] += amp * (math.sin(w * i) + 0.2 * math.sin(w2 * i))
    att = int(0.8 * rate)
    rel = int(1.2 * rate)
    for i in range(n):
        g = 1.0
        if i < att:
            g = math.sin(0.5 * math.pi * i / att) ** 2
        if i > n - rel:
            g = min(g, math.sin(0.5 * math.pi * (n - i) / rel) ** 2)
        out[i] *= g
    return out


def blip(freq, rate):
    """Rising bubble pop for the background."""
    n = int(0.09 * rate)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += TAU * freq * (1.0 + 1.2 * t) / rate
        out.append(math.sin(phase) * math.sin(math.pi * t) * math.exp(-2.0 * t))
    return out


# F major, one chord per bar: Fmaj7 Dm7 Bbmaj7 C | Fmaj7 Am7 Bbmaj7 Csus-C
MUSIC_CHORDS = [
    ((53, 57, 60, 64), 41),
    ((50, 53, 57, 60), 38),
    ((46, 50, 53, 57), 34),
    ((48, 52, 55, 58), 36),
    ((53, 57, 60, 64), 41),
    ((45, 48, 52, 55), 45),
    ((46, 50, 53, 57), 34),
    ((48, 53, 55, 60), 36),
]

# Melody in F major pentatonic (F G A C D): (eighth offset, midi, eighths).
MUSIC_MELODY = [
    [(0, 72, 2), (2, 69, 1), (3, 72, 1), (4, 74, 3)],
    [(0, 72, 2), (2, 69, 2), (4, 65, 2), (6, 67, 2)],
    [(0, 69, 3), (3, 70, 1), (4, 72, 2), (6, 74, 2)],
    [(0, 72, 4), (4, 67, 2), (6, 69, 2)],
    [(0, 77, 2), (2, 76, 1), (3, 74, 1), (4, 72, 3)],
    [(0, 69, 2), (2, 72, 2), (4, 76, 2), (6, 74, 2)],
    [(0, 74, 2), (2, 72, 1), (3, 70, 1), (4, 69, 2), (6, 67, 2)],
    [(0, 65, 3), (3, 67, 1), (4, 69, 4)],
]


def music_loop():
    rate = MUSIC_RATE
    bar = EIGHTH * 8
    n = int(round(bar * BARS * rate))
    rng = random.Random(84)
    pad = [0.0] * n
    bass = [0.0] * n
    mel = [0.0] * n
    bubbles = [0.0] * n

    for b, (notes, root) in enumerate(MUSIC_CHORDS):
        start = int(b * bar * rate)
        mix_into(pad, pad_voice(notes, bar + 1.2, rate), start, 0.07)
        low = marimba(midi_hz(root), 1.4, rate)
        mix_into(bass, low, start, 0.5)
        mix_into(bass, low[: int(0.9 * rate)], start + int(5 * EIGHTH * rate),
                 0.3)
        # Soft arpeggio on the off-beats.
        for k, e in enumerate((1, 3, 5, 7)):
            note = notes[k % len(notes)] + 12
            mix_into(mel, marimba(midi_hz(note), 0.6, rate),
                     start + int(e * EIGHTH * rate), 0.1)
    for b, phrase in enumerate(MUSIC_MELODY):
        for off, midi, length in phrase:
            dur = min(1.8, 0.5 + 0.25 * length)
            mix_into(mel, marimba(midi_hz(midi), dur, rate),
                     int((b * bar + off * EIGHTH) * rate),
                     0.32 if off == 0 else 0.26)
    # Sparse bubble pops, deterministic placement.
    for _ in range(BARS * 3):
        pos = int(rng.random() * n)
        freq = 500 + rng.random() * 600
        mix_into(bubbles, blip(freq, rate), pos, 0.05 + 0.04 * rng.random())

    pad = circular(lowpass, pad, 1200, rate)
    bass = circular(lowpass, bass, 500, rate)
    mel = circular(lowpass, mel, 3000, rate)
    echo = circular(feedback_delay, mel, int(round(EIGHTH * 3 * rate)), 0.4,
                    1800, rate)
    out = [p + b + m + 0.5 * e + u
           for p, b, m, e, u in zip(pad, bass, mel, echo, bubbles)]
    return circular(highpass, out, 35, rate)


def write_music(path, samples):
    peak = max(abs(v) for v in samples) or 1.0
    scale = MUSIC_PEAK / peak
    frames = b"".join(
        struct.pack("<h", int(round(max(-1.0, min(1.0, v * scale)) * 32767)))
        for v in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(MUSIC_RATE)
        w.writeframes(frames)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, samples in build().items():
        write(os.path.join(out_dir, name + ".wav"), samples)
    write_music(os.path.join(out_dir, "music_loop.wav"), music_loop())


if __name__ == "__main__":
    main()
