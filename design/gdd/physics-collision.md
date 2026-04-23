# 物理碰撞层 (Physics Collision)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 精确即力量 (Pillar 1)
> **Risk Level**: HIGH — Web 平台碰撞性能待验证

## Overview

**物理碰撞层**是《归宗》所有空间查询和碰撞检测的底层工具。它管理碰撞体（hitbox/hurtbox）、执行空间查询（射线检测、区域检测）、并提供碰撞结果给上层的命中判定系统。这个系统不决定"什么算命中"——只负责"什么东西碰到了什么东西"。

**职责边界：**
- **做**：碰撞体管理（创建/销毁/更新碰撞形状）、空间查询（射线检测、ShapeCast3D、Area3D 重叠检测）、碰撞结果输出（碰撞位置、法线、碰撞对象）
- **不做**：伤害计算（由命中判定层负责）、命中类型判断（由命中判定层负责）、无敌帧逻辑（由玩家控制器/命中判定层负责）

**为什么需要它：** 物理碰撞层是"精确即力量"的技术基础。没有精确的碰撞检测，精确打击就是空谈。Web 平台的碰撞检测性能直接影响游戏的可玩性——这个系统必须在性能预算内提供精确的空间查询。

> **⚠️ 高风险系统**：Web 平台实时碰撞检测可能有延迟，直接影响"精确即力量"支柱。需要在原型阶段验证帧率和碰撞精度。

## Player Fantasy

**玩家不感知碰撞检测——但他们感知"命中了"和"没命中"的区别。**

玩家感受到的是：
- 剑挥过敌人时，流光轨迹精确地贴合剑尖路径——碰撞检测的精度决定了轨迹的精度
- 闪避穿过攻击时，"差一点就打中了"的紧张感——碰撞体的大小决定了这个"差一点"
- 万剑归宗时，所有流光精确地穿过敌人——没有穿模、没有漏检

**支柱对齐：** 直接服务于"精确即力量"(Pillar 1)——碰撞检测的精度 = 精确打击的精度。

## Detailed Design

### Core Rules

1. 物理碰撞层使用 Godot 4.6 的 Jolt 物理引擎（默认后端）进行碰撞检测
2. 每个游戏实体（玩家、敌人、剑招）有两类碰撞体：**hurtbox**（受伤区域）和 **hitbox**（攻击区域）
3. hitbox 和 hurtbox 使用 Godot 的 Area3D + CollisionShape3D 实现——Area3D 不产生物理响应（不推开物体），只检测重叠
4. 剑招的 hitbox 通过 ShapeCast3D 实现——从剑尖位置向前投射一个形状，检测沿途碰撞
5. 物理碰撞层每物理帧（`_physics_process`）更新一次碰撞状态
6. 碰撞检测结果通过 `area_entered` / `area_exited` 信号或 `get_overlapping_areas()` 查询返回给上层

### Collision Layers（碰撞层）

| 层 | 名称 | 碰撞对象 | 说明 |
|----|------|---------|------|
| 1 | Player | 玩家碰撞体 | 玩家的 hurtbox |
| 2 | Enemy | 敌人碰撞体 | 敌人的 hurtbox |
| 3 | PlayerAttack | 玩家攻击 | 玩家剑招的 hitbox |
| 4 | EnemyAttack | 敌人攻击 | 敌人攻击的 hitbox |
| 5 | Environment | 环境 | 地形、障碍物 |
| 6 | Interactable | 可交互物体 | 绕剑式附着点 |

**碰撞矩阵：**

| | Player | Enemy | PlayerAttack | EnemyAttack | Environment | Interactable |
|--|--------|-------|-------------|-------------|-------------|-------------|
| Player | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ |
| Enemy | ✗ | ✗ | ✓ | ✗ | ✓ | ✗ |
| PlayerAttack | ✗ | ✓ | ✗ | ✗ | ✗ | ✓ |
| EnemyAttack | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ |

### Hitbox Types

| Hitbox 类型 | 形状 | 用途 | 实现方式 |
|------------|------|------|---------|
| 剑招 hitbox | 扇形/矩形 | 三式剑招的攻击区域 | Area3D + CollisionShape3D |
| 追踪 hitbox | 球形 | 剑气追踪目标 | ShapeCast3D |
| 范围 hitbox | 球形 | 万剑归宗的爆炸范围 | Area3D + CollisionShape3D |
| 附着检测 | 射线 | 绕剑式附着检测 | RayCast3D |

### Interactions with Other Systems

**对外发出的接口：**

| 接口 | 类型 | 说明 | 接收系统 |
|------|------|------|---------|
| `create_hitbox(owner, shape, position, rotation)` | 创建 | 创建攻击碰撞体 | 三式剑招系统, 敌人系统 |
| `destroy_hitbox(id)` | 销毁 | 销毁攻击碰撞体 | 三式剑招系统, 敌人系统 |
| `get_hitbox_collisions(hitbox_id)` | 查询 | 获取碰撞体的所有碰撞结果 | 命中判定层 |
| `raycast(from, to, mask)` | 查询 | 射线检测 | 绕剑式附着, 环境交互 |
| `shape_cast(from, to, shape, mask)` | 查询 | 形状投射检测 | 钻剑式穿透 |
| `collision_detected` | 信号 | 碰撞发生 | 命中判定层 |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 三式剑招系统 | 剑招执行 | 创建/更新剑招 hitbox |
| 敌人系统 | 敌人攻击 | 创建敌人攻击 hitbox |
| 玩家控制器 | 玩家位置更新 | 更新玩家 hurtbox 位置 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `create_hitbox` | `create_hitbox(owner: Node3D, shape: Shape3D, pos: Vector3, rot: Vector3)` | `int` | 创建 hitbox，返回 ID |
| `destroy_hitbox` | `destroy_hitbox(id: int)` | `void` | 销毁 hitbox |
| `get_hitbox_collisions` | `get_hitbox_collisions(id: int)` | `Array[CollisionResult]` | 获取碰撞结果列表 |
| `raycast` | `raycast(from: Vector3, to: Vector3, mask: int)` | `RaycastResult or null` | 射线检测 |
| `shape_cast` | `shape_cast(from: Vector3, to: Vector3, shape: Shape3D, mask: int)` | `Array[CollisionResult]` | 形状投射 |
| `update_hitbox_transform` | `update_hitbox_transform(id: int, pos: Vector3, rot: Vector3)` | `void` | 更新 hitbox 位置/旋转 |

