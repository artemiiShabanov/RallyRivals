# План RallyRivals

Источник: `docs/plan.yaml`. Обновить: `python3 tools/sync_plan.py`.

Размеры: S = полдня, M = день, L = два дня, XL = три дня.

## M0 Сделано до миграции

**Цель:** Всё, что было закрыто в tasks.yaml до перехода на GitHub Issues (сентябрь 2026): ядро, трек-пайплайн, редактор карт, 15 воксельных машин, UI, аудио, экономика, кампания.  
**Готово, когда:** Закрыта при миграции.  
**Оценка:** 147.5 дн. (осталось 0.0)

| | Задача | Тип | Кто | Размер |
|---|---|---|---|---|
| [x] | Project scaffold, folders, renderer/display config | code |  | M |
| [x] | Input map (keyboard + gamepad) | code |  | M |
| [x] | Repo conventions + prototypes/ excluded from release | code |  | S |
| [x] | Three design pillars | design |  | M |
| [x] | Fill canonical GDD | design |  | L |
| [x] | ADR-001: vehicle physics model | design |  | L |
| [x] | ADR-002: track representation | design |  | XL |
| [x] | Image-driven track baker (images -> static scene) to scripts/ | code |  | L |
| [x] | Gray-box test track (authored images + tuned TrackPath) | code |  | M |
| [x] | Checkpoint gates baked from the spline | code |  | M |
| [x] | Bake tool as in-editor @tool button | code |  | M |
| [x] | Apply region per race (runtime reskin: off-road grip+colour + prop tints + dressing; RaceDef.region replaces .season) | code |  | L |
| [x] | Prop system: catalog + props.json (scatter/oriented) + collisions + editor authoring | code |  | M |
| [x] | Bake AI racing line from the spline | code |  | M |
| [x] | Weather grip modifier (stacks on surface grip) | code |  | S |
| [x] | Apply per-race time-of-day + weather visuals | code |  | M |
| [x] | Debug overlay/tools (perf, physics, state readouts) | code |  | M |
| [x] | Map editor: canvas shell (zoom/pan, blueprint underlay, layer toggles, save/load) | code |  | XL |
| [x] | Map editor: surface paint brush (palette from .tres, sizes, off-road eraser) | code |  | L |
| [x] | Map editor: race tools (start/dir/gate pairs + validation) | code |  | L |
| [x] | Map editor: prop stamp tool | code |  | S |
| [x] | Map editor: auto-heightmap from road + height control points | code |  | XL |
| [x] | Map editor: export 4 images + one-click bake | code |  | M |
| [x] | Map editor: shift-drag straight lines + prop brush (drag to lay props, aimed types take the drag direction) | code |  | M |
| [x] | Point-to-point tracks (cyan finish pair: open march/curve, finish gate, editor tool) | code |  | L |
| [x] | Promote VehicleBody3D controller to scripts/ | code |  | L |
| [x] | Front/rear grip + handbrake drift layer | code |  | M |
| [x] | Per-surface grip via SurfaceType | code |  | M |
| [x] | Damage system (visible + performance) | code |  | L |
| [x] | Drive handling from the 5 stat bars | code |  | M |
| [x] | Chase camera (promote from prototype) | code |  | M |
| [x] | Scene/flow manager + pause | code |  | M |
| [x] | Save system | code |  | M |
| [x] | Pooling / perf helpers (perf-first rule) | code |  | M |
| [x] | Apply graphics/audio/control settings | code |  | S |
| [x] | RaceDef resource (track, type, culture, conditions, reward pools) | code |  | M |
| [x] | Lap/stage timing | code |  | M |
| [x] | Race lifecycle director (grid -> 3-2-1-GO countdown -> run -> finish -> freeze -> hand to results) | code |  | L |
| [x] | Win/lose + finishing place | code |  | M |
| [x] | Race types: sprint + circuit | code |  | L |
| [x] | Race type: time trial vs clock | code |  | S |
| [x] | Race type: endurance / attrition | code |  | M |
| [x] | Race type: grand prix (qualify + grid + class gate) | code |  | L |
| [x] | Officials penalty vs Wilds ramming rules | code |  | M |
| [x] | Assemble the race field: class band + size by type, drawn from the chapter roster | code |  | M |
| [x] | Spawn + score the assembled field in open races (physical grid, band-paced sim times, live gap-to-leader standings) | code |  | M |
| [x] | AI rival driving a baked spline line | code |  | XL |
| [x] | Boss-rival duel behavior | code |  | M |
| [x] | Five stat bars display widget | ui |  | S |
| [x] | Basic HUD (speed / position / timer) | ui |  | M |
| [x] | Title / main menu (New / Continue / Settings / Quit) | ui |  | S |
| [x] | Settings + input remap screen | ui |  | M |
| [x] | Save-slot select screen (3 slots: new/continue/delete) | ui |  | M |
| [x] | Career hub shell (stub tiles Map/Shop/Garage + live RACE tile) | ui |  | M |
| [x] | Loading screen (async scene load) | ui |  | S |
| [x] | Pre-race info screen | ui |  | M |
| [x] | Post-race results + rewards screen (reward line stubbed until economy) | ui |  | M |
| [x] | Region map of races + CP/boss progress | ui |  | L |
| [x] | Car preview component (3D model turntable) | ui |  | M |
| [x] | Car shop screen | ui |  | M |
| [x] | Garage / car-select screen | ui |  | M |
| [x] | Change car from pre-race (owned-car picker) | ui |  | S |
| [x] | Pause menu | ui |  | S |
| [x] | Restyle HUD as a broadcast scorebug | ui |  | S |
| [x] | Money + CP wallets (seed money + debug top-up; real earn = economy) | code |  | S |
| [x] | Car catalog registry (all/owned/by-class + placeholder prices) | code |  | S |
| [x] | Banked-best top-up payout economy | code |  | L |
| [x] | Class system S-D + class gating | code |  | M |
| [x] | Always-open price-gated car shop | code |  | M |
| [x] | Owned-cars garage + selection | code |  | M |
| [x] | Beat rival -> win their car (pink-slip) | code |  | M |
| [x] | Chapter CP gate (~70%) + advance on boss win | code |  | L |
| [x] | SurfaceType resources (asphalt/dirt/snow/sand/gravel/ice) | design |  | M |
| [x] | Define car stat roster (classes S-D) | design |  | M |
| [x] | Define 3-4 manufacturers (identity + brand feature) | design |  | M |
| [x] | Define 4 boss-rivals (brand + class per chapter) | design |  | M |
| [x] | 4-chapter structure (class mixes, boss per chapter) | design |  | M |
| [x] | Chapter driver rosters (9 per chapter: name, number, brand, behaviour) | design |  | M |
| [x] | Placeholder voxel car block-out | 3d |  | M |
| [x] | Voxel inventory scaffold: 45 car + 3 wheel stubs with .vox sources | 3d |  | S |
| [x] | CarDef model refs: body/wheel meshes swap with the car | code |  | S |
| [x] | Head/taillights: night beams via LightingPreset + brake flare | code |  | S |
| [x] | Voxel prop set (rocks/signs/barriers) — each prop authored per region x3 for scatter variety | 3d |  | L |
| [x] | Voxel scenery/buildings set | 3d |  | L |
| [x] | Visual family per manufacturer | 3d |  | M |
| [x] | Voxel car: Kerb (Apex D, starter) — MV pipeline validation | 3d |  | M |
| [x] | Voxel car: Mule (Wreckhouse D) | 3d |  | M |
| [x] | Voxel car: Spark (Mayfly D) | 3d |  | M |
| [x] | Voxel car: Tangent (Apex C) | 3d |  | M |
| [x] | Voxel car: Crowbar (Wreckhouse C) | 3d |  | M |
| [x] | Voxel car: Fuse (Mayfly C) | 3d |  | M |
| [x] | Voxel car: Meridian (Apex B) | 3d |  | M |
| [x] | Voxel car: Anvil (Wreckhouse B) | 3d |  | M |
| [x] | Voxel car: Strobe (Mayfly B) | 3d |  | M |
| [x] | Voxel car: Verdict (Apex A) | 3d |  | M |
| [x] | Voxel car: Sledge (Wreckhouse A) | 3d |  | M |
| [x] | Voxel car: Comet (Mayfly A) | 3d |  | M |
| [x] | Voxel car: Stiletto (Apex S) | 3d |  | M |
| [x] | Voxel car: Juggernaut (Wreckhouse S) | 3d |  | M |
| [x] | Voxel car: Nova (Mayfly S) | 3d |  | M |
| [x] | Voxel wheel: Apex Cartel rim | 3d |  | S |
| [x] | Voxel wheel: Wreckhouse rim | 3d |  | S |
| [x] | Voxel wheel: Mayfly Speedworks rim | 3d |  | S |
| [x] | Screen shake + landing thump (+ VHS glitch spike) | vfx |  | S |
| [x] | Per-surface particles (dust/snow/spray) | vfx |  | M |
| [x] | Tyre skid marks (per-surface ribbon under sliding wheels) | vfx |  | M |
| [x] | Damage VFX (hood smoke + body judder) | vfx |  | M |
| [x] | Weather visuals (rain/snow/fog) | vfx |  | L |
| [x] | HUD scorebug graphics (VHS register) | ui |  | M |
| [x] | VHS UI theme (white-on-blue OSD) + font | ui |  | L |
| [x] | Stylized VHS scene transition (channel-change / tracking-glitch wipe) | ui |  | M |
| [x] | Master colour palette (voxel + terrain ramps, ADR-003) | art |  | S |
| [x] | Weather-driven sky sets (VHS banded sky shader) | vfx |  | M |
| [x] | Time-of-day lighting presets | vfx |  | M |
| [x] | Terrain surface/splat-blend shader | vfx |  | M |
| [x] | Per-surface material response: matte/gloss + fake blocky relief | vfx |  | M |
| [x] | VHS tape post-process (grain/bleed/tracking; intensity slider + off switch) | vfx |  | M |
| [x] | SFX infrastructure: buses, pooled Sfx autoload, SfxDef, placeholder sounds | audio |  | M |
| [x] | Engine audio: 3 RPM bands crossfaded + start/off cues | audio |  | M |
| [x] | Per-surface tyre roll + skid, crossfaded on surface change | audio |  | M |
| [x] | Impact SFX scaled by collision impulse + debris burst | audio |  | S |
| [x] | UI clicks/confirms (wired in debug menu; real menus reuse) | audio |  | S |
| [x] | Ambient beds: festival crowd + per-weather (rain/snow/wind/fog) + thunder | audio |  | M |
| [x] | Music direction + sourcing plan | audio |  | L |
| [x] | Menu/career music track (breezy city pop) | audio |  | M |
| [x] | Race music set: one loop per race type (city-pop palette) | audio |  | L |
| [x] | Boss-duel music (distinct track) | audio |  | S |
| [x] | ADR: voxel art pipeline (export/runtime, FX, coherence) | design |  | M |
| [x] | Sync GDD 4/7 with decided ADR-001/002 | design |  | S |
| [x] | Spec: field-matching rule for open (non-GP) races | design |  | S |
| [x] | Spec: banked-best reward economy | design |  | S |
| [x] | Fun verdict: first drive (feel/flow) | design |  | M |

## M1 Чувство езды и честная гонка

**Цель:** Довести ощущение руля и гонку против ИИ до «весело и честно»: тюнинг констант, различия классов и покрытий, кривая сложности ИИ.  
**Готово, когда:** Плейтест полной гонки даёт вердикт «напряжённо и честно».  
**Оценка:** 7.0 дн.

| | Задача | Тип | Кто | Размер |
|---|---|---|---|---|
| [ ] | Tune car feel constants (buttery pass) | design | both | L |
| [ ] | Differentiate feel across classes/brands | design | both | M |
| [ ] | Tune grip values per surface + weather modifiers | design | both | M |
| [ ] | Difficulty via opponents + track complexity | code | claude | M |
| [ ] | AI pace/aggression curve | design | both | M |
| [ ] | Fun verdict: full race (tense + fair) | design | artemii | M |

## M2 Вертикальный срез

**Цель:** Одна настоящая трасса и одна отполированная гонка от пре-рейса до результатов, с боссом.  
**Готово, когда:** Плейтест вертикального среза пройден; первая трасса собрана из авторских карт.  
**Оценка:** 4.0 дн.

| | Задача | Тип | Кто | Размер |
|---|---|---|---|---|
| [ ] | First real track (heightmap/surface/markers images) | design | both | L |
| [ ] | Boss-rival intro screen (car + class) | ui | claude | M |
| [ ] | Fun verdict: vertical slice (one polished race) | design | artemii | M |

