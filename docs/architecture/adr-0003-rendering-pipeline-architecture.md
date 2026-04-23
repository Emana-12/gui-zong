# ADR-0003: 渲染管线与着色器架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Rendering / Shader |
| **Knowledge Risk** | HIGH — D3D12 默认（4.6），glow 重做，shader 纹理类型变化（4.4），shader baker（4.5） |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | D3D12 渲染后端（4.6 默认），glow 重做参数（4.6） |
| **Verification Required** | 1) WebGL 2.0 回退是否自动触发 2) 水墨 toon ramp 在 WebGL 下的表现 3) 后处理 pass 在 Web 端的性能 4) 所有 .gdshader uniform 声明使用 `Texture` 基类型（非 `Texture2D`，4.4 变更） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0008（流光轨迹渲染） |
| **Blocks** | 流光轨迹系统、着色器/渲染系统实现 |
| **Ordering Note** | 应在流光轨迹系统之前 Accepted |

## Context

### Problem Statement
《归宗》需要水墨风格的 3D 渲染——色调阶梯（toon ramp）代替连续光照、手绘质感代替 PBR、极简粒子代替华丽特效。同时必须在 Web 平台（WebGL 2.0）上运行，draw call 预算 < 50，后处理 pass < 2。

### Constraints
- Web 平台：WebGL 2.0 渲染后端，无 GDExtension，无 compute shader
- 性能预算：draw call < 50, 三角面 < 10K, 帧时间 < 16.6ms
- 色板极简：仅墨色 + 金色两种色相
- 着色器复杂度必须低——WebGL 2.0 兼容
- Godot 4.6 的 D3D12 默认与 Web 导出无关（Web 始终使用 WebGL）

### Requirements
- 水墨角色着色器（toon ramp + rim light + 动态高光）
- 水墨环境着色器（stepped lighting + 手绘纹理）
- 流光轨迹着色器（LineRenderer 材质）
- 后处理：描边 + 色调调整（≤2 pass）
- 材质管理：场景 ≤ 15 个共享材质

## Decision

使用 **Godot Shader Language (.gdshader) + Forward+ 渲染器 + WebGL 2.0 回退** 模式。

核心架构：
1. **渲染器**：Forward+（Desktop），Web 导出时自动使用 WebGL 2.0 后端
2. **着色器库**：3 类核心着色器（角色/环境/轨迹），全部用 `.gdshader` 编写
3. **光照模型**：色调阶梯（stepped lighting）代替连续 PBR——2-5 个明暗阶梯
4. **后处理**：最多 2 个 pass（描边 + 色调调整），Web 端可动态关闭
5. **材质共享**：通过命名材质池减少 draw call——同着色器同参数 = 同材质实例
6. **降级策略**：帧率 < 30fps 时自动关闭后处理，降低 `ink_steps` 到 2

### Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│              ShaderRenderingSystem (Foundation)       │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │ Shader Library                            │       │
│  │                                           │       │
│  │  shd_ink_character.gdshader               │       │
│  │    → toon ramp + rim light + highlight    │       │
│  │                                           │       │
│  │  shd_ink_environment.gdshader             │       │
│  │    → stepped lighting + texture blend     │       │
│  │                                           │       │
│  │  shd_light_trail.gdshader                 │       │
│  │    → color + alpha + fade + glow          │       │
│  └───────────────────────────────────────────┘       │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │ Material Pool (共享材质)                   │       │
│  │  ≤ 15 材质实例                             │       │
│  │  按 (shader, params) 哈希去重              │       │
│  └───────────────────────────────────────────┘       │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │ Post-Processing (≤2 pass)                 │       │
│  │  Pass 1: 描边 (可选, Web 端可关闭)        │       │
│  │  Pass 2: 色调调整 (墨色/金色色温)         │       │
│  └───────────────────────────────────────────┘       │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │ Auto-Degradation                          │       │
│  │  fps < 30 → 关闭后处理                    │       │
│  │  fps < 20 → ink_steps = 2                 │       │
│  └───────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
  ┌─────────────┐         ┌──────────────┐
  │ 角色/环境   │         │ 流光轨迹     │
  │ 应用着色器  │         │ 应用材质     │
  └─────────────┘         └──────────────┘
```

### Key Interfaces

```gdscript
# ShaderRenderingSystem.gd (Foundation)

# 共享材质池
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

func set_character_highlight(intensity: float) -> void:
    # 设置所有角色着色器的高光参数
    pass

func set_post_process_enabled(pass_name: StringName, enabled: bool) -> void:
    pass

func get_fps() -> int:
    return Engine.get_frames_per_second()
