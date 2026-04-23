# Epic: 着色器/渲染 (Shader/Rendering)

> **Layer**: Foundation
> **GDD**: design/gdd/shader-rendering.md
> **Architecture Module**: 着色器/渲染模块
> **Status**: Ready
> **Stories**: 5 stories created — see table below
> **⚠️ Note**: Vertical slice 将水墨着色器列为 Out of Scope。Sprint 1 只需渲染管线骨架（Forward+ 配置、WebGL 2.0 回退、基础材质管理），着色器库延后。

## Overview

着色器/渲染系统是《归宗》视觉身份的技术载体。它提供水墨风格着色器库、Forward+ 渲染管线与 WebGL 2.0 回退、材质管理（≤15 实例）和后处理 pass 管理（≤2 个）。所有视觉效果建立在这个系统之上。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Rendering Pipeline Architecture | Forward+ with WebGL 2.0 fallback, shader library, material pool | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-SHADER-001 | Ink-wash character shader with configurable parameters | ADR-0003 ✅ |
| TR-SHADER-002 | Ink-wash environment shader with ink-wash lighting | ADR-0003 ✅ |
| TR-SHADER-003 | Light trail shader (ink black / gold) | ADR-0003 ✅ |
| TR-SHADER-004 | Forward+ pipeline with WebGL 2.0 auto-fallback | ADR-0003 ✅ |
| TR-SHADER-005 | Material pool: ≤15 shared instances to reduce draw calls | ADR-0003 ✅ |
| TR-SHADER-006 | Post-processing: ≤2 passes (outline + tone adjustment) | ADR-0003 ✅ |
| TR-SHADER-007 | Auto-degradation strategy for Web platform | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/shader-rendering.md` are verified
- Visual/Feel stories have screenshot evidence with sign-off in `production/qa/evidence/`
- Web export renders correctly at ≥50fps on target browsers

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 材质池与着色器管理器 | Logic | Ready | ADR-0003 |
| 002 | 水墨着色器库（角色 + 环境） | Visual/Feel | Ready | ADR-0003 |
| 003 | 流光轨迹着色器与三式连接 | Integration | Ready | ADR-0003 |
| 004 | 自动降级系统 | Logic | Ready | ADR-0003 |
| 005 | 后处理 Pass 与 WebGL 回退 | Integration | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/shader-rendering/story-001-material-pool.md` to validate the first story, then `/dev-story` to begin implementation.
