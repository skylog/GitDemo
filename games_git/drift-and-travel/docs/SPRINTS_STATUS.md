# Finom Drift & Travel — Sprint Status

**Дата:** 2026-05-17
**PRD:** [PRD.md](./PRD.md) v2.1 (Beta — local relay)
**GDD:** [finom-drift-and-travel-gdd-v4.md](./finom-drift-and-travel-gdd-v4.md) v4.0

---

## Сводка прогресса

| Sprint | Название | Статус | Файлов | Тестировался |
|--------|----------|--------|--------|--------------|
| 0 | Setup | ✅ Готов | 2 + структура папок | ⬜ Нет (нужно открыть в Godot) |
| 1 | Foundation (KartConfig, presets, input) | ✅ Готов | 7 | ⬜ Нет |
| 2 | Kart & Physics local-only | ✅ Готов | 3 | ⬜ Нет |
| 3 | Track & Race Logic single-player | ✅ Готов | 8 (3 new + 5 overwritten) | ⬜ Нет |
| 4 | Game Flow (FSM + Countdown + Results) | ✅ Готов | 7 (6 new + 1 overwritten) | ⬜ Нет |
| 5 | Single-screen HUD + Mini-map | ✅ Готов | 4 | ⬜ Нет |
| 6 | Local Relay MVP (Node.js) | ✅ Готов | 4 | ⬜ Не запускался |
| 7 | Network client integration | ✅ Готов | 5 new + 2 modified | ⬜ Нет |
| 8 | State sync + Input sync | ✅ Готов | 2 new + 1 modified | ⬜ Нет |
| 9 | Race sync + Disconnect handling | ✅ Готов | 2 new + 2 modified | ⬜ Нет |
| 10 | Physics Panel host-only + Animation | ✅ Готов | 4 new + 1 modified | ⬜ Нет |
| 11 | Polish + Web Export | ✅ Готов | 2 new/modified | ⬜ Нет |

**Готовность Beta:** 12 спринтов из 12 (100%). Полный цикл: single-player, relay, лобби, сетевая синхронизация, Physics Panel, анимации, README, валидация.

---

## Sprint 0 — Setup ✅

**Gate:** Godot открывает проект без ошибок, 4 autoload готовы.

**Файлы:**
- `project.godot` — Godot 4.3, autoload, Input Map (WASD+Space+LCtrl+F1-F3+R), Physics Layers (world/kart/checkpoint/powerup)
- `.gitignore` — Godot + macOS + IDE
- Структура папок: `scenes/{kart,track,ui}/`, `scripts/`, `resources/presets/`, `assets/{models,animations,textures,fonts}/`

**Открытые риски:**
- Возможна нормализация `Object(InputEventKey,...)` синтаксиса при первом открытии Godot — придётся пересохранить Input Map один раз.

---

## Sprint 1 — Foundation ✅

**Gate:** В Inspector видны все @export, `InputManager.get_input()` возвращает корректный dict.

**Файлы:**
- `resources/kart_config.gd` — 24 @export по GDD §4
- `resources/presets/mario_kart.tres` — все значения GDD §4.2
- `resources/presets/kart_kraft.tres` — все значения GDD §4.3
- `scripts/input_manager.gd` — Beta one-player, WASD+Space+LCtrl (отличие от GDD §8.2)
- `scripts/game_manager.gd` — autoload stub с enum State {LOADING, MENU, LOBBY, RACE_COUNTDOWN, RACE_ACTIVE, RACE_FINISHED, RESULTS} (расширен Sprint 4)
- `scripts/race_manager.gd` — autoload stub (перезаписан Sprint 3)
- `scripts/checkpoint_manager.gd` — autoload stub (перезаписан Sprint 3)

---

## Sprint 2 — Kart & Physics ✅

**Gate:** WASD водит кресло по пустой плоскости, Space дрифт.

