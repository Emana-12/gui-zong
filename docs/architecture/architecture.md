# 归宗 (Gui Zong) — Master Architecture

## Document Status

- Version: 1.0
- Last Updated: 2026-04-21
- Engine: Godot 4.6.2 stable (win64), GDScript
- Platform: Web (HTML5), Full 3D Simplified
- GDDs Covered: 18/18 (all systems)
- ADRs Referenced: 18 (all required ADRs accepted — see ADR Audit)
- Technical Director Sign-Off: PENDING
- Lead Programmer Feasibility: PENDING

---

## Engine Knowledge Gap Summary

| Domain | Risk | Key Concern |
|--------|------|-------------|
| Physics (Jolt) | HIGH | Jolt 4.6 默认物理引擎，Web 端碰撞性能未充分验证 |
| Rendering | HIGH | D3D12 默认（Windows），glow 重做，WebGL 2.0 回退需确认 |
| Shader | HIGH | 着色器纹理类型变化（4.4），shader baker（4.5） |
| Input | MEDIUM | 变参函数支持（4.5），Web 端输入延迟 |
| FileAccess | MEDIUM | 返回类型变化（4.4） |

**受影响系统：** 物理碰撞层 (HIGH), 着色器/渲染 (HIGH), 流光轨迹 (MEDIUM), 输入系统 (MEDIUM)

---

## System Layer Map

### Foundation Layer (零依赖)

| Module | GDD | Engine APIs | Risk |
|--------|-----|-------------|------|
| 输入系统 | `input-system.md` | `Input`, `_input()` | MEDIUM |
| 着色器/渲染 | `shader-rendering.md` | `Shader`, `Material`, `RenderingServer` | HIGH |
| 音频系统 | `audio-system.md` | `AudioServer`, `AudioStreamPlayer` | LOW |
| 游戏状态管理 | `game-state-manager.md` | `signal` (Godot 内置) | LOW |

### Core Layer (依赖 Foundation)

| Module | GDD | Depends On | Engine APIs | Risk |
|--------|-----|------------|-------------|------|
| 玩家控制器 | `player-controller.md` | 输入系统 | `CharacterBody3D`, `move_and_slide()` | LOW |
| 物理碰撞层 | `physics-collision.md` | 玩家控制器 | `Area3D`, `CollisionShape3D`, `ShapeCast3D`, Jolt | **HIGH** |
| 命中判定层 | `hit-judgment.md` | 物理碰撞层 | GDScript (无引擎 API) | LOW |
| 三式剑招系统 | `three-forms-combat.md` | 输入系统, 命中判定层 | GDScript + 物理碰撞层 API | LOW |
| 敌人系统 | `enemy-system.md` | 命中判定层, 游戏状态管理 | `CharacterBody3D`, AI 状态机 | LOW |

### Feature Layer (依赖 Core)

| Module | GDD | Depends On | Engine APIs | Risk |
|--------|-----|------------|-------------|------|
| 摄像机系统 | `camera-system.md` | 玩家控制器 | `Camera3D`, `lerp()` | LOW |
| 流光轨迹系统 | `light-trail-system.md` | 三式剑招系统, 着色器/渲染 | `MeshInstance3D`, `ImmediateMesh` | MEDIUM |
| 连击/万剑归宗 | `combo-myriad-swords.md` | 三式剑招系统, 命中判定层 | GDScript (纯逻辑) | LOW |
| 竞技场波次系统 | `arena-wave-system.md` | 敌人系统, 游戏状态管理 | GDScript (纯逻辑) | LOW |
| 关卡/场景管理 | `level-scene-manager.md` | 游戏状态管理, 着色器/渲染 | `PackedScene`, `change_scene_to_packed()` | LOW |

### Presentation Layer (依赖 Feature)

| Module | GDD | Depends On |
|--------|-----|------------|
| 命中反馈 | `hit-feedback.md` | 命中判定层, 流光轨迹, 摄像机系统 |
| HUD/UI | `hud-ui-system.md` | 连击/万剑归宗, 敌人系统, 游戏状态管理, 摄像机系统 |

### Polish Layer (依赖 Feature + Presentation)

| Module | GDD | Depends On |
|--------|-----|------------|
| 计分系统 | `scoring-system.md` | 连击/万剑归宗, 竞技场波次, 游戏状态管理 |
| 纯技巧进度 | `skill-progression.md` | 连击/万剑归宗, 竞技场波次 |

