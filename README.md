# RallyRivals

Arcade 3D rally racing against AI rivals. Built with **Godot 4.4.1** (Forward Plus).

## Project layout

```
rallyrivals/
  assets/
    models/      # 3D meshes (cars, track pieces, props) — mostly CC0 packs
    materials/   # shared materials / shaders
    textures/    # texture maps
    audio/       # SFX + music (CC0 / licensed libraries)
  scenes/        # .tscn scene files
  scripts/       # .gd scripts not tied 1:1 to a scene
  ui/            # menus, HUD
  addons/        # third-party plugins
  prototypes/    # throwaway spikes — NOT production, excluded from release builds
```

## Input actions

| Action          | Keyboard      | Gamepad        |
|-----------------|---------------|----------------|
| `accelerate`    | W / Up        | Right trigger  |
| `brake_reverse` | S / Down      | Left trigger   |
| `steer_left`    | A / Left      | Left stick ←   |
| `steer_right`   | D / Right     | Left stick →   |
| `handbrake`     | Space         | A / Cross      |
| `reset_car`     | R             | —              |
| `pause`         | Esc           | Start          |

## Content pipeline (art & audio)

Solo dev, no 3D-modeling or audio-design background — so content leans on free/CC0 libraries:

- **3D models:** Kenney *Car Kit* / *Racing Kit* (CC0, low-poly), Quaternius, Poly Pizza.
- **Audio:** Kenney audio packs, Freesound (CC0 filter), Sonniss GDC bundles for engine/ambience.
- **Look:** low-poly + lighting/post-processing does the heavy lifting instead of hand-detailed assets.

Keep a `CREDITS.md` updated as assets are pulled in (license compliance for shipping).
