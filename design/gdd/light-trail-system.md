# 流光轨迹系统 (Light Trail System)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 极简即美学 (Pillar 2), 精确即力量 (Pillar 1)

## Overview

**流光轨迹系统**是《归宗》最核心的视觉表达——墨色流光和金色剑气追踪剑尖运动，精确勾勒每一次出招的轨迹。这是"剑招即笔触"（Art Bible Principle 1）的技术实现。

**职责边界：**
- **做**：轨迹生成（根据当前剑式创建 LineRenderer）、轨迹更新（每帧添加新点）、轨迹淡出（逐渐消失）
- **不做**：剑招逻辑（三式剑招系统）、碰撞检测（物理碰撞层）、材质反应（命中反馈）

## Player Fantasy

**玩家看到的是自己"画"出的水墨——每一招都是一笔墨。**

玩家感受到的是：
- 游剑式出招时，金色细线像小蛇一样在空中留下轨迹——灵活、流畅
- 钻剑式出招时，金色光锥在剑尖凝聚——蓄力、锐利
- 绕剑式出招时，墨色流光绕着身体画圆——防御、包围
- 万剑归宗时，万道金色轨迹同时飞舞——壮观但不混乱

**支柱对齐：**
- Pillar 2（极简即美学）：流光轨迹是画面中最亮的元素——"以留白衬笔触"
- Pillar 1（精确即力量）：轨迹精确反映剑尖运动——玩家能通过轨迹看到自己的"笔法"

## Detailed Design

### Core Rules

1. 流光轨迹系统监听三式剑招系统的 `form_activated` 信号，根据当前剑式创建对应颜色/形状的轨迹
2. 每条轨迹使用 Godot 的 MeshInstance3D + ImmediateMesh 或 LineRenderer 实现——比粒子系统省 90% 性能
3. 轨迹由一系列点组成，每帧添加剑尖当前位置到轨迹末尾
4. 轨迹有淡出机制——旧的点逐渐变透明直到消失
5. 万剑归宗时，轨迹数量暴增但使用同一材质——1 个 draw call 批量渲染

### Trail Types by Form

