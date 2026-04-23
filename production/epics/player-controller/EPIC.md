# Epic: 玩家控制器 (Player Controller)

> **Layer**: Core
> **GDD**: design/gdd/player-controller.md
> **Architecture Module**: 玩家控制器模块
> **Status**: Ready
> **Stories**: 3 stories (3 Logic) — see below

## Overview

玩家控制器是玩家在游戏世界中的化身——管理移动、闪避、生命值和死亡。CharacterBody3D 驱动的恒定速度移动（5.0 m/s），闪避带无敌帧，3 点生命值，归零触发死亡信号。玩家始终自动面向最近敌人。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010: Player Controller Architecture | CharacterBody3D, constant speed movement, dodge with i-frames, auto-face enemy | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PLAYER-001 | CharacterBody3D with move_and_slide(), constant speed 5.0 m/s | ADR-0010 ✅ |
| TR-PLAYER-002 | Dodge with invincibility frames and cooldown | ADR-0010 ✅ |
| TR-PLAYER-003 | HP system: 3 HP, take_damage(), player_died signal | ADR-0010 ✅ |
| TR-PLAYER-004 | Auto-face nearest enemy | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/player-controller.md` are verified
- All Logic stories have passing test files in `tests/unit/player-controller/`
- Visual/Feel stories have evidence docs with sign-off

## Next Step

Run `/create-stories player-controller` to break this epic into implementable stories.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Movement & Auto-face | Logic | Ready | ADR-0010 |
| 002 | Dodge & Invincibility | Logic | Ready | ADR-0010 |
| 003 | Health & Death | Logic | Ready | ADR-0010 |
