#!/usr/bin/env python3
"""Prepare sourced audio drops for the game (docs/AUDIO.md §5).

Reads a raw file from rallyrivals/assets/audio/_incoming/<id>.<any>, converts it to the format the
manifest wants for that id, and writes it to the right folder. Format, channel count and level
target all follow from what the sound IS — you only ever pass the id and, for loops, how long.

    python3 prep_audio.py wind_light 10        # loop: 10 s body
    python3 prep_audio.py impact_heavy_1       # one-shot: whole file
    python3 prep_audio.py engine_mid 2 --from 12.5   # loop starting 12.5 s in

Uses afconvert (ships with macOS — CoreAudio's resampler) so there is nothing to install.
After running, set the Godot import loop mode and point the .tres at the new stream; the script
prints exactly what still needs doing.
"""
import argparse
import array
import math
import os
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(ROOT, "rallyrivals", "assets", "audio")
INCOMING = os.path.join(AUDIO, "_incoming")

BEDS = {"festival_crowd", "wind_light", "wind_low", "rain", "rain_heavy", "snow_wind"}
LOOPS = {"engine_low", "engine_mid", "engine_high", "roll_asphalt", "roll_gravel", "roll_dirt",
         "roll_sand", "roll_snow", "roll_ice", "skid_asphalt", "skid_loose", "scrape",
         "slipstream", "nitro_loop"}
# One-shots that get played positionally (Sfx.play_at) must be mono, or their baked-in stereo
# image fights the engine's spatialisation.
POSITIONAL = {"impact_light", "impact_heavy", "debris_cubes", "checkpoint", "engine_start",
              "engine_off", "nitro_fire"}

RATE = 44100


def classify(sound_id):
    """-> (dest_dir, channels, peak_dbfs, is_loop)"""
    base = sound_id.rstrip("0123456789_") or sound_id
    if sound_id in BEDS:
        return os.path.join(AUDIO, "ambient"), 2, -6.0, True
    if sound_id in LOOPS:
        return os.path.join(AUDIO, "loops"), 1, -6.0, True
    if base in POSITIONAL or sound_id in POSITIONAL:
        return os.path.join(AUDIO, "sfx"), 1, -3.0, False
    return os.path.join(AUDIO, "sfx"), 2, -3.0, False


def find_source(sound_id):
    for f in sorted(os.listdir(INCOMING)):
        if os.path.splitext(f)[0] == sound_id and not f.endswith((".md", ".txt")):
            return os.path.join(INCOMING, f)
    sys.exit(f"no source for '{sound_id}' in {INCOMING}")


def convert(src, channels):
    tmp = os.path.join(tempfile.mkdtemp(), "conv.wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", str(channels),
                    "--src-quality", "127", src, tmp], check=True)
    return tmp


def read_wav(path):
    w = wave.open(path)
    ch, rate, n = w.getnchannels(), w.getframerate(), w.getnframes()
    s = array.array("h")
    s.frombytes(w.readframes(n))
    w.close()
    return s, ch, rate


def write_wav(path, samples, ch):
    o = wave.open(path, "wb")
    o.setnchannels(ch)
    o.setsampwidth(2)
    o.setframerate(RATE)
    o.writeframes(samples.tobytes())
    o.close()


def make_loop(s, ch, n, f):
    """Body is [0,n); the head fades in from the material FOLLOWING it, so out[0] is the sample
    that naturally succeeds out[n-1] and the wrap is two consecutive samples rather than a step.
    Equal-power (sqrt) weights hold energy flat — a linear crossfade dips ~3 dB and pumps once
    per loop."""
    out = s[: n * ch]
    for k in range(f):
        t = k / f
        a, b = math.sqrt(1.0 - t), math.sqrt(t)
        for c in range(ch):
            out[k * ch + c] = int(s[(n + k) * ch + c] * a + s[k * ch + c] * b)
    return out


def edge_fade(s, ch, ms=5):
    """One-shots: a few ms in/out so a non-zero first or last sample can't click."""
    f = int(RATE * ms / 1000)
    total = len(s) // ch
    f = min(f, total // 2)
    for k in range(f):
        g = k / f
        for c in range(ch):
            s[k * ch + c] = int(s[k * ch + c] * g)
            s[(total - 1 - k) * ch + c] = int(s[(total - 1 - k) * ch + c] * g)
    return s


def normalize(s, target_db):
    peak = max(abs(v) for v in s) or 1
    gain = (10 ** (target_db / 20.0) * 32767.0) / peak
    for i in range(len(s)):
        s[i] = max(-32768, min(32767, int(s[i] * gain)))
    return s, 20 * math.log10(gain)


def rms_db(s):
    step = max(1, len(s) // 200000)
    vals = [s[i] / 32768.0 for i in range(0, len(s), step)]
    return 20 * math.log10(math.sqrt(sum(v * v for v in vals) / len(vals)) or 1e-9)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("seconds", nargs="?", type=float, help="loop body length (loops/beds only)")
    ap.add_argument("--from", dest="start", type=float, default=0.0, help="offset into the source")
    ap.add_argument("--fade", type=float, default=1.0, help="loop crossfade seconds")
    a = ap.parse_args()

    dest_dir, channels, peak_db, is_loop = classify(a.id)
    src = find_source(a.id)
    s, ch, _ = read_wav(convert(src, channels))
    total = len(s) // ch

    if a.start:
        s = s[int(a.start * RATE) * ch:]
        total = len(s) // ch

    if is_loop:
        if not a.seconds:
            sys.exit(f"'{a.id}' is a loop — pass a length, e.g. `{a.id} 10`")
        n, f = int(a.seconds * RATE), int(a.fade * RATE)
        if total < n + f:
            sys.exit(f"need {(n + f) / RATE:.1f}s from the offset, have {total / RATE:.1f}s")
        out = make_loop(s, ch, n, f)
    else:
        out = edge_fade(s[: int(a.seconds * RATE) * ch] if a.seconds else s, ch)

    before = rms_db(out)
    out, gain = normalize(out, peak_db)
    dest = os.path.join(dest_dir, a.id + ".wav")
    write_wav(dest, out, ch)

    frames = len(out) // ch
    print(f"{a.id}: {frames / RATE:.2f}s  {'stereo' if ch == 2 else 'mono'}  {RATE}Hz")
    print(f"  {os.path.basename(src)} -> {os.path.relpath(dest, ROOT)}")
    print(f"  gain {gain:+.1f} dB -> peak {peak_db:.1f} dBFS, RMS {rms_db(out):.1f} dBFS")
    if is_loop:
        seam = abs(out[0] - out[(frames - 1) * ch])
        deltas = [abs(out[i * ch] - out[(i - 1) * ch]) for i in range(1, min(frames, 40000))]
        mean = sum(deltas) / len(deltas)
        ok = seam <= max(mean * 4, 1500)
        print(f"  seam step {seam} vs mean {mean:.0f}  {'OK' if ok else 'SUSPECT — audition it'}")
        print(f"  NEXT: set edit/loop_mode=2 in {a.id}.wav.import, then point the .tres at the .wav")
    else:
        print(f"  NEXT: point {a.id}.tres at the .wav")


if __name__ == "__main__":
    main()
