shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon;

/// 水墨角色着色器 (Ink Character Shader)
/// toon ramp + rim light + 动态高光 — 模拟水墨画的线描效果
///
/// 设计参考:
/// - design/gdd/shader-rendering.md §Shader Library — 水墨角色着色器
/// - docs/architecture/adr-0003-rendering-pipeline-architecture.md
///
/// 着色器纹理类型使用 Texture (非 Texture2D — Godot 4.4+ 变更)
/// WebGL 2.0 兼容：无 compute shader，无复杂纹理采样

// --- 参数 ---

/// 角色基础色（墨色）
uniform vec3 base_color : source_color = vec3(0.102, 0.102, 0.18);

/// 高光/剑气色（金色）
uniform vec3 highlight_color : source_color = vec3(0.831, 0.659, 0.263);

/// 高光强度（0 = 学徒/无高光，1 = 剑圣/满高光）
uniform float highlight_intensity : hint_range(0.0, 1.0) = 0.0;

/// 墨色边缘柔化程度
uniform float ink_edge_softness : hint_range(0.1, 0.5) = 0.2;

/// 轮廓光强度（勾勒角色边缘，模拟水墨线描）
uniform float rim_light_power : hint_range(2.0, 5.0) = 3.0;

/// 轮廓光颜色
uniform vec3 rim_color : source_color = vec3(0.831, 0.659, 0.263);

/// 可选手绘纹理（用于叠加墨迹细节）
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

	// 金属度/粗糙度 — 非 PBR 路径，设置为纯漫反射
	METALLIC = 0.0;
	ROUGHNESS = 1.0;

	// 高光混合：在墨色基础上叠加金色高光
	SPECULAR = highlight_intensity * 0.8;
}

void light() {
	// --- 色调阶梯 (toon ramp) ---
	// 公式: ink_step = floor(dot(normal, light_dir) * ink_steps) / ink_steps
	// 这里使用 3 级阶梯：暗面 / 中间调 / 亮面
	float NdotL = dot(NORMAL, LIGHT);
	float toon_step = smoothstep(
		0.0,
		ink_edge_softness,
		NdotL
	);

	// 阶梯化：将连续的 toon_step 映射为离散阶梯
	float stepped = floor(toon_step * 3.0) / 3.0;
	stepped = max(stepped, 0.05); // 暗面不全黑 — 保留墨色层次

	// 漫反射贡献
	vec3 diffuse = ALBEDO * ATTENUATION * stepped;

	// --- 高光叠加 ---
	// 在亮面区域叠加金色高光
	vec3 highlight = highlight_color * highlight_intensity * smoothstep(0.6, 0.8, toon_step);

	DIFFUSE_LIGHT += diffuse + highlight;
}

void light_advanced() {
	// --- 轮廓光 (rim light) ---
	// 模拟水墨画的"线描"效果 — 在物体边缘产生亮线
	float rim = 1.0 - dot(NORMAL, VIEW);
	rim = pow(rim, rim_light_power);
	rim = smoothstep(0.0, ink_edge_softness, rim);

	DIFFUSE_LIGHT += rim_color * rim * ATTENUATION * 0.5;
}
