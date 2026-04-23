# Story 002: Raycast & Shape Cast

> **Epic**: 物理碰撞层
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/physics-collision.md`
**Requirement**: `TR-PHYSICS-003`, `TR-PHYSICS-004`

**ADR Governing Implementation**: ADR-0005: Physics Collision Architecture
**ADR Decision Summary**: PhysicsDirectSpaceState3D for raycast, ShapeCast3D for sword sweep detection.

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH

## Acceptance Criteria

- [x] raycast(A, B, mask) with collider → RaycastResult with nearest hit point
- [x] raycast(A, A, mask) → null

## Implementation Notes

- PhysicsDirectSpaceState3D.intersect_ray()
- ShapeCast3D for sword sweep (continuous collision)
- RaycastResult: position, normal, collider

## Out of Scope

- Story 001: Hitbox/hurtbox
- Story 003: Performance

## QA Test Cases

- **AC-1**: 射线命中 — Given 碰撞体在路径上, When raycast, Then 最近碰撞点
- **AC-2**: 零长度 — Given A==B, When raycast, Then null

## Test Evidence

**Story Type**: Logic | `tests/unit/physics-collision/raycast_test.gd`

## Dependencies

- Depends on: story-001
- Unlocks: hit-judgment

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 2/2 passing
**Deviations**: shape_cast() 类型安全修复（超出 story 范围，LP 要求一致性修复）
**Test Evidence**: tests/unit/physics-collision/raycast_test.gd (8 test functions)
**Code Review**: APPROVED (2 HIGH fixes applied: safe type conversion + is_instance_valid in raycast() and shape_cast())
