# ADR-0014: Arena Wave Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core |
| **Knowledge Risk** | LOW — uses Timer nodes, signals, and Dictionary; no post-cutoff APIs |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Spawn queue correctness when 万剑归宗 kills all enemies in one frame |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (game state — `state_changed` signal for COMBAT/INTERMISSION), ADR-0007 (enemy AI — `spawn_enemy()`, `enemy_died` signal, `get_alive_count()`) |
| **Enables** | ADR-0017 (scoring system — needs `get_current_wave()` for wave record) |
| **Blocks** | Scoring system wave record, HUD wave display |
| **Ordering Note** | ADR-0007 must be Accepted before implementation; ADR-0007 is currently sparse — its `spawn_enemy()` and `enemy_died` APIs must be formalized |

## Context

### Problem Statement

归宗 is an infinite-wave arena game. Without a wave system, there is no difficulty progression, no spawn rhythm, and no "再来一波" motivation. The wave system is the heartbeat of the game loop — it determines when enemies appear, how many, what types, and how difficulty scales over time.

### Constraints

- Web (HTML5) target — wave calculation must be trivial (< 0.01ms/frame)
- Max 10 active enemies simultaneously (performance budget from ADR-0005)
- Must integrate with ADR-0001 state machine (COMBAT = run waves, INTERMISSION = pause, DEATH = stop)
- Must integrate with ADR-0007 enemy system for spawning and death detection
- Wave difficulty is infinite — no hard cap, but scaling factor must keep difficulty curve playable for at least 15 minutes
- Spawn queue: if active enemies = 10, new spawns must wait (not drop)

### Requirements

- TR-WAV-001: Wave scaling formula: `enemy_count = base_count + floor(wave_number * scaling_factor)`
- TR-WAV-002: Max active enemies = 10 (enforced by spawn queue)
- TR-WAV-003: Wave state signals: `wave_started`, `wave_completed`, `intermission_started`
- TR-WAV-004: INTERMISSION state interaction — intermission timer, optional auto-advance

## Decision

### Architecture

The wave system is a `Node3D` scene node (`WaveManager.tscn`) with a dedicated script (`wave_manager.gd`). It is NOT an Autoload — it lives in the main scene tree and is referenced by other systems via group lookup or injected reference. It owns wave progression logic, spawn scheduling, and difficulty scaling. Enemy spawning is delegated to ADR-0007's `spawn_enemy()` API.

### Wave Lifecycle

```
COMBAT entered
    │
    ▼
start_wave(N)
    │
    ├── calculate enemy_count from formula
    ├── build spawn queue: [{type, delay}, ...]
    ├── emit wave_started(N, enemy_count)
    │
    ▼
Spawning Loop (every frame):
    ├── if active_enemies < 10 AND queue not empty:
    │   └── spawn next enemy from queue
    └── if active_enemies >= 10:
        └── wait (queue holds)

    │
    ▼
All enemies dead (get_alive_count() == 0)
    │
    ├── emit wave_completed(N)
    ├── enter INTERMISSION (state_changed signal)
    │
    ▼
Intermission Timer (3.0s default)
    │
    ├── emit intermission_started(N)
    └── on timeout:
        └── request_state(COMBAT) → state_changed → start_wave(N+1)
```

### Wave Difficulty Formula

```
enemy_count = base_count + floor(wave_number * scaling_factor)
```

| Variable | Value | Range |
|----------|-------|-------|
| `base_count` | 2 | 1–3 |
| `scaling_factor` | 0.8 | 0.5–1.5 |
| `max_active_enemies` | 10 | 5–15 |

Example outputs:
- Wave 1: 2 + floor(1 × 0.8) = 2 enemies
- Wave 5: 2 + floor(5 × 0.8) = 6 enemies
- Wave 10: 2 + floor(10 × 0.8) = 10 enemies (= max_active, cap)
- Wave 20: 2 + floor(20 × 0.8) = 18 enemies (capped at 10 active, 8 queued)

### Enemy Type Introduction Schedule

| Wave | New Types Unlocked | Composition Rule |
|------|-------------------|------------------|
| 1 | 流动型 | 100% 流动型 |
| 2 | 松韧型 | 66% 流动, 33% 松韧 |
| 4 | 远程型 | 40% 流动, 30% 松韧, 30% 远程 |
| 6 | 重甲型 | Weighted random from all 4 |
| 8 | 敏捷型 | Weighted random from all 5 |

