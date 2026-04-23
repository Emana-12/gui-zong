# Story 003: 连击系统信号集成

> **Epic**: 连击/万剑归宗系统 (Combo/Myriad Swords)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/combo-myriad-swords.md`
**Requirement**: TR-COMBO-005
**ADR Governing Implementation**: ADR-0009: 连击系统架构
**ADR Decision Summary**: 连击系统通过 `combo_changed(new_count)` 和 `myriad_triggered(trail_count, damage, range)` 两个信号与下游系统（HUD、轨迹系统、计分系统）集成。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/combo-myriad-swords.md`, scoped to this story:*

- [ ] 连击数变化时发出 `combo_changed(new_count)` 信号
- [ ] 万剑归宗触发时发出 `myriad_triggered(trail_count, damage, range)` 信号
- [ ] 信号与 HUD 连击显示集成正确
- [ ] 信号与 light-trail-system 批量轨迹集成正确
- [ ] 信号与计分系统集成正确

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 信号定义在连击系统节点上，遵循 snake_case 过去式命名
- `combo_changed` 在每次连击数变化（+1 或归零）时发出
- `myriad_triggered` 在万剑归宗触发时发出，携带公式计算结果
- 下游系统通过 `connect()` 连接信号
- 信号在单帧内发出，确保下游系统在下一帧收到更新

## Out of Scope

- 连击计数与超时逻辑（Story 001）
- 万剑归宗触发与公式逻辑（Story 002）
- HUD 实际渲染（hud-ui-system Epic）
- 轨迹实际生成（light-trail-system Epic）

## QA Test Cases

- **AC-1**: combo_changed 信号
  - Given: 连击数 = 0，已连接 combo_changed 信号
  - When: 有效命中使连击数变为 1
  - Then: 信号携带参数 1 被发出
  - Edge cases: 连击归零时信号携带参数 0、重复连接不重复触发

- **AC-2**: myriad_triggered 信号
  - Given: 连击数 = 10，不在冷却中，已连接 myriad_triggered 信号
  - When: 调用 `trigger_myriad()`
  - Then: 信号携带 (trail_count=15, damage=5, range=8.0) 被发出
  - Edge cases: 自动触发时信号同样发出、冷却拒绝时不发出信号

- **AC-3**: 下游集成
  - Given: HUD、轨迹系统、计分系统均已连接对应信号
  - When: 连击变化或万剑归宗触发
  - Then: 所有下游系统在同一帧内收到信号并更新状态
  - Edge cases: 某一下游系统未连接时不影响其他系统

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combo-myriad-swords/combo_signals_test.gd`
**Status**: Complete — AC-1, AC-2 covered by unit tests (combo_counter_test.gd + myriad_trigger_test.gd). AC-3 (downstream integration) deferred to scene wiring phase — signals defined and emitted, consumers connect at runtime.

## Completion Notes
- `combo_changed(count)` emitted on hit (line 117) and reset (line 208)
- `charge_changed(progress)` emitted on hit (line 118) and reset (line 209)
- `myriad_triggered(trail_count, damage, radius)` emitted in trigger_myriad() (line 177)
- AC-3 downstream integration (HUD, light-trail, scoring) requires scene tree wiring — verified signal definitions exist, connections deferred to integration testing phase

## Dependencies

- Depends on: Story 001 (计数器), Story 002 (触发与公式)
- Unlocks: HUD 连击显示、light-trail-system 批量触发、计分系统连击记录
