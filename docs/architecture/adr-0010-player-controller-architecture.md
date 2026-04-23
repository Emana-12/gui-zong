# ADR-0010: Player Controller Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core (Physics + Input) |
| **Knowledge Risk** | LOW — uses high-level CharacterBody3D API, unchanged across Jolt/GodotPhysics |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — CharacterBody3D, move_and_slide(), Input action system are all pre-cutoff |
| **Verification Required** | Jolt high-speed collision: verify dodge (15m/s) does not penetrate thin Environment colliders on Web |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (game state — must be Accepted; player listens to `state_changed` signal), ADR-0002 (input system — must be Accepted; player consumes InputSystem API), ADR-0005 (physics collision — must be Accepted; player CollisionShape3D uses layer matrix) |
| **Enables** | ADR-0006 (three-forms combat — player must exist before attacks attach), ADR-0007 (enemy system — enemies need player position for approach), ADR-0009 (combo system — combo counter resets on player hit) |
| **Blocks** | Core loop prototype cannot be built until this ADR is Accepted |
| **Ordering Note** | Foundation layer ADRs (0001, 0002, 0005) must be Accepted before implementation begins |

## Context

### Problem Statement

归宗 is a 3D action roguelite where the player controls a sword-wielding character from a 3/4 top-down camera angle, fighting waves of enemies in a bounded arena. The player controller is the most foundational gameplay system — every combat mechanic, camera behaviour, and UI element depends on it. Without a clear architectural decision on state management, movement model, and health system, downstream systems cannot be built consistently.

### Constraints

- Web (HTML5) target — every per-frame operation must fit within 16.6ms total frame budget
- CharacterBody3D is the only acceptable physics body (no RigidBody3D or custom integration)
- Must integrate with ADR-0001 game state machine (player freezes on non-COMBAT states)
- Must consume input from ADR-0002 InputSystem (never read `Input` directly)
- Collision layers per ADR-0005 (Player = Layer 1)
- No GDExtension — GDScript only for Web compatibility

### Requirements

- TR-PLR-001: CharacterBody3D with constant speed 5.0m/s, no acceleration curve
- TR-PLR-002: Dodge 3.0m distance in 0.2s, 0.15s invincibility, 0.5s cooldown
- TR-PLR-003: HP = 3, 1 damage per hit, 0.5s hit stun with invincibility, no recovery
- TR-PLR-004: Auto-face nearest enemy instantly (no slerp), updated every frame
- TR-PLR-006: All movement and dodge calculations per-frame, Web-platform safe

## Decision

### Architecture

The player controller is a single `CharacterBody3D` scene (`PlayerController.tscn`) with a dedicated GDScript (`player_controller.gd`) implementing a 6-state finite state machine. It consumes input from the `InputSystem` Autoload, exposes a read-only health interface, and communicates state changes via Godot signals.

### State Machine

```
enum State { IDLE, MOVING, DODGING, DODGE_COOLDOWN, HIT_STUN, DEAD }

IDLE ──[move_input]──→ MOVING
MOVING ──[no_input]──→ IDLE
IDLE/MOVING ──[dodge_pressed]──→ DODGING
DODGING ──[0.2s elapsed]──→ DODGE_COOLDOWN
DODGE_COOLDOWN ──[0.5s elapsed]──→ IDLE
IDLE/MOVING/DODGE_COOLDOWN ──[damage_taken]──→ HIT_STUN
HIT_STUN ──[0.5s elapsed]──→ IDLE
ANY ──[hp ≤ 0]──→ DEAD
```

- State stored as `var current_state: State = State.IDLE`
- Transitions validated in `_physics_process(delta)` via `match` statement
- EXECUTING is never interruptible — dodge must complete its full 0.2s before any state change (except death)

### Movement Model

- `velocity` is set directly on the CharacterBody3D, then `move_and_slide()` is called
- Normal movement: `velocity = input_direction * MOVE_SPEED` (5.0 m/s, constant)
- Dodge: `velocity = dodge_direction * DODGE_SPEED` (15.0 m/s, constant, 0.2s = 3.0m travel)
- DODGE_COOLDOWN and HIT_STUN: player can still move at normal speed (input accepted) but cannot dodge
- DEAD: velocity zeroed, input ignored

