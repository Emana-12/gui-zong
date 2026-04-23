# 关卡/场景管理 (Level/Scene Manager)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 极简即美学 (Pillar 2)

## Overview

**关卡/场景管理**管理 2 个竞技场区域（山石/水竹）的加载、切换和重置。它确保玩家在重启时能快速回到战斗，同时在完整 Demo 中支持区域选择。

**职责边界：**
- **做**：场景加载/卸载、区域切换、场景重置（RESTART 时）、区域选择入口
- **不做**：场景内容设计（由 Art Bible 定义视觉风格）、敌人生成（竞技场波次系统）

## Player Fantasy

**两个区域，两种山水——山石险峻，水竹空灵。**

玩家感受到的是：
- 山石区：锐角几何、强烈侧光、沉重压迫
- 水竹区：柔和曲线、散射光、空灵飘逸
- 切换时：水墨晕开过渡，自然如画卷翻页

## Detailed Design

### Core Rules

1. 场景使用 Godot 的 `PackedScene` 资源预加载——2 个区域在启动时加载到内存
2. 区域切换通过 `change_scene(scene_name)` 触发——销毁当前场景实例，实例化新场景
3. 场景重置通过 `reset_scene()` 触发——重新实例化当前场景（RESTART 时调用）
4. 区域选择在 TITLE 状态或 INTERMISSION 状态可用（完整 Demo 功能）
5. 场景加载时间目标 < 1 秒（Web 平台可能更长）

### Scene List

| 区域 | 场景文件 | 视觉风格 | 出现敌人 |
|------|---------|---------|---------|
| 山石区 | `ArenaMountain.tscn` | 锐角、斧劈皴、墨青底 | 松韧型、重甲型、远程型 |
| 水竹区 | `ArenaBamboo.tscn` | 曲线、披麻皴、宣纸底 | 流动型、敏捷型 |

### Interactions

**对外发出的接口：**

| 接口 | 类型 | 说明 |
|------|------|------|
| `change_scene(scene_name: String)` | 切换 | 切换到指定场景 |
| `reset_scene()` | 重置 | 重新实例化当前场景 |
| `get_current_scene()` | 查询 | 当前场景名称 |
| `get_spawn_points()` | 查询 | 获取场景中的敌人生成点 |
| `scene_changed` | 信号 | 场景切换完成 |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 游戏状态管理 | `state_changed` → RESTART | 调用 `reset_scene()` |
| 游戏状态管理 | `state_changed` → TITLE | 加载标题场景 |
| HUD/UI | 区域选择 | 调用 `change_scene()` |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `change_scene` | `change_scene(scene_name: String)` | `void` | 切换场景 |
| `reset_scene` | `reset_scene()` | `void` | 重置当前场景 |
| `get_current_scene` | `get_current_scene()` | `String` | 当前场景名 |
| `get_spawn_points` | `get_spawn_points()` | `Array[Vector3]` | 敌人生成点列表 |

## Edge Cases

- **如果场景加载失败**（Web 端网络问题）：回退到默认场景（山石区），显示错误提示。
- **如果 RESTART 时场景重置失败**：回退到 TITLE 状态。
- **如果区域切换时有活跃敌人**：先销毁所有敌人（`kill_all()`），再切换场景。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 游戏状态管理 | 硬依赖 | `state_changed` 信号 |
| 着色器/渲染 | 硬依赖 | 场景渲染管线 |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 竞技场波次系统 | 硬依赖 | `get_spawn_points()` — 获取生成位置 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `scene_load_timeout` | 5.0s | 2.0–10.0s | 场景加载超时时间（Web 端） |
| `default_scene` | "mountain" | — | 默认场景 |

## Acceptance Criteria

- **GIVEN** 游戏状态为 RESTART，**WHEN** `reset_scene()` 被调用，**THEN** 当前场景被销毁并重新实例化
- **GIVEN** 调用 `change_scene("bamboo")`，**WHEN** 切换完成，**THEN** 水竹区场景加载，`scene_changed` 信号触发
- **GIVEN** 调用 `get_spawn_points()`，**WHEN** 场景中有 5 个生成点，**THEN** 返回 5 个 Vector3 位置
- **GIVEN** 场景加载超时（>5 秒），**WHEN** Web 端加载缓慢，**THEN** 回退到默认场景

## Open Questions

- 场景切换的视觉过渡：是纯黑闪切还是水墨晕开过渡？后者更符合 Art Bible 但实现更复杂。
- 区域选择的 UI 如何呈现？（缩略图预览？文字选择？）
- 水竹区的水面效果如何在 Web 性能预算内实现？