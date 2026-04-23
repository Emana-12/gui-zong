# Story 001: 波次生成与公式

> **Epic**: 竞技场波次系统 (Arena Wave System)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/arena-wave-system.md`
**Requirement**: TR-WAVE-001, TR-WAVE-003
**ADR Governing Implementation**: ADR-0014: 竞技场波次架构
**ADR Decision Summary**: 公式生成波次难度，enemy_count = 2 + floor(wave_number * 0.8)，敌人类型按波次解锁，使用加权随机选择。

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

*From GDD `design/gdd/arena-wave-system.md`, scoped to this story:*

- [ ] 波次 1 开始时调用 `start_wave(1)`，生成 2 个流动型敌人
- [ ] 波次 5 时计算敌人数量为 2 + floor(5 * 0.8) = 6 个敌人
- [ ] 敌人类型按波次解锁，新类型在特定波次首次出现

## Implementation Notes

*Derived from ADR Implementation Guidelines:*

- 缩放公式：`enemy_count = 2 + floor(wave_number * 0.8)`
- 波次 1: 2 敌人，波次 5: 6 敌人，波次 10: 10 敌人（达到上限）
- 敌人类型解锁表存储在 Dictionary 中：`{wave_number: [enemy_types]}`
- 加权随机选择：根据当前波次可用的敌人类型及其权重随机选取
- `start_wave()` 内部调用 enemy AI 系统的 `spawn_enemy()` 接口

## Out of Scope

- 波次生命周期与完成信号（Story 002）
- 生成队列与最大活跃数上限（Story 002）
- 实际敌人 AI 行为（enemy-system Epic）

## QA Test Cases

- **AC-1**: 波次 1 生成
  - Given: 游戏进入 COMBAT 状态
  - When: 调用 `start_wave(1)`
  - Then: 调用 `spawn_enemy()` 恰好 2 次，敌人类型为流动型
  - Edge cases: 连续调用 `start_wave(1)` 两次（不应重复生成）

- **AC-2**: 缩放公式
  - Given: wave_number = 5
  - When: 计算敌人数量
  - Then: 2 + floor(5 * 0.8) = 2 + 4 = 6
  - Edge cases: wave=1 返回 2、wave=10 返回 10、wave=20 返回 18

- **AC-3**: 敌人类型解锁
  - Given: 当前波次为首次出现新敌人类型的波次
  - When: 选择敌人类型
  - Then: 新类型出现在可选池中
  - Edge cases: 波次 1 仅 1 种类型、所有类型已解锁后全类型可选

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/arena-wave-system/wave_generation_test.gd`
**Status**: Complete (test file exists and passing)

## Dependencies

- Depends on: ADR-0014 Accepted, ADR-0007 (enemy AI) Accepted
- Unlocks: Story 002 (波次生命周期依赖生成逻辑)
