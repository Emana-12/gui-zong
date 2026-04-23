# ADR-0001: 场景管理与状态流转架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core (Scripting/State Management) |
| **Knowledge Risk** | LOW — GDScript signal 机制和枚举在 LLM 训练数据内 |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md`（信号机制参考） |
| **Post-Cutoff APIs Used** | None — 使用 Godot 标准 signal 和 GDScript 枚举 |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (输入系统), ADR-0005 (物理碰撞), 所有依赖游戏状态的系统 |
| **Blocks** | 所有监听 state_changed 信号的系统实现 |
| **Ordering Note** | 此 ADR 必须最先 Accepted，因为它是 Foundation 层第一个系统 |

## Context

### Problem Statement
《归宗》需要一个统一的游戏状态管理系统，协调 5 个游戏状态（TITLE/COMBAT/INTERMISSION/DEATH/RESTART）之间的流转。所有 18 个系统需要知道当前游戏状态并响应状态变化。

### Constraints
- Web 平台性能：状态管理不能增加可感知的延迟
- Godot 4.6.2 + GDScript
- 18 个系统中有 5 个直接依赖此系统
- 状态转换必须是即时的（单帧完成）
- 全局暂停功能独立于状态机

### Requirements
- 支持 5 个游戏状态的有限状态机
- 合法/非法转换矩阵验证
- 状态变化通过信号广播到所有监听系统
- 全局暂停/恢复（独立于状态机）
- Web 平台标签页焦点变化时自动暂停

## Decision

使用 **Godot 内置 signal + GDScript 枚举 + 有限状态机（FSM）** 模式。

核心架构：
1. **Autoload 单例** `GameStateManager` 作为全局状态管理器
2. **GDScript 枚举** `State` 定义 5 个游戏状态
3. **转换矩阵** `Dictionary` 定义合法转换
4. **Godot signal** `state_changed(old_state, new_state)` 广播状态变化
5. **全局暂停** 通过 `get_tree().paused` 独立控制

### Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│                  GameStateManager (Autoload)          │
│                                                      │
│  ┌─────────────┐    ┌──────────────────┐            │
│  │ State Enum  │───→│ Transition Matrix │            │
│  │ TITLE       │    │ TITLE→COMBAT ✓   │            │
│  │ COMBAT      │    │ COMBAT→DEATH ✓   │            │
│  │ INTERMISSION│    │ DEATH→RESTART ✓  │            │
│  │ DEATH       │    │ ...              │            │
│  │ RESTART     │    └──────────────────┘            │
│  └─────────────┘              │                      │
│         │              change_state(new)             │
│         │                     │                      │
│         ▼                     ▼                      │
│  ┌──────────────┐    ┌────────────────┐             │
│  │ get_current_ │    │ signal:        │             │
│  │ state()      │    │ state_changed  │──→ 广播     │
│  └──────────────┘    └────────────────┘             │
│                                                      │
│  ┌──────────────────────────────────┐               │
│  │ Pause (独立于状态机)              │               │
│  │ pause_game() / resume_game()     │               │
│  │ get_tree().paused = true/false   │               │
│  └──────────────────────────────────┘               │
└──────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
  ┌─────────────┐         ┌──────────────┐
  │ 所有依赖系统 │         │ HUD/UI       │
  │ 监听信号    │         │ 监听信号     │
  └─────────────┘         └──────────────┘
```

### Key Interfaces

```gdscript
# GameStateManager.gd (Autoload 单例)

enum State { TITLE, COMBAT, INTERMISSION, DEATH, RESTART }

signal state_changed(old_state: State, new_state: State)
signal game_paused(paused: bool)

var _current_state: State = State.TITLE
var _is_paused: bool = false

# 合法转换矩阵
var _valid_transitions: Dictionary = {
    State.TITLE: [State.COMBAT],
    State.COMBAT: [State.INTERMISSION, State.DEATH],
    State.INTERMISSION: [State.COMBAT, State.DEATH],
    State.DEATH: [State.RESTART],
    State.RESTART: [State.COMBAT],
}

func change_state(new_state: State) -> bool:
    if new_state == _current_state:
        return false  # 同状态不转换
    if new_state not in _valid_transitions.get(_current_state, []):
        push_warning("Invalid transition: %s → %s" % [_current_state, new_state])
        return false
    var old_state = _current_state
    _current_state = new_state
    state_changed.emit(old_state, new_state)
    return true

func get_current_state() -> State:
    return _current_state

func pause_game() -> void:
    _is_paused = true
    get_tree().paused = true
    game_paused.emit(true)

func resume_game() -> void:
    _is_paused = false
    get_tree().paused = false
    game_paused.emit(false)

func is_paused() -> bool:
    return _is_paused
```

