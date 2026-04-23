# 着色器/渲染 (Shader/Rendering)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 极简即美学 (Pillar 2)

## Overview

**着色器/渲染系统**是《归宗》视觉身份的技术载体。它提供水墨风格着色器、低多边形渲染管线、和 Web 平台的 WebGL 2.0 兼容渲染。所有视觉效果（流光轨迹、墨点炸碎、万剑归宗爆发）都建立在这个系统之上。

**职责边界：**
- **做**：水墨风格着色器库（角色/环境/特效）、渲染管线配置（WebGL 2.0 回退）、材质管理、后处理 pass 管理（≤2 个）
- **不做**：具体的视觉效果逻辑（由流光轨迹系统、命中反馈系统等负责）、场景内容（由关卡/场景管理负责）

**为什么需要它：** 没有统一的着色器/渲染管理，每个视觉系统都需要自己处理 WebGL 兼容性和性能优化。这个系统确保所有视觉元素在 Web 平台上以一致的水墨风格渲染，同时不超过性能预算。

## Player Fantasy

**玩家看到的是水墨画——不是着色器代码。**

玩家感受到的是：
- 山石在侧光下呈现出斧劈皴般的明暗面——没有贴图噪点，没有 PBR 反光，只有一笔笔干净的墨色
- 金色剑气划过时，轨迹上的材质自然地产生反应——金属冒火花、木杖裂细纹——一切都像水墨画中的飞白和皴法
- 万剑归宗时，全屏的金色流光让整个画面白热化——但每一帧仍然是干净的、可读的

**情感目标：** 画感。玩家应该感觉在一幅活着的水墨画中战斗——每一帧都可以截下来当屏保。

**设计测试：** 如果任何一个渲染效果让玩家想到"这是个游戏特效"而不是"这是一笔墨"，着色器就需要调整。

**支柱对齐：** 直接服务于"极简即美学"(Pillar 2)——着色器是"以留白衬笔触"的技术实现。

## Detailed Design

### Core Rules

1. 所有着色器使用 Godot Shader Language (.gdshader)，不使用 GDExtension/C++（Web 端不支持）
2. 渲染管线使用 Godot 4.6 的 Forward+ 渲染器，Web 导出时自动回退到 WebGL 2.0 后端
3. 着色器库提供 3 类核心着色器：**水墨角色着色器**、**水墨环境着色器**、**流光轨迹着色器**
4. 材质管理：场景总计 ≤ 15 个材质实例，通过共享材质减少 draw call
5. 后处理 pass 限制为 ≤ 2 个：**描边 pass**（可选）+ **色调调整 pass**（墨色/金色色温控制）
6. 光照使用 Godot 的内置 DirectionalLight3D，不做实时全局光照——锐角几何的面光差异天然产生水墨效果

### Shader Library（着色器库）

