# Asset Deliverable Manifest — 归宗 (Gui Zong)

> **Generated**: 2026-04-22
> **Sprint**: S02-06
> **Engine**: Godot 4.6.2
> **Platform**: Web (HTML5)
> **Scan Scope**: All 18 GDDs in `design/gdd/` + 18 ADRs in `docs/architecture/`

## Summary

Total asset references across all GDDs: **3 shaders, 5 scenes, ≤15 materials, 20-30 SFX, 4 BGM tracks, 5 enemy models, 2 fonts, ≤16 sprite/decal pool nodes**.

**Disk Status**: `assets/` directory does not exist. All assets are planned — none created yet.

---

## 1. Shaders (.gdshader)

| File | System | Purpose | Web Constraint |
|------|--------|---------|---------------|
| `shd_ink_character.gdshader` | Shader/Rendering | 角色调阶明暗、轮廓光、动态高光 | WebGL 2.0 compatible |
| `shd_ink_environment.gdshader` | Shader/Rendering | 环境调阶光照、手绘纹理混合 | WebGL 2.0 compatible |
| `shd_light_trail.gdshader` | Light Trail | 轨迹颜色、透明度、淡出、辉光 | WebGL 2.0 compatible |

**Post-processing**: ≤2 passes (outline + color grading). Web端可关闭.

**Shader Parameters** (ink_character):
- `base_color`: vec3 = `#1A1A2E` (墨黑)
- `highlight_color`: vec3 = `#D4A843` (金墨)
- `highlight_intensity`: float 0.0–1.0
- `ink_edge_softness`: float 0.1–0.5
- `rim_light_power`: float 2.0–5.0

**Shader Parameters** (ink_environment):
- `base_color`: vec3 = `#4A4A5E` (淡墨灰)
- `ink_dark`: vec3 = `#1A1A2E`
- `ink_steps`: int 3–5
- `texture_blend`: float 0.0–1.0

**Shader Parameters** (light_trail):
- `trail_color`: vec3 (金墨/金白/墨黑 per form)
- `trail_alpha`: float 0.6–1.0
- `fade_speed`: float 0.5–2.0
- `glow_intensity`: float 0.0–1.0

---

## 2. Scenes (.tscn)

| File | System | Purpose | Disk Status |
|------|--------|---------|-------------|
| `ArenaMountain.tscn` | Level/Scene Manager | 山石区竞技场（锐角几何、斧劈皴、墨青底） | MISSING |
| `ArenaBamboo.tscn` | Level/Scene Manager | 水竹区竞技场（柔和曲线、披麻皴、宣纸底） | MISSING |
| `HUD.tscn` | HUD/UI | CanvasLayer + Control 节点 HUD 系统 | MISSING |
| `SceneManager.tscn` | Level/Scene Manager | 场景生命周期管理（非 Autoload） | MISSING |
| `HitFeedback.tscn` | Hit Feedback | 材质反应池（非 Autoload） | MISSING |

---

## 3. Materials (.tres / ShaderMaterial)

### Shader Materials (≤15 total budget)

| Material | System | Shader | Count | Usage |
|----------|--------|--------|-------|-------|
| Character material (ink) | Shader/Rendering | `shd_ink_character` | ≤4 | 敌人/玩家角色 |
| Environment material (ink) | Shader/Rendering | `shd_ink_environment` | ≤8 | 竞技场环境 |
| Trail material — 游剑式 | Light Trail | `shd_light_trail` | 1 | 金墨 #D4A843 |
| Trail material — 钻剑式 | Light Trail | `shd_light_trail` | 1 | 金白 #F5E6B8 |
| Trail material — 绕剑式 | Light Trail | `shd_light_trail` | 1 | 墨黑 #1A1A2E |
| `spark_material.tres` | Hit Feedback | Standard | 1 | 金属火花 |
| `crack_material.tres` | Hit Feedback | Decal | 1 | 木杖裂纹 |
| `ink_splash_material.tres` | Hit Feedback | Standard | 1 | 墨点泼溅 |
| `shockwave_material.tres` | Hit Feedback | Shader | 1 | 扇形冲击波 |

---

## 4. Audio

### SFX Library (20–30 files)

| Category | Count | Format | Sample Rate | Source GDD |
|----------|-------|--------|-------------|-----------|
| 三式剑招命中 | 3 | OGG Vorbis | 22050 Hz | audio-system.md |
| 材质反应 | 3 | OGG Vorbis | 22050 Hz | audio-system.md |
| 三式轨迹 | 3 | OGG Vorbis | 22050 Hz | audio-system.md |
| UI 音效 | 2–3 | OGG Vorbis | 22050 Hz | audio-system.md |
| 命中反馈 | 6–8 | OGG Vorbis | 22050 Hz | hit-feedback.md |
| 万剑归宗 | 1 | OGG Vorbis | 22050 Hz | combo-myriad-swords.md |
| 环境音 | 2–3 | OGG Vorbis | 22050 Hz | audio-system.md |
| 玩家音效 | 2–3 | OGG Vorbis | 22050 Hz | player-controller.md |

