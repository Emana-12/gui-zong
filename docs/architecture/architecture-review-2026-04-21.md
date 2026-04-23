# Architecture Review Report

**Date**: 2026-04-21
**Engine**: Godot 4.6.2 stable (win64), GDScript
**Mode**: Full
**GDDs Reviewed**: 18 (all systems) + 1 systems-index
**ADRs Reviewed**: 18 (all Accepted)
**Story Files**: 0 (pre-production)
**Test Files**: 0 (pre-production)
**Previous Review**: 2026-04-20 — CONCERNS (60/90 covered, 24 gaps, 9 missing ADRs)

---

## Phase 1: Document Load Summary

| Category | Count | Status |
|----------|-------|--------|
| GDDs loaded | 19 | All read |
| ADRs loaded | 18 | All Accepted |
| Engine reference modules | 8 | All read |
| TR Registry | 1 | Empty (needs population) |
| Consistency failures log | — | Not found |
| Story files | 0 | Pre-production |
| Test files | 0 | Pre-production |

---

## Phase 2: Technical Requirements Extracted

Total technical requirements extracted from 18 system GDDs: **87**

| GDD | System | TR Count | TR-IDs |
|-----|--------|----------|--------|
| game-state-manager.md | Game State Manager | 6 | TR-GSM-001 to TR-GSM-006 |
| input-system.md | Input System | 5 | TR-INPUT-001 to TR-INPUT-005 |
| shader-rendering.md | Shader/Rendering | 7 | TR-SHADER-001 to TR-SHADER-007 |
| audio-system.md | Audio System | 5 | TR-AUDIO-001 to TR-AUDIO-005 |
| player-controller.md | Player Controller | 6 | TR-PLR-001 to TR-PLR-006 |
| camera-system.md | Camera System | 5 | TR-CAM-001 to TR-CAM-005 |
| physics-collision.md | Physics Collision | 5 | TR-PHYSICS-001 to TR-PHYSICS-005 |
| hit-judgment.md | Hit Judgment | 5 | TR-HIT-001 to TR-HIT-005 |
| three-forms-combat.md | Three Forms Combat | 5 | TR-COMBAT-001 to TR-COMBAT-005 |
| enemy-system.md | Enemy System | 5 | TR-ENEMY-001 to TR-ENEMY-005 |
| light-trail-system.md | Light Trail | 5 | TR-TRAIL-001 to TR-TRAIL-005 |
| combo-myriad-swords.md | Combo/Myriad | 5 | TR-COMBO-001 to TR-COMBO-005 |
| hit-feedback.md | Hit Feedback | 4 | TR-FBK-001 to TR-FBK-004 |
| hud-ui-system.md | HUD/UI | 5 | TR-HUD-001 to TR-HUD-005 |
| arena-wave-system.md | Arena Wave | 5 | TR-WAVE-001 to TR-WAVE-005 |
| level-scene-manager.md | Level/Scene | 4 | TR-LSM-001 to TR-LSM-004 |
| scoring-system.md | Scoring | 3 | TR-SCR-001 to TR-SCR-003 |
| skill-progression.md | Skill Progression | 3 | TR-SKL-001 to TR-SKL-003 |

---

## Phase 3: Traceability Matrix

### Full Matrix

