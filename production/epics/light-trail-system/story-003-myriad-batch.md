# Story 003: 万剑归宗批量轨迹

> **Epic**: 流光轨迹系统 (Light Trail System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/light-trail-system.md`
**Requirement**: TR-TRAIL-005
**ADR Governing Implementation**: ADR-0008: 流光轨迹渲染架构
**ADR Decision Summary**: 万剑归宗触发时批量创建最多 50 条轨迹，使用轨迹池和共享材质确保单帧内完成且 draw call 不超标。

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM

## Acceptance Criteria

*From GDD `design/gdd/light-trail-system.md`, scoped to this story:*

- [ ] 调用 `create_myriad_trails(count, center)` 时，count 条金色轨迹在同一帧内同时生成（圆形分布）
- [ ] 批量轨迹使用共享材质，draw call 总数不超过 50

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- `create_myriad_trails(count, center)` 从轨迹池中批量取出 count 个节点
- 接收中心位置 Vector3，内部自动生成圆形分布偏移（半径 1.0-4.0m）
- 批量操作在单帧内完成，不使用 yield/await 分帧
- 与连击系统集成：连击系统通过 `myriad_triggered` 信号传递轨迹数量

## Out of Scope

- 轨迹生命周期管理（Story 001）
- 轨迹池化与上限逻辑（Story 002）
- 连击系统触发逻辑（combo-myriad-swords Epic）

## QA Test Cases

- **AC-1**: 批量轨迹生成
  - Given: 轨迹池中有足够可用节点
  - When: 调用 `create_myriad_trails(50, center)`
  - Then: 最多 50 条轨迹在同一帧内创建，圆形分布于 center 周围
  - Edge cases: count=0、count=1、count=50（上限）、活跃轨迹已满时按剩余容量生成

- **AC-2**: 批量 draw call 验证
  - Given: 50 条批量轨迹全部活跃
  - When: 渲染帧
  - Then: "3D Draw Calls" 不超过 50
  - Edge cases: 批量轨迹与其他轨迹共存时总数不超过 50

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/light-trail-system/myriad_batch_test.gd`
**Status**: Complete (light_trail_system.gd create_myriad_trails() — circular distribution, pool-backed, single-frame)

## Dependencies

- Depends on: Story 001 (生命周期 API), Story 002 (池化与上限)
- Unlocks: combo-myriad-swords Epic 的万剑归宗视觉反馈
