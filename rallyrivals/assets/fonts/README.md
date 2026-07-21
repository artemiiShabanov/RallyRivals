# UI font

Drop **one** font file here and the theme picks it up automatically — the generator loads the first
`.ttf` / `.otf` it finds in this folder.

```
assets/fonts/<anything>.ttf
```

Then rebuild the theme:

```
godot --headless --script res://scripts/tools/gen_ui_theme.gd --path .
```

Until a font is here, the theme falls back to Godot's default font, so the UI still works — it just
won't have the final look.

## What suits the game (arcade-retro, voxel)

- A **pixel / bitmap font** matches the voxel look best (e.g. a blocky display face for headings).
- Pick something with a **heavy, wide** display weight for the big HUD numbers; legibility at a
  glance matters more than character for a speed readout.
- A monospace-ish or tabular-figures font stops the timer/speed **jittering** as digits change
  width. If the font has tabular figures, even better.

## Licence — commercial game

Same rule as audio (`docs/AUDIO.md`): the game is commercial, so the font licence must permit
**embedding/redistribution in a commercial product**.

- **SIL Open Font License (OFL)** — the gold standard, free, embeddable, no attribution in-app
  required. Most Google Fonts are OFL. Safe.
- **Apache / MIT** fonts — also fine.
- **"Free for personal use"** — NOT usable. Common trap on dafont-style sites.
- Log the source + licence in `assets/fonts/SOURCES.md` when you add one.

Good OFL starting points for this style: **Press Start 2P**, **Silkscreen**, **VT323**,
**Pixelify Sans**, **Chakra Petch**, **Rajdhani** (the last two are wide sporty non-pixel faces
that also fit an arcade racer).
