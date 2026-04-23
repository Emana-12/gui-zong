# Story 001: 音频总线架构与音量管理

> **Epic**: 音频系统 (Audio System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUDIO-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Audio System Architecture
**ADR Decision Summary**: 3-bus architecture (Master→SFX+BGM) using Godot AudioServer, OGG Vorbis 22050Hz, SFX preload <30 files <2MB.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: AudioServer.add_bus() / set_bus_volume_db() 均为稳定 API。Web 端 AudioStreamPlayer 正常工作。

**Control Manifest Rules (this layer)**:
- Required: 音频使用 3 条总线：Master → SFX + BGM — source: ADR-0004
- Required: 音效预加载（< 30 文件，< 2MB），BGM 流式加载 — source: ADR-0004
- Forbidden: 禁止在 Web 导出中使用 GDExtension — source: ADR-0003
- Guardrail: 音效库 < 30 文件，< 2MB — source: ADR-0004

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] **AC-1**: 游戏启动时创建 3 条音频总线：Master（index 0）、SFX（index 1）、BGM（index 2），SFX 和 BGM 均路由到 Master
- [ ] **AC-2**: `set_bus_volume("sfx", 0.8)` 设置 SFX 总线音量为 0.8（80%）
- [ ] **AC-3**: `set_bus_volume("sfx", 1.5)` 时实际设置为 1.0（clamp 到 0–1 范围）
- [ ] **AC-4**: `set_bus_volume("sfx", -0.3)` 时实际设置为 0.0（clamp 到 0–1 范围）
- [ ] **AC-5**: `set_bus_volume("master", 1.0)` 设置 Master 总线音量为 1.0

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

- AudioManager 作为场景节点（非 Autoload），通过 group `audio_manager` 访问
- 启动时调用 `AudioServer.add_bus()` 创建 SFX 和 BGM 总线，设置路由到 Master
- `set_bus_volume(bus, volume)` 内部使用 `clampf(volume, 0.0, 1.0)` 后转为 dB：`linear_to_db(clamped)`
- 总线名称映射：`"master"` → bus index 0, `"sfx"` → 自定义 index, `"bgm"` → 自定义 index
- 使用 `AudioServer.set_bus_volume_db(index, db_value)` 设置实际音量

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: SFX 播放（play_sfx）与实例限制
- **Story 003**: 循环音效与 BGM crossfade
- **Story 004**: Web AudioContext 初始化

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Bus architecture setup
  - Given: AudioManager is initialized
  - When: Check AudioServer bus count
  - Then: At least 3 buses exist (Master, SFX, BGM)
  - Edge cases: Re-initialization should not duplicate buses

- **AC-2**: Volume set within range
  - Given: SFX bus exists
  - When: set_bus_volume("sfx", 0.8)
  - Then: SFX bus volume_db equals linear_to_db(0.8)
  - Edge cases: Boundary values 0.0 and 1.0

- **AC-3**: Volume clamp upper bound
  - Given: SFX bus exists
  - When: set_bus_volume("sfx", 1.5)
  - Then: SFX bus volume_db equals linear_to_db(1.0)
  - Edge cases: Values > 1.0 (2.0, 100.0)

- **AC-4**: Volume clamp lower bound
  - Given: SFX bus exists
  - When: set_bus_volume("sfx", -0.3)
  - Then: SFX bus volume_db equals linear_to_db(0.0)
  - Edge cases: Values < 0.0 (-1.0, -100.0)

- **AC-5**: Master volume set
  - Given: Master bus exists at index 0
  - When: set_bus_volume("master", 1.0)
  - Then: Master bus volume_db equals linear_to_db(1.0)
  - Edge cases: Setting to 0.0 (mute)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio-system/audio_bus_test.gd` — must exist and pass

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (SFX playback requires bus architecture)
