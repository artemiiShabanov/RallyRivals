# assets/audio/music/

Finished music loops, one per context (AUDIO.md §7). Played by the `Music` autoload.

**To add a track `<id>` (e.g. `menu`, `time_trial`, `circuit`, `sprint`, `endurance`, `grand_prix`):**
1. Drop `<id>.ogg` here. In its **Import** tab: **Loop = on**, **Loop Offset = 0.0**, Reimport
   (a non-zero offset can pop — AUDIO.md §1). Keep it stereo.
2. Create `<id>.tres` (a `MusicDef`) pointing `stream` at it; set `volume_db` LUFS-matched to the
   others, `fade` to taste (~1.5 s).
3. That context now plays it automatically — `Music.play("<id>")` is already wired
   (menu screens → "menu"; the race director → the race type).

Contexts: `menu` · `time_trial` · `circuit` · `sprint` · `endurance` · `grand_prix`.
The **boss duel is a sprint**, so it uses the `sprint` track (no separate file).

CC-BY tracks: log attribution in `../../../../CREDITS.md` and `../SOURCES.md`.
