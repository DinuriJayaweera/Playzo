"""Synthesises the game's original music loop and sound effects.

Run from the repo root:  python3 tool/generate_audio.py
Needs numpy and ffmpeg (with libmp3lame). Writes assets/audio/*.mp3.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def note_freq(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
             "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def envelope(n, attack=0.01, release=0.08):
    env = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, min(n - a, int(release * SR)))
    env[:a] = np.linspace(0, 1, a)
    env[-r:] = np.linspace(1, 0, r)
    return env


def tone(freq, dur, kind="square", vol=0.3, attack=0.01, release=0.08):
    n = int(dur * SR)
    t = np.arange(n) / SR
    phase = (freq * t) % 1.0
    if kind == "square":
        # A softened pulse wave: bright but not harsh.
        w = np.tanh(np.sin(2 * np.pi * freq * t) * 3) * 0.8
    elif kind == "triangle":
        w = 4 * np.abs(phase - 0.5) - 1
    elif kind == "saw":
        w = 2 * phase - 1
    else:
        w = np.sin(2 * np.pi * freq * t)
    return w * envelope(n, attack, release) * vol


def mix_into(buf, sig, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def write_mp3(name, samples, bitrate="96k"):
    samples = samples / max(1e-9, np.max(np.abs(samples))) * 0.85
    pcm = (samples * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp,
                    "-codec:a", "libmp3lame", "-b:a", bitrate, out], check=True)
    os.remove(tmp)
    print("wrote", out)


def music():
    bpm = 112
    beat = 60 / bpm
    chords = [
        ("C3", ["C4", "E4", "G4"]), ("A2", ["A3", "C4", "E4"]),
        ("F2", ["F3", "A3", "C4"]), ("G2", ["G3", "B3", "D4"]),
    ] * 2
    melody = [
        "E5", "G5", "C6", "G5", "E5", "D5", "C5", "D5",
        "E5", "C5", "A4", "C5", "E5", "D5", "C5", "A4",
        "F5", "A5", "C6", "A5", "G5", "F5", "E5", "F5",
        "G5", "D5", "B4", "D5", "G5", "A5", "B5", "G5",
        "E5", "G5", "C6", "D6", "E6", "D6", "C6", "G5",
        "A5", "E5", "C5", "E5", "A5", "G5", "E5", "C5",
        "F5", "G5", "A5", "C6", "A5", "G5", "F5", "A5",
        "G5", "F5", "E5", "D5", "B4", "D5", "G5", None,
    ]
    total = len(chords) * 4 * beat
    buf = np.zeros(int(total * SR) + SR)
    for bar, (bass, triad) in enumerate(chords):
        t0 = bar * 4 * beat
        for b in range(4):
            mix_into(buf, tone(note_freq(bass), beat * 0.9, "triangle", 0.45),
                     t0 + b * beat)
        for step in range(8):
            n = triad[[0, 1, 2, 1][step % 4]]
            mix_into(buf, tone(note_freq(n) * 2, beat * 0.45, "sine", 0.12,
                               release=0.15), t0 + step * beat / 2)
        # A light hi-hat tick on the off-beats.
        for b in range(4):
            n = int(0.03 * SR)
            hat = np.random.default_rng(bar * 4 + b).uniform(-1, 1, n)
            mix_into(buf, hat * envelope(n, 0.001, 0.025) * 0.06,
                     t0 + b * beat + beat / 2)
    for i, n in enumerate(melody):
        if n:
            mix_into(buf, tone(note_freq(n), beat * 0.48, "square", 0.22,
                               release=0.12), i * beat / 2)
    write_mp3("music.mp3", buf[: int(total * SR)], "112k")


def sweep(f0, f1, dur, kind="sine", vol=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    freqs = np.linspace(f0, f1, n)
    phase = np.cumsum(freqs) / SR
    if kind == "square":
        w = np.tanh(np.sin(2 * np.pi * phase) * 3)
    else:
        w = np.sin(2 * np.pi * phase)
    return w * envelope(n, 0.005, dur * 0.6) * vol


def sfx():
    write_mp3("whoosh.mp3", sweep(380, 1400, 0.22))
    write_mp3("tap.mp3", tone(note_freq("A5"), 0.07, "sine", 0.5, 0.002, 0.05))
    buzz = sweep(220, 110, 0.32, "square", 0.5)
    write_mp3("wrong.mp3", buzz)

    def jingle(notes, step, kind="square"):
        buf = np.zeros(int((len(notes) * step + 0.6) * SR))
        for i, n in enumerate(notes):
            mix_into(buf, tone(note_freq(n), step * 1.8, kind, 0.35, 0.005, 0.2),
                     i * step)
            mix_into(buf, tone(note_freq(n) / 2, step * 1.8, "triangle", 0.25),
                     i * step)
        return buf

    write_mp3("win.mp3", jingle(["C5", "E5", "G5", "C6", "E6", "G6"], 0.09))
    write_mp3("lose.mp3", jingle(["G4", "F#4", "F4", "E4"], 0.18, "triangle"))
    write_mp3("hint.mp3", jingle(["E6", "B6"], 0.06, "sine"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    music()
    sfx()
