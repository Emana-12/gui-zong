# ADR-0002: 输入系统架构与 Web 适配

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Input |
| **Knowledge Risk** | MEDIUM — 变参函数支持（4.5），Web 端输入延迟特性 |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md` |
| **Post-Cutoff APIs Used** | None — 使用标准 `Input` 类和 `_input()` 回调 |
| **Verification Required** | Web 端 `_input()` vs `_process()` 的实际延迟差异需要在 Chrome/Firefox/Safari 中测试 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（游戏状态管理——输入系统需要监听状态变化以启用/禁用动作组） |
| **Enables** | ADR-0006（三式剑招系统——依赖输入系统的精确时序） |
| **Blocks** | 玩家控制器、三式剑招系统实现 |
| **Ordering Note** | 必须在三式剑招系统之前 Accepted |

## Context

### Problem Statement
《归宗》是一款精确打击的动作游戏——"精确即力量"支柱要求输入延迟最小化。Web 平台的浏览器输入轮询有额外延迟（~1-2 帧），需要特殊处理。三式剑招需要输入缓冲来确保连招的流畅性。

### Constraints
- Web 平台：浏览器输入轮询额外延迟 1-2 帧
- 三键独立：游/钻/绕各有独立输入，三键可同时可用
- 输入缓冲：招式执行窗口内提前按下的输入需要被捕获
- Godot 4.6.2 + GDScript

### Requirements
- 键盘/鼠标 + 手柄双输入源支持
- 输入缓冲窗口（默认 100ms）
- Web 平台最小化输入延迟
- 游戏状态变化时启用/禁用对应动作组

## Decision

使用 **Godot 内置 Input 单例 + `_input()` 回调 + 输入缓冲队列** 模式。

核心架构：
1. **使用 `_input()` 而非 `_process()` 捕获输入** — `_input()` 在渲染帧之前调用，比 `_process()` 少 1 帧延迟
2. **输入映射通过 Godot 的 Input Map**（Project Settings）定义——硬件按键映射到抽象动作名
3. **输入缓冲使用单元素队列**——只保留最近的一个缓冲输入，新输入覆盖旧输入
4. **动作组管理**——游戏状态变化时通过 `enable_action()` 启用/禁用对应动作组
5. **Web AudioContext 初始化**——首次用户交互时调用 `AudioServer` 初始化

### Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│                  InputSystem (Autoload)               │
│                                                      │
│  ┌─────────────┐    ┌──────────────────┐            │
│  │ _input()    │───→│ Input Map        │            │
│  │ (Web 低延迟)│    │ J → attack_you   │            │
│  └─────────────┘    │ K → attack_zuan  │            │
│                     │ L → attack_rao   │            │
│                     │ WASD → move_*    │            │
│                     │ Space → dodge    │            │
│                     └──────────────────┘            │
│                              │                      │
│                              ▼                      │
│                     ┌──────────────────┐            │
│                     │ Input Buffer     │            │
│                     │ (单元素队列)      │            │
│                     │ 容量=1           │            │
│                     │ 窗口=6帧(100ms)  │            │
│                     └──────────────────┘            │
│                              │                      │
│                              ▼                      │
│  ┌──────────────────────────────────────┐           │
│  │ Public API                           │           │
│  │ is_action_pressed()                  │           │
│  │ is_action_just_pressed()             │           │
│  │ get_move_direction()                 │           │
│  │ get_buffered_action()                │           │
│  │ enable_action(action, enabled)       │           │
│  └──────────────────────────────────────┘           │
└──────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
  ┌─────────────┐         ┌──────────────┐
  │ 玩家控制器  │         │ 三式剑招系统 │
  └─────────────┘         └──────────────┘
```

### Key Interfaces

