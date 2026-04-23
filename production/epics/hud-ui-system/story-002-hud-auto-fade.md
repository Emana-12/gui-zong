# Story 002: HUD 自动淡出与状态响应

> **Epic**: HUD/UI 系统
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/hud-ui-system.md`
**Requirement**: `TR-HUD-002`, `TR-HUD-003`
**ADR Governing Implementation**: ADR-0015: HUD/UI 架构
**ADR Decision Summary**: 信号订阅驱动 HUD 状态切换，3 秒无受击自动淡出至 0.3 alpha，受击立即恢复全显，万剑归宗特殊淡出。

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: CanvasItem.modulate alpha 和 Tween 均在 LLM 训练数据范围内。

## Acceptance Criteria

- [ ] **自动半透明**：3 秒内玩家未受伤 → HUD alpha 从 1.0 渐变至 0.3
- [ ] **受伤恢复全显**：玩家受伤 → HUD alpha 立即恢复至 1.0（不渐变）
- [ ] **万剑归宗淡出**：fade_hud(0.0, 0.3) → HUD 在 0.3 秒内完全淡出（alpha 1.0→0.0）
- [ ] **万剑归宗恢复**：万剑归宗效果结束后 → HUD 渐显回 1.0
- [ ] **公式正确**: `hud_alpha = lerp(current_alpha, target_alpha, fade_speed * delta)` 实现平滑过渡

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- **淡出公式**: `hud_alpha = lerp(current_alpha, target_alpha, fade_speed * delta)`
  - target_alpha = 0.3 if time_since_last_hit > 3.0 else 1.0
  - fade_speed 控制渐变速度，建议值 2.0-3.0
- **时间追踪**: 使用 `_last_hit_time` 变量，每次受击时更新为 `Time.get_ticks_msec()`
- **受击信号**: 订阅 PlayerController 的 `health_changed` 信号，参数 (old_health, new_health)
  - new_health < old_health 时标记为受伤，重置计时器，alpha 恢复 1.0
- **万剑归宗淡出**: 监听 ComboSystem 的 `combo_myriad_triggered` 信号
  - fade_hud(target_alpha=0.0, duration=0.3) 使用 Tween 执行
  - 效果结束后 fade_hud(1.0, 0.5) 恢复
- **状态依赖**: 非 COMBAT 状态下，淡出逻辑不生效（直接隐藏或由 Story 003 控制）
- **性能**: `_process(delta)` 中每帧 lerp 计算量极小，无性能风险

## Out of Scope

- **Story 001**: 战斗 HUD 基础显示（生命值/连击/剑式/蓄力环）
- **Story 003**: 菜单系统、游戏结束画面

## QA Test Cases

- **AC-1**: 自动淡出 — Given: COMBAT 状态, 3 秒内无受击, When: 3 秒后检查, Then: HUD alpha ≈ 0.3
- **AC-2**: 受伤恢复 — Given: HUD alpha=0.3, When: 玩家受击, Then: HUD alpha 立即 = 1.0（当帧）
- **AC-3**: 万剑归宗淡出 — Given: COMBAT, HUD 可见, When: 调用 fade_hud(0.0, 0.3), Then: 0.3 秒内 alpha 1.0→0.0
- **AC-4**: 万剑归宗恢复 — Given: 万剑归宗效果完成, When: 效果结束信号, Then: HUD 渐显回 1.0
- **AC-5**: 公式平滑 — Given: alpha=1.0, target=0.3, When: 多帧 lerp, Then: 每帧 alpha 平滑递减（无跳变）
- **AC-Edge**: 连续受击 — Given: HUD alpha 正在淡出, When: 连续受击 2 次, Then: 每次立即重置 alpha=1.0
- **AC-Edge**: 非 COMBAT 状态 — Given: TITLE 状态, When: 3 秒后, Then: 淡出逻辑不执行

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: `production/qa/evidence/hud-auto-fade-evidence.md` + 截图
- 自动化: `tests/unit/hud-ui-system/hud_fade_test.gd`（淡出公式、信号响应）

**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: Story 001（HUD 基础显示就绪）、PlayerController story-003（health_changed 信号）、ComboSystem（myriad 信号）
- Unlocks: Story 003（菜单系统需要 HUD 状态响应能力）