| TR-ID | GDD | Requirement Summary | ADR | Status |
|-------|-----|---------------------|-----|--------|
| TR-GSM-001 | game-state-manager | FSM 5 states (TITLE/COMBAT/INTERMISSION/DEATH/RESTART) | ADR-0001 | ✅ |
| TR-GSM-002 | game-state-manager | state_changed signal broadcast | ADR-0001 | ✅ |
| TR-GSM-003 | game-state-manager | Transition matrix validation | ADR-0001 | ✅ |
| TR-GSM-004 | game-state-manager | Autoload singleton pattern | ADR-0001 | ✅ |
| TR-GSM-005 | game-state-manager | Independent pause control | ADR-0001 | ✅ |
| TR-GSM-006 | game-state-manager | Web tab background auto-pause | ADR-0001 | ✅ |
| TR-INPUT-001 | input-system | Input buffer (cap 1, 6-frame window) | ADR-0002 | ✅ |
| TR-INPUT-002 | input-system | _input() for web input capture | ADR-0002 | ✅ |
| TR-INPUT-003 | input-system | Action group enable/disable | ADR-0002 | ✅ |
| TR-INPUT-004 | input-system | Query interface (is_action_pressed etc.) | ADR-0002 | ✅ |
| TR-INPUT-005 | input-system | Multiple simultaneous input handling | ADR-0002 | ✅ |
| TR-SHADER-001 | shader-rendering | 3 shader types (character/environment/trail) | ADR-0003 | ✅ |
| TR-SHADER-002 | shader-rendering | Shared material pool (≤15 instances) | ADR-0003 | ✅ |
| TR-SHADER-003 | shader-rendering | WebGL 2.0 fallback | ADR-0003 | ✅ |
| TR-SHADER-004 | shader-rendering | Stepped lighting (non-PBR) | ADR-0003 | ✅ |
| TR-SHADER-005 | shader-rendering | ≤2 post-processing passes | ADR-0003 | ✅ |
| TR-SHADER-006 | shader-rendering | Query interface (get_material etc.) | ADR-0003 | ✅ |
| TR-SHADER-007 | shader-rendering | Auto-degradation thresholds | ADR-0003 | ⚠️ Partial |
| TR-AUDIO-001 | audio-system | 3 audio buses (Master/SFX/BGM) | ADR-0004 | ✅ |
| TR-AUDIO-002 | audio-system | SFX preload (<2MB, <30 files) | ADR-0004 | ✅ |
| TR-AUDIO-003 | audio-system | Max 8 concurrent sounds, 3 per effect | ADR-0004 | ✅ |
| TR-AUDIO-004 | audio-system | BGM streaming | ADR-0004 | ✅ |
| TR-AUDIO-005 | audio-system | Web AudioContext initialization | ADR-0004 | ✅ |
| TR-PLR-001 | player-controller | CharacterBody3D, constant 5.0 m/s | ADR-0010 | ✅ |
| TR-PLR-002 | player-controller | Dodge: 3.0m/0.2s, 0.15s invincibility | ADR-0010 | ✅ |
| TR-PLR-003 | player-controller | HP=3, 1 dmg/hit, 0.5s hit stun | ADR-0010 | ✅ |
| TR-PLR-004 | player-controller | Auto-face nearest enemy | ADR-0010 | ✅ |
| TR-PLR-005 | player-controller | get_dodge_success_rate() API | ADR-0010 | ⚠️ Partial |
| TR-PLR-006 | player-controller | Web per-frame position update | ADR-0010 | ✅ |
| TR-CAM-001 | camera-system | 3/4 overhead, 45° angle | ADR-0012 | ✅ |
| TR-CAM-002 | camera-system | Height 6.0m, distance 8.0m, lerp 5.0 | ADR-0012 | ✅ |
| TR-CAM-003 | camera-system | FOV zoom 60→75° | ADR-0012 | ✅ |
| TR-CAM-004 | camera-system | Camera3D per-frame following | ADR-0012 | ✅ |
| TR-CAM-005 | camera-system | State-dependent camera behavior | ADR-0012 | ✅ |
| TR-PHYSICS-001 | physics-collision | 6 collision layers | ADR-0005 | ✅ |
| TR-PHYSICS-002 | physics-collision | Hitbox/hurtbox separation | ADR-0005 | ✅ |
| TR-PHYSICS-003 | physics-collision | Hitbox pooling (≤18 active) | ADR-0005 | ✅ |
| TR-PHYSICS-004 | physics-collision | ShapeCast3D + RayCast3D | ADR-0005 | ✅ |
| TR-PHYSICS-005 | physics-collision | Web performance fallback roadmap | ADR-0005 | ⚠️ Partial |
| TR-HIT-001 | hit-judgment | HitResult struct (7 fields) | ADR-0011 | ✅ |
| TR-HIT-002 | hit-judgment | Deduplication mechanism | ADR-0011 | ✅ |
| TR-HIT-003 | hit-judgment | Invincibility + self-hit check | ADR-0011 | ✅ |
| TR-HIT-004 | hit-judgment | Damage calculation pipeline | ADR-0011 | ✅ |
| TR-HIT-005 | hit-judgment | hit_landed signal broadcast | ADR-0011 | ✅ |
| TR-COMBAT-001 | three-forms-combat | 4-state FSM (IDLE/EXEC/RECOVER/COOLDOWN) | ADR-0006 | ✅ |
| TR-COMBAT-002 | three-forms-combat | 3 forms with distinct parameters | ADR-0006 | ✅ |
| TR-COMBAT-003 | three-forms-combat | Independent cooldown per form | ADR-0006 | ✅ |
| TR-COMBAT-004 | three-forms-combat | DPS balance (游1.67/钻2.50/绕2.35) | ADR-0006 | ✅ |
| TR-COMBAT-005 | three-forms-combat | form_activated/form_finished signals | ADR-0006 | ✅ |
| TR-ENEMY-001 | enemy-system | 5 enemy types with distinct stats | ADR-0007 | ✅ |
| TR-ENEMY-002 | enemy-system | 6-state AI FSM | ADR-0007 | ✅ |
| TR-ENEMY-003 | enemy-system | Max 10 active enemies | ADR-0007 | ✅ |
| TR-ENEMY-004 | enemy-system | spawn_enemy/kill_all interface | ADR-0007 | ✅ |
| TR-ENEMY-005 | enemy-system | enemy_died signal | ADR-0007 | ✅ |
| TR-TRAIL-001 | light-trail | MeshInstance3D + ImmediateMesh | ADR-0008 | ✅ |
| TR-TRAIL-002 | light-trail | Trail pooling (max 50) | ADR-0008 | ✅ |
| TR-TRAIL-003 | light-trail | Shared material (3 per form type) | ADR-0008 | ✅ |
| TR-TRAIL-004 | light-trail | Per-form trail parameters | ADR-0008 | ✅ |
| TR-TRAIL-005 | light-trail | Myriad batch rendering (1 draw call) | ADR-0008 | ✅ |
| TR-COMBO-001 | combo-myriad | Combo timeout 3s | ADR-0009 | ✅ |
| TR-COMBO-002 | combo-myriad | Charge 10, auto-trigger 20 | ADR-0009 | ✅ |
| TR-COMBO-003 | combo-myriad | Myriad formulas (trails/damage/range) | ADR-0009 | ✅ |
| TR-COMBO-004 | combo-myriad | Different form = +1 combo | ADR-0009 | ✅ |
| TR-COMBO-005 | combo-myriad | combo_changed/myriad_triggered signals | ADR-0009 | ✅ |
| TR-FBK-001 | hit-feedback | Material reactions (gold/wood/ink/shock) | ADR-0013 | ✅ |
| TR-FBK-002 | hit-feedback | Hit stop formula (2+floor(dmg/2)) | ADR-0013 | ✅ |
| TR-FBK-003 | hit-feedback | Max 4 draw calls/frame | ADR-0013 | ✅ |
| TR-FBK-004 | hit-feedback | Low-fps hit stop reduction | ADR-0013 | ✅ |
| TR-HUD-001 | hud-ui | HUD elements (health/combo/form/charge/wave) | ADR-0015 | ✅ |
| TR-HUD-002 | hud-ui | State-dependent HUD switching | ADR-0015 | ✅ |
| TR-HUD-003 | hud-ui | Auto-fade (3s → 0.3 alpha) | ADR-0015 | ✅ |
| TR-HUD-004 | hud-ui | Menu stack system | ADR-0015 | ✅ |
| TR-HUD-005 | hud-ui | Web responsive anchoring | ADR-0015 | ✅ |
| TR-WAVE-001 | arena-wave | Scaling formula (2+floor(n*0.8)) | ADR-0014 | ✅ |
| TR-WAVE-002 | arena-wave | Max 10 active enemies + spawn queue | ADR-0014 | ✅ |
| TR-WAVE-003 | arena-wave | Enemy type unlock schedule | ADR-0014 | ✅ |
| TR-WAVE-004 | arena-wave | Wave lifecycle + INTERMISSION | ADR-0014 | ✅ |
| TR-WAVE-005 | arena-wave | wave_completed signal | ADR-0014 | ✅ |
| TR-LSM-001 | level-scene | 2 arena PackedScenes | ADR-0016 | ✅ |
| TR-LSM-002 | level-scene | Preload + spawn points (Marker3D) | ADR-0016 | ✅ |
| TR-LSM-003 | level-scene | Fade transition | ADR-0016 | ✅ |
| TR-LSM-004 | level-scene | Web memory release (queue_free) | ADR-0016 | ✅ |
| TR-SCR-001 | scoring | Best wave/combo/myriad tracking | ADR-0017 | ✅ |
| TR-SCR-002 | scoring | JSON + localStorage persistence | ADR-0017 | ✅ |
| TR-SCR-003 | scoring | Cross-system signal collection | ADR-0017 | ✅ |
| TR-SKL-001 | skill-progression | 3 operation metrics | ADR-0018 | ✅ |
| TR-SKL-002 | skill-progression | Last 10 runs trend data | ADR-0018 | ✅ |
| TR-SKL-003 | skill-progression | JSON + localStorage persistence | ADR-0018 | ✅ |

