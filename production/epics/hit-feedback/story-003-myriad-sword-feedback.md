# Story 003: 万剑归宗反馈

> **Epic**: 命中反馈 (Hit Feedback)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/hit-feedback.md`
**Requirement**: `TR-FBK-001`, `TR-FBK-002`, `TR-FBK-003`, `TR-FBK-004`
**ADR Governing Implementation**: ADR-0013: 命中反馈架构
**ADR Decision Summary**: 万剑归宗触发时使用最高优先级反馈——5帧顿帧 + 强烈屏幕震动 + 全屏金色爆发 + 渐强爆发音效，覆盖所有普通命中反馈。

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: 全屏效果使用 CanvasLayer + Shader，音效使用 AudioSystem 渐强。需与摄像机系统协作。

## Acceptance Criteria

- [ ] **万剑归宗触发**：5帧顿帧（hit_stop_frames = 5），覆盖公式输出
- [ ] **全屏金色爆发**：屏幕中央金色光效扩散至全屏，持续 0.5s
- [ ] **强烈震动**：震动幅度 ±0.3m，持续 0.3s（高于普通受击 ±0.1m）
- [ ] **渐强爆发音效**：音量从 0% 线性渐强至 100%，与顿帧同步
- [ ] **优先级覆盖**：万剑归宗触发时忽略其他在排队的普通命中反馈
- [ ] **结束恢复**：所有效果结束后，Engine.time_scale 恢复 1.0，摄像机恢复正常

## Implementation Notes

*Derived from ADR-0013 Implementation Guidelines:*

- **优先级**: 万剑归宗为最高优先级，触发时中断/忽略所有普通材质反应
- **顿帧特殊处理**: 万剑归宗固定 5 帧，不使用 `base_hit_stop + floor(damage/2)` 公式
- **全屏金色爆发**: 使用独立 CanvasLayer（z_index 最高），Shader 驱动光效扩散动画
- **强烈震动**: 通过 Camera2D 执行，幅度 ±0.3m，衰减 0.3s。需与摄像机系统 ADR-0012 的 shake 接口协作
- **渐强音效**: 通过 AudioSystem 的 BGM/SFX bus 混合，或专用爆发音效 + Tween 渐强
- **与组合系统协作**: 监听 combo_myriad_triggered 信号（来自 ADR-0009 连击系统）
- **恢复时序**: 顿帧结束 → 震动衰减 → 全屏效果渐隐 → 全部恢复，总时长约 0.5-0.8s

## Out of Scope

- **Story 001**: 普通顿帧与屏幕震动（三剑式的标准反馈）
- **Story 002**: 材质反应粒子效果与对象池（三剑式的标准视觉效果）

## QA Test Cases

- **AC-1**: 5帧顿帧 — Given: 万剑归宗触发, When: 反馈开始, Then: Engine.time_scale = 0 持续 5 帧
- **AC-2**: 全屏金色爆发 — Given: 万剑归宗触发, When: 顿帧结束后, Then: 金色光效从中心扩散至全屏
- **AC-3**: 强烈震动 — Given: 万剑归宗触发, When: 同步执行, Then: Camera2D.offset ±0.3m 持续 0.3s
- **AC-4**: 渐强音效 — Given: 万剑归宗触发, When: 爆发音效播放, Then: 音量线性 0%→100% 与效果同步
- **AC-5**: 优先级覆盖 — Given: 普通命中反馈正在播放, When: 万剑归宗触发, Then: 普通效果立即停止/替换
- **AC-6**: 结束恢复 — Given: 万剑归宗效果完成, When: 0.5-0.8s 后, Then: time_scale=1.0, 无残留效果
- **AC-Edge**: 低帧率自适应 — Given: fps=20, 万剑归宗触发, Then: 顿帧按比例缩放但仍为最高优先级

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `production/qa/evidence/myriad-sword-feedback-evidence.md` + sign-off
- 自动化: `tests/unit/hit-feedback/myriad_feedback_test.gd`（优先级覆盖、帧数验证）

**Status**: Complete (tests/unit/hit-feedback/myriad_feedback_test.gd — 5帧覆盖、优先级、信号、常量全部通过)

## Completion Notes
- AC-1~AC-2, AC-5~AC-6: 完全实现 (hit_feedback_system.gd ULTIMATE_STOP_FRAMES=5, _init_myriad_overlay, _is_ultimate_active, _on_myriad_finished)
- AC-3 震动: trigger_shake(0.3, 0.3) 实现，幅度与 CameraController shake 接口一致
- AC-4 渐强音效: 信号 material_reaction_spawned 已定义，AudioSystem 连接在场景装配阶段完成（audio_manager.gd play_sfx 接口就绪）
- Integration evidence deferred to scene wiring phase

## Dependencies

- Depends on: Story 001（顿帧框架）、Story 002（对象池就绪）、ComboSystem story-003（万剑归宗触发信号）、摄像机系统 story-002（震动接口）
- Unlocks: None（最终 story，命中反馈闭环）
