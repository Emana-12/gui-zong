# 命中判定层 (Hit Judgment)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 精确即力量 (Pillar 1)

## Overview

**命中判定层**是"什么算命中"的游戏逻辑层。它接收物理碰撞层的碰撞结果，判断：这次碰撞是否构成有效命中？造成多少伤害？命中的是哪个剑式？目标是否处于无敌状态？然后将判定结果输出给下游系统（连击计数、命中反馈、敌人受伤）。

**职责边界：**
- **做**：伤害计算、命中类型判断（游/钻/绕）、无敌帧过滤、命中结果输出
- **不做**：碰撞检测（物理碰撞层负责）、伤害应用（敌人/玩家控制器负责）、视觉/音频反馈（命中反馈负责）

**为什么需要它：** 物理碰撞层只回答"什么东西碰到了什么"，但不回答"这算不算命中"。命中判定层将碰撞转化为游戏规则——这是从物理世界到游戏世界的桥梁。

## Player Fantasy

**玩家感受到的是"打中了"或"没打中"——判定层决定了这个感受的精确度。**

玩家感受到的是：
- 剑挥过敌人，流光命中——"叮"的一声确认，连击+1
- 闪避穿过攻击——"差一点就打中了"的紧张
- 三式各有不同的命中感——游剑式缠绕触发材质反应、钻剑式穿透产生冲击波、绕剑式护身化解敌击

**支柱对齐：** 直接服务于"精确即力量"(Pillar 1)——命中判定的精确度 = 玩家感到"我确实打中了"的精确度。

## Detailed Design

### Core Rules

1. 命中判定层监听物理碰撞层的 `collision_detected` 信号，对每个碰撞执行判定流程
2. 判定流程：碰撞发生 → 检查目标无敌状态 → 检查命中类型（哪一式）→ 计算伤害 → 输出判定结果
3. 每次有效命中输出一个 `HitResult` 数据结构，包含：命中者、被命中者、剑式类型、伤害值、碰撞位置、碰撞法线
4. 无敌帧过滤：如果目标 `is_invincible()` 返回 true，该碰撞不构成有效命中
5. 同一招式的同一 hitbox 对同一目标只造成一次伤害（去重机制）
6. 三式各有独立的伤害计算——游剑式低伤害高频率、钻剑式高伤害低频率、绕剑式中等伤害+范围

### HitResult 数据结构

| 字段 | 类型 | 说明 |
|------|------|------|
| `attacker` | Node3D | 攻击者（玩家或敌人） |
| `target` | Node3D | 被命中者 |
| `sword_form` | String | 剑式类型：`"you"` / `"zuan"` / `"rao"` / `"none"`（非剑招攻击） |
| `damage` | int | 伤害值 |
| `hit_position` | Vector3 | 命中世界坐标 |
| `hit_normal` | Vector3 | 命中面法线方向 |
| `material_type` | String | 被命中材质：`"metal"` / `"wood"` / `"ink"` / `"body"` |
| `is_vulnerability_hit` | bool | 是否击中方向破绽（2× 伤害） |

### Damage Rules

| 剑式 | 基础伤害 | 命中频率 | 说明 |
|------|---------|---------|------|
| 游剑式 | 1 | 高（连续缠绕） | 低伤害但持续输出，触发材质反应 |
| 钻剑式 | 3 | 低（蓄力穿透） | 高伤害单次爆发，穿透防御 |
| 绕剑式 | 2 | 中（护身范围） | 中等伤害，范围化解敌方攻击 |
| 敌人攻击 | 1 | — | 每次命中扣玩家 1 HP |

### Directional Vulnerability（方向破绽）

命中敌人时检查是否击中破绽。破绽命中条件：攻击方向匹配破绽方向 **AND** 剑式匹配克制剑式。

**判定流程（在去重之后、伤害计算之前）:**

1. 获取敌人类型（`enemy.get_enemy_type()`）
2. 查询该类型的破绽配置（方向 + 克制剑式）
3. 计算攻击来自敌人的哪个方向（前方/后方/左侧/右侧/上方）
4. 如果方向匹配 AND 剑式匹配 → `multiplier = 2.0`，否则 `multiplier = 1.0`
5. `final_damage = base_damage × multiplier`

**方向判定（从敌人视角）:**

| 方向 | 判定条件 |
|------|---------|
| 前方 | 攻击者在敌人朝向 ±45° 内 |
| 后方 | 攻击者在敌人朝向 ±135°~180° |
| 左侧 | 攻击者在敌人左侧 90° |
| 右侧 | 攻击者在敌人右侧 90° |
| 上方 | 攻击者 Y 坐标 > 敌人 Y + 0.5m |

**破绽表（来自 EnemySystem.VULNERABILITY）:**

| 敌人 | 破绽方向 | 克制剑式 | 破绽伤害 |
|------|---------|---------|---------|
| 松韧型 | 正前方 | 钻剑式 | 6 (= 3 × 2) |
| 重甲型 | 上方 | 钻剑式 | 6 (= 3 × 2) |
| 流动型 | 侧面 | 游剑式 | 2 (= 1 × 2) |
| 远程型 | 正前方 | 钻剑式 | 6 (= 3 × 2) |
| 敏捷型 | 背后 | 绕剑式 | 4 (= 2 × 2) |

### Hit Deduplication（命中去重）

- 每个 hitbox 对每个目标维护一个 `already_hit` 列表
- 碰撞发生时，检查目标是否已在 `already_hit` 列表中——如果在，忽略
- hitbox 销毁时，清空对应的 `already_hit` 列表
- 这防止了同一招式的多次碰撞造成多次伤害（如旋转剑招持续接触敌人）

### Interactions with Other Systems

