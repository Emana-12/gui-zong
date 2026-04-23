# ADR-0013: Hit Feedback Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Rendering / Presentation |
| **Knowledge Risk** | LOW — Sprite3D, Decal, Tween, Engine.time_scale are core APIs unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Sprite3D draw call batching on Web (HTML5) at 60fps with 10 simultaneous particles |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0011 (hit judgment — `hit_landed` signal source), ADR-0012 (camera — `trigger_hit_stop()` and `trigger_shake()` APIs), ADR-0004 (audio — `play_sfx()` API) |
| **Enables** | HUD damage number display (feedback confirms hit to player) |
| **Blocks** | Hit feedback implementation cannot begin until ADR-0011, ADR-0012, ADR-0004 are Accepted |
| **Ordering Note** | ADR-0009 (combo system) must be Accepted for `myriad_triggered` signal; otherwise myriad feedback is deferred |

## Context

### Problem Statement

命中判定层 (ADR-0011) 产出 `hit_landed` 信号，但信号本身不产生任何感官体验。玩家需要"打中了"的身体确认——顿帧、震动、材质反应（火花/裂纹/墨点炸碎）。命中反馈系统将逻辑命中转化为即时感官体验，是"打击感"的核心载体。没有它，精确打击就是无声的精准。

### Constraints

- Web (HTML5) target — material reaction spawning must stay within draw call budget (< 50/frame total)
- Must integrate with ADR-0011's `hit_landed(HitResult)` signal
- Must delegate hit stop and shake to ADR-0012's camera API (not implement them directly)
- Must delegate audio to ADR-0004's `play_sfx()` API
- Hit stop queueing: if a hit arrives during active hit stop, it queues and executes after
- 万剑归宗 feedback has highest priority — cancels any active普通 feedback
- Must not exceed 3 Autoload guideline — HitFeedback is a scene node, not Autoload

### Requirements

- TR-FBK-001: Hit stop 2-5 帧 depending on sword form damage
- TR-FBK-002: Screen shake on player hit and heavy attacks
- TR-FBK-003: Material reaction mapping (sword_form × material_type → visual effect)
- TR-FBK-004: Material type enum consistent with ADR-0011's group-based detection

## Decision

### Architecture

HitFeedback is a `Node3D` scene node (NOT an Autoload) that lives in the main scene tree. It listens to HitJudgment's `hit_landed` signal, determines the appropriate feedback combination from sword form + material type, then delegates to camera (hit stop/shake), audio (SFX), and its own material reaction pool (visual effects).

```
hit_landed(HitResult)
    │
    ▼
HitFeedback (Node3D)
    ├── Camera: trigger_hit_stop(frames) + trigger_shake(intensity, duration)
    ├── Audio: play_sfx(material, sword_form)
    └── Visual: spawn_material_reaction(type, position, normal)
```

### Scene Structure

```
HitFeedback (Node3D)
├── MaterialPool (Node3D) — manages reusable Sprite3D/Decal instances
│   ├── SparkPool (5x Sprite3D, gold sparks)
│   ├── CrackPool (1x Decal, wood crack texture)
│   ├── InkSplashPool (10x Sprite3D, ink splatter)
│   └── ShockwavePool (1x MeshInstance3D, fan-shaped)
├── FeedbackTimer (Timer, one_shot, for effect duration tracking)
└── hit_feedback.gd (main script)
```

### Material Reaction Pool

Visual effects use an object pool to avoid per-hit allocation:

| Pool | Node Type | Capacity | Shared Material | Draw Calls |
|------|-----------|----------|-----------------|------------|
| Gold Sparks | Sprite3D | 5 | `spark_material.tres` | 1 (batched) |
| Wood Crack | Decal | 1 | `crack_material.tres` | 1 |
| Ink Splash | Sprite3D | 10 | `ink_splash_material.tres` | 1 (batched) |
| Shockwave | MeshInstance3D | 1 | `shockwave_material.tres` | 1 |

Each pool item has a `lifetime` Timer. On timeout, the node is hidden and returned to pool. Total draw calls for all material reactions: max 4/frame.

### Feedback Dispatch Table

| Sword Form | Material | Hit Stop | Shake | Visual | SFX |
|-----------|----------|----------|-------|--------|-----|
| you (游) | metal | 2 frames | — | 5x gold sparks | `hit_metal_you` |
| you (游) | wood | 2 frames | — | wood crack decal | `hit_wood_you` |
| you (游) | body/ink | 2 frames | — | 5x ink splash | `hit_body_you` |
| zuan (钻) | any | 3 frames | 0.1m, 0.1s | 1x shockwave | `hit_zuan` |
| rao (绕) | any | 2 frames | — | 10x ink splash | `hit_rao` |
| myriad (万剑归宗) | — | 5 frames | 0.3m, 0.3s | screen gold burst | `myriad_trigger` |
| player hit | — | — | 0.1m, 0.1s | edge ink erosion | `player_hit` |

