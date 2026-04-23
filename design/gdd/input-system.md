# 输入系统 (Input System)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 精确即力量 (Pillar 1)

## Overview

**输入系统**是《归宗》所有玩家操作的入口。它将原始的硬件输入（键盘/鼠标/手柄）转化为游戏可用的抽象动作，并提供精确的输入时序控制——这是"精确即力量"支柱的物理基础。

**职责边界：**
- **做**：输入映射（硬件→动作）、输入缓冲（精确时序窗口）、输入状态查询（当前按下/释放）、平台适配（Web 端输入延迟优化）
- **不做**：输入响应逻辑（由玩家控制器处理）、剑招触发逻辑（由三式剑招系统处理）

**为什么需要它：** 没有统一的输入抽象层，每个系统都需要直接处理硬件输入——这会导致映射不一致、时序精度不可控、和 Web 平台适配分散在各处。输入系统确保所有系统通过同一套精确的输入接口工作。

## Player Fantasy

**玩家不会注意到输入系统的存在——但他们会在按下键的瞬间感受到响应。**

玩家感受到的是：
- 按下攻击键时，剑招在下一帧就启动——没有可感知的延迟
- 连续输入三式时，每一次按键都被精确捕获——没有丢失的输入
- 在 Web 浏览器中玩游戏时，手感和原生平台一样精确——没有"Web 游戏特有的黏滞感"

**情感目标：** 即时感。玩家应该感觉自己的手指和剑之间没有障碍——按键即出招，松键即收招。

**设计测试：** 如果玩家在任何一个操作时感到"按了但没反应"或"反应慢了半拍"，输入系统就有问题。

**支柱对齐：** 直接服务于"精确即力量"(Pillar 1)——没有精确的输入捕获，精确打击就无从谈起。玩家的"精确"建立在输入系统的"精确"之上。

## Detailed Design

### Core Rules

1. 输入系统将原始硬件输入（键盘按键/鼠标按钮/手柄按钮+摇杆）映射为抽象的**游戏动作**（Game Actions）
2. 游戏动作分为两类：**即时动作**（按下即触发，如攻击、闪避）和**持续状态**（按住期间为真，如移动方向）
3. 三式剑招各有独立的即时动作映射：`attack_you`（游剑式）、`attack_zuan`（钻剑式）、`attack_rao`（绕剑式），三键独立，同时按下则最后按下的生效
4. 输入缓冲系统捕获在**招式不可打断窗口内**按下的动作，在窗口结束后自动执行——确保精确的连招输入不会被吞掉
5. 输入系统每帧（`_process`）更新一次输入状态，在帧开始时提供给所有依赖系统查询
6. Web 平台通过 Godot 的内置输入系统自动处理 COOP/COEP 约束下的输入延迟，输入系统在此基础上不增加额外延迟层

### Input Actions（游戏动作列表）

| 动作名称 | 类型 | 默认键盘映射 | 默认手柄映射 | 说明 |
|---------|------|------------|------------|------|
| `move_forward` | 持续 | W | 左摇杆上 | 前进 |
| `move_back` | 持续 | S | 左摇杆下 | 后退 |
| `move_left` | 持续 | A | 左摇杆左 | 左移 |
| `move_right` | 持续 | D | 左摇杆右 | 右移 |
| `dodge` | 即时 | Space | B/Circle | 闪避 |
| `attack_you` | 即时 | J | X/Square | 游剑式（金色细线缠绕） |
| `attack_zuan` | 即时 | K | Y/Triangle | 钻剑式（金色光锥穿透） |
| `attack_rao` | 即时 | L | A/Cross | 绕剑式（墨色流光护身） |
| `confirm` | 即时 | Enter / Space | A/Cross | 菜单确认 |
| `cancel` | 即时 | Escape | B/Circle | 菜单取消/暂停 |
| `restart` | 即时 | R | Start | 死亡后重启 |

### Input Buffering（输入缓冲）

**缓冲目的：** 在招式执行期间（不可打断窗口），玩家可能提前按下下一个动作。缓冲系统确保这些输入不被丢失。

**缓冲规则：**
- 缓冲窗口 = 招式执行时间的最后 N 帧（可调，默认 6 帧 ≈ 100ms @60fps）
- 只缓冲**即时动作**，不缓冲持续状态（移动方向始终实时更新）
- 缓冲区容量 = 1（只保留最近的一个缓冲输入，新输入覆盖旧输入）
- 当招式可打断时，立即执行缓冲区中的动作
- 如果缓冲窗口结束时没有新输入，缓冲区清空

**设计决策：** 缓冲区容量为 1 而非队列——避免玩家无脑按键产生不可控的连招。每次必须精确输入下一个招式。

