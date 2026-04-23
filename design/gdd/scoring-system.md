# 计分系统 (Scoring System)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 玩家即进度 (Pillar 3)

## Overview

**计分系统**追踪玩家每局的表现数据——最高波次、最长连击、万剑归宗触发次数——并维护最佳记录。它是"再来一局"的数据驱动力。

## Detailed Design

### Core Rules

1. 每局开始时所有计分数据归零
2. 追踪 3 项数据：**最高波次**、**最长连击**、**万剑归宗触发次数**
3. 游戏结束时，将本局数据与历史最佳记录比较——如果打破记录则更新
4. 最佳记录持久化到本地文件（Web 平台使用 `FileAccess` 或 `LocalStorage`）

### Score Data

| 数据 | 更新时机 | 数据源 |
|------|---------|--------|
| 最高波次 | 每波完成 | 竞技场波次 `get_current_wave()` |
| 最长连击 | 连击中断时 | 连击系统 `get_combo_count()` |
| 万剑归宗次数 | 每次触发 | 连击系统 `myriad_triggered` 信号 |

### Interactions

**上游依赖：** 连击/万剑归宗系统, 竞技场波次系统, 游戏状态管理
**下游依赖：** HUD/UI（得分画面显示）

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `get_current_score` | `get_current_score()` | `ScoreData` | 本局数据 |
| `get_best_score` | `get_best_score()` | `ScoreData` | 历史最佳 |
| `save_score` | `save_score()` | `void` | 保存到本地 |
| `reset_current` | `reset_current()` | `void` | 重置本局数据 |

## Tuning Knobs

| 旋钮 | 默认值 | 说明 |
|------|--------|------|
| `score_save_enabled` | true | 是否持久化最佳记录 |

## Acceptance Criteria

- **GIVEN** 本局达到波次 10，**WHEN** `get_current_score()` 被查询，**THEN** 最高波次=10
- **GIVEN** 本局连击中断在 15，**WHEN** 更新最长连击，**THEN** 最长连击=15
- **GIVEN** 本局打破历史记录，**WHEN** `save_score()` 被调用，**THEN** 最佳记录更新
- **GIVEN** 新一局开始，**WHEN** `reset_current()` 被调用，**THEN** 本局数据归零

## Open Questions

- 是否需要额外评分维度？（如无伤通关奖励、最短时间到达某波次）
- 最佳记录是否需要在 UI 中展示？（标题画面显示"历史最高：波次 X"）