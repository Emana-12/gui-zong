# Story 002: Intermission & Wave Completion

> **Epic**: 游戏状态管理
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/game-state-manager.md`
**Requirement**: `TR-GSM-001`, `TR-GSM-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Game State Architecture
**ADR Decision Summary**: COMBAT→INTERMISSION on wave completion, manual or auto-advance back to COMBAT. Death takes priority over wave completion in the same frame.

**Estimate**: 2 points (~1-2 hours)
**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: GDScript signal mechanism within training data. No performance impact — signal callback, not per-frame logic.

**Control Manifest Rules (Foundation layer)**:
- Required: State transitions via `change_state(new_state)` method
- Required: Signal-based notification via `state_changed(old, new)`
- Forbidden: Directly modifying other systems' states

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-manager.md`, scoped to this story:*

- [ ] **GIVEN** COMBAT 状态，**WHEN** 收到外部 `wave_completed` 信号，**THEN** 状态转换为 INTERMISSION，发出 `state_changed(COMBAT, INTERMISSION)`
- [ ] **GIVEN** INTERMISSION 状态且 `intermission_auto_advance=false`，**WHEN** 外部调用 `change_state(COMBAT)`，**THEN** 状态转换为 COMBAT
- [ ] **GIVEN** INTERMISSION 状态且 `intermission_auto_advance=true`，**WHEN** 计时器达到 `intermission_duration`（外部触发），**THEN** 状态转换为 COMBAT
- [ ] **GIVEN** COMBAT 状态，**WHEN** 同一帧内玩家死亡（change_state(DEATH)）且波次完成（wave_completed），**THEN** 优先处理 DEATH，最终状态为 DEATH
- [ ] **GIVEN** 非 COMBAT 状态，**WHEN** 收到 `wave_completed` 信号，**THEN** 忽略，状态不变

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- **wave_completed 信号归属**: 由竞技场波次系统发出，GameStateManager 监听此信号。GameStateManager 不拥有此信号的发射逻辑——它只在收到信号后执行 COMBAT→INTERMISSION 转换
- **INTERMISSION 计时器**: 不在 GameStateManager 中管理。`intermission_duration` 和计时器逻辑由竞技场波次系统负责。竞技场波次系统在计时器到期后调用 `GameStateManager.change_state(COMBAT)`
- **同帧死亡优先级**: 通过游戏循环的执行顺序保证——玩家控制器的 `player_died` 信号在敌人系统的 `wave_completed` 信号之前处理。GameStateManager 收到 `player_died` 后已转换为 DEATH，此时再收到 `wave_completed` 会被忽略（非 COMBAT 状态）
- **intermission_auto_advance**: 此参数由竞技场波次系统拥有，GameStateManager 不管理此值。GameStateManager 只负责接受/拒绝 INTERMISSION→COMBAT 转换

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: FSM 核心、状态转换矩阵、death_delay 机制
- **Story 003**: 暂停管理、Web 焦点

---

## QA Test Cases

*Written by qa-lead at story creation.*

**Automated test specs (Logic story):**

- **AC-1**: COMBAT→INTERMISSION on wave_completed
  - Given: 当前状态 = COMBAT
  - When: 模拟发出 wave_completed 信号
  - Then: get_current_state() == INTERMISSION; state_changed(COMBAT, INTERMISSION) 被发射
  - Edge cases: wave_number 参数正确传递

- **AC-2**: INTERMISSION manual advance
  - Given: 当前状态 = INTERMISSION, intermission_auto_advance=false
  - When: 调用 change_state(State.COMBAT)
  - Then: get_current_state() == COMBAT; 转换成功
  - Edge cases: 验证 intermission_auto_advance 不影响手动转换

- **AC-3**: INTERMISSION auto advance
  - Given: 当前状态 = INTERMISSION, intermission_auto_advance=true
  - When: 外部系统调用 change_state(State.COMBAT)（模拟计时器到期）
  - Then: 状态变为 COMBAT
  - Edge cases: 竞技场波次系统的计时器边界值

- **AC-4**: 同帧死亡优先于波次完成
  - Given: 当前状态 = COMBAT
  - When: 先调用 change_state(DEATH)，再模拟 wave_completed 信号
  - Then: 最终状态 = DEATH; wave_completed 被忽略（非 COMBAT 状态）
  - Edge cases: 反序触发（先 wave 后 death）——需确保游戏循环顺序

- **AC-5**: wave_completed 非 COMBAT 忽略
  - Given: 当前状态 = TITLE
  - When: 收到 wave_completed 信号
  - Then: 状态不变, 无副作用
  - Edge cases: 在 DEATH/RESTART/INTERMISSION 状态各测一次

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game-state-manager/intermission_test.gd` — must exist and pass
- Tests cover: wave completion trigger, manual advance, auto advance (mock), same-frame priority, non-COMBAT ignore

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (needs FSM core for state transitions and signals)
- Unlocks: Story 003 (none — independent)

---

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: `_on_wave_completed` 命名使用 `_on_` 前缀但为公开 API，建议后续改为 `notify_wave_completed`
- ADVISORY: `test_wave_completed_receives_wave_number` 无实际断言，与 AC-1 测试重复
- ADVISORY: GDD 信号表将 `wave_completed` 列为 GameStateManager 发出的信号，但实现中它是接收方
**Test Evidence**: Logic — `tests/unit/game-state-manager/intermission_test.gd` (9 test functions)
**Code Review**: Complete (GDScript specialist + QA tester + Lead Programmer)
