# ADR-0007: 敌人 AI 架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Navigation / Scripting |
| **Knowledge Risk** | LOW |
| **References Consulted** | — |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005（物理碰撞）, ADR-0001（游戏状态管理） |
| **Enables** | 竞技场波次系统 |
| **Blocks** | 竞技场波次系统实现 |

## Decision

使用 **GDScript 状态机 + 简单规则 AI** 模式。不做行为树——5 种敌人各有固定的行为模式，状态机足够。

核心架构：
1. **每个敌人节点**：CharacterBody3D + AI 状态机组件
2. **6 态状态机**：IDLE → APPROACH → ATTACK → RECOVER → HIT_STUN → DEAD
3. **5 种敌人各有参数化差异**：感知范围、攻击范围、移动速度、攻击频率
4. **AI 冻结**：非 COMBAT 状态时所有敌人 AI 停止更新

### 5 种敌人行为

| 类型 | 感知范围 | 攻击范围 | 移动速度 | 特殊行为 |
|------|---------|---------|---------|---------|
| 松韧型 | 10m | 2m | 慢 | 直线冲锋 |
| 重甲型 | 8m | 2.5m | 极慢 | 缓慢逼近，大范围攻击 |
| 流动型 | 12m | 1.5m | 快 | 快速游走，连续攻击 |
| 远程型 | 15m | 10m | 不移动 | 远程投射 |
| 敏捷型 | 10m | 1.8m | 极快 | 闪避玩家攻击 |

## Consequences

### Positive
- 状态机简单易调试
- 参数化差异让 5 种敌人有明确区分
- 无行为树开销

### Negative
- 敏捷型的闪避机制需要特殊处理（检测玩家攻击方向并侧闪）
- 远程型需要独立的投射物管理

## GDD Requirements Addressed

| GDD System | Requirement |
|------------|-------------|
| enemy-system.md | Core Rules 1-6 |
| enemy-system.md | AI State Machine |
| enemy-system.md | Enemy Behaviors by Type |
