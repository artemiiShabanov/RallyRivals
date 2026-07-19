# Drop folder — raw sourced audio

Put raw downloads here and Claude processes them into the game. `.gdignore` keeps Godot from
importing anything in this folder, so half-finished drops can't break the project.

## Naming

**The filename before the extension must be the manifest id.** That's the whole contract — it's
how each file finds its destination and format.

```
engine_mid.wav        -> driven loop, mono, seamless, -6 dBFS
roll_gravel.aiff      -> driven loop, mono, seamless, -6 dBFS
rain.mp3              -> ambience bed, ogg, stereo, seamless, -6 dBFS
impact_heavy_1.wav    -> one-shot variant 1 of 3, mono, -3 dBFS
impact_heavy_2.wav
impact_heavy_3.wav
ui_click.wav          -> one-shot, stereo, -3 dBFS
```

Any input format is fine — wav, ogg, mp3, flac, aiff, stereo or mono, any sample rate. Conversion
is the job. Variants use `_1` `_2` `_3`. Ids are in `SFX_STATUS.md` / `docs/AUDIO.md` §2.

Partial drops are fine and encouraged — one group at a time (all the UI sounds, or just the three
engine loops) is easier to review than 41 at once.

If a file needs trimming to a specific region, say so — "engine_mid: use 0:12–0:15" — rather than
trying to edit it first.

## Provenance — the one thing that must come with the files

Add a line per file to `sources.txt` in this folder:

```
engine_mid.wav | Sonniss GDC 2020 / Soundholder Game Audio Engines | Sonniss bundle licence | Soundholder
ui_click.wav   | https://kenney.nl/assets/ui-audio | CC0 | Kenney
```

If a whole batch is from one source, one line saying so is enough. This is the only part that
can't be reconstructed later, and it's what a storefront review asks for.

## What happens to them

1. Convert to target format/channels/rate per the manifest (mono for positional, wav for loops,
   ogg for beds)
2. Trim silence, peak-normalise (−3 dBFS one-shots, −6 dBFS loops)
3. Build seamless loops where needed — equal-power crossfade, the same method as the generator
4. Set loop points / import settings so Godot actually loops them
5. Point the `SfxDef` / `AmbientDef` at the new stream, or replace the driven-loop `.res`
6. Log provenance in `../SOURCES.md`, update the status board
7. Run the audio probe (levels, loop seams, format, no looping one-shots) and commit

## What Claude cannot check

**Whether it sounds right.** Levels, seams, formats, lengths and clipping are all measurable and
get verified. Whether a gravel loop actually sounds like gravel, whether a crossfade pumps, or
whether the engine sits well against the others — that needs your ears. Audition after each batch
with `\` → Audio.

Anything measurably suspect (clipped, near-silent, wrong length, DC offset, a "loop" that can't be
made seamless) gets flagged rather than silently shipped.
