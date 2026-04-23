# ADR-0004: 音频系统架构

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Audio |
| **Knowledge Risk** | LOW — AudioServer 和 AudioStreamPlayer 在 LLM 训练数据内，Web Audio API 后端稳定 |
| **References Consulted** | `docs/engine-reference/godot/modules/audio.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Web 平台 AudioContext 初始化时机（需要用户手势） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（游戏状态管理——BGM 随状态切换） |
| **Enables** | 命中反馈系统、HUD/UI 系统（音效播放） |
| **Blocks** | 命中反馈系统实现 |
| **Ordering Note** | 应在命中反馈系统之前 Accepted |

## Context

### Problem Statement
《归宗》需要精确的音效反馈——三式各有音色（游剑式高频"嗖"、钻剑式低频"砰"、绕剑式中频"呼"），材质反应有独特音效（金属"叮"、木材"咔"、墨点"噗"）。BGM 需要在游戏状态间平滑切换。Web 平台的 AudioContext 需要用户手势初始化。

### Constraints
- Web 平台：AudioContext 需要用户手势（点击/按键）初始化
- 音效库 < 30 个文件，OGG Vorbis 格式，22050 Hz
- 3 条音频总线：Master / SFX / BGM
- 同一音效最多同时 3 个实例

### Requirements
- 音效播放（一次性 + 循环）
- BGM 管理（播放/切换/crossfade）
- 音量控制（3 轨独立）
- Web AudioContext 自动初始化

## Decision

使用 **Godot AudioServer + AudioStreamPlayer + 预加载** 模式。

核心架构：
1. **3 条音频总线**：Master → SFX + BGM，每条独立音量控制
2. **音效预加载**：所有音效在启动时加载到内存（< 30 文件，< 2MB）
3. **BGM 流式加载**：BGM 使用 `AudioStreamPlayer` 的流式模式
4. **Web AudioContext**：首次用户交互时自动初始化
5. **音效实例限制**：同一音效最多 3 个同时实例

### Key Interfaces

```gdscript
# AudioSystem.gd (Foundation)

func play_sfx(name: StringName, volume: float = 1.0, pitch: float = 1.0) -> void
func play_loop(name: StringName, volume: float = 1.0) -> void
func stop_loop(name: StringName) -> void
func play_bgm(name: StringName, crossfade: float = 1.0) -> void
func stop_bgm(fade_out: float = 1.0) -> void
func set_bus_volume(bus: StringName, volume: float) -> void
func init_audio_context() -> void  # Web 平台首次交互调用
```

## Consequences

### Positive
- Godot 原生音频系统满足所有需求，无需自定义
- 预加载确保音效即时播放（无加载延迟）
- 3 轨总线提供灵活的音量控制

### Negative
- 预加载增加了启动内存占用（约 2MB）
- Web 端 AudioContext 初始化依赖用户手势——首次交互前静默

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| audio-system.md | Core Rules 1-7 | 3 轨总线 + 预加载 + 流式 BGM + 实例限制 + Web 适配 |
| audio-system.md | Sound Categories | 三式音色 + 材质反应音效 + BGM 管理 |
| hit-feedback.md | 命中音效 | `play_sfx()` 接口 |

## Performance Implications
- **CPU**: 极低——音频播放由 AudioServer 处理
- **Memory**: 约 2MB（音效预加载）
- **Load Time**: 增加约 0.5 秒（音效预加载）
- **Network**: N/A

## Related Decisions
- ADR-0001（游戏状态管理）—— BGM 随 `state_changed` 切换
