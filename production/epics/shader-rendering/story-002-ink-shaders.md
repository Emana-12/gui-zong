# Story 002: 水墨着色器库（角色 + 环境）

> **Epic**: 着色器/渲染 (Shader/Rendering)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/shader-rendering.md`
**Requirement**: `TR-SHADER-001`, `TR-SHADER-002`, `TR-SHADER-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: 渲染管线与着色器架构
**ADR Decision Summary**: 使用 .gdshader 手写着色器，色调阶梯（stepped lighting）代替连续 PBR 光照，产生水墨画的"面分明"效果。

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH
**Engine Notes**: shader 纹理类型变化（4.4）— 所有 uniform 使用 `Texture` 基类型。D3D12 默认（4.6）不影响 Web 导出。WebGL 2.0 下需验证 toon ramp 表现。

**Control Manifest Rules (Foundation layer)**:
- Required: 所有着色器使用 .gdshader；材质共享池 ≤15 实例
- Forbidden: VisualShader；PBR + 后处理水墨滤镜
- Guardrail: draw call ≤50；场景三角面 <10K

---

## Acceptance Criteria

*From GDD `design/gdd/shader-rendering.md`, scoped to this story:*

- [ ] **AC-1**: GIVEN 一个低多边形角色模型，WHEN 应用 `shd_ink_character.gdshader`，THEN 角色呈现色调阶梯明暗面（非连续渐变）
- [ ] **AC-2**: GIVEN 一个环境网格，WHEN 应用 `shd_ink_environment.gdshader`，THEN 环境呈现斧劈皴般的锐角明暗

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

### 水墨角色着色器 (`shd_ink_character.gdshader`)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `base_color` | vec3 | 墨黑 (#1A1A2E) | 角色基础色 |
| `highlight_color` | vec3 | 金墨 (#D4A843) | 高光/剑气色 |
| `highlight_intensity` | float | 0.0–1.0 | 高光强度（学徒=0，剑圣=1） |
| `ink_edge_softness` | float | 0.1–0.5 | 墨色边缘柔化 |
| `rim_light_power` | float | 2.0–5.0 | 轮廓光强度 |

- 使用 toon ramp（色调阶梯）实现水墨风格明暗
- 角色轮廓通过 `rim_light` 勾勒，模拟水墨画的"线描"效果
- 不使用 PBR 光照模型

### 水墨环境着色器 (`shd_ink_environment.gdshader`)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `base_color` | vec3 | 淡墨灰 (#4A4A5E) | 环境基础色 |
| `ink_dark` | vec3 | 墨黑 (#1A1A2E) | 暗部颜色（斧劈皴暗面） |
| `ink_steps` | int | 3–5 | 色调阶梯数 |
| `texture_blend` | float | 0.0–1.0 | 手绘纹理混合度 |

- 使用 stepped lighting 代替连续光照
- 每个面根据法线与光源角度被分配到固定墨色阶梯
- 模拟水墨画的"面分明"效果

### 关键注意事项

- 所有 uniform 声明使用 `Texture` 基类型（Godot 4.4 变更，非 `Texture2D`）
- 着色器必须在 WebGL 2.0 下编译通过（无 compute shader，有限纹理采样）
- 使用 Godot 内置 DirectionalLight3D，不做实时全局光照

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 材质池与着色器管理器（ShaderRenderingSystem.gd）
- Story 003: 流光轨迹着色器
- Story 004: 自动降级系统
- Story 005: 后处理 pass + WebGL 回退

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**手动验证步骤（Visual/Feel 故事）：**

- **AC-1**: 水墨角色着色器视觉验证
  - Setup: 创建一个低多边形角色场景，应用 shd_ink_character.gdshader，添加 DirectionalLight3D
  - Verify: 角色明暗面呈现色调阶梯（非连续渐变），rim light 勾勒角色边缘
  - Pass condition: 明暗分界清晰可见，无 PBR 反光，金色高光可调（highlight_intensity 0→1）

- **AC-2**: 水墨环境着色器视觉验证
  - Setup: 创建环境网格场景（锐角几何体），应用 shd_ink_environment.gdshader，添加 DirectionalLight3D
  - Verify: 环境呈现斧劈皴般的锐角明暗，色调阶梯数可调（ink_steps 2-5）
  - Pass condition: 每个面的墨色阶梯可见，无连续渐变，类似水墨画的"皴法"效果

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/story-002-ink-shaders-evidence.md` + sign-off

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: None（Foundation 层零依赖）
- Unlocks: Story 003（流光轨迹着色器复用相同的着色器架构模式）
