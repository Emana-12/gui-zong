# Story 003: DPS Balance & Death Cancel

> **Epic**: 三式剑招系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/three-forms-combat.md`
**Requirement**: `TR-THREE-005`

**ADR Governing Implementation**: ADR-0006: Three Forms Combat Architecture
**ADR Decision Summary**: Three-form DPS balance (游1.67/钻2.50/绕2.35), cancel_current() on death.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] 游 DPS=1.67, 钻 DPS=2.50, 绕 DPS=2.35 — all within 50% range
- [ ] Player dies during EXECUTING → cancel_current(), hitbox destroyed

## Implementation Notes

- DPS = base_damage / (execute + recovery + cooldown)
- cancel_current(): destroy hitbox, reset to IDLE
- Listen to player_died signal from player controller

## Out of Scope

- Story 001: Form execution
- Story 002: Switching & cooldown

## QA Test Cases

- **AC-1**: DPS均衡 — When 计算, Then 三式DPS差异<50%
- **AC-2**: 死亡取消 — Given EXECUTING, When player_died, Then cancel_current+hitbox销毁

## Test Evidence

**Story Type**: Config/Data | `tests/unit/three-forms-combat/balance_cancel_test.gd`

## Dependencies

- Depends on: story-001, story-002
- Unlocks: None

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 2/2 passing
**Deviations**: ADVISORY — TR-ID mismatch (TR-THREE-005 vs TR-COMBAT-xxx); test file path mismatch (balance_test.gd → balance_cancel_test.gd, corrected)
**Test Evidence**: tests/unit/three-forms-combat/balance_cancel_test.gd (8 test functions)
**Code Review**: Skipped (Lean mode)
**Test Coverage**: Skipped (Lean mode, Config/Data story)
