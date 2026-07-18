# Audio — pipeline, sound manifest, sourcing

How sound is wired in RallyRivals, every sound the game needs, and where to get them for free
without a licensing headache later.

## 1. How it's wired

**Buses** (`rallyrivals/default_bus_layout.tres`): `Master → Music / SFX / UI`.
`Sfx.set_bus_volume("SFX", 0.8)` is the settings hook (linear 0..1, mutes at 0).

**Two systems, two resource types:**

| | one-shots | loops |
|---|---|---|
| resource | `SfxDef` (`scripts/audio/sfx_def.gd`) | `AmbientDef` (`scripts/audio/ambient_def.gd`) |
| lives in | `assets/audio/sfx/*.tres` | `assets/audio/ambient/*.tres` |
| played by | `Sfx` autoload — `play(def)` / `play_at(def, pos)` | `AmbientBed` — `set_layer(name, def)` |
| behaviour | pooled players, random stream pick, pitch jitter | named layers, crossfaded, non-spatial |

`SfxDef` holds *candidate* streams: give it three gravel impacts and each play picks one at
random with a pitch nudge, so repeated hits never sound machine-stamped.

`AmbientBed` runs two layers today: **`world`** (venue bed — set by the race harness from
`RaceDef.ambience`) and **`weather`** (set by `WeatherFX` from `WeatherPreset.ambient`). They fade
independently, so a storm rolling in doesn't interrupt the crowd. Setting a layer to the def it's
already playing just retargets its level — safe to call every frame.

Thunder is a `SfxDef` on the preset, fired **0.3–2.6 s after** each lightning flash — sound lags
light by the distance to the strike.

**Adding a real sound** — no code changes:
1. Drop the file in `assets/audio/sfx/` or `assets/audio/ambient/`.
2. Loops only: select it, Import tab → **Loop** on → Reimport. (Placeholders skip this — they're
   `.res` `AudioStreamWAV` with loop points baked into the resource.)
3. Point the `.tres` def at it in the inspector. Audition with `\` → Audio.
4. Log it in `assets/audio/SOURCES.md`.

**Formats:** `.ogg` for anything over ~2 s (music, beds, engine loops); `.wav` for short
one-shots (uncompressed, no decode latency). Avoid `.mp3` — gapless looping is unreliable.
Make anything positional (`play_at`) **mono** — stereo files don't pan properly in 3D.
Aim for peaks around −3 dBFS in the file and set the level in the def, not the file.

## 2. Sound manifest

Status: ✅ placeholder in place · ⬜ not sourced yet. Placeholders are synthesized filtered noise
(`scripts/tools/gen_test_sfx.gd`, `gen_ambient_sfx.gd`) — CC0 by construction, replace freely.

### Ambience — `audio-sfx-ambient` ✅ done
| sound | type | used by |
|---|---|---|
| `festival_crowd` ✅ | loop | venue bed, all races (GDD: outlaw festival) |
| `wind_light` ✅ | loop | clear weather |
| `wind_low` ✅ | loop | fog (still, muffled) |
| `rain` ✅ | loop | rain |
| `rain_heavy` ✅ | loop | thunderstorm |
| `snow_wind` ✅ | loop | snow |
| `thunder` ×2 ✅ | one-shot | delayed after each lightning flash |

### Vehicle — `audio-sfx-engine`
| sound | type | notes |
|---|---|---|
| `engine_loop` ⬜ | loop | seamless mid-RPM; pitch-driven from throttle/speed. **Start here** |
| `engine_low` / `engine_high` ⬜ | loop | optional layers to crossfade — richer than pitching one loop ±2 octaves |
| `engine_start` / `engine_off` ⬜ | one-shot | race start / results |

Three brands (Apex/Wreckhouse/Mayfly) eventually want distinct engine character — one loop each
is the cheap version; don't source three until the one-loop version feels right.

### Tyres — `audio-sfx-surface`
| sound | type | notes |
|---|---|---|
| `roll_asphalt` `roll_gravel` `roll_dirt` `roll_sand` `roll_snow` `roll_ice` ⬜ | loop | one per `SurfaceType` id; volume/pitch from speed, crossfaded on surface change |
| `skid_asphalt` ⬜ | loop | tyre screech, faded in by slip angle |
| `skid_loose` ⬜ | loop | gravel/dirt slide — grittier, no screech |

### Impacts — `audio-sfx-impact`
| sound | type | notes |
|---|---|---|
| `impact_light` ×2–3 ⬜ | one-shot | scaled by collision impulse |
| `impact_heavy` ×2–3 ⬜ | one-shot | triggers damage-state swap |
| `scrape` ⬜ | loop | wall-riding |
| `debris_cubes` ⬜ | one-shot | ADR-003 cube burst |

### Race events
| sound | type | task |
|---|---|---|
| `checkpoint` ✅ | one-shot | wired in `track_demo` |
| `countdown_beep` ×3 + `countdown_go` ⬜ | one-shot | `code-race-types` |
| `lap_best` ⬜ | one-shot | `code-race-timing` |
| `finish_win` / `finish_lose` ⬜ | one-shot | `code-race-result` |
| `wrong_way` ⬜ | loop/one-shot | `code-track-checkpoints` |
| `slipstream` ⬜ | loop | `audio-sfx-slipstream` |
| `nitro_fire` + `nitro_loop` ⬜ | one-shot + loop | `audio-sfx-nitro` |

### UI — `audio-sfx-ui`
`ui_click` ✅ · `ui_move` ⬜ (menu navigation) · `ui_confirm` ⬜ · `ui_back` ⬜ · `ui_error` ⬜ ·
`ui_purchase` ⬜ · `ui_unlock` ⬜ (pink-slip win). Kenney's interface pack covers this set in one
CC0 download — the cheapest whole-task win on this page.

### Music — `audio-music-*`
`menu` ⬜ · `race` ⬜ · `boss` ⬜. Direction is its own task (`audio-music-direction`); source only
after that lands.

**Roughly 40 sound files + 3 music tracks** for the full game. Ambience and UI are the two cheapest
groups; engine and tyres are the two that actually sell the driving.

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

## 4. Licence hygiene

Log every file in `assets/audio/SOURCES.md` **as you download it** — source URL, licence, author.
Reconstructing provenance later is miserable, and it's what an asset-store or publisher review
will ask for. Keep the licence text with the download for anything CC-BY.

Rules of thumb: CC0 always fine · CC-BY fine, needs a credits entry · **CC-BY-NC never** (this game
is commercial) · "free for personal use" never · unclear licence, no download.
