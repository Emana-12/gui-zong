# Story 002: 万剑归宗触发与公式

> **Epic**: 连击/万剑归宗系统 (Combo/Myriad Swords)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/combo-myriad-swords.md`
**Requirement**: TR-COMBO-002, TR-COMBO-003
**ADR Governing Implementation**: ADR-0009: 连击系统架构
**ADR Decision Summary**: 10 连击蓄力完成可手动触发万剑归宗，20 连击自动触发，万剑归宗的轨迹数/伤害/范围通过公式根据连击数缩放，触发后进入冷却。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/combo-myriad-swords.md`, scoped to this story:*

- [ ] 连击数 = 10 时，`get_charge_progress()` 返回 1.0（蓄力完成）
- [ ] 连击数 = 10 且蓄力完成时，`trigger_myriad()` 成功触发万剑归宗
- [ ] 连击数 = 20 时达到自动触发阈值，万剑归宗自动触发
- [ ] 万剑归宗触发后，10 连击时轨迹数 = 40，伤害 = 10，范围 = 8m
- [ ] 万剑归宗冷却中时，`trigger_myriad()` 返回 false

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- `get_charge_progress()` 返回 `clamp(combo_count / 10.0, 0.0, 1.0)`
- 手动触发：连击 >= 10 且不在冷却中
- 自动触发：连击达到 20 时立即触发
- 万剑归宗公式（基于连击数 n）：
  - 轨迹数 = 20 + combo_count * 2（上限 50）
  - 伤害 = 5 + combo_count * 0.5
  - 范围 = 8.0（固定）
- 冷却使用 Timer 节点，冷却期间拒绝触发

## Out of Scope

- 连击计数与超时逻辑（Story 001）
- combo_changed / myriad_triggered 信号与下游集成（Story 003）
- 轨迹实际生成（light-trail-system Epic）

## QA Test Cases

- **AC-1**: 蓄力进度查询
  - Given: 连击数 = 10
  - When: 调用 `get_charge_progress()`
  - Then: 返回 1.0
  - Edge cases: combo=0 返回 0.0、combo=5 返回 0.5、combo=15 返回 1.0（clamp）

- **AC-2**: 手动触发万剑归宗
  - Given: 连击数 = 10，不在冷却中
  - When: 调用 `trigger_myriad()`
  - Then: 返回 true，进入冷却状态
  - Edge cases: combo=9 时触发失败、冷却中触发失败

- **AC-3**: 自动触发
  - Given: 连击数 = 19
  - When: 下一次有效命中使连击数达到 20
  - Then: 万剑归宗自动触发，无需手动调用
  - Edge cases: combo 从 19 跳到 21（同式不变不影响）

- **AC-4**: 公式计算
  - Given: 万剑归宗触发，连击数 = 10
  - When: 查询轨迹数、伤害、范围
  - Then: 轨迹数 = 40（20+10×2），伤害 = 10（5+10×0.5），范围 = 8.0m
  - Edge cases: combo=20 时轨迹数=50（上限）、伤害=15、范围=8.0m

- **AC-5**: 冷却拒绝
  - Given: 万剑归宗刚触发，冷却 Timer 正在运行
  - When: 再次调用 `trigger_myriad()`
  - Then: 返回 false
  - Edge cases: 冷却刚结束时触发成功

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combo-myriad-swords/myriad_trigger_test.gd`
**Status**: Complete (tests/unit/combo-myriad-swords/myriad_trigger_test.gd — 22 test functions, all passing)

## Dependencies

- Depends on: Story 001 (连击计数器)
- Unlocks: Story 003 (信号集成)
