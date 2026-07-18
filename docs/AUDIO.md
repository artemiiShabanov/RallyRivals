# Audio — pipeline, sound manifest, sourcing

How sound is wired in RallyRivals, every sound the game needs, and where to get them for free
without a licensing headache later.

## 1. How it's wired

**Buses** (`rallyrivals/default_bus_layout.tres`): `Master → Music / SFX / UI`.
`Sfx.set_bus_volume("SFX", 0.8)` is the settings hook (linear 0..1, mutes at 0).

**Two systems, two resource types:**

| | one-shots | ambience loops | driven loops |
|---|---|---|---|
| resource | `SfxDef` | `AmbientDef` | none — raw stream |
| lives in | `assets/audio/sfx/` | `assets/audio/ambient/` | `assets/audio/loops/` |
| played by | `Sfx.play(def)` / `play_at(def, pos)` | `AmbientBed.set_layer(name, def)` | `Sfx.attach_loop(node, stream)` |
| behaviour | pooled players, random stream pick, pitch jitter | named layers, crossfaded, non-spatial | parented to an emitter, driven live |

**Driven loops deliberately have no `SfxDef`.** A `LOOP_FORWARD` stream played through the
one-shot pool would hold its player forever and starve the pool. Engine and tyre loops belong to
systems that drive their pitch and level continuously, and those systems will bring their own
config resources (RPM ranges, per-surface mapping) when they're built.

`SfxDef` holds *candidate* streams: give it three gravel impacts and each play picks one at
random with a pitch nudge, so repeated hits never sound machine-stamped.

`AmbientBed` runs two layers today: **`world`** (venue bed — set by the race harness from
`RaceDef.ambience`) and **`weather`** (set by `WeatherFX` from `WeatherPreset.ambient`). They fade
independently, so a storm rolling in doesn't interrupt the crowd. Setting a layer to the def it's
already playing just retargets its level — safe to call every frame.

Thunder is a `SfxDef` on the preset, fired **0.3–2.6 s after** each lightning flash — sound lags
light by the distance to the strike.

**Adding a real sound** — no code changes:
1. Drop the real `.wav` / `.ogg` in the matching folder. Import the actual file rather than
   converting to `.res` — placeholders are `.res` because they're generated and disposable; a
   sourced file should stay inspectable and re-editable outside Godot.
2. Loops only: select it, **Import** tab → **Loop Mode = Forward** → Reimport. Do *not* leave it
   on `Detect from WAV` — that reads the file's `smpl` chunk, which most library WAVs and editor
   exports don't write, and the loop then silently doesn't loop. This is the #1 cause of
   "my loop doesn't loop".