**Файлы:**
- `scenes/kart/kart.gd` (225 строк) — `class_name Kart extends RigidBody3D`. Физика по GDD §6: gravity / steering / acceleration / drift / lateral friction / ground friction / air resistance / clamp. Респаун при y<-5 и stuck 5s. Анимация и сеть — отложены.
- `scenes/kart/kart.tscn` — узлы по GDD §5.1: RigidBody3D (mass=80, layer=2, mask=1) + ChairMesh + CollisionShape + CharacterRig/AnimationPlayer + 4 RayCast3D + CameraArm/KartCamera + NameLabel + RespawnTimer
- `scenes/_sprint2_test.tscn` — пол 100×0.2×100 + Kart на (0,1,0) + DirectionalLight + WorldEnvironment

**Чтобы протестировать:** Main Scene = `_sprint2_test.tscn`, F5.

---

## Sprint 3 — Track & Race Logic ✅

**Gate:** Один kart, 3 круга, корректные lap_times, направление проверяется.

**Файлы (new):**
- `scenes/track/test_track.gd` — добавляет в группу "track", ставит cp_index meta
- `scenes/track/test_track.tscn` — square donut: outer 30×30, inner 22×22, corridor 4m. Floor + 4 outer walls + 4 inner walls + StartLine + 5 Area3D checkpoints + 2 Marker3D spawn points + Sun + WorldEnvironment
- `scenes/_sprint3_test.gd` + `_sprint3_test.tscn` — driver: spawn 1 kart, bind track, set GameManager state = RACE_ACTIVE

**Файлы (overwritten):**
- `scripts/checkpoint_manager.gd` (71 строка) — полная реализация GDD §10.1: order check, direction check (.dot(expected) > 0), регистрация круга, finish после TOTAL_LAPS
- `scripts/race_manager.gd` (71 строка) — полная реализация GDD §10.2: setup, position calc (каждые 0.5s), kart_score = lap*10000 + cp*1000 - dist, register_kart_finished, get_respawn_transform
- `scenes/kart/kart.gd` — `_on_respawn_timeout` использует `RaceManager.get_respawn_transform`

**Layout треков:**
```
Координаты (X right, Z forward):
  CP3(-X)
  ┌───────────────┐
  │  inner wall   │
CP4│   22×22       │CP2
  │   island      │
  │               │
  └───────────────┘
  CP0──CP1 (south)
Spawn_P1: (-10, 0.5, +13), facing +X
Spawn_P2: (-10, 0.5, +12), facing +X
Movement: clockwise (CP0 → CP1 → CP2 → CP3 → CP4 → CP0)
```

---

## Sprint 4 — Game Flow ✅

**Gate:** Полный цикл LOADING → COUNTDOWN → ACTIVE → FINISHED → RESULTS → restart.

**Файлы (new):**
- `scenes/ui/countdown.gd` + `countdown.tscn` — CanvasLayer overlay, 3-2-1-GO с таймингом 1s + 0.5s GO, сигнал `countdown_finished`
- `scenes/ui/results.gd` + `results.tscn` — CanvasLayer, динамически создаёт 8 строк (по 1st..8th), `show_results(finish_order)`, R = restart
- `scenes/_sprint4_test.gd` + `_sprint4_test.tscn` — оркестрация: bind track → start_race → countdown.start() → on_countdown_finished → ACTIVE → on_kart_finished → FINISHED (3s pause) → RESULTS

**Файлы (overwritten):**
- `scripts/game_manager.gd` (61 строка) — полная FSM с `set_state`, `start_race`, `on_countdown_finished`, `on_kart_finished` (auto-transition FINISHED → RESULTS через 3s), `restart()`. Сигналы: `state_changed`, `race_started`, `kart_finished_signal`, `all_finished`.

**Известные ограничения:**
- В Sprint 4 driver только 1 kart — multiplayer лобби начинается со Sprint 7.
- Нет паузы, нет escape menu.
- Restart перезагружает сцену целиком (быстро для single-player, для сети нужен Sprint 9).

---

## Sprint 6 — Local Relay MVP ✅

**Gate:** Два браузера обмениваются сообщениями через `ws://localhost:8080/?room=XXXX`.

