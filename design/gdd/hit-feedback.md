# 命中反馈 (Hit Feedback)

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 精确即力量 (Pillar 1), 极简即美学 (Pillar 2)

## Overview

**命中反馈系统**是"打中了"的感官确认——顿帧、屏幕震动、材质反应（火花/裂纹/墨点炸碎）。它将命中判定层的逻辑结果转化为玩家的即时感官体验。没有命中反馈，精确打击就是"无声的精准"——有它，每一击都有"分量"。

**职责边界：**
- **做**：顿帧（命中瞬间暂停几帧）、屏幕震动（受击时）、材质反应视觉效果（金属火花、木杖裂纹、墨点炸碎）、命中音效触发
- **不做**：命中判定（命中判定层）、伤害应用（敌人/玩家控制器）、轨迹生成（流光轨迹系统）

## Player Fantasy

**玩家感到"打中了"——不是通过数字，而是通过身体感受。**

玩家感受到的是：
- 游剑式命中金属时——"叮"的一声 + 金色火花飞溅 + 2 帧顿帧
- 钻剑式穿透时——"砰"的一声 + 扇形冲击波扩散 + 短暂屏幕震动
- 绕剑式化解敌击时——墨点炸碎扩散 + "噗"的一声
- 受到敌人攻击时——屏幕轻微震动 + 墨色边缘侵蚀

**支柱对齐：**
- Pillar 1（精确即力量）：命中反馈是精确打击的"确认音"——玩家通过反馈知道自己确实打中了
- Pillar 2（极简即美学）：反馈不用华丽特效——用材质反应（水墨技法）代替数字特效

## Detailed Design

### Core Rules

1. 命中反馈系统监听命中判定层的 `hit_landed` 信号，对每个有效命中执行反馈流程
2. 反馈流程：顿帧 → 材质反应视觉 → 命中音效 → （可选）屏幕震动
3. 顿帧是全局暂停 2 帧（由摄像机系统执行），其他反馈由本系统负责
4. 材质反应根据被命中物体的材质类型和使用的剑式决定——金属冒火花、木杖裂细纹、墨点炸碎
5. 万剑归宗触发时，执行特殊反馈：全屏金色爆发 + 强烈震动 + 高潮音效

### Feedback Types

| 触发条件 | 顿帧 | 震动 | 材质反应 | 音效 |
|---------|------|------|---------|------|
| 游剑式命中金属 | 2 帧 | 无 | 金色火花飞溅（<5 Sprite3D） | 金属"叮" |
| 游剑式命中木材 | 2 帧 | 无 | 墨色细纹渗裂（Decal） | 木头"咔" |
| 游剑式命中墨体 | 2 帧 | 无 | 墨点泼溅（<10 Sprite3D） | 水墨"噗" |
| 钻剑式命中 | 3 帧 | 轻微 | 扇形冲击波（金白色扩散） | 闷响"砰" |
| 绕剑式化解敌击 | 2 帧 | 无 | 墨点炸碎（<10 Sprite3D） | 水墨"噗" |
| 万剑归宗触发 | 5 帧 | 强烈 | 全屏金色爆发 | 渐强爆发音 |
| 玩家受击 | 无 | 轻微水平抖动 | 屏幕边缘墨迹侵蚀 | 闷响 |

### Material Reaction Implementation

| 材质类型 | 视觉实现 | 性能考量 |
|---------|---------|---------|
| 金属火花 | < 5 个 Sprite3D，预设飞溅动画 | 1 个共享材质，1 个 draw call |
| 木杖裂纹 | Decal + 裂纹贴图 | 1 个 draw call |
| 墨点炸碎 | < 10 个 Sprite3D，预设扩散动画 | 1 个共享材质，1 个 draw call |
| 扇形冲击波 | 1 个 MeshInstance（扇形），缩放动画 | 1 个 draw call |

### Interactions with Other Systems

**对外发出的接口：**

| 接口 | 类型 | 说明 | 接收系统 |
|------|------|------|---------|
| `trigger_hit_stop(frames: int)` | 触发 | 触发顿帧 | 摄像机系统 |
| `trigger_shake(intensity: float, duration: float)` | 触发 | 触发屏幕震动 | 摄像机系统 |
| `spawn_material_reaction(type: String, pos: Vector3, normal: Vector3)` | 创建 | 生成材质反应视觉 | 本系统内部 |
| `play_hit_sfx(material: String, sword_form: String)` | 触发 | 播放命中音效 | 音频系统 |

**接收的外部触发：**

| 触发来源 | 事件 | 响应 |
|---------|------|------|
| 命中判定层 | `hit_landed` 信号 | 执行完整反馈流程 |
| 连击/万剑归宗 | `myriad_triggered` 信号 | 执行万剑归宗特殊反馈 |
| 玩家控制器 | `take_damage` 事件 | 执行受击反馈 |