## Alternatives Considered

### Alternative 1: Autoload + 自定义事件总线
- **Description**: 不用 Godot signal，用自定义的事件总线（发布/订阅模式）管理状态通知
- **Pros**: 更灵活的过滤和优先级控制
- **Cons**: 重新发明轮子——Godot signal 已经是发布/订阅模式；额外维护成本；丢失 Godot 编辑器的信号调试支持
- **Rejection Reason**: Godot signal 满足所有需求，无需自定义

### Alternative 2: 状态节点树（每个状态一个节点）
- **Description**: 每个游戏状态用一个 Node 表示，状态切换 = 切换活跃节点
- **Pros**: 状态逻辑封装清晰
- **Cons**: 过度设计——5 个状态不需要节点树；增加了节点管理开销；状态间的共享数据需要额外机制
- **Rejection Reason**: 5 个状态用枚举+FSM 更简洁，节点树适合 10+ 状态的复杂 FSM

## Consequences

### Positive
- 使用 Godot 原生 signal，零额外开销
- Autoload 单例全局可访问，任何系统都可以直接查询状态
- 转换矩阵在代码中显式定义，非法转换被拦截
- 全局暂停通过 `get_tree().paused` 实现，Godot 原生支持

### Negative
- Autoload 单例模式——违反"禁止全局单例滥用"的技术偏好。但状态管理是唯一适合用单例的场景（全局协调枢纽）。
- 信号是"发送即忘"——发送方不确认接收方是否处理了信号。如果需要确认机制，需要额外设计。

### Risks
- **信号风暴**：如果大量系统同时响应 `state_changed`，可能在同一帧产生大量计算。→ 缓解：确保各系统的状态响应逻辑轻量（只切换标志，不做重计算）。
- **状态不一致**：如果某个系统错过了 `state_changed` 信号（如初始化顺序问题）。→ 缓解：系统启动时主动查询 `get_current_state()`，不只依赖信号。

### Conflict Resolutions

**与 ADR-0007（敌人 AI）— COMBAT 状态权威冲突**：ADR-0007 声明"非 COMBAT 状态时所有敌人 AI 停止更新"，隐含了对 COMBAT 状态的控制。已解决：状态权威始终在 ADR-0001 的 `GameStateManager`。ADR-0007 的敌人 AI 在 `_ready()` 中查询 `GameStateManager.get_current_state()` 获取初始状态，之后通过监听 `state_changed` 信号响应变化。ADR-0007 不调用 `change_state()` — 只消费状态，不管理状态。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-manager.md | Core Rules 1-6 | FSM 枚举 + 转换矩阵 + 信号广播 + 暂停独立 |
| game-state-manager.md | Public API | `change_state()`, `get_current_state()`, `pause_game()`, `resume_game()`, `is_paused()` |
| game-state-manager.md | Edge Cases 1-7 | 同状态忽略、非法转换拒绝、暂停独立、Web 焦点处理 |
| player-controller.md | 游戏状态为非 COMBAT 时冻结 | 监听 `state_changed` 信号 |
| enemy-system.md | COMBAT 时运行 AI | 监听 `state_changed` 信号 |
| hud-ui-system.md | 状态切换 UI | 监听 `state_changed` 信号 |

## Performance Implications
- **CPU**: 极低——状态转换是简单的枚举赋值 + 信号发射
- **Memory**: 极低——Autoload 单例 + 枚举，无额外内存开销
- **Load Time**: 无影响——Autoload 在启动时自动初始化
- **Network**: N/A（单机游戏）

## Validation Criteria
- 所有合法转换在 1 帧内完成，信号在同一帧内被所有监听系统收到
- 非法转换被拦截并输出警告日志
- 全局暂停时所有依赖系统正确冻结
- Web 平台标签页切到后台时自动暂停

## Related Decisions
- 此 ADR 是所有其他 ADR 的基础——所有依赖游戏状态的系统都需要此 ADR 先 Accepted