## Formulas

**碰撞检测频率：**

`collision_checks_per_sec = physics_fps`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 物理帧率 | `physics_fps` | int | 30–60 | Godot 物理帧率（默认 60） |

**输出：** 每秒 30–60 次碰撞检测。Web 平台可能受性能影响降低到 30。

**同屏 hitbox 数量预算：**

`total_hitboxes = player_hitboxes + enemy_hitboxes + environment_hitboxes`

| 组成 | 预算 |
|------|------|
| 玩家 hitbox | ≤ 3（三式剑招各有 1 个） |
| 敌人 hitbox | ≤ 10（每个敌人 ≤ 1 个攻击 hitbox） |
| 环境 hitbox | ≤ 5（绕剑式附着点） |
| **总计** | **≤ 18** |

## Edge Cases

- **如果 hitbox 和 hurtbox 在同一帧内重叠又分离**（高速移动）：Area3D 的 `area_entered` 信号仍会触发——Godot 保证帧内检测。
- **如果多个 hitbox 同时命中同一个 hurtbox**：每个碰撞独立处理，命中判定层负责去重（如同一招式不造成多次伤害）。
- **如果 Web 平台物理帧率降低到 30fps**：碰撞检测精度降低——可能漏检高速移动物体。解决方案：增大 hitbox 尺寸或使用 ShapeCast3D（连续碰撞检测）。
- **如果 hitbox 创建后立即销毁**（如剑招被打断）：在 `_physics_process` 中销毁，不在信号回调中销毁（避免 Godot 的信号处理顺序问题）。
- **如果射线检测的起点和终点重合**：返回 null（无碰撞）。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 玩家控制器 | 硬依赖 | `get_position()` — 更新玩家 hurtbox 位置 |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 命中判定层 | 硬依赖 | `get_hitbox_collisions()`, `collision_detected` 信号 |
| 三式剑招系统 | 硬依赖 | `create_hitbox()`, `destroy_hitbox()`, `update_hitbox_transform()` |
| 敌人系统 | 硬依赖 | `create_hitbox()`, `destroy_hitbox()` |
| 流光轨迹系统 | 软依赖 | `raycast()` — 确定轨迹路径 |
| 连击/万剑归宗 | 软依赖 | `shape_cast()` — 万剑归宗范围检测 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `player_hurtbox_radius` | 0.5 m | 0.3–1.0 m | 玩家受伤区域大小。太小=不公平（判定太严格），太大=手感差（被打中不合理） |
| `enemy_hurtbox_radius` | 0.8 m | 0.5–1.5 m | 敌人受伤区域大小 |
| `sword_hitbox_width` | 1.0 m | 0.5–2.0 m | 剑招 hitbox 宽度 |
| `sword_hitbox_length` | 2.0 m | 1.0–4.0 m | 剑招 hitbox 长度（剑的攻击距离） |
| `physics_fps` | 60 | 30–60 | 物理帧率。降低=性能更好但碰撞精度降低 |

## Visual/Audio Requirements

**本系统不直接产生视觉/音频效果。** 碰撞检测是纯逻辑层。视觉效果由下游系统负责：
- 命中反馈：顿帧、震动、材质反应（火花/裂纹/墨点炸碎）
- 流光轨迹：剑尖轨迹可视化

## UI Requirements

**无。** 本系统不包含 UI。

## Acceptance Criteria

- **GIVEN** 玩家挥剑，**WHEN** 剑招 hitbox 与敌人 hurtbox 重叠，**THEN** `collision_detected` 信号触发，返回碰撞位置和对象
- **GIVEN** 玩家闪避，**WHEN** 玩家 hurtbox 与敌人攻击 hitbox 重叠但处于无敌帧，**THEN** 命中判定层通过 `is_invincible()` 过滤——物理碰撞层仍检测到碰撞
- **GIVEN** 调用 `raycast(A, B, mask)`，**WHEN** 射线路径上有碰撞体，**THEN** 返回最近碰撞点的 RaycastResult
- **GIVEN** 调用 `raycast(A, A, mask)`（起点=终点），**WHEN** 执行射线检测，**THEN** 返回 null
- **GIVEN** 同屏有 3 个玩家 hitbox + 10 个敌人 hitbox + 5 个环境 hitbox，**WHEN** 统计活跃 hitbox，**THEN** ≤ 18
- **GIVEN** Web 平台物理帧率降至 30fps，**WHEN** 碰撞检测执行，**THEN** 每秒仍进行 30 次碰撞检测
- **GIVEN** hitbox 创建后在同一帧被销毁，**WHEN** 执行销毁，**THEN** 不产生错误或残留

## Open Questions

- Jolt 物理引擎在 Web 平台的性能表现尚未验证——需要在原型阶段用 Benchmark 测试。
- ShapeCast3D（连续碰撞检测）的性能开销有多大？如果太重，钻剑式的穿透检测可能需要降级为离散检测。
- 碰撞层的碰撞矩阵是否需要在运行时动态调整？（如万剑归宗时玩家攻击应该能击中所有敌人，包括原本免疫的）