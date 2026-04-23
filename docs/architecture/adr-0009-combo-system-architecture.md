# ADR-0009: 连击系统架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core (Scripting) |
| **Knowledge Risk** | LOW |
| **References Consulted** | — |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006（三式剑招系统） |
| **Enables** | 计分系统, 纯技巧进度系统 |
| **Blocks** | 计分系统实现 |

## Decision

使用 **GDScript 纯逻辑 + 信号驱动** 模式。连击系统不涉及渲染或物理——纯计数和触发逻辑。

核心架构：
1. **连击计数**：不同剑式连续命中才 +1，同式连续不增加但不断连
2. **连击超时**：默认 3 秒无命中则归零
3. **万剑归宗蓄力**：10 连击蓄力完成，20 连击自动触发
4. **万剑归宗效果**：范围伤害（5 + combo × 0.5），轨迹数（20 + combo × 2），范围（5 + combo × 0.3m）

### Key Interfaces

```gdscript
signal combo_changed(count: int)
signal myriad_triggered()

func get_combo_count() -> int
func get_charge_progress() -> float  # 0.0–1.0
func is_myriad_ready() -> bool
func trigger_myriad() -> bool
func reset_combo() -> void
```

## Consequences

### Positive
- 纯逻辑系统——无渲染/物理开销
- 连击规则简洁清晰
- 万剑归宗的壮观程度与连击数成正比——直接体现"技巧即力量"

### Negative
- 连击超时（3 秒）的平衡需要原型测试
- 自动触发（20 连击）可能让手动触发失去意义

## GDD Requirements Addressed

| GDD System | Requirement |
|------------|-------------|
| combo-myriad-swords.md | Core Rules 1-6 |
| combo-myriad-swords.md | Combo Rules |
| combo-myriad-swords.md | Myriad Swords Rules |
