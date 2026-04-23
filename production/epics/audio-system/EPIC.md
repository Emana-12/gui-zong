# Epic: 音频系统 (Audio System)

> **Layer**: Foundation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: 音频系统模块
> **Status**: Ready
> **Stories**: 4 stories created
> **⚠️ Note**: Vertical slice 将音频系统列为 Out of Scope。本 Epic 不应在垂直切片验证通过前启动。

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 音频总线架构与音量管理 | Logic | Ready | ADR-0004 |
| 002 | SFX 播放与实例限制 | Logic | Ready | ADR-0004 |
| 003 | 循环音效与 BGM Crossfade | Integration | Ready | ADR-0004 |
| 004 | Web AudioContext 初始化 | Integration | Ready | ADR-0004 |

## Overview

音频系统是《归宗》所有声音的入口——精确命中音效、三式剑招音色、环境氛围音、BGM 管理。它通过 Godot 的 AudioServer 和 Web Audio API 后端提供音频播放服务。三式各有独特音色，声音是精确打击的听觉确认。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Audio System Architecture | 3-bus architecture (Master/SFX/BGM), OGG Vorbis, Web AudioContext init | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-AUDIO-001 | 3-bus audio architecture: Master/SFX/BGM with independent volume | ADR-0004 ✅ |
| TR-AUDIO-002 | Sound categories: one-shot, loop, BGM with crossfade | ADR-0004 ✅ |
| TR-AUDIO-003 | OGG Vorbis format, 22050 Hz, Web-friendly | ADR-0004 ✅ |
| TR-AUDIO-004 | Pitch/volume variation for material reaction differences | ADR-0004 ✅ |
| TR-AUDIO-005 | Web AudioContext initialization via user gesture | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-system.md` are verified
- All Logic stories have passing test files in `tests/unit/audio-system/`
- Integration story has playtest evidence confirming audio responsiveness

## Next Step

Run `/story-readiness production/epics/audio-system/story-001-audio-bus.md` then `/dev-story` to begin implementation.
