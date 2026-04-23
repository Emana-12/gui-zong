# Epic: 竞技场波次系统 (Arena Wave System)

> **Layer**: Feature
> **GDD**: design/gdd/arena-wave-system.md
> **Architecture Module**: 竞技场波次模块
> **Status**: Ready
> ## Stories

| Story | Title | Type | TR Coverage | Status |
|-------|-------|------|-------------|--------|
| [Story 001](story-001-wave-generation.md) | 波次生成与公式 | Logic | TR-WAVE-001, TR-WAVE-003 | Ready |
| [Story 002](story-002-wave-lifecycle.md) | 波次生命周期与完成 | Integration | TR-WAVE-002, TR-WAVE-004, TR-WAVE-005 | Ready |

## Overview

竞技场波次系统管理敌人生成的节奏——一波接一波，每波引入新的敌人组合，难度持续递增直到玩家死亡。它决定了"再来一波"的动力。公式生成波次，最大同屏 10 敌人，敌人类型按波次解锁。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0014: 竞技场波次架构 | 公式生成波次, 最大10敌, 加权随机选择, INTERMISSION 状态 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-WAVE-001 | Scaling formula: enemy_count = 2 + floor(wave_number * 0.8) | ADR-0014 ✅ |
| TR-WAVE-002 | Max 10 active enemies + spawn queue for overflow | ADR-0014 ✅ |
| TR-WAVE-003 | Enemy type unlock schedule — new types appear at specific waves | ADR-0014 ✅ |
| TR-WAVE-004 | Wave lifecycle + INTERMISSION state between waves | ADR-0014 ✅ |
| TR-WAVE-005 | wave_completed signal for scoring and state transitions | ADR-0014 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/arena-wave-system.md` are verified
- All Logic stories have passing test files in `tests/unit/arena-wave-system/`
- Integration test confirms wave lifecycle end-to-end

## Next Step

Run `/create-stories arena-wave-system` to break this epic into implementable stories.
