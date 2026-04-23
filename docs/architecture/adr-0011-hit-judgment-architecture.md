# ADR-0011: Hit Judgment Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core |
| **Knowledge Risk** | LOW — uses only Area3D signals and Dictionary, no post-cutoff APIs |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Area3D `area_entered` signal reliability with Jolt at high overlap counts |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (physics collision — collision layer matrix and hitbox pooling), ADR-0010 (player controller — `is_invincible()` and `take_damage()` API) |
| **Enables** | ADR-0006 (three-forms combat — needs damage calculation), ADR-0009 (combo system — needs `hit_landed` signal) |
| **Blocks** | Hit feedback system, combo/万剑归宗 system implementation |
| **Ordering Note** | ADR-0005 and ADR-0010 must be Accepted before implementation |

## Context

### Problem Statement

The physics collision layer (ADR-0005) answers "what touched what" but not "does this count as a hit." The hit judgment layer bridges physics to game rules: it filters collisions through invincibility checks, deduplication, sword form identification, and damage calculation before emitting a clean `hit_landed` signal that downstream systems (combo, feedback, enemies, HUD) consume.

### Constraints

- Must integrate with ADR-0005's `collision_detected` signal and hitbox ID system
- Must check player invincibility via ADR-0010's `is_invincible()` interface
- Must support 4 attack types: you (游), zuan (钻), rao (绕), none (enemy attack)
- Hit deduplication must work per-hitbox per-target within hitbox lifetime
- Web performance: processing all collisions must take < 0.5ms/frame

### Requirements

- TR-HIT-001: HitResult data structure with attacker, target, sword_form, damage, hit_position, hit_normal, material_type
- TR-HIT-002: Damage values: you=1, zuan=3, rao=2, enemy=1
- TR-HIT-004: Hit position and normal passed through for material reaction system
- TR-HIT-005: `hit_landed` signal broadcast to all interested systems

## Decision

### Architecture

Hit Judgment is a single Autoload singleton (`HitJudgment`) that listens to the physics collision layer's `collision_detected` signal. For each collision, it runs a 4-step filter pipeline:

```
collision_detected → invincibility check → dedup check → damage calc → hit_landed signal
```

### HitResult Data Structure

```gdscript
class HitResult:
    var attacker: Node3D
    var target: Node3D
    var sword_form: String  # "you", "zuan", "rao", "none"
    var damage: int
    var hit_position: Vector3
    var hit_normal: Vector3
    var material_type: String  # "metal", "wood", "ink", "body"
```

Stored as a GDScript class (not Resource) for performance — no serialization overhead.

### Filter Pipeline

1. **Invincibility check**: Query `target.is_invincible()` (ADR-0010 API). If true → discard.
2. **Self-hit check**: If `attacker == target` → discard.
3. **Dedup check**: Each hitbox maintains a `Dictionary` mapping `target_id → bool`. If target already registered → discard.
4. **Damage calculation**: `base_damage * sword_form_multiplier` (default multiplier = 1.0).

### Damage Table

| Sword Form | Base Damage | Multiplier Range | Final Range |
|------------|-------------|-----------------|-------------|
| you (游剑式) | 1 | 0.5–2.0 | 1–2 |
| zuan (钻剑式) | 3 | 0.5–2.0 | 2–6 |
| rao (绕剑式) | 2 | 0.5–2.0 | 1–4 |
| none (enemy) | 1 | 1.0 (fixed) | 1 |

### Hit Deduplication

