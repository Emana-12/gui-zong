# Story 001: Form Execution & Hitbox Lifecycle

> **Epic**: 三式剑招系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/three-forms-combat.md`
**Requirement**: `TR-THREE-001`, `TR-THREE-003`

**ADR Governing Implementation**: ADR-0006: Three Forms Combat Architecture
**ADR Decision Summary**: Three independent state machines (IDLE→EXECUTING→RECOVERING→COOLDOWN), hitbox create/destroy lifecycle per form.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] J + not cooldown → 游剑式, hitbox active ~0.25s
- [ ] K + not cooldown → 钻剑式, hitbox active ~0.1s
- [ ] L + not cooldown → 绕剑式, hitbox active ~0.35s
- [ ] form_activated signal on execution

## Implementation Notes

- FORM_DATA dictionary: {YOU: {damage:1, execute:0.3, recovery:0.1, cooldown:0.2}, ZUAN: {...}, RAO: {...}}
- Each form: create_hitbox on EXECUTE enter, destroy_hitbox on RECOVER enter
- form_activated signal with form name

## Out of Scope

- Story 002: Switching & cooldown
- Story 003: Balance & cancel

## QA Test Cases

- **AC-1**: 游执行 — Given 非冷却, When 按J, Then 游剑式+hitbox 0.25s
- **AC-2**: 钻执行 — Given 非冷却, When 按K, Then 钻剑式+hitbox 0.1s
- **AC-3**: 绕执行 — Given 非冷却, When 按L, Then 绕剑式+hitbox 0.35s
- **AC-4**: 信号 — Given 执行, When form_activated, Then 参数="you/zuan/rao"

## Test Evidence

**Story Type**: Logic | `tests/unit/three-forms-combat/form_execution_test.gd`

## Dependencies

- Depends on: input-system story-001, physics-collision story-001
- Unlocks: story-002

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 4/4 passing
**Deviations**: TR-ID mismatch (story uses TR-THREE-xxx, registry uses TR-COMBAT-xxx) — functionally correct, story file IDs need update
**Test Evidence**: `tests/unit/three-forms-combat/form_execution_test.gd` (13 test functions)
**Code Review**: APPROVED WITH SUGGESTIONS (LP-CODE-REVIEW — find_child → dependency injection recommended; RECOVERING interrupt logic vs ADR description)
**Test Coverage**: GAPS (QL-TEST-COVERAGE — hitbox lifecycle and signal parameter coverage can be strengthened, non-blocking)
