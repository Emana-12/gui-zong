# Epic: 摄像机系统 (Camera System)

> **Layer**: Core
> **GDD**: design/gdd/camera-system.md
> **Architecture Module**: 摄像机模块
> **Status**: Ready
> **Stories**: 3 stories — see below

## Overview

摄像机系统控制玩家在竞技场中的视角——固定 45° 俯视角跟随玩家，保持竞技场可见，万剑归宗时拉远展示全景，死亡时完全冻结。摄像机是玩家"看"这个水墨世界的窗口——好的摄像机是看不见的摄像机。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0012: Camera System Architecture | Fixed 45° top-down, smooth lerp follow, state-driven effects (zoom/freeze) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CAMERA-001 | Fixed 45° top-down angle, no player camera control | ADR-0012 ✅ |
| TR-CAMERA-002 | Smooth follow via lerp (factor 5.0), XZ plane only | ADR-0012 ✅ |
| TR-CAMERA-003 | Arena framing: keep arena center visible | ADR-0012 ✅ |
| TR-CAMERA-004 | Myriad swords zoom effect (FOV/distance increase) | ADR-0012 ✅ |
| TR-CAMERA-005 | Death freeze: stop all camera movement | ADR-0012 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/camera-system.md` are verified
- Visual/Feel story has playtest evidence confirming camera stability

## Next Step

Run `/create-stories camera-system` to break this epic into implementable stories.


## Stories

| 001 | Camera Follow & Configuration | Logic | Ready | ADR-0012 |
| 002 | FOV Effects & Shake | Visual/Feel | Ready | ADR-0012 |
| 003 | State-Driven Camera | Logic | Ready | ADR-0012 |
