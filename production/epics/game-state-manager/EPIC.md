# Epic: 游戏状态管理 (Game State Manager)

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-manager.md
> **Architecture Module**: 游戏状态管理模块
> **Status**: Ready
> **Stories**: 3 stories (2 Logic, 1 Integration) — see below
> **⚠️ Note**: Vertical slice 只需 COMBAT/DEATH/RESTART 三状态循环。TITLE 和 INTERMISSION 延后。

## Overview

游戏状态管理是《归宗》的底层状态协调枢纽。它管理游戏从启动到退出的完整生命周期——标题画面、战斗、波次间歇、死亡、重启——并通过信号通知所有依赖系统状态变化。它不存储任何具体游戏数据，只负责状态间的协调和生命周期。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Game State Architecture | 5-state FSM (TITLE/COMBAT/INTERMISSION/DEATH/RESTART), signal-based transitions | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-GAME-001 | 5-state FSM with legal transition matrix | ADR-0001 ✅ |
| TR-GAME-002 | Signal-based state change notification | ADR-0001 ✅ |
| TR-GAME-003 | Global pause management independent of state | ADR-0001 ✅ |
| TR-GAME-004 | Single-frame state transitions with system-level visual transitions | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-state-manager.md` are verified
- All Logic stories have passing test files in `tests/unit/game-state-manager/`
- Integration story has playtest evidence confirming state flow correctness

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | FSM Core & State Transitions | Logic | Complete | ADR-0001 |
| 002 | Intermission & Wave Completion | Logic | Complete | ADR-0001 |
| 003 | Pause & Web Focus | Integration | Ready | ADR-0001 |

## Next Step

Run `/create-stories game-state-manager` to break this epic into implementable stories.