### Traceability Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered | 83 | 95.4% |
| ⚠️ Partial | 4 | 4.6% |
| ❌ Gap | 0 | 0.0% |
| **Total** | **87** | **100%** |

**Coverage improvement**: 66.7% → 95.4% (+28.7pp from previous review)

### Partial Coverage Details

| TR-ID | Issue | Resolution |
|-------|-------|------------|
| TR-SHADER-007 | ADR-0003 defines auto-degradation but GDD specifies fps<20 ink_steps=2 trigger not in ADR code examples | Add ink_steps=2 threshold to ADR-0003 degradation table |
| TR-PLR-005 | ADR-0018 needs `get_dodge_success_rate()` from player controller, but ADR-0010 does not formalize this API | Add `get_dodge_success_rate() -> float` to ADR-0010's public API section |
| TR-PHYSICS-005 | GDD specifies 4-layer fallback roadmap; ADR-0005 documents fallback but less detailed | Expand ADR-0005 fallback section or accept GDD as authoritative |

---

## Phase 4: Cross-ADR Conflict Detection

### Conflict 1: Dependency Ordering vs Layer Classification (MEDIUM)

**Type**: Architecture Document Inconsistency

`architecture.md` assigns ADRs to layers that don't match their dependency topology:

| ADR | architecture.md Layer | Actual Topo Level | Discrepancy |
|-----|----------------------|-------------------|-------------|
| ADR-0007 (Enemy AI) | Feature | Level 2 | Should be Core |
| ADR-0011 (Hit Judgment) | Feature | Level 2 | Should be Core |
| ADR-0012 (Camera) | Presentation | Level 3 | Should be Feature |
| ADR-0014 (Arena Wave) | Feature | Level 3 | Should be in same tier as 0008/0009 |

