# ADR-0005: 物理碰撞架构与 Web 性能

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Physics |
| **Knowledge Risk** | HIGH — Jolt 成为默认物理引擎（4.6），Web 端碰撞性能未充分验证 |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | Jolt 物理引擎（4.6 默认后端） |
| **Verification Required** | 1) Jolt 在 Web 端的碰撞检测性能 2) Area3D + CollisionShape3D 的 Web 端帧率 3) ShapeCast3D 的连续碰撞检测开销 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（游戏状态管理）|
| **Enables** | ADR-0006（三式剑招系统）、命中判定层、敌人系统 |
| **Blocks** | 三式剑招系统、命中判定层、敌人系统实现 |
| **Ordering Note** | 必须在三式剑招系统之前 Accepted；建议在原型阶段先验证 Jolt Web 性能 |

## Context

### Problem Statement
《归宗》的"精确即力量"支柱要求精确的碰撞检测——hitbox/hurtbox 的精度直接决定玩家感到"我确实打中了"的精确度。Web 平台的物理引擎性能是最大技术风险。Godot 4.6 默认使用 Jolt 物理引擎，但其在 Web 端的性能尚未充分验证。

### Constraints
- Web 平台：Jolt 物理引擎性能未知
- 碰撞层数：6 层（Player, Enemy, PlayerAttack, EnemyAttack, Environment, Interactable）
- 同屏 hitbox：≤ 18 个
- 物理帧率：30-60fps
- 无 GDExtension（无法用 C++ 优化）

### Requirements
- Area3D + CollisionShape3D 用于 hitbox/hurtbox（不产生物理响应，只检测重叠）
- ShapeCast3D 用于钻剑式穿透检测
- RayCast3D 用于绕剑式附着检测
- 碰撞层矩阵：6 层的交叉检测规则
- hitbox 生命周期管理（创建/更新/销毁）

## Decision

使用 **Godot Area3D + Jolt 物理引擎 + 碰撞层矩阵** 模式。

核心架构：
1. **碰撞体类型**：Area3D + CollisionShape3D（不产生物理推力，只检测重叠）
2. **物理引擎**：Jolt（Godot 4.6 默认）——如果 Web 端性能不达标，降级方案见下方
3. **碰撞层**：6 层，通过 Godot 的 collision_layer / collision_mask 配置矩阵
4. **hitbox 管理**：池化复用——预创建 hitbox 实例，运行时激活/停用而非频繁创建/销毁
5. **空间查询**：ShapeCast3D（钻剑式穿透）、RayCast3D（绕剑式附着）

### Web 性能降级路线图

```
Jolt 物理 (当前) → Godot 内置物理 → 简化碰撞检测 → 纯射线检测
   (理想)           (安全)           (极端)          (保底)
```

如果 Jolt 在 Web 端的物理帧时间 > 4ms：
1. 首先尝试切换到 Godot 内置物理（非 Jolt）
2. 如果仍不达标，减少同时活跃 hitbox 数量（从 18 降到 10）
3. 如果仍不达标，用射线检测代替 Area3D 重叠检测

### Key Interfaces

```gdscript
# PhysicsCollisionSystem.gd (Core)

func create_hitbox(owner: Node3D, shape: Shape3D, pos: Vector3, rot: Vector3) -> int
func destroy_hitbox(id: int) -> void
func update_hitbox_transform(id: int, pos: Vector3, rot: Vector3) -> void
func get_hitbox_collisions(id: int) -> Array[CollisionResult]
func raycast(from: Vector3, to: Vector3, mask: int) -> RaycastResult
func shape_cast(from: Vector3, to: Vector3, shape: Shape3D, mask: int) -> Array[CollisionResult]

signal collision_detected(result: CollisionResult)
```

## Consequences

### Positive
- Area3D 不产生物理响应——适合动作游戏的精确 hitbox/hurtbox
- Jolt 物理引擎（如果 Web 端性能达标）提供更精确的碰撞检测
- 碰撞层矩阵确保正确的碰撞过滤

### Negative
- Jolt 在 Web 端的性能是未知数——需要原型验证
- hitbox 池化增加了管理复杂度
- ShapeCast3D 的连续碰撞检测开销可能在 Web 端显著

### Risks
- **Jolt Web 性能不达标**：→ 缓解：降级路线图（见 Decision）。
- **hitbox 池化大小不足**：万剑归宗时 50 条轨迹可能需要 50+ hitbox。→ 缓解：万剑归宗用范围检测（Area3D）代替逐条射线检测。
- **碰撞层矩阵配置错误**：导致某些碰撞不被检测。→ 缓解：在 Acceptance Criteria 中覆盖所有碰撞层组合。

### Conflict Resolutions

**与 ADR-0008（流光轨迹）— hitbox 上限冲突**：ADR-0005 限制同屏 ≤ 18 hitbox，但万剑归宗的 50 条轨迹需要碰撞检测。已解决：万剑归宗使用单一 Area3D 范围检测（一个 Area3D 覆盖所有轨迹的伤害区域），不为每条轨迹创建独立 hitbox。50 条轨迹仅作视觉渲染（ADR-0008 管辖），碰撞由 ADR-0005 的范围 Area3D 处理。

**与 ADR-0006（三式剑招）— hitbox 生命周期接口冲突**：ADR-0006 描述为"EXECUTING 开始时创建，RECOVERING 开始时销毁"，而 ADR-0005 使用池化复用（`create_hitbox()`/`destroy_hitbox()`）。已解决：ADR-0006 调用 ADR-0005 的 `create_hitbox()` 在 EXECUTING 阶段激活 hitbox，`destroy_hitbox()` 在 RECOVERING 阶段停用 hitbox。池化内部管理实例复用，对外表现为创建/销毁语义。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| physics-collision.md | Core Rules 1-6 | Area3D + 碰撞层 + hitbox 管理 + 空间查询 |
| physics-collision.md | Collision Layers | 6 层碰撞矩阵 |
| physics-collision.md | Hitbox Types | 4 类 hitbox + 对应实现方式 |
| hit-judgment.md | 碰撞结果输入 | `collision_detected` 信号 |
| three-forms-combat.md | 剑招 hitbox | `create_hitbox()` / `destroy_hitbox()` |

## Performance Implications
- **CPU**: 中——物理碰撞检测是主要 CPU 消耗（目标 < 4ms/帧）
- **Memory**: 低——hitbox 池化复用，无频繁分配
- **Load Time**: 无影响
- **Network**: N/A

## Validation Criteria
- Jolt 物理在 Web 端物理帧时间 < 4ms（60fps 下 < 24% 帧预算）
- 18 个同时活跃 hitbox 的碰撞检测正确且无性能问题
- 碰撞层矩阵过滤正确（如 PlayerAttack 不碰撞 Player）

## Related Decisions
- ADR-0006（三式剑招系统）—— 使用此 ADR 的 hitbox API
