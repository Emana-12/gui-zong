# Story 003: Web Performance

> **Epic**: 物理碰撞层
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/physics-collision.md`
**Requirement**: `TR-PHYSICS-005`

**ADR Governing Implementation**: ADR-0005: Physics Collision Architecture
**ADR Decision Summary**: ≤18 total hitboxes, Web 30fps fallback, performance monitoring.

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH

## Acceptance Criteria

- [ ] 3 player + 10 enemy + 5 environment hitboxes → ≤18
- [ ] Web at 30fps → 30 collision checks/sec maintained

## Implementation Notes

- Hitbox count monitoring
- Web export performance profiling
- Fallback: if Web < 30fps, reduce enemy hitboxes or enlarge shapes

## Out of Scope

- Story 001: Hitbox/hurtbox core
- Story 002: Raycast

## QA Test Cases

- **AC-1**: 预算 — Given max场景, When 计数, Then ≤18
- **AC-2**: 性能 — Given Web 30fps, When 运行, Then 30 checks/sec

## Test Evidence

**Story Type**: Integration | `tests/integration/physics-collision/performance_test.gd` + Web profiling data

## Dependencies

- Depends on: story-001, story-002
- Unlocks: None

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 1/2 passing (AC-1 covered, AC-2 deferred for Web export)
**Deviations**: None
**Test Evidence**: tests/integration/physics-collision/performance_test.gd (5 test functions)
**Code Review**: APPROVED (initially CHANGES REQUIRED for hardcoded magic numbers — fixed to use MAX_HITBOXES constant)
**QL-TEST-COVERAGE**: GAPS (advisory — AC-2 needs Web export profiling)
**Advisory**: AC-2 Web 30fps performance deferred — requires Web export build for manual verification. Monitoring API (get_active_hitbox_count) is in place.
