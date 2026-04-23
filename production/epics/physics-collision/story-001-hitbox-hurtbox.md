# Story 001: Hitbox/Hurtbox Management

> **Epic**: 物理碰撞层
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/physics-collision.md`
**Requirement**: `TR-PHYSICS-001`, `TR-PHYSICS-002`

**ADR Governing Implementation**: ADR-0005: Physics Collision Architecture
**ADR Decision Summary**: Area3D + CollisionShape3D for hitbox/hurtbox, 4 collision layers, hitbox pooling.

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH — Jolt 4.6 Web performance unverified

## Acceptance Criteria

- [ ] Sword hitbox overlaps enemy hurtbox → collision_detected signal with position + target
- [ ] Player hurtbox overlaps enemy attack during invincibility → collision still detected (hit judgment filters)
- [ ] Create + destroy hitbox same frame → no error or residual

## Implementation Notes

- Area3D + CollisionShape3D, no physics response (overlap detection only)
- 4 collision layers: Player(1), Enemy(2), PlayerAttack(3), EnemyAttack(4)
- Hitbox pooling: pre-create, activate/deactivate at runtime
- Destroy in _physics_process, not in signal callbacks

## Out of Scope

- Story 002: Raycast/shape cast
- Story 003: Performance validation

## QA Test Cases

- **AC-1**: 重叠检测 — Given hitbox+hurtbox重叠, When _physics_process, Then collision_detected信号
- **AC-2**: 无敌帧 — Given 无敌中, When 敌人hitbox重叠, Then 碰撞仍检测到
- **AC-3**: 同帧销毁 — Given 创建hitbox, When 同帧destroy, Then 无错误

## Test Evidence

**Story Type**: Logic | `tests/unit/physics-collision/hitbox_test.gd`

## Dependencies

- Depends on: player-controller story-001
- Unlocks: hit-judgment story-001

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 3/3 passing
**Deviations**: Story says "4 collision layers" — ADR/implementation use 6 (doc stale, code correct)
**Fixes applied**: shape_cast runtime bug (intersect_shape API), hot-path allocation, dead code removal
**Test Evidence**: tests/unit/physics-collision/hitbox_test.gd (7 test functions)
**Code Review**: GAPS (advisory) + CHANGES REQUIRED (fixed)
