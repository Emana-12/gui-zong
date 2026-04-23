# Epic: 三式剑招系统 (Three Forms Combat)

> **Layer**: Core
> **GDD**: design/gdd/three-forms-combat.md
> **Architecture Module**: 三式剑招模块
> **Status**: Ready
> **Stories**: 3 stories — see below
> **⚠️ Note**: 这是游戏核心身份系统，设计复杂度最高。三套独立状态机 + hitbox 生命周期 + 切换打断逻辑。建议拆分为 3+ 个 Story 以精确估算。

## Overview

三式剑招系统是《归宗》的核心身份——游剑式、钻剑式、绕剑式三套独立的剑招体系。三键独立随时可用，每式有独特的攻击方式和战术价值。没有"最强形态"——三式各有不可替代的使用场景。IDLE→EXECUTING→RECOVERING→COOLDOWN 状态机驱动每式的生命周期。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Three Forms Combat Architecture | Three independent state machines, hitbox lifecycle per form, RECOVERING interrupt for switching | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-THREE-001 | Three independent forms with separate execution/recovery/cooldown | ADR-0006 ✅ |
| TR-THREE-002 | EXECUTING = non-interruptible, RECOVERING = interruptible for switching | ADR-0006 ✅ |
| TR-THREE-003 | Per-form hitbox creation/destruction lifecycle | ADR-0006 ✅ |
| TR-THREE-004 | Form-specific hitbox shapes (thin/medium/wide arc) | ADR-0006 ✅ |
| TR-THREE-005 | Three-form balance: 游(fast/low DPS), 钻(slow/high DPS), 绕(medium/defensive) | ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/three-forms-combat.md` are verified
- All Logic stories have passing test files in `tests/unit/three-forms-combat/`
- Visual/Feel story has playtest evidence confirming form differentiation

## Next Step

Run `/create-stories three-forms-combat` to break this epic into implementable stories.


## Stories

| 001 | Form Execution & Hitbox Lifecycle | Logic | Ready | ADR-0006 |
| 002 | Form Switching & Cooldown | Logic | Ready | ADR-0006 |
| 003 | DPS Balance & Death Cancel | Config/Data | Ready | ADR-0006 |