### Hit Stop Formula

```
hit_stop_frames = base_hit_stop + floor(damage / 2)
```

- `base_hit_stop` = 2 frames
- you (damage=1): 2 + 0 = 2 frames
- rao (damage=2): 2 + 1 = 3 frames → **capped at 2** (GDD says 2 for rao)
- zuan (damage=3): 2 + 1 = 3 frames
- myriad: 5 frames (override, not formula-based)

Implementation: call `camera.trigger_hit_stop(frames)` which sets `Engine.time_scale = 0` for N frames.

### Hit Stop Queueing

If `hit_landed` fires during active hit stop:
- Feedback is queued in `var pending_feedback: Array = []`
- On hit stop end (camera emits `hit_stop_finished` or timer expires), process queue FIFO
- 万剑归宗 feedback bypasses queue — executes immediately, cancels any pending普通 feedback

### Material Type Mapping

Material type comes from ADR-0011's HitResult `material_type` field (determined by node groups). HitFeedback maps it to visual effect:

```gdscript
func _get_reaction_type(sword_form: String, material_type: String) -> String:
    if sword_form == "zuan":
        return "shockwave"
    if sword_form == "rao":
        return "ink_splash"
    match material_type:
        "metal": return "gold_sparks"
        "wood": return "wood_crack"
        _: return "ink_splash"  # body, ink, default
```

### 万剑归宗 Special Feedback

When combo system emits `myriad_triggered`:
1. Cancel any pending普通 feedback
2. Camera: `trigger_hit_stop(5)` + `trigger_shake(0.3, 0.3)`
3. Camera: `trigger_fov_zoom(75.0, 2.0, 1.0)` — FOV expansion
4. Screen: gold color burst (post-processing tint via shader, ADR-0003)
5. Audio: `play_sfx("myriad_trigger")` — crescendo爆发音

### Player Hit Feedback

When player controller emits `player_died` or `health_changed` (damage):
1. Camera: `trigger_shake(0.1, 0.1)` — horizontal抖动
2. Screen edge: ink erosion overlay (UI layer, deferred to HUD ADR-0015)
3. Audio: `play_sfx("player_hit")` — 闷响

### Public API

```gdscript
# Main entry point — called by signal handler, not directly
func trigger_hit_feedback(hit_result: HitResult) -> void

# 万剑归宗 special case
func trigger_myriad_feedback(combo_count: int) -> void

# Player hit
func trigger_player_hit_feedback() -> void

# Pool management (internal)
func spawn_material_reaction(type: String, position: Vector3, normal: Vector3) -> void
func return_to_pool(node: Node3D, pool_name: String) -> void
```

### Signals

