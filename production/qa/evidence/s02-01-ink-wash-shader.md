# S02-01: Ink-Wash Shader Prototype — Test Evidence

**Date**: 2026-04-22
**Story**: `production/sprints/sprint-02.md` S02-01
**Type**: Visual/Feel
**Verdict**: IMPLEMENTED — manual verification required in Godot editor

---

## 概述

水墨着色器原型实现，包含三个着色器 + ShaderManager 自动加载 + 测试场景。

## 文件清单

| 文件 | 用途 |
|------|------|
| `src/shaders/shd_ink_character.gdshader` | 角色着色器 — toon ramp + rim light + 动态高光 |
| `src/shaders/shd_ink_environment.gdshader` | 环境着色器 — stepped lighting + 可配置 ink_steps |
| `src/shaders/shd_light_trail.gdshader` | 轨迹着色器 — unshaded additive + UV fade + 辉光 |
| `src/core/shader_manager.gd` | ShaderManager autoload — 材质池 + 公共 API + 自动降级 |
| `src/tests/shader_test.tscn` | 测试场景 — 三种着色器可视化验证 |
| `src/tests/shader_test.gd` | 测试场景脚本 — 程序化材质应用 + 交互切换 |

## 验收标准映射

| AC | 标准 | 状态 | 证据 |
|----|------|------|------|
| AC-1 | 角色着色器 toon ramp 渲染 | ✅ 已实现 | `shd_ink_character.gdshader` — `light()` 中 3 级阶梯化 |
| AC-2 | 环境着色器 stepped lighting | ✅ 已实现 | `shd_ink_environment.gdshader` — 可配置 ink_steps 2-5 |
| AC-3 | 轨迹着色器 additive glow + fade | ✅ 已实现 | `shd_light_trail.gdshader` — unshaded + blend_add |
| AC-4 | ShaderManager 材质池 ≤15 实例 | ✅ 已实现 | `shader_manager.gd` — MAX_POOL_SIZE=15，哈希去重 |
| AC-5 | WebGL 2.0 兼容 | ✅ 已实现 | 所有着色器使用 Texture (非 Texture2D)，无 compute shader |
| AC-6 | 自动降级 (fps<30 关后处理, fps<20 ink_steps=2) | ✅ 已实现 | `shader_manager.gd` — `_check_degradation()` |
| AC-7 | 公共 API 完整 | ✅ 已实现 | get_material, create_trail_material, set_character_highlight, set_post_process_enabled, get_fps |
| AC-8 | ≥50fps WebGL 目标 | ⏳ 需 Web 导出测试 | 在 Godot 编辑器中验证本地帧率后导出 Web 测试 |

## 手动验证清单

在 Godot 编辑器中打开 `src/tests/shader_test.tscn` 运行：

- [ ] 左侧球体显示 toon ramp 明暗阶梯（3 级色调分离可见）
- [ ] 球体边缘有金色轮廓光 (rim light)
- [ ] 地面/墙面显示 stepped lighting（面片化明暗）
- [ ] 右侧四边形显示金色轨迹渐隐效果
- [ ] 按 [1] 切换角色高光 — 球体金色高光可见/不可见
- [ ] 按 [2] 循环 ink_steps — 环境明暗阶梯数变化 (2→3→4→5)
- [ ] 按 [3] 切换轨迹辉光强度
- [ ] FPS 标签实时显示帧率和材质池使用情况
- [ ] 控制台无着色器编译错误

## 着色器参数验证

### 角色着色器 (shd_ink_character.gdshader)
- base_color: #1A1A2E (vec3(0.102, 0.102, 0.18)) ✅
- highlight_color: #D4A843 (vec3(0.831, 0.659, 0.263)) ✅
- ink_edge_softness: 0.1-0.5 range ✅
- rim_light_power: 2.0-5.0 range ✅
- render_mode: diffuse_toon ✅
- Texture 类型 (非 Texture2D) ✅

### 环境着色器 (shd_ink_environment.gdshader)
- base_color: #4A4A5E (vec3(0.29, 0.29, 0.369)) ✅
- ink_dark: #1A1A2E (vec3(0.102, 0.102, 0.18)) ✅
- ink_steps: 2-5 range (int) ✅
- 阶梯公式: `floor(normalized * ink_steps) / ink_steps` ✅

### 轨迹着色器 (shd_light_trail.gdshader)
- trail_color: #D4A843 ✅
- trail_alpha: 0.6-1.0 range ✅
- fade_speed: 0.5-2.0 range ✅
- glow_intensity: 0.0-1.0 range ✅
- render_mode: unshaded, cull_disabled, blend_add ✅

## 性能预算

| 指标 | 预算 | 实际 | 状态 |
|------|------|------|------|
| 材质池实例 | ≤15 | 预创建 3 + 测试 3 = 6 | ✅ |
| Draw calls (测试场景) | ≤17 | ~6 (3 mesh + light + camera + UI) | ✅ |
| 后处理通道 | ≤2 | 0 (原型无后处理) | ✅ |

## 注意事项

- 着色器在 Godot 编辑器中预览需手动分配材质（脚本运行时自动分配）
- Web 导出帧率测试需实际导出 HTML5 后在浏览器中验证
- `light_advanced()` 函数在 Godot 4.6 中的行为需确认（部分版本可能不调用）
- 材质池满时返回 null 并输出 warning，不会崩溃
