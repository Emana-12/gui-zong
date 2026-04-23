# Story 003: State-Driven Camera

> **Epic**: 摄像机系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-CAMERA-005`

**ADR Governing Implementation**: ADR-0012: Camera System Architecture
**ADR Decision Summary**: Camera frozen on DEATH, fixed position on TITLE.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] DEATH → camera completely frozen
- [ ] TITLE → camera at fixed position

## Implementation Notes

- Listen to GameStateManager.state_changed
- DEATH: stop all camera movement and effects
- TITLE: position camera at predefined title position

## Out of Scope

- Story 001: Follow
- Story 002: Effects

## QA Test Cases

- **AC-1**: 死亡冻结 — Given DEATH, When 玩家死亡, Then 摄像机位置不变
- **AC-2**: 标题 — Given TITLE, When 显示, Then 固定位置

## Test Evidence

**Story Type**: Logic | `tests/unit/camera-system/state_camera_test.gd`

## Dependencies

- Depends on: story-001, game-state-manager story-001
- Unlocks: None

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 2/2 passing
**Deviations**: None
**Test Evidence**: `tests/unit/camera-system/state_camera_test.gd` (10 test functions)
**Code Review**: APPROVED WITH SUGGESTIONS (3 non-blocking: enum vs magic numbers, strengthen test assertion, config externalization)
