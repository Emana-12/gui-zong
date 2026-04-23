# Epic: 命中反馈 (Hit Feedback)

> **Layer**: Presentation
> **GDD**: design/gdd/hit-feedback.md
> **Architecture Module**: 命中反馈模块
> **Status**: Ready
> **Stories**: 3 stories (2 Visual/Feel, 1 Integration) — Ready

## Overview

命中反馈系统是"打中了"的感官确认——顿帧、屏幕震动、材质反应（火花/裂纹/墨点炸碎）。它将命中判定层的逻辑结果转化为玩家的即时感官体验。没有命中反馈，精确打击就是"无声的精准"——有它，每一击都有"分量"。顿帧由摄像机系统执行，材质反应使用对象池（最大 4 draw call/帧）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0013: 命中反馈架构 | 顿帧公式, 材质反应对象池, 分发表(剑式×材质→效果), 万剑归宗最高优先级 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-FBK-001 | Material reactions: gold/wood/ink/shock particle effects | ADR-0013 ✅ |
| TR-FBK-002 | Hit stop formula: 2 + floor(damage/2) frames | ADR-0013 ✅ |
| TR-FBK-003 | Max 4 draw calls per frame for feedback effects | ADR-0013 ✅ |
| TR-FBK-004 | Low-fps hit stop reduction — scale duration inversely with frame rate | ADR-0013 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/hit-feedback.md` are verified
- All Logic stories have passing test files in `tests/unit/hit-feedback/`
- Visual verification confirms hit stop + shake + material reactions match spec

## Stories

| Story | Title | Type | Status |
|-------|-------|------|--------|
| [story-001](story-001-hit-stop-shake.md) | 顿帧与屏幕震动 | Visual/Feel | Ready |
| [story-002](story-002-material-reaction-pool.md) | 材质反应与对象池 | Visual/Feel | Ready |
| [story-003](story-003-myriad-sword-feedback.md) | 万剑归宗反馈 | Integration | Ready |
