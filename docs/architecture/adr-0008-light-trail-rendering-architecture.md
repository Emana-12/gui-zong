# ADR-0008: 流光轨迹渲染架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Rendering |
| **Knowledge Risk** | MEDIUM — ImmediateMesh 在 4.x 中的行为可能与 3.x 不同 |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | 万剑归宗 50 条轨迹的 draw call 数量 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003（渲染管线）, ADR-0006（三式剑招） |
| **Enables** | 命中反馈系统（材质反应视觉） |
| **Blocks** | 命中反馈系统实现 |

## Decision

使用 **MeshInstance3D + ImmediateMesh + 共享材质** 模式代替 LineRenderer（Godot 没有内置 LineRenderer）。

核心架构：
1. **每条轨迹**：MeshInstance3D 节点 + ImmediateMesh 动态生成顶点
2. **轨迹更新**：每帧添加剑尖位置到顶点列表，更新 mesh
3. **淡出机制**：顶点 alpha 值从新到旧递减
4. **万剑归宗批量渲染**：50 条轨迹共享同一材质 → 1 个 draw call
5. **轨迹池化**：预创建 50 个 MeshInstance3D 节点，运行时激活/停用

### 轨迹类型

| 剑式 | 颜色 | 宽度 | 淡出时间 |
|------|------|------|---------|
| 游剑式 | 金墨 (#D4A843) | 0.05m | 0.5s |
| 钻剑式 | 金白 (#F5E6B8) | 0.1m | 0.3s |
| 绕剑式 | 墨黑 (#1A1A2E) | 0.08m | 0.8s |

## Consequences

### Positive
- ImmediateMesh 动态生成——不需要预定义网格
- 共享材质确保 50 条轨迹 = 1 个 draw call
- 池化复用避免频繁节点创建/销毁

### Negative
- ImmediateMesh 在高频更新时可能有性能开销
- 50 条轨迹的顶点数据需要每帧更新

## GDD Requirements Addressed

| GDD System | Requirement |
|------------|-------------|
| light-trail-system.md | Core Rules 1-5 |
| light-trail-system.md | Trail Types by Form |
| shader-rendering.md | 流光轨迹着色器 |