3. Point the `.tres` def at it in the inspector — or, for a driven loop, replace the stream.
4. Audition with `\` → Audio (one-shots, beds, and driven loops are all playable there).
5. Log it in `assets/audio/SOURCES.md`.

**Formats:** `.wav` (QOA compression) for short one-shots — no decode latency, fired often.
`.ogg` for anything long: beds, engine loops, music. **Avoid `.mp3` for loops**: MP3 frames are a
fixed 1152 samples and must be full, so the encoder inserts ~576 samples of delay at the head and
up to 1152 of padding at the tail — that silence *is* the gap. Ogg loops fine, but keep
**Loop Offset at 0.0** and bake the loop into the file: a non-zero offset can pop
([godot#64775](https://github.com/godotengine/godot/issues/64775)).

**Mono for anything positional** (`play_at`, engine, tyres, impacts). A stereo file carries its own
baked-in left-right image, which fights the engine's spatialization — part of the sound stays on
the wrong side and it never collapses to a point source. Keep stereo for music, the non-spatial
beds, UI, and full-screen cues like `finish_win`. Converting: `-ac 1` sums both channels, which can
thin out a wide recording through phase cancellation — if it goes hollow, take one channel instead.

**Levels:** peak-normalize files to a common ceiling — **−3 dBFS for one-shots, −6 dBFS for
loops and beds** (loops are always playing, so everything else stacks on top of them) — then do
all balancing in `volume_db` on the def. Headroom matters because a race sums engine + tyres +
rain + crowd + an impact + a UI click at once, and summed signals clip. Don't LUFS-normalize
one-shots (a 0.2 s click has no meaningful integrated loudness); *do* use LUFS to match the three
music tracks and the six beds to each other. Peak-normalizing does **not** make a set sound even —
a bright click at −3 dBFS reads much louder than a dull thud at −3 — so audition each group
back-to-back in game and fix outliers in the def.

**Sample rate:** keep sourced files at 44.1 kHz; don't downsample. The placeholders are 22.05 kHz
because they're noise and it halves the repo, but real files get pitch-shifted — `SfxDef` jitters
±12% on impacts and the engine loop is pitch-driven across its whole range — and pitching a
downsampled file *up* exposes its missing bandwidth immediately. If you need the size back, use
**Force/Mono** in the import settings: same 50%, no quality cost.

## 2. Sound manifest

**All 41 sounds have placeholders** — synthesized filtered noise and harmonic stacks from
`scripts/tools/gen_placeholder_audio.gd`, CC0 by construction, seeded so regeneration is
byte-identical. None are production sounds; replace freely. Columns below track what each is
*for* and which system owns it — **⬜ = still a placeholder, ✅ = real sound sourced.**

The live sourcing checklist (placeholder / sourced / wired per sound) is kept separately so it can
be ticked off without editing this doc.

### Ambience — `audio-sfx-ambient` (system done, sounds ⬜)
| sound | type | used by |
|---|---|---|
| `festival_crowd` | bed | venue bed, all races (GDD: outlaw festival) |
| `wind_light` | bed | clear weather |
| `wind_low` | bed | fog (still, muffled) |
| `rain` | bed | rain |
| `rain_heavy` | bed | thunderstorm |
| `snow_wind` | bed | snow |
| `thunder` ×2 | one-shot | delayed 0.3–2.6 s after each lightning flash |

### Vehicle — `audio-sfx-engine`
| sound | type | notes |
|---|---|---|
| `engine_mid` | driven loop | the one that matters — pitch-driven from throttle/speed. **Start here** |
| `engine_low` / `engine_high` | driven loop | RPM layers to crossfade — richer than pitching one loop ±2 octaves |
| `engine_start` / `engine_off` | one-shot | race start / results |

Three brands (Apex/Wreckhouse/Mayfly) eventually want distinct engine character — one loop each
is the cheap version; don't source three until the one-loop version feels right.

### Tyres — `audio-sfx-surface`
| sound | type | notes |
|---|---|---|
| `roll_asphalt` `roll_gravel` `roll_dirt` `roll_sand` `roll_snow` `roll_ice` | driven loop | one per `SurfaceType` id; volume/pitch from speed, crossfaded on surface change |
| `skid_asphalt` | driven loop | tyre screech, faded in by slip angle |
| `skid_loose` | driven loop | gravel/dirt slide — grittier, no screech |

### Impacts — `audio-sfx-impact`
| sound | type | notes |
|---|---|---|
| `impact_light` ×3 | one-shot | scaled by collision impulse |
| `impact_heavy` ×3 | one-shot | triggers damage-state swap |
| `scrape` | driven loop | wall-riding |
| `debris_cubes` ×3 | one-shot | ADR-003 cube burst |

### Race events
| sound | type | task |
|---|---|---|
| `checkpoint` | one-shot | wired in `track_demo` |
| `countdown_beep` + `countdown_go` | one-shot | `code-race-types` |
| `lap_best` | one-shot | `code-race-timing` |
| `finish_win` / `finish_lose` | one-shot | `code-race-result` |
| `wrong_way` | one-shot | `code-track-checkpoints` |
| `slipstream` | driven loop | `audio-sfx-slipstream` |
| `nitro_fire` + `nitro_loop` | one-shot + driven loop | `audio-sfx-nitro` |

### UI — `audio-sfx-ui`
`ui_click` · `ui_move` (menu navigation) · `ui_confirm` · `ui_back` · `ui_error` · `ui_purchase` ·
`ui_unlock` (pink-slip win). Kenney's interface pack covers this set in one CC0 download — the
cheapest whole-task win on this page.

### Music — `audio-music-*`
`menu` · `race` · `boss` — **no placeholders on purpose**; `audio-music-direction` writes the brief
first, and a synthesized stand-in would only anchor the direction badly.

**41 sound files + 3 music tracks** for the full game. Ambience and UI are the two cheapest groups;
engine and tyres are the two that actually sell the driving.

## 3. Where to get sounds for free

Ranked by how much time they save. **Prefer CC0** — no attribution string to maintain, no risk if
a file's provenance gets murky three years in.

**Best for this project:**

- **[Sonniss GDC Game Audio Bundle](https://sonniss.com/gameaudiogdc)** — professional sound
  libraries released free every year, tens of GB, **royalty-free for commercial games, no
  attribution**. Grab a few years' bundles. The vehicle/engine and weather libraries here are far
  better than anything on the free-sample sites. *Start here for engine and tyre sounds.*
- **[Kenney](https://kenney.nl/assets?q=audio)** — CC0, game-ready, consistent. Interface and
  impact packs. Deliberately stylized, which suits the voxel look.
- **[Freesound](https://freesound.org)** — the biggest library, but **licenses are per-file**:
  filter to **CC0** and you can ignore the rest. CC-BY needs attribution; **CC-BY-NC is
  non-commercial — unusable if you ever sell the game.** Account required.
- **[OpenGameArt](https://opengameart.org)** — game-focused, mixed CC0/CC-BY/GPL. Check each asset.

**Also worth a look:**

- **[Pixabay](https://pixabay.com/sound-effects/)** — own license, free commercial use, no
  attribution. Quality is uneven and provenance is thin; fine for filler, not for hero sounds.
- **[99Sounds](https://99sounds.org)** — curated free packs, royalty-free.
- **[Zapsplat](https://zapsplat.com)** — large library, free tier **requires attribution**.
- **[SoundImage](https://soundimage.org)** (Eric Matyas) — free music and SFX, **attribution
  required**; a real option for `audio-music-*`.

**Avoid:** the **BBC Sound Effects** archive — the RemArc licence is personal/educational/research
only, **not commercial use**. YouTube "free sound effects" rips: unverifiable provenance.

**For engine sounds specifically:** a clean pitchable loop is genuinely hard to find free. Three
routes, cheapest first — (1) Sonniss vehicle libraries, (2) record a real car with a phone (an
idle at steady RPM is enough to start), (3) synthesize procedurally. Arcade racers don't need
realism; they need *responsive*, so a decent loop that tracks throttle instantly beats a gorgeous
recording that lags.

## 5. Preparing a sourced file

Raw downloads are almost never drop-in. The three jobs are: make it loop, make it mono (if
positional), make it sit at the right level.

### Making a seamless loop

Two distinct seam failures, often confused:

- **Click/pop** — the waveform jumps between the last and first sample. Fix with a zero-crossing
  edit or a 2–5 ms fade at each end.
- **Pumping/dip** — a *linear* crossfade sums two uncorrelated signals and loses ~3 dB in the
  middle, so the loop point audibly ducks every cycle. Fix by using an **equal-power** crossfade
  curve. This is the detail most tutorials get wrong, and it's why the generator uses `sqrt`
  weights rather than a straight lerp.

**Loop length:** 4–10 s for noise-like beds (rain, wind, crowd, tyre roll) — long enough that the
ear doesn't catch the repeat, short enough to stay small. Under ~2 s you hear the period. Engine
loops go the *other* way: a fraction of a second, because you're pitch-shifting it live and a long
loop makes pitch tracking feel laggy.

**In Audacity** (free, macOS) — the crossfade-loop recipe:
1. Import, select the region you want, **Edit → Remove Special → Trim Audio**, drag to time 0.
2. Select the first *N* seconds (*N* = crossfade length, 0.5–2 s for beds) and **Cut**.
3. **Tracks → Add New → Mono Track**, **Paste** into it, and slide it to overlap the *tail* of the
   original.
4. Select across both tracks over the overlap → **Effect → Fading → Crossfade Tracks** →
   Fade type = **Constant Power 1** ← this is the anti-pumping setting.
5. **Tracks → Mix → Mix and Render**, then tiny (few ms) fades at the very start and end.
6. Audition with **Transport → Playing → Loop Play**.
7. **File → Export → Export as WAV**, 16-bit PCM.

`Z` (**Select → At Zero Crossings**) snaps a selection to zero-crossings — often enough on its own
for short percussive loops that don't need a crossfade at all.

If you end up doing this more than a handful of times, Reaper ($60 personal licence, 60-day full
free evaluation) makes crossfades non-destructive and draggable, which is a different experience
from Audacity's commit-and-undo loop.

### Batch commands

`brew install ffmpeg sox` first. These are from documentation, not run here — check results by ear.

```bash
# convert to game-ready mono 44.1k/16-bit
for f in *.wav; do ffmpeg -i "$f" -ac 1 -ar 44100 -c:a pcm_s16le "out/$f"; done

