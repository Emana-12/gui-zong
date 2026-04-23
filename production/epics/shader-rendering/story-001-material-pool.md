# Story 001: 材质池与着色器管理器

> **Epic**: 着色器/渲染 (Shader/Rendering)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/shader-rendering.md`
**Requirement**: `TR-SHADER-005`, `TR-SHADER-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: 渲染管线与着色器架构
**ADR Decision Summary**: 使用 .gdshader + Forward+ 渲染器，通过命名材质池（Dictionary hash）共享材质实例，限制 ≤15 个材质。

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH
**Engine Notes**: D3D12 默认（4.6），glow 重做，shader 纹理类型变化（4.4）。所有 uniform 声明使用 `Texture` 基类型（非 `Texture2D`，4.4 变更）。

**Control Manifest Rules (Foundation layer)**:
- Required: 所有着色器使用 .gdshader；材质共享池 ≤15 实例
- Forbidden: VisualShader；PBR + 后处理水墨滤镜
- Guardrail: draw call ≤50；后处理 ≤2 pass；材质实例 ≤15

---

## Acceptance Criteria

*From GDD `design/gdd/shader-rendering.md`, scoped to this story:*

- [ ] **AC-3**: GIVEN `ink_steps=4`, WHEN 面法线与光方向点积=0.7, THEN 色调阶梯公式输出为 0.5（第 3 阶梯）
- [ ] **AC-4**: GIVEN 调用 `create_trail_material(#D4A843, 0.8)`, WHEN 返回材质, THEN 材质为金墨色、80% 透明度
- [ ] **AC-8**: GIVEN 调用 `get_material("nonexistent")`, WHEN 材质不存在, THEN 返回 null

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

### 材质池实现

```gdscript
# ShaderRenderingSystem.gd (Foundation)
var _material_pool: Dictionary = {}  # {hash: Material}

func get_material(name: StringName) -> Material:
    return _material_pool.get(name)

func create_trail_material(color: Color, alpha: float) -> Material:
    var hash = "%s_%s" % [color.to_html(), alpha]
    if hash in _material_pool:
        return _material_pool[hash]
    var mat = ShaderMaterial.new()
    mat.shader = preload("res://shaders/shd_light_trail.gdshader")
    mat.set_shader_parameter("trail_color", color)
    mat.set_shader_parameter("trail_alpha", alpha)
    _material_pool[hash] = mat
    return mat
```

### 色调阶梯公式（着色器端）

```glsl
// 在 shd_ink_environment.gdshader 中
float ink_step = floor(dot(normal, light_dir) * ink_steps) / ink_steps;
```

### 管理器职责

- 维护 `_material_pool` Dictionary，按 `(shader, params)` 哈希去重
- 提供 `get_material(name)` 查询接口 — 材质不存在返回 null
- 提供 `create_trail_material(color, alpha)` 创建/获取接口 — 哈希冲突使用完整参数序列化
- 提供 `set_character_highlight(intensity)` 设置所有角色着色器高光参数
- 提供 `set_post_process_enabled(pass_name, enabled)` 后处理 pass 管理
- 提供 `get_fps()` 帧率查询

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 水墨角色着色器 + 水墨环境着色器（shader 文件本身）
- Story 003: 流光轨迹着色器 + 三式连接
- Story 004: 自动降级系统
- Story 005: 后处理 pass + WebGL 回退

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**自动化测试规格（Logic 故事）：**

- **AC-3**: 色调阶梯公式验证
  - Given: ink_steps=4, normal=(0,1,0), light_dir=(0.707, 0.707, 0)
  - When: 计算 floor(dot(normal, light_dir) * ink_steps) / ink_steps
  - Then: 结果为 0.5
  - Edge cases: dot=0.0 → 0.0; dot=1.0 → 0.75; ink_steps=2 时边界值

- **AC-4**: create_trail_material 返回正确材质
  - Given: 调用 create_trail_material(Color("#D4A843"), 0.8)
  - When: 检查返回材质的 shader_parameter
  - Then: trail_color ≈ Color("#D4A843"), trail_alpha ≈ 0.8
  - Edge cases: 相同参数调用两次返回同一实例（材质池去重）; alpha=0.0 边界

- **AC-8**: get_material 不存在时返回 null
  - Given: _material_pool 为空
  - When: 调用 get_material("nonexistent")
  - Then: 返回 null
  - Edge cases: 空字符串; 已存在的名称返回正确材质

**预计测试数量**: ~8 个单元测试

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/shader-rendering/material_pool_test.gd` — must exist and pass

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: None（Foundation 层零依赖）
- Unlocks: Story 003（流光轨迹使用 create_trail_material）