### Health System

- `var health: int = 3` (private, read-only from outside)
- `var max_health: int = 3` (const)
- `take_damage(amount: int)` — decrements health, triggers HIT_STUN + invincibility frames, emits `health_changed`
- `heal(amount: int)` — increments health up to max_health, emits `health_changed` (reserved for future systems)
- Invincibility tracked by `var invincible: bool` with a Timer node
- On health ≤ 0: transition to DEAD, emit `player_died`

### Dodge Tracking

- `var dodge_attempts: int = 0` — incremented on every dodge start (DODGING entry)
- `var dodge_successes: int = 0` — incremented when dodge completes without taking damage (DODGE_COOLDOWN entry, not HIT_STUN)
- `get_dodge_success_rate() -> float` returns `dodge_successes / dodge_attempts`, or `0.0` if `dodge_attempts == 0`
- Used by ADR-0018 (Skill Progression) to track player skill improvement over runs

### Auto-Face Nearest Enemy

- Every frame in `_physics_process`, query all nodes in "enemies" group
- Find nearest by `global_position.distance_squared_to()` (no sqrt, faster)
- Set `look_at()` toward nearest enemy (instant, no interpolation)
- If no enemies exist: maintain last facing direction

### Public API

```gdscript
# Read-only queries
func get_position() -> Vector3
func get_velocity() -> Vector3
func get_health() -> int
func get_max_health() -> int
func is_invincible() -> bool
func is_dodging() -> bool
func get_dodge_success_rate() -> float  # 成功闪避次数 / 总闪避尝试次数, 无闪避时返回 0.0

# State modification (called by HitJudgment system)
func take_damage(amount: int) -> void
func heal(amount: int) -> void
```

### Signals

```gdscript
signal player_died
signal health_changed(new_health: int, max_health: int)
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| InputSystem (ADR-0002) | `InputSystem.get_move_direction()`, `InputSystem.is_action_just_pressed("dodge")` | Consumer |
| GameStateManager (ADR-0001) | Listens `state_changed(old, new)`, freezes on non-COMBAT | Consumer |
| Physics (ADR-0005) | CollisionShape3D on Layer 1 (Player), detects Layer 5 (Environment) | Consumer |
| Camera System | Reads `get_position()` for follow target | Consumer |
| HitJudgment | Calls `take_damage()` | Provider |
| HUD | Reads `get_health()`, listens `health_changed` | Consumer |
| Enemy System | Reads `get_position()` for approach targeting | Consumer |

### Scene Structure

```
PlayerController (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D)
├── MeshInstance3D (placeholder capsule)
├── DodgeTimer (Timer, one_shot, 0.2s)
├── CooldownTimer (Timer, one_shot, 0.5s)
├── HitStunTimer (Timer, one_shot, 0.5s)
├── InvincibleTimer (Timer, one_shot, 0.65s = 0.5s stun + 0.15s buffer)
└── Hurtbox (Area3D) [managed by ADR-0005 hitbox system]
    └── CollisionShape3D (slightly larger than body)
