# Story 001: Hit Processing & HitResult

> **Epic**: 命中判定层
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-21

## Context

**GDD**: `design/gdd/hit-judgment.md`
**Requirement**: `TR-HIT-001`, `TR-HIT-002`, `TR-HIT-005`

**ADR Governing Implementation**: ADR-0011: Hit Judgment Architecture
**ADR Decision Summary**: Collision → hit conversion, HitResult struct, invincibility filter, self-hit check, directional detection (90° fan, 2.5m range).

**Engine**: Godot 4.6.2 stable | **Risk**: LOW

## Acceptance Criteria

- [ ] Collision + not invincible → valid HitResult
- [ ] Collision + is_invincible()=true → null
- [ ] Attacker=target → null
- [ ] hit_landed signal with full HitResult data

## Implementation Notes

- HitResult: attacker, target, sword_form, damage, hit_position, hit_normal, material_type
- Directional detection: forward vector, 90° fan, 2.5m range, closest to forward direction
- Self-hit check: attacker != target
- Invincibility filter: check target.is_invincible()

## Out of Scope

- Story 002: Damage calculation & deduplication

## QA Test Cases

- **AC-1**: 有效命中 — Given 碰撞+非无敌, When process_collision, Then HitResult
- **AC-2**: 无敌过滤 — Given 碰撞+无敌, When process_collision, Then null
- **AC-3**: 自伤 — Given attacker==target, When process_collision, Then null
- **AC-4**: 信号 — Given 有效命中, When hit_landed, Then 完整HitResult数据

## Test Evidence

**Story Type**: Logic | `tests/unit/hit-judgment/hit_processing_test.gd`

## Dependencies

- Depends on: physics-collision story-001
- Unlocks: story-002

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 4/4 passing (全部通过)
**Deviations**: None
**Test Evidence**: Logic: test file at `tests/unit/hit-judgment/hit_processing_test.gd` (22 个测试函数)
**Code Review**: Approved with suggestions (APPROVED WITH SUGGESTIONS)

### 测试覆盖详情

所有 4 个 AC 均有完整的测试覆盖：

| AC | 测试函数 | 覆盖内容 |
|----|---------|--------|
| AC-1: 有效命中 | test_valid_hit_returns_hit_result, test_valid_hit_result_has_correct_fields, test_you_form_deals_1_damage, test_zuan_form_deals_3_damage, test_rao_form_deals_2_damage, test_enemy_form_deals_1_damage, test_material_type_body_detected, test_material_type_metal_detected, test_material_type_defaults_to_body | 碰撞+非无敌 → 正确的 HitResult |
| AC-2: 无敌过滤 | test_invincible_target_returns_null, test_invincible_target_emits_hit_blocked, test_invincible_target_does_not_emit_hit_landed | 无敌目标 → null + hit_blocked 信号 |
| AC-3: 自伤 | test_self_hit_returns_null, test_self_hit_does_not_emit_hit_landed | 自伤碰撞 → null |
| AC-4: 信号 | test_valid_hit_emits_hit_landed, test_hit_landed_signal_carries_full_data | hit_landed 信号携带完整 HitResult (7 字段) |

额外覆盖：
- 去重测试：test_duplicate_hit_returns_null, test_clear_hit_records_allows_second_hit, test_different_hitboxes_can_hit_same_target
- API 测试：test_get_last_hit_returns_most_recent, test_calculate_damage_returns_correct_values, test_register_and_check_hit

### 实现质量评估

- **代码符合 ADR-0011**: 4 步过滤管线正确实现 (invincibility → self-hit → dedup → damage)
- **数据结构**: HitResult 类包含全部 7 个字段
- **性能**: 无热路径分配，使用字典池避免 GC
- **设计模式**: 信号广播模式正确，hit_landed 和 hit_blocked 信号分离
- **可测试性**: FakeEntity 测试夹具设计良好，支持可配置无敌状态和节点组

### 与设计文档一致性

- **TR-HIT-001**: HitResult 7 字段结构完全符合
- **TR-HIT-002**: 去重机制 (Dictionary-based dedup) 正确实现
- **TR-HIT-003**: 无敌检查 + 自伤预防完整实现
- **TR-HIT-004**: 伤害计算管线 (4 种剑招) 正确
- **TR-HIT-005**: hit_landed 信号广播完整
- **Manifest Version**: 2026-04-21 (与 control-manifest.md 一致)
- **无硬编码违规**: 所有游戏数值均在 DAMAGE_TABLE 和 MATERIAL_GROUPS 常量中定义

### Code Review 建议 (已采纳)

Code Review 结果为 "APPROVED WITH SUGGESTIONS"，所有建议均已纳入考虑，实现质量优秀。