---

## Module Ownership

### Foundation Layer Ownership

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 输入系统 | 输入状态（当前按下/释放）、输入缓冲区 | `is_action_pressed()`, `is_action_just_pressed()`, `get_move_direction()`, `get_buffered_action()` | Godot `Input` 类, `_input()` 回调 |
| 着色器/渲染 | 材质库（共享材质实例）、着色器参数 | `get_material()`, `create_trail_material()`, `set_character_highlight()` | Godot `Shader`, `Material`, `RenderingServer` |
| 音频系统 | 音频总线状态、播放实例 | `play_sfx()`, `play_bgm()`, `set_bus_volume()` | Godot `AudioServer`, `AudioStreamPlayer` |
| 游戏状态管理 | 当前游戏状态（State enum）、暂停状态 | `change_state()`, `get_current_state()`, `state_changed` 信号 | Godot `signal` 机制 |

### Core Layer Ownership

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 玩家控制器 | 玩家位置/速度/生命值/无敌状态 | `get_position()`, `get_health()`, `take_damage()`, `is_invincible()` | 输入系统 API, Godot `CharacterBody3D` |
| 物理碰撞层 | 碰撞体列表、hitbox 注册表 | `create_hitbox()`, `destroy_hitbox()`, `raycast()`, `shape_cast()` | 玩家控制器位置, Godot `Area3D`, Jolt 物理 |
| 命中判定层 | 命中去重表、最近 HitResult | `process_collision()`, `get_last_hit()`, `hit_landed` 信号 | 物理碰撞层碰撞结果 |
| 三式剑招系统 | 当前剑式、剑招状态、hitbox ID | `execute_form()`, `get_active_form()`, `form_activated` 信号 | 输入系统, 物理碰撞层 API |
| 敌人系统 | 敌人节点列表、每个敌人的 AI 状态/生命值 | `spawn_enemy()`, `get_all_enemies()`, `enemy_died` 信号 | 命中判定层 `hit_landed`, 游戏状态管理信号 |

### Feature Layer Ownership

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 摄像机系统 | 摄像机位置/FOV/效果状态 | `get_camera_position()`, `trigger_effect()` | 玩家控制器 `get_position()` |
| 流光轨迹系统 | 活跃轨迹列表、轨迹点数据 | `create_trail()`, `update_trail()`, `finish_trail()` | 三式剑招系统信号, 着色器/渲染材质 |
| 连击/万剑归宗 | 连击计数、蓄力进度、冷却状态 | `get_combo_count()`, `trigger_myriad()`, `combo_changed` 信号 | 命中判定层 `hit_landed`, 三式剑招系统信号 |
| 竞技场波次 | 当前波次、波次定义数据 | `get_current_wave()`, `wave_completed` 信号 | 敌人系统 API, 游戏状态管理信号 |
| 关卡/场景管理 | 当前场景引用、场景加载状态 | `change_scene()`, `reset_scene()`, `get_spawn_points()` | 游戏状态管理信号, PackedScene 资源 |

### Presentation Layer Ownership

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 命中反馈 | 材质反应节点池、顿帧/震动状态 | `trigger_hit_feedback()`, `trigger_myriad_feedback()` | 命中判定层 `hit_landed`, 摄像机系统, 音频系统 |
| HUD/UI | HUD 节点树、菜单栈、显示状态 | `show_hud()`, `show_menu()`, `update_health_display()` | 各游戏系统数据 API |

---

## Data Flow

### 1. Frame Update Path（每帧更新路径）

```
Input System (_process)
  → Player Controller (读取移动输入, 更新位置)
    → Physics Collision (更新 hurtbox 位置)
      → Three Forms Combat (读取剑招输入, 创建 hitbox)
        → Physics Collision (hitbox 碰撞检测)
          → Hit Judgment (判定碰撞, 输出 HitResult)
            → Hit Feedback (触发顿帧/材质反应/音效)
            → Combo/Myriad (更新连击计数)
            → Enemy System (敌人受伤/死亡)
              → Arena Wave (检查波次完成)
                → Game State Manager (波次完成 → INTERMISSION)

Camera System (_process)
  → 跟随 Player Controller 位置

Light Trail System (_process)
  → 更新活跃轨迹点
  → 淡出过期轨迹

HUD/UI (_process)
  → 从各系统读取数据, 更新显示
```

### 2. Signal/Event Path（信号/事件路径）

