# ADR-0016: Level Scene Manager Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core |
| **Knowledge Risk** | LOW — PackedScene, change_scene_to_packed(), Node.add_child(), queue_free() are core APIs unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/scene-system.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | PackedScene memory footprint for 2 arena scenes on Web (HTML5); scene transition frame spike |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (game state — `state_changed` for RESTART/TITLE triggers) |
| **Enables** | ADR-0014 (arena wave — needs `get_spawn_points()` for enemy placement) |
| **Blocks** | Arena wave spawn position calculation |
| **Ordering Note** | ADR-0001 must be Accepted before implementation; ADR-0014 consumes this ADR's `get_spawn_points()` API |

## Context

### Problem Statement

归宗 has 2 arena areas (Mountain Stone / Water Bamboo) that must load quickly, reset cleanly on restart, and transition smoothly. Without a scene manager, each system would handle its own scene logic — leading to inconsistent loading behavior, memory leaks from unreleased scene instances, and no centralized spawn point management for the wave system.

### Constraints

- Web (HTML5) target — scene load/unload must complete within 5 seconds (network latency consideration)
- 2 arenas preloaded at startup (PackedScene resources in memory)
- Must integrate with ADR-0001 state machine (RESTART = reset current scene, TITLE = load title scene)
- Must provide spawn points to ADR-0014's wave system
- Scene switch must destroy all active enemies first (wave system coordination)
- Memory: 2 arena PackedScenes must fit within Web memory budget

### Requirements

- TR-LSM-001: 2 arenas as PackedScene resources (ArenaMountain.tscn, ArenaBamboo.tscn)
- TR-LSM-002: PackedScene preload at startup
- TR-LSM-004: Scene transition with fade in/out
- TR-LSM-005: Web memory release — old scene instance freed on switch

## Decision

### Architecture

The Level Scene Manager is a `Node` scene node (`SceneManager.tscn`) that owns scene lifecycle: loading, switching, resetting, and spawn point management. It is NOT an Autoload — it lives in the main scene tree. It preloads the 2 arena PackedScenes at startup and manages a single active scene instance at a time. Scene transitions use a fade-to-black pattern via a CanvasLayer overlay.

### Scene Structure

```
SceneManager (Node)
├── ActiveScene (Node3D) — current arena instance (child of this node)
├── FadeOverlay (CanvasLayer, layer=100)
│   └── FadeRect (ColorRect, full_rect, black)
└── scene_manager.gd (main script)
```

### Arena Resources

| Arena | Scene File | PackedScene Variable | Visual Style |
|-------|-----------|---------------------|--------------|
| Mountain Stone | `ArenaMountain.tscn` | `arena_mountain: PackedScene` | Sharp angles, axe-cut texture, dark ink base |
| Water Bamboo | `ArenaBamboo.tscn` | `arena_bamboo: PackedScene` | Soft curves, hemp-fiber texture, rice paper base |

Preload at startup:
```gdscript
const ARENA_SCENES: Dictionary = {
    "mountain": preload("res://scenes/arenas/ArenaMountain.tscn"),
    "bamboo": preload("res://scenes/arenas/ArenaBamboo.tscn"),
}
```

### Scene Lifecycle

```
Startup:
    preload 2 PackedScenes
    instantiate default arena → add as child of ActiveScene

change_scene("bamboo"):
    fade to black (0.3s)
    → queue_free() current ActiveScene child
    → clear all enemies (notify wave system)
    → instantiate ARENA_SCENES["bamboo"]
    → add as child of ActiveScene
    → emit scene_changed("bamboo")
    → fade from black (0.3s)

reset_scene():
    fade to black (0.3s)
    → queue_free() current ActiveScene child
    → instantiate same PackedScene
    → add as child of ActiveScene
    → emit scene_changed(current_scene_name)
    → fade from black (0.3s)

DEATH → TITLE:
    → queue_free() arena
    → load title scene (separate PackedScene)
```

