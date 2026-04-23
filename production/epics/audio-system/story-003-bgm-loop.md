# Story 003: 循环音效与 BGM Crossfade

> **Epic**: 音频系统 (Audio System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUDIO-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Audio System Architecture
**ADR Decision Summary**: BGM 使用流式加载，支持 crossfade 切换（默认 1s），循环音效支持启动/停止。

**Engine**: Godot 4.6.2 | **风险**: LOW
**Engine Notes**: AudioStreamPlayer 用于 BGM（非 2D/3D）。Tween 用于 crossfade 淡入淡出。BGM 使用 AudioStreamOggVorbis 的 loop 属性。

**Control Manifest Rules (this layer)**:
- Required: 音频使用 3 条总线：Master → SFX + BGM — source: ADR-0004
- Required: 音效预加载（< 30 文件，< 2MB），BGM 流式加载 — source: ADR-0004
- Forbidden: 禁止硬编码游戏数值 — 必须数据驱动
- Guardrail: 音效库 < 30 文件，< 2MB — source: ADR-0004

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] **AC-1**: `play_loop("trail_ink", 0.6)` 以 60% 音量持续播放墨色流光循环音效
- [ ] **AC-2**: `stop_loop("trail_ink")` 停止正在播放的循环音效
- [ ] **AC-3**: `stop_loop("nonexistent")` 静默忽略，不报错
- [ ] **AC-4**: `play_bgm("combat", 1.0)` 以 1 秒 crossfade 从当前 BGM 切换到战斗曲
- [ ] **AC-5**: BGM crossfade 过程中再次调用 `play_bgm("ambient", 1.0)`，中断当前 crossfade，立即开始新的 crossfade
- [ ] **AC-6**: `stop_bgm(0.5)` 以 0.5 秒淡出停止 BGM

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

### 循环音效 (play_loop / stop_loop)
- 使用 AudioStreamPlayer，设置 stream.loop = true
- `play_loop(name, volume)`: 创建 player，设置 volume，play()
- `stop_loop(name)`: 查找活跃 player，stop() + queue_free()，不存在则静默忽略
- 追踪字典：`active_loops: Dictionary = { "name": AudioStreamPlayer }`

### BGM 管理 (play_bgm / stop_bgm)
- 使用两个 AudioStreamPlayer（bgm_current / bgm_next）实现 crossfade
- `play_bgm(name, crossfade_duration)`:
  1. 加载 BGM stream（非 preload，运行时加载）
  2. bgm_next 播放新曲，volume_db = linear_to_db(0.0)
  3. Tween: bgm_current 从当前音量 → 0.0，bgm_next 从 0.0 → bgm_volume
  4. crossfade 完成后 bgm_current.stop()，交换 current/next 引用
- **中断处理**: 如果正在 crossfade 时再次调用 play_bgm：
  - kill() 当前 tween
  - bgm_current 立即设为当前音量（不等淡出）
  - 以新 BGM 开始新的 crossfade
- `stop_bgm(fade_out_duration)`: Tween bgm_current → 0.0，完成后 stop()
- BGM 总是路由到 BGM 总线（bus_index = BGM bus from Story 001）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 音频总线架构（SFX/BGM 总线、set_bus_volume）
- **Story 002**: 一次性 SFX 播放（play_sfx）与实例限制
- **Story 004**: Web AudioContext 初始化

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Loop playback
  - Given: AudioManager initialized with "trail_ink" available
  - When: play_loop("trail_ink", 0.6) is called
  - Then: An AudioStreamPlayer is created with loop=true, volume_db = linear_to_db(0.6), playing = true
  - Edge cases: Same loop called twice → second call ignored or restarts

- **AC-2**: Loop stop
  - Given: "trail_ink" is actively looping
  - When: stop_loop("trail_ink") is called
  - Then: The AudioStreamPlayer stops and is freed, removed from active_loops
  - Edge cases: Stop immediately after play

- **AC-3**: Stop nonexistent loop
  - Given: No loop named "nonexistent" is playing
  - When: stop_loop("nonexistent") is called
  - Then: No error, no crash, method returns normally
  - Edge cases: Empty string, null-like values

- **AC-4**: BGM crossfade
  - Given: "title" BGM is currently playing at full volume
  - When: play_bgm("combat", 1.0) is called
  - Then: "combat" starts at volume 0, "title" fades from current to 0 over 1s, "combat" fades from 0 to bgm_volume over 1s
  - Edge cases: crossfade = 0 (immediate switch)

- **AC-5**: Crossfade interruption
  - Given: Crossfade from "title" to "combat" is in progress (0.5s in)
  - When: play_bgm("ambient", 1.0) is called
  - Then: Current tween is killed, "combat" becomes the outgoing BGM, "ambient" starts crossfade
  - Edge cases: Rapid 3+ play_bgm calls in succession

- **AC-6**: BGM stop with fade
  - Given: "combat" BGM is playing
  - When: stop_bgm(0.5) is called
  - Then: BGM fades from current volume to 0 over 0.5s, then stops
  - Edge cases: fade_out = 0 (immediate stop)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio-system/audio_bgm_loop_test.gd` OR playtest doc

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: Story 001（需要音频总线架构）, Story 002（AudioManager 基础设施）
- Unlocks: None