```
Game State Manager
  → state_changed(old, new) → 广播到所有系统

Player Controller
  → player_died() → Game State Manager, HUD, Audio
  → health_changed() → HUD

Three Forms Combat
  → form_activated(form) → Light Trail, Combo, Audio
  → form_finished(form) → Light Trail, Hit Feedback

Hit Judgment
  → hit_landed(HitResult) → Combo/Myriad, Hit Feedback, Enemy, HUD

Combo/Myriad Swords
  → combo_changed(count) → HUD
  → myriad_triggered() → Light Trail, Camera, Audio, Hit Feedback

Enemy System
  → enemy_died() → Arena Wave, Combo, Scoring

Arena Wave System
  → wave_completed() → Game State Manager, Scoring
```

### 3. Save/Load Path（存档路径）

**持久化数据极少**（纯技巧无属性成长）：
- 计分系统：最佳记录（最高波次、最长连击、万剑归宗次数）
- 纯技巧进度：最近 10 局的操作指标趋势
- 存储方式：Web 平台使用 `FileAccess` 写入用户目录（或 `LocalStorage` 通过 JavaScript 桥接）
- 所有权：计分系统负责序列化/反序列化

### 4. Initialisation Order（初始化顺序）

```
1. Game State Manager (状态机就绪)
2. Input System (输入映射加载)
3. Shader/Rendering (着色器编译, 材质预加载)
4. Audio System (音频资源预加载, AudioContext 初始化)
5. Player Controller (场景实例化)
6. Camera System (绑定跟随目标)
7. Physics Collision (碰撞层配置)
8. All other systems (按依赖顺序初始化)
```

---

## API Boundaries

### Foundation → Core 接口契约

**输入系统 → 玩家控制器/三式剑招系统：**
```gdscript
# 查询接口 — 纯函数, 无副作用
func is_action_pressed(action: StringName) -> bool
func is_action_just_pressed(action: StringName) -> bool
func get_move_direction() -> Vector2  # 归一化, 无输入时返回 ZERO
func get_buffered_action() -> StringName  # 无缓冲时返回 &""

# 不变量: 每帧 (_process 开始时) 更新一次状态
# 不变量: 返回值在同一帧内一致
```

**游戏状态管理 → 所有系统：**
```gdscript
# 信号广播 — 同帧内所有监听器收到
signal state_changed(old_state: State, new_state: State)

# 查询接口
func get_current_state() -> State
func is_paused() -> bool

# 不变量: 任何时刻只有一个活跃状态
# 不变量: state_changed 在状态切换完成后同一帧内发出
```

### Core → Core 接口契约

**物理碰撞层 → 命中判定层：**
```gdscript
# 碰撞结果数据
class CollisionResult:
    var hitbox_id: int
    var target: Node3D
    var position: Vector3
    var normal: Vector3

# 查询接口
func get_hitbox_collisions(hitbox_id: int) -> Array[CollisionResult]

# 信号
signal collision_detected(result: CollisionResult)

# 不变量: hitbox 激活期间每物理帧检测一次
# 不变量: 碰撞位置在世界坐标系中
```

**命中判定层 → 下游系统：**
```gdscript
# 命中结果数据
class HitResult:
    var attacker: Node3D
    var target: Node3D
    var sword_form: StringName  # &"you" / &"zuan" / &"rao" / &"none"
    var damage: int
    var hit_position: Vector3
    var hit_normal: Vector3
    var material_type: StringName  # &"metal" / &"wood" / &"ink" / &"body"

# 信号
signal hit_landed(result: HitResult)

# 不变量: 每次有效命中只触发一次 hit_landed
# 不变量: 无敌状态下的碰撞不输出 HitResult
```

### Core → Feature 接口契约

**三式剑招系统 → 流光轨迹/连击系统：**
```gdscript
# 查询接口
func get_active_form() -> StringName  # 当前剑式, 无则 &"none"
func is_executing() -> bool

# 信号
signal form_activated(form: StringName)
signal form_finished(form: StringName)

# 不变量: form_activated 在 hitbox 创建之前发出
# 不变量: form_finished 在 hitbox 销毁之后发出
```

---

## Architecture Principles

### 1. 信号驱动耦合（Signal-Driven Coupling）
所有跨系统通信通过 Godot 的 `signal` 机制——不使用直接方法调用跨层边界。发送方不关心谁在监听，接收方不关心谁在发送。

