# SFX status board — RallyRivals

Working checklist for sourcing production audio. Three independent columns:

- **PH** — placeholder exists (synthesized, CC0, auditionable in-game)
- **SRC** — production sound sourced + logged in `assets/audio/SOURCES.md`
- **WIRED** — actually triggered by game code (not just sitting in the folder)

15 placeholders + **23 sourced** — all beds, 3 engine bands, 2 surface loops, 12 one-shot defs.
Still placeholder: ui_move, ui_back, skid_asphalt, 6 roll_*, checkpoint, engine_start/off, impacts, debris.

**Deferred:** `slipstream`, `nitro_loop`, `nitro_fire` removed for now — their features
(`code-vehicle-slipstream`, `code-vehicle-brand-features`) aren't built. Backlog tasks remain.
Audition everything in-game: `\` → Audio (one-shots + beds + driven loops).

---

## Ambience — `assets/audio/ambient/` (AmbientDef + .res)

| # | sound | PH | SRC | WIRED | notes |
|---|---|:--:|:--:|:--:|---|
| 1 | festival_crowd | — | ✅ | ✅ | **SOURCED** — gamesounds.xyz, 12 s stereo wav, seamless, −27.5 dB in mix |
| 2 | wind_light | — | ✅ | ✅ | **SOURCED** — Adobe, 10 s stereo, seamless, −36.5 dB |
| 3 | wind_low | — | ✅ | ✅ | **SOURCED** — Adobe, 10 s stereo, seamless, −37.0 dB |
| 4 | rain | — | ✅ | ✅ | **SOURCED** — Adobe, 10 s, seamless, −34.8 dB |
| 5 | rain_heavy | — | ✅ | ✅ | **SOURCED** — Adobe, cut from 2.0 s (source fades in), −24.4 dB |
| 6 | snow_wind | — | ✅ | ✅ | **SOURCED** — Adobe, 10 s, seamless, −38.6 dB |

## Driven loops — `assets/audio/loops/` (raw .res, no SfxDef)

Deliberately NOT SfxDefs: a looping stream in the one-shot pool never releases its player.
Their owning systems will define their own config resources.

| # | sound | PH | SRC | WIRED | owning task |
|---|---|:--:|:--:|:--:|---|
| 7 | engine_low | — | ✅ | ⬜ | **SOURCED** — Sonniss, 14.25 s mono, natural loop kept whole |
| 8 | engine_mid | — | ✅ | ⬜ | **SOURCED** — Sonniss, 6.37 s mono, 1 s crossfade |
| 9 | engine_high | — | ✅ | ⬜ | **SOURCED** — Sonniss, 5.50 s mono, 0.5 s crossfade |
| 10 | roll_asphalt | ✅ | ⬜ | ⬜ | audio-sfx-surface |
| 11 | roll_gravel | ✅ | ⬜ | ⬜ | audio-sfx-surface |
| 12 | roll_dirt | ✅ | ⬜ | ⬜ | audio-sfx-surface |
| 13 | roll_sand | ✅ | ⬜ | ⬜ | audio-sfx-surface |
| 14 | roll_snow | ✅ | ⬜ | ⬜ | audio-sfx-surface |
| 15 | roll_ice | ✅ | ⬜ | ⬜ | audio-sfx-surface |
| 16 | skid_asphalt | ✅ | ⬜ | ⬜ | ⚠️ **still to source** — needs a sustained squeal, not a skid event |
| 17 | skid_loose | — | ✅ | ⬜ | **SOURCED** — 1.15 s mono from 0.1 s, gritty (tonality 0.09) |
| 18 | scrape | — | ✅ | ⬜ | **SOURCED** — 2.93 s mono, natural loop kept whole. ⚠️ 11 dB envelope swing — may read as pulsing once wired |

## One-shots — `assets/audio/sfx/` (SfxDef + .res)

| # | sound | var | PH | SRC | WIRED | owning task |
|---|---|:--:|:--:|:--:|:--:|---|
| 19 | checkpoint | 1 | ✅ | ⬜ | ✅ | wired in track_demo |
| 20 | thunder | 2 | — | ✅ | ✅ | **SOURCED** — 2 variants, 2.75 s + 4.07 s |
| 21 | countdown_beep | 1 | — | ✅ | ⬜ | **SOURCED** — 0.99 s, 0.72 s of silence trimmed |
| 22 | countdown_go | 1 | — | ✅ | ⬜ | **SOURCED** — 0.48 s |
| 23 | lap_best | 1 | — | ✅ | ⬜ | **SOURCED** — 0.57 s |
| 24 | finish_win | 1 | — | ✅ | ⬜ | **SOURCED** — 0.84 s |
| 25 | finish_lose | 1 | — | ✅ | ⬜ | **SOURCED** — 0.45 s |
| 26 | wrong_way | 1 | — | ✅ | ⬜ | **SOURCED** — 0.23 s |
| 27 | impact_light | 3 | ✅ | ⬜ | ⬜ | audio-sfx-impact |
| 28 | impact_heavy | 3 | ✅ | ⬜ | ⬜ | audio-sfx-impact |
| 29 | debris_cubes | 3 | ✅ | ⬜ | ⬜ | audio-sfx-impact (ADR-003 burst) |
| 30 | engine_start | 1 | ✅ | ⬜ | ⬜ | audio-sfx-engine |
| 31 | engine_off | 1 | ✅ | ⬜ | ⬜ | audio-sfx-engine |
| 32 | ui_click | 1 | — | ✅ | ⬜ | **SOURCED** — ⚠️ only 2.6 ms, verify it reads as a click |
| 33 | ui_move | 1 | ✅ | ⬜ | ⬜ | ⚠️ **re-source** — dropped file had only 4 distinct sample values (~1.6 bits)
| 34 | ui_confirm | 1 | — | ✅ | ⬜ | **SOURCED** — 0.06 s |
| 35 | ui_back | 1 | ✅ | ⬜ | ⬜ | still to source (was not in the drop)
| 36 | ui_error | 1 | — | ✅ | ⬜ | **SOURCED** — 0.18 s |
| 37 | ui_purchase | 1 | — | ✅ | ⬜ | **SOURCED** — 0.43 s |
| 38 | ui_unlock | 1 | — | ✅ | ⬜ | **SOURCED** — 0.62 s |

## Music — `audio-music-*`

| # | track | PH | SRC | WIRED |
|---|---|:--:|:--:|:--:|
| 39 | menu | ⬜ | ⬜ | ⬜ |
| 40 | race | ⬜ | ⬜ | ⬜ |
| 41 | boss | ⬜ | ⬜ | ⬜ |

No placeholders for music on purpose — `audio-music-direction` decides the brief first.

---

## Sourcing order (highest impact first)

Full detail in `docs/AUDIO.md` §3 (sources + licences) and §4 (engine specifically).

1. ~~engine_low/mid/high~~ **done** (Sonniss). Next: build the band crossfade — `audio-sfx-engine`.
2. **roll_gravel / roll_asphalt / skid_loose** — the surface system is the game's identity.
   Sonniss (344 Audio SUV Dirt Track, Soundholder Cars In Motion) + Adobe Transportation.
3. **UI set (7 sounds)** — one Kenney CC0 pack closes the whole row. Or ChipTone in an afternoon.
4. **impact_light / impact_heavy / debris_cubes** — Adobe Crashes + Impacts, or Kenney Impact.
6. Everything else — replace opportunistically.

Optional spend worth considering: **one month of Zapsplat Premium (~£4.99)** gets WAV instead of
MP3 and clears attribution **for life** on everything downloaded that month. Their vehicle
catalogue is the deepest of any free tier. The free tier being MP3-only makes it useless for
engine loops specifically (encoder padding breaks seamless looping).

## Do not use

BBC Sound Effects/RemArc (non-commercial — and tempting, it has great motorsport) · Mixkit *music*
(games explicitly barred; Mixkit SFX are fine) · The Recordist free (demo only, has good vehicle
content so it would bite) · Krotos free tier · ElevenLabs free tier · Meta AudioGen ·
Freesound CC-BY-NC.

---

# Shopping list — formats + where to get each

Format rules: **positional = mono** · **loops = WAV** (precise loop points, gets pitched) ·
**long beds = OGG** · 44.1 kHz/16-bit throughout · peak **−3 dBFS one-shots, −6 dBFS loops**.

Source shorthand:
- **SON-20** / **SON-21** = Sonniss GDC bundle 2020 / 2021-23, via https://gamesounds.xyz
- **ADOBE** = https://www.adobe.com/products/audition/offers/adobeauditiondlcsfx.html
- **KENNEY** = https://kenney.nl/assets/category:Audio (CC0)
- **BSB** = https://bigsoundbank.com (CC0)
- **FS** = freesound.org — **check the licence on each sound page**, it is per-sound
- **CHIP** = https://sfbgames.itch.io/chiptone (output CC0)

## Driven loops — WAV · mono · seamless · −6 dBFS

| sound | len | primary source | fallback |
|---|---|---|---|
| `engine_low/mid/high` | 1–3 s | **SON-20 › Soundholder "Game Audio Engines"** — 22 cars, RPM loops already cut | SON-20/21 › Pole Position rally cars (Škoda Fabia R5, Corolla, Volvo 142) |
| `engine_*_offload` ×3 | 1–3 s | EngineSim "Dyno Hold" (enginesim.dev) — clean off-load steadies at exact RPM | fake from on-load: kill intake, cut ~2k + ~10k, drop fundamental |
| `roll_asphalt` | 2–4 s | **SON-20 › Soundholder "Cars In Motion / Wet Asphalt"** | ADOBE › Transportation |
| `roll_gravel` `roll_dirt` | 2–4 s | **SON-21 › 344 Audio "SUV Dirt Track Racing"** | SON-20 › Pole Position gravel/stone-on-body |
| `roll_sand` | 2–4 s | ADOBE › Transportation | scarce — layer quiet asphalt roll + sand foley |
| `roll_snow` `roll_ice` | 2–4 s | ADOBE › Transportation + Weather | scarce — layer quiet roll + snow crunch foley |
| `skid_asphalt` | 2–4 s | **FS CC0 squeal set: /s/71736/ /71737/ /71738/** (audible-edge, the canonical one) | ADOBE › Transportation |
| `skid_loose` | 2–4 s | **SON-21 › 344 Audio dirt track** | SON-15 › Membrans Rally Cars 01/02 |
| `scrape` | 2–4 s | ADOBE › Industry | SON-20 › Pole Position "Car Destruction" |

**Prototyping the band system before sourcing:** https://opengameart.org/content/racing-car-engine-sound-loops
(CC0, six pitch variants = a ready-made RPM ladder, low fidelity but the right shape).
⚠️ The popular qubodup engine loop on FS is **CC-BY, not CC0**.

## Ambience beds — OGG · stereo · seamless · −6 dBFS

| sound | len | primary source | fallback |
|---|---|---|---|
| `festival_crowd` | 8–20 s | **ADOBE › Sports** (81 MB) | FS CC0 crowd; SoundImage urban ambience (credit in-game) |
| `wind_light` `wind_low` | 8–20 s | **ADOBE › Ambience 1 & 2** (2.4 GB) | FS CC0 |
| `rain` `rain_heavy` | 8–20 s | **ADOBE › Weather** (396 MB) | FS CC0 |
| `snow_wind` | 8–20 s | ADOBE › Weather + Ambience | FS CC0 |

## One-shots, positional — WAV · mono · −3 dBFS

| sound | var | len | primary source | fallback |
|---|---|---|---|---|
| `impact_light` | 3 | 0.2–0.5 s | **ADOBE › Crashes + Impacts** | KENNEY Impact Sounds (130, CC0, stylized — good arcade fit) |
| `impact_heavy` | 3 | 0.4–1.0 s | **SON-20 › Pole Position "Car Destruction"** | ADOBE › Crashes |
| `debris_cubes` | 3 | 0.4–0.8 s | SON-20 › Pole Position gravel/stone-on-body | 99sounds metal hits; ADOBE › Impacts |
| `checkpoint` | 1 | 0.2–0.4 s | **CHIP** (generate) | KENNEY Interface |
| `engine_start` | 1 | 1.5–3 s | **SON-20 › Soundholder engine on/off** | **BSB** starters (CC0); FS /s/405322/ (CC0) |
| `engine_off` | 1 | 1–2 s | SON-20 › Soundholder engine on/off | BSB (CC0) |

## One-shots, non-positional — WAV · stereo · −3 dBFS

| sound | len | primary source | fallback |
|---|---|---|---|
| `thunder` ×2 | 2–4 s | **ADOBE › Weather** | **BSB** (CC0) |
| `countdown_beep` `countdown_go` | 0.2 / 0.5 s | **CHIP** (generate — exact pitch control) | KENNEY Digital Audio |
| `lap_best` | 0.5–1 s | CHIP | KENNEY Music Jingles |
| `finish_win` `finish_lose` | 1–2 s | **KENNEY Music Jingles** | CHIP |
| `ui_click` `ui_move` `ui_confirm` `ui_back` `ui_error` | 0.05–0.3 s | **KENNEY UI Audio + Interface Sounds** — one CC0 download covers all 7 | CHIP |
| `ui_purchase` `ui_unlock` | 0.5–1.5 s | KENNEY Music Jingles | CHIP |
| `wrong_way` | 0.5–1 s | CHIP | KENNEY Interface |

## Music — OGG · stereo · −16 LUFS matched

`menu` `race` `boss` — source after `audio-music-direction`. Options: SoundImage.org (free,
**credit required inside the game**), or commission. ⚠️ **Mixkit music explicitly bars video
games** even though its SFX are fine.

---

## Regenerate placeholders

```
godot --headless --script res://scripts/tools/gen_placeholder_audio.gd --path .
```
Seeded — identical bytes every run, so git stays quiet.
