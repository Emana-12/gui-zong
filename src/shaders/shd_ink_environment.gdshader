shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon;

/// 水墨环境着色器 (Ink Environment Shader)
/// stepped lighting + 手绘纹理 — 模拟斧劈皴般的锐角明暗
///
/// 设计参考:
/// - design/gdd/shader-rendering.md §Shader Library — 水墨环境着色器
/// - docs/architecture/adr-0003-rendering-pipeline-architecture.md
///
/// 着色器纹理类型使用 Texture (非 Texture2D — Godot 4.4+ 变更)
/// WebGL 2.0 兼容：无 compute shader，无复杂纹理采样

// --- 参数 ---

/// 环境基础色（淡墨灰）
uniform vec3 base_color : source_color = vec3(0.29, 0.29, 0.369);

/// 暗部颜色（墨黑 — 斧劈皴的暗面）
uniform vec3 ink_dark : source_color = vec3(0.102, 0.102, 0.18);

/// 色调阶梯数（越少越像水墨画）
uniform int ink_steps : hint_range(2, 5) = 4;

/// 可选手绘纹理
uniform Texture ink_texture : filter_linear_mipmap;

/// 纹理混合度（0 = 纯色，1 = 全纹理）
uniform float texture_blend : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// 基础色：纯色 或 与手绘纹理混合
	vec3 base = base_color;
	if (texture_blend > 0.0) {
		vec3 tex_color = texture(ink_texture, UV).rgb;
		base = mix(base_color, tex_color, texture_blend);
	}
	ALBEDO = base;

	// 非 PBR 路径
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
}

void light() {
	// --- 色调阶梯 (stepped lighting) ---
	// 公式: ink_step = floor(dot(normal, light_dir) * ink_steps) / ink_steps
	// 每个面根据法线与光源角度被分配到固定的墨色阶梯中
	float NdotL = dot(NORMAL, LIGHT);

	// 将 NdotL 从 [-1, 1] 映射到 [0, 1]
	float normalized = NdotL * 0.5 + 0.5;

	// 阶梯化
	float step_index = floor(normalized * float(ink_steps));
	float stepped = step_index / float(ink_steps);
	stepped = max(stepped, 0.02); // 暗部不全黑

	// 在墨黑和基础色之间插值 — 暗面更接近墨黑
	vec3 ink_blend = mix(ink_dark, ALBEDO, stepped);

	// 漫反射贡献
	DIFFUSE_LIGHT += ink_blend * ATTENUATION;
}