```

## Alternatives Considered

### Alternative 1: Component-Based Architecture
- **Description**: Split player into separate components (MovementComponent, HealthComponent, InputComponent) composed onto a root node
- **Pros**: Better separation of concerns, reusable components for enemies
- **Cons**: Over-engineered for a single-player arena game with 1 player entity; component communication adds signal overhead; harder to reason about state machine transitions across components
- **Rejection Reason**: Violates "极简即美学" design pillar. A single script with a clear state machine is simpler and sufficient for the project's scope.

### Alternative 2: AnimationTree-Driven State Machine
- **Description**: Use Godot's AnimationTree state machine to drive gameplay states, with animation callbacks triggering state transitions
- **Pros**: Visual state machine editor in Godot; animation and gameplay states are always synchronized
- **Cons**: Couples gameplay logic to animation assets (which don't exist yet); AnimationTree overhead for 6 simple states; harder to debug pure logic issues; Web performance of AnimationTree is uncertain
- **Rejection Reason**: Premature coupling to animation pipeline. States are purely logical with fixed durations (0.2s, 0.5s) — no animation blending needed.

### Alternative 3: Separate Dodge Mechanic as Child Node
- **Description**: Implement dodge as a separate child node (DodgeHandler) that temporarily takes over velocity
- **Pros**: Isolates dodge logic; could be reused for enemy dodge abilities
- **Cons**: Adds node hierarchy complexity; dodge and movement share the same velocity property — splitting them requires a mediator; no enemies currently dodge
- **Rejection Reason**: No reuse case exists. The dodge logic (10 lines of velocity override + timer) does not justify a separate node.

## Consequences

### Positive

- Single source of truth for player state — all systems query one node
- State machine is trivially debuggable (one match statement, one enum)
- Read-only health interface prevents accidental modification by downstream systems
- Signal-based communication allows loose coupling with HUD, enemies, and combat systems
- Constant speed eliminates acceleration tuning complexity

### Negative

- Auto-face nearest enemy scans all enemies every frame — O(n) per frame where n = active enemies (< 10 per ADR-0005, acceptable)
- No component reuse — enemy controllers must implement their own movement (acceptable since enemy behaviour differs significantly per ADR-0007)
- Single state enum means all states are mutually exclusive — cannot be in HIT_STUN while DODGING (intentional design)

### Risks

- **Dodge wall penetration**: At 15m/s, Jolt may allow CharacterBody3D to penetrate thin Environment colliders during the 0.2s dodge. Mitigation: test during prototype; if confirmed, use ShapeCast3D pre-check before dodge or cap collision shape thickness to 0.3m minimum.
- **Enemy scan performance**: If enemy count grows beyond 10 (future content), the per-frame nearest-enemy scan becomes noticeable. Mitigation: cache result for 0.1s (6 frames) instead of every frame; or use a spatial hash.
- **Web timer precision**: Godot Timer nodes on Web may have ±1 frame jitter. Mitigation: use accumulated delta in _physics_process for state transition timing (Timer nodes as backup only).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| player-controller.md | CharacterBody3D, constant 5.0m/s speed | Direct implementation: velocity = direction * 5.0, move_and_slide() |
| player-controller.md | Dodge 3.0m in 0.2s, invincible 0.15s, cooldown 0.5s | DodgeTimer (0.2s) → CooldownTimer (0.5s), InvincibleTimer covers stun+buffer |
| player-controller.md | HP=3, 1 dmg/hit, 0.5s hit stun, no recovery | Health variable + take_damage() + HitStunTimer, heal() reserved |
| player-controller.md | Auto-face nearest enemy, instant | Per-frame distance_squared_to scan + look_at, no interpolation |
| player-controller.md | Web platform per-frame calculation | All logic in _physics_process, no async/threads, constant-time operations |
| player-controller.md | `get_dodge_success_rate()` for skill tracking | DodgeTracking section: dodge_attempts/successes counters, rate API |

## Performance Implications

- **CPU**: State machine match + move_and_slide + nearest-enemy scan ≈ 0.1ms/frame (well within budget)
- **Memory**: Single CharacterBody3D node tree ≈ 2KB (negligible)
- **Load Time**: Scene preload < 1ms (simple geometry, no external assets)
- **Network**: N/A (single-player, local only)

## Validation Criteria

- Player moves at exactly 5.0m/s in all 4 cardinal directions (measured with debug overlay)
- Dodge travels exactly 3.0m (distance between start and end position)
- Player cannot take damage during 0.65s invincibility window (0.5s stun + 0.15s buffer)
- Player cannot dodge during DODGE_COOLDOWN
- Player can move during DODGE_COOLDOWN and HIT_STUN
- Player faces nearest enemy within 1 frame of enemy position change
- On health reaching 0, player_died signal fires exactly once
- System freezes when GameStateManager transitions to non-COMBAT state

## Related Decisions

- ADR-0001: Game State Architecture — player must listen to state_changed
- ADR-0002: Input System Architecture — player consumes InputSystem API
- ADR-0005: Physics Collision Architecture — player CollisionShape3D uses layer matrix
- ADR-0006: Three-Forms Combat — attacks attach to player node
- ADR-0007: Enemy System — enemies target player position
