# Audio provenance

One row per audio file, filled in **at download time**. See `docs/AUDIO.md` §4 for the rules
(CC0 preferred, CC-BY needs a credits entry, CC-BY-NC never — this game is commercial).

Anything CC-BY also needs a line in the in-game credits screen.

| file | source | licence | author | date |
|---|---|---|---|---|
| `ambient/festival_crowd.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `ambient/wind_light.wav` | Adobe free SFX (Audition DLC) | Adobe Software Licence Agreement — commercial OK, **no attribution required**, no standalone redistribution | Adobe | 2026-07-19 |
| `ambient/wind_low.wav` | Adobe free SFX (Audition DLC) | Adobe Software Licence Agreement — commercial OK, **no attribution required**, no standalone redistribution | Adobe | 2026-07-19 |
| `ambient/rain.wav` | Adobe free SFX (Audition DLC) | Adobe Software Licence Agreement — commercial OK, **no attribution required**, no standalone redistribution | Adobe | 2026-07-19 |
| `ambient/rain_heavy.wav` | Adobe free SFX (Audition DLC) | Adobe Software Licence Agreement — commercial OK, **no attribution required**, no standalone redistribution | Adobe | 2026-07-19 |
| `ambient/snow_wind.wav` | Adobe free SFX (Audition DLC) | Adobe Software Licence Agreement — commercial OK, **no attribution required**, no standalone redistribution | Adobe | 2026-07-19 |
| `loops/engine_low.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `loops/engine_high.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `loops/engine_mid.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `loops/skid_loose.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `loops/scrape.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `sfx/thunder_1.wav` `thunder_2.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `sfx/ui_*.wav`, `countdown_*.wav`, `lap_best.wav`, `finish_*.wav`, `wrong_way.wav`, `checkpoint.wav` | generated with **sfxr** (DrPetter) | public domain — generated output, owned outright | project | 2026-07-19 |
| `sfx/impact_light_*.wav`, `impact_heavy_*.wav`, `debris_cubes_*.wav` | Adobe free SFX (Audition DLC) | Adobe Software Licence Agreement — commercial OK, **no attribution required**, no standalone redistribution | Adobe | 2026-07-19 |
| `sfx/engine_start.wav` `engine_off.wav` | https://gamesounds.xyz (Sonniss GDC bundle mirror) | #GameAudioGDC Bundle Licence — commercial OK, **no attribution required** | Sonniss contributor | 2026-07-19 |
| `loops/roll_*.wav` (6 surfaces) | ⚠️ **which source?** | | | 2026-07-19 |
| `loops/skid_asphalt.wav` | ⚠️ **which source?** | | | 2026-07-19 |

**Every sound is sourced — no synthesized placeholders remain.** `gen_placeholder_audio.gd` is
kept as the authoring record and still regenerates anything that gets deleted, but it skips any id
with a real recording beside it.

Example of what a filled row looks like:

| `loops/engine_mid.ogg` | https://freesound.org/s/123456/ | CC0 1.0 | username | 2026-08-01 |
