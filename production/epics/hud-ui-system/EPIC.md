# Epic: HUD/UI 系统

> **Layer**: Presentation
> **GDD**: design/gdd/hud-ui-system.md
> **Architecture Module**: HUD/UI 模块
> **Status**: Ready
> **Stories**: 3 stories (3 UI) — Ready

## Overview

HUD/UI 系统是玩家与游戏信息的界面层——生命值墨滴、连击计数器、波次显示、菜单系统。UI 是水墨世界的自然延伸，不是叠加层（Art Bible Section 7: "墨迹侵蚀式"）。使用 CanvasLayer + Control 节点架构，信号订阅模式。3 秒无受击自动淡出至 30% alpha。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0015: HUD/UI 架构 | CanvasLayer + Control, 信号订阅, 自动淡出, 菜单栈模式 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-HUD-001 | HUD elements: health, combo, form, charge, wave indicators | ADR-0015 ✅ |
| TR-HUD-002 | State-dependent HUD switching — show/hide based on game state | ADR-0015 ✅ |
| TR-HUD-003 | Auto-fade: 3 seconds idle → 0.3 alpha | ADR-0015 ✅ |
| TR-HUD-004 | Menu stack system — push/pop menu screens | ADR-0015 ✅ |
| TR-HUD-005 | Web responsive anchoring — adapt to different viewport sizes | ADR-0015 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/hud-ui-system.md` are verified
- All UI stories have manual evidence in `production/qa/evidence/`
- HUD visual matches Art Bible Section 7 (ink-erosion style, correct palette)

## Stories

| Story | Title | Type | Status |
|-------|-------|------|--------|
| [story-001](story-001-combat-hud-display.md) | 战斗 HUD 显示 | UI | Ready |
| [story-002](story-002-hud-auto-fade.md) | HUD 自动淡出与状态响应 | UI | Ready |
| [story-003](story-003-menu-game-over.md) | 菜单系统与游戏结束 | UI | Ready |