### Scene Transition Fade

```gdscript
func _fade_to_black(duration: float = 0.3) -> void:
    fade_rect.visible = true
    var tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, duration)
    await tween.finished

func _fade_from_black(duration: float = 0.3) -> void:
    var tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, duration)
    await tween.finished
    fade_rect.visible = false
```

### Spawn Point Management

Each arena scene contains Marker3D nodes named "SpawnPoint_0" through "SpawnPoint_N". The scene manager collects them and exposes via API:

```gdscript
func get_spawn_points() -> Array[Vector3]:
    var points: Array[Vector3] = []
    for child in active_scene.get_children():
        if child.name.begins_with("SpawnPoint_"):
            points.append(child.global_position)
    return points
```

This replaces the random arena-edge calculation in ADR-0014 — spawn positions are now designer-placed per arena.

### Memory Management

On scene switch, the old scene instance is freed:
```gdscript
func _clear_active_scene() -> void:
    if active_scene != null:
        for child in active_scene.get_children():
            child.queue_free()
        active_scene.queue_free()
        active_scene = null
```

PackedScenes remain in memory (preloaded constants). Only instances are freed. On Web, `queue_free()` returns memory to the JS heap on the next GC cycle.

### State Integration

| Game State | Scene Behaviour |
|-----------|----------------|
| TITLE | Load title scene (separate from arenas) |
| COMBAT | Active arena loaded, spawn points available |
| INTERMISSION | Arena remains loaded (no scene change) |
| DEATH | Arena remains loaded (frozen), menu overlay on top |
| RESTART | `reset_scene()` — destroy + reinstantiate current arena |

Transition handling via ADR-0001's `state_changed(old, new)` signal:

```gdscript
func _on_state_changed(old_state: int, new_state: int) -> void:
    match new_state:
        State.RESTART:
            reset_scene()
        State.TITLE:
            _load_title_scene()
```

### Error Handling

| Error | Response |
|-------|----------|
| PackedScene load fails (Web network) | Fall back to default arena (mountain); log error |
| `reset_scene()` fails | Transition to TITLE state as fallback |
| Scene switch with active enemies | Notify wave system to `kill_all()` before switching |
| Spawn points missing in scene | Return empty array; wave system falls back to random positions |

### Public API

```gdscript
# Scene control
func change_scene(scene_name: String) -> void
func reset_scene() -> void
func get_current_scene() -> String

# Spawn points
func get_spawn_points() -> Array[Vector3]

# State queries
func is_scene_loaded() -> bool
func get_arena_bounds() -> AABB
```

### Signals

