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
| everything else under `loops/` | synthesized — `scripts/tools/gen_placeholder_audio.gd` | CC0 (own work) | project | 2026-07-18 |

**All beds and all one-shots are sourced.** Only the 7 remaining `loops/` entries (`skid_asphalt`
and the six `roll_*`) are still synthesized placeholders — filtered noise generated from code, CC0
by construction. As each is replaced, drop it from the blanket row above and give it its own row.

Example of what a filled row looks like:

| `loops/engine_mid.ogg` | https://freesound.org/s/123456/ | CC0 1.0 | username | 2026-08-01 |
