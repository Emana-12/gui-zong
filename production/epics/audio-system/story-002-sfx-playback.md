# Story 002: SFX 播放与实例限制

> **Epic**: 音频系统 (Audio System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUDIO-002`, `TR-AUDIO-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Audio System Architecture
**ADR Decision Summary**: 音效预加载 (<30 文件, <2MB)，同音效最大 3 实例，最大同时 8 个音效。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: AudioStreamPlayer 为稳定 API。preload() 在 _ready() 中调用。pitch_scale 属性控制音调。

**Control Manifest Rules (this layer)**:
- Required: 音效预加载（< 30 文件，< 2MB），BGM 流式加载 — source: ADR-0004
- Forbidden: 禁止硬编码游戏数值 — 必须数据驱动
- Guardrail: 音效库 < 30 文件，< 2MB — source: ADR-0004

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] **AC-1**: `play_sfx("hit_metal", 0.8, 1.0)` 以 80% 音量、原始音调播放金属碰撞音效
- [ ] **AC-2**: `play_sfx("hit_metal", 0.5, 1.5)` 以 50% 音量、1.5 倍音调播放
- [ ] **AC-3**: 同一音效被快速触发 5 次，最多 3 个实例同时播放（same_sfx_overlap_limit = 3）
- [ ] **AC-4**: 不同音效同时播放不受同一音效限制影响
- [ ] **AC-5**: 音效库包含 25 个 OGG Vorbis 文件时，总大小 ≤ 2 MB

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

- 音效在 `_ready()` 中通过 `preload()` 加载到 Dictionary：`{ "name": AudioStream }`
- `play_sfx(name, volume, pitch)` 流程：
  1. 查找 AudioStream，不存在则 warn + return
  2. 检查同名音效活跃实例数 ≥ same_sfx_overlap_limit(3) 则跳过
  3. 创建 AudioStreamPlayer，设置 stream / volume_db / pitch_scale
  4. 连接 `finished` 信号到回收函数
  5. 播放并将 player 加入活跃列表
- 活跃实例追踪：`{ "sfx_name": [AudioStreamPlayer, ...] }` — finished 时移除
- pitch_scale 直接映射：pitch 参数即 pitch_scale 值（1.0 = 原始）
- volume 参数使用 `linear_to_db()` 转换后设到 player.volume_db
- 总实例上限 max_concurrent_sfx = 8 超出时拒绝新播放

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 音频总线架构（SFX/BGM 总线创建、set_bus_volume）
- **Story 003**: 循环音效（play_loop/stop_loop）与 BGM crossfade
- **Story 004**: Web AudioContext 初始化

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Basic SFX playback
  - Given: AudioManager initialized with "hit_metal" preloaded
  - When: play_sfx("hit_metal", 0.8, 1.0) is called
  - Then: An AudioStreamPlayer is created, volume_db = linear_to_db(0.8), pitch_scale = 1.0, and playing = true
  - Edge cases: Name not found → warn + no crash

- **AC-2**: Pitch variation
  - Given: AudioManager initialized with "hit_metal" preloaded
  - When: play_sfx("hit_metal", 0.5, 1.5) is called
  - Then: pitch_scale = 1.5, volume_db = linear_to_db(0.5)
  - Edge cases: pitch = 0.5 (lower), pitch = 2.0 (higher)

- **AC-3**: Same-SFX overlap limit
  - Given: "hit_metal" has 2 active instances playing
  - When: play_sfx("hit_metal", ...) is called 4 more times
  - Then: Only 1 new instance is created (total = 3), remaining 3 calls are skipped
  - Edge cases: Limit = 1 → only 1 instance ever

- **AC-4**: Different SFX independence
  - Given: "hit_metal" has 3 active instances (at limit)
  - When: play_sfx("hit_wood", ...) is called
  - Then: "hit_wood" instance is created normally (not affected by metal limit)
  - Edge cases: Multiple different SFX all at individual limits

- **AC-5**: Library size constraint
  - Given: 25 OGG Vorbis files at 22050Hz, avg 1.5s duration
  - When: Calculate total_size_mb = (25 * 1.5 * 22050 * 16 / 8 / 1024 / 1024) * 0.15
  - Then: total_size_mb ≈ 1.5 MB ≤ 2 MB
  - Edge cases: 30 files × 3s → verify still ≤ 2MB

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio-system/audio_sfx_test.gd` — must exist and pass

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: Story 001（需要音频总线架构）
- Unlocks: Story 003（循环/BGM 使用相同 AudioManager 基础设施）
