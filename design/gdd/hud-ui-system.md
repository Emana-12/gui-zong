# HUD/UI 系统

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 极简即美学 (Pillar 2)

## Overview

**HUD/UI 系统**是玩家与游戏信息的界面层——生命值墨滴、连击计数器、波次显示、菜单系统。UI 是水墨世界的自然延伸，不是叠加层（Art Bible Section 7: "墨迹侵蚀式"）。

**职责边界：**
- **做**：HUD 显示（生命值/连击/剑式指示/万剑归宗蓄力/波次计数）、菜单系统（标题/暂停/游戏结束/得分）、UI 状态切换
- **不做**：游戏逻辑（游戏状态管理）、数据计算（各系统负责提供数据）

## Player Fantasy

**UI 是画上的题款——属于画面，但有独立身份。**

玩家感受到的是：
- 生命值是一滴墨在消耗——满血时饱满，低血时干涸
- 连击计数器是墨点在积累——密度随连击增长
- 万剑归宗蓄力环填满金色——"来了！"
- 菜单从墨中浮现——肃穆的邀请

**支柱对齐：** Pillar 2（极简即美学）——UI 的"华丽"来自墨迹密度变化，而非装饰。

## Detailed Design

### Core Rules

1. HUD 使用 Godot 的 CanvasLayer + Control 节点——2D UI 叠加在 3D 场景之上
2. 所有 UI 元素使用墨色+金色统一色板（Art Bible Section 4）
3. HUD 在 COMBAT 状态显示，其他状态切换到对应 UI（标题菜单/间歇/死亡画面）
4. 战斗 HUD 在 3 秒无受伤后自动半透明化（减少视觉干扰）
5. 万剑归宗触发时 HUD 淡出，结束后淡入（避免金色淹没 HUD）
6. 死亡画面的文字用纯白而非金墨（对比度保障）

### HUD Elements

| 元素 | 视觉表现 | 数据源 | 更新频率 |
|------|---------|--------|---------|
| 生命值 | 墨滴消耗（大小变化） | 玩家控制器 `get_health()` | 实时 |
| 连击计数 | 墨点积累 + 金色数字 | 连击系统 `get_combo_count()` | 实时 |
| 当前剑式指示 | 三式图标（激活=金墨，未激活=淡墨） | 三式剑招系统 `get_active_form()` | 实时 |
| 万剑归宗蓄力 | 墨色圆环填满金色 | 连击系统 `get_charge_progress()` | 实时 |
| 波次计数 | 金色数字 + 墨色装饰 | 竞技场波次系统 | 每波更新 |

### Menu Systems

| 菜单 | 触发状态 | 内容 | 视觉风格 |
|------|---------|------|---------|
| 标题画面 | TITLE | 游戏名 + "开始"按钮 | 金墨书法 + 水墨山水背景 |
| 暂停菜单 | COMBAT（按取消键） | 继续/重启/退出 | 半透明墨色覆盖 |
| 游戏结束 | DEATH | 得分 + "再来一次" | 墨化为静态水墨画 |
| 得分画面 | DEATH（详细） | 波次/最高连击/万剑归宗次数 | 宣纸质感背景 + 金墨数据 |

### Interactions with Other Systems

**接收的数据：**

| 数据源 | 数据 | 用途 |
|--------|------|------|
| 玩家控制器 | `get_health()`, `get_max_health()`, `health_changed` | 生命值墨滴 |
| 连击系统 | `get_combo_count()`, `get_charge_progress()`, `combo_changed` | 连击计数器 + 蓄力环 |
| 三式剑招系统 | `get_active_form()`, `form_activated` | 剑式指示器 |
| 敌人系统 | `get_alive_count()` | 敌人数量显示 |
| 游戏状态管理 | `state_changed` | UI 状态切换 |
| 摄像机系统 | `get_camera_position()` | 世界坐标转屏幕坐标（敌人血条） |
| 计分系统 | 得分数据 | 得分画面 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `show_hud` | `show_hud()` | `void` | 显示战斗 HUD |
| `hide_hud` | `hide_hud()` | `void` | 隐藏战斗 HUD |
| `show_menu` | `show_menu(menu_name: String)` | `void` | 显示指定菜单 |
| `hide_all_menus` | `hide_all_menus()` | `void` | 隐藏所有菜单 |
| `update_health_display` | `update_health_display(current: int, max_hp: int)` | `void` | 更新生命值显示 |
| `update_combo_display` | `update_combo_display(count: int)` | `void` | 更新连击显示 |
| `update_charge_display` | `update_charge_display(progress: float)` | `void` | 更新蓄力环 |
| `fade_hud` | `fade_hud(to_alpha: float, duration: float)` | `void` | HUD 淡入淡出 |