### Public API

| 方法 | 签名 | 返回值 | 说明 |
|------|------|--------|------|
| `trigger_hit_feedback` | `trigger_hit_feedback(hit_result: HitResult)` | `void` | 执行完整命中反馈 |
| `trigger_myriad_feedback` | `trigger_myriad_feedback(combo_count: int)` | `void` | 执行万剑归宗特殊反馈 |
| `trigger_player_hit_feedback` | `trigger_player_hit_feedback()` | `void` | 执行玩家受击反馈 |

## Formulas

**顿帧时长与剑式伤害关联：**

`hit_stop_frames = base_hit_stop + floor(damage / 2)`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 基础顿帧 | `base_hit_stop` | int | 2 帧 | 最少顿帧数 |
| 伤害 | `damage` | int | 1–3 | 命中伤害 |

**输出：** 2–3 帧。钻剑式（3 伤害）= 3 帧，游剑式（1 伤害）= 2 帧。

## Edge Cases

- **如果顿帧期间有新的命中事件**：排队等待，顿帧结束后立即执行新反馈。
- **如果材质反应节点在动画中被销毁**：安全检查后跳过更新。
- **如果万剑归宗反馈与普通命中反馈同时发生**：万剑归宗优先级更高，普通反馈被取消。
- **如果帧率低于 30fps**：顿帧减少到 1 帧（避免过度卡顿感）。

## Dependencies

### 上游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 命中判定层 | 硬依赖 | `hit_landed` 信号 |
| 流光轨迹系统 | 软依赖 | 轨迹可视参考 |
| 摄像机系统 | 硬依赖 | `trigger_effect("hit_stop")`, `trigger_effect("shake")` |

### 下游依赖

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 音频系统 | 硬依赖 | `play_sfx()` — 命中音效 |

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 说明 |
|------|--------|---------|------|
| `hit_stop_frames` | 2 | 1–4 | 基础顿帧帧数 |
| `shake_intensity_hit` | 0.1m | 0.05–0.2m | 受击震动幅度 |
| `shake_duration_hit` | 0.1s | 0.05–0.2s | 受击震动时长 |
| `myriad_shake_intensity` | 0.3m | 0.1–0.5m | 万剑归宗震动幅度 |
| `myriad_hit_stop_frames` | 5 | 3–8 | 万剑归宗顿帧帧数 |
| `material_reaction_lifetime` | 0.5s | 0.3–1.0s | 材质反应视觉持续时间 |

## Visual/Audio Requirements

**本系统直接产生视觉/音频效果——命中反馈是"打击感"的核心。**

Art Bible 定义的材质反应：
- 金属碰撞：金墨飞溅（Section 1, Principle 2）
- 木杖碰撞：水墨渗裂（Section 1, Principle 2）
- 墨点炸碎：泼墨（Section 1, Principle 2）
- 扇形冲击波：金白色扩散（Section 4, Color System）

## UI Requirements

**无直接 UI。** 命中反馈是纯视觉/音频效果，不涉及 HUD 元素。

## Acceptance Criteria

- **GIVEN** 游剑式命中金属敌人，**WHEN** `trigger_hit_feedback` 被调用，**THEN** 2 帧顿帧 + 金色火花飞溅 + 金属"叮"音效
- **GIVEN** 钻剑式命中敌人，**WHEN** `trigger_hit_feedback` 被调用，**THEN** 3 帧顿帧 + 扇形冲击波 + 闷响"砰"音效
- **GIVEN** 绕剑式化解敌方攻击，**WHEN** `trigger_hit_feedback` 被调用，**THEN** 2 帧顿帧 + 墨点炸碎 + 水墨"噗"音效
- **GIVEN** 万剑归宗触发，**WHEN** `trigger_myriad_feedback` 被调用，**THEN** 5 帧顿帧 + 强烈震动 + 全屏金色爆发 + 渐强爆发音
- **GIVEN** 玩家受击，**WHEN** `trigger_player_hit_feedback` 被调用，**THEN** 轻微水平震动 + 屏幕边缘墨迹侵蚀
- **GIVEN** 材质反应持续 0.5 秒，**WHEN** 动画结束，**THEN** 节点自动销毁

## Open Questions

- 顿帧的实现方式：是全局暂停 `_process` 还是暂停特定节点？Godot 中全局暂停更简单但可能影响不需要暂停的系统（如音频）。
- 万剑归宗的"全屏金色爆发"具体实现：是全屏后处理色调变化还是大量 Sprite3D？前者性能更好但效果可能不够壮观。
- 材质反应的"预设动画"是用 AnimatedSprite3D 还是 Tween 控制？前者更可控但增加资产数量。