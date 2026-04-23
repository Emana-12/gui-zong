# Story 002: Dodge & Invincibility

> **Epic**: 玩家控制器
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-PLAYER-002`

**ADR Governing Implementation**: ADR-0010: Player Controller Architecture
**ADR Decision Summary**: Dodge with 3.0m displacement, 0.15s invincibility window, 0.5s cooldown.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [x] **GIVEN** 闪避键按下且非冷却中，**WHEN** 执行闪避，**THEN** 向当前移动方向位移 3.0m
- [x] **GIVEN** 闪避前 0.15s 内，**WHEN** 查询 `is_invincible()`，**THEN** 返回 true
- [x] **GIVEN** 闪避冷却中（0.5s），**WHEN** 按闪避键，**THEN** 输入被忽略

## Implementation Notes

- Timer-based dodge: 0.2s duration, 0.15s i-frame window, 0.5s cooldown
- Direction: current move direction, or forward if stationary

## Out of Scope

- Story 001: 基础移动
- Story 003: 生命值和死亡

## QA Test Cases

- **AC-1**: 闪避位移 — Given COMBAT+非冷却, When 按Space, Then 位置偏移≈3.0m
- **AC-2**: 无敌帧 — Given 闪避中前0.15s, When is_invincible(), Then true
- **AC-3**: 冷却 — Given 冷却中, When 按Space, Then 无位移

## Test Evidence

**Story Type**: Logic | `tests/unit/player-controller/dodge_test.gd`

## Dependencies

- Depends on: story-001 (movement system)
- Unlocks: story-003

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 3/3 passing
**Deviations**: Advisory — hardcoded State.COMBAT value (1) flagged for tech debt
**Test Evidence**: `tests/unit/player-controller/dodge_test.gd` — 17 test functions
**Code Review**: Complete (LP-CODE-REVIEW: CHANGES REQUIRED → 3 fixes applied)
**Fixes Applied**:
1. Added 0.15s invincibility cutoff in `_process_dodging()`
2. Removed unused variable `pos_before_cooldown`
3. Renamed Chinese function names to English snake_case
