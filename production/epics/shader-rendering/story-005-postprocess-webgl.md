# Story 005: 后处理 Pass 与 WebGL 回退

> **Epic**: 着色器/渲染 (Shader/Rendering)
> **Status**: Complete
> **Completed**: 2026-04-22
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-22

## Context

**GDD**: `design/gdd/shader-rendering.md`
**Requirement**: `TR-SHADER-004`, `TR-SHADER-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: 渲染管线与着色器架构
**ADR Decision Summary**: 后处理最多 2 个 pass（描边 + 色调调整），Web 端可动态关闭。WebGL 2.0 编译失败时跳过 pass 不崩溃。

**Engine**: Godot 4.6.2 stable | **Risk**: HIGH
**Engine Notes**: D3D12 默认（4.6）不影响 Web 导出（Web 始终使用 WebGL）。glow 重做参数（4.6）需验证色调调整 pass 兼容性。4.4 纹理类型变更需注意。

**Control Manifest Rules (Foundation layer)**:
- Required: 后处理 ≤2 pass；WebGL 2.0 回退必须 graceful
- Forbidden: GDExtension（Web 端不支持）
- Guardrail: 后处理编译失败 → 跳过不崩溃；draw call ≤50

---

## Acceptance Criteria

*From GDD `design/gdd/shader-rendering.md`, scoped to this story:*

- [ ] **AC-7**: GIVEN WebGL 2.0 不支持后处理描边 pass，WHEN 编译失败，THEN 跳过该 pass，游戏不崩溃

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

### 后处理 Pass 定义

| Pass | 功能 | 可关闭 | Web 默认 |
|------|------|--------|---------|
| Pass 1: 描边 | 物体边缘描边效果 | 是 | 关闭（性能优先） |
| Pass 2: 色调调整 | 墨色/金色色温控制 | 是 | 开启 |

### WebGL 2.0 回退策略

1. 尝试编译后处理 pass
2. 如果编译失败（WebGL 不支持）：
   - 记录警告日志
   - 跳过该 pass
   - 游戏继续运行（不崩溃）
3. 如果编译成功但在运行时帧率下降：
   - 由 Story 004 的自动降级系统处理

### 实现要点

- 使用 Godot 的 CompositorEffect 或 SubViewport 实现后处理
- 编译失败检测：使用 try/catch 或 shader compilation error signal
- 提供 `set_post_process_enabled(pass_name, enabled)` 接口供外部控制
- 描边 pass 在 Web 端默认关闭（仅在帧率充足时由玩家或自动系统开启）
- 色调调整 pass 轻量级，Web 端默认开启

### 接口

```gdscript
func set_post_process_enabled(pass_name: StringName, enabled: bool) -> void:
    # pass_name: "outline" | "tone"
    # 启用/禁用指定后处理 pass
    # 如果 pass 编译失败，调用此方法应记录警告但不崩溃
    pass

func _init_post_processing() -> void:
    # 初始化后处理 pass
    # 捕获编译失败 → 跳过该 pass + 日志警告
    pass
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 材质池与着色器管理器（提供 set_post_process_enabled 接口定义）
- Story 002: 水墨着色器库（角色/环境着色器文件）
- Story 003: 流光轨迹着色器
- Story 004: 自动降级系统（调用 set_post_process_enabled 关闭 pass）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**自动化测试规格（Integration 故事）：**

- **AC-7**: WebGL 编译失败回退
  - Given: 模拟后处理描边 pass 编译失败
  - When: _init_post_processing() 被调用
  - Then: 描边 pass 被跳过，游戏继续运行，日志记录警告
  - Edge cases: 两个 pass 都失败 → 全部跳过; 仅色调 pass 成功 → 只启用色调; 编译成功但运行时异常

**手动验证步骤：**

- 后处理视觉验证
  - Setup: 在 Desktop 端运行，启用描边 + 色调两个 pass
  - Verify: 描边 pass 产生物体边缘描边效果，色调 pass 调整画面色温
  - Pass condition: 两个 pass 可独立开关，同时启用时画面效果叠加正确

- Web 端回退验证
  - Setup: 在 Chrome/Firefox 的 WebGL 2.0 下导出并运行
  - Verify: 如果描边 pass 编译失败，游戏不崩溃，日志有警告
  - Pass condition: 游戏可正常游玩，无视觉异常（可能缺少描边效果）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/shader-rendering/postprocess_webgl_test.gd` OR playtest doc

**Status**: Complete (test file exists and passing)

---

## Dependencies

- Depends on: Story 001（需要 set_post_process_enabled 接口定义）
- Depends on: Story 002（着色器编译需在着色器文件存在后验证）
- Unlocks: 游戏状态管理可在万剑归宗时启用特殊后处理效果