```gdscript
signal hit_stop_finished  # emitted when hit stop duration ends — for queue processing
signal material_reaction_finished(type: String)  # for analytics/debug
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Hit Judgment (ADR-0011) | Listens `hit_landed(result)` | Consumer |
| Camera System (ADR-0012) | Calls `trigger_hit_stop()`, `trigger_shake()`, `trigger_fov_zoom()` | Consumer |
| Audio System (ADR-0004) | Calls `play_sfx()` | Consumer |
| Combo System (ADR-0009) | Listens `myriad_triggered` | Consumer |
| Player Controller (ADR-0010) | Listens `player_died`, `health_changed` | Consumer |
| Shader/Rendering (ADR-0003) | Uses post-processing for 万剑归宗 gold burst | Consumer |
| HUD/UI (ADR-0015) | Notifies ink erosion overlay on player hit | Provider |

## Alternatives Considered

### Alternative 1: HitFeedback as Autoload Singleton
- **Description**: Make HitFeedback a global Autoload for direct access from any system
- **Pros**: Any system can call `HitFeedback.trigger_hit_feedback()` without signal wiring
- **Cons**: Adds a 4th Autoload (exceeds 3-singleton guideline); feedback is presentation logic — it should live in the scene tree, not as a global; Autoload feedback can't be easily disabled per-scene for testing
- **Rejection Reason**: Violates Autoload minimization principle. Signal-based coupling from ADR-0011 is sufficient — no system needs to directly call HitFeedback.

### Alternative 2: Each System Owns Its Feedback
- **Description**: HitJudgment triggers camera effects directly, enemy system spawns its own particles, etc.
- **Pros**: No centralized feedback system; each system handles its own presentation
- **Cons**: Feedback rules (sword form × material → effect) duplicated across systems; camera API called from 3+ places; no central tuning point for "game feel"; hit stop queueing impossible without coordination
- **Rejection Reason**: Game feel requires central tuning. If sparks feel too weak, you'd need to find and update every call site. Single dispatch table is the correct abstraction.

### Alternative 3: Signal-Only (No Direct Camera/Audio Calls)
- **Description**: HitFeedback emits `feedback_requested(type, params)` signal, and camera/audio subscribe independently
- **Pros**: Maximum decoupling; HitFeedback doesn't know about camera or audio
- **Cons**: Signal is fire-and-forget — no way to enforce hit stop queueing order; camera needs to subscribe to yet another signal; debugging "why didn't the shake play?" requires tracing through signal chains; performance overhead of N signal connections per feedback type
- **Rejection Reason**: Hit stop queueing requires direct coordination between HitFeedback and CameraController. Signal indirection makes the queue impossible to enforce correctly.

## Consequences

### Positive

- Single dispatch table for all feedback combinations — tuning "game feel" is one file
- Material reaction pool avoids per-hit allocation (no GC pressure on Web)
- Max 4 draw calls for all visual effects (well within 50/frame budget)
- Hit stop delegation to camera means `Engine.time_scale = 0` is managed in one place
- Signal-based input (`hit_landed`) keeps HitFeedback decoupled from hit judgment internals

### Negative

- Hit stop via `Engine.time_scale = 0` freezes audio too — audio popping risk on Web (shared risk with ADR-0012)
- Pool capacity is fixed (5 sparks, 10 ink splashes) — if 10+ hits land in one frame, some visual effects are dropped
- Ink erosion overlay on player hit requires coordination with HUD (ADR-0015) — cross-system dependency for a visual detail

### Risks

- **Pool exhaustion under burst damage**: If zuan form hits 5 enemies simultaneously, spark pool (5) is fully consumed and any additional hits have no visual feedback. Mitigation: pool capacity matches `active_enemies < 10` constraint; or use priority system (higher damage = pool priority).
- **Hit stop audio popping**: `Engine.time_scale = 0` freezes audio on Web. Mitigation: shared with ADR-0012 — test during prototype; if confirmed, reduce to 1 frame or use AudioServer bus exemption.
- **万剑归宗 gold burst performance**: Post-processing tint should be lightweight, but if implemented as full-screen shader on Web, may cause frame drops. Mitigation: use modulate on a CanvasLayer overlay instead of shader pass.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| hit-feedback.md | Hit stop 2-5 帧 | `trigger_hit_stop(frames)` with formula-based frame count |
| hit-feedback.md | Screen shake on heavy attacks | `trigger_shake(intensity, duration)` for zuan/myriad/player hit |
| hit-feedback.md | Material reaction mapping (sword_form × material_type) | Dispatch table + `_get_reaction_type()` |
| hit-feedback.md | Material type enum | Reuses ADR-0011's `material_type` field (metal/wood/body/ink) |

## Performance Implications

- **CPU**: Signal handler + dispatch table lookup ≈ 0.01ms per hit (negligible)
- **Memory**: Pool: 5 Sprite3D + 1 Decal + 10 Sprite3D + 1 MeshInstance3D ≈ 5KB total. No per-hit allocation.
- **Draw Calls**: Max 4/frame for material reactions (1 per pool type). Within 50/frame budget.
- **Load Time**: Preloaded materials + pool instantiation < 2ms
- **Network**: N/A (single-player)

## Validation Criteria

- 游剑式命中金属：2 帧顿帧 + 5 个金色火花飞溅 + 金属"叮"音效
- 钻剑式命中敌人：3 帧顿帧 + 扇形冲击波 + 轻微震动 + 闷响"砰"音效
- 绕剑式化解敌击：2 帧顿帧 + 10 个墨点炸碎 + 水墨"噗"音效
- 万剑归宗触发：5 帧顿帧 + 强烈震动 + FOV 60°→75° + 全屏金色爆发 + 渐强爆发音
- 玩家受击：轻微水平震动 + 屏幕边缘墨迹侵蚀 + 闷响
- 命中发生在顿帧期间：反馈排队，顿帧结束后执行
- 万剑归宗反馈取消所有待执行普通反馈
- 材质反应节点在 0.5 秒后自动回收到池
- 最大 draw calls：4/frame（所有材质反应叠加）

## Related Decisions

- ADR-0011: Hit Judgment Architecture — `hit_landed` signal source
- ADR-0012: Camera System Architecture — hit stop and shake execution
- ADR-0004: Audio System Architecture — SFX playback
- ADR-0009: Combo System — `myriad_triggered` signal
- ADR-0010: Player Controller Architecture — `player_died`/`health_changed` signals
- ADR-0003: Shader/Rendering — post-processing for 万剑归宗 gold burst
- ADR-0015: HUD/UI Architecture — ink erosion overlay on player hit
