# Story 002: Damage Calculation & Deduplication

> **Epic**: 命中判定层
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/hit-judgment.md`
**Requirement**: `TR-HIT-003`, `TR-HIT-004`

**ADR Governing Implementation**: ADR-0011: Hit Judgment Architecture
**ADR Decision Summary**: Per-form damage table, per-swing hit deduplication set.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [x] 游剑式 damage → 1
- [x] 钻剑式 damage → 3
- [x] 绕剑式 damage → 2
- [x] Same hitbox + same target → is_already_hit, collision ignored

## Implementation Notes

- Damage table: {you:1, zuan:3, rao:2, none:1}
- Dedup: Dictionary< hitbox_id, Array<target_id> > — per swing lifecycle
- Clear dedup set when hitbox destroyed

## Out of Scope

- Story 001: Hit processing & HitResult

## QA Test Cases

- **AC-1**: 游伤害 — Given "you", When calculate_damage, Then 1
- **AC-2**: 钻伤害 — Given "zuan", When calculate_damage, Then 3
- **AC-3**: 绕伤害 — Given "rao", When calculate_damage, Then 2
- **AC-4**: 去重 — Given hitbox#1→targetA已命中, When 再次碰撞, Then 忽略

## Test Evidence

**Story Type**: Logic | `tests/unit/hit-judgment/damage_dedup_test.gd`

## Dependencies

- Depends on: story-001
- Unlocks: three-forms-combat, enemy-system

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 4/4 passing (游剑式 damage=1, 钻剑式 damage=3, 绕剑式 damage=2, 去重机制)
**Deviations**: None
**Test Evidence**: Logic: tests/unit/hit-judgment/damage_dedup_test.gd (10 个测试函数覆盖所有 AC)
**Code Review**: LP-CODE-REVIEW — APPROVE (2026-04-22)