**Impact**: If a programmer follows architecture.md layer order for implementation, they may start Feature-layer ADRs before their Core-layer dependencies are ready.

**Resolution**: Align architecture.md layer assignments with dependency topology, or document that "layer" is conceptual (domain grouping) while dependency topology is the implementation order.

### Conflict 2: Missing Interface — get_dodge_success_rate() (LOW)

**Type**: Integration Contract Gap

ADR-0018 (Skill Progression) depends on ADR-0010 (Player Controller) providing `get_dodge_success_rate()`. However:
- ADR-0010's public API section does not include this method
- ADR-0010's GDD (`player-controller.md`) does not list it as an exposed interface

**Impact**: When implementing skill progression, the programmer will find no API to call for dodge success rate.

**Resolution**: Add `get_dodge_success_rate() -> float` to ADR-0010's public API, tracking successful dodges vs total dodge attempts.

### Previously Resolved Conflicts (verified still resolved)

| Conflict | Status | Verification |
|----------|--------|-------------|
| ADR-0005 vs ADR-0008 (hitbox limit) | ✅ Resolved | Single Area3D range check for myriad — verified in both ADRs |
| ADR-0003 vs ADR-0008 (material pool) | ✅ Resolved | 3 shared materials — verified in both ADRs |
| ADR-0005 vs ADR-0006 (hitbox lifecycle) | ✅ Resolved | Pooling with create/destroy external semantics — verified |
| ADR-0001 vs ADR-0007 (COMBAT authority) | ✅ Resolved | ADR-0007 only consumes state — verified |

