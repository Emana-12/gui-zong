# Story 001: 连击计数与超时

> **Epic**: 连击/万剑归宗系统 (Combo/Myriad Swords)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/combo-myriad-swords.md`
**Requirement**: TR-COMBO-001, TR-COMBO-004
**ADR Governing Implementation**: ADR-0009: 连击系统架构
**ADR Decision Summary**: 纯逻辑系统，不同式连续命中 +1 连击，同式连续命中不增加，受击归零，3 秒超时归零。无渲染或物理依赖。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/combo-myriad-swords.md`, scoped to this story:*

- [ ] 游→钻→绕连续命中，第 3 次命中时连击数 = 3
- [ ] 连击数 = 3 时，再使用游剑式命中（与上一式相同），连击数不变（仍 = 3）
- [ ] 连击数 = 5 时被敌人击中，连击归零
- [ ] 连击数 = 7 时，3 秒内无命中，连击归零（超时）

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 使用 GDScript 纯逻辑实现，Timer 节点管理超时
- 每次命中记录上一次使用的剑式类型，仅当当前式与上一式不同时 +1
- 受击事件通过信号接收（`hit_received` 信号），收到后重置计数器
- 超时使用 Godot Timer 节点，每次有效命中后 `restart()`

## Out of Scope

- 万剑归宗触发与公式（Story 002）
- combo_changed / myriad_triggered 信号与下游集成（Story 003）

## QA Test Cases

- **AC-1**: 不同式连续命中 +1
  - Given: 连击数 = 0
  - When: 依次使用游、钻、绕各命中一次
  - Then: 连击数 = 3
  - Edge cases: 游→钻→游→钻（交替）、长序列 20+ 连击

- **AC-2**: 同式连续命中不变
  - Given: 上一次命中使用游剑式，连击数 = 3
  - When: 再次使用游剑式命中
  - Then: 连击数仍为 3，不增加
  - Edge cases: 连续 3 次同式命中、首次命中（连击数 0→1）

- **AC-3**: 受击归零
  - Given: 连击数 = 5
  - When: 收到敌方 hit_received 信号
  - Then: 连击数归零
  - Edge cases: 连击数 = 1 时受击、连续受击两次

- **AC-4**: 超时归零
  - Given: 连击数 = 7，Timer 正在运行
  - When: 3 秒内无新命中
  - Then: Timer 超时回调触发，连击数归零
  - Edge cases: Timer 还剩 0.1 秒时新命中（应重启计时器）

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combo-myriad-swords/combo_counter_test.gd`
**Status**: Complete (tests/unit/combo-myriad-swords/combo_counter_test.gd — 16 test functions, all passing)

## Dependencies

- Depends on: ADR-0009 Accepted, ADR-0006 (三式剑招系统) Accepted
- Unlocks: Story 002 (万剑归宗触发依赖连击计数)