- Each hitbox (from ADR-0005's pool) carries a `Dictionary` field: `var already_hit: Dictionary = {}`
- On successful hit: `already_hit[target.get_instance_id()] = true`
- On hitbox destruction (returned to pool): `already_hit.clear()`
- This prevents rotating attacks from dealing damage every physics frame

### Public API

```gdscript
# Processing
func process_collision(attacker: Node3D, target: Node3D, hitbox_id: int,
                       collision_point: Vector3, collision_normal: Vector3,
                       sword_form: String) -> HitResult

# Queries
func get_last_hit() -> HitResult
func calculate_damage(sword_form: String, target: Node3D) -> int

# Dedup (called by hitbox owner after hit)
func register_hit(hitbox_id: int, target_id: int) -> void
func is_already_hit(hitbox_id: int, target_id: int) -> bool
```

### Signals

```gdscript
signal hit_landed(result: HitResult)
signal hit_blocked(result: HitResult)  # target was invincible — for audio feedback
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Physics (ADR-0005) | Listens `collision_detected(attacker, target, hitbox_id, point, normal)` | Consumer |
| Player Controller (ADR-0010) | Queries `target.is_invincible()`, calls `target.take_damage()` | Consumer |
| Three-Forms Combat (ADR-0006) | Provides sword_form identification per hitbox | Consumer |
| Combo System (ADR-0009) | Emits `hit_landed` — combo counter increments | Provider |
| Hit Feedback | Emits `hit_landed` — triggers material reaction | Provider |
| Enemy System | Emits `hit_landed` — enemy health decrements | Provider |
| HUD | Emits `hit_landed` — damage number display | Provider |

### Material Type Detection

Material type is determined by the target's node group membership:
- `"body"` — nodes in "enemies" or "player" group
- `"metal"` — nodes in "environment_metal" group
- `"wood"` — nodes in "environment_wood" group
- `"ink"` — nodes in "environment_ink" group (shanshui decorations)

This avoids hardcoding material types in hit judgment — targets declare their own material.

## Alternatives Considered

### Alternative 1: Hit Judgment as Component per Entity
- **Description**: Each entity (player, enemy) has its own HitJudgmentComponent that processes collisions locally
- **Pros**: Decentralized, no singleton, each entity handles its own logic
- **Cons**: Damage calculation rules duplicated across components; dedup logic must be shared or reimplemented; no central point for analytics or balance tuning
- **Rejection Reason**: Violates single data ownership principle. Damage rules must be centralized to prevent inconsistencies between player and enemy damage calculation.

### Alternative 2: Signal-Only (No Processing Method)
- **Description**: Hit Judgment only emits signals, never processes collisions — each system does its own filtering
- **Pros**: Maximum decoupling, each system owns its filter logic
- **Cons**: Invincibility check duplicated in every consumer; dedup impossible without central state; damage formula scattered across systems
- **Rejection Reason**: Creates N copies of the invincibility check and damage formula. One wrong copy = exploitable bug.

### Alternative 3: Resource-Based HitResult
- **Description**: Use Godot Resource subclass for HitResult instead of plain class
- **Pros**: Inspector-visible, serializable, can be saved as .tres files
- **Cons**: Resource creation overhead per hit (allocation + refcount); hit results are ephemeral (never serialized); inspector visibility not needed at runtime
- **Rejection Reason**: Unnecessary overhead for a per-frame ephemeral data structure.

## Consequences

### Positive

- Single source of truth for damage calculation — balance tuning changes one function
- Dedup mechanism prevents exploit where spinning attacks hit every frame
- `hit_landed` signal allows any system to react without coupling to hit judgment internals
- Material type detection via groups keeps hit judgment decoupled from art/content pipeline
- `hit_blocked` signal enables audio feedback on invincibility (player hears "tink" on dodge)

### Negative

- HitJudgment is an Autoload singleton — adds to global namespace (acceptable: only GameStateManager and InputSystem are other Autoloads, within the 3-singleton limit)
- Dictionary-based dedup uses node instance IDs — if node is freed and re-allocated with same ID within one frame, false dedup could occur (extremely unlikely in practice)
- Material type via groups requires content creators to assign correct groups (editor workflow constraint)

### Risks

- **Dedup Dictionary growth**: If hitboxes are never returned to pool, `already_hit` grows unbounded. Mitigation: ADR-0005's hitbox pooling clears dictionaries on return.
- **Frame-perfect double hits**: If two Area3D overlaps fire in the same physics frame, both may pass dedup before either registers. Mitigation: process collisions sequentially within a single frame (Godot processes signals sequentially by default).
- **Material group misassignment**: Level designers may forget to assign groups, defaulting to no material type. Mitigation: HitJudgment defaults to `"body"` if no material group is found.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| hit-judgment.md | HitResult data structure with 7 fields | `HitResult` class with all required fields |
| hit-judgment.md | Damage: you=1, zuan=3, rao=2, enemy=1 | Damage table + `calculate_damage()` with configurable multipliers |
| hit-judgment.md | Hit position + normal for material reaction | Collision point/normal passed through from ADR-0005 |
| hit-judgment.md | `hit_landed` signal broadcast | Typed signal with HitResult parameter |

## Performance Implications

- **CPU**: 4-step filter pipeline ≈ 0.01ms per collision (Dictionary lookup + 2 method calls). At max 18 hitboxes × 2 targets = 36 checks/frame ≈ 0.36ms. Within budget.
- **Memory**: HitResult instances are short-lived (created per hit, consumed same frame). ~200 bytes each. At max 18 simultaneous hits = 3.6KB peak.
- **Load Time**: Autoload registration < 1ms.
- **Network**: N/A (single-player).

## Validation Criteria

- Collision with invincible target returns null (no HitResult emitted)
- Same hitbox hitting same target twice returns null on second hit
- you form deals 1 damage, zuan deals 3, rao deals 2
- hit_landed signal contains correct HitResult with all 7 fields
- Self-hit collision returns null
- hit_blocked signal fires when invincible target is hit
- Material type detected correctly from node groups

## Related Decisions

- ADR-0005: Physics Collision Architecture — source of collision_detected signal
- ADR-0010: Player Controller Architecture — is_invincible() and take_damage() APIs
- ADR-0006: Three-Forms Combat — sword_form identification per hitbox
- ADR-0009: Combo System — consumes hit_landed signal
