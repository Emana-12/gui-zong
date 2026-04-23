# Story 003: State Management & Query API

> **Epic**: 敌人系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-ENEMY-002`, `TR-ENEMY-005`

**ADR Governing Implementation**: ADR-0007: Enemy AI Architecture
**ADR Decision Summary**: AI frozen in non-COMBAT states, query API for enemy lists.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] INTERMISSION → AI frozen, no updates
- [ ] get_all_enemies() with 5 → array of 5
- [ ] get_alive_count() with 2 alive → 2

## Implementation Notes

- Listen to GameStateManager.state_changed — freeze AI in non-COMBAT
- Enemy list maintained by EnemyManager (Autoload or child node)
- Counter-form design (5 types force different sword forms) — full types in later sprint

## Out of Scope

- Story 001: Spawn & AI
- Story 002: Damage & death

## QA Test Cases

- **AC-1**: 冻结 — Given INTERMISSION, When AI检查, Then 无更新
- **AC-2**: 列表 — Given 5敌人, When get_all_enemies, Then 5个节点
- **AC-3**: 存活 — Given 2活, When get_alive_count, Then 2

## Test Evidence

**Story Type**: Logic | `tests/unit/enemy-system/state_query_test.gd`

## Dependencies

- Depends on: story-001, game-state-manager story-001
- Unlocks: None

## Completion Notes
**Completed**: 2026-04-22
**Criteria**: 3/3 passing
**Deviations**: None
**Test Evidence**: `tests/unit/enemy-system/state_query_test.gd` (11 test functions)
**Code Review**: Skipped (Lean mode)
**Test Coverage**: Skipped (Lean mode)
