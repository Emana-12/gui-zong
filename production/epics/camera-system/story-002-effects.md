# Story 002: FOV Effects & Shake

> **Epic**: 摄像机系统
> **Status**: Complete
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-CAMERA-004`

**ADR Governing Implementation**: ADR-0012: Camera System Architecture
**ADR Decision Summary**: FOV lerp for myriad zoom, random offset for shake, Engine.time_scale for hit stop.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] Myriad trigger → FOV 60°→75° in 2s
- [ ] Myriad ends → FOV restores 60° in 1s
- [ ] Hit shake → ±0.1m horizontal for 0.1s
- [ ] Hit stop → camera pauses 2 frames

## Implementation Notes

- FOV lerp: lerp(current_fov, target_fov, speed * delta)
- Shake: random offset added to camera position
- Hit stop: Engine.time_scale = 0 for 2 frames (careful on Web — audio pop risk)

## Out of Scope

- Story 001: Basic follow
- Story 003: State-driven

## QA Test Cases

- **AC-1**: 拉远 — When myriad触发, Then FOV 60→75 in 2s
- **AC-2**: 恢复 — When myriad结束, Then FOV 75→60 in 1s
- **AC-3**: 震动 — When hit, Then ±0.1m 0.1s
- **AC-4**: 顿帧 — When hit, Then 2帧暂停

## Test Evidence

**Story Type**: Visual/Feel | `production/qa/evidence/camera-effects-evidence.md` + sign-off

## Dependencies

- Depends on: story-001
- Unlocks: story-003

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 4/4 passing (all implemented, manual playtest verification pending)
**Deviations**: None blocking. LP-CODE-REVIEW: APPROVED WITH SUGGESTIONS (6 optional improvements)
**Test Evidence**: Visual/Feel — evidence doc at `production/qa/evidence/camera-effects-evidence.md`, sign-off pending
**Code Review**: APPROVED WITH SUGGESTIONS (lead-programmer, 2026-04-21)
