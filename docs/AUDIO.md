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

Licence terms below were verified July 2026. **They change** — archive the licence page alongside
anything you download, and re-check before shipping.

### Start here — this order

1. **[Sonniss GDC bundles](https://gdc.sonniss.com/)** — professional libraries, free yearly,
   royalty-free, **no attribution**, and the archive contains **actual rally car libraries** plus a
   22-car library of pre-cut idle/RPM loops. For this game specifically that's the jackpot — see
   §4 for the exact library names. Browse via [GameSounds.xyz](https://gamesounds.xyz/) (plain HTTP
   mirror) instead of torrenting ~30 GB a year. Note `sonniss.com/gameaudiogdc/` only lists through
   2024 — the current bundle is on the `gdc.` host.
2. **[Adobe free SFX](https://www.adobe.com/products/audition/offers/adobeauditiondlcsfx.html)** —
   best free-to-effort ratio for everything that isn't the engine. ~12 GB uncompressed, **no
   attribution, no account, no Audition licence needed**. Transportation (1.4 GB), Crashes,
   Impacts, Ambience, Weather, Sports (crowd), Multimedia (UI). Maps almost one-for-one onto our
   manifest.
3. **[Kenney](https://kenney.nl/assets/category:Audio)** — **CC0**, cleanest terms on this page.
   UI Audio (~50), Interface, Impact (~130). Closes `audio-sfx-ui` in one download and the
   stylization suits the voxel look. **No vehicle content at all.**
4. **[BigSoundBank](https://bigsoundbank.com/licenses.html)** — **CC0**, ~177 car-tagged sounds
   (starters, doors, horns, passes) plus crowds and weather, in WAV. Attribution-free vehicle
   one-shots. Single-mic, so good for one-shots, weak for engine loops.
5. **[ChipTone](https://sfbgames.itch.io/chiptone)** — output is CC0. Generate countdown beeps,
   lap stingers and UI blips in an afternoon.

**Sources 1–5 require zero attribution and zero bookkeeping** — a complete soundscape with no
credit-line obligation.

Then, as needed:

- **[Freesound](https://freesound.org)** — widest selection anywhere (~715k), the only realistic
  source for oddly specific material (gravel-under-tyre, handbrake). **Filter to CC0**; CC-BY works
  with a credits line. Quality varies wildly and loop points are rarely clean. Note the **API is
  non-commercial only** — hand-download, don't ship an integration.
- **[Zapsplat](https://www.zapsplat.com/license-type/standard-license/)** — best genre coverage
  here (160k+, dedicated Vehicles category), and the May 2026 licence explicitly permits games and
  survives a project being sold. **But the free tier is MP3-only**, which makes seamless engine
  loops effectively impossible. One month of Premium (~£4.99) gets WAV and clears attribution
  **for life** on everything downloaded that month — likely the highest-leverage small spend in
  the project.
- **[Pixabay](https://pixabay.com/service/license-summary/)** — free commercial, no attribution.
  **Licence depends on the file's published date**: anything before 2019-01-09 is CC0, anything
  after is the Pixabay Content Licence. Record the date per asset.
- **[99Sounds](https://99sounds.org/license/)** — no attribution, 24-bit WAV. Zero vehicle content,
  but genuinely good crash/collision layers (metal hit + sub = solid arcade crash). Downloads route
  through Gumroad pay-what-you-want; type 0.
- **[OpenGameArt](https://opengameart.org/content/faq)** — thin for this genre (a car search returns
  about a dozen). Prefer CC0 or OGA-BY. **Skip GPL-only audio.**
- **[itch.io](https://itch.io/game-assets/assets-cc0/free)** — **no site-wide licence**; each
  creator sets terms and the License field is unverified self-declaration. The readme inside the
  zip governs. Screenshot the page at download time — creators delete pages.
  [FilmCow](https://filmcow.itch.io/filmcow-sfx) (4,000+, no credit required) is the standout.

### 🚨 Do not use

| Source | Why |
|---|---|
| **BBC Sound Effects / RemArc** | Non-commercial/personal/research **only** — despite what several "best free SFX" listicles claim. The archive is excellent for vintage motorsport, which is exactly what makes it a trap. Commercial route is buying the same effects via Pro Sound Effects. |
| **Mixkit *music*** | "Video Games" is explicitly listed under NOT ALLOWED. Mixkit *SFX* are fine — same site, opposite answer. |
| **The Recordist free SFX** | "Demonstration purposes only." Has excellent vehicle content, so it would have bitten us. $5/sound to clear. |
| **WeLoveIndies free tier** | Demo/pitch only; commercial buyout required before release. |
| **Krotos Studio base tier** | Post-Apr-2025 terms exclude game audio; needs Pro or Max. |
| **Freesound CC-BY-NC / Sampling+** | Non-commercial, and mixed into search results with no visual warning. |
| **OpenGameArt GPL-only** | OGA itself declines to endorse it for closed-source commercial work. |

### Gotchas worth internalising

- **"Ship in a game" ≠ "redistribute the asset."** Sonniss, Pixabay, Zapsplat, 99Sounds, Adobe and
  Mixkit all permit the first and forbid the second. The one action that breaches all six at once:
  shipping loose raw audio files in a user-browsable folder, or publishing a modding asset pack.
  **Packing into the `.pck` resolves this cleanly** — which is what a normal Godot export does, so
  just don't ship an unpacked `assets/audio/`.
- **CC-BY-SA contaminates your edits, not your code.** Retune or layer a CC-BY-SA engine loop and
  that derivative must ship CC-BY-SA. Your source and other assets are unaffected — but it's a
  needless obligation when CC0 alternatives exist.
- **SoundImage (Eric Matyas)** requires the credit **inside the game itself**; a store page or
  YouTube description is explicitly insufficient. Fine, just know the rule before you rely on it.
- **AI-training bans are the new standard clause** (Sonniss, Zapsplat, BBC). Irrelevant to
  shipping; relevant only if you ever train something on your own SFX corpus.
- **Soundly's optional Freesound add-on library is *not* covered by Soundly's clearance** — select
  the CC0-only option if you use it.
- **[Fab](https://dev.epicgames.com/documentation/en-us/fab/licenses-and-pricing-in-fab)** probably
  permits non-Unreal engines, but the binding EULA could not be verified (the page blocks automated
  fetch). Read it in a browser before shipping Fab audio in a Godot build. Free audio there is thin
  anyway.

## 4. Engine audio — the one that matters

The engine is the hardest asset in a racer and the one that most changes how the car feels. Worth
its own section.

### Download this first

The Sonniss archive contains **actual rally car libraries**, which is an absurd piece of luck for
this project. Browse via [GameSounds.xyz](https://gamesounds.xyz/) (directory listing, pull single
folders) rather than the multi-GB zips:

| Bundle | Library | Why |
|---|---|---|
| **2020** | **Soundholder — Game Audio Engines** | The prize. 311 WAVs, **22 cars**, already cut into **idle loops, RPM loops, RPM ramps, engine on/off, interiors and stems**. Normally a paid library. This alone can carry the whole engine system. |
| 2020 | Pole Position — Toyota Corolla 1998 **rally car** | |
| 2020 | Pole Position — Volvo 142 **rally car** | |
| 2021–23 | Pole Position — **Škoda Fabia R5 WRC2** | Modern WRC |
| 2015 | Membrans — **Rally Cars Sound Pack 01 & 02** | |
| 2021–23 | 344 Audio — **SUV Dirt Track Racing** | Gravel/dirt character |
| 2020 | Soundholder — **Cars In Motion: Wet Asphalt** | Pairs with our weather system |

Pole Position are a Stockholm outfit who record rally professionally — their bundle contributions
suit this project better than anything else free. Note: the licence inside the zip you download
governs your copy (the AI-training clause was added later), so keep each bundle's `License.pdf`.

Free alternative for prototyping: [OpenGameArt racing car engine loops](https://opengameart.org/content/racing-car-engine-sound-loops)
(**CC0**) is six WAVs of one loop at different pitches — a ready-made RPM ladder, low fidelity but
exactly the right *shape* to build the system against. Careful: the popular
[qubodup engine loop](https://freesound.org/people/qubodup/sounds/147242/) is **CC-BY, not CC0**.

### Technique — do this, skip the rest

**Tier 0, single loop + `pitch_scale = rpm / base_rpm`.** What most Godot vehicle demos do. Fine
for 30 minutes of placeholder, but samples audibly stretch past **±500 RPM** from where they were
recorded, and worse: *the timbre never changes*. A real engine at 6000 RPM isn't a higher-pitched
1000 RPM engine. And coasting sounds identical to flooring it — which is precisely the thing
players feel.

**Tier 1, RPM bands + crossfade ← build this.** Full-fat production uses loops every 500 RPM
(every 250 below ~2500), ~13 per perspective. **We don't need that.** 3–4 bands (idle / low / mid /
high) with pitch scaling *within* each band keeps every sample inside its ±500 RPM comfort zone
across 1000–7000. Crossfade width ≈ half the band spacing, equal-power, not linear.

**The single highest-value addition is not more bands — it's an on-load/off-load blend.** Two
timbres at the same RPM, picked by throttle. That's what makes the car feel connected to your
right foot. If you only have one sample set, fake the off-load version offline: remove the intake
layer, cut ~2 kHz and ~10 kHz, drop the fundamental a few dB, lower the level.

**Tier 2 (granular) and Tier 3 (runtime synthesis): skip.** Granular actually rates *most*
realistic in the one academic comparison I found, but Godot has no granular engine — you'd write
it against `AudioStreamGenerator`, and the classic failure (clicks from jumping between grains) is
easy to hit and tedious to fix. Wrong cost/benefit for a solo dev on an arcade racer.

**But do use the synthesis tools offline as a sample factory.**
[EngineSim Community Edition](https://www.enginesim.dev/) has a "Dyno Hold" mode that gives you
the one thing you cannot capture without a dynamometer: **clean on-load vs off-load steadies at
exact RPMs**. One indie dev built their whole engine sound this way with no car — 16 files, idle
plus gas at 1000 RPM intervals, captured through Audacity.
[`enginesound`](https://github.com/DasEtwas/enginesound) (MIT) does the same and exports loops with
a built-in crossfade flag, but ships Windows binaries only — on macOS you'd build from 2021-era
Rust, so try EngineSim first.

To label bands correctly you need each loop's true RPM:
`RPM = (loop fundamental Hz × 60 ÷ cylinders) × 2`

### Godot 4 specifics

- **`pitch_scale` resamples** (pitch *and* tempo), which is exactly what an engine wants, and it's
  cheap. **Don't** reach for `AudioEffectPitchShift` — it colours the audio even at 1.0
  ([#55090](https://github.com/godotengine/godot/issues/55090)).
- **Disable `doppler_tracking` on the engine player.** It multiplies with your `pitch_scale` and
  fights the RPM mapping. Enable it on passing AI cars if you want the effect there.
- **`AudioStreamSynchronized`** (4.3+) plays up to 32 sub-streams sample-locked with per-stream
  volume — a near-perfect fit for the on-load/off-load pair, which must stay locked *and* share one
  `pitch_scale`. ⚠️ `set_sync_stream_volume()` is on the **resource**, and Godot resources are
  shared by default — **`.duplicate()` per vehicle** or every car on the grid shares volumes.
  Verify that early with two cars.
- It **cannot** carry the RPM bands themselves: each band needs its own `pitch_scale`, and the
  player's pitch applies to all sub-streams. Bands need separate `AudioStreamPlayer3D` nodes.
- **WAV for engine loops** — precise loop points, uncompressed, gets pitched. Ogg for the long beds.

### The shape this takes in our codebase

Both primitives already exist. `Sfx.attach_loop()` returns an `AudioStreamPlayer3D` parented to an
emitter, and `AmbientBed` already implements the exact `move_toward` dB crossfade — including the
"same stream, just retarget the level" optimisation — that the band blending needs.

- An `EngineDef` resource mirroring `SfxDef`: bands of `{stream, base_rpm, min_rpm, max_rpm}`, plus
  idle and redline cues.
- An `EngineAudio` node that calls `attach_loop()` once per band (3–4 players, all playing), and
  each frame sets `pitch_scale = rpm / band.base_rpm` and an equal-power volume weight across the
  band's RPM window. Clamp per-band pitch to ~0.85–1.3 and let band boundaries do the rest.
- Throttle drives the on-load/off-load blend. Route to the existing `SFX` bus so the volume
  settings already work.
- Cost is 3–4 players per car. With a full grid, give distant AI a single-loop fallback and reserve
  the band stack for the player and nearest rivals.

Reference implementation worth reading:
[Dechode/Godot-Advanced-Vehicle](https://github.com/Dechode/Godot-Advanced-Vehicle) (Godot 4, full
RPM/clutch/drivetrain sim). Best two articles:
[BOOM Library on interactive car engines](https://www.boomlibrary.com/blog/the-car-engine-sound-primer-mike-caviezel/)
(RPM spacing, crossfade widths, the on/off-load EQ recipe) and
[Pole Position on recording cars](https://www.asoundeffect.com/car-sound-effects-recording/).

### If you record your own

**Skip the phone.** Phone OS audio applies AGC, noise suppression, and a high-pass filter that
removes exactly the low end that makes an engine sound powerful. A Zoom H1n or Tascam DR-05X
(~$80–120) is a categorical upgrade: manual gain, 24-bit, real capsules.

- **96 kHz / 24-bit, mono, manual gain set low.** The high sample rate matters more here than
  almost anywhere else, because engine loops get pitch-shifted constantly — at 48 kHz your ceiling
  is 12 kHz after an octave down, which is why pitched engines sound dull.
- **One mic position: exhaust, off-axis, 1–2 m back.** Exhaust carries the character; engine bay
  only adds clarity. **Never point into the pipe** — gas blast distorts and carbon damages capsules.
- **Capture:** cold start, warm start, shutdown, 60 s+ idle, throttle blips, off-load steadies ~500
  RPM apart held 10 s each, then a single-gear full-throttle ramp to redline and a coastdown.
  **Slate every take verbally** — with 50 near-identical files it's the difference between a
  session and a garbage pile.
- **Mistakes:** riding gain mid-take (repeat the run instead), AGC left on, reverberant locations
  (parking garages stamp unremovable slap-back), takes under 5–10 s.
- **Post order:** high-pass → denoise → EQ → **normalise last**. High-pass at **30–50 Hz, not the
  usual 80–120** — a 4-cylinder at 3000 RPM has a 100 Hz fundamental and the standard field cutoff
  would gut it. Cut loops on **whole combustion cycles** or they thump, and audition at ~30
  repetitions: a click you can't hear once is a metronome after thirty.
- ⚠️ **Safety.** Carbon monoxide — never rev in an enclosed space, never lie near a tailpipe in
  still air. Moving belts and fans can start with the engine off. **Do not** jack the wheels up or
  brake against the torque converter to fake load — a car in gear on jack stands can walk off
  them. Use EngineSim for load steadies instead. Revving is also noise-regulated; go daytime,
  weekday, industrial estate, with the owner's permission.

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

Log every file in `assets/audio/SOURCES.md` **as you download it** — source URL, licence, author,
download date, and (for Pixabay) the file's published date. Reconstructing provenance later is
miserable, and it's the first thing a storefront or publisher review asks for. Screenshot or
archive the licence page too: terms change, and several sources here reserve the right to change
them.

Rules of thumb: CC0 always fine · CC-BY fine, needs a credits entry · **CC-BY-NC never** (this game
is commercial) · "free for personal use" never · unclear licence, no download.

**Ship audio packed, not loose.** Sonniss, Zapsplat, Pixabay, 99Sounds, Adobe and Mixkit all permit
using a sound *in* a game and forbid redistributing the asset itself. A normal Godot export packs
everything into the `.pck`, which settles it — just don't ship an unpacked `assets/audio/` folder
or publish a modding asset pack without re-checking.

### A note on AI-generated SFX

Tempting, and mostly not worth it here:

- **ElevenLabs free tier is non-commercial** per its Terms of Use, even though its marketing pages
  say otherwise. The terms govern. Paid plans do include commercial rights.
- **Meta AudioGen/MusicGen weights are CC-BY-NC** — the code is MIT but the released checkpoints
  are not usable commercially. **Stable Audio** free tier is likewise non-commercial.
- **AI output may not be copyrightable at all.** If a work lacks human authorship it may not be
  protectable, which means you might have no standing to stop someone lifting your engine sound
  straight out of the shipped game. A vendor's "commercial licence" is not the same as you owning
  a copyright.
- **Don't feed licensed SFX into an AI tool.** Sonniss, Zapsplat and A Sound Effect all explicitly
  prohibit using their sounds for AI training — generating variants from them likely breaches the
  licence you're relying on.

For a game you intend to sell, recorded libraries with written licences carry materially less risk.
Use AI for one-off filler at most, never for the signature engine sound.