**Total size budget**: ≤2 MB

### BGM (4 tracks, streaming)

| Track | Style | Source GDD |
|-------|-------|-----------|
| 标题曲 | 肃穆、邀请感（古琴/箫） | audio-system.md |
| 战斗曲 | 紧张、节奏感（鼓+弦） | audio-system.md |
| 氛围曲 | 宁静、蓄势（环境音为主） | audio-system.md |
| 高潮曲 | 爆发、辉煌（全乐器） | audio-system.md |

### Audio Bus Layout

```
Master
├── SFX
│   ├── Sword Hits
│   ├── Sword Trails
│   ├── Material Reactions
│   ├── UI Sounds
│   └── Ambient
└── BGM
```

---

## 5. Sprites / Textures

| Asset | System | Type | Pool Size | Usage |
|-------|--------|------|-----------|-------|
| 金色火花 | Hit Feedback | Sprite3D | ≤5/次 | 游剑式金属碰撞 |
| 木杖裂纹 | Hit Feedback | Decal | 1 | 游剑式木杖碰撞 |
| 墨点泼溅 | Hit Feedback | Sprite3D | ≤10/次 | 绕剑式墨点炸碎 |
| 扇形冲击波 | Hit Feedback | MeshInstance3D | 1 | 钻剑式穿透 |
| 墨滴纹理 | HUD/UI | TextureRect | — | 生命值显示 |
| 蓄力环纹理 | HUD/UI | TextureProgressBar | — | 万剑归宗蓄力 |
| 剑式图标 ×3 | HUD/UI | TextureRect | 3 | 三式指示器 |

**Pool budget**: ≤16 Sprite3D/Decal nodes total

---

## 6. Meshes / Models

### Enemy Models (5 types)

| Type | Silhouette | Source GDD |
|------|-----------|-----------|
| 松韧型（松） | 竖长轮廓 | enemy-system.md |
| 重甲型（石） | 宽厚轮廓 | enemy-system.md |
| 流动型（水） | 曲线轮廓 | enemy-system.md |
| 远程型（云） | 轻盈轮廓 | enemy-system.md |
| 敏捷型（竹） | 尖锐轮廓 | enemy-system.md |

### Environment Meshes

| Asset | System | Source |
|-------|--------|--------|
| 山石区环境 | Level/Scene Manager | level-scene-manager.md |
| 水竹区环境 | Level/Scene Manager | level-scene-manager.md |
| 扇形冲击波网格 | Hit Feedback | adr-0013 |
| 钻剑式光锥 | Three Forms Combat | three-forms-combat.md |

**Note**: Light trail mesh is runtime-generated via ImmediateMesh (MeshInstance3D).

---

## 7. Fonts

| Font | System | Style | Source |
|------|--------|-------|--------|
| 金墨书法字体 | HUD/UI | 标题/连击/菜单 | hud-ui-system.md |
| 死亡画面字体 | HUD/UI | 纯白（对比度） | hud-ui-system.md |

**Constraint**: Web platform — fonts must be bundled with HTML5 export.

---

## 8. Performance Budgets

| Metric | Budget | Source |
|--------|--------|--------|
| Draw calls/frame | <50 | technical-preferences.md |
| Scene triangles | <10K | technical-preferences.md |
| Active enemies | <10 | arena-wave-system.md |
| Active particles | <50 | technical-preferences.md |
| Post-processing passes | <2 | technical-preferences.md |
| Material instances | ≤15 | shader-rendering.md |
| Sprite3D/Decal pool | ≤16 | adr-0013 |
| Light trails | ≤50 | light-trail-system.md |
| ZIP package (gzipped) | <50MB | technical-preferences.md |
| Audio library | <2MB | audio-system.md |
| Scene load (Web) | <5s | adr-0016 |

---

## 9. Art Bible Color Reference

| Swatch | Hex | Name | Usage |
|--------|-----|------|-------|
| ■ | `#1A1A2E` | 墨黑 | 角色/环境暗部 |
| ■ | `#D4A843` | 金墨 | 剑气/流光/连击数字 |
| ■ | `#4A4A5E` | 淡墨灰 | 环境基础色 |
| ■ | `#F5E6B8` | 金白 | 钻剑式轨迹 |
| ■ | `#FFFFFF` | 纯白 | 死亡画面文字 |
