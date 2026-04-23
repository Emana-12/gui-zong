# Epic: 流光轨迹系统 (Light Trail System)

> **Layer**: Feature
> **GDD**: design/gdd/light-trail-system.md
> **Architecture Module**: 流光轨迹渲染模块
> **Status**: Ready
> ## Stories

| Story | Title | Type | TR Coverage | Status |
|-------|-------|------|-------------|--------|
| [Story 001](story-001-trail-lifecycle.md) | 轨迹生命周期管理 | Visual/Feel | TR-TRAIL-001, TR-TRAIL-004 | Ready |
| [Story 002](story-002-trail-pooling.md) | 轨迹池化与共享材质 | Logic | TR-TRAIL-002, TR-TRAIL-003 | Ready |
| [Story 003](story-003-myriad-batch.md) | 万剑归宗批量轨迹 | Integration | TR-TRAIL-005 | Ready |

## Overview

流光轨迹系统是《归宗》最核心的视觉表达——墨色流光和金色剑气追踪剑尖运动，精确勾勒每一次出招的轨迹。这是"剑招即笔触"（Art Bible Principle 1）的技术实现。50 条轨迹共享 1 个材质（1 draw call），轨迹池化预创建以避免运行时分配。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008: 流光轨迹渲染架构 | MeshInstance3D + ImmediateMesh, 轨迹池化, 共享材质 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-TRAIL-001 | MeshInstance3D + ImmediateMesh for trail rendering | ADR-0008 ✅ |
| TR-TRAIL-002 | Trail pooling with max 50 active trail segments | ADR-0008 ✅ |
| TR-TRAIL-003 | Shared material: 3 materials per form type (游/钻/绕) | ADR-0008 ✅ |
| TR-TRAIL-004 | Per-form trail parameters: width, fade time, color | ADR-0008 ✅ |
| TR-TRAIL-005 | Myriad batch rendering — 50 trails in 1 draw call | ADR-0008 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/light-trail-system.md` are verified
- All Logic stories have passing test files in `tests/unit/light-trail-system/`
- Visual verification confirms trail rendering matches Art Bible (ink + gold palette)

## Next Step

Run `/create-stories light-trail-system` to break this epic into implementable stories.