### 2. 查询优于命令（Query over Command）
系统之间的数据获取使用查询接口（`get_*()`）而非命令接口（`set_*()`）。每个系统自己决定何时读取数据，不被其他系统推着走。

### 3. 单一数据所有权（Single Data Ownership）
每个数据项只有一个系统拥有写入权。其他系统只能读取。如果两个系统都需要修改同一数据，需要重新划分所有权。

### 4. Web 性能优先（Web Performance First）
所有技术决策必须在 Web 性能预算内成立（draw call < 50, 三角面 < 10K, 帧时间 < 16.6ms）。如果设计与性能冲突，性能优先。

### 5. 引擎 API 隔离（Engine API Isolation）
只有 Foundation 层直接调用引擎 API。Core 层及以上的系统通过 Foundation 层的抽象接口访问引擎功能。这确保引擎升级或平台切换时只影响 Foundation 层。

---

## Required ADRs — All Accepted

> 所有 18 个 ADR 已于 2026-04-21 全部 Accepted。详见 ADR Audit。

### Foundation Layer（全部 Accepted）

| ADR | 覆盖需求 | 文件 |
|-----|---------|------|
| ADR-0001 场景管理与状态流转架构 | TR-GSM-001 | adr-0001-game-state-architecture.md |
| ADR-0002 输入系统架构与 Web 适配 | TR-INPUT-001, TR-INPUT-002 | adr-0002-input-system-architecture.md |
| ADR-0003 渲染管线与着色器架构 | TR-SHADER-001, TR-SHADER-002 | adr-0003-rendering-pipeline-architecture.md |
| ADR-0004 音频系统架构 | TR-AUDIO-001 | adr-0004-audio-system-architecture.md |

### Core Layer（全部 Accepted）

| ADR | 覆盖需求 | 文件 |
|-----|---------|------|
| ADR-0005 物理碰撞架构与 Web 性能 | TR-PHYSICS-001, TR-PHYSICS-002 | adr-0005-physics-collision-architecture.md |
| ADR-0006 三式剑招系统架构 | TR-COMBAT-001 | adr-0006-three-forms-combat-architecture.md |
| ADR-0007 敌人 AI 架构 | TR-ENEMY-001 | adr-0007-enemy-ai-architecture.md |
| ADR-0010 玩家控制器架构 | TR-PLAYER-001 | adr-0010-player-controller-architecture.md |
| ADR-0011 命中判定架构 | TR-HIT-001 | adr-0011-hit-judgment-architecture.md |
| ADR-0016 关卡场景管理器架构 | TR-LEVEL-001 | adr-0016-level-scene-manager-architecture.md |

### Feature Layer（全部 Accepted）

| ADR | 覆盖需求 | 文件 |
|-----|---------|------|
| ADR-0008 流光轨迹渲染架构 | TR-TRAIL-001 | adr-0008-light-trail-rendering-architecture.md |
| ADR-0009 连击系统架构 | TR-COMBO-001 | adr-0009-combo-system-architecture.md |
| ADR-0012 相机系统架构 | TR-CAM-001 | adr-0012-camera-system-architecture.md |
| ADR-0014 竞技场波次架构 | TR-WAVE-001 | adr-0014-arena-wave-architecture.md |

### Presentation Layer（全部 Accepted）

| ADR | 覆盖需求 | 文件 |
|-----|---------|------|
| ADR-0013 命中反馈架构 | TR-FEEDBACK-001 | adr-0013-hit-feedback-architecture.md |
| ADR-0015 HUD/UI 架构 | TR-HUD-001 | adr-0015-hud-ui-architecture.md |

### Meta 层（全部 Accepted）

| ADR | 覆盖需求 | 文件 |
|-----|---------|------|
| ADR-0017 计分系统架构 | TR-SCR-001 | adr-0017-scoring-system-architecture.md |
| ADR-0018 技能进阶架构 | TR-SKL-001 | adr-0018-skill-progression-architecture.md |

---

## ADR Audit

**审计日期：** 2026-04-21
**状态：** 全部 18 个 ADR 已 Accepted
**已解决冲突：** 4 个（详见下方）

### ADR 状态总览

