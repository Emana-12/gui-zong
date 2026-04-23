# 游戏状态管理 (Game State Manager)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 无（纯基础设施）
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS (resolved) 2026-04-21

## Overview

**游戏状态管理**是《归宗》的底层状态协调枢纽。它管理游戏从启动到退出的完整生命周期——标题画面、战斗、波次间歇、死亡、重启——并通过信号/事件通知所有依赖系统状态变化。

它不存储任何具体游戏数据（分数在计分系统、连击在连击系统、生命值在玩家控制器），只负责**状态间的协调和生命周期**。每个状态定义了：哪些系统应该活跃、哪些应该休眠、状态间转换的条件和时序。

**职责边界：**
- **做**：定义游戏阶段（标题/战斗/间歇/死亡/重启）、管理状态转换条件、发出状态变化信号、管理全局暂停
- **不做**：存储游戏数据、管理UI流程、处理输入映射

**为什么需要它：** 没有集中的状态管理，每个系统都需要自己判断"当前游戏在什么阶段"——这会导致逻辑分散、状态不一致、和转换时序混乱。一个统一的状态枢纽让所有系统只需监听状态变化信号，而不关心转换逻辑。

## Player Fantasy

**玩家不会注意到游戏状态管理的存在——这正是它的成功标准。**

玩家感受到的是：
- 死亡后画面墨化为静态水墨画，然后自然地重新晕开——没有卡顿、没有闪烁、没有"我在哪"的困惑
- 波次间歇时战斗暂停，环境安静下来——节奏感来自状态的明确切换
- 按下重启后立刻回到战斗——无加载、无等待，"再来一次"的冲动不被打断

**情感目标：** 流畅感。玩家应该感觉游戏像一气呵成的水墨画——状态之间的过渡是自然的呼吸，不是生硬的切换。

**设计测试：** 如果玩家在任何一个状态转换时感到"卡了一下"或"不知道现在是什么状态"，状态管理就有问题。

**支柱对齐：** 间接服务于所有支柱——没有流畅的状态流转，精确打击（Pillar 1）的节奏感会被打断，极简体验（Pillar 2）会被状态混乱破坏。

## Detailed Design

### Core Rules

1. 游戏状态管理是一个有限状态机（FSM），管理 5 个游戏状态：**标题(TITLE)**、**战斗(COMBAT)**、**间歇(INTERMISSION)**、**死亡(DEATH)**、**重启(RESTART)**
2. 任何时刻只有一个活跃状态
3. 状态转换通过 `change_state(new_state)` 方法触发，该方法验证转换是否合法，然后执行退出旧状态→进入新状态的流程
4. 每个状态转换发出 `state_changed(old_state, new_state)` 信号，所有依赖系统监听此信号
5. 状态转换是即时的（单帧完成），但视觉过渡由各系统自行处理（如墨化动画由 HUD 系统负责）
6. 全局暂停通过 `pause_game()` / `resume_game()` 控制，独立于状态机——暂停时不改变当前状态

### States and Transitions

| 状态 | 进入条件 | 退出条件 | 活跃系统 | 休眠系统 |
|------|---------|---------|---------|---------|
| **TITLE** | 游戏启动 | 玩家按下开始键 | HUD/UI（标题菜单） | 所有战斗系统 |
| **COMBAT** | 标题开始 / 间歇结束 | 玩家生命值归零 | 所有战斗系统、HUD | 标题菜单 |
| **INTERMISSION** | 一波敌人清完 | 自动过渡（计时器）或玩家输入 | HUD（间歇UI）、音频（氛围音） | 敌人生成、碰撞检测 |
| **DEATH** | 玩家生命值归零 | 玩家按下重启键 | HUD（死亡画面）、音频（死亡音效） | 所有战斗系统 |
| **RESTART** | 死亡后重启输入 | 场景重置完成（< 1帧）→ COMBAT | 无（瞬时状态） | 无 |

**合法转换矩阵：**

| 从 \ 到 | TITLE | COMBAT | INTERMISSION | DEATH | RESTART |
|---------|-------|--------|-------------|-------|---------|
| **TITLE** | — | ✓ | ✗ | ✗ | ✗ |
| **COMBAT** | ✗ | — | ✓ | ✓ | ✗ |
| **INTERMISSION** | ✗ | ✓ | — | ✗ | ✗ |
| **DEATH** | ✗ | ✗ | ✗ | — | ✓ |
| **RESTART** | ✗ | ✓ | ✗ | ✗ | — |

