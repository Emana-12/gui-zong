# Epic: 关卡/场景管理 (Level/Scene Manager)

> **Layer**: Feature
> **GDD**: design/gdd/level-scene-manager.md
> **Architecture Module**: 关卡场景管理器模块
> **Status**: Ready
> ## Stories

| Story | Title | Type | TR Coverage | Status |
|-------|-------|------|-------------|--------|
| [Story 001](story-001-scene-loading.md) | 场景加载与切换 | Integration | TR-LSM-001, TR-LSM-003 | Ready |
| [Story 002](story-002-spawn-points.md) | 生成点与 Web 回退 | Logic | TR-LSM-002, TR-LSM-004 | Ready |

## Overview

关卡/场景管理管理 2 个竞技场区域（山石/水竹）的加载、切换和重置。它确保玩家在重启时能快速回到战斗，同时在完整 Demo 中支持区域选择。2 个区域预加载 PackedScene，fade-to-black 切换，场景切换约 2-5ms。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0016: 关卡场景管理器架构 | 预加载 PackedScene, Marker3D 生成点, fade 切换, Web 内存释放 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-LSM-001 | 2 arena PackedScenes preloaded at startup | ADR-0016 ✅ |
| TR-LSM-002 | Preload + spawn points via Marker3D nodes | ADR-0016 ✅ |
| TR-LSM-003 | Fade transition between scenes (canvas modulate) | ADR-0016 ✅ |
| TR-LSM-004 | Web memory release via queue_free on scene unload | ADR-0016 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/level-scene-manager.md` are verified
- All Logic stories have passing test files in `tests/unit/level-scene-manager/`
- Integration test confirms scene load/unload cycle without memory leak

## Next Step

Run `/create-stories level-scene-manager` to break this epic into implementable stories.
