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


def seam_ratio(s, ch, frames):
    """How the wrap-around step compares to this signal's own typical step. A fixed threshold
    can't work: white-ish noise legitimately jumps far between adjacent samples while a tonal
    engine loop barely moves."""
    seam = abs(s[0] - s[(frames - 1) * ch])
    deltas = [abs(s[i * ch] - s[(i - 1) * ch]) for i in range(1, min(frames, 40000))]
    return seam / max(sum(deltas) / len(deltas), 1.0)


def highpass(s, ch, hz, poles=2):
    """Strip engine rumble from a tyre-roll recording. A rolling car always has an engine, so
    library roll loops carry its fundamental and low harmonics — often most of their energy. Tyre
    grit lives above ~500 Hz, and the game's own engine loop supplies the low end anyway, so
    cutting it here removes the bleed and prevents two engines fighting."""
    a = math.exp(-2.0 * math.pi * hz / RATE)
    n = len(s) // ch
    for c in range(ch):
        v = [s[i * ch + c] / 32768.0 for i in range(n)]
        for _ in range(poles):
            px = py = 0.0
            for i in range(n):
                x = v[i]
                py = a * (py + x - px)
                px = x
                v[i] = py
        for i in range(n):
            s[i * ch + c] = max(-32768, min(32767, int(v[i] * 32768.0)))
    return s


def flatten(s, ch, win_s=0.3, max_boost_db=12.0):
    """Hold the level constant across a loop. Recordings of a car passing or slowing drift in
    level, and a loop whose end is quieter than its start pulses once per cycle. Gain is clamped
    so quiet passages don't drag the noise floor up with them."""
    n = len(s) // ch
    win = max(int(RATE * win_s), 1024)
    hop = win // 2
    env = []
    for a in range(0, max(n - win, 1), hop):
        acc = sum((s[(a + k) * ch] / 32768.0) ** 2 for k in range(0, win, 8))
        env.append(math.sqrt(acc / (win // 8)) + 1e-9)
    if len(env) < 2:
        return s
    target = sorted(env)[len(env) // 2]
    lim = 10 ** (max_boost_db / 20.0)
    for i in range(n):
        pos = min(i / hop, len(env) - 1.001)
        k = int(pos)
        e = env[k] + (env[k + 1] - env[k]) * (pos - k)
        g = max(1.0 / lim, min(lim, target / e))
        for c in range(ch):
            s[i * ch + c] = max(-32768, min(32767, int(s[i * ch + c] * g)))
    return s


def trim_silence(s, ch, thresh=0.02, tail_ms=25):
    """Strip dead air from a one-shot, keeping a short tail so a decay isn't chopped. Library
    one-shots are often padded — countdown_beep arrived with 0.74 s of trailing silence."""
    n = len(s) // ch
    pk = max(abs(v) for v in s) or 1
    t = pk * thresh
    lead = 0
    while lead < n and all(abs(s[lead * ch + c]) < t for c in range(ch)):
        lead += 1
    trail = n - 1
    while trail > lead and all(abs(s[trail * ch + c]) < t for c in range(ch)):
        trail -= 1
    lead = max(0, lead - int(RATE * 0.002))
    trail = min(n - 1, trail + int(RATE * tail_ms / 1000))
    return s[lead * ch:(trail + 1) * ch]


def edge_fade(s, ch, in_ms=2, out_ms=5):
    """One-shots: a short fade in/out so a non-zero first or last sample can't click.

    The fade-in must NEVER reach the peak. Percussive one-shots — sfxr blips especially — often
    peak at sample 0, and fading across that destroys the attack, leaves a much smaller residual
    peak, and then normalisation amplifies the remains (ui_move needed +47 dB instead of +11).
    So the fade-in is capped at the distance to the peak, and both fades at a fraction of the file
    so a 3 ms click isn't swallowed whole."""
    total = len(s) // ch
    if total < 8:
        return s
    peak_idx = max(range(total), key=lambda i: max(abs(s[i * ch + c]) for c in range(ch)))
    fin = min(int(RATE * in_ms / 1000), peak_idx, total // 8)
    fout = min(int(RATE * out_ms / 1000), total // 8)
    for k in range(fin):
        g = k / fin
        for c in range(ch):
            s[k * ch + c] = int(s[k * ch + c] * g)
    for k in range(fout):
        g = k / fout
        for c in range(ch):
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
    ap.add_argument("--fade-out", dest="fade_out", type=float, default=0.005,
                    help="one-shot tail fade in seconds; raise it when a sound is cut off "
                         "before it has decayed (engine_off ends 12 dB above silence)")
    ap.add_argument("--hpf", type=float, default=0.0,
                    help="high-pass in Hz — strips engine rumble bleed from tyre-roll recordings")
    ap.add_argument("--flatten", action="store_true",
                    help="hold level constant across a loop, so a drifting source doesn't pulse")
    ap.add_argument("--peak", type=float, default=None,
                    help="override the peak target in dBFS (default -3 one-shot, -6 loop)")
    ap.add_argument("--keep-quiet-head", action="store_true",
                    help="skip silence trimming — for sounds that open quietly on purpose, "
                         "like a starter motor cranking before the engine catches")
    a = ap.parse_args()

    dest_dir, channels, peak_db, is_loop = classify(a.id)
    src = find_source(a.id)
    s, ch, _ = read_wav(convert(src, channels))
    total = len(s) // ch

    if a.start:
        s = s[int(a.start * RATE) * ch:]
        total = len(s) // ch

    if a.hpf:
        s = highpass(s, ch, a.hpf)
        print(f"  high-passed at {a.hpf:.0f} Hz")
    if a.flatten:
        s = flatten(s, ch)
        print("  level flattened across the loop")
    if a.peak is not None:
        peak_db = a.peak

    if is_loop:
        if a.seconds:
            n, f = int(a.seconds * RATE), int(a.fade * RATE)
            if total < n + f:
                sys.exit(f"need {(n + f) / RATE:.1f}s from the offset, have {total / RATE:.1f}s")
            out = make_loop(s, ch, n, f)
        else:
            # No length given: the file IS the loop (a pre-cut library loop). Only crossfade if
            # its natural seam is worse than the signal's own typical sample-to-sample step —
            # a clean loop cut on whole cycles needs no help, and fading it would only shorten it.
            if seam_ratio(s, ch, total) <= 3.0:
                out = s
                print("  natural seam is clean — kept whole, no crossfade")
            else:
                f = int(a.fade * RATE)
                out = make_loop(s, ch, total - f, f)
                print(f"  natural seam poor — crossfaded {a.fade:.2f}s (body {(total - f) / RATE:.2f}s)")
    else:
        out = s[: int(a.seconds * RATE) * ch] if a.seconds else s
        before = len(out) // ch
        if not a.keep_quiet_head:
            out = trim_silence(out, ch)
        out = edge_fade(out, ch, out_ms=a.fade_out * 1000.0)
        if len(out) // ch < before:
            print(f"  trimmed {(before - len(out) // ch) / RATE:.3f}s of silence")

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
