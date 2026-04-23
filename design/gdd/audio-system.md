# 音频系统 (Audio System)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 精确即力量 (Pillar 1)

## Overview

**音频系统**是《归宗》所有声音的入口——精确命中音效、三式剑招音色、环境氛围音、BGM 管理。它通过 Godot 的 AudioServer 和 Web Audio API 后端提供音频播放服务。

**职责边界：**
- **做**：音频资源管理（加载/缓存）、音效播放（一次性/循环）、BGM 管理（播放/切换/淡入淡出）、音量控制（主音量/SFX/BGM 分轨）
- **不做**：具体的音效设计（由声音设计师定义）、音频触发逻辑（由下游系统决定何时播放什么音效）

**为什么需要它：** 没有统一的音频管理，每个系统都需要自己处理音频加载和播放——这会导致内存浪费（同一音效多次加载）、音量不一致、和 Web 平台的 AudioContext 初始化问题分散在各处。

## Player Fantasy

**玩家听到的不是音效文件——是剑划过空气的声音。**

玩家感受到的是：
- 游剑式命中金属时"叮"的一声——清脆、精准、即时
- 绕剑式护身时墨色流光"嗖嗖"环绕——持续的低频嗡鸣
- 钻剑式穿透防御时"砰"的闷响——力量感
- 万剑归宗时万道流光汇聚的渐强音——从低沉到爆发

**情感目标：** 打击感。每一次命中都应该"听起来就像打中了"——声音是精确打击的听觉确认。

**设计测试：** 如果玩家关闭声音后感到"手感变差了"——音效就做到了它的工作。

**支柱对齐：** 服务于"精确即力量"(Pillar 1)——精确命中需要精确的音效反馈。三式各有音色，声音是区分三式的听觉维度。

## Detailed Design

### Core Rules

1. 音频系统管理 3 条音频总线：**Master**（主音量）、**SFX**（音效）、**BGM**（背景音乐），每条独立控制音量
2. 音效播放分为 3 类：**一次性音效**（命中、UI 点击）、**循环音效**（绕剑式嗡鸣、环境音）、**BGM**（战斗曲、氛围曲）
3. 所有音频资源使用 OGG Vorbis 格式，22050 Hz 采样率——Web 友好，体积小
4. 音频资源在游戏启动时预加载到内存（音效库 < 30 个文件），BGM 使用流式加载
5. 音效播放支持 pitch 变化（±半音）和音量变化——用于材质反应的细微差异（金属 vs 木材 vs 墨点）
6. BGM 管理支持 crossfade（淡入淡出切换），默认 crossfade 时长 1 秒
7. Web 平台的 AudioContext 初始化需要用户手势（点击/按键）——首次交互时自动初始化

### Sound Categories（音效分类）

#### 三式剑招音色

| 剑式 | 命中音效 | 轨迹音效 | 音色特征 |
|------|---------|---------|---------|
| 游剑式 | "叮"——清脆金属碰撞 | "嗖"——细线划过空气 | 高频为主，尖锐 |
| 钻剑式 | "砰"——闷响穿透 | "嗡"——粒子凝聚的低频 | 低频为主，厚重 |
| 绕剑式 | "啪"——墨点炸碎 | "呼"——流光环绕 | 中频，柔和 |

#### 材质反应音效

| 材质 | 音效 | 音色特征 |
|------|------|---------|
| 金属 | 金属碰撞"叮"——高频清脆 | 短促、明亮 |
| 木材 | 木头断裂"咔"——中频闷响 | 短促、钝感 |
| 墨点 | 水墨泼溅"噗"——低频扩散 | 柔和、扩散感 |

#### BGM 管理

| 场景 | BGM | 风格 |
|------|-----|------|
| 标题画面 | 标题曲 | 肃穆、邀请感（古琴/箫） |
| 战斗 | 战斗曲 | 紧张、节奏感（鼓+弦） |
| 间歇 | 氛围曲 | 宁静、蓄势（环境音为主） |
| 死亡 | 静默 | 无 BGM，只有余音消散 |
| 万剑归宗 | 高潮曲 | 爆发、辉煌（全乐器） |