Enemy type selection uses weighted random from the unlocked pool. Weights are stored in a Dictionary for easy tuning:

```gdscript
var type_weights: Dictionary = {
    "liudong": 4.0,   # 流动型 — always available, common
    "songren": 3.0,   # 松韧型 — wave 2+
    "yuancheng": 2.0, # 远程型 — wave 4+
    "zhongjia": 1.5,  # 重甲型 — wave 6+
    "minjie": 1.0,    # 敏捷型 — wave 8+
}
```

### Spawn Queue

When `active_enemies >= max_active_enemies`, new spawns are queued:

```gdscript
var spawn_queue: Array = []  # [{type: String, position: Vector3}]

func _process_spawn_queue() -> void:
    while spawn_queue.size() > 0 and _get_active_count() < MAX_ACTIVE_ENEMIES:
        var entry = spawn_queue.pop_front()
        enemy_system.spawn_enemy(entry.type, entry.position)
```

Spawn positions are determined by the arena layout — random points on the arena boundary circle, at least 5m from the player. Position calculation is delegated to a utility function:

```gdscript
func _get_spawn_position() -> Vector3:
    var angle = randf_range(0, TAU)
    var radius = ARENA_RADIUS  # from arena config
    return Vector3(cos(angle) * radius, 0, sin(angle) * radius)
```

### State Integration

| Game State | Wave Behaviour |
|-----------|---------------|
| COMBAT | Active — spawning enemies, tracking kills |
| INTERMISSION | Paused — intermission timer running, no spawns |
| DEATH | Stopped — clear spawn queue, stop all timers |
| RESTART | Reset — wave_number = 1, clear queue, reset type unlocks |
| TITLE | Inactive — no wave logic |

Transition handling via ADR-0001's `state_changed(old, new)` signal:

```gdscript
func _on_state_changed(old_state: int, new_state: int) -> void:
    match new_state:
        State.COMBAT:
            if old_state == State.INTERMISSION:
                start_wave(current_wave + 1)
            elif old_state == State.RESTART:
                start_wave(1)
        State.DEATH:
            spawn_queue.clear()
            intermission_timer.stop()
        State.INTERMISSION:
            intermission_timer.start(INTERMISSION_DURATION)
```

### Public API

```gdscript
# Queries
func get_current_wave() -> int
func get_wave_progress() -> Vector2  # (kills, total_enemies)
func get_active_enemy_count() -> int
func get_spawn_queue_size() -> int

# Control
func start_wave(wave_number: int) -> void
func get_wave_data(wave_number: int) -> Dictionary  # {count, types, positions}
```

### Signals