### No Additional Conflicts Found

Checked all 153 ADR pairs (18 choose 2) for:
- Data ownership conflicts: None (each data item has single owner)
- Integration contract conflicts: 1 found (missing API)
- Performance budget conflicts: None (draw calls ~22/50 max, enemies ≤10, post-processing ≤2)
- Dependency cycles: None (verified acyclic)
- Architecture pattern conflicts: None (signal-driven throughout)
- State management conflicts: None (COMBAT authority resolved)

---

## Phase 4b: ADR Dependency Ordering

### Topological Sort (verified, no cycles)

```
Level 0 — Foundation (no dependencies):
  1. ADR-0001: 场景管理与状态流转架构
  2. ADR-0003: 渲染管线与着色器架构

Level 1 — Depends on Foundation:
  3. ADR-0002: 输入系统架构 (requires ADR-0001)
  4. ADR-0004: 音频系统架构 (requires ADR-0001)
  5. ADR-0005: 物理碰撞架构 (requires ADR-0001)
  6. ADR-0016: 关卡场景管理器架构 (requires ADR-0001)

Level 2 — Depends on Level 1:
  7. ADR-0006: 三式剑招系统架构 (requires ADR-0002, ADR-0005)
  8. ADR-0007: 敌人 AI 架构 (requires ADR-0001, ADR-0005)
  9. ADR-0010: 玩家控制器架构 (requires ADR-0001, ADR-0002, ADR-0005)

Level 3 — Depends on Level 2:
 10. ADR-0008: 流光轨迹渲染架构 (requires ADR-0003, ADR-0006)
 11. ADR-0009: 连击系统架构 (requires ADR-0006)
 12. ADR-0011: 命中判定架构 (requires ADR-0005, ADR-0010)
 13. ADR-0012: 相机系统架构 (requires ADR-0001, ADR-0010)
 14. ADR-0014: 竞技场波次架构 (requires ADR-0001, ADR-0007)

Level 4 — Depends on Level 3:
 15. ADR-0013: 命中反馈架构 (requires ADR-0004, ADR-0011, ADR-0012)
 16. ADR-0015: HUD/UI 架构 (requires ADR-0001, ADR-0009, ADR-0010, ADR-0012)
 17. ADR-0017: 计分系统架构 (requires ADR-0009, ADR-0014)

Level 5 — Depends on Level 4:
 18. ADR-0018: 技能进阶架构 (requires ADR-0009, ADR-0010, ADR-0017)
```

### Dependency Issues

- **Unresolved dependencies**: None — all `Depends On` references point to Accepted ADRs
- **Dependency cycles**: None detected
- **Orphaned ADRs**: None — all 18 ADRs are reachable
- **Critical path**: ADR-0001 → ADR-0005 → ADR-0010 → ADR-0011 → ADR-0013

---

## Phase 5: Engine Compatibility Audit

### Version Consistency
All 18 ADRs reference **Godot 4.6.2 stable** — consistent. No ADR written for an older engine version.

### Post-Cutoff API Usage

| ADR | Post-Cutoff API | Engine Version | Verified |
|-----|-----------------|----------------|----------|
| ADR-0003 | D3D12 rendering backend | 4.6 | ✅ rendering.md confirms D3D12 default on Windows |
| ADR-0003 | Glow rework parameters | 4.6 | ✅ rendering.md confirms glow before tonemapping |
| ADR-0005 | Jolt physics engine | 4.6 | ✅ physics.md confirms Jolt is 3D default |

### Post-Cutoff API Consistency
- No two ADRs make contradictory assumptions about the same post-cutoff API
- ADR-0003 correctly identifies D3D12 as irrelevant for Web export
- ADR-0005 correctly uses Area3D (overlap-only) and avoids HingeJoint3D (ignored by Jolt)