| 剑式 | 轨迹颜色 | 轨迹形状 | 宽度 | 淡出时间 | 说明 |
|------|---------|---------|------|---------|------|
| 游剑式 | 金墨 (#D4A843) | 细长曲线 | 0.05m | 0.5 秒 | 金色细线，像小蛇缠绕 |
| 钻剑式 | 金白 (#F5E6B8) | 短促光锥 | 0.1m | 0.3 秒 | 高密度粒子状 |
| 绕剑式 | 墨黑 (#1A1A2E) | 环形弧线 | 0.08m | 0.8 秒 | 墨色圆弧，护身 |
| 万剑归宗 | 金墨 (#D4A843) | 所有类型的混合 | 0.05m | 1.0 秒 | 万道轨迹同时飞舞 |

### Trail Lifecycle

| 阶段 | 行为 | 时长 |
|------|------|------|
| **生成** | 收到 `form_activated` 信号，创建 LineRenderer，设置材质和颜色 | 1 帧 |
| **更新** | 每帧添加剑尖位置到轨迹点列表 | 持续到剑招结束 |
| **冻结** | 收到 `form_finished` 信号，停止添加新点 | 1 帧 |
| **淡出** | 轨迹点从新到旧逐渐变透明 | 0.3–1.0 秒 |
| **销毁** | 所有点完全透明后销毁节点 | 自动 |

### Interactions with Other Systems

**对外发出的接口：**

| 接口 | 类型 | 说明 | 接收系统 |
|------|------|------|---------|
| `create_trail(form: String, start_pos: Vector3)` | 创建 | 创建指定剑式的轨迹 | 三式剑招系统 |
| `update_trail(trail_id: int, pos: Vector3)` | 更新 | 更新轨迹点位置 | 三式剑招系统 |
| `finish_trail(trail_id: int)` | 结束 | 冻结并开始淡出 | 三式剑招系统 |
| `create_myriad_trails(count: int, positions: Array)` | 创建 | 批量创建万剑归宗轨迹 | 连击/万剑归宗 |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 三式剑招系统 | `form_activated` | 创建对应颜色的轨迹 |
| 三式剑招系统 | `form_finished` | 冻结轨迹，开始淡出 |
| 连击/万剑归宗 | 万剑归宗触发 | 批量创建万道金色轨迹 |
| 着色器/渲染 | 材质系统 | 获取/创建轨迹材质 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `create_trail` | `create_trail(form: String, start_pos: Vector3)` | `int` | 创建轨迹，返回 ID |
| `update_trail` | `update_trail(trail_id: int, pos: Vector3)` | `void` | 添加轨迹点 |
| `finish_trail` | `finish_trail(trail_id: int)` | `void` | 冻结并淡出 |
| `create_myriad_trails` | `create_myriad_trails(count: int, positions: Array)` | `Array[int]` | 批量创建万剑归宗轨迹 |
| `get_active_trail_count` | `get_active_trail_count()` | `int` | 获取活跃轨迹数量 |

## Formulas

**轨迹点密度：**

`points_per_second = target_fps / point_interval_frames`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 目标帧率 | `target_fps` | int | 30–60 | 游戏帧率 |
| 点间隔帧数 | `point_interval_frames` | int | 1–3 | 每隔几帧添加一个点 |

**输出：** 20–60 点/秒。点太密=性能差，点太稀=轨迹不流畅。

**万剑归宗轨迹数上限：**

`max_trails = min(myriad_count, performance_budget / points_per_trail)`

**默认：** 50 条轨迹（万剑归宗的"万道"是修辞，实际 50 条足够壮观）。

## Edge Cases

- **如果剑招执行时间极短**（如 0.05 秒）：轨迹可能只有 1-3 个点——仍创建轨迹，但视觉上可能只是一个点。
- **如果同时有超过 50 条活跃轨迹**：停止创建新轨迹，不崩溃。
- **如果轨迹节点在淡出中被意外销毁**：安全检查后跳过更新。
- **如果万剑归宗时轨迹数量超出性能预算**：减少点密度（`point_interval_frames` 增大到 3）。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 三式剑招系统 | 硬依赖 | `form_activated`, `form_finished` 信号 |
| 着色器/渲染 | 硬依赖 | `create_trail_material()` — 获取轨迹材质 |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 命中反馈 | 软依赖 | 轨迹可视但不影响判定 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `trail_width_you` | 0.05m | 0.03–0.1m | 游剑式轨迹宽度 |
| `trail_width_zuan` | 0.1m | 0.05–0.2m | 钻剑式轨迹宽度 |
| `trail_width_rao` | 0.08m | 0.05–0.15m | 绕剑式轨迹宽度 |
| `fade_time_you` | 0.5s | 0.3–1.0s | 游剑式淡出时间 |
| `fade_time_zuan` | 0.3s | 0.2–0.5s | 钻剑式淡出时间 |
| `fade_time_rao` | 0.8s | 0.5–1.5s | 绕剑式淡出时间 |
| `point_interval_frames` | 1 | 1–3 | 轨迹点间隔帧数 |
| `max_concurrent_trails` | 50 | 20–100 | 最大同时活跃轨迹数 |
| `myriad_trail_count` | 50 | 20–100 | 万剑归宗轨迹数量 |

## Visual/Audio Requirements

**本系统直接产生视觉效果——流光轨迹是游戏最核心的视觉资产。**

Art Bible 定义：
- 绕剑式墨色轨迹：LineRenderer + 墨色材质（Section 8: Asset Standards）
- 游剑式金色细线：LineRenderer + 金色材质
- 钻剑式光锥：MeshInstance + 缩放动画
- 万剑归宗流光：LineRenderer 批量渲染，同一材质，1 个 draw call

## UI Requirements

**无。** 本系统不包含 UI。

## Acceptance Criteria

- **GIVEN** 游剑式激活，**WHEN** `create_trail("you", sword_tip_pos)` 被调用，**THEN** 金色细线轨迹从剑尖位置开始生成
- **GIVEN** 轨迹正在更新，**WHEN** 每帧调用 `update_trail(id, new_pos)`，**THEN** 轨迹点列表添加新位置
- **GIVEN** 剑式结束，**WHEN** `finish_trail(id)` 被调用，**THEN** 轨迹冻结，在 `fade_time` 内逐渐淡出
- **GIVEN** 万剑归宗触发，**WHEN** `create_myriad_trails(50, positions)` 被调用，**THEN** 50 条金色轨迹同时生成
- **GIVEN** 活跃轨迹数 = 50，**WHEN** 再次创建轨迹，**THEN** 被拒绝（不超过上限）
- **GIVEN** 所有轨迹点完全透明，**WHEN** 淡出完成，**THEN** 轨迹节点自动销毁
- **GIVEN** 轨迹使用同一材质批量渲染，**WHEN** 50 条轨迹同时活跃，**THEN** draw call ≤ 1（轨迹材质）+ 1（场景）+ ... ≤ 50 总计

## Open Questions

- 轨迹点的存储是用数组还是 PoolVector3Array？后者在 Godot 4.6 中的性能更好。
- 万剑归宗的轨迹是预生成路径还是实时跟随剑尖？预生成更可控但缺乏动态感。
- 轨迹是否需要与环境交互？（如轨迹经过岩石时在岩石表面留下墨迹）——当前设计不支持，但概念中的"材质交互"暗示了这个可能性。