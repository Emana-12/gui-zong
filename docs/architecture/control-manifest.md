# Control Manifest

> **Engine**: Godot 4.6.2 stable, GDScript
> **Platform**: Web (HTML5), Full 3D Simplified
> **Last Updated**: 2026-04-22
> **Manifest Version**: 2026-04-22
> **ADRs Covered**: ADR-0001 ~ ADR-0018 (all Accepted)
> **Status**: Active

此清单是程序员的快速参考，从所有 ADR、技术偏好和引擎参考文档中提取。每条规则的推理过程见引用的 ADR。

---

## Foundation Layer Rules

*适用于：游戏状态管理、输入系统、着色器/渲染、音频系统*

### Required Patterns

- **游戏状态使用 Autoload 单例 + GDScript 枚举 + Godot signal** — 状态变化通过 `state_changed(old, new)` 信号广播 — source: ADR-0001
- **状态转换必须通过 `change_state(new_state)` 方法** — 验证转换合法性后执行 — source: ADR-0001
- **全局暂停使用 `get_tree().paused`** — 独立于状态机 — source: ADR-0001
- **输入捕获使用 `_input()` 而非 `_process()`** — 减少 Web 端 1 帧延迟 — source: ADR-0002
- **输入缓冲区容量 = 1** — 只保留最近的一个缓冲输入 — source: ADR-0002
- **所有着色器使用 Godot Shader Language (.gdshader)** — 不使用 GDExtension — source: ADR-0003
- **材质通过共享池管理** — 同着色器同参数 = 同材质实例，减少 draw call — source: ADR-0003
- **后处理 pass ≤ 2 个** — 描边 + 色调调整 — source: ADR-0003
- **音频使用 3 条总线**：Master → SFX + BGM — source: ADR-0004
- **音效预加载**（< 30 文件，< 2MB），BGM 流式加载 — source: ADR-0004

### Forbidden Approaches

- **Never 使用 `_process()` 读取输入** — 会在 Web 端增加 1 帧延迟 — source: ADR-0002
- **Never 使用多元素输入缓冲队列** — 会导致无脑按键产生不可控连招 — source: ADR-0002
- **Never 使用 VisualShader 代替手写 .gdshader** — WebGL 兼容性不可控 — source: ADR-0003
- **Never 使用 PBR 材质 + 后处理水墨滤镜** — 违反"极简即美学"支柱 — source: ADR-0003
- **Never 直接修改其他系统的状态** — 必须通过信号或查询接口 — source: ADR-0001

### Performance Guardrails

- **着色器/渲染**: draw call ≤ 50/帧，后处理 ≤ 2 pass，材质实例 ≤ 15 — source: ADR-0003
- **音频**: 音效库 < 30 文件，< 2MB — source: ADR-0004
- **自动降级**: fps < 30 → 关闭后处理；fps < 20 → `ink_steps = 2` — source: ADR-0003

---

## Core Layer Rules

*适用于：玩家控制器、摄像机系统、物理碰撞层、命中判定层、三式剑招系统、敌人系统*

### Required Patterns

