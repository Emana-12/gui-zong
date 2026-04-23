shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

/// 流光轨迹着色器 (Light Trail Shader)
/// 颜色 + 透明度 + 淡出 + 辉光 — 用于剑气轨迹材质
///
/// 设计参考:
/// - design/gdd/shader-rendering.md §Shader Library — 流光轨迹着色器
/// - docs/architecture/adr-0003-rendering-pipeline-architecture.md
/// - docs/architecture/adr-0008-light-trail-rendering-architecture.md
///
/// 使用 unshaded 模式 — 轨迹不受场景光照影响，自发光
/// WebGL 2.0 兼容

// --- 参数 ---

/// 轨迹颜色（金色 #D4A843）
uniform vec3 trail_color : source_color = vec3(0.831, 0.659, 0.263);

/// 轨迹透明度（0.6 ~ 1.0）
uniform float trail_alpha : hint_range(0.0, 1.0) = 0.8;

/// 轨迹淡出速度（越大越快消失）
uniform float fade_speed : hint_range(0.5, 2.0) = 1.0;

/// 辉光强度（万剑归宗时增大）
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.3;

/// 全局时间（由 ShaderManager 每帧更新）
uniform float time : hint_range(0.0, 1000.0) = 0.0;

/// 是否使用顶点颜色（0.0 = 使用 uniform 颜色, 1.0 = 使用顶点颜色 alpha）
uniform float use_vertex_color : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// 基础颜色 + 辉光叠加
	vec3 color = trail_color;
	color += trail_color * glow_intensity;

	// 透明度衰减 — 基于 UV 的 x 轴（轨迹从前到后淡出）
	float alpha = trail_alpha * (1.0 - UV.x * fade_speed);

	// 顶点颜色 alpha 叠加（用于共享材质下的独立淡出）
	if (use_vertex_color > 0.5) {
		alpha *= COLOR.a;
	}

	alpha = clamp(alpha, 0.0, 1.0);

	ALBEDO = color;
	ALPHA = alpha;
}