**对外发出的接口：**

| 接口 | 类型 | 说明 | 接收系统 |
|------|------|------|---------|
| `hit_landed` | 信号 | 有效命中发生 | 连击/万剑归宗, 命中反馈, 敌人系统, HUD |
| `get_last_hit()` | 查询 | 获取最近一次 HitResult | 命中反馈（材质反应判断） |
| `calculate_damage(sword_form, target)` | 计算 | 计算指定剑式对目标的伤害 | 三式剑招系统（预判伤害） |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 物理碰撞层 | `collision_detected` | 执行命中判定流程 |
| 玩家控制器 | `is_invincible()` | 过滤无敌状态下的碰撞 |
| 三式剑招系统 | 当前激活剑式 | 确定命中类型 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `process_collision` | `process_collision(collision: CollisionResult)` | `HitResult or null` | 处理碰撞，返回判定结果（null=无效命中） |
| `get_last_hit` | `get_last_hit()` | `HitResult` | 获取最近一次有效 HitResult |
| `calculate_damage` | `calculate_damage(sword_form: String, target: Node3D)` | `int` | 计算伤害值 |
| `register_hitbox_dedup` | `register_hitbox_dedup(hitbox_id: int, target: Node3D)` | `void` | 注册去重（hitbox 命中目标后调用） |
| `is_already_hit` | `is_already_hit(hitbox_id: int, target: Node3D)` | `bool` | 检查是否已命中 |

## Formulas

**伤害计算：**

`final_damage = base_damage * sword_form_multiplier`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 基础伤害 | `base_damage` | int | 1–3 | 剑式基础伤害 |
| 剑式倍率 | `sword_form_multiplier` | float | 0.5–2.0 | 剑式伤害倍率（可用于变体调整） |

**输出：** 1–6 点伤害（在默认倍率下）

**示例：** 游剑式 base=1, multiplier=1.0 → final=1。钻剑式 base=3, multiplier=1.0 → final=3。

## Edge Cases

- **如果碰撞目标处于无敌状态**：返回 null（无效命中），不输出 HitResult。
- **如果 hitbox 已命中目标但碰撞仍在持续**：通过去重机制忽略后续碰撞。
- **如果同一帧内多个 hitbox 命中同一目标**：每个 hitbox 独立判定，各自输出 HitResult。
- **如果攻击者和目标是同一实体**（自伤）：忽略，不判定为命中。
- **如果 sword_form 为 null（非剑招攻击，如敌人普通攻击）**：使用 `sword_form="none"`，基础伤害=1。
- **如果碰撞位置在世界原点（0,0,0）**：仍判定为有效命中，但位置可能无效——下游系统负责处理。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 物理碰撞层 | 硬依赖 | `collision_detected` 信号, `get_hitbox_collisions()` |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 连击/万剑归宗 | 硬依赖 | `hit_landed` 信号 |
| 命中反馈 | 硬依赖 | `hit_landed` 信号, `get_last_hit()` |
| 敌人系统 | 硬依赖 | `hit_landed` 信号（敌人受伤） |
| 三式剑招系统 | 软依赖 | `calculate_damage()` 预判 |
| HUD/UI | 软依赖 | `hit_landed` 信号（伤害数字显示） |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `damage_you` | 1 | 1–2 | 游剑式基础伤害 |
| `damage_zuan` | 3 | 2–5 | 钻剑式基础伤害 |
| `damage_rao` | 2 | 1–3 | 绕剑式基础伤害 |
| `damage_enemy` | 1 | 1–2 | 敌人攻击伤害 |
| `sword_form_multiplier` | 1.0 | 0.5–2.0 | 全局剑式伤害倍率 |

## Visual/Audio Requirements

**本系统不直接产生视觉/音频效果。** 命中判定结果由下游系统（命中反馈、流光轨迹）负责产生视觉/音频效果。

## UI Requirements

**无直接 UI。** `hit_landed` 信号可被 HUD/UI 系统监听以显示伤害数字（可选功能）。

## Acceptance Criteria

- **GIVEN** 物理碰撞层检测到碰撞，**WHEN** 目标不处于无敌状态，**THEN** `process_collision` 返回有效 HitResult
- **GIVEN** 物理碰撞层检测到碰撞，**WHEN** 目标 `is_invincible()=true`，**THEN** `process_collision` 返回 null
- **GIVEN** hitbox #1 已命中目标 A，**WHEN** 同一 hitbox 再次碰撞目标 A，**THEN** `is_already_hit` 返回 true，碰撞被忽略
- **GIVEN** 游剑式命中，**WHEN** `calculate_damage("you", target)`，**THEN** 返回 1
- **GIVEN** 钻剑式命中，**WHEN** `calculate_damage("zuan", target)`，**THEN** 返回 3
- **GIVEN** 绕剑式命中，**WHEN** `calculate_damage("rao", target)`，**THEN** 返回 2
- **GIVEN** 有效命中发生，**WHEN** `hit_landed` 信号触发，**THEN** 信号包含完整的 HitResult 数据
- **GIVEN** 攻击者=目标（自伤碰撞），**WHEN** `process_collision` 被调用，**THEN** 返回 null

## Open Questions

- 伤害公式是否需要考虑距离衰减？（当前设计为固定伤害，不考虑距离）对于钻剑式穿透可能需要——远距离穿透伤害是否应降低？
- 命中去重的时间窗口是否需要？当前设计为 hitbox 生命周期内去重。如果 hitbox 持续时间很长（如绕剑式护身），可能需要时间窗口限制。
- 是否需要暴击/弱点系统？对于 Demo 阶段不需要，但完整游戏可能需要为不同敌人类型设置弱点（如石系敌人对钻剑式弱）。