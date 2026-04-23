# Story 002: Form Switching & Cooldown

> **Epic**: 三式剑招系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/three-forms-combat.md`
**Requirement**: `TR-THREE-002`

**ADR Governing Implementation**: ADR-0006: Three Forms Combat Architecture
**ADR Decision Summary**: EXECUTING non-interruptible, RECOVERING interruptible, per-form independent cooldowns.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] EXECUTING → new form input ignored
- [ ] RECOVERING → new form input cancels, switches to new form
- [ ] Same form on cooldown → input ignored
- [ ] Different form not on cooldown → executes normally

## Implementation Notes

- RECOVERING interrupt: cancel recovery timer, immediately start new form EXECUTING
- Independent cooldowns: each form has own Timer node
- is_on_cooldown(form) query for external systems

## Out of Scope

- Story 001: Form execution
- Story 003: Balance & cancel

## QA Test Cases

- **AC-1**: 不可打断 — Given EXECUTING, When 按K, Then 忽略
- **AC-2**: 可打断 — Given RECOVERING, When 按K, Then 切换钻剑式
- **AC-3**: 冷却 — Given 游冷却中, When 按J, Then 忽略
- **AC-4**: 独立冷却 — Given 游冷却中, When 按L, Then 绕剑式执行

## Test Evidence

**Story Type**: Logic | `tests/unit/three-forms-combat/switching_cooldown_test.gd`

## Dependencies

- Depends on: story-001
- Unlocks: story-003

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — TR-ID mismatch (TR-THREE-002 vs TR-COMBAT-002); direct internal access in test
**Test Evidence**: tests/unit/three-forms-combat/switching_cooldown_test.gd (16 test functions)
**Code Review**: APPROVED WITH SUGGESTIONS (LP-CODE-REVIEW)
**Test Coverage**: ADEQUATE (QL-TEST-COVERAGE)
**Tech debt**: hitbox pooling violation, find_child → DI, _process vs _physics_process (carried from story-001)
