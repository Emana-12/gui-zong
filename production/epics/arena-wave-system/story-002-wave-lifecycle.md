# Story 002: 波次生命周期与完成

> **Epic**: 竞技场波次系统 (Arena Wave System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/arena-wave-system.md`
**Requirement**: TR-WAVE-002, TR-WAVE-004, TR-WAVE-005
**ADR Governing Implementation**: ADR-0014: 竞技场波次架构
**ADR Decision Summary**: 波次完成后进入 INTERMISSION 状态并发出 `wave_completed` 信号，最大同屏 10 敌人，超出的敌人排队等待生成，波次间有短暂休息间隔。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/arena-wave-system.md`, scoped to this story:*

- [ ] 波次所有敌人死亡时 `get_alive_count()` = 0，`wave_completed` 信号触发
- [ ] 活跃敌人 = 10（上限）时，新敌人需要生成则进入排队等待
- [ ] 波次完成后进入 INTERMISSION 状态，短暂间隔后自动开始下一波

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 监听 enemy AI 系统的 `enemy_died` 信号，每次收到后检查 `get_alive_count()`
- 当存活数降为 0 时发出 `wave_completed(wave_number)` 信号
- 生成队列使用 Array 存储待生成的敌人数据
- 每次有敌人死亡时检查队列，若活跃数 < 10 则从队列取出并生成
- INTERMISSION 状态使用 Timer 节点控制间隔（可配置，默认 3 秒）
- 状态机：COMBAT → (wave_completed) → INTERMISSION → (timer) → COMBAT + start_wave(n+1)

## Out of Scope

- 波次生成公式与敌人类型解锁（Story 001）
- 实际敌人 AI 与死亡逻辑（enemy-system Epic）
- 波次计分（scoring-system Epic）

## QA Test Cases

- **AC-1**: 波次完成信号
  - Given: 波次 3 有 4 个敌人，已有 3 个死亡
  - When: 最后 1 个敌人死亡，`get_alive_count()` = 0
  - Then: `wave_completed(3)` 信号被发出
  - Edge cases: 万剑归宗一帧杀光所有敌人（同时死亡）

- **AC-2**: 生成队列与上限
  - Given: 活跃敌人 = 10（上限），队列中有 3 个待生成敌人
  - When: 1 个敌人死亡，`get_alive_count()` 变为 9
  - Then: 从队列取出 1 个敌人生成，活跃数恢复为 10
  - Edge cases: 多个敌人同时死亡（队列批量补充）

- **AC-3**: INTERMISSION 状态
  - Given: 波次完成
  - When: 进入 INTERMISSION
  - Then: Timer 开始倒计时，倒计时结束后自动调用 `start_wave(next_wave)`
  - Edge cases: 玩家在 INTERMISSION 期间退出

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/arena-wave-system/wave_lifecycle_test.gd`
**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: Story 001 (波次生成逻辑), ADR-0007 (enemy_died 信号)
- Unlocks: scoring-system 的波次记录、HUD 波次显示
