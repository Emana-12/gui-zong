# Epic: 命中判定层 (Hit Judgment)

> **Layer**: Core
> **GDD**: design/gdd/hit-judgment.md
> **Architecture Module**: 命中判定层模块
> **Status**: Ready
> **Stories**: 3 stories — see below

## Overview

命中判定层是"什么算命中"的游戏逻辑层。接收物理碰撞层的碰撞结果，判断：这次碰撞是否构成有效命中？造成多少伤害？目标是否处于无敌状态？然后输出 HitResult 给下游系统（连击计数、命中反馈、敌人受伤）。纯 GDScript 逻辑，无引擎风险。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0011: Hit Judgment Architecture | Collision → hit conversion, HitResult struct, invincibility filter, per-swing deduplication | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-HIT-001 | HitResult data structure: attacker, target, sword_form, damage, position, normal, material_type | ADR-0011 ✅ |
| TR-HIT-002 | Invincibility frame filtering | ADR-0011 ✅ |
| TR-HIT-003 | Per-swing hit deduplication (same hitbox + same target = 1 hit) | ADR-0011 ✅ |
| TR-HIT-004 | Three-form damage calculation (游:1, 钻:3, 绕:2) | ADR-0011 ✅ |
| TR-HIT-005 | Directional hit detection (90° fan, 2.5m range) | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/hit-judgment.md` are verified
- All Logic stories have passing test files in `tests/unit/hit-judgment/`

## Next Step

Run `/create-stories hit-judgment` to break this epic into implementable stories.


## Stories

| 001 | Hit Processing & HitResult | Logic | Ready | ADR-0011 |
| 002 | Damage Calculation & Dedup | Logic | Ready | ADR-0011 |
