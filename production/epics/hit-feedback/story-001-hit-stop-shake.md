# Story 001: 顿帧与屏幕震动

> **Epic**: 命中反馈 (Hit Feedback)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/hit-feedback.md`
**Requirement**: `TR-FBK-002`, `TR-FBK-004`
**ADR Governing Implementation**: ADR-0013: 命中反馈架构
**ADR Decision Summary**: 顿帧公式 hit_stop_frames = base_hit_stop + floor(damage/2)，各剑式独立顿帧时长，玩家受击水平震动，低帧率自适应缩放。

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: Engine.time_scale 用于顿帧，Camera2D.offset 用于震动。均在 LLM 训练数据范围内。

## Acceptance Criteria

- [ ] **游剑式命中**：hit_stop_frames = 2 + floor(1/2) = 2帧，顿帧后恢复
- [ ] **钻剑式命中**：hit_stop_frames = 2 + floor(3/2) = 3帧，顿帧后恢复
- [ ] **绕剑式化解**：hit_stop_frames = 2 + floor(2/2) = 3帧（或默认2帧），顿帧后恢复
- [ ] **玩家受击**：轻微水平震动（±0.1m, 0.1s），HUD 边缘墨迹侵蚀效果
- [ ] **低帧率自适应**：当 fps < 30 时，顿帧时长按比例缩短（TR-FBK-004）

## Implementation Notes

*Derived from ADR-0013 Implementation Guidelines:*

- **顿帧公式**: `hit_stop_frames = base_hit_stop + floor(damage / 2)`，base_hit_stop = 2
- **顿帧执行**: 通过 `Engine.time_scale = 0` 暂停指定帧数，然后恢复 `Engine.time_scale = 1.0`
- **Web 平台注意**: time_scale = 0 可能导致音频爆音，需在顿帧期间暂停音频或静音
- **屏幕震动**: 使用 Camera2D.offset 添加随机偏移，衰减持续 0.1s
- **玩家受击震动**: 水平方向 ±0.1m，与摄像机系统（ADR-0012）协作
- **帧率自适应**: 当检测到 fps < 30 时，`adjusted_frames = hit_stop_frames * (actual_fps / 60.0)`，确保实际暂停时间恒定
- **信号订阅**: HitFeedbackManager 监听 hit_judged 信号，获取 damage 和 form_type，计算顿帧帧数

## Out of Scope

- **Story 002**: 材质反应粒子效果（火花/冲击波/墨点）及对象池管理
- **Story 003**: 万剑归宗特殊反馈（5帧顿帧 + 全屏爆发）

## QA Test Cases

- **AC-1**: 游剑式顿帧 — Given: 命中金属敌人, damage=1, When: 触发命中反馈, Then: Engine.time_scale = 0 持续 2 帧
- **AC-2**: 钻剑式顿帧 — Given: 命中敌人, damage=3, When: 触发命中反馈, Then: Engine.time_scale = 0 持续 3 帧
- **AC-3**: 绕剑式化解顿帧 — Given: 化解敌方攻击, damage=2, When: 触发命中反馈, Then: 顿帧 2-3 帧
- **AC-4**: 玩家受击震动 — Given: 玩家受到攻击, When: 受击反馈触发, Then: Camera2D.offset 水平随机 ±0.1m 持续 0.1s
- **AC-5**: 低帧率缩放 — Given: fps = 20, hit_stop_frames = 3, When: 顿帧触发, Then: 实际暂停时间 = 3 * (20/60) = 1 帧（约 0.05s 等效）
- **AC-Edge**: 多次连续命中 — Given: 短时间内连续命中, When: 顿帧叠加, Then: 新顿帧重置计时器而非累加

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/hit-stop-shake-evidence.md` + sign-off
- 自动化: `tests/unit/hit-feedback/hit_stop_test.gd`（公式验证）

**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: 摄像机系统 story-001（Camera2D 基础跟随）、命中判定 story-001（hit_judged 信号）
- Unlocks: Story 002（材质反应需要顿帧完成）、Story 003（万剑归宗需要顿帧框架）
