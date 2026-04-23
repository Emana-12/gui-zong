# Story 001: Camera Follow & Configuration

> **Epic**: 摄像机系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-CAMERA-001`, `TR-CAMERA-002`

**ADR Governing Implementation**: ADR-0012: Camera System Architecture
**ADR Decision Summary**: Fixed 45° top-down, smooth lerp follow on XZ plane, Y fixed at 6.0m.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] Player moves A→B → camera smooth follow (lerp factor 5.0)
- [ ] Fixed 45° angle, 8m distance, 60° FOV

## Implementation Notes

- Camera3D, lerp(camera_pos, player_pos.xz, follow_speed * delta)
- Y fixed at 6.0m, only XZ follows player
- Transform: position = player_pos + Vector3(0, 6, -8) rotated 45°

## Out of Scope

- Story 002: FOV effects & shake
- Story 003: State-driven behavior

## QA Test Cases

- **AC-1**: 跟随 — Given 玩家移动, When 0.5s后, Then 摄像机在玩家附近
- **AC-2**: 配置 — When 默认, Then 45°/8m/60°FOV

## Test Evidence

**Story Type**: Logic | `tests/unit/camera-system/follow_test.gd`

## Dependencies

- Depends on: player-controller story-001
- Unlocks: story-002

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 2/2 passing
**Deviations**: ADVISORY — TR-ID prefix mismatch (TR-CAMERA vs TR-CAM, same requirements)
**Test Evidence**: Logic: tests/unit/camera-system/follow_test.gd (12 test functions)
**Code Review**: LP-CODE-REVIEW CHANGES REQUIRED → 3 fixes applied (_exit_tree, get_camera, precise assertions)
**QA Coverage**: QL-TEST-COVERAGE GAPS (advisory) — boundary tests, get_camera_forward, signal disconnect untested