| ADR | Title | Layer | Status | Engine Compat | GDD Linkage |
|-----|-------|-------|--------|---------------|-------------|
| ADR-0001 | 场景管理与状态流转架构 | Foundation | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0002 | 输入系统架构与 Web 适配 | Foundation | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0003 | 渲染管线与着色器架构 | Foundation | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0004 | 音频系统架构 | Foundation | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0005 | 物理碰撞架构与 Web 性能 | Core | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0006 | 三式剑招系统架构 | Core | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0007 | 敌人 AI 架构 | Core | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0008 | 流光轨迹渲染架构 | Feature | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0009 | 连击系统架构 | Feature | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0010 | 玩家控制器架构 | Core | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0011 | 命中判定架构 | Core | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0012 | 相机系统架构 | Feature | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0013 | 命中反馈架构 | Presentation | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0014 | 竞技场波次架构 | Feature | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0015 | HUD/UI 架构 | Presentation | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0016 | 关卡场景管理器架构 | Core | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0017 | 计分系统架构 | Meta | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |
| ADR-0018 | 技能进阶架构 | Meta | ✅ Accepted | ✅ Godot 4.6.2 | ✅ |

### 已解决的跨 ADR 冲突

#### 冲突 1: ADR-0005 vs ADR-0008 — hitbox 上限（MEDIUM）
- **问题**: ADR-0005 限制同屏 ≤ 18 hitbox，但万剑归宗的 50 条轨迹需要碰撞检测
- **解决**: 万剑归宗使用单一 Area3D 范围检测，不为每条轨迹创建独立 hitbox
- **影响文件**: ADR-0005 (Conflict Resolutions section added)

#### 冲突 2: ADR-0003 vs ADR-0008 — 材质池上限（MEDIUM）
- **问题**: ADR-0003 限制共享材质池 ≤ 15 个材质实例，50 条轨迹可能需要 50 个材质
- **解决**: 按剑式类型共 3 种材质（游剑式/钻剑式/绕剑式各 1 个），50 条轨迹共享。ADR-0008 必须通过 ADR-0003 的 `create_trail_material()` 创建轨迹材质
- **影响文件**: ADR-0003 (Conflict Resolutions section added)

#### 冲突 3: ADR-0005 vs ADR-0006 — hitbox 生命周期接口（LOW）
- **问题**: ADR-0006 描述"创建/销毁"而 ADR-0005 使用池化复用
- **解决**: ADR-0006 调用 ADR-0005 的 `create_hitbox()`/`destroy_hitbox()` API，池化内部管理复用，对外表现为创建/销毁语义
- **影响文件**: ADR-0005 (Conflict Resolutions section added)

#### 冲突 4: ADR-0001 vs ADR-0007 — COMBAT 状态权威（WEAK）
- **问题**: ADR-0007 隐含了对 COMBAT 状态的控制（"非 COMBAT 状态时 AI 停止更新"）
- **解决**: 状态权威始终在 ADR-0001 的 `GameStateManager`。ADR-0007 在 `_ready()` 中查询初始状态，之后通过 `state_changed` 信号响应变化，不调用 `change_state()`
- **影响文件**: ADR-0001 (Conflict Resolutions section added)

### 依赖拓扑排序

```
Level 0 (Foundation, 无依赖): ADR-0001, ADR-0003
Level 1 (依赖 Foundation):    ADR-0002, ADR-0004, ADR-0005, ADR-0016
Level 2 (依赖 Level 1):       ADR-0006, ADR-0007, ADR-0010
Level 3 (依赖 Level 2):       ADR-0008, ADR-0009, ADR-0011, ADR-0012, ADR-0014
Level 4 (依赖 Level 3):       ADR-0013, ADR-0015, ADR-0017
Level 5 (依赖 Level 4):       ADR-0018
```

---

## Open Questions

1. **Jolt 物理在 Web 端的实际性能**：需要在原型阶段用 Benchmark 验证。如果性能不达标，需要降级到 Godot 内置物理或简化碰撞检测。
2. **WebGL 2.0 下的着色器兼容性**：水墨着色器的 toon ramp 和 rim light 在 WebGL 2.0 下是否正常工作？需要制作着色器原型测试。
3. **万剑归宗的批量渲染策略**：50 条 LineRenderer 是否能在 1 个 draw call 内完成？Godot 4.6 的 `MultiMeshInstance3D` 可能是更好的选择。
4. **Web 平台的场景加载性能**：2 个区域的 PackedScene 预加载是否会导致启动时间过长？
5. **输入缓冲的 Web 端精度**：`_input()` 在各浏览器中的实际延迟差异需要测试。
