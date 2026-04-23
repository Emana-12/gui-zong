# Story 001: FSM Core & State Transitions

> **Epic**: 游戏状态管理
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/game-state-manager.md`
**Requirement**: `TR-GSM-001`, `TR-GSM-002`, `TR-GSM-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Game State Architecture
**ADR Decision Summary**: Autoload singleton `GameStateManager` with GDScript enum `State`, transition matrix as Dictionary, Godot signal `state_changed(old, new)` for broadcasting.

**Estimate**: 3 points (~2-3 hours)
**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: GDScript signal mechanism and enum within LLM training data. No post-cutoff APIs.

**Control Manifest Rules (Foundation layer)**:
- Required: Autoload singleton + GDScript enum + Godot signal for state management
- Required: All transitions via `change_state(new_state)` method
- Forbidden: Directly modifying other systems' states — must use signals or query interfaces
- Forbidden: Using `_process()` for input

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-manager.md`, scoped to this story:*

- [ ] **GIVEN** 游戏启动，**WHEN** 初始化完成，**THEN** 当前状态为 TITLE
- [ ] **GIVEN** TITLE 状态，**WHEN** 玩家按下开始键（调用 `change_state(COMBAT)`），**THEN** 状态转换为 COMBAT，发出 `state_changed(TITLE, COMBAT)` 信号
- [ ] **GIVEN** COMBAT 状态，**WHEN** 玩家生命值归零（调用 `change_state(DEATH)`），**THEN** 状态转换为 DEATH，发出 `state_changed(COMBAT, DEATH)` 信号
- [ ] **GIVEN** DEATH 状态，**WHEN** 等待时间 ≥ `death_delay` 且调用 `change_state(RESTART)`，**THEN** 状态经 RESTART 瞬时转换为 COMBAT（外部系统观察到 RESTART 状态至少 1 帧）
- [ ] **GIVEN** DEATH 状态，**WHEN** 等待时间 < `death_delay` 且调用 `change_state(RESTART)`，**THEN** 返回 false，状态保持 DEATH，不发出信号
- [ ] **GIVEN** 任意状态，**WHEN** `change_state` 传入当前状态，**THEN** 无操作，不发出信号，返回 false
- [ ] **GIVEN** 任意状态转换，**WHEN** 转换完成，**THEN** 所有依赖系统在同一帧内收到 `state_changed` 信号
- [ ] **GIVEN** 非法转换（如 TITLE→DEATH），**WHEN** 调用 `change_state`，**THEN** 返回 false，push_warning 输出日志

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- **Autoload 单例** `GameStateManager` 注册为 Godot Autoload，全局可访问
- **State 枚举**: `enum State { TITLE, COMBAT, INTERMISSION, DEATH, RESTART }`
- **转换矩阵**: Dictionary 定义合法转换：`TITLE: [COMBAT]`, `COMBAT: [INTERMISSION, DEATH]`, `INTERMISSION: [COMBAT]`, `DEATH: [RESTART]`, `RESTART: [COMBAT]`
- **RESTART 是外部可见状态**: `change_state(RESTART)` 将状态设为 RESTART，发出信号。然后立即（同一帧）自动转换为 COMBAT。外部系统会观察到两次信号：`(DEATH→RESTART)` 和 `(RESTART→COMBAT)`
- **death_delay 计时**: GameStateManager 内部使用 Godot Timer 节点管理。进入 DEATH 时启动 Timer（时长 = `death_delay`），Timer 完成前 `change_state(RESTART)` 被拒绝
- **player_died 信号**: 由玩家控制器发出。GameStateManager 不发出此信号——它监听此信号并调用 `change_state(DEATH)`。本 Story 不需要实现 player_died 的发射方
- **全局暂停**: 通过 `get_tree().paused = true/false` 实现。暂停独立于状态机——暂停时状态不变

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: INTERMISSION 状态管理、wave_completed 信号响应、同帧死亡优先级
- **Story 003**: pause_game/resume_game、Web 焦点丢失自动暂停

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**Timer Mocking Note**: `death_delay` uses a Godot Timer node. In tests, set `timer.wait_time` to a short value (e.g. 0.01s) and call `timer.start()` then await `timer.timeout` to deterministically test AC-4/AC-5 without real-time delays. Alternatively, expose `_death_delay_timer` for test injection.

**Automated test specs (Logic story):**

- **AC-1**: 游戏初始状态为 TITLE
  - Given: GameStateManager 已通过 _ready() 初始化
  - When: 调用 get_current_state()
  - Then: 返回 State.TITLE
  - Edge cases: 多次调用返回一致结果

- **AC-2**: TITLE→COMBAT 转换发出信号
  - Given: 当前状态 = TITLE
  - When: 调用 change_state(State.COMBAT)
  - Then: get_current_state() == State.COMBAT; state_changed 信号参数为 (TITLE, COMBAT); 返回 true
  - Edge cases: 验证信号参数顺序(old_state, new_state)

- **AC-3**: COMBAT→DEATH 转换
  - Given: 当前状态 = COMBAT
  - When: 调用 change_state(State.DEATH)
  - Then: get_current_state() == State.DEATH; state_changed(COMBAT, DEATH) 被发射
  - Edge cases: 信号参数正确性

- **AC-4**: DEATH 等待 death_delay 后重启
  - Given: 当前状态 = DEATH, death_delay Timer 已完成
  - When: 调用 change_state(State.RESTART)
  - Then: 外部系统观察到两次信号: (DEATH→RESTART) 和 (RESTART→COMBAT); 最终状态 = COMBAT
  - Edge cases: RESTART 状态至少持续 1 帧

- **AC-5**: DEATH delay 未到时忽略重启
  - Given: 当前状态 = DEATH, death_delay Timer 未完成
  - When: 调用 change_state(State.RESTART)
  - Then: 返回 false, 状态保持 DEATH, 不发出信号
  - Edge cases: death_delay 边界值 (刚好 0.5s vs 0.499s)

- **AC-6**: 同状态 change_state 无操作
  - Given: 当前状态 = COMBAT
  - When: 调用 change_state(State.COMBAT)
  - Then: 返回 false, 无信号发出, 状态不变
  - Edge cases: 对所有 5 个状态各测一次

- **AC-7**: 非法转换被拒绝
  - Given: 当前状态 = TITLE
  - When: 调用 change_state(State.DEATH)
  - Then: 返回 false, 状态不变, push_warning 输出
  - Edge cases: 测试多组非法转换 (TITLE→DEATH, DEATH→COMBAT, INTERMISSION→DEATH)

- **AC-8**: 信号在同一帧内到达
  - Given: 两个 mock 监听系统已连接 state_changed 信号
  - When: 调用 change_state()
  - Then: 两个监听系统在同一个 process_frame 内都收到信号
  - Edge cases: 多个监听系统同时连接

- **AC-Edge**: 同帧竞争转换优先级（DEATH 优先）
  - Given: COMBAT 状态，最后一击同时触发 player_died 和 wave_completed
  - When: 两个事件在同一帧内调用 change_state(DEATH) 和 change_state(INTERMISSION)
  - Then: 最终状态为 DEATH，INTERMISSION 转换被忽略（因 COMBAT→DEATH 已执行，后续 INTERMISSION 调用因状态已离开 COMBAT 被拒绝）
  - Edge cases: 调用顺序反转（wave_completed 先于 player_died），结果应相同

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game-state-manager/fsm_core_test.gd` — must exist and pass
- Tests cover: all legal transitions, all illegal transitions, same-state no-op, death_delay gating, signal parameters

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation layer, zero dependency)
- Unlocks: Story 002 (needs FSM core for intermission), Story 003 (needs pause mechanism)

---

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 8/8 passing
**Deviations**:
- ADVISORY: `death_delay` @export_range 下限 0.1s 与 GDD 安全范围 0.2s 不一致
- ADVISORY: AC-7 测试未断言 `push_warning` 输出
- ADVISORY: 重入保护锁 (`_transitioning`) 无独立测试覆盖
**Test Evidence**: Logic — `tests/unit/game-state-manager/fsm_core_test.gd` (11 test functions)
**Code Review**: Complete (GDScript specialist + QA tester + Lead Programmer)