```gdscript
signal scene_changed(scene_name: String)
signal scene_load_started(scene_name: String)
signal scene_load_failed(scene_name: String)
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Game State (ADR-0001) | Listens `state_changed` — triggers scene reset/load | Consumer |
| Arena Wave (ADR-0014) | Provides `get_spawn_points()` for enemy placement | Provider |
| Enemy System (ADR-0007) | Calls `kill_all()` before scene switch | Consumer |
| HUD/UI (ADR-0015) | Notifies scene change for UI update | Provider |

## Alternatives Considered

### Alternative 1: Godot's Built-in SceneTree.change_scene_to_packed()
- **Description**: Use `get_tree().change_scene_to_packed()` instead of manual scene management
- **Pros**: Engine handles loading, transition, and memory management
- **Cons**: `change_scene_to_packed()` replaces the entire scene tree — destroys HUD, camera, and all Autoloads' scene references; no fade control; can't keep scene manager alive across transitions
- **Rejection Reason**: The built-in API replaces the root scene, destroying the scene manager itself. Manual instantiation under a persistent parent node preserves all system references.

### Alternative 2: Scene Manager as Autoload
- **Description**: Make SceneManager an Autoload for global scene access
- **Pros**: Any system can call `SceneManager.change_scene()` directly
- **Cons**: Adds a 4th Autoload (exceeds 3-singleton guideline); scene management is scene-specific — it should live in the scene tree; Autoload scene manager complicates testing
- **Rejection Reason**: Violates Autoload minimization. Systems that need scene state use group lookup or injected reference.

### Alternative 3: ResourceLoader Threaded Loading
- **Description**: Use `ResourceLoader.load_threaded_request()` for async scene loading
- **Pros**: No frame spike during load; loading screen possible
- **Cons**: 2 arenas preloaded at startup — no runtime loading needed; threaded loading API adds complexity for zero benefit with only 2 small scenes; Web threaded loading requires SharedArrayBuffer (COOP/COEP headers)
- **Rejection Reason**: Over-engineered for 2 preloaded scenes. Revisit if arena count exceeds 5 or scene size exceeds 10MB.

## Consequences

### Positive

- Preloaded PackedScenes guarantee instant instantiation — no load-time spike during gameplay
- Single active scene instance at a time — simple memory model, clean `queue_free()` lifecycle
- Designer-placed spawn points give precise control over enemy positioning per arena
- Fade transition hides frame spike from `queue_free()` + `add_child()` sequence
- Scene manager as scene node preserves all system references during transitions

### Negative

- 2 PackedScenes permanently in memory (~5-15MB each estimated) — can't unload unused arena
- Fade-to-black is simple but not as visually rich as ink-wash dissolve transition
- `queue_free()` on Web triggers GC cycle — potential micro-stutter (mitigated by fade overlay hiding it)
- No async loading — if arenas grow large, startup load time increases linearly

### Risks

- **Memory pressure on Web**: 2 large PackedScenes in memory simultaneously. Mitigation: keep arena geometry simple (< 5K triangles each); monitor Web memory via devtools during prototype.
- **queue_free() frame spike**: Freeing a scene with many nodes can spike for 1-2 frames. Mitigation: fade-to-black overlay hides the spike; if persistent, spread `queue_free()` across frames.
- **Missing spawn points**: If arena scene lacks SpawnPoint markers, wave system has no spawn positions. Mitigation: validation check in `_ready()` warns if spawn points are missing; wave system falls back to random edge positions.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| level-scene-manager.md | 2 arenas as PackedScene | Preloaded constants: `arena_mountain`, `arena_bamboo` |
| level-scene-manager.md | PackedScene preload | `const ARENA_SCENES` dictionary with `preload()` at startup |
| level-scene-manager.md | Scene transition fade | CanvasLayer fade overlay, 0.3s tween to/from black |
| level-scene-manager.md | Web memory release | `queue_free()` on scene switch; PackedScenes stay preloaded |

## Performance Implications

- **CPU**: `queue_free()` + `add_child()` ≈ 2-5ms (one-time during transition, hidden by fade)
- **Memory**: 2 PackedScenes ≈ 10-30MB total (estimated; must verify during prototype)
- **Draw Calls**: Fade overlay = 1 additional draw call during transition only
- **Load Time**: Preload at startup adds 0.5-2s to initial load (Web network dependent)

## Validation Criteria

- Default arena (mountain) loads on startup within 2 seconds on Web
- `change_scene("bamboo")` transitions with fade, loads bamboo arena, emits `scene_changed`
- `reset_scene()` destroys and reinstantiates current arena
- `get_spawn_points()` returns correct Vector3 positions from scene Marker3D nodes
- DEATH state keeps arena loaded (frozen)
- RESTART state triggers `reset_scene()` via state_changed signal
- Memory does not grow after 10 scene switches (no leak from unreleased instances)
- Fade overlay hides any frame spike during scene transition

## Related Decisions

- ADR-0001: Game State Architecture — `state_changed` for RESTART/TITLE scene triggers
- ADR-0007: Enemy AI Architecture — `kill_all()` before scene switch
- ADR-0014: Arena Wave Architecture — `get_spawn_points()` for enemy spawn positions
