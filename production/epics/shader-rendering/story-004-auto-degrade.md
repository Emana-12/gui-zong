# Story 004: 自动降级系统

> **Epic**: 着色器/渲染 (Shader/Rendering)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/shader-rendering.md`
**Requirement**: `TR-SHADER-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: 渲染管线与着色器架构
**ADR Decision Summary**: 帧率驱动的自动降级策略 — fps<30 关闭后处理，fps<20 降低 ink_steps 到 2。

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH
**Engine Notes**: D3D12 默认（4.6）不影响 Web 导出。glow 重做参数（4.6）可能影响降级时的辉光行为。

**Control Manifest Rules (Foundation layer)**:
- Required: 自动降级在帧率 < 30fps 时触发
- Forbidden: 无
- Guardrail: auto_degrade_threshold 可配（20–45 fps 安全范围）

---

## Acceptance Criteria

*From GDD `design/gdd/shader-rendering.md`, scoped to this story:*

- [ ] **AC-6**: GIVEN Web 平台帧率持续 < 30fps，WHEN 自动降级触发，THEN 后处理 pass 被关闭，`ink_steps` 降至 2

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

### 降级策略层级

```
Level 0 (正常): 所有后处理开启，ink_steps = 4
Level 1 (fps < 30): 关闭所有后处理 pass
Level 2 (fps < 20): ink_steps = 2（最低墨色阶梯）
```

### 实现要点

- 使用 `Engine.get_frames_per_second()` 获取帧率
- 持续监控：不是瞬时触发，需要帧率在阈值以下持续 N 帧（防抖）
- 降级后不自动恢复（避免反复切换造成视觉闪烁）
- 通过 `set_post_process_enabled(pass_name, false)` 关闭后处理
- 通过修改着色器参数 `ink_steps = 2` 降低复杂度
- 可配置阈值：`auto_degrade_threshold` 默认 30fps，安全范围 20–45fps

### 公共接口调用

```gdscript
# 降级逻辑伪代码
func _check_degradation() -> void:
    var fps := Engine.get_frames_per_second()
    if fps < 20 and _degradation_level < 2:
        _set_ink_steps(2)
        _degradation_level = 2
    elif fps < 30 and _degradation_level < 1:
        set_post_process_enabled("outline", false)
        set_post_process_enabled("tone", false)
        _degradation_level = 1
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 材质池与着色器管理器（提供 set_post_process_enabled 接口）
- Story 002: 水墨着色器库（着色器文件本身）
- Story 003: 流光轨迹着色器
- Story 005: 后处理 pass 实现 + WebGL 编译失败回退

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**自动化测试规格（Logic 故事）：**

- **AC-6**: 自动降级触发验证
  - Given: 模拟帧率持续 < 30fps（使用 Engine.get_frames_per_second mock）
  - When: _check_degradation() 被调用
  - Then: 后处理 pass 被关闭（outline=false, tone=false），ink_steps 降至 2
  - Edge cases: 帧率刚好 30 → 不触发; 帧率从 60 突降到 15 → 直接触发 Level 2; 帧率恢复 → 不自动恢复

- 降级防抖测试
  - Given: 帧率在 29-31 之间波动
  - When: 多帧后检查
  - Then: 不因瞬时波动触发降级（需持续 N 帧低于阈值）

- 降级不恢复测试
  - Given: 已触发 Level 1 降级
  - When: 帧率恢复到 60fps
  - Then: 降级状态不变（不自动恢复）

**预计测试数量**: ~5 个单元测试

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/shader-rendering/auto_degrade_test.gd` — must exist and pass

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: Story 001（需要 set_post_process_enabled 接口和 get_fps）
- Unlocks: 性能监控集成（游戏状态管理可基于降级级别调整游戏体验）