### Platform Adaptation（平台适配）

| 平台 | 输入延迟特性 | 适配策略 |
|------|------------|---------|
| Web (HTML5) | 浏览器输入轮询有额外延迟（~1-2帧） | 使用 Godot 的 `_input()` 而非 `_process()` 捕获输入，减少延迟 |
| Desktop | 原生延迟，可忽略 | 标准处理 |

### Interactions with Other Systems

**对外发出的信号/接口：**

| 接口 | 类型 | 返回值 | 接收系统 |
|------|------|--------|---------|
| `is_action_pressed(action: String)` | 查询 | `bool` | 玩家控制器、三式剑招系统 |
| `is_action_just_pressed(action: String)` | 查询 | `bool` | 玩家控制器、三式剑招系统 |
| `is_action_just_released(action: String)` | 查询 | `bool` | 玩家控制器 |
| `get_move_direction()` | 查询 | `Vector2` | 玩家控制器 |
| `get_buffered_action()` | 查询 | `String or null` | 三式剑招系统 |
| `action_triggered` | 信号 | `(action: String)` | HUD/UI（显示按键提示） |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 玩家 | 按下/释放硬件按键/按钮 | 更新输入状态，触发对应游戏动作 |
| 游戏状态管理 | `state_changed` 信号 | 在 TITLE/DEATH 状态下只响应菜单动作，其他动作被忽略 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `is_action_pressed` | `is_action_pressed(action: String)` | `bool` | 动作当前是否处于按下状态 |
| `is_action_just_pressed` | `is_action_just_pressed(action: String)` | `bool` | 动作在本帧是否刚被按下 |
| `is_action_just_released` | `is_action_just_released(action: String)` | `bool` | 动作在本帧是否刚被释放 |
| `get_move_direction` | `get_move_direction()` | `Vector2` | 当前移动方向（归一化） |
| `get_buffered_action` | `get_buffered_action()` | `String or null` | 获取缓冲区中的动作名，无则返回 null |
| `set_buffer_window` | `set_buffer_window(frames: int)` | `void` | 设置输入缓冲窗口（帧数） |
| `enable_action` | `enable_action(action: String, enabled: bool)` | `void` | 启用/禁用特定动作（用于菜单状态下禁用战斗输入） |

## Formulas

**缓冲窗口计算：**

`buffer_window_frames = ceil(target_buffer_ms / (1000 / target_fps))`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 目标缓冲时间 | `target_buffer_ms` | float | 50–200 ms | 缓冲窗口的毫秒数 |
| 目标帧率 | `target_fps` | float | 30–60 | 游戏目标帧率 |

**输出范围：** 3 帧（200ms @60fps 或 50ms @30fps）到 12 帧（200ms @60fps）

**示例：** 默认 `target_buffer_ms=100`，`target_fps=60` → `buffer_window_frames = ceil(100 / 16.67) = 6 帧`

**Web 平台输入延迟补偿：**

`effective_latency_frames = browser_latency_frames - input_system_latency_frames`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 浏览器延迟 | `browser_latency_frames` | int | 1–3 | 浏览器输入轮询的额外帧数 |
| 输入系统延迟 | `input_system_latency_frames` | int | 0–1 | 输入系统自身的处理延迟（使用 `_input()` 时为 0） |

**输出范围：** 0–3 帧。目标是通过 `_input()` 捕获使 `effective_latency_frames` 最小化。

**示例：** Chrome 浏览器通常有 1-2 帧延迟，使用 `_input()` 后系统延迟为 0 → 有效延迟 1-2 帧。

## Edge Cases

- **如果玩家在同一帧按下多个剑招键（游+钻+绕）**：只执行最后被处理的那个（Godot 输入事件的处理顺序）。提示玩家"每次只按一个剑招键"作为新手引导。
- **如果缓冲区中有输入但当前状态不允许执行**（如死亡状态）：清空缓冲区，不执行。
- **如果玩家在缓冲窗口内快速切换方向键**：移动方向始终实时更新（不缓冲），只有即时动作被缓冲。
- **如果 Web 平台焦点丢失后恢复**：恢复后第一帧的所有输入事件被忽略（防止焦点恢复瞬间的"幽灵输入"）。
- **如果手柄断开连接**：自动切换到键盘输入模式，发出 `input_device_changed` 信号通知 UI。
- **如果键盘和手柄同时输入**：使用最后有输入的设备作为当前输入源（Godot 默认行为）。
- **如果 `enable_action` 禁用了正在被按住的动作**：下一帧 `is_action_pressed` 返回 false，但不触发 `just_released`。

## Dependencies