**设计决策说明：**
- **COMBAT → RESTART 被禁止**：不允许从战斗中直接重启。这是"纯技巧"理念的体现——不允许"打不过就重来"的逃避行为。玩家必须面对死亡，然后才能重启。
- **INTERMISSION → DEATH 被禁止**：间歇状态下不处理生命值变化，玩家不会受到伤害。如果极端情况下生命值归零（理论上不应发生），忽略该事件。

**核心循环：** TITLE → COMBAT → (INTERMISSION ↔ COMBAT 循环) → DEATH → RESTART → COMBAT → ...

### Interactions with Other Systems

**对外发出的信号：**

| 信号 | 参数 | 触发时机 | 接收系统 |
|------|------|---------|---------|
| `state_changed` | `(old_state: State, new_state: State)` | 每次状态转换 | 所有依赖系统 |
| `game_paused` | `(paused: bool)` | 暂停/恢复 | HUD/UI, 音频 |
| `wave_completed` | `(wave_number: int)` | 一波敌人清完 | 竞技场波次, 计分 |
| `player_died` | `()` | 玩家生命值归零 | HUD, 音频, 计分 |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 输入系统 | 玩家按下开始键（TITLE 状态下） | TITLE → COMBAT |
| 敌人系统 | 当前波次所有敌人死亡 | COMBAT → INTERMISSION |
| 玩家控制器 | 玩家生命值归零 | COMBAT → DEATH |
| 输入系统 | 玩家按下重启键（DEATH 状态下） | DEATH → RESTART → COMBAT |
| 竞技场波次 | 间歇计时器到期 | INTERMISSION → COMBAT |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `change_state` | `change_state(new_state: State)` | `bool`（是否成功） | 触发状态转换。非法转换返回 false |
| `get_current_state` | `get_current_state()` | `State` | 返回当前活跃状态 |
| `pause_game` | `pause_game()` | `void` | 全局暂停（不改变状态） |
| `resume_game` | `resume_game()` | `void` | 恢复暂停 |
| `is_paused` | `is_paused()` | `bool` | 返回是否处于暂停状态 |

所有方法通过 Godot 的 `signal` 机制广播状态变化——同一帧内所有监听系统自然收到信号。

## Formulas

**无。** 游戏状态管理是纯状态机——状态转换基于事件触发，不涉及数值计算。

相关数值由其他系统管理：
- 波次间歇时长 → 竞技场波次系统的 Tuning Knob
- 死亡后重启延迟 → 本系统的 Tuning Knob（见下文）

## Edge Cases

- **如果玩家在状态转换动画中按下重启键**：忽略输入，直到 DEATH 状态完全进入后才接受重启输入。防止"黑屏闪切"。
- **如果玩家生命值在 INTERMISSION 状态归零**（理论上不应发生，但需防御）：忽略，INTERMISSION 状态下不处理生命值变化。间歇状态下敌人不攻击，玩家不应受到伤害。
- **如果两个状态转换在同一帧触发**（如最后一击同时击杀敌人和玩家）：优先处理 DEATH（玩家死亡优先级高于波次完成）。
- **如果 RESTART 状态的场景重置失败**：回退到 TITLE 状态，显示错误提示而非崩溃。
- **如果 `change_state` 被调用时传入当前状态**：忽略，不发出信号，不执行转换。
- **如果游戏在 TITLE 状态下收到 `wave_completed` 信号**：忽略，标题状态下不处理战斗事件。
- **Web 平台焦点丢失**：浏览器标签页切到后台时自动暂停（`pause_game()`），恢复时自动恢复（`resume_game()`）。

## Dependencies

### 上游依赖（本系统依赖）

无。游戏状态管理是 Foundation 层零依赖系统。

### 下游依赖（其他系统依赖本系统）

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 敌人系统 | 硬依赖 | 监听 `state_changed` 信号，在 COMBAT 时生成敌人，其他状态停止生成 |
| HUD/UI 系统 | 硬依赖 | 监听 `state_changed` 信号，根据状态切换 UI 显示（标题菜单/战斗 HUD/间歇/死亡画面） |
| 竞技场波次系统 | 硬依赖 | 监听 `state_changed` 和 `wave_completed` 信号，管理波次节奏 |
| 关卡/场景管理 | 硬依赖 | 监听 `state_changed` 信号，在 RESTART 时重置场景 |
| 计分系统 | 软依赖 | 监听 `player_died` 和 `wave_completed` 信号记录数据，但不依赖状态管理才能运行 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `death_delay` | 0.5 秒 | 0.2–2.0 秒 | 死亡状态进入后，接受重启输入的最小等待时间。太短=误触重启，太长=玩家焦虑 |
| `restart_transition` | 0.1 秒 | 0–0.5 秒 | RESTART 状态的持续时间（场景重置的缓冲）。0 = 瞬切 |
| `intermission_auto_advance` | false | true/false | 间歇是否自动过渡到下一波（true=计时器自动，false=等待玩家输入） |
| `intermission_duration` | 3.0 秒 | 1.0–10.0 秒 | 仅当 `intermission_auto_advance=true` 时生效。间歇到下一波的等待时间 |
| `pause_on_focus_loss` | true | true/false | Web 平台标签页切到后台时是否自动暂停 |

