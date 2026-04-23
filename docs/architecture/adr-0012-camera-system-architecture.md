# ADR-0012: Camera System Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Rendering |
| **Knowledge Risk** | LOW — Camera3D, lerp, FOV adjustment are core APIs unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Camera3D FOV interpolation smoothness on Web (HTML5) at 60fps |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (game state — camera behaviour changes per state), ADR-0010 (player controller — `get_position()` as follow target) |
| **Enables** | HUD/UI system (world-to-screen coordinate conversion) |
| **Blocks** | HUD/UI system implementation (needs `get_camera_position()`) |
| **Ordering Note** | ADR-0001 and ADR-0010 must be Accepted before implementation |

## Context

### Problem Statement

归宗 is a 3D action game with a fixed 3/4 top-down camera. The camera must follow the player smoothly, frame the arena so all enemies are visible, provide visual impact during 万剑归宗 (Myriad Swords), and freeze on death for the ink-wash effect. Without clear camera architecture, downstream systems (HUD coordinate conversion, hit feedback shake) cannot integrate consistently.

### Constraints

- Web (HTML5) target — camera operations must be lightweight (< 0.1ms/frame)
- No player camera control — fixed angle, auto-follow only
- Must integrate with ADR-0001 game state (freeze on DEATH, rotate on TITLE)
- Must expose position for HUD world-to-screen conversion
- Must support stacking effects (shake + FOV zoom simultaneously)

### Requirements

- TR-CAM-001: 3/4 top-down view at 45° downward tilt
- TR-CAM-002: 8.0m distance, lerp follow with factor 5.0
- TR-CAM-003: FOV effect 60° → 75° during 万剑归宗
- TR-CAM-004: Camera3D node with per-frame interpolation

## Decision

### Architecture

The camera is a `Camera3D` node managed by a `CameraController` script. It is NOT an Autoload — it lives in the main scene tree and is referenced by other systems via a group or node path. The controller implements a behaviour state machine driven by the game state (ADR-0001), with a separate effect stack for transient visual impacts.

### Scene Structure

```
CameraController (Node3D)
└── Camera3D
    ├── Position: offset from player at (0, 6.0, 8.0) rotated -45° on X
    └── FOV: 60° (default)
```

### Camera Position Model

The camera maintains a fixed offset from the follow target (player):
- **Height (Y)**: 6.0m — constant, never changes
- **Distance (Z)**: 8.0m from player in camera's local forward direction
- **Angle**: 45° downward tilt — fixed, no rotation except TITLE state

Follow formula (XZ only, Y fixed):
```gdscript
var target_pos = follow_target.global_position
target_pos.y = CAMERA_HEIGHT  # fixed
camera.global_position = camera.global_position.lerp(target_pos, follow_speed * delta)
camera.look_at(follow_target.global_position)
```

### Behaviour by Game State

| Game State | Camera Behaviour | Implementation |
|------------|-----------------|----------------|
| TITLE | Fixed position, slow orbit rotation | `rotate_y(orbit_speed * delta)` |
| COMBAT | Smooth lerp follow on XZ plane | `lerp(pos, player_pos, 5.0 * delta)` |
| INTERMISSION | Slight pull-back + slow orbit | Distance lerps to 10.0m, orbit active |
| DEATH | Completely frozen | Skip all update logic |
| RESTART | Instant snap to COMBAT position | `global_position = combat_position` |

State transitions are handled by listening to ADR-0001's `state_changed` signal.

### Effect System

Effects are implemented as a priority stack. Only one "major" effect (FOV zoom, freeze) is active at a time, but "minor" effects (shake) can overlay.

```gdscript
enum EffectType { NONE, FOV_ZOOM, SHAKE, HIT_STOP }

var active_effect: EffectType = EffectType.NONE
var effect_timer: float = 0.0
```

| Effect | Trigger | Behaviour | Duration | Priority |
|--------|---------|-----------|----------|----------|
| Hit Stop | `hit_landed` | Skip `_process` for 2 frames | 2 frames | Highest (freezes everything) |
| FOV Zoom | 万剑归宗 trigger | FOV lerp 60°→75° (expand), then 75°→60° (recover) | 2s expand + 1s recover | High |
| Shake | `take_damage` | Random offset ±0.1m on XZ | 0.1s | Low (can overlay) |

- Hit Stop: implemented by setting `Engine.time_scale = 0` for 2 frames, then restoring. This freezes ALL gameplay, not just camera.
- FOV Zoom: `camera.fov = lerp(camera.fov, target_fov, 2.0 * delta)`
- Shake: `camera.h_offset = randf_range(-0.1, 0.1)` each frame for 0.1s

### Public API

