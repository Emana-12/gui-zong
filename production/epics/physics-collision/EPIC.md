# Epic: 物理碰撞层 (Physics Collision)

> **Layer**: Core
> **GDD**: design/gdd/physics-collision.md
> **Architecture Module**: 物理碰撞层模块
> **Status**: Ready
> **Stories**: 3 stories — see below
> **⚠️ HIGH ENGINE RISK**: Jolt 4.6 默认物理引擎，Web 端碰撞性能未验证。建议 Sprint 前进行 Web 端物理压力测试。

## Overview

物理碰撞层是《归宗》所有空间查询和碰撞检测的底层工具。管理 hitbox/hurtbox（Area3D + CollisionShape3D），执行空间查询（ShapeCast3D 用于剑招扫掠），提供碰撞结果给上层的命中判定系统。不决定"什么算命中"——只负责"什么东西碰到了什么东西"。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Physics Collision Architecture | Area3D hitbox/hurtbox, ShapeCast3D for sword sweeps, 4 collision layers, Jolt backend | **HIGH** |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PHYSICS-001 | Hitbox/hurtbox management (Area3D + CollisionShape3D) | ADR-0005 ✅ |
| TR-PHYSICS-002 | 4 collision layers: Player/Enemy/PlayerAttack/EnemyAttack | ADR-0005 ✅ |
| TR-PHYSICS-003 | ShapeCast3D for sword sweep collision detection | ADR-0005 ✅ |
| TR-PHYSICS-004 | Collision result output (position, normal, target) | ADR-0005 ✅ |
| TR-PHYSICS-005 | Web-optimized collision: ≤10 simultaneous hitboxes | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/physics-collision.md` are verified
- All Logic stories have passing test files in `tests/unit/physics-collision/`
- Performance evidence: Web export maintains ≥50fps with 10 active hitboxes

## Next Step

Run `/create-stories physics-collision` to break this epic into implementable stories.


## Stories

| 001 | Hitbox/Hurtbox Management | Logic | Ready | ADR-0005 |
| 002 | Raycast & Shape Cast | Logic | Ready | ADR-0005 |
| 003 | Web Performance | Integration | Ready | ADR-0005 |
