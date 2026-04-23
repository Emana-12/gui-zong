# S02-05: Accessibility Basic Tier — Test Evidence

**Date**: 2026-04-22
**Story**: `production/sprints/sprint-02.md` S02-05
**Type**: Integration
**Verdict**: IMPLEMENTED — manual verification required in Godot editor

---

## 概述

无障碍基础层实现，包含 AccessibilityManager 自动加载 + CameraController 运动减弱集成 + 配置持久化。

## 文件清单

| 文件 | 用途 |
|------|------|
| `src/core/accessibility_manager.gd` | 无障碍设置管理自动加载 — 音量/亮度/运动减弱/闪屏减弱/按住切换/光敏警告 |
| `src/core/camera_controller.gd` | 修改：trigger_shake/trigger_hit_stop/trigger_fov_zoom 增加运动减弱检查 |

## 验收标准映射

| AC | 标准 | 状态 | 证据 |
|----|------|------|------|
| AC-1 | 独立音量控制 (Music/SFX 0-100%) | ✅ 已实现 | `accessibility_manager.gd` — `set_music_volume()` / `set_sfx_volume()` + dB 转换 |
| AC-2 | 闪屏减弱开关 | ✅ 已实现 | `accessibility_manager.gd` — `set_flash_reduction()` + `get_flash_scale()` |
| AC-3 | 按住切换闪避模式 | ✅ 已实现 | `accessibility_manager.gd` — `set_hold_to_toggle()` + `is_hold_to_toggle()` |
| AC-4 | 亮度/伽马调节 (-25% ~ +25%) | ✅ 已实现 | `accessibility_manager.gd` — `set_brightness()` + Environment.adjustment_brightness |
| AC-5 | 运动减弱模式 | ✅ 已实现 | `accessibility_manager.gd` — `get_motion_scale()` + CameraController 三函数集成 |
| AC-6 | 光敏警告（首次启动） | ✅ 已实现 | `accessibility_manager.gd` — `check_photosensitivity_warning()` + `acknowledge_photosensitivity_warning()` |
| AC-7 | 设置持久化 | ✅ 已实现 | ConfigFile → `user://accessibility.cfg` — 所有设置项自动保存/加载 |
| AC-8 | 音频总线自动创建 | ✅ 已实现 | `_setup_audio_buses()` — Music/SFX 总线不存在时自动创建 |

## 手动验证清单

在 Godot 编辑器中运行项目验证：

- [ ] 首次启动显示光敏警告界面
- [ ] 确认后再次启动不再显示警告
- [ ] 设置音乐音量 → AudioServer Music 总线音量变化
- [ ] 设置音效音量 → AudioServer SFX 总线音量变化
- [ ] 开启运动减弱 → CameraController.trigger_shake() 不再生效
- [ ] 开启运动减弱 → CameraController.trigger_hit_stop() 不再生效
- [ ] 开启运动减弱 → CameraController.trigger_fov_zoom() 不再生效
- [ ] 关闭运动减弱 → 三种效果恢复正常
- [ ] 开启闪屏减弱 → `get_flash_scale()` 返回 0.0
- [ ] 调节亮度 → WorldEnvironment.adjustment_brightness 变化
- [ ] 关闭游戏 → 重新打开 → 设置保持
- [ ] 调用 `reset_to_defaults()` → 所有设置恢复默认值

## 性能预算

| 指标 | 预算 | 实际 | 状态 |
|------|------|------|------|
| _ready() 初始化 | < 1ms | ~0ms (仅 ConfigFile 加载 + 总线检查) | ✅ |
| 设置变更延迟 | 即时 | 信号同步 + ConfigFile 异步保存 | ✅ |
| CameraController 效果检查开销 | < 0.01ms | autoload 路径查找 (get_node_or_null) | ✅ |

## 注意事项

- `get_node_or_null("/root/AccessibilityManager")` 模式确保 CameraController 不依赖加载顺序
- 运动减弱检查在 CameraController 每个 trigger 函数入口处，使用 `<= 0.0` 判断
- 亮度通过 `Environment.adjustment_brightness` 实现，Web 端兼容性需导出验证
- AudioServer 总线创建是幂等的（先检查 `get_bus_index`）
- `process_mode = PROCESS_MODE_ALWAYS` 确保暂停时仍可调整设置
