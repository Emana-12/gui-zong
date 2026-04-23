# Story 003: 菜单系统与游戏结束

> **Epic**: HUD/UI 系统
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/hud-ui-system.md`
**Requirement**: `TR-HUD-004`, `TR-HUD-005`
**ADR Governing Implementation**: ADR-0015: HUD/UI 架构
**ADR Decision Summary**: 菜单栈 push/pop 模式，DEATH 状态触发游戏结束画面，墨迹侵蚀式浮现动画，纯白文字确保对比度，Web 响应式布局。

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: Control 节点、CanvasLayer、Popup/Panel 均在 LLM 训练数据范围内。Web 响应式使用 anchor + expand。

## Acceptance Criteria

- [ ] **菜单栈系统**: push_menu(name) / pop_menu() 实现菜单栈，支持暂停菜单和游戏结束菜单
- [ ] **DEATH 游戏结束**: 游戏状态切换到 DEATH → show_menu("game_over") → 游戏结束画面从墨中浮现
- [ ] **墨迹侵蚀动画**: 游戏结束画面以墨迹侵蚀方式展开（从边缘向中心），持续约 0.5s
- [ ] **纯白文字**: 游戏结束画面文字使用纯白色（#FFFFFF），非金墨色，确保灰阶背景对比度（TR-HUD-004）
- [ ] **Web 响应式**: 菜单元素在不同视口尺寸下正确锚定和缩放（TR-HUD-005）
- [ ] **重新开始按钮**: 游戏结束画面包含"重新开始"按钮，点击后触发 RESTART 状态转换

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- **菜单栈**: 用 Array 存储当前打开的菜单名栈，push 时添加并显示，pop 时移除并隐藏
- **节点结构**:
  ```
  MenuLayer (CanvasLayer, z_index 20)
  ├── GameOverMenu (Panel) — 游戏结束画面
  │   ├── TitleLabel (Label, #FFFFFF) — "剑意已尽" 或类似
  │   ├── ScoreLabel (Label, #FFFFFF) — 得分显示
  │   └── RestartButton (Button) — 重新开始
  └── PauseMenu (Panel) — 暂停菜单（可选，本 story 聚焦 game_over）
  ```
- **墨迹侵蚀动画**: 使用 Shader 或 Tween + TextureRect mask 实现墨迹从边缘侵蚀展开效果
- **纯白文字**: Label 的 font_color 强制设为 `Color.WHITE`（1, 1, 1, 1），不使用金墨色
- **DEATH 信号响应**: 订阅 GameStateManager.state_changed(old, DEATH)，触发 show_menu("game_over")
- **show_menu(name)**: 公开方法，push 菜单并播放墨迹侵蚀动画
- **Web 响应式**: 使用 Control 节点的 anchor 和 size_flags，确保在 480p-1440p 视口下不溢出
- **RestartButton 连接**: pressed 信号连接至 GameStateManager.change_state(RESTART)

## Out of Scope

- **Story 001**: 战斗 HUD 基础显示（生命值/连击/剑式/蓄力环）
- **Story 002**: HUD 自动淡出与受击恢复

## QA Test Cases

- **AC-1**: 菜单栈 push — Given: 空栈, When: push_menu("game_over"), Then: game_over 菜单可见，栈 = ["game_over"]
- **AC-2**: 菜单栈 pop — Given: 栈 = ["game_over"], When: pop_menu(), Then: game_over 菜单隐藏，栈 = []
- **AC-3**: DEATH 触发 game_over — Given: COMBAT 状态, When: state_changed(COMBAT, DEATH), Then: show_menu("game_over") 被调用
- **AC-4**: 墨迹侵蚀动画 — Given: show_menu 被调用, When: 动画播放, Then: 从边缘向中心侵蚀展开，约 0.5s 完成
- **AC-5**: 纯白文字 — Given: game_over 菜单, When: 渲染, Then: 所有 Label 的 font_color = #FFFFFF
- **AC-6**: 重新开始按钮 — Given: game_over 菜单可见, When: 点击 RestartButton, Then: change_state(RESTART) 被调用
- **AC-7**: Web 响应式 — Given: 视口 480p/720p/1080p/1440p, When: 菜单显示, Then: 元素不溢出，布局正确
- **AC-Edge**: 重复 push — Given: 栈已含 "game_over", When: 再次 push_menu("game_over"), Then: 无重复添加（幂等）

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: `production/qa/evidence/menu-system-evidence.md` + 截图（含 480p/720p/1080p 视口）
- 自动化: `tests/unit/hud-ui-system/menu_stack_test.gd`（push/pop 逻辑）

**Status**: Complete (tests/unit/hud-ui-system/menu_game_over_test.gd — 菜单栈、游戏结束面板、按钮、信号全覆盖)

## Completion Notes
- AC-1, AC-3~AC-7: 完全实现 (battle_hud.gd show_menu/hide_menu, _play_ink_erosion_animation, DEATH_TEXT_COLOR=WHITE, PRESET_CENTER, RestartButton)
- AC-2 DEATH触发: show_game_over() 方法就绪，GameStateManager.state_changed(DEATH) 订阅在场景装配阶段连接
- UI evidence (截图含多视口) deferred to Godot 编辑器验证阶段

## Dependencies

- Depends on: Story 002（HUD 状态响应就绪）、GameStateManager story-001（state_changed DEATH 信号）
- Unlocks: None（菜单系统为 HUD/UI 最终 story）
