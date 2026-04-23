# Story 003: Pause & Web Focus

> **Epic**: 游戏状态管理
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/game-state-manager.md`
**Requirement**: `TR-GSM-005, TR-GSM-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Game State Architecture
**ADR Decision Summary**: Global pause via `get_tree().paused` independent of state machine. Web focus loss triggers auto-pause.

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: `get_tree().paused` is stable Godot API. Web focus notification via `_notification()` — verify on HTML5 export.

**Control Manifest Rules (Foundation layer)**:
- Required: Global pause via `get_tree().paused` — independent of state machine
- Guardrail: Pause must not change game state

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-manager.md`, scoped to this story:*

- [ ] **GIVEN** 游戏运行中，**WHEN** 调用 `pause_game()`，**THEN** `get_tree().paused == true`，`is_paused() == true`，发出 `game_paused(true)` 信号
- [ ] **GIVEN** 已暂停，**WHEN** 调用 `resume_game()`，**THEN** `get_tree().paused == false`，`is_paused() == false`，发出 `game_paused(false)` 信号
- [ ] **GIVEN** 当前状态 = COMBAT，**WHEN** 暂停后恢复，**THEN** `get_current_state() == COMBAT`（状态不变）
- [ ] **GIVEN** Web 平台运行中且 `pause_on_focus_loss=true`，**WHEN** 浏览器标签页切到后台，**THEN** 自动调用 `pause_game()`
- [ ] **GIVEN** 已暂停（因焦点丢失），**WHEN** 浏览器标签页回到前台，**THEN** 自动调用 `resume_game()`

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- **暂停实现**: `get_tree().paused = true` 冻结所有节点的 `_process()` 和 `_physics_process()`（除了设置了 `process_mode = PROCESS_MODE_ALWAYS` 的节点）
- **GameStateManager 自身不被暂停**: 需要设置 `process_mode = PROCESS_MODE_ALWAYS`，确保暂停状态下仍能响应 `resume_game()` 调用
- **Web 焦点检测**: 使用 `_notification(what)` 回调：
  - `NOTIFICATION_APPLICATION_FOCUS_OUT` → 调用 `pause_game()`
  - `NOTIFICATION_APPLICATION_FOCUS_IN` → 调用 `resume_game()`
- **pause_on_focus_loss 控制**: 仅当此参数为 true 时才自动暂停/恢复。如果为 false，焦点变化不触发任何操作
- **暂停不影响 death_delay 计时**: death_delay Timer 需要设置 `process_mode = PROCESS_MODE_ALWAYS`，确保暂停期间计时仍然进行。或者在暂停时记录暂停时间，恢复时补偿

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: FSM 核心、状态转换矩阵
- **Story 002**: INTERMISSION、wave_completed 响应

---

## QA Test Cases

*Written by qa-lead at story creation.*

**Automated test specs (Integration story — API behavior):**

- **AC-1**: pause_game 冻结游戏
  - Given: 游戏运行中, is_paused() == false
  - When: 调用 pause_game()
  - Then: get_tree().paused == true; is_paused() == true; game_paused(true) 信号被发出
  - Edge cases: 重复调用 pause_game() 不产生副作用

- **AC-2**: resume_game 恢复游戏
  - Given: 游戏已暂停
  - When: 调用 resume_game()
  - Then: get_tree().paused == false; is_paused() == false; game_paused(false) 信号被发出
  - Edge cases: 未暂停时调用 resume_game()

- **AC-3**: 暂停不影响当前状态
  - Given: 当前状态 = COMBAT
  - When: 调用 pause_game() 然后 resume_game()
  - Then: get_current_state() == COMBAT（状态不变）
  - Edge cases: 在所有 5 个状态下各测一次

**Manual verification steps (Web focus — cannot automate):**

- **AC-4**: 标签页切后台自动暂停
  - Setup: Web 导出版本在浏览器中运行，进入 COMBAT 状态
  - Verify: 切换到另一个浏览器标签页
  - Pass condition: 游戏立即暂停（画面冻结），is_paused() == true

- **AC-5**: 标签页回前台自动恢复
  - Setup: 游戏因焦点丢失已暂停
  - Verify: 切回游戏标签页
  - Pass condition: 游戏自动恢复，is_paused() == false，状态不变

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/game-state-manager/pause_test.gd` — API behavior tests (pause/resume, state preservation)
- Visual/Feel: `production/qa/evidence/pause-web-focus-evidence.md` — manual Web focus verification with screenshot

**Status**: [ ] Not yet created

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 3/5 passing (AC-1, AC-2, AC-3 ✓; AC-4, AC-5 DEFERRED — 需 Web 导出后手动验证)
**Deviations**: AC-3 Edge Case 缺少 RESTART 状态测试 (ADVISORY); AC-4/AC-5 手动验证证据待 Web 导出 (DEFERRED)
**Test Evidence**: `tests/integration/game-state-manager/pause_test.gd` — 12 个测试函数
**Code Review**: APPROVED WITH SUGGESTIONS (LP-CODE-REVIEW)
**QA Coverage**: GAPS — RESTART 状态测试缺失, 手动证据待补

---

## Dependencies

- Depends on: Story 001 (needs FSM core for state queries)
- Unlocks: None