### 上游依赖（本系统依赖）

无。输入系统是 Foundation 层零依赖系统。直接使用 Godot 内置的 `Input` 类和 `_input()` 回调。

### 下游依赖（其他系统依赖本系统）

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 玩家控制器 | 硬依赖 | 查询 `is_action_pressed`、`get_move_direction`、`is_action_just_pressed`（闪避） |
| 三式剑招系统 | 硬依赖 | 查询 `is_action_just_pressed`（三式触发）、`get_buffered_action`（连招缓冲） |
| HUD/UI 系统 | 软依赖 | 监听 `action_triggered` 信号显示按键提示（可选功能） |
| 游戏状态管理 | 交互依赖 | 输入系统监听 `state_changed` 信号，在不同状态下启用/禁用对应动作组 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `buffer_window_ms` | 100 ms | 50–200 ms | 输入缓冲窗口。太短=连招困难（输入被吞），太长=连招过于宽松（无脑按键） |
| `move_deadzone` | 0.15 | 0.05–0.30 | 手柄摇杆死区。太小=漂移误触，太大=移动不灵敏 |
| `mouse_sensitivity` | 1.0 | 0.5–2.0 | 鼠标灵敏度（如果后续有相机控制需要） |
| `input_cooldown_frames` | 0 | 0–3 | 两次即时动作之间的最小帧数间隔。0=无冷却，可防止按键抖动 |

## Visual/Audio Requirements

**本系统不直接产生视觉/音频效果。** 输入的视觉/音频反馈由下游系统负责：
- 三式剑招系统负责剑招启动的视觉效果（流光轨迹）
- 命中反馈负责命中的音频效果
- HUD/UI 负责按键提示的视觉显示（可选功能）

## UI Requirements

**可选功能（非 MVP）：** HUD 可显示当前按下的剑招键提示（三式图标高亮）。监听 `action_triggered` 信号。可在后续迭代中添加。

## Acceptance Criteria

- **GIVEN** 玩家按下 W 键，**WHEN** 查询 `is_action_pressed("move_forward")`，**THEN** 返回 true
- **GIVEN** 玩家释放 W 键，**WHEN** 查询 `is_action_pressed("move_forward")`，**THEN** 返回 false
- **GIVEN** 玩家按下 J 键（游剑式），**WHEN** 查询 `is_action_just_pressed("attack_you")`，**THEN** 仅在按下后的第一帧返回 true
- **GIVEN** 玩家在招式执行窗口内按下 K 键，**WHEN** 查询 `get_buffered_action()`，**THEN** 返回 "attack_zuan"
- **GIVEN** 缓冲区有动作但游戏处于 DEATH 状态，**WHEN** 缓冲窗口到期，**THEN** 缓冲区清空，动作不执行
- **GIVEN** 玩家同时按下 J 和 K 键，**WHEN** 同一帧内处理，**THEN** 只执行最后被处理的那个剑招
- **GIVEN** 手柄摇杆偏移 < `move_deadzone`，**WHEN** 查询 `get_move_direction()`，**THEN** 返回 Vector2.ZERO
- **GIVEN** 手柄摇杆偏移 ≥ `move_deadzone`，**WHEN** 查询 `get_move_direction()`，**THEN** 返回归一化方向向量
- **GIVEN** Web 平台运行中，**WHEN** 使用 `_input()` 捕获输入，**THEN** 输入延迟 ≤ 浏览器原生延迟（无额外系统延迟）
- **GIVEN** 游戏处于 TITLE 状态，**WHEN** 玩家按下 J 键（游剑式），**WHEN** `is_action_just_pressed("attack_you")` 返回 true，**THEN** 三式剑招系统不应响应（由状态管理过滤）
- **GIVEN** 手柄断开连接，**WHEN** 系统检测到设备变化，**THEN** 自动切换到键盘模式，发出 `input_device_changed` 信号
- **GIVEN** `buffer_window_ms=100` 且 `target_fps=60`，**WHEN** 计算 `buffer_window_frames`，**THEN** 结果为 6 帧

## Open Questions

- 三式剑招是否需要支持鼠标输入（如鼠标左/中/右键分别对应三式）？当前设计只用了键盘 J/K/L 和手柄按钮。如果后续需要鼠标支持，需要添加鼠标映射。
- 输入缓冲窗口的默认值（100ms）是否足够宽松？需要在原型阶段测试实际手感。
- Web 平台的 `_input()` 是否在所有浏览器中都能消除额外延迟？需要在 Chrome/Firefox/Safari 中分别测试。
- 是否需要支持按键重映射（Key Remapping）？对于 Demo 阶段可能不需要，但如果是完整游戏，这是标准功能。