### Audio Bus Architecture

```
Master
├── SFX (音效)
│   ├── Sword Hits (剑招命中)
│   ├── Sword Trails (剑招轨迹)
│   ├── Material Reactions (材质反应)
│   ├── UI Sounds (UI 音效)
│   └── Ambient (环境音)
└── BGM (背景音乐)
```

### Interactions with Other Systems

**对外发出的接口：**

| 接口 | 类型 | 说明 | 接收系统 |
|------|------|------|---------|
| `play_sfx(name: String, volume: float, pitch: float)` | 播放 | 播放一次性音效 | 命中反馈, HUD/UI |
| `play_loop(name: String, volume: float)` | 播放 | 播放/启动循环音效 | 三式剑招系统 |
| `stop_loop(name: String)` | 停止 | 停止循环音效 | 三式剑招系统 |
| `play_bgm(name: String, crossfade: float)` | 播放 | 切换 BGM（带 crossfade） | 游戏状态管理 |
| `stop_bgm(fade_out: float)` | 停止 | 停止 BGM（带淡出） | 游戏状态管理 |
| `set_bus_volume(bus: String, volume: float)` | 设置 | 设置总线音量 | 设置菜单 |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 命中反馈 | 命中事件 | 播放对应材质的命中音效 |
| 游戏状态管理 | `state_changed` | 切换 BGM（战斗曲/氛围曲/静默） |
| 三式剑招系统 | 剑招触发/结束 | 播放/停止轨迹音效 |
| 万剑归宗 | 万剑归宗触发 | 播放高潮曲 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `play_sfx` | `play_sfx(name: String, volume: float, pitch: float)` | `void` | 播放一次性音效 |
| `play_loop` | `play_loop(name: String, volume: float)` | `void` | 播放循环音效 |
| `stop_loop` | `stop_loop(name: String)` | `void` | 停止循环音效 |
| `play_bgm` | `play_bgm(name: String, crossfade: float)` | `void` | 切换 BGM |
| `stop_bgm` | `stop_bgm(fade_out: float)` | `void` | 停止 BGM |
| `set_bus_volume` | `set_bus_volume(bus: String, volume: float)` | `void` | 设置总线音量（0–1） |
| `init_audio_context` | `init_audio_context()` | `void` | Web 平台初始化 AudioContext |

## Formulas

**音效库大小估算：**

`total_size_mb = (sfx_count * avg_sfx_duration_s * sample_rate * bit_depth / 8 / 1024 / 1024) * compression_ratio`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 音效数量 | `sfx_count` | int | 20–30 | 音效文件总数 |
| 平均时长 | `avg_sfx_duration_s` | float | 0.5–3.0 秒 | 音效平均时长 |
| 采样率 | `sample_rate` | int | 22050 Hz | OGG 采样率 |
| 压缩比 | `compression_ratio` | float | 0.1–0.2 | OGG Vorbis 压缩比 |

**输出范围：** 约 0.5–2 MB（远低于 50MB 预算）

**示例：** 25 个音效 × 1.5 秒平均 × 22050 Hz × 16 bit / 8 × 0.15 压缩比 ≈ 1.5 MB

## Edge Cases

- **如果 Web 平台 AudioContext 尚未初始化**：`play_sfx` 静默失败，不报错。首次用户交互时调用 `init_audio_context()` 自动初始化。
- **如果同一音效在同一帧被多次触发**（如快速连击）：允许重叠播放，但限制同一音效最多同时 3 个实例。
- **如果 BGM 切换时正在 crossfade 中**：中断当前 crossfade，立即开始新的 crossfade。
- **如果循环音效请求停止但不在播放中**：静默忽略。
- **如果 `set_bus_volume` 传入超出 0–1 范围的值**：clamp 到 0–1。
- **如果音频文件加载失败**（Web 端网络问题）：发出警告日志，使用静默代替。

