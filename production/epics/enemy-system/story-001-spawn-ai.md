# Story 001: Spawn & AI State Machine

> **Epic**: 敌人系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-ENEMY-001`, `TR-ENEMY-003`

**ADR Governing Implementation**: ADR-0007: Enemy AI Architecture
**ADR Decision Summary**: CharacterBody3D per enemy, AI state machine (IDLE→APPROACH→ATTACK→RECOVER), parameterized by enemy type.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] spawn_enemy("pine", pos) → enemy at position, HP=5
- [ ] Player within perception → IDLE→APPROACH, moves toward player
- [ ] Enemy enters attack range → ATTACK, attack hitbox created

## Implementation Notes

- Parameterized: 5 types via dictionary (hp, speed, attack_range, perception_range)
- Vertical slice: only "pine" type (近战士兵, HP=5, speed=3.0)
- AI state machine with Timer-based transitions

## Out of Scope

- Story 002: Damage & death
- Story 003: State management & queries

## QA Test Cases

- **AC-1**: 生成 — Given spawn("pine",pos), When 完成, Then HP=5在指定位置
- **AC-2**: 追击 — Given 玩家<10m, When IDLE, Then →APPROACH移动
- **AC-3**: 攻击 — Given 进入攻击范围, When ATTACK, Then hitbox创建

## Test Evidence

**Story Type**: Logic | `tests/unit/enemy-system/spawn_ai_test.gd`

## Dependencies

- Depends on: physics-collision story-001
- Unlocks: story-002

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 3/3 passing
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/enemy-system/spawn_ai_test.gd` (22 test functions, all passing)
**Code Review**: Skipped (Lean mode)