- **物理碰撞使用 Area3D + CollisionShape3D** — 不产生物理响应，只检测重叠 — source: ADR-0005
- **碰撞层使用 6 层矩阵**：Player / Enemy / PlayerAttack / EnemyAttack / Environment / Interactable — source: ADR-0005
- **hitbox 使用池化复用** — 预创建实例，运行时激活/停用 — source: ADR-0005
- **三式剑招使用 GDScript 枚举 + 4 态状态机**：IDLE → EXECUTING → RECOVERING → COOLDOWN — source: ADR-0006
- **三键独立**：J/K/L 各自触发对应剑式，按下即切换（打断 RECOVERING，不打断 EXECUTING）— source: ADR-0006
- **冷却独立**：每式有独立冷却计时器，不同式不受彼此冷却影响 — source: ADR-0006
- **敌人 AI 使用简单状态机**：IDLE → APPROACH → ATTACK → RECOVER → HIT_STUN → DEAD — source: ADR-0007
- **敌人参数化**：5 种敌人通过参数（感知范围/攻击范围/移动速度/攻击频率）区分 — source: ADR-0007
- **玩家控制器使用 CharacterBody3D + 6 态状态机**：IDLE / MOVING / DODGING / DODGE_COOLDOWN / HIT_STUN / DEAD — source: ADR-0010
- **移动速度恒定 5.0m/s**，闪避 15.0m/s 持续 0.2s，无加速度曲线 — source: ADR-0010
- **玩家 HP = 3**，受击触发 0.5s HIT_STUN + 0.65s 无敌帧 — source: ADR-0010
- **自动面朝最近敌人** — 每帧 `distance_squared_to` 扫描 + `look_at`，无插值 — source: ADR-0010
- **玩家只通过 `InputSystem` 消费输入** — 禁止直接读取 `Input` 单例 — source: ADR-0010
- **命中判定使用 4 步过滤管线**：无敌检查 → 自伤检查 → 去重检查 → 伤害计算 — source: ADR-0011
- **HitResult 数据结构**：attacker / target / sword_form / damage / hit_position / hit_normal / material_type — source: ADR-0011
- **伤害表**：游=1，钻=3，绕=2，敌人=1 — source: ADR-0011
- **命中去重使用 hitbox 内 Dictionary** — `target_id → bool`，hitbox 回池时清空 — source: ADR-0011
- **材质类型通过节点组检测**：enemies/player → body，environment_metal → metal，environment_wood → wood，environment_ink → ink — source: ADR-0011
- **摄像机使用 Camera3D + 固定 45° 俯角** — 高度 6.0m，距离 8.0m，lerp 跟随因子 5.0 — source: ADR-0012
- **摄像机不是 Autoload** — 作为场景节点通过 group 或注入引用访问 — source: ADR-0012
- **摄像机效果使用优先级栈**：Hit Stop (最高) > FOV Zoom > Shake (可叠加) — source: ADR-0012
- **顿帧通过 `Engine.time_scale = 0` 实现** — 冻结所有游戏逻辑 N 帧 — source: ADR-0012
- **摄像机按游戏状态切换行为**：TITLE=轨道旋转，COMBAT=跟随，INTERMISSION=后拉，DEATH=冻结，RESTART=瞬移 — source: ADR-0012

### Forbidden Approaches

- **Never 使用行为树管理敌人 AI** — 5 种敌人各有固定行为模式，状态机足够 — source: ADR-0007
- **Never 允许 EXECUTING 状态被打断** — 必须等执行完毕才能切换剑式 — source: ADR-0006
- **Never 频繁创建/销毁 hitbox 节点** — 必须使用池化复用 — source: ADR-0005
- **Never 使用 RigidBody3D 或自定义物理集成** — 只用 CharacterBody3D — source: ADR-0010
- **Never 直接读取 `Input` 单例** — 必须通过 InputSystem Autoload — source: ADR-0010
- **Never 使用 AnimationTree 驱动玩家状态机** — 状态纯逻辑，无需动画资产耦合 — source: ADR-0010
- **Never 将 HitJudgment 设为组件模式** — 伤害计算规则必须集中，防止不一致 — source: ADR-0011
- **Never 使用 Resource 子类做 HitResult** — 每帧临时数据无需序列化开销 — source: ADR-0011
- **Never 将 CameraController 设为 Autoload** — 超过 3 单例限制，摄像机是场景节点 — source: ADR-0012
- **Never 使用 SpringArm3D 做摄像机碰撞** — 竞技场无头顶几何体，属于过度工程 — source: ADR-0012
- **Never 使用 RemoteTransform3D 做跟随** — 不支持 XZ-only 和 Y 固定需求 — source: ADR-0012

### Performance Guardrails

- **物理碰撞**: 物理帧时间 < 4ms（60fps 下 < 24% 帧预算）— source: ADR-0005
- **同屏 hitbox**: ≤ 18 个 — source: ADR-0005
- **Web 降级**: Jolt 不达标 → Godot 内置物理 → 减少 hitbox → 纯射线检测 — source: ADR-0005
- **玩家控制器**: 状态机 + move_and_slide + 敌人扫描 ≈ 0.1ms/帧 — source: ADR-0010
- **命中判定**: 4 步管线 ≈ 0.01ms/碰撞，最大 36 次检查/帧 ≈ 0.36ms — source: ADR-0011
- **摄像机**: lerp + look_at ≈ 0.02ms/帧 — source: ADR-0012
- **闪避穿墙防护**: Jolt 高速碰撞需测试 15m/s 闪避是否穿透薄碰撞体 — source: ADR-0010

---

## Feature Layer Rules

*适用于：流光轨迹系统、连击/万剑归宗系统、竞技场波次系统、关卡/场景管理*

### Required Patterns

