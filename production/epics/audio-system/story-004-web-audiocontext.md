# Story 004: Web AudioContext 初始化

> **Epic**: 音频系统 (Audio System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUDIO-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Audio System Architecture
**ADR Decision Summary**: Web 平台 AudioContext 需要用户手势初始化，首次交互自动触发，初始化前播放静默失败。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Godot 4.6 Web 导出的音频后端为 Web Audio API。AudioContext 在用户交互前处于 suspended 状态。Godot 内部处理大部分 Web Audio 细节，但需要确认首次交互时音频自动恢复。

**Control Manifest Rules (this layer)**:
- Required: 音频使用 3 条总线：Master → SFX + BGM — source: ADR-0004
- Forbidden: 禁止在 Web 导出中使用 GDExtension — source: ADR-0004
- Guardrail: 音效库 < 30 文件，< 2MB — source: ADR-0004

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] **AC-1**: `init_audio_context()` 方法存在，可在任意时刻调用
- [ ] **AC-2**: 在 Web 平台 AudioContext 未初始化时调用 `play_sfx`，静默失败不报错
- [ ] **AC-3**: 首次用户交互（点击/按键）时自动调用 `init_audio_context()`
- [ ] **AC-4**: AudioContext 初始化后，后续 `play_sfx` 正常播放
- [ ] **AC-5**: 非 Web 平台（桌面/编辑器）调用 `init_audio_context()` 无副作用

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

- `init_audio_context()` 设置 `_audio_context_initialized = true` 标志
- 在 `_ready()` 中检测平台：`OS.has_feature("web")` 为 true 时进入 Web 模式
- Web 模式下：
  - 初始状态 `_audio_context_initialized = false`
  - 通过 `_input(event)` 监听首次输入事件（InputEventMouseButton / InputEventKey）
  - 首次交互时调用 `init_audio_context()` 并断开输入监听
  - play_sfx / play_loop / play_bgm 在未初始化时检查标志，直接 return（静默失败）
- 非 Web 模式：
  - `_ready()` 中直接调用 `init_audio_context()`（`_audio_context_initialized = true`）
  - 所有播放方法正常执行，不受标志影响
- Godot 4.6 Web 导出的音频处理：AudioServer 在首次用户交互时自动 resume AudioContext
  - 本 story 的 `init_audio_context()` 作为显式 API 供外部调用
  - 同时在内部标志位层面确保 play 系列方法的安全性

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 音频总线架构（SFX/BGM 总线、set_bus_volume）
- **Story 002**: SFX 播放（play_sfx）与实例限制的具体实现
- **Story 003**: 循环音效与 BGM crossfade 的具体实现

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: init_audio_context method exists
  - Given: AudioManager is in the scene tree
  - When: init_audio_context() is called
  - Then: _audio_context_initialized is set to true, no error
  - Edge cases: Called multiple times → idempotent

- **AC-2**: Silent failure before init (Web mode)
  - Given: OS.has_feature("web") = true, _audio_context_initialized = false
  - When: play_sfx("hit_metal", 0.8, 1.0) is called
  - Then: No AudioStreamPlayer is created, no error/warning emitted
  - Edge cases: play_loop, play_bgm also silent-fail

- **AC-3**: Auto-init on first interaction
  - Given: Web mode, _audio_context_initialized = false
  - When: An InputEventMouseButton or InputEventKey is received in _input()
  - Then: init_audio_context() is called, _audio_context_initialized = true
  - Edge cases: Subsequent input events → no re-initialization

- **AC-4**: Playback after init
  - Given: _audio_context_initialized = true
  - When: play_sfx("hit_metal", 0.8, 1.0) is called
  - Then: AudioStreamPlayer is created and plays normally
  - Edge cases: Immediately after init (same frame)

- **AC-5**: No-op on non-Web
  - Given: OS.has_feature("web") = false
  - When: init_audio_context() is called
  - Then: No error, _audio_context_initialized remains true
  - Edge cases: Called in editor → no crash

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio-system/audio_web_init_test.gd` OR playtest doc

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: Story 001（需要 AudioManager 基础设施）
- Unlocks: None
