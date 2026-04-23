# Story 002: 轨迹池化与共享材质

> **Epic**: 流光轨迹系统 (Light Trail System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/light-trail-system.md`
**Requirement**: TR-TRAIL-002, TR-TRAIL-003
**ADR Governing Implementation**: ADR-0008: 流光轨迹渲染架构
**ADR Decision Summary**: 轨迹池化预创建 50 个 MeshInstance3D 节点避免运行时分配，所有轨迹共享 3 种材质（游/钻/绕各一种），50 条轨迹仅 1 个 draw call。

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM

## Acceptance Criteria

*From GDD `design/gdd/light-trail-system.md`, scoped to this story:*

- [ ] 活跃轨迹数达到 50（上限）时，再次调用 `create_trail()` 返回拒绝（返回 -1 或 null）
- [ ] 50 条轨迹共享 3 种材质（游/钻/绕各一种），每种剑式的轨迹共享同一材质实例，draw call 总数不超过 50

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 轨迹池在 `_ready()` 中预创建 50 个 MeshInstance3D，全部设置为不可见
- 从池中取出节点时设为可见并重置 ImmediateMesh 内容
- 归还节点时设为不可见并清空 ImmediateMesh
- 共享材质通过 `mesh.surface_set_material()` 设置同一 Material 实例
- 验证 draw call: 可通过 Godot 性能监视器的 "3D Draw Calls" 确认

## Out of Scope

- 轨迹生命周期管理（Story 001）
- 万剑归宗批量轨迹生成（Story 003）
- 轨迹淡出和自动销毁（Story 001）

## QA Test Cases

- **AC-1**: 轨迹池上限拒绝
  - Given: 已有 50 条活跃轨迹
  - When: 调用 `create_trail("you", Vector3.ZERO)`
  - Then: 返回 -1（或 null），不创建新轨迹
  - Edge cases: 第 50 条成功、第 51 条拒绝、释放一条后重新创建成功

- **AC-2**: 共享材质 draw call 验证
  - Given: 50 条活跃轨迹全部使用同一材质
  - When: 渲染帧
  - Then: Godot 性能监视器中 "3D Draw Calls" 不超过 50
  - Edge cases: 仅 1 条轨迹时 draw call 为 1，50 条时 draw call 不超过 50

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/light-trail-system/trail_pooling_test.gd`
**Status**: Complete (tests/unit/light-trail-system/trail_pooling_test.gd)

## Dependencies

- Depends on: Story 001 (轨迹生命周期 API)
- Unlocks: Story 003 (万剑归宗需要池化和上限逻辑)
