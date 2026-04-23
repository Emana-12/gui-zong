# Story 001: Movement & Auto-face

> **Epic**: 玩家控制器
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-PLAYER-001`

**ADR Governing Implementation**: ADR-0010: Player Controller Architecture
**ADR Decision Summary**: CharacterBody3D with move_and_slide(), constant speed 5.0 m/s, no acceleration curve, auto-face nearest enemy.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

**Control Manifest Rules (Core layer)**:
- Required: CharacterBody3D + move_and_slide() for movement

## Acceptance Criteria

- [ ] **GIVEN** W 键按下且 COMBAT 状态，**WHEN** 查询位置，**THEN** 玩家以 5.0 m/s 移动
- [ ] **GIVEN** 所有方向键释放，**WHEN** 正在移动，**THEN** 玩家立即停止（无惯性）
- [ ] **GIVEN** TITLE 状态，**WHEN** 按方向键，**THEN** 角色不移动
- [ ] **GIVEN** 最近敌人变化，**WHEN** 更新朝向，**THEN** 玩家下一帧面向新最近敌人

## Implementation Notes

- CharacterBody3D, velocity = input_direction * MOVE_SPEED, move_and_slide()
- 非 COMBAT 状态冻结移动（监听 state_changed 信号）
- 自动朝向：每帧查找最近敌人，look_at()

## Out of Scope

- Story 002: 闪避和无敌帧
- Story 003: 生命值和死亡

## QA Test Cases

- **AC-1**: 移动 — Given COMBAT, When 按下W, Then 位置变化=5.0*delta
- **AC-2**: 停止 — Given 移动中, When 释放所有键, Then velocity=0
- **AC-3**: TITLE冻结 — Given TITLE, When 按方向键, Then 位置不变
- **AC-4**: 朝向 — Given 敌人A最近, When 敌人A被杀, Then 下帧朝向敌B

## Test Evidence

**Story Type**: Logic | `tests/unit/player-controller/movement_test.gd`

## Dependencies

- Depends on: game-state-manager story-001 (state signal)
- Unlocks: story-002, story-003

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 4/4 passing (all ACs fully covered)
**Deviations**: None
**Test Evidence**: tests/unit/player-controller/movement_test.gd (18 test functions)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (advisory: magic numbers, signal connection, generic types)
**QA Coverage**: ADEQUATE — 18 tests fully cover all 4 ACs