```

## Alternatives Considered

### Alternative 1: 使用 VisualShader（节点式着色器）
- **Description**: 用 Godot 的 VisualShader 编辑器代替手写 .gdshader
- **Pros**: 可视化编辑，更直观
- **Cons**: VisualShader 在 WebGL 2.0 下的兼容性不如手写着色器可控；导出时可能生成低效代码
- **Rejection Reason**: 手写着色器对 Web 性能和兼容性有完全控制

### Alternative 2: 使用 PBR 材质 + 后处理水墨滤镜
- **Description**: 场景用标准 PBR 渲染，后处理 pass 叠加水墨滤镜
- **Pros**: 开发简单，不需要自定义着色器
- **Cons**: PBR 渲染在 Web 端性能开销大；后处理水墨滤镜效果不自然（像滤镜而非水墨画）；增加 1 个后处理 pass
- **Rejection Reason**: 违反"极简即美学"支柱——PBR 追求真实感而非画感

### Alternative 3: 全 Unlit 着色器（零光照）
- **Description**: 所有物体使用 unlit 着色器，明暗通过顶点色手绘
- **Pros**: Web 性能最好——无光照计算
- **Cons**: 光照效果静态——无法响应万剑归宗时的光照变化；角色没有动态明暗
- **Rejection Reason**: 万剑归宗时需要动态光照变化（金色占比从 15% 升到 60%+）

## Consequences

### Positive
- 手写着色器对 WebGL 兼容性有完全控制
- 色调阶梯天然产生水墨画的"面分明"效果
- 材质共享池有效减少 draw call
- 自动降级策略确保 Web 端可玩性

### Negative
- 手写着色器比 VisualShader 维护成本高
- WebGL 2.0 限制了着色器功能（无 compute shader，有限纹理采样）
- 色调阶梯在极端角度可能产生 banding（明暗跳跃）

### Risks
- **WebGL 2.0 着色器兼容性**：某些 GLSL 特性在 WebGL 下不可用。→ 缓解：在原型阶段用目标浏览器测试每个着色器。
- **后处理 pass 性能**：描边 pass 在 Web 端可能超过 2ms 帧预算。→ 缓解：默认关闭描边 pass，仅在帧率充足时启用。
- **材质池哈希冲突**：不同参数产生相同哈希。→ 缓解：使用完整的参数序列化作为哈希键。

### Conflict Resolutions

**与 ADR-0008（流光轨迹）— 材质池上限冲突**：ADR-0003 限制共享材质池 ≤ 15 个材质实例。ADR-0008 声明 50 条轨迹共享同一材质 → 1 draw call。已解决：50 条轨迹仅消耗材质池中的 1 个槽位（按剑式类型共 3 种材质：游剑式/钻剑式/绕剑式各 1 个）。材质池剩余 12 个槽位供角色/环境/后处理使用。ADR-0008 必须通过 ADR-0003 的 `create_trail_material()` 创建轨迹材质，不得绕过材质池直接实例化。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| shader-rendering.md | Core Rules 1-6 | .gdshader 着色器库 + Forward+/WebGL 2.0 + 材质共享 + 后处理 ≤2 pass |
| shader-rendering.md | Shader Library | 3 类着色器 + 参数表 |
| shader-rendering.md | Rendering Pipeline | Forward+ / WebGL 2.0 回退 |
| shader-rendering.md | Auto-Degradation | 帧率驱动的自动降级 |
| art-bible.md | Section 3: Shape Language | 锐角几何 + 色调阶梯 |
| art-bible.md | Section 4: Color System | 墨色 + 金色统一色板 |
| art-bible.md | Section 8: Asset Standards | 材质 ≤ 15, 后处理 ≤ 2 pass |

## Performance Implications
- **CPU**: 低——着色器在 GPU 执行，CPU 只做材质参数设置
- **Memory**: 低——共享材质池 ≤ 15 个材质实例，每个着色器编译一次
- **Load Time**: 着色器编译在启动时完成，可能增加 0.5-1 秒启动时间
- **Network**: N/A

## Validation Criteria
- 所有着色器在 Chrome/Firefox/Safari 的 WebGL 2.0 下正常渲染
- draw call 总数 ≤ 50（含场景 + 角色 + 轨迹 + 后处理）
- 帧率 ≥ 60fps（Desktop），≥ 30fps（Web 低端设备）
- 自动降级在帧率 < 30fps 时正确触发

## Related Decisions
- ADR-0001（游戏状态管理）—— 渲染参数随状态变化
- ADR-0008（流光轨迹渲染）—— 使用此 ADR 的材质系统
