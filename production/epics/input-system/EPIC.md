# Epic: 输入系统 (Input System)

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: 输入系统模块
> **Status**: Ready
> **Stories**: 3 stories (2 Logic, 1 Integration) — see below

## Overview

输入系统是《归宗》所有玩家操作的入口。它将硬件输入（键盘/鼠标/手柄）映射为抽象游戏动作，提供输入缓冲确保精确连招不被吞掉，并适配 Web 平台的输入延迟特性。三式剑招各有独立按键（J/K/L），三键独立同时可用——这是"精确即力量"支柱的物理基础。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Input System Architecture | Autoload singleton, `_input()` callback, single-element input buffer | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-INPUT-001 | Input mapping: hardware → abstract game actions | ADR-0002 ✅ |
| TR-INPUT-002 | Input buffering: capture inputs during non-interruptible windows | ADR-0002 ✅ |
| TR-INPUT-003 | Three-form independent keys (J/K/L), simultaneous press handling | ADR-0002 ✅ |
| TR-INPUT-004 | Platform adaptation: Web input latency via `_input()` | ADR-0002 ✅ |
| TR-INPUT-005 | Action enable/disable for state-based filtering | ADR-0002 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/input-system.md` are verified
- All Logic stories have passing test files in `tests/unit/input-system/`
- Integration story has playtest evidence confirming input responsiveness

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Input Mapping & Query API | Logic | Ready | ADR-0002 |
| 002 | Input Buffering | Logic | Ready | ADR-0002 |
| 003 | Platform & Device Adaptation | Integration | Ready | ADR-0002 |

## Next Step

Run `/create-stories input-system` to break this epic into implementable stories.