```gdscript
# Queries
func get_camera_position() -> Vector3
func get_camera_forward() -> Vector3

# Control
func set_follow_target(target: Node3D) -> void
func set_follow_speed(speed: float) -> void

# Effects
func trigger_effect(effect_name: StringName) -> void
func trigger_hit_stop(frames: int = 2) -> void
func trigger_fov_zoom(target_fov: float = 75.0, expand_time: float = 2.0, recover_time: float = 1.0) -> void
func trigger_shake(intensity: float = 0.1, duration: float = 0.1) -> void
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Game State (ADR-0001) | Listens `state_changed` — switches behaviour | Consumer |
| Player Controller (ADR-0010) | Reads `get_position()` for follow target | Consumer |
| HUD/UI | Calls `get_camera_position()`, uses `Camera3D.unproject_position()` | Consumer |
| Hit Feedback | Calls `trigger_shake()`, `trigger_hit_stop()` | Consumer |
| Combo System | Calls `trigger_fov_zoom()` on 万剑归宗 | Consumer |

## Alternatives Considered

### Alternative 1: RemoteTransform3D Follow
- **Description**: Use a RemoteTransform3D node parented to the player that copies its transform to the camera
- **Pros**: Zero code for basic follow; engine-optimized transform copy
- **Cons**: No smoothing (instant snap); adding lerp requires manual override anyway; RemoteTransform3D doesn't support XZ-only follow (copies Y too); can't easily freeze on DEATH
- **Rejection Reason**: The lerp and Y-fixed requirements make RemoteTransform3D unsuitable — code is needed regardless, and the code path is simpler without the node indirection.

### Alternative 2: SpringArm3D for Camera Collision
- **Description**: Use SpringArm3D to prevent camera from clipping through environment geometry
- **Pros**: Automatic collision avoidance; camera won't clip through arena walls
- **Cons**: Arena is a flat bounded area with no geometry above player — no collision risk. SpringArm3D adds raycast overhead every frame for a problem that doesn't exist.
- **Rejection Reason**: Over-engineering. The arena design has no overhead geometry. Add SpringArm3D only if future arena designs introduce walls or ceilings.

### Alternative 3: Camera as Autoload Singleton
- **Description**: Make CameraController an Autoload for global access
- **Pros**: Any system can call camera APIs without node path references
- **Cons**: Adds a 4th Autoload (exceeds 3-singleton guideline from control manifest); camera is a scene node, not a system — it should live in the scene tree; Autoload camera can't be easily replaced per-scene
- **Rejection Reason**: Violates Autoload minimization principle. Other systems access camera via group lookup or injected reference.

## Consequences

### Positive

- Simple architecture: one Camera3D, one script, one follow formula
- Effect stack allows independent shake + FOV zoom without complex state management
- Fixed angle eliminates camera control bugs (clipping, disorientation)
- `unproject_position()` integration gives HUD reliable world-to-screen conversion
- Hit stop via `Engine.time_scale = 0` freezes ALL gameplay consistently

### Negative

- `Engine.time_scale = 0` for hit stop freezes audio too — may need audio exemption workaround
- No camera collision avoidance — if future arenas add walls, camera may clip (acceptable for current scope)
- Fixed angle means players cannot see "above" enemies — tall enemies may be partially hidden (design constraint, not a bug)

### Risks

- **Hit stop audio artifact**: Setting `Engine.time_scale = 0` may cause audio popping on Web. Mitigation: test during prototype; if confirmed, use a separate `AudioServer` bus with independent time scale, or reduce to 1 frame instead of 2.
- **FOV zoom on Web**: Rapid FOV changes may cause visual artifacts on some WebGL implementations. Mitigation: clamp FOV delta per frame to max 2° change.
- **Shake randomness**: `randf_range` produces different results per frame, causing jittery feel. Mitigation: use a sine-wave based shake pattern for smoother motion.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| camera-system.md | 3/4 top-down 45° angle | Fixed Camera3D rotation at -45° X axis |
| camera-system.md | 8.0m distance, lerp factor 5.0 | `lerp(pos, target, 5.0 * delta)` with 8m offset |
| camera-system.md | FOV 60°→75° for 万剑归宗 | `trigger_fov_zoom()` with configurable target FOV |
| camera-system.md | Camera3D node, per-frame interpolation | Camera3D with lerp in `_physics_process` |

## Performance Implications

- **CPU**: lerp + look_at ≈ 0.02ms/frame (negligible)
- **Memory**: One Camera3D node + one script ≈ 1KB
- **Load Time**: < 1ms
- **Network**: N/A

## Validation Criteria

- Camera follows player within 0.5s of movement (measured: lerp convergence)
- All enemies visible during combat at 8m distance (requires arena size validation)
- FOV smoothly transitions 60°→75° in 2s during 万剑归宗
- FOV recovers 75°→60° in 1s after 万剑归宗
- Camera shakes ±0.1m for 0.1s on player hit
- Camera completely freezes during DEATH state
- Camera orbits slowly during TITLE state
- `get_camera_position()` returns accurate world coordinates for HUD conversion

## Related Decisions

- ADR-0001: Game State Architecture — camera behaviour per state
- ADR-0010: Player Controller Architecture — follow target source
- ADR-0003: Shader/Rendering — post-processing pass coordination