#### 水墨角色着色器 (`shd_ink_character.gdshader`)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `base_color` | vec3 | 墨黑 (#1A1A2E) | 角色基础色（墨色） |
| `highlight_color` | vec3 | 金墨 (#D4A843) | 高光/剑气色（金色） |
| `highlight_intensity` | float | 0.0–1.0 | 高光强度（学徒=0，剑圣=1） |
| `ink_edge_softness` | float | 0.1–0.5 | 墨色边缘柔化程度 |
| `rim_light_power` | float | 2.0–5.0 | 轮廓光强度（勾勒角色边缘） |

**实现原理：** 使用顶点色 + toon ramp（色调阶梯）实现水墨风格。不使用 PBR 光照模型。角色轮廓通过 `rim_light` 勾勒，模拟水墨画的"线描"效果。

#### 水墨环境着色器 (`shd_ink_environment.gdshader`)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `base_color` | vec3 | 淡墨灰 (#4A4A5E) | 环境基础色 |
| `ink_dark` | vec3 | 墨黑 (#1A1A2E) | 暗部颜色（斧劈皴的暗面） |
| `ink_steps` | int | 3–5 | 色调阶梯数（越少越像水墨画） |
| `texture_blend` | float | 0.0–1.0 | 手绘纹理混合度（0=纯色，1=全纹理） |

**实现原理：** 使用 stepped lighting（色调阶梯）代替连续光照。每个面根据法线与光源的角度被分配到固定的墨色阶梯中，产生类似水墨画的"面分明"效果。

#### 流光轨迹着色器 (`shd_light_trail.gdshader`)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `trail_color` | vec3 | 金墨 (#D4A843) | 轨迹颜色 |
| `trail_alpha` | float | 0.6–1.0 | 轨迹透明度 |
| `fade_speed` | float | 0.5–2.0 | 轨迹淡出速度 |
| `glow_intensity` | float | 0.0–1.0 | 辉光强度（万剑归宗时增大） |

**实现原理：** 用于 LineRenderer 的轨迹材质。颜色和透明度由三式剑招系统动态设置（绕剑式=墨色，游剑式/钻剑式=金色）。

### Rendering Pipeline

| 层 | 配置 | 预算 |
|----|------|------|
| 场景渲染 | Forward+ (Desktop) / WebGL 2.0 (Web) | — |
| 光照 | 1x DirectionalLight3D（模拟水墨画的侧光） | 1 个光源 |
| 后处理 | 描边 + 色调调整（可选，Web 端可关闭） | ≤ 2 pass |
| 输出 | 直接输出到屏幕 | — |

**Web 平台降级策略：**
- 如果帧率 < 60fps：首先关闭后处理描边 pass
- 如果仍然不达标：降低着色器复杂度（减少 `ink_steps`）
- 如果仍然不达标：切换到更简单的 unlit 着色器

### Interactions with Other Systems

**对外发出的接口：**

| 接口 | 类型 | 说明 | 接收系统 |
|------|------|------|---------|
| `get_material(name: String)` | 查询 | 获取共享材质实例 | 流光轨迹, 命中反馈, 关卡/场景 |
| `create_trail_material(color: Color, alpha: float)` | 创建 | 创建流光轨迹材质 | 流光轨迹系统 |
| `set_character_highlight(intensity: float)` | 设置 | 设置角色高光强度（学徒→剑圣动态变化） | 玩家控制器 |
| `set_post_process_enabled(pass: String, enabled: bool)` | 设置 | 启用/禁用后处理 pass | 游戏状态管理（根据性能动态调整） |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 流光轨迹系统 | 请求创建轨迹材质 | 返回材质实例 |
| 游戏状态管理 | `state_changed` | 万剑归宗时增大 `glow_intensity`，死亡时降低亮度 |
| 性能监控 | 帧率低于阈值 | 触发降级策略 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `get_material` | `get_material(name: String)` | `Material` | 获取命名共享材质 |
| `create_trail_material` | `create_trail_material(color: Color, alpha: float)` | `Material` | 创建流光轨迹材质 |
| `set_character_highlight` | `set_character_highlight(intensity: float)` | `void` | 设置角色高光强度（0–1） |
| `set_post_process_enabled` | `set_post_process_enabled(pass_name: String, enabled: bool)` | `void` | 启用/禁用后处理 pass |
| `get_fps` | `get_fps()` | `int` | 获取当前帧率（用于性能监控） |

## Formulas

**色调阶梯计算：**

`ink_step = floor(dot(normal, light_dir) * ink_steps) / ink_steps`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 法线 | `normal` | vec3 | 归一化向量 | 顶点法线 |
| 光方向 | `light_dir` | vec3 | 归一化向量 | 光源方向 |
| 阶梯数 | `ink_steps` | int | 3–5 | 色调阶梯数量 |

**输出：** 0 到 (ink_steps-1) 的整数索引，映射到对应的墨色阶梯。

**示例：** `ink_steps=4`，面法线与光方向点积=0.7 → `floor(0.7 * 4) / 4 = 2 / 4 = 0.5` → 使用第 3 个墨色阶梯（中灰）。

**Draw call 预算估算：**

`total_draw_calls = scene_materials + character_materials + trail_materials + post_process_passes`

| 组成 | 预算 |
|------|------|
| 场景材质 | ≤ 8（共享地形/岩石/竹材质） |
| 角色材质 | ≤ 4（玩家 + 3 个近距敌人共享角色着色器） |
| 轨迹材质 | ≤ 3（墨色/金色/金白各一个共享材质） |
| 后处理 | ≤ 2（描边 + 色调） |
| **总计** | **≤ 17**（远低于 50 的 draw call 预算） |

## Edge Cases

- **如果 WebGL 2.0 不支持某个着色器功能**（如特定的纹理采样）：回退到更简单的 unlit 着色器，输出日志警告。
- **如果 draw call 超过 40（接近 50 预算上限）**：自动合并同材质的网格实例，减少 draw call。
- **如果帧率持续低于 30fps**：自动关闭所有后处理 pass，并降低 `ink_steps` 到最低值 2。
- **如果材质实例数量超过 15**：发出警告，提示需要合并材质。
- **如果后处理 pass 编译失败**（WebGL 兼容性问题）：跳过该 pass，不崩溃。
- **如果 `get_material` 请求的材质名不存在**：返回 null，调用者负责处理。

## Dependencies

### 上游依赖

无。着色器/渲染系统是 Foundation 层零依赖系统。直接使用 Godot 内置的 Shader、Material、RenderingServer。

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 流光轨迹系统 | 硬依赖 | 使用 `create_trail_material` 创建轨迹材质 |
| 关卡/场景管理 | 硬依赖 | 使用 `get_material` 获取环境材质 |
| 命中反馈 | 软依赖 | 使用材质参数变化（如高亮）产生视觉反馈 |
| 游戏状态管理 | 交互依赖 | 监听 `state_changed` 信号调整渲染参数（万剑归宗亮度、死亡灰阶） |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `ink_steps` | 4 | 2–5 | 色调阶梯数。越少越像水墨画，越多越平滑 |
| `rim_light_power` | 3.0 | 2.0–5.0 | 角色轮廓光强度 |
| `post_process_outline` | true | true/false | 后处理描边 pass 开关 |
| `post_process_tone` | true | true/false | 后处理色调调整 pass 开关 |
| `glow_intensity_base` | 0.3 | 0.0–1.0 | 流光轨迹基础辉光强度 |
| `auto_degrade_threshold` | 30 fps | 20–45 fps | 自动降级的帧率阈值 |

## Visual/Audio Requirements

**本系统不直接产生视觉效果——它提供着色器和材质工具，由下游系统创建具体的视觉效果。**

着色器本身的视觉要求已在 Art Bible 中定义：
- 水墨风格：色调阶梯代替连续光照（Section 3: Shape Language）
- 色板：墨色+金色统一色板（Section 4: Color System）
- 材质即画种：碰撞材质产生不同水墨技法反应（Section 1: Visual Identity Statement）

## UI Requirements

**本系统不包含 UI。** 性能降级状态可通过调试 overlay 显示（非 MVP）。

## Acceptance Criteria

- **GIVEN** 一个低多边形角色模型，**WHEN** 应用 `shd_ink_character.gdshader`，**THEN** 角色呈现色调阶梯明暗面（非连续渐变）
- **GIVEN** 一个环境网格，**WHEN** 应用 `shd_ink_environment.gdshader`，**THEN** 环境呈现斧劈皴般的锐角明暗
- **GIVEN** `ink_steps=4`，**WHEN** 面法线与光方向点积=0.7，**THEN** 色调索引为 0.5（第 3 阶梯）
- **GIVEN** 调用 `create_trail_material(#D4A843, 0.8)`，**WHEN** 返回材质，**THEN** 材质为金墨色、80% 透明度
- **GIVEN** 场景有 8 个环境材质 + 4 个角色材质 + 3 个轨迹材质 + 2 个后处理 pass，**WHEN** 统计 draw call，**THEN** ≤ 17
- **GIVEN** Web 平台帧率持续 < 30fps，**WHEN** 自动降级触发，**THEN** 后处理 pass 被关闭，`ink_steps` 降至 2
- **GIVEN** WebGL 2.0 不支持后处理描边 pass，**WHEN** 编译失败，**THEN** 跳过该 pass，游戏不崩溃
- **GIVEN** 调用 `get_material("nonexistent")`，**WHEN** 材质不存在，**THEN** 返回 null

## Open Questions

- 水墨角色着色器的 toon ramp 是否需要在 Godot 4.6 的 WebGL 2.0 下进行特殊适配？需要在原型阶段测试。
- 后处理描边 pass 在 Web 端的性能影响有多大？如果超过 2ms 帧时间，应该默认关闭。
- 角色动态高光（学徒→剑圣）是通过修改着色器参数还是通过切换着色器变体实现？前者更灵活但可能有性能开销。