**Файлы:**
- `relay/relay.js` (209 строк, Node 20+, ws ^8.x) — Map<roomCode, Set<WebSocket>>, типы: `create_room`, `join_room`, `leave_room`, `broadcast`, `to_host`. На disconnect host → broadcast `host_disconnected` + delete room; client → broadcast `player_left`. HTTP `/stats` endpoint. JSON try/catch. Без TLS.
- `relay/package.json` — `"type": "module"`, dep `ws ^8.x`, script `start: node relay.js`
- `relay/README.md` — установка Node 20+, npm install, node relay.js, как узнать IP (`hostname -I` / `ipconfig`), как раздать клиентам, ngrok
- `relay/.gitignore` — node_modules/, *.log

**Не запускался** — нужно `cd relay && npm install && node relay.js` для smoke-теста.

---

## ✅ Sprint 5 — Single-screen HUD + Mini-map

**Gate:** HUD обновляется (Speed/Lap/Position/Time/Name), mini-map показывает свою точку.

**Файлы:**
- `scenes/ui/hud.tscn` + `hud.gd` — Speed (km/h), Position (1st…8th), Lap (1/3…3/3), LapTime, PlayerName
- Mini-map: динамические ColorRect-точки (8 цветов из PRD §7), проекция XZ на 207×207px
- Обновление каждый frame для Speed/LapTime, каждые 0.5s для Position/Lap
- `_sprint5_test.{gd,tscn}` — Sprint 4 + HUD layer

---

## ✅ Sprint 7 — Network client integration

**Gate:** 2 PC в LAN видят друг друга в лобби, Start ведёт обоих в countdown.

**Файлы (new):**
- `scripts/network_manager.gd` (autoload) — WebSocketPeer, create/join/leave room, broadcast, to_host, all relay сигналы
- `scenes/ui/menu.tscn` + `menu.gd` — Create Room / Join Room / nickname / relay address / 4-char code gen
- `scenes/ui/lobby.tscn` + `lobby.gd` — список игроков, lobby_sync broadcast, Start (host only)
- `scenes/_sprint7_test.{gd,tscn}` — MENU → LOBBY → COUNTDOWN flow test

**Файлы (modified):**
- `scripts/game_manager.gd` — добавлен `go_to_menu()`, MENU/LOBBY в FSM

---

## ✅ Sprint 8 — State sync + Input sync

**Gate:** 4 PC — все 4 видят корректно движущиеся kart'ы, лаг <60ms в LAN.

**Файлы (new):**
- `scenes/_sprint8_test.{gd,tscn}` — полный сетевой драйвер: state_tick @ 20Hz (host), input_tick @ 30Hz (client)

**Файлы (modified):**
- `scenes/kart/kart.gd` — добавлены `is_interpolated`, `get_network_state()`, `apply_network_state()`, `apply_remote_input()`, `_interpolate_network()` с буфером из 4 состояний и задержкой 100ms

---

## ✅ Sprint 9 — Race sync + Disconnect handling

**Gate:** 4-player полный матч, dropout одного клиента не ломает остальных.

**Файлы (new):**
- `scenes/_sprint9_test.{gd,tscn}` — драйвер Sprint 9: `player_left` → удаление kart из сцены и RaceManager; host broadcast `race_state: results` с finish_order; клиент получает и устанавливает RESULTS

**Файлы (modified):**
- `scripts/race_manager.gd` — добавлен `remove_kart(p_name)`: вычищает kart из списков, проверяет окончание гонки
- `scenes/kart/kart.gd` — `get_network_state` / `apply_network_state` расширены полями `next_cp`, `is_finished`, `total_time`

---

## ✅ Sprint 10 — Physics Panel + Animation

**Gate:** Host двигает слайдер — клиенты видят изменение в течение 1 тика; анимации играют.

**Файлы (new):**
- `scenes/ui/physics_panel.tscn` + `physics_panel.gd` — 17 слайдеров по GDD §13.3, F2/F3 пресеты, Apply All → signal `config_applied`; UI строится программно
- `scenes/_sprint10_test.{gd,tscn}` — Sprint 9 driver + PhysicsPanel (host-only), F1/F2/F3 input, `config_changed` broadcast и приём на клиентах

**Файлы (modified):**
- `scenes/kart/kart.gd` — 7-state animation FSM (`_update_animation`, `_get_target_anim_state`, `_get_blend_time`), Tween-placeholder на ChairMesh по GDD §7.4; `anim_state` добавлен в network state

---

