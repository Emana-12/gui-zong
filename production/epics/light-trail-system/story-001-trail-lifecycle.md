# Story 001: 轨迹生命周期管理

> **Epic**: 流光轨迹系统 (Light Trail System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/light-trail-system.md`
**Requirement**: TR-TRAIL-001, TR-TRAIL-004
**ADR Governing Implementation**: ADR-0008: 流光轨迹渲染架构
**ADR Decision Summary**: 使用 MeshInstance3D + ImmediateMesh + 共享材质模式渲染轨迹，轨迹池化预创建避免运行时分配，每种剑式（游/钻/绕）有独立的宽度、淡出时间和颜色参数。

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM

## Acceptance Criteria

*From GDD `design/gdd/light-trail-system.md`, scoped to this story:*

- [ ] 游剑式激活时调用 `create_trail("you", sword_tip_pos)`，金色细线轨迹从剑尖位置开始生成
- [ ] 轨迹更新中每帧调用 `update_trail(id, new_pos)`，轨迹点列表追加新位置
- [ ] 剑式结束时调用 `finish_trail(id)`，轨迹冻结并在 `fade_time` 内淡出
- [ ] 所有轨迹点完全透明后，轨迹节点自动销毁（`queue_free`）

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 使用 `MeshInstance3D` + `ImmediateMesh` 渲染轨迹（Godot 无内置 LineRenderer）
- 每种剑式有独立的轨迹参数：宽度（width）、淡出时间（fade_time）、颜色（color）
- 轨迹淡出通过 Shader 中的 alpha 渐变实现，而非 GDScript 逐帧修改
- 轨迹销毁使用 `queue_free()` 确保 Web 平台内存及时释放

## Out of Scope

- 轨迹池化与共享材质（Story 002）
- 万剑归宗批量轨迹生成（Story 003）
- 轨迹数量上限拒绝逻辑（Story 002）

## QA Test Cases

- **AC-1**: 游剑式激活生成轨迹
  - Given: 剑尖位置为 (1.0, 2.0, 3.0)
  - When: 调用 `create_trail("you", Vector3(1.0, 2.0, 3.0))`
  - Then: 返回有效 trail_id，对应 MeshInstance3D 节点被添加到场景树，包含初始点 (1.0, 2.0, 3.0)
  - Edge cases: 传入零向量位置、极端坐标值

- **AC-2**: 轨迹更新追加点
  - Given: 已有 trail_id 对应活跃轨迹
  - When: 连续调用 `update_trail(id, pos)` 3 次
  - Then: 轨迹点列表长度从 1 增加到 4，ImmediateMesh 重新绘制
  - Edge cases: 相邻两点距离极近（<0.01）、距离极远（>10m）

- **AC-3**: 轨迹冻结并淡出
  - Given: 活跃轨迹有 N 个点
  - When: 调用 `finish_trail(id)`
  - Then: 轨迹停止接收新点，alpha 值从 1.0 开始在 fade_time 内递减到 0.0
  - Edge cases: fade_time 为 0 时立即销毁

- **AC-4**: 轨迹自动销毁
  - Given: 已完成淡出的轨迹
  - When: alpha 达到 0.0
  - Then: MeshInstance3D 节点从场景树移除，trail_id 不再有效
  - Edge cases: 多条轨迹几乎同时完成淡出

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: 截图 + `tests/unit/light-trail-system/trail_lifecycle_test.gd`
**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: ADR-0008 Accepted, ADR-0003 (渲染管线) Accepted
- Unlocks: Story 003 (万剑归宗批量轨迹依赖生命周期 API)