### Deprecated API Check
**None found.** All 18 ADRs use current 4.6-compatible patterns:
- No `playback_active` (deprecated 4.3)
- No `bone_pose_updated` (deprecated 4.3)
- No `NavigationRegion2D.avoidance_layers` (deprecated 4.3)

### Missing Engine Compatibility Sections
All 18 ADRs include Engine Compatibility sections. **0 missing.**

### Engine Specialist Findings

1. **ADR-0003 (Glow)**: 4.6 glow processes before tonemapping (screen blending). ADR-0003's tone adjustment pass should be tested against new glow ordering in prototype phase.

2. **ADR-0015 (Dual Focus)**: Godot 4.6 introduces dual focus system (mouse/touch vs keyboard/gamepad). `grab_focus()` only affects keyboard/gamepad. ADR-0015's HUD focus management may need adaptation.

3. **Shader texture types**: 4.4 changed `Texture2D` → `Texture` base type in shader uniforms. ADR-0003 should verify all `.gdshader` uniform declarations use the new type.

---

## Phase 5b: GDD Revision Flags

| GDD | Assumption | Reality | Severity | Action |
|-----|-----------|---------|----------|--------|
| player-controller.md | Exposes dodge stats for skill progression | ADR-0010 missing `get_dodge_success_rate()` | MEDIUM | Add API to ADR-0010 |
| shader-rendering.md | Post-processing tone pass independent of glow | 4.6 glow before tonemapping (screen blending) | LOW | Verify in prototype |

**No GDDs need revision.** Both flags are ADR-level fixes.

---

## Phase 6: Architecture Document Coverage

### systems-index.md vs architecture.md

All 18 systems from `systems-index.md` appear in `architecture.md`:

| Layer | systems-index | architecture.md | Match |
|-------|---------------|-----------------|-------|
| Foundation | 4 | 4 | ✅ |
| Core | 6 | 6 | ✅ |
| Feature | 4 | 4 | ✅ |
| Presentation | 2 | 2 | ✅ |
| Polish | 2 | 2 | ✅ |

### Validation Results
- **Orphaned architecture**: None
- **Orphaned GDDs**: None
- **Data Flow paths**: 4 paths verified (frame update, signal/event, save/load, initialization)
- **API Boundaries**: Foundation→Core, Core→Core, Core→Feature contracts all match ADR definitions
- **Architecture Principles**: 5 principles defined and consistent with ADR implementations

---

## Phase 7: Verdict

### Verdict: CONCERNS

**Improvement**: 66.7% → 95.4% coverage (+28.7pp), 0 gaps (was 24)

### Strengths
- 83/87 TRs fully covered, 4 partial, 0 gaps
- All 18 ADRs Accepted with consistent Godot 4.6.2 references
- No deprecated APIs, no dependency cycles, no data ownership conflicts
- All 4 previously identified conflicts remain resolved
- Performance budgets collectively within limits (draw calls ~22/50, enemies ≤10)
- Complete architecture document with all 18 systems mapped

### Non-Blocking Issues (fix before Pre-Production gate)

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | TR Registry is empty (0 entries) | MEDIUM | Populate all 87 TR-IDs |
| 2 | Missing API: `get_dodge_success_rate()` in ADR-0010 | MEDIUM | Add to ADR-0010 public API |
| 3 | Layer classification inconsistency | LOW | Align architecture.md layers with topo sort |
| 4 | ADR-0003 shader texture type (Texture2D → Texture) | LOW | Verify shader uniforms use `Texture` |
| 5 | ADR-0015 dual focus system (4.6) | LOW | Verify HUD focus with 4.6 behavior |

---

## Immediate Actions

1. **Populate TR Registry** — all 87 TR-IDs need stable IDs before story creation
2. **Add `get_dodge_success_rate()` to ADR-0010** — blocks skill progression implementation
3. **Align architecture.md layer classifications** with dependency topology
4. **Run `/gate-check pre-production`** — after items 1-3 are resolved
