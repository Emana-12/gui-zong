# ADR-0006: 三式剑招系统架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core (Scripting) |
| **Knowledge Risk** | LOW — GDScript 状态机和信号在训练数据内 |
| **References Consulted** | — |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002（输入系统）, ADR-0005（物理碰撞） |
| **Enables** | ADR-0008（流光轨迹）, ADR-0009（连击系统） |
| **Blocks** | 流光轨迹系统、连击/万剑归宗系统实现 |

## Decision

使用 **GDScript 枚举 + 状态机 + 物理碰撞层 API** 模式管理三式剑招。

核心架构：
1. **三式枚举**：`enum Form { NONE, YOU, ZUAN, RAO }`
2. **剑招状态机**：IDLE → EXECUTING → RECOVERING → COOLDOWN → IDLE
3. **hitbox 生命周期**：EXECUTING 开始时创建，RECOVERING 开始时销毁
4. **三键独立**：J/K/L 各自触发对应剑式，按下即切换（打断 RECOVERING，不打断 EXECUTING）
5. **冷却独立**：每式有独立冷却计时器，不同式不受彼此冷却影响

### 三式参数

| 参数 | 游剑式 | 钻剑式 | 绕剑式 |
|------|--------|--------|--------|
| 执行时长 | 0.3s | 0.5s | 0.4s |
| 恢复时长 | 0.1s | 0.2s | 0.15s |
| 冷却时间 | 0.2s | 0.5s | 0.3s |
| 基础伤害 | 1 | 3 | 2 |
| DPS | 1.67 | 2.50 | 2.35 |

### Key Interfaces

```gdscript
signal form_activated(form: Form)
signal form_finished(form: Form)

func execute_form(form: Form) -> bool  # 返回是否成功
func get_active_form() -> Form
func is_executing() -> bool
func is_on_cooldown(form: Form) -> bool
func cancel_current() -> void
```

## Consequences

### Positive
- 三式 DPS 均衡（1.67/2.50/2.35）——没有"最强形态"
- 状态机简单清晰——IDLE/EXECUTING/RECOVERING/COOLDOWN 四态
- 冷却独立确保三键独立的战术深度

### Negative
- EXECUTING 不可打断——玩家在执行中无法取消，可能导致被敌人攻击时无法闪避
- 冷却时间的平衡需要大量测试

## GDD Requirements Addressed

| GDD System | Requirement |
|------------|-------------|
| three-forms-combat.md | Core Rules 1-6 |
| three-forms-combat.md | Three Forms Definition (参数表) |
| three-forms-combat.md | Form Switching Rules |

## Related Decisions
- ADR-0002（输入系统）—— 剑招输入和缓冲
- ADR-0005（物理碰撞）—— hitbox 创建/销毁