## Dependencies

### 上游依赖

无。音频系统是 Foundation 层零依赖系统。直接使用 Godot 的 AudioServer、AudioStreamPlayer、AudioStreamPlayer2D。

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 命中反馈 | 硬依赖 | 调用 `play_sfx` 播放命中音效 |
| HUD/UI 系统 | 软依赖 | 调用 `play_sfx` 播放 UI 音效 |
| 游戏状态管理 | 交互依赖 | 监听 `state_changed` 信号，调用 `play_bgm` 切换 BGM |
| 三式剑招系统 | 软依赖 | 调用 `play_loop`/`stop_loop` 播放轨迹音效 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `master_volume` | 1.0 | 0.0–1.0 | 主音量 |
| `sfx_volume` | 0.8 | 0.0–1.0 | 音效音量 |
| `bgm_volume` | 0.5 | 0.0–1.0 | BGM 音量 |
| `bgm_crossfade_duration` | 1.0 秒 | 0.5–3.0 秒 | BGM 切换的 crossfade 时长 |
| `max_concurrent_sfx` | 8 | 4–16 | 最大同时播放音效数（性能控制） |
| `same_sfx_overlap_limit` | 3 | 1–5 | 同一音效最大同时实例数 |

## Visual/Audio Requirements

**本系统不直接产生视觉效果。** 音频的详细设计（每首 BGM 的编曲、每个音效的录制规格）由声音设计师在音频系统 GDD 之外定义。

音频格式要求已在 Art Bible Section 8（Asset Standards）中定义：
- 格式：OGG Vorbis
- 采样率：22050 Hz
- 音效数量：< 30 个
- 音乐：循环片段

## UI Requirements

**可选功能（非 MVP）：** 设置菜单中的音量滑块（Master/SFX/BGM 三轨）。调用 `set_bus_volume`。可在后续迭代中添加。

## Acceptance Criteria

- **GIVEN** 命中反馈触发金属碰撞事件，**WHEN** 调用 `play_sfx("hit_metal", 0.8, 1.0)`，**THEN** 金属碰撞音效以 80% 音量、原始音调播放
- **GIVEN** 游戏状态从 TITLE 切换到 COMBAT，**WHEN** 调用 `play_bgm("combat", 1.0)`，**THEN** 战斗曲以 1 秒 crossfade 从标题曲切换
- **GIVEN** 绕剑式激活，**WHEN** 调用 `play_loop("trail_ink", 0.6)`，**THEN** 墨色流光循环音效以 60% 音量持续播放
- **GIVEN** 绕剑式结束，**WHEN** 调用 `stop_loop("trail_ink")`，**THEN** 循环音效停止
- **GIVEN** 玩家快速连击 5 次，**WHEN** 同一音效被触发 5 次，**THEN** 最多 3 个实例同时播放
- **GIVEN** `set_bus_volume("sfx", 1.5)`，**WHEN** 设置音量，**THEN** 实际设置为 1.0（clamp）
- **GIVEN** Web 平台 AudioContext 未初始化，**WHEN** 调用 `play_sfx`，**THEN** 静默失败，不报错
- **GIVEN** 音效库包含 25 个文件，**WHEN** 计算总大小，**THEN** ≤ 2 MB

## Open Questions

- 三式的轨迹音效（绕剑式"呼"、游剑式"嗖"、钻剑式"嗡"）是循环播放还是根据剑招执行时间动态调整？如果是循环音效，停止时需要淡出避免突兀。
- BGM 的高潮曲（万剑归宗时）是单独的曲目还是从战斗曲动态过渡？动态过渡更流畅但实现更复杂。
- Web 平台的 AudioContext 初始化时机：是在标题画面等待用户点击，还是在首次进入战斗时？前者更可靠。
