# Systems Index: 归宗 (Gui Zong)

> **Status**: Draft
> **Created**: 2026-04-20
> **Last Updated**: 2026-04-20
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

《归宗》是一款中国剑侠 3D 动作 Roguelite，核心是三式剑招（游剑式、钻剑式、绕剑式）的精确打击体验。游戏共需要 18 个系统，从基础输入/渲染框架到核心战斗三式剑招，再到连击/万剑归宗的高潮场景和竞技场波次循环。纯技巧无属性成长的设计意味着没有传统 RPG 进度系统，但需要计分和最佳记录来驱动"再来一局"动机。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 输入系统 (Input System) | Foundation | MVP | Designed | design/gdd/input-system.md | — |
| 2 | 着色器/渲染 (Shader/Rendering) | Foundation | MVP | Designed | design/gdd/shader-rendering.md | — |
| 3 | 音频系统 (Audio System) | Foundation | MVP | Designed | design/gdd/audio-system.md | — |
| 4 | 游戏状态管理 (Game State Manager) | Foundation | MVP | Designed | design/gdd/game-state-manager.md | — |
| 5 | 玩家控制器 (Player Controller) | Core | MVP | Designed | design/gdd/player-controller.md | 输入系统 |
| 6 | 摄像机系统 (Camera System) | Core | MVP | Designed | design/gdd/camera-system.md | 玩家控制器 |
| 7 | 物理碰撞层 (Physics Collision) | Core | MVP | Designed | design/gdd/physics-collision.md | 玩家控制器 |
| 8 | 命中判定层 (Hit Judgment) | Core | MVP | Designed | design/gdd/hit-judgment.md | 物理碰撞层 |
| 9 | 三式剑招系统 (Three Forms Combat) | Core | MVP | Designed | design/gdd/three-forms-combat.md | 输入系统, 命中判定层 |
| 10 | 敌人系统 (Enemy System) | Core | MVP | Designed | design/gdd/enemy-system.md | 命中判定层, 游戏状态管理 |
| 11 | 流光轨迹系统 (Light Trail System) | Feature | MVP | Designed | design/gdd/light-trail-system.md | 三式剑招系统, 着色器/渲染 |
| 12 | 连击/万剑归宗系统 (Combo/Myriad Swords) | Feature | MVP | Designed | design/gdd/combo-myriad-swords.md | 三式剑招系统, 命中判定层 |
| 13 | 命中反馈 (Hit Feedback) | Presentation | MVP | Designed | design/gdd/hit-feedback.md | 命中判定层, 流光轨迹系统, 摄像机系统 |
| 14 | HUD/UI 系统 | Presentation | MVP | Designed | design/gdd/hud-ui-system.md | 连击/万剑归宗, 敌人系统, 游戏状态管理, 摄像机系统 |
| 15 | 竞技场波次系统 (Arena Wave System) | Feature | 完整 Demo | Designed | design/gdd/arena-wave-system.md | 敌人系统, 游戏状态管理 |
| 16 | 关卡/场景管理 (Level/Scene Manager) | Feature | 完整 Demo | Designed | design/gdd/level-scene-manager.md | 游戏状态管理, 着色器/渲染 |
| 17 | 计分系统 (Scoring System) | Polish | 完整 Demo | Designed | design/gdd/scoring-system.md | 连击/万剑归宗, 竞技场波次, 游戏状态管理 |
| 18 | 纯技巧进度系统 (Skill Progression) | Polish | 完整 Demo | Designed | design/gdd/skill-progression.md | 连击/万剑归宗, 竞技场波次 |

**架构调整记录（TD-SYSTEM-BOUNDARY 审查后）：**
- 原"碰撞/命中检测"拆分为"物理碰撞层"（底层工具）+ "命中判定层"（游戏逻辑）
- 原"材质交互系统"合并入"命中反馈"（材质反应作为命中反馈的一部分）
- 补充依赖：HUD→摄像机、计分→游戏状态

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Foundation** | 零依赖的底层框架 | 输入系统, 着色器/渲染, 音频系统, 游戏状态管理 |
| **Core** | 依赖 Foundation 的游戏核心 | 玩家控制器, 摄像机系统, 物理碰撞层, 命中判定层, 三式剑招系统, 敌人系统 |
| **Feature** | 依赖 Core 的玩法系统 | 流光轨迹, 连击/万剑归宗, 竞技场波次, 关卡/场景管理 |
| **Presentation** | 依赖 Feature 的展示层 | 命中反馈（含材质交互）, HUD/UI |
| **Polish** | 依赖 Feature+Presentation 的元系统 | 计分系统, 纯技巧进度系统 |

---

## Dependency Map