- **流光轨迹使用 MeshInstance3D + ImmediateMesh** — 动态生成顶点代替 LineRenderer — source: ADR-0008
- **万剑归宗轨迹共享同一材质** — 50 条轨迹 = 1 个 draw call — source: ADR-0008
- **轨迹池化**：预创建 50 个 MeshInstance3D 节点 — source: ADR-0008
- **连击系统纯逻辑**：不同剑式连续命中才 +1，同式不增加但不断连 — source: ADR-0009
- **万剑归宗蓄力阈值 = 10 连击，自动触发 = 20 连击** — source: ADR-0009
- **波次使用公式生成**：`enemy_count = base_count + floor(wave_number * scaling_factor)` — source: ADR-0014
- **最大同屏敌人 = 10** — 超出时进入生成队列等待 — source: ADR-0014
- **敌人类型按波次解锁**：波1=流动型，波2=松韧型，波4=远程型，波6=重甲型，波8=敏捷型 — source: ADR-0014
- **敌人类型选择使用加权随机** — 权重通过 Dictionary 配置，便于调参 — source: ADR-0014
- **关卡场景管理使用预加载 PackedScene** — 2 个竞技场常驻内存，运行时实例化 — source: ADR-0016
- **场景切换使用 fade-to-black** — CanvasLayer 遮罩 0.3s 渐变，隐藏 queue_free 帧尖峰 — source: ADR-0016
- **生成点由场景内 Marker3D 节点提供** — SceneManager.get_spawn_points() 收集 — source: ADR-0016
- **旧场景实例通过 queue_free 释放** — PackedScene 常量保留在内存中 — source: ADR-0016

### Forbidden Approaches

- **Never 使用粒子系统生成流光轨迹** — 性能开销是 ImmediateMesh 的 10 倍 — source: ADR-0008
- **Never 允许运气触发万剑归宗** — 只能通过技巧（连击）触发 — source: ADR-0009
- **Never 将 WaveManager 设为 Autoload** — 波次管理是场景特定逻辑 — source: ADR-0014
- **Never 让敌人系统自行管理波次生成** — 生成节奏和难度缩放是独立关注点 — source: ADR-0014
- **Never 使用 Godot 内置 change_scene_to_packed()** — 会替换整个场景树，销毁 HUD/摄像机/系统引用 — source: ADR-0016
- **Never 将 SceneManager 设为 Autoload** — 超过 3 单例限制 — source: ADR-0016
- **Never 使用 ResourceLoader 多线程加载** — 2 个预加载场景无需异步，Web 端需 SharedArrayBuffer — source: ADR-0016

### Performance Guardrails

- **活跃轨迹**: ≤ 50 条 — source: ADR-0008
- **万剑归宗轨迹数**: 20 + combo_count × 2，上限 50 — source: ADR-0009
- **波次计算**: 公式 + 队列检查 ≈ 0.001ms/帧 — source: ADR-0014
- **场景切换**: queue_free + add_child ≈ 2-5ms（被 fade 遮罩隐藏）— source: ADR-0016
- **2 个 PackedScene 内存**: 约 10-30MB 总计 — source: ADR-0016

---

## Presentation Layer Rules

*适用于：命中反馈、HUD/UI*

### Required Patterns

- **顿帧由摄像机系统执行** — 全局暂停 2-3 帧 — source: ADR-0001 + ADR-0012
- **材质反应使用对象池** — 预创建 Sprite3D/Decal 实例，运行时激活/回收 — source: ADR-0013
- **材质反应池最大 draw call = 4/帧** — 金色火花(1) + 木裂纹(1) + 墨飞溅(1) + 冲击波(1) — source: ADR-0013
- **命中反馈分发表**：剑式 × 材质类型 → 顿帧帧数 + 震动 + 视觉效果 + 音效 — source: ADR-0013
- **顿帧期间命中反馈排队** — FIFO 执行，万剑归宗反馈可插队 — source: ADR-0013
- **万剑归宗反馈优先级最高** — 取消所有待执行普通反馈 — source: ADR-0013
- **HitFeedback 不是 Autoload** — 作为 Node3D 场景节点通过信号耦合 — source: ADR-0013
- **HUD 使用 CanvasLayer + Control 节点** — 2D UI 叠加在 3D 场景之上 — source: ADR-0015
- **HUD 数据来源使用信号订阅 + _ready() 初始化读取** — 防止场景加载时显示过期数据 — source: ADR-0015
- **HUD 3 秒无受击自动淡出至 30% alpha** — lerp 插值，受击立即恢复 — source: ADR-0015
- **菜单使用栈模式** — push/pop 语义，同一时间只显示一个菜单 — source: ADR-0015
- **HUD 响应式布局使用 Control 节点锚点 + viewport.size_changed** — source: ADR-0015
- **死亡画面文字用纯白**（非金墨）— 确保灰阶背景上的对比度 — source: ADR-0015

