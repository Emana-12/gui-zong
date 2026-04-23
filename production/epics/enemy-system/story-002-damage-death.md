# Story 002: Damage, Stun & Death

> **Epic**: 敌人系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-ENEMY-004`

**ADR Governing Implementation**: ADR-0007: Enemy AI Architecture
**ADR Decision Summary**: take_damage(), HIT_STUN 0.3s, DEAD state with enemy_died signal.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] take_damage(3) on HP=5 → HP=2, HIT_STUN 0.3s
- [ ] HP=0 → DEAD, enemy_died signal
- [ ] get_alive_count() with 2 alive 3 dead → 2

## Implementation Notes

- take_damage() reduces HP, triggers HIT_STUN timer
- DEAD: disable collision, emit enemy_died, cleanup after animation
- get_alive_count() filters by is_alive()

## Out of Scope

- Story 001: Spawn & AI
- Story 003: State management

## QA Test Cases

- **AC-1**: 受击 — Given HP=5, When take_damage(3), Then HP=2+HIT_STUN
- **AC-2**: 死亡 — Given HP=2, When take_damage(2), Then DEAD+enemy_died
- **AC-3**: 计数 — Given 2活3死, When get_alive_count, Then 2

## Test Evidence

**Story Type**: Logic | `tests/unit/enemy-system/damage_death_test.gd`

## Dependencies

- Depends on: story-001
- Unlocks: story-003

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 3/3 passing
**Deviations**: None
**Test Evidence**: `tests/unit/enemy-system/damage_death_test.gd` (17 test functions)
**Code Review**: Skipped (Lean mode)
**Test Coverage**: Skipped (Lean mode)
