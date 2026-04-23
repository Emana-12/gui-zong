# 竞技场波次系统 (Arena Wave System)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 三式皆平等 (Pillar 4)

## Overview

**竞技场波次系统**管理敌人生成的节奏——一波接一波，每波引入新的敌人组合，难度持续递增直到玩家死亡。它决定了"再来一波"的动力。

**职责边界：**
- **做**：波次定义（每波敌人类型和数量）、波次触发（生成敌人）、波次完成检测（所有敌人死亡）、难度递增曲线
- **不做**：敌人 AI（敌人系统）、敌人生成位置（本系统决定）、死亡检测（敌人系统负责）

## Player Fantasy

**每一波都是新的挑战——不是刷怪，是升级的考验。**

玩家感受到的是：
- 第一波只有 1-2 个简单敌人——"还挺轻松"
- 第五波出现混合敌人——"得用不同剑式了"
- 第十波极限压力——"这才是真正的考验"

**支柱对齐：** Pillar 4（三式皆平等）——不同波次的敌人组合迫使玩家使用不同剑式。

## Detailed Design

### Core Rules

1. 波次系统监听游戏状态管理的 `state_changed` 信号，在 COMBAT 状态时运行
2. 每波定义为一个敌人生成列表：[{类型, 数量, 生成延迟}, ...]
3. 波次完成条件：当前波所有敌人死亡 → 触发间歇 → 间歇结束 → 下一波
4. 难度递增：每波敌人数量 +1，每 3 波引入新敌人类型
5. 无上限——游戏在玩家死亡时结束，波次理论无限

### Wave Difficulty Curve

| 波次 | 敌人总数 | 敌人类型 | 说明 |
|------|---------|---------|------|
| 1 | 2 | 流动型 ×2 | 入门——简单敌人 |
| 2 | 3 | 流动型 ×2, 松韧型 ×1 | 引入第二种敌人 |
| 3 | 4 | 流动型 ×2, 松韧型 ×2 | 增加数量 |
| 4 | 5 | 流动型 ×2, 松韧型 ×1, 远程型 ×2 | 引入远程型 |
| 5 | 6 | 流动型 ×2, 松韧型 ×2, 远程型 ×2 | 混合组合 |
| 6+ | +1/波 | 逐步引入重甲型、敏捷型 | 难度递增 |

### Interactions

**对外发出的接口：**

| 接口 | 类型 | 说明 |
|------|------|------|
| `get_current_wave()` | 查询 | 当前波次编号 |
| `get_wave_progress()` | 查询 | 当前波进度（已击杀/总数） |
| `wave_completed` | 信号 | 当前波所有敌人死亡 |
| `spawn_enemies(wave_data)` | 触发 | 生成敌人（调用敌人系统） |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 游戏状态管理 | `state_changed` → COMBAT | 开始/继续波次 |
| 敌人系统 | `enemy_died` | 检查波次完成 |
| 游戏状态管理 | `state_changed` → INTERMISSION | 间歇等待 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `get_current_wave` | `get_current_wave()` | `int` | 当前波次编号 |
| `get_wave_progress` | `get_wave_progress()` | `Vector2` | (已击杀数, 总数) |
| `start_wave` | `start_wave(wave_number: int)` | `void` | 开始指定波次 |
| `get_wave_data` | `get_wave_data(wave_number: int)` | `WaveData` | 获取波次定义 |

## Formulas

**波次敌人数量：**

`enemy_count = base_count + floor(wave_number * scaling_factor)`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 基础数量 | `base_count` | int | 2 | 第一波敌人数量 |
| 波次编号 | `wave_number` | int | 1–∞ | 当前波次 |
| 缩放系数 | `scaling_factor` | float | 0.5–1.5 | 每波增加的敌人数 |

**输出：** 波次 1=2, 波次 5=4, 波次 10=7, 波次 20=12。上限受 `max_active_enemies` 约束（默认 10）。

## Edge Cases

- **如果所有敌人在同一帧被击杀**（万剑归宗）：每帧检查存活数，全部为 0 时触发 `wave_completed`。
- **如果敌人数量超出 `max_active_enemies`**：排队等待，前一批死亡后生成下一批。
- **如果间歇期间玩家死亡**：不触发下一波，直接进入 DEATH 状态。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 敌人系统 | 硬依赖 | `spawn_enemy()`, `get_alive_count()`, `enemy_died` 信号 |
| 游戏状态管理 | 硬依赖 | `state_changed` 信号 |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 计分系统 | 硬依赖 | `get_current_wave()` — 波次记录 |
| HUD/UI | 软依赖 | `get_current_wave()`, `get_wave_progress()` — 波次显示 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `base_enemy_count` | 2 | 1–3 | 第一波敌人数量 |
| `scaling_factor` | 0.8 | 0.5–1.5 | 每波增加的敌人数 |
| `max_active_enemies` | 10 | 5–15 | 同时活跃敌人上限 |
| `intermission_duration` | 3.0s | 1.0–10.0s | 波次间歇时长 |
| `intermission_auto_advance` | false | true/false | 是否自动进入下一波 |

## Visual/Audio Requirements

- 波次开始时：远景敌人轮廓变实（Art Bible Section 2）
- 波次完成时：BGM 渐弱，氛围音渐入
- 新敌人类型引入时：短提示（可选）

## UI Requirements

- 波次计数：金色数字 + 墨色装饰（HUD 系统负责）

## Acceptance Criteria

- **GIVEN** 波次 1 开始，**WHEN** `start_wave(1)` 被调用，**THEN** 2 个流动型敌人生成
- **GIVEN** 波次 1 所有敌人死亡，**WHEN** `get_alive_count()=0`，**THEN** `wave_completed` 信号触发
- **GIVEN** 波次 5，**WHEN** 计算敌人数量，**THEN** 2 + floor(5×0.8) = 6 个敌人
- **GIVEN** 活跃敌人 = 10（上限），**WHEN** 新敌人需要生成，**THEN** 排队等待

## Open Questions

- 波次敌人的生成位置如何决定？（随机在竞技场边缘？固定生成点？）
- 是否需要"特殊波次"（如全远程型、全重甲型）来增加变化？
- 难度递增是否有上限？当前设计为无限——但实际体验可能需要在某个波次后降低递增速度。