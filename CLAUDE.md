# RallyRivals: рабочие заметки для Claude

Аркадные ралли-гонки против ИИ-соперников, 3D, воксельный арт, VHS-эстетика. Соло-разработка с целью
выпустить. Перед дизайном читай `docs/PILLARS.md` и `docs/GDD.md`, перед планированием `docs/PLAN.md`.
Общий процесс всех проектов: gamedev-hub/WORKFLOW.md.

## Layout

- `rallyrivals/` проект Godot 4.4 (Forward Plus); `project.godot` лежит здесь, не в корне репозитория.
  - `scenes/` сцены по областям: `vehicle/`, `track/`, `race/`, `ai/`, `ui/`, `tools/` (редактор карт
    `map_editor.tscn`, кнопка бейка `track_bake.tscn`, галерея UI).
  - `scripts/` код по тем же областям плюс `core/` (scene flow, save, settings, камера), `meta/`
    (экономика, классы, кампания), `audio/`, `world/`, `surfaces/`, `tools/` (дебаг-меню и
    генераторы `gen_*.gd`, которые пишут `.tres`).
  - `assets/` ресурсы и тюнинг-числа: `cars/`, `surfaces/`, `regions/`, `races/`, `tracks/<id>/`
    (3 авторские картинки + `props.json`; `baked_track.tscn` и `ground_*.res` в gitignore),
    `voxels/` (.vox и запечённые меши), `audio/`, `fonts/`.
  - `ui/` темы и общие контролы; `prototypes/` одноразовые спайки, из релиза исключаются.
- `docs/` дизайн и план. Руками правятся `GDD.md` (решённое), `IDEAS.md` (нерешённое), `PILLARS.md`,
  `CARS.md`, `RIVALS.md`, `ROSTER.md`, `CAMPAIGN.md`, `AUDIO.md`, `SFX_STATUS.md`, `PLAYTESTS.md`
  (журнал плейтестов), `FUN_CHECKLIST.md`, `LAUNCH_CHECKLIST.md`, `adr/` (технические решения),
  `specs/` (спеки систем). `plan.yaml` источник плана, `PLAN.md` генерируется.
- `tools/sync_plan.py` зеркалит план в GitHub. `prep_audio.py` в корне готовит звуки из
  `rallyrivals/assets/audio/_incoming/` (см. `docs/AUDIO.md` §5).
- `CREDITS.md` лицензии ассетов, пополнять при каждом новом стороннем ассете.

## Verification loop

- Godot: `/Applications/Godot.app/Contents/MacOS/Godot`. Всегда передавать абсолютный `--path`
  до `rallyrivals/`: запуск из каталога без `project.godot` молча сообщает ноль ошибок парсинга.
- Проверить, что проект собирается без ошибок скриптов:
  `Godot --path <abs>/rallyrivals --headless --editor --quit` (вывод без `SCRIPT ERROR`/`Parse Error`).
- После добавления ассетов: `Godot --path <abs>/rallyrivals --headless --import`. Воксельные `.png`
  палитры импортировать lossless с `detect_3d=0`, иначе палитра размывается.
- Бейк трассы: `Godot --path <abs>/rallyrivals --headless --script res://scripts/track/bake_track_cli.gd -- res://assets/tracks/<id>`.
- Гонять сцену без редактора: `Godot --path <abs>/rallyrivals --headless res://scenes/<...>.tscn --quit-after 300`.
  Автотеста с `END ok` пока нет: завести при первой же задаче с риском регрессии.
- Генераторы `.tres` (`scripts/tools/gen_*.gd`): после добавления `@export` в ресурс перегенерировать
  и grep-проверить, что редактор не сбросил поле в дефолт во всех `.tres`.
- Перед коммитом: редактор открывается без ошибок, тронутые сцены запускаются, в `CREDITS.md` есть
  новые ассеты. Многие закоммиченные ассеты были заглушками: готовность проверять по реальной
  проводке, не по наличию файла.

## Process

1. Взять issue (`/next-task`). Нужно дизайн-решение: бриф в issue (вопрос, 2-3 варианта,
   рекомендация), метка `status: needs decision`, ждать Артемия.
2. Реализация на `main`, небольшие коммиты, сообщение ссылается на issue (`#12`). Пуш в конце сессии.
3. Играбельно: метка `status: needs playtest`, комментарий что пробовать и каким дебаг-меню
   (`\` в дебаг-сборке). Артемий играет и закрывает; результаты через `/playtest` в `docs/PLAYTESTS.md`.
4. Definition of done: редактор без ошибок, скриншот или замер в issue, решения в GDD/ADR.
5. Правка плана: `docs/plan.yaml`, затем `python3 tools/sync_plan.py --github` (`/sync-plan`).
6. Проект должен оставаться играбельным после каждого коммита; чередовать типы задач, короткие
   задачи вперемешку с длинными.

## Conventions

- GDScript со статической типизацией; `var x := f()` падает, если `f` возвращает Variant.
- `snake_case` функции и переменные, `PascalCase` классы и ноды, сигналы вверху скрипта.
- Тюнинг-числа только в `assets/**/*.tres`, не в коде сцен. Ресурсы с `class_name` в `scripts/`.
- Воксельные машины моделируются по референсу: реальная машина на модель, спек-лист пропорций,
  затем модель (см. `docs/CARS.md`).
- Язык документов и issues русский или английский, как уже в файле; код и идентификаторы английские.
- Трейлер коммита: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