## M3 Контент кампании

**Цель:** Набор трасс на 4 главы, таблицы выплат и цен, пейсинг прогрессии.  
**Готово, когда:** Кампания проходится от первой гонки до четвёртого босса; плейтест цикла даёт «хочу следующую победу».  
**Оценка:** 6.0 дн.

| | Задача | Тип | Кто | Размер |
|---|---|---|---|---|
| [ ] | Campaign track set (v1 regions x races) | design | both | XL |
| [ ] | Payout/price tables (banked-best economy) | design | both | M |
| [ ] | Chapter CP-gate % + progression pacing | design | both | M |
| [ ] | Fun verdict: campaign loop (want-next-win) | design | artemii | M |

## M4 Релиз

**Цель:** Экспорт под три ОС, Steam-ачивки, чеклист запуска и упаковка для магазина.  
**Готово, когда:** Сборки собираются на mac/win/linux, LAUNCH_CHECKLIST.md закрыт.  
**Оценка:** 3.5 дн.

| | Задача | Тип | Кто | Размер |
|---|---|---|---|---|
| [ ] | Export presets + exclude prototypes/* from release | release | claude | M |
| [ ] | Per-OS export configs (mac/win/linux) | release | claude | S |
| [ ] | Steam achievements (event-triggered, no in-game unlocks) | code | claude | M |
| [ ] | Launch checklist + store packaging | release | both | M |

## Итого

Всего 168.0 рабочих дней, из них осталось 20.5.