## Formulas

**HUD 半透明化触发：**

`hud_alpha = lerp(current_alpha, target_alpha, fade_speed * delta)`

`target_alpha = 0.3 if time_since_last_hit > 3.0 else 1.0`

3 秒无受伤后 HUD 自动半透明（alpha=0.3），受伤后立即恢复全显（alpha=1.0）。

## Edge Cases

- **如果 HUD 节点在更新中被销毁**：安全检查后跳过。
- **如果万剑归宗触发时 HUD 已经隐藏**：不执行淡出，直接保持隐藏。
- **如果多个菜单同时请求显示**：后显示的覆盖先显示的（栈式管理）。
- **如果生命值显示与实际值不一致**（帧延迟）：每帧从玩家控制器读取实际值，不做缓存。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 连击/万剑归宗 | 硬依赖 | `get_combo_count()`, `get_charge_progress()` |
| 敌人系统 | 硬依赖 | `get_alive_count()` |
| 游戏状态管理 | 硬依赖 | `state_changed` 信号 |
| 摄像机系统 | 硬依赖 | `get_camera_position()` |

### 下游依赖

无。HUD/UI 是叶节点系统。

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `hud_fade_delay` | 3.0s | 1.0–5.0s | 无受伤后 HUD 半透明化延迟 |
| `hud_fade_alpha` | 0.3 | 0.1–0.5 | HUD 半透明时的 alpha 值 |
| `combo_counter_scale` | 1.0 | 0.5–2.0 | 连击计数器大小倍率 |
| `menu_transition_duration` | 0.3s | 0.1–0.5s | 菜单切换动画时长 |

## Visual/Audio Requirements

**视觉需求（Art Bible Section 7 定义）：**
- 生命值：墨滴消耗（大小变化）
- 连击计数：墨点积累 + 金色数字
- 蓄力环：墨色圆环填满金色
- 菜单：墨迹侵蚀式边缘
- 字体：金墨书法体

**音频需求：**
- 菜单打开/关闭：墨滴落纸声
- 连击 +1：轻"叮"声
- 蓄力完成：提示音

## UI Requirements

**本系统本身就是 UI 系统。** 所有 UI 需求在上述 HUD Elements 和 Menu Systems 中定义。

**📌 UX Flag — HUD/UI 系统**: 此系统有 UI 需求。在 Phase 4（Pre-Production）中，运行 `/ux-design` 为每个屏幕（标题画面/战斗 HUD/暂停菜单/游戏结束/得分画面）创建 UX 规范。

## Acceptance Criteria

- **GIVEN** 游戏状态为 COMBAT，**WHEN** 战斗开始，**THEN** 生命值墨滴、连击计数器、剑式指示器、蓄力环全部显示
- **GIVEN** 玩家生命值从 3 降到 2，**WHEN** `update_health_display(2, 3)` 被调用，**THEN** 墨滴变小
- **GIVEN** 连击数达到 5，**WHEN** `update_combo_display(5)` 被调用，**THEN** 显示 5 个墨点 + 金色数字 "5"
- **GIVEN** 3 秒内玩家未受伤，**WHEN** 检查 HUD 状态，**THEN** HUD 自动半透明（alpha=0.3）
- **GIVEN** 玩家受伤，**WHEN** `update_health_display` 更新，**THEN** HUD 立即恢复全显（alpha=1.0）
- **GIVEN** 万剑归宗触发，**WHEN** `fade_hud(0.0, 0.3)` 被调用，**THEN** HUD 在 0.3 秒内淡出
- **GIVEN** 游戏状态切换到 DEATH，**WHEN** `show_menu("game_over")` 被调用，**THEN** 游戏结束画面从墨中浮现
- **GIVEN** 死亡画面显示，**WHEN** 文字渲染，**THEN** 使用纯白色（非金墨）以确保灰阶背景上的对比度

## Open Questions

- 连击计数器的墨点积累是用预设数量的墨点还是动态生成？预设更可控但有上限。
- 菜单系统的导航是否支持手柄 D-Pad？Web 平台需要考虑手柄用户。
- HUD 元素的位置是固定布局还是响应式？Web 平台不同分辨率需要考虑自适应。