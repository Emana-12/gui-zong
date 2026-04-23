# 计分画面 UX 规范

> **Epic**: HUD/UI 系统
> **Created**: 2026-04-23
> **Sprint**: S03-07
> **Status**: Draft

## Overview

计分画面嵌入死亡画面面板中，显示本局表现数据与历史最佳对比。玩家在看到"剑已断"后，下方显示本局关键指标和是否打破记录。

## Player Fantasy

玩家死亡后看到自己的战绩——波次、连击、万剑归宗次数——与历史最佳对比。打破记录时金墨色高亮，激励"再来一局"。

## Layout

死亡画面面板扩展区域（现有 panel 下方或叠加）:

```
┌─────────────────────────────────┐
│         剑已断 (纯白 36px)       │
│            1250 分              │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 波次    本局: 12  最佳: 15│   │
│  │ 连击    本局: 8   最佳: 14│   │
│  │ 万剑    本局: 3   最佳: 5 │   │
│  └─────────────────────────┘   │
│                                 │
│  ★ 新纪录! ★ (金墨色闪烁)      │
│                                 │
│        [ 重新开始 ]             │
└─────────────────────────────────┘
```

- **数据行**: 纯白标签 + 金墨色数字，三行对比
- **新纪录标记**: 仅在打破记录时显示，金墨色脉冲动画
- **字号**: 标签 16px, 数字 24px

## Data Source

| 数据 | 来源 | API |
|------|------|-----|
| 本局波次 | ScoringSystem | `get_current_score().highest_wave` |
| 最佳波次 | ScoringSystem | `get_best_score().highest_wave` |
| 本局连击 | ScoringSystem | `get_current_score().longest_combo` |
| 最佳连击 | ScoringSystem | `get_best_score().longest_combo` |
| 本局万剑 | ScoringSystem | `get_current_score().myriad_count` |
| 最佳万剑 | ScoringSystem | `get_best_score().myriad_count` |

## Animation

**新纪录脉冲**:
- 时长: 1.0s 循环
- 效果: alpha 1.0 → 0.5 → 1.0
- 颜色: #D9A621 (金墨色)

## Interaction

- 数据为只读显示，无交互
- 重新开始按钮与死亡画面共享

## Edge Cases

- **首局（无历史记录）**: 最佳列显示 "—"
- **全部为 0**: 本局列显示 "0"，最佳列显示 "—" 或 "0"
- **多项打破记录**: 每项独立高亮，新纪录标记只显示一次