```gdscript
# InputSystem.gd (Autoload 单例)

# 缓冲窗口（帧数）
@export var buffer_window_frames: int = 6  # ≈ 100ms @60fps

var _buffered_action: StringName = &""
var _buffer_frame_count: int = 0
var _disabled_actions: Dictionary = {}

func _input(event: InputEvent) -> void:
    # 使用 _input() 而非 _process() 减少 Web 端延迟
    for action in _all_actions:
        if _disabled_actions.get(action, false):
            continue
        if event.is_action_pressed(action):
            # 检查是否在缓冲窗口内——如果是剑招动作则缓冲
            if action.begins_with("attack_"):
                _buffered_action = action
                _buffer_frame_count = 0

func is_action_pressed(action: StringName) -> bool:
    if _disabled_actions.get(action, false):
        return false
    return Input.is_action_pressed(action)

func is_action_just_pressed(action: StringName) -> bool:
    if _disabled_actions.get(action, false):
        return false
    return Input.is_action_just_pressed(action)

func get_move_direction() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func get_buffered_action() -> StringName:
    if _buffer_frame_count >= buffer_window_frames:
        _buffered_action = &""
        return &""
    return _buffered_action

func enable_action(action: StringName, enabled: bool) -> void:
    _disabled_actions[action] = not enabled

func _process(_delta: float) -> void:
    # 更新缓冲帧计数
    if _buffered_action != &"":
        _buffer_frame_count += 1
        if _buffer_frame_count >= buffer_window_frames:
            _buffered_action = &""
```

## Alternatives Considered

### Alternative 1: 全部使用 `_process()` 读取输入
- **Description**: 在 `_process()` 中每帧调用 `Input.is_action_just_pressed()`
- **Pros**: 简单直接，所有逻辑在同一回调中
- **Cons**: Web 端额外增加 1 帧延迟——`_process()` 在渲染帧之后调用，而 `_input()` 在渲染帧之前
- **Rejection Reason**: "精确即力量"支柱要求最小化输入延迟

### Alternative 2: 多元素输入缓冲队列
- **Description**: 缓冲区容量 > 1，保留多个提前输入
- **Pros**: 连招输入更宽松
- **Cons**: 玩家可能无脑按键产生不可控的连招——违反"精确即力量"支柱
- **Rejection Reason**: 缓冲区容量=1 确保每次必须精确输入下一个招式

## Consequences

### Positive
- `_input()` 回调将 Web 端输入延迟降到最低（只受浏览器轮询影响，无系统额外延迟）
- 输入缓冲确保连招的精确性——玩家在招式执行窗口内提前输入不会被吞掉
- 动作组管理确保菜单状态和战斗状态的输入隔离

### Negative
- `_input()` 和 `_process()` 分离——输入捕获在 `_input()` 中，状态更新在 `_process()` 中，需要确保时序正确
- 缓冲区容量=1 对新手可能太严格——需要新手引导解释缓冲机制

### Risks
- **Web 端 `_input()` 的实际延迟**：不同浏览器可能有差异。→ 缓解：在 Chrome/Firefox/Safari 中分别测试，记录各浏览器的延迟数据。
- **手柄断开时的输入状态**：手柄突然断开可能导致"按键卡住"。→ 缓解：监听手柄连接/断开事件，断开时重置输入状态。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-system.md | Core Rules 1-6 | `_input()` 捕获 + Input Map 映射 + 缓冲机制 + 动作组管理 |
| input-system.md | Input Buffering | 单元素缓冲队列 + 6 帧窗口 |
| input-system.md | Platform Adaptation | `_input()` 代替 `_process()` |
| input-system.md | Public API | 所有查询接口和缓冲接口 |

## Performance Implications
- **CPU**: 极低——`_input()` 每帧只处理输入事件，不做重计算
- **Memory**: 极低——缓冲区只有 1 个动作名
- **Load Time**: 无影响
- **Network**: N/A

## Validation Criteria
- Web 端使用 `_input()` 后输入延迟 ≤ 浏览器原生延迟
- 输入缓冲在 100ms 窗口内正确捕获提前输入
- 压力下（快速连按）不丢失输入
- 动作禁用后正确过滤

## Related Decisions
- ADR-0001（游戏状态管理）—— 输入系统监听状态变化
- ADR-0006（三式剑招系统）—— 使用此 ADR 的输入缓冲