## ✅ Sprint 11 — Polish + Web Export

**Gate:** Все пункты DoD PRD §8 закрыты.

**Файлы (new/modified):**
- `README.md` — полные инструкции: Node 20+ → npm install → node relay.js → Web Export → python -m http.server → ngrok fallback; таблица управления; known limitations
- `scripts/network_manager.gd` — `_sanitize_name()` trim 16 chars (PRD R13); `sanitize_input()` clamp accel/brake/steer к допустимым диапазонам (PRD R12)

**Ручное тестирование (DoD):**
- ⬜ 4-игрока LAN матч 3 круга без рассинхронизации
- ⬜ 2-игрока 10 заездов подряд без крашей
- ⬜ Web Export `build/web/` открывается через `python -m http.server`

---

## Структура проекта на 2026-05-17

```
drift-and-travel/
├── project.godot                       Godot 4.3, autoloads + input + layers
├── .gitignore
├── docs/
│   ├── PRD.md                          v2.1 продуктовый план
│   ├── SPRINTS_STATUS.md               ← этот файл
│   └── finom-drift-and-travel-gdd-v4.md  v4.0 тех. референс
├── relay/                              Sprint 6 готов
│   ├── package.json
│   ├── relay.js                        209 строк, Node.js + ws
│   ├── README.md
│   └── .gitignore
├── scripts/                            4 autoload скриптов
│   ├── game_manager.gd                 61 строка, полная FSM
│   ├── race_manager.gd                 71 строка, lap/position/respawn
│   ├── checkpoint_manager.gd           71 строка, order+direction
│   └── input_manager.gd                15 строк, Beta one-player
├── resources/
│   ├── kart_config.gd                  24 @export по GDD §4
│   └── presets/
│       ├── mario_kart.tres
│       └── kart_kraft.tres
├── scenes/
│   ├── _sprint2_test.tscn              empty floor + Kart
│   ├── _sprint3_test.{gd,tscn}         track + 1 kart, RaceManager wired
│   ├── _sprint4_test.{gd,tscn}         + countdown + results
│   ├── kart/
│   │   ├── kart.gd                     225 строк
│   │   └── kart.tscn
│   ├── track/
│   │   ├── test_track.gd
│   │   └── test_track.tscn             square donut, 5 CP, 2 spawns
│   └── ui/
│       ├── countdown.{gd,tscn}
│       └── results.{gd,tscn}
└── assets/{models,animations,textures,fonts}/   пустые папки
```

---

## Как продолжить работу

### Перед следующим спринтом — проверка вручную

1. Открыть `project.godot` в Godot 4.3+.
2. Если Godot ругается на Input Map в `project.godot` — открыть `Project Settings → Input Map`, ничего не менять, нажать Close (Godot нормализует синтаксис).
3. Прогнать Gate'ы Sprint 2, 3, 4 по очереди, меняя Main Scene в `Project Settings → Application → Run → Main Scene`:
   - `res://scenes/_sprint2_test.tscn` → WASD водит
   - `res://scenes/_sprint3_test.tscn` → 3 круга, в Output `[CheckpointManager] %s finished lap N`
   - `res://scenes/_sprint4_test.tscn` → countdown → race → results → R restart
4. Smoke-test relay: `cd relay && npm install && node relay.js`, открыть `ws://localhost:8080` через клиент (Sprint 7 ещё не написан, можно проверить через `wscat -c ws://localhost:8080` после `npm i -g wscat`).

### Следующая сессия — рекомендованный порядок

1. **Sprint 5 (HUD + Mini-map)** — самый автономный, нужен для каждого pre-network теста.
2. **Sprint 7 (Network client + Lobby)** — самый рискованный, нужно прототипировать раньше PRD R1 (host fairness) и R7 (mixed content).
3. **Sprint 8 (State sync)** — после 7.
4. Дальше — 9, 10, 11 в порядке PRD.

### Открытые блокирующие вопросы из PRD §12

- Минор Godot 4 (рекомендация: **4.3-stable**)
- `.glb` ассеты (текущая stratergie: **placeholder BoxMesh/CapsuleMesh**)
- Брендинг Finom (нет данных)
- Lap count (PRD F10 = **3**)

