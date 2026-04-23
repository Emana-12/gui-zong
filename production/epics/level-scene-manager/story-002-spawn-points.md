# Story 002: 生成点与 Web 回退

> **Epic**: 关卡/场景管理 (Level/Scene Manager)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/level-scene-manager.md`
**Requirement**: TR-LSM-002, TR-LSM-004
**ADR Governing Implementation**: ADR-0016: 关卡场景管理器架构
**ADR Decision Summary**: 使用 Marker3D 节点标记生成点，`get_spawn_points()` 返回场景中所有 Marker3D 的位置，Web 端加载超时（>5秒）时回退到默认场景。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/level-scene-manager.md`, scoped to this story:*

- [ ] 调用 `get_spawn_points()` 时，若场景中有 5 个 Marker3D 生成点，返回 5 个 Vector3 位置
- [ ] 场景加载超时（>5 秒）时，Web 端回退到默认场景

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- `get_spawn_points()` 遍历当前场景树，收集所有 Marker3D 节点的 `global_position`
- 返回 `PackedVector3Array` 类型，便于直接传给波次系统
- 超时检测：场景加载开始时启动 Timer（5 秒），加载完成时停止 Timer
- 超时回调：释放正在加载的场景，回退到默认场景（山石区），发出警告日志
- Web 平台特别注意：HTML5 加载可能较慢，5 秒超时是兜底机制

## Out of Scope

- 场景加载与切换逻辑（Story 001）
- 使用生成点的波次系统（arena-wave-system Epic）
- 实际 Marker3D 节点的放置（level-design Epic）

## QA Test Cases

- **AC-1**: 生成点获取
  - Given: 场景中有 5 个 Marker3D 节点
  - When: 调用 `get_spawn_points()`
  - Then: 返回包含 5 个 Vector3 的数组，值与各 Marker3D 的 global_position 一致
  - Edge cases: 场景中无 Marker3D 时返回空数组、Marker3D 有旋转不影响位置

- **AC-2**: Web 超时回退
  - Given: 场景加载开始，Timer 设为 5 秒
  - When: 5 秒内未完成加载
  - Then: Timer 超时回调触发，当前加载被取消，默认场景被加载
  - Edge cases: 4.9 秒完成加载（不触发超时）、5.1 秒完成（触发超时）

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/level-scene-manager/spawn_points_test.gd`
**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: Story 001 (场景加载完成)
- Unlocks: arena-wave-system 的敌人生成位置获取
