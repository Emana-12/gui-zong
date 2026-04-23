# 纯技巧进度系统 (Skill Progression)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 玩家即进度 (Pillar 3)

## Overview

**纯技巧进度系统**是"玩家即进度"支柱的视觉表达——玩家在局间看到自己的进步不是通过数字变大，而是通过操作指标的可视化。它展示"你比上次更强了"——但这种"更强"是手法的进化，不是属性的提升。

## Detailed Design

### Core Rules

1. 本系统不提供任何数值成长——不做永久属性升级
2. 本系统追踪 3 项操作指标：**平均连击长度**、**闪避成功率**、**万剑归宗频率**
3. 每局结束后，将本局指标与历史平均值比较——显示进步/退步趋势
4. 进度展示是纯信息性的——不提供任何游戏内优势

### Progression Metrics

| 指标 | 计算方式 | 展示方式 |
|------|---------|---------|
| 平均连击长度 | 总连击数 / 连击中断次数 | 折线图（最近 10 局） |
| 闪避成功率 | 成功闪避次数 / 总闪避次数 | 百分比趋势 |
| 万剑归宗频率 | 万剑归宗次数 / 游戏时长（分钟） | 每分钟触发次数趋势 |

### Interactions

**上游依赖：** 连击/万剑归宗系统, 玩家控制器, 计分系统
**下游依赖：** HUD/UI（进度展示画面）

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `get_average_combo` | `get_average_combo()` | `float` | 历史平均连击长度 |
| `get_dodge_success_rate` | `get_dodge_success_rate()` | `float` | 历史闪避成功率（0–1） |
| `get_myriad_frequency` | `get_myriad_frequency()` | `float` | 历史万剑归宗频率 |
| `record_run` | `record_run(run_data: RunData)` | `void` | 记录本局数据 |
| `get_trend` | `get_trend(metric: String)` | `Array[float]` | 最近 10 局的趋势数据 |

## Edge Cases

- **如果只玩了一局**：无趋势数据，只显示本局指标。
- **如果某个指标从未发生**（如从未触发万剑归宗）：显示 0，不做特殊处理。
- **如果 Web 平台清除了本地存储**：所有历史数据丢失，从零开始追踪。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 连击/万剑归宗 | 硬依赖 | 连击数据、万剑归宗触发记录 |
| 玩家控制器 | 硬依赖 | 闪避事件数据 |
| 计分系统 | 软依赖 | 每局数据汇总 |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| HUD/UI | 软依赖 | `get_trend()` — 进度展示画面 |

## Tuning Knobs

| 旋钮 | 默认值 | 说明 |
|------|--------|------|
| `trend_history_size` | 10 | 保留最近 N 局的趋势数据 |

## Acceptance Criteria

- **GIVEN** 玩家完成了 5 局游戏，**WHEN** `get_trend("avg_combo")` 被查询，**THEN** 返回包含 5 个浮点数的数组
- **GIVEN** 本局平均连击长度为 8.5，**WHEN** `record_run` 被调用，**THEN** 历史数据更新
- **GIVEN** 从未触发万剑归宗，**WHEN** `get_myriad_frequency()` 被查询，**THEN** 返回 0.0

## Open Questions

- 进度展示画面何时显示？（死亡后？标题画面？菜单中？）
- 是否需要"里程碑"成就？（如"第一次触发万剑归宗"、"10 连击"）——当前设计不做成就系统。
- 趋势数据的可视化是用简单的折线图还是更丰富的 UI？