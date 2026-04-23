# Epic: 敌人系统 (Enemy System)

> **Layer**: Core
> **GDD**: design/gdd/enemy-system.md
> **Architecture Module**: 敌人系统模块
> **Status**: Ready
> **Stories**: 3 stories — see below
> **⚠️ Note**: GDD 定义 5 种敌人类型。Vertical slice 只需 1 种（近战士兵）。完整敌人类型延后迭代。

## Overview

敌人系统管理游戏中所有敌人的生命周期、AI 行为和战斗交互。5 种敌人类型各有攻击模式和弱点，迫使玩家使用不同剑式应对——"三式皆平等"的直接实现。AI 使用简单状态机：IDLE → APPROACH → ATTACK → RECOVER。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Enemy AI Architecture | CharacterBody3D, AI state machine, 5 enemy types with counter-form design | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ENEMY-001 | CharacterBody3D per enemy with HP and AI state machine | ADR-0007 ✅ |
| TR-ENEMY-002 | 5 enemy types: 松韧/重甲/流动/远程/敏捷 | ADR-0007 ✅ |
| TR-ENEMY-003 | AI states: IDLE→APPROACH→ATTACK→RECOVER loop | ADR-0007 ✅ |
| TR-ENEMY-004 | Hit stun on damage, death signal | ADR-0007 ✅ |
| TR-ENEMY-005 | Counter-form design: each type weak to specific sword form | ADR-0007 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/enemy-system.md` are verified
- All Logic stories have passing test files in `tests/unit/enemy-system/`
- Vertical slice: at least 1 enemy type (近战士兵) fully functional

## Next Step

Run `/create-stories enemy-system` to break this epic into implementable stories.


## Stories

| 001 | Spawn & AI State Machine | Logic | Ready | ADR-0007 |
| 002 | Damage, Stun & Death | Logic | Ready | ADR-0007 |
| 003 | State Management & Query API | Logic | Ready | ADR-0007 |