### Foundation Layer (零依赖)

1. **输入系统** — 所有玩家操作的入口，剑招精确时序的基础
2. **着色器/渲染** — Web 导出的渲染管线，水墨风格着色器的载体
3. **音频系统** — 精确命中音效的播放通道，三式各有音色
4. **游戏状态管理** — 战斗/间歇/死亡/菜单的状态流转枢纽

### Core Layer (依赖 Foundation)

1. **玩家控制器** — 依赖: 输入系统 — 玩家移动、闪避、输入映射
2. **摄像机系统** — 依赖: 玩家控制器 — 3D 竞技场视角跟随
3. **物理碰撞层** — 依赖: 玩家控制器 — 空间查询、碰撞体管理、射线检测（底层工具）
4. **命中判定层** — 依赖: 物理碰撞层 — 伤害计算、无敌帧、命中类型判断（游戏逻辑）
5. **三式剑招系统** — 依赖: 输入系统, 命中判定层 — 游戏核心身份 ⚠️ **瓶颈系统（4个依赖）**
6. **敌人系统** — 依赖: 命中判定层, 游戏状态管理 — 5种敌人的 AI、生命值、受击反馈

### Feature Layer (依赖 Core)

1. **流光轨迹系统** — 依赖: 三式剑招系统, 着色器/渲染 — 墨色/金色流光追踪剑尖
2. **连击/万剑归宗系统** — 依赖: 三式剑招系统, 命中判定层 — 连击积累和终极触发
3. **竞技场波次系统** — 依赖: 敌人系统, 游戏状态管理 — 随机波次、难度递增
4. **关卡/场景管理** — 依赖: 游戏状态管理, 着色器/渲染 — 2个区域的加载和切换

### Presentation Layer (依赖 Feature)

1. **命中反馈** — 依赖: 命中判定层, 流光轨迹系统, 摄像机系统 — 顿帧、屏幕震动、材质反应（火花/裂纹/墨点炸碎）
2. **HUD/UI 系统** — 依赖: 连击/万剑归宗, 敌人系统, 游戏状态管理, 摄像机系统 — 生命值墨滴、连击计数、菜单

### Polish Layer (依赖 Feature + Presentation)

1. **计分系统** — 依赖: 连击/万剑归宗, 竞技场波次, 游戏状态管理 — 最佳记录、波次计数、分数持久化
2. **纯技巧进度系统** — 依赖: 连击/万剑归宗, 竞技场波次 — 局间视觉进度表达

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | 游戏状态管理 | MVP | Foundation | S |
| 2 | 输入系统 | MVP | Foundation | S |
| 3 | 着色器/渲染 | MVP | Foundation | M |
| 4 | 音频系统 | MVP | Foundation | S |
| 5 | 玩家控制器 | MVP | Core | M |
| 6 | 物理碰撞层 | MVP | Core | M |
| 7 | 命中判定层 | MVP | Core | S |
| 8 | 摄像机系统 | MVP | Core | S |
| 9 | 三式剑招系统 | MVP | Core | L |
| 10 | 敌人系统 | MVP | Core | M |
| 11 | 流光轨迹系统 | MVP | Feature | M |
| 12 | 连击/万剑归宗系统 | MVP | Feature | M |
| 13 | 命中反馈 | MVP | Presentation | M |
| 14 | HUD/UI 系统 | MVP | Presentation | M |
| 15 | 竞技场波次系统 | 完整 Demo | Feature | M |
| 16 | 关卡/场景管理 | 完整 Demo | Feature | S |
| 17 | 计分系统 | 完整 Demo | Polish | S |
| 18 | 纯技巧进度系统 | 完整 Demo | Polish | S |

---

## Circular Dependencies

- 未发现循环依赖。

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 物理碰撞层 | Technical | Web 平台实时碰撞检测性能，直接影响"精确即力量"支柱 | 早期原型验证帧率和碰撞精度 |
| 三式剑招系统 | Design | 三式平衡是最大设计风险——需要确保没有"最强形态" | 大量测试每式的使用场景覆盖率 |
| 着色器/渲染 | Technical | 水墨风格着色器的 WebGL 兼容性未验证 | 制作着色器原型在目标浏览器测试 |
| 敌人系统 | Scope | 5 种敌人意味着 5 套 AI + 动画 + 模型，个人开发者最大瓶颈 | 先用 1 种敌人验证，再扩展 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 18 |
| Design docs started | 18 |
| Design docs reviewed | 0 |
| Design docs approved | 18 |
| MVP systems designed | 14/14 |
| 完整 Demo systems designed | 4/4 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Prototype the highest-risk system early (`/prototype physics-collision`)