### Forbidden Approaches

- **Never 使用实时粒子系统做材质反应** — 使用对象池 Sprite3D/Decal — source: ADR-0013
- **Never 在万剑归宗时保持 HUD 全显** — HUD 淡出避免金色淹没 — source: ADR-0015
- **Never 将 HitFeedback 设为 Autoload** — 反馈是表现逻辑，应在场景树中 — source: ADR-0013
- **Never 让各系统自行管理自身反馈** — 反馈规则需要集中调参 — source: ADR-0013
- **Never 将 HUD 设为 Autoload** — 超过 3 单例限制，HUD 是场景节点 — source: ADR-0015
- **Never 让各系统自行渲染 UI** — 视觉一致性需要集中管理 — source: ADR-0015

### Performance Guardrails

- **材质反应池**: 5 金色火花 + 1 木裂纹 + 10 墨飞溅 + 1 冲击波，总 draw call ≤ 4/帧 — source: ADR-0013
- **HUD draw call**: 约 15-20（含菜单），与 3D 合计 < 50/帧 — source: ADR-0015
- **顿帧帧数**: 游=2，钻=3，绕=2，万剑归宗=5 — source: ADR-0013
- **震动强度**: 普通=±0.1m/0.1s，万剑归宗=±0.3m/0.3s — source: ADR-0013

---

## Global Rules (All Layers)

### Naming Conventions

| 元素 | 规范 | 示例 |
|------|------|------|
| Classes | PascalCase | `PlayerController` |
| Variables/Functions | snake_case | `move_speed`, `take_damage()` |
| Signals | snake_case past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### Performance Budgets

| 目标 | 值 |
|------|-----|
| 帧率 | 60fps |
| 帧预算 | 16.6ms |
| Draw calls | < 50/帧 |
| 内存 | Web 平台持续监控 |
| 场景三角面 | < 10K |
| 活跃敌人 | < 10 |
| 活跃粒子 | < 50 |
| 后处理 pass | < 2 |
| ZIP 包大小 | < 50MB (gzipped) |

### Approved Libraries / Addons

- [None — 所有功能用 GDScript + Godot 内置实现]

### Forbidden Patterns

- **禁止全局单例滥用** — 用依赖注入代替（游戏状态管理是唯一例外的 Autoload）
- **禁止硬编码游戏数值** — 必须数据驱动（Tuning Knobs）
- **禁止在 Web 导出中使用 GDExtension** — Web 端不支持

### Forbidden APIs (Godot 4.6.2)

- **`PhysicsServer3D` 直接调用** — 使用高层 Area3D/CollisionShape3D 代替
- **GDExtension (.gdextension)** — Web 端不支持，禁止使用
- **`change_scene_to_packed()`** — 替换整个场景树，使用 SceneManager 手动管理代替 — source: ADR-0016
- **`ResourceLoader.load_threaded_request()`** — 2 个预加载场景无需多线程，Web 端需 SharedArrayBuffer — source: ADR-0016
- **`JavaScriptBridge.eval()` 直接调用** — 仅限 ScoringSystem/SkillProgression 的 localStorage 回退路径，其他系统禁止使用 — source: ADR-0017, ADR-0018

### Cross-Cutting Constraints

- **所有系统只通过信号或查询接口通信** — 不使用直接方法调用跨层边界
- **每个数据项只有一个系统拥有写入权** — 其他系统只读
- **Web 性能是硬约束** — 如果设计与性能冲突，性能优先
- **引擎 API 只在 Foundation 层直接调用** — Core 层及以上通过 Foundation 抽象接口
- **Autoload 上限 = 3**：GameStateManager + InputSystem + HitJudgment — 其他系统使用场景节点 + group/injected reference — source: ADR-0010, ADR-0011, ADR-0012, ADR-0013, ADR-0014, ADR-0015, ADR-0016
- **Web 持久化使用 FileAccess + JSON** — 回退路径为 JavaScriptBridge.eval() localStorage — source: ADR-0017, ADR-0018
- **表现层系统（摄像机、HUD、命中反馈）必须是场景节点，不得为 Autoload** — source: ADR-0012, ADR-0013, ADR-0015
