# Story 001: 场景加载与切换

> **Epic**: 关卡/场景管理 (Level/Scene Manager)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/level-scene-manager.md`
**Requirement**: TR-LSM-001, TR-LSM-003
**ADR Governing Implementation**: ADR-0016: 关卡场景管理器架构
**ADR Decision Summary**: 2 个竞技场区域（山石/水竹）使用 PackedScene 预加载，场景切换使用 fade-to-black 过渡，切换耗时约 2-5ms，使用 queue_free 释放旧场景确保 Web 平台内存回收。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/level-scene-manager.md`, scoped to this story:*

- [ ] 游戏状态为 RESTART 时调用 `reset_scene()`，当前场景销毁并重新实例化
- [ ] 调用 `change_scene("bamboo")` 时，水竹区场景加载完成，`scene_changed` 信号触发
- [ ] 场景切换使用 fade-to-black 过渡动画

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 2 个 PackedScene 在 `_ready()` 中通过 `preload()` 加载
- `reset_scene()`: `queue_free()` 当前场景实例 → 重新 `instantiate()` → `add_child()`
- `change_scene(scene_name)`: fade_out → `queue_free()` 旧场景 → `instantiate()` 新场景 → `add_child()` → fade_in
- Fade 使用 CanvasModulate 节点调节 alpha
- 场景切换信号 `scene_changed(scene_name)` 在 fade_in 完成后发出
- Web 平台：`queue_free()` 后调用 `await get_tree().process_frame` 确保释放完成

## Out of Scope

- 生成点获取与 Web 超时回退（Story 002）
- 实际场景内容和竞技场布局（level-design Epic）
- 波次系统与场景的关联（arena-wave-system Epic）

## QA Test Cases

- **AC-1**: 场景重置
  - Given: 当前场景为山石区，游戏状态变为 RESTART
  - When: 调用 `reset_scene()`
  - Then: 旧场景节点被移除，新实例化的山石区场景被添加到场景树
  - Edge cases: 连续调用两次 reset_scene（不应重复实例化）

- **AC-2**: 场景切换
  - Given: 当前场景为山石区
  - When: 调用 `change_scene("bamboo")`
  - Then: fade_out 执行 → 山石区移除 → 水竹区加载 → fade_in 执行 → `scene_changed("bamboo")` 发出
  - Edge cases: 切换到不存在的场景名（应报错或忽略）、当前场景与目标相同

- **AC-3**: Fade 过渡
  - Given: 场景切换被触发
  - When: 过渡动画播放中
  - Then: CanvasModulate alpha 从 1.0 渐变到 0.0（fade_out），再从 0.0 渐变到 1.0（fade_in）
  - Edge cases: fade_duration = 0 时无动画直接切换

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/level-scene-manager/scene_transition_test.gd`
**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: ADR-0016 Accepted, ADR-0001 (game state) Accepted
- Unlocks: Story 002 (生成点依赖场景加载完成)