**`intermission_duration` 所有权：** 此值由竞技场波次系统拥有和管理。游戏状态管理系统在收到波次系统的触发信号时执行转换，不自行管理间歇计时器。两个系统之间的接口是信号（`wave_completed` 和状态转换触发），而非共享数据。

## Visual/Audio Requirements

**本系统不直接产生视觉/音频效果。** 状态变化的视觉/音频表达由各 Presentation 系统负责：

| 状态转换 | 视觉效果（由 HUD/UI 负责） | 音频效果（由音频系统负责） |
|---------|------------------------|------------------------|
| TITLE → COMBAT | 标题菜单淡出，战斗 HUD 淡入 | BGM 切换到战斗曲 |
| COMBAT → INTERMISSION | 战斗 HUD 半透明化 | BGM 渐弱，氛围音渐入 |
| COMBAT → DEATH | 画面墨化为静态水墨画（3-4 秒） | BGM 停止，死亡音效 |
| DEATH → RESTART | 墨画重新晕开（2 秒） | 无或短音效 |
| INTERMISSION → COMBAT | 敌人轮廓从远景变实 | BGM 渐强 |

## UI Requirements

**本系统不直接管理 UI。** UI 状态的切换由 HUD/UI 系统监听 `state_changed` 信号后自行处理。

## Acceptance Criteria

- **GIVEN** 游戏启动，**WHEN** 初始化完成，**THEN** 当前状态为 TITLE
- **GIVEN** TITLE 状态，**WHEN** 玩家按下开始键，**THEN** 状态转换为 COMBAT，发出 `state_changed(TITLE, COMBAT)` 信号
- **GIVEN** COMBAT 状态，**WHEN** 所有敌人被击杀，**THEN** 状态转换为 INTERMISSION，发出 `wave_completed` 信号
- **GIVEN** COMBAT 状态，**WHEN** 玩家生命值归零，**THEN** 状态转换为 DEATH，发出 `player_died` 信号
- **GIVEN** DEATH 状态，**WHEN** 等待时间 ≥ `death_delay` 且玩家按下重启键，**THEN** 状态经 RESTART 瞬时转换为 COMBAT
- **GIVEN** DEATH 状态，**WHEN** 等待时间 < `death_delay` 且玩家按下重启键，**THEN** 输入被忽略，状态不变
- **GIVEN** INTERMISSION 状态且 `intermission_auto_advance=false`，**WHEN** 玩家输入触发，**THEN** 状态转换为 COMBAT
- **GIVEN** INTERMISSION 状态且 `intermission_auto_advance=true`，**WHEN** 计时器达到 `intermission_duration`，**THEN** 状态转换为 COMBAT
- **GIVEN** 任意状态，**WHEN** `change_state` 传入当前状态，**THEN** 无操作，不发出信号
- **GIVEN** COMBAT 状态，**WHEN** 同一帧内玩家死亡且波次完成，**THEN** 优先处理 DEATH
- **GIVEN** 任意非 TITLE 状态，**WHEN** 收到 `wave_completed` 信号，**THEN** 仅在 COMBAT 状态下处理，其他状态忽略
- **GIVEN** Web 平台运行中，**WHEN** 浏览器标签页切到后台，**THEN** 自动调用 `pause_game()`
- **GIVEN** 已暂停，**WHEN** 浏览器标签页回到前台，**THEN** 自动调用 `resume_game()`
- **GIVEN** 任意状态转换，**WHEN** 转换完成，**THEN** 所有依赖系统在同一帧内收到 `state_changed` 信号

## Open Questions

- 波次间歇是否自动过渡（`intermission_auto_advance` 的默认值）取决于竞技场波次系统的设计——建议在设计该系统时确认
- 是否需要"暂停"作为独立状态？当前设计用 `pause_game()` 独立于状态机处理。如果后续需要"暂停时显示特定 UI"，可能需要将暂停提升为状态
- RESTART 状态中场景重置的具体流程（重置哪些数据、保留哪些数据）取决于关卡/场景管理系统的设计
