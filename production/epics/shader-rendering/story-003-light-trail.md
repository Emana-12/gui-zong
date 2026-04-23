# Story 003: 流光轨迹着色器与三式连接

> **Epic**: 着色器/渲染 (Shader/Rendering)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/shader-rendering.md`
**Requirement**: `TR-SHADER-003`, `TR-SHADER-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: 渲染管线与着色器架构
**ADR Decision Summary**: 流光轨迹着色器用于 LineRenderer 材质，颜色和透明度由三式剑招系统动态设置。50 条轨迹共享同一材质 → 1 draw call，3 种剑式共消耗材质池 3 个槽位。

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH
**Engine Notes**: 纹理类型变化（4.4）— uniform 使用 `Texture` 基类型。需与 ADR-0008（流光轨迹渲染）确认 LineRenderer 接口。

**Control Manifest Rules (Foundation layer)**:
- Required: 所有着色器使用 .gdshader；材质共享池 ≤15 实例
- Forbidden: VisualShader；GDExtension（Web 端不支持）
- Guardrail: draw call ≤50；轨迹材质 ≤3 种（墨色/金色/金白）

---

## Acceptance Criteria

*From GDD `design/gdd/shader-rendering.md`, scoped to this story:*

- [ ] **AC-5**: GIVEN 场景有 8 个环境材质 + 4 个角色材质 + 3 个轨迹材质 + 2 个后处理 pass，WHEN 统计 draw call，THEN ≤ 17

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

### 流光轨迹着色器 (`shd_light_trail.gdshader`)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `trail_color` | vec3 | 金墨 (#D4A843) | 轨迹颜色 |
| `trail_alpha` | float | 0.6–1.0 | 轨迹透明度 |
| `fade_speed` | float | 0.5–2.0 | 轨迹淡出速度 |
| `glow_intensity` | float | 0.0–1.0 | 辉光强度（万剑归宗时增大） |

### 三式连接

- 绕剑式 = 墨色轨迹（trail_color = #1A1A2E）
- 游剑式 = 金色轨迹（trail_color = #D4A843）
- 钻剑式 = 金白轨迹（trail_color = #F5E6B8）
- 颜色通过 `create_trail_material(color, alpha)` 动态设置
- 50 条轨迹共享同一材质 → 1 draw call（按剑式类型共 3 种材质）

### Draw call 预算验证

```gdscript
# 预算公式：
# total_draw_calls = scene_materials + character_materials + trail_materials + post_process_passes
# = 8 + 4 + 3 + 2 = 17 ≤ 50 ✓
```

### 材质池约束

- 轨迹材质必须通过 ADR-0003 的 `create_trail_material()` 创建
- 不得绕过材质池直接实例化 ShaderMaterial
- 3 种轨迹材质消耗材质池 15 个槽位中的 3 个

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 材质池与着色器管理器（提供 create_trail_material 接口）
- Story 002: 水墨角色/环境着色器
- Story 004: 自动降级系统
- Story 005: 后处理 pass

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**自动化测试规格（Integration 故事）：**

- **AC-5**: Draw call 预算验证
  - Given: 场景中有 8 个环境材质、4 个角色材质、3 个轨迹材质、2 个后处理 pass
  - When: 统计所有材质的 draw call 数
  - Then: 总数 ≤ 17
  - Edge cases: 仅轨迹材质（3 个）→ 3 draw calls; 全部材质 → 17; 材质池去重验证（同参数不增加 draw call）

**手动验证步骤：**

- 流光轨迹视觉验证
  - Setup: 创建 LineRenderer 场景，应用 shd_light_trail.gdshader，分别测试墨色/金色/金白三种轨迹
  - Verify: 轨迹颜色正确，透明度和淡出效果可见，辉光参数可调
  - Pass condition: 三种颜色清晰可辨，轨迹随时间淡出

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/shader-rendering/trail_drawcall_test.gd` OR playtest doc

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: Story 001（需要 create_trail_material 接口）
- Unlocks: 流光轨迹系统（ADR-0008）使用此着色器