# peak-normalise to -3 dBFS (sox is better at this than ffmpeg)
for f in *.wav; do sox "$f" "out/$f" gain -n -3; done

# trim silence at both ends (reverse trick handles the tail)
for f in *.wav; do
  sox "$f" "out/$f" silence 1 0.05 0.1% reverse silence 1 0.05 0.1% reverse
done

# stereo -> mono, phase-safe alternative if summing goes hollow
sox in.wav out.wav remix -     # sum both channels
sox in.wav out.wav remix 1     # keep left only

# whole pipeline for one positional SFX
sox raw.wav clean.wav remix - rate -h 44100 \
    silence 1 0.05 0.1% reverse silence 1 0.05 0.1% reverse gain -n -3
```

For LUFS-matching the music tracks and the beds, [`ffmpeg-normalize`](https://github.com/slhck/ffmpeg-normalize)
(`pipx install ffmpeg-normalize`) wraps the fiddly two-pass `loudnorm` invocation:

```bash
ffmpeg-normalize *.wav -nt peak -t -3 -c:a pcm_s16le -ext wav -of out/   # SFX
ffmpeg-normalize *.ogg -nt ebu  -t -16 -of out/                          # music/beds
```

Single-pass `loudnorm` applies *dynamic* gain and will squash the material — always two-pass, or
let the wrapper do it.

## 6. Licence hygiene

Log every file in `assets/audio/SOURCES.md` **as you download it** — source URL, licence, author.
Reconstructing provenance later is miserable, and it's what an asset-store or publisher review
will ask for. Keep the licence text with the download for anything CC-BY.

Rules of thumb: CC0 always fine · CC-BY fine, needs a credits entry · **CC-BY-NC never** (this game
is commercial) · "free for personal use" never · unclear licence, no download.