```gdscript
signal wave_started(wave_number: int, enemy_count: int)
signal wave_completed(wave_number: int)
signal intermission_started(wave_number: int)
signal enemy_spawned(enemy_type: String, position: Vector3)
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Game State (ADR-0001) | Listens `state_changed` — triggers wave start/stop | Consumer |
| Enemy AI (ADR-0007) | Calls `spawn_enemy()`, listens `enemy_died`, queries `get_alive_count()` | Consumer |
| Scoring (ADR-0017) | Reads `get_current_wave()` for wave record | Consumer |
| HUD/UI (ADR-0015) | Reads `get_current_wave()`, `get_wave_progress()` for display | Consumer |
| Combo System (ADR-0009) | Indirect — combo resets between waves via game state |

## Alternatives Considered

### Alternative 1: Wave Data as External Resource Files
- **Description**: Each wave defined as a `.tres` Resource file with enemy list, positions, timing
- **Pros**: Level designers can edit waves without code; data-driven; easy to add "special waves"
- **Cons**: Over-engineered for procedural infinite waves — wave content is generated by formula, not hand-authored; Resource files for 100+ waves is file bloat; no designer exists yet to author wave files
- **Rejection Reason**: Infinite procedural waves don't benefit from hand-authored data. The formula + weighted random approach is sufficient for the current scope. Revisit if "boss waves" or "special events" are added later.

### Alternative 2: Wave System as Autoload Singleton
- **Description**: Make WaveManager a global Autoload for direct access
- **Pros**: Any system can query wave state without group lookup
- **Cons**: Adds a 4th Autoload (exceeds 3-singleton guideline); wave management is scene-specific logic — it should live in the scene tree; Autoload wave manager can't be replaced per-arena
- **Rejection Reason**: Violates Autoload minimization. HUD and scoring access wave state via `get_node("/root/Arena/WaveManager")` or group lookup.

### Alternative 3: Enemy System Owns Spawning
- **Description**: Remove WaveManager; enemy system spawns enemies on a timer, wave system only counts
- **Pros**: One less system; enemy system already knows how to spawn
- **Cons**: Blurs responsibility — enemy system would need wave difficulty data, type unlock schedule, spawn queue logic; coupling enemy AI with wave pacing makes both harder to tune
- **Rejection Reason**: Wave pacing (when to spawn, how many, which types) is a distinct concern from enemy behavior (how enemies act). Separation allows independent tuning.

## Consequences

### Positive

- Formula-based wave generation requires zero content authoring — infinite waves from math
- Spawn queue respects performance budget (max 10 active enemies) without dropping spawns
- Weighted random type selection ensures variety without rigid spawn patterns
- State integration via `state_changed` signal keeps wave logic decoupled from game state internals
- Wave number exposed via simple query API — scoring and HUD consume without coupling

### Negative

- Procedural wave generation may produce repetitive patterns at high wave numbers — no hand-crafted variety
- Spawn position uses random arena-edge points — no tactical spawn placement (e.g., flanking, ambush)
- Enemy type weights are fixed per wave-unlock — no adaptive difficulty based on player performance

### Risks

- **万剑归宗 instant-kill frame**: If all 10 enemies die in one frame (万剑归宗), `get_alive_count()` returns 0 and wave completes immediately. Mitigation: Godot processes signals sequentially — all `enemy_died` signals fire before the next `_process` frame, so the check is correct. Test during prototype.
- **Spawn queue starvation**: If player can't kill enemies fast enough, queued spawns never execute (active always = 10). Mitigation: this is intentional — it creates natural difficulty pressure. Player must clear enemies to allow reinforcements.
- **Scaling curve at high waves**: At wave 20+, formula produces 18 enemies but only 10 active. The queue fills faster than it drains, creating a constant stream. May feel overwhelming. Mitigation: reduce `scaling_factor` after wave 15 (diminishing returns curve).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| arena-wave-system.md | Wave scaling formula | `enemy_count = base_count + floor(wave * 0.8)` with cap at `max_active_enemies` |
| arena-wave-system.md | Max active enemies = 10 | Spawn queue enforced in `_process_spawn_queue()` |
| arena-wave-system.md | Wave state signals | `wave_started`, `wave_completed`, `intermission_started` signals |
| arena-wave-system.md | INTERMISSION interaction | Listens `state_changed` → INTERMISSION, starts intermission timer, auto-advances on timeout |

## Performance Implications

- **CPU**: Formula calculation + queue check ≈ 0.001ms/frame (negligible — integer math + array pop)
- **Memory**: Spawn queue max size = formula output - 10 (e.g., wave 20: 8 entries) ≈ 500 bytes
- **Load Time**: WaveManager scene < 1ms (Timer node + script, no assets)
- **Network**: N/A (single-player)

## Validation Criteria

- Wave 1 spawns exactly 2 流动型 enemies
- Wave 5 spawns exactly 6 enemies (2 + floor(5 × 0.8) = 6)
- When active enemies = 10, new spawns queue instead of executing
- When an enemy dies and active < 10, queued spawn executes
- `wave_completed` fires exactly once when all wave enemies are dead
- Intermission timer starts after wave completion
- After intermission timeout, wave N+1 starts automatically
- DEATH state clears spawn queue and stops intermission timer
- RESTART state resets wave to 1
- 万剑归宗 instant-kill completes the wave correctly (no stuck state)

## Related Decisions

- ADR-0001: Game State Architecture — state_changed signal for COMBAT/INTERMISSION/DEATH
- ADR-0007: Enemy AI Architecture — spawn_enemy(), enemy_died, get_alive_count()
- ADR-0017: Scoring System Architecture — wave record from get_current_wave()
- ADR-0015: HUD/UI Architecture — wave number display
