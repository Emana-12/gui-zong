# Story 002: Input Buffering

> **Epic**: 输入系统
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-INPUT-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Input System Architecture
**ADR Decision Summary**: Single-element input buffer — captures attack inputs during non-interruptible windows. Buffer capacity = 1 (new input overwrites old). Buffer cleared on window expiry or DEATH state.

**Engine**: Godot 4.6.2 stable | **Risk**: MEDIUM
**Engine Notes**: Buffer is pure GDScript logic — no engine risk.

**Control Manifest Rules (Foundation layer)**:
- Required: Buffer capacity = 1 — only one buffered action at a time
- Forbidden: Multi-element buffer queue — causes uncontrolled combos from button mashing

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **GIVEN** 缓冲窗口已激活，**WHEN** 窗口内按下 K 键（钻剑式），**THEN** `get_buffered_action()` 返回 "attack_zuan"
- [ ] **GIVEN** 缓冲区已有 "attack_you"，**WHEN** 窗口内按下 K 键，**THEN** `get_buffered_action()` 返回 "attack_zuan"（旧值被覆盖，容量=1）
- [ ] **GIVEN** 缓冲区有动作但游戏处于 DEATH 状态，**WHEN** 查询缓冲区，**THEN** 缓冲区被清空，返回空
- [ ] **GIVEN** 缓冲区有动作且帧计数达到 `buffer_window_frames`，**WHEN** 查询缓冲区，**THEN** 缓冲区过期清空，返回空
- [ ] **GIVEN** 缓冲窗口已激活，**WHEN** 按下 Space（闪避，非攻击动作），**THEN** `get_buffered_action()` 不包含 "dodge"（非攻击动作不缓冲）
- [ ] **GIVEN** 缓冲窗口内连续快速按下 J、K、L，**WHEN** 查询缓冲区，**THEN** 返回最后按下的 "attack_rao"

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- **缓冲触发条件**: 只有 `attack_` 前缀的动作才被缓冲（`_input()` 中 `action.begins_with("attack_")` 检查）
- **缓冲存储**: `_buffered_action: StringName` + `_buffer_frame_count: int`，两个变量
- **帧计数更新**: 在 `_process(_delta)` 中每帧递增 `_buffer_frame_count`，达到 `buffer_window_frames` 时清空 `_buffered_action`
- **覆盖行为**: 新的攻击输入直接覆盖 `_buffered_action`，重置 `_buffer_frame_count = 0`
- **DEATH 状态清空**: 监听 `GameStateManager.state_changed` 信号，当转换到 DEATH 时清空 `_buffered_action`
- **查询接口**: `get_buffered_action()` 检查帧计数是否超限——超限则清空并返回空

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 基础输入查询 API（is_action_pressed 等）、enable_action、set_buffer_window
- **Story 003**: 手柄支持、Web 延迟验证、手柄断开处理

---

## QA Test Cases

*Written by qa-lead at story creation.*

**Automated test specs (Logic story):**

- **AC-1**: 缓冲捕获
  - Given: 缓冲窗口已激活（buffer_window_frames = 6）
  - When: 在窗口内按下 K 键
  - Then: get_buffered_action() == "attack_zuan"
  - Edge cases: 窗口第 1 帧按下、最后一帧按下

- **AC-2**: 缓冲区覆盖（容量=1）
  - Given: 缓冲区已有 "attack_you"
  - When: 在窗口内按下 K 键
  - Then: get_buffered_action() == "attack_zuan"
  - Edge cases: 连续覆盖 3 次

- **AC-3**: DEATH 状态清空缓冲区
  - Given: 缓冲区有 "attack_zuan"
  - When: 状态切换到 DEATH
  - Then: get_buffered_action() == ""（空）
  - Edge cases: 在缓冲窗口中间切换状态

- **AC-4**: 缓冲窗口过期清空
  - Given: 缓冲区有 "attack_zuan"，帧计数 = 0
  - When: 等待 buffer_window_frames 帧（不产生新输入）
  - Then: get_buffered_action() == ""（空）
  - Edge cases: 边界值（刚好 buffer_window_frames - 1 帧时仍然有效）

- **AC-5**: 非攻击动作不缓冲
  - Given: 缓冲窗口已激活
  - When: 按下 Space（dodge）
  - Then: get_buffered_action() 不包含 "dodge"
  - Edge cases: 所有非攻击动作各测一次

- **AC-6**: 连续快速输入保留最新
  - Given: 缓冲窗口已激活
  - When: 第 1 帧按 J，第 2 帧按 K，第 3 帧按 L
  - Then: get_buffered_action() == "attack_rao"
  - Edge cases: 更快速度（同帧多输入）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input-system/input_buffer_test.gd` — must exist and pass

**Status**: [x] Complete — test file exists and passes

---

## Dependencies

- Depends on: Story 001 (needs is_action_pressed API and buffer_window_frames)
- Unlocks: Story 003 (none — independent)

## Completion Notes
**Completed**: 2026-04-21
**Criteria**: 6/6 passing (all ACs fully covered)
**Deviations**: None
**Test Evidence**: `tests/unit/input-system/input_buffer_test.gd` — 13 test functions, all passing
**Code Review**: LP-CODE-REVIEW → APPROVED
**QA Coverage**: QL-TEST-COVERAGE → ADEQUATE
