# Story 001: 战斗 HUD 显示

> **Epic**: HUD/UI 系统
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/hud-ui-system.md`
**Requirement**: `TR-HUD-001`
**ADR Governing Implementation**: ADR-0015: HUD/UI 架构
**ADR Decision Summary**: CanvasLayer + Control 节点架构，信号订阅模式获取游戏状态数据，水墨风格 UI 元素（墨滴/墨点/墨迹）。

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: Control 节点、CanvasLayer、Label、TextureProgressBar 均在 LLM 训练数据范围内。无 post-cutoff API。

## Acceptance Criteria

- [ ] **COMBAT 状态显示**：游戏状态为 COMBAT 时，生命值墨滴、连击计数器、剑式指示器、蓄力环全部可见
- [ ] **生命值墨滴**：update_health_display(current, max) 更新墨滴大小/数量，当前值 < max 时墨滴变小
- [ ] **连击计数器**：update_combo_display(combo_count) 显示对应数量墨点 + 金色数字
- [ ] **剑式指示器**：显示当前激活剑式（游/钻/绕），高亮当前选中
- [ ] **蓄力环**：ChargeProgress 环形进度条，显示蓄力进度百分比
- [ ] **非 COMBAT 隐藏**：游戏状态非 COMBAT 时，战斗 HUD 不显示

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- **CanvasLayer 架构**: 战斗 HUD 位于独立 CanvasLayer（z_index 10），确保始终在游戏画面之上
- **信号订阅**: HUD 不主动查询，而是订阅 GameStateManager.state_changed、Player.health_changed、ComboSystem.combo_changed 等信号
- **水墨风格元素**:
  - 生命值：墨滴纹理（art/ui/ink_drop.png），数量 = 当前生命值
  - 连击：墨点纹理 + Label（金色描边字体）
  - 剑式：三个图标（游/钻/绕），当前剑式高亮
- **布局**: 使用 Control 节点锚点（anchor）定位，响应 Web 不同视口尺寸
- **update_health_display(current, max)**: 公开方法，参数为当前值和最大值
- **update_combo_display(count)**: 公开方法，参数为连击数
- **节点结构**:
  ```
  HUDLayer (CanvasLayer)
  ├── HealthContainer (HBoxContainer) — 生命值墨滴
  ├── ComboContainer (HBoxContainer) — 连击计数器
  ├── FormIndicator (HBoxContainer) — 剑式指示器
  └── ChargeRing (TextureProgressBar) — 蓄力环
  ```

## Out of Scope

- **Story 002**: HUD 自动淡出、受击恢复全显、万剑归宗淡出
- **Story 003**: 菜单栈系统、游戏结束画面

## QA Test Cases

- **AC-1**: COMBAT 显示 — Given: 游戏状态 COMBAT, When: HUD 初始化完成, Then: 所有 4 个 HUD 元素可见
- **AC-2**: 生命值墨滴 — Given: health=3/max=3, When: 调用 update_health_display(2, 3), Then: 墨滴从 3 个变为 2 个（第 3 个变小/消失）
- **AC-3**: 连击计数 — Given: combo=0, When: 调用 update_combo_display(5), Then: 显示 5 个墨点 + 金色数字 "5"
- **AC-4**: 剑式高亮 — Given: 当前游剑式, When: 切换到钻剑式, Then: 钻剑式图标高亮，游剑式取消高亮
- **AC-5**: 蓄力环 — Given: 蓄力进度 60%, When: update_charge_display(0.6), Then: 环形进度条填充 60%
- **AC-6**: 非 COMBAT 隐藏 — Given: 游戏状态 TITLE, When: HUD 加载, Then: 战斗 HUD 元素不可见
- **AC-Edge**: 生命值为 0 — Given: health=0, When: update_health_display(0, 3), Then: 所有墨滴消失

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: `production/qa/evidence/hud-combat-display-evidence.md` + 截图
- 自动化: `tests/unit/hud-ui-system/hud_display_test.gd`（信号订阅、数据绑定验证）

**Status**: Complete (tests/unit/hud-ui-system/combat_hud_test.gd — 显示方法和常量全覆盖)

## Completion Notes
- AC-1~AC-5: 完全实现 (battle_hud.gd update_health/combo/form/charge_display)
- AC-6 非COMBAT隐藏: show()/hide() 方法就绪，GameStateManager.state_changed 订阅在场景装配阶段连接
- UI evidence (截图) deferred to Godot 编辑器验证阶段

## Dependencies

- Depends on: GameStateManager story-001（state_changed 信号）、PlayerController story-003（health_changed 信号）、ComboSystem（combo_changed 信号）
- Unlocks: Story 002（淡出机制需要 HUD 基础显示就绪）
