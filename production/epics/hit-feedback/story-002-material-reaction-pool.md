# Story 002: 材质反应与对象池

> **Epic**: 命中反馈 (Hit Feedback)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/hit-feedback.md`
**Requirement**: `TR-FBK-001`, `TR-FBK-003`
**ADR Governing Implementation**: ADR-0013: 命中反馈架构
**ADR Decision Summary**: 材质反应分发表(剑式×材质→效果)，对象池预分配粒子节点，最大 4 draw call/帧限制，0.5秒自动销毁。

**Engine**: Godot 4.6.2 stable | **Risk**: LOW
**Engine Notes**: GPUParticles2D 在 LLM 训练数据范围内。对象池为纯 GDScript 逻辑。

## Acceptance Criteria

- [ ] **游剑式命中金属**：金色火花飞溅粒子效果 + 金属"叮"音效
- [ ] **钻剑式命中敌人**：扇形冲击波粒子效果 + 闷响"砰"音效
- [ ] **绕剑式化解**：墨点炸碎粒子效果 + 水墨"噗"音效
- [ ] **材质反应持续 0.5 秒**：动画结束 → 节点自动回收至对象池
- [ ] **对象池限制**：同时活跃粒子节点不超过 4 个（draw call 上限，TR-FBK-003）
- [ ] **音效播放**：材质反应伴随对应音效，通过 AudioSystem (ADR-0004) 播放

## Implementation Notes

*Derived from ADR-0013 Implementation Guidelines:*

- **分发表**: Dictionary 结构 `{form_type: {material_type: effect_scene}}`，将剑式和材质映射到对应粒子场景
- **对象池**: 预创建 4 个 GPUParticles2D 节点，初始化时隐藏。命中时从池中取出、定位、激活；0.5s 后回收
- **自动销毁计时**: 使用 SceneTreeTimer 或 Tween 控制 0.5 秒生命周期：`get_tree().create_timer(0.5).timeout.connect(_recycle)`
- **粒子场景**: 每种效果为独立 .tscn 文件，包含 GPUParticles2D + 音效播放器
- **Draw call 保证**: 所有材质反应复用相同材质/纹理集，确保不超过 4 draw call/帧
- **对象池空闲**: 若池满（4 个都在用），新命中不产生材质反应（优先保证帧率）
- **位置对齐**: 粒子节点放置在命中点 world_position，由 hit_judged 信号携带

## Out of Scope

- **Story 001**: 顿帧与屏幕震动（独立的时停机制）
- **Story 003**: 万剑归宗特殊反馈（全屏爆发效果，需对象池就绪后实现）

## QA Test Cases

- **AC-1**: 金色火花 — Given: 游剑式命中金属敌人, When: 命中反馈触发, Then: 金色火花粒子在命中点生成 + 金属音效播放
- **AC-2**: 扇形冲击波 — Given: 钻剑式命中, When: 命中反馈触发, Then: 扇形冲击波粒子 + 沉闷音效
- **AC-3**: 墨点炸碎 — Given: 绕剑式化解, When: 命中反馈触发, Then: 墨点破碎粒子 + 水墨音效
- **AC-4**: 自动回收 — Given: 材质反应已触发, When: 0.5 秒后, Then: 粒子节点回收至池中，不可见
- **AC-5**: 池上限 — Given: 4 个粒子节点正在使用, When: 第 5 次命中发生, Then: 不生成新粒子（静默跳过），不报错
- **AC-6**: 音效关联 — Given: 每种材质反应, When: 粒子激活时, Then: 对应音效通过 AudioSystem 播放
- **AC-Edge**: 池回收后再分配 — Given: 粒子节点已回收, When: 新命中触发, Then: 回收的节点被重新使用

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/material-reaction-evidence.md` + sign-off
- 自动化: `tests/unit/hit-feedback/object_pool_test.gd`（池分配/回收逻辑）

**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: Story 001（顿帧框架）、AudioSystem story-002（SFX 播放）、ShaderRendering story-001（材质池）
- Unlocks: Story 003（万剑归宗爆发效果需要对象池就绪）
