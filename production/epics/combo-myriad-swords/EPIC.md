# Epic: 连击/万剑归宗系统 (Combo/Myriad Swords)

> **Layer**: Feature
> **GDD**: design/gdd/combo-myriad-swords.md
> **Architecture Module**: 连击系统模块
> **Status**: Ready
> ## Stories

| Story | Title | Type | TR Coverage | Status |
|-------|-------|------|-------------|--------|
| [Story 001](story-001-combo-counter.md) | 连击计数与超时 | Logic | TR-COMBO-001, TR-COMBO-004 | Ready |
| [Story 002](story-002-myriad-trigger.md) | 万剑归宗触发与公式 | Logic | TR-COMBO-002, TR-COMBO-003 | Ready |
| [Story 003](story-003-combo-signals.md) | 连击系统信号集成 | Integration | TR-COMBO-005 | Ready |

## Overview

连击/万剑归宗系统是《归宗》的高潮引擎——通过三式切换积累连击，达到阈值时触发万剑归宗终极场景。万剑归宗是玩家技巧的最高表达——不靠运气，只靠技巧。纯逻辑系统，不同剑式连续命中才 +1。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: 连击系统架构 | 纯逻辑系统, 不同式连续+1, 10蓄力/20自动触发, 万剑归宗公式 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-COMBO-001 | Combo timeout of 3 seconds — counter resets if no hit within window | ADR-0009 ✅ |
| TR-COMBO-002 | Charge 10 hits for myriad, auto-trigger at 20 hits | ADR-0009 ✅ |
| TR-COMBO-003 | Myriad formulas: trail count = 5 + combo, damage multiplier, range scaling | ADR-0009 ✅ |
| TR-COMBO-004 | Different form hit = +1 combo (form switching rewards) | ADR-0009 ✅ |
| TR-COMBO-005 | combo_changed and myriad_triggered signals | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/combo-myriad-swords.md` are verified
- All Logic stories have passing test files in `tests/unit/combo-myriad-swords/`
- Integration with hit-judgment confirmed (hit_landed signal → combo counter)

## Next Step

Run `/create-stories combo-myriad-swords` to break this epic into implementable stories.
