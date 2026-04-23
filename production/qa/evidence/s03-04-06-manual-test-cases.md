# 手动 QA 测试用例：Sprint 03

**生成日期**: 2026-04-23
**Sprint**: Sprint 03 (Polish)
**覆盖故事**: S03-04 (敌人类型扩展), S03-06 (核心战斗音频素材)
**测试类型**: Playtest / Audio Playtest
**Gate Level**: ADVISORY (Visual/Feel stories — 需 designer sign-off)

---

## 第一部分：S03-04 敌人类型扩展 (Playtest)

### 测试前置条件（所有 S03-04 测试共用）

- Godot 4.6.2 项目已加载
- 测试场景包含：玩家节点 (PlayerController)、EnemySystem 节点、PhysicsCollisionSystem 节点、GameStateManager 节点
- 游戏状态设为 COMBAT
- 玩家 HP = 3，位置设为原点 (0, 0, 0)

---

### TC-ENEMY-001：松韧型生成与基础属性

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 在调试控制台调用 `EnemySystem.spawn_enemy("pine", Vector3(5, 0, 0))`
2. 观察松韧型敌人是否出现在 (5, 0, 0) 附近
3. 选中敌人节点，检查其 `max_hp` 属性
4. 观察敌人外观颜色是否为松绿色 (约 0.4, 0.55, 0.3)
5. 观察敌人是否自动朝向玩家方向

**Expected Result**:
- 敌人生成在 (5, 0, 0) 位置
- `max_hp` = 5
- 颜色为松绿色
- 敌人朝向玩家

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-002：重甲型生成与基础属性

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 在调试控制台调用 `EnemySystem.spawn_enemy("stone", Vector3(6, 0, 0))`
2. 观察重甲型敌人是否出现在 (6, 0, 0) 附近
3. 选中敌人节点，检查其 `max_hp` 属性
4. 观察敌人外观颜色是否为石灰色 (约 0.5, 0.5, 0.5)
5. 观察敌人是否自动朝向玩家方向

**Expected Result**:
- 敌人生成在 (6, 0, 0) 位置
- `max_hp` = 8
- 颜色为石灰色
- 敌人朝向玩家

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-003：流动型生成与基础属性

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 在调试控制台调用 `EnemySystem.spawn_enemy("water", Vector3(4, 0, 0))`
2. 观察流动型敌人是否出现在 (4, 0, 0) 附近
3. 选中敌人节点，检查其 `max_hp` 属性
4. 观察敌人外观颜色是否为水蓝色 (约 0.3, 0.5, 0.7)
5. 观察敌人是否自动朝向玩家方向

**Expected Result**:
- 敌人生成在 (4, 0, 0) 位置
- `max_hp` = 3
- 颜色为水蓝色
- 敌人朝向玩家

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-004：远程型生成与基础属性

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 在调试控制台调用 `EnemySystem.spawn_enemy("ranged", Vector3(12, 0, 0))`
2. 观察远程型敌人是否出现在 (12, 0, 0) 附近
3. 选中敌人节点，检查其 `max_hp` 属性
4. 观察敌人外观颜色是否为云白色 (约 0.7, 0.7, 0.8)
5. 等待 3 秒，观察敌人是否保持静止不移动

**Expected Result**:
- 敌人生成在 (12, 0, 0) 位置
- `max_hp` = 2
- 颜色为云白色
- 敌人不移动（speed = 0.0）

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-005：敏捷型生成与基础属性

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 在调试控制台调用 `EnemySystem.spawn_enemy("agile", Vector3(5, 0, 0))`
2. 观察敏捷型敌人是否出现在 (5, 0, 0) 附近
3. 选中敌人节点，检查其 `max_hp` 属性
4. 观察敌人外观颜色是否为竹青色 (约 0.5, 0.65, 0.4)
5. 观察敌人是否自动朝向玩家方向

**Expected Result**:
- 敌人生成在 (5, 0, 0) 位置
- `max_hp` = 4
- 颜色为竹青色
- 敌人朝向玩家

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-006：AI 状态机 — IDLE 转 APPROACH

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)，无其他敌人

**Steps**:
1. 调用 `EnemySystem.spawn_enemy("pine", Vector3(8, 0, 0))`（感知范围 = 10m）
2. 观察敌人初始状态是否为 IDLE（静止不动）
3. 缓慢向敌人方向移动，直到距离 < 10m
4. 观察敌人是否开始向玩家移动（进入 APPROACH 状态）

**Expected Result**:
- 生成后敌人处于 IDLE 状态，不动
- 玩家进入感知范围后，敌人切换到 APPROACH 状态，开始移动

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-007：AI 状态机 — APPROACH 转 ATTACK

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 调用 `EnemySystem.spawn_enemy("pine", Vector3(3, 0, 0))`（攻击范围 = 2m）
2. 等待敌人进入 APPROACH 状态并向玩家移动
3. 当敌人距离 < 2m 时，观察敌人是否进入 ATTACK 状态
4. 观察敌人是否有攻击动画/动作（0.3 秒）

**Expected Result**:
- 敌人进入攻击范围后切换到 ATTACK 状态
- 攻击动作持续约 0.3 秒

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-008：AI 状态机 — ATTACK 转 RECOVER 再转 APPROACH

**Precondition**: 敌人已在 ATTACK 状态

**Steps**:
1. 使用 TC-ENEMY-007 场景，等待敌人完成攻击动画（0.3 秒）
2. 观察敌人是否进入 RECOVER 状态（短暂停顿 0.2 秒）
3. 观察 RECOVER 结束后敌人是否回到 APPROACH 状态继续追击

**Expected Result**:
- ATTACK 结束后进入 RECOVER，停顿 0.2 秒
- RECOVER 结束后回到 APPROACH 继续追击玩家

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-009：AI 状态机 — 受击 HIT_STUN

**Precondition**: 游戏处于 COMBAT 状态，场上存在一个松韧型敌人 (HP=5)

**Steps**:
1. 操控玩家使用任意剑式攻击松韧型敌人
2. 观察敌人受击后是否立即停止行动
3. 观察敌人是否有约 0.3 秒的硬直停顿
4. 观察硬直结束后敌人是否恢复 APPROACH 追击

**Expected Result**:
- 受击后敌人立即停顿（HIT_STUN 状态）
- 硬直持续约 0.3 秒
- 硬直结束后恢复追击

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-010：AI 状态机 — 死亡 DEAD + 动画清理

**Precondition**: 游戏处于 COMBAT 状态，场上存在一个松韧型敌人 (HP=5)

**Steps**:
1. 调用 `EnemySystem.take_damage(enemy_id, 5)` 将敌人血量归零
2. 观察敌人是否进入 DEAD 状态
3. 观察敌人是否有缩小溶解动画（约 0.3 秒，缩放到 0.1 倍）
4. 等待动画结束，观察敌人节点是否被销毁（queue_free）
5. 调用 `EnemySystem.get_alive_count()` 确认计数减少

**Expected Result**:
- HP 归零后进入 DEAD 状态
- 播放缩小溶解动画（0.3 秒缩至 0.1 倍）
- 动画完成后节点被销毁
- `get_alive_count()` 返回值减 1

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-011：松韧型移动速度对比

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 同时生成松韧型 (speed=2.0) 和重甲型 (speed=1.0)，距离玩家均为 8m
2. 等待两个敌人都进入 APPROACH 状态
3. 观察两者同时移动时的速度差异
4. 松韧型应明显快于重甲型到达玩家位置

**Expected Result**:
- 松韧型到达玩家位置的时间约为重甲型的一半
- 速度差异可明显感知

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-012：流动型快速移动验证

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 生成流动型敌人在 (10, 0, 0)（speed=4.0，感知范围=12m）
2. 等待敌人进入 APPROACH 状态
3. 计时敌人从 10m 处到达玩家位置的时间
4. 与松韧型 (speed=2.0) 从相同距离到达的时间对比

**Expected Result**:
- 流动型到达时间应显著短于松韧型（约一半时间）
- 流动型移动视觉上明显更快

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-013：敏捷型高速移动验证

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 生成敏捷型敌人在 (8, 0, 0)（speed=5.0）
2. 等待敌人进入 APPROACH 状态
3. 观察其移动速度是否是所有类型中最快的
4. 对比流动型 (speed=4.0) 同时移动的速度

**Expected Result**:
- 敏捷型移动速度明显快于流动型
- 是所有 5 种类型中移动最快的

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-014：方向破绽 — 松韧型正面 + 钻剑式 = 2x 伤害

**Precondition**: 游戏处于 COMBAT 状态，松韧型敌人朝向玩家（玩家在其正面）

**Steps**:
1. 生成松韧型敌人在 (3, 0, 0)，等待其转向朝向玩家
2. 确认玩家位于敌人前方扇形区域内（±45°）
3. 使用钻剑式 (ZUAN) 攻击敌人正面
4. 观察敌人受到的伤害值（应为 3 × 2.0 = 6 点）
5. 对比使用游剑式 (YOU) 攻击同一位置的伤害（应为 1 点）

**Expected Result**:
- 钻剑式正面命中松韧型：伤害 = 6（基础 3 × 破绽 2.0）
- 游剑式正面命中松韧型：伤害 = 1（基础 1，无破绽加成）

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-015：方向破绽 — 重甲型上方 + 钻剑式 = 2x 伤害

**Precondition**: 游戏处于 COMBAT 状态，重甲型敌人位于 (3, 0, 0)

**Steps**:
1. 生成重甲型敌人
2. 将玩家移动到敌人上方位置（Y 差 > 0.5m），例如 (3, 1, 0)
3. 使用钻剑式 (ZUAN) 从上方攻击
4. 观察伤害值（应为 3 × 2.0 = 6 点）
5. 将玩家移动到敌人侧面相同距离，使用钻剑式攻击
6. 观察伤害值（应为 3 点，无破绽加成）

**Expected Result**:
- 上方 + 钻剑式：伤害 = 6
- 侧面 + 钻剑式：伤害 = 3（无破绽加成）

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-016：方向破绽 — 流动型侧面 + 游剑式 = 2x 伤害

**Precondition**: 游戏处于 COMBAT 状态，流动型敌人朝向玩家

**Steps**:
1. 生成流动型敌人在 (3, 0, 0)，等待其转向朝向玩家
2. 将玩家移动到敌人侧面（左或右），例如 (3, 0, 2)
3. 使用游剑式 (YOU) 从侧面攻击
4. 观察伤害值（应为 1 × 2.0 = 2 点）
5. 将玩家移动到敌人正面，使用游剑式攻击
6. 观察伤害值（应为 1 点，无破绽加成）

**Expected Result**:
- 侧面 + 游剑式：伤害 = 2
- 正面 + 游剑式：伤害 = 1

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-017：方向破绽 — 远程型正面 + 钻剑式 = 2x 伤害

**Precondition**: 游戏处于 COMBAT 状态，远程型敌人朝向玩家

**Steps**:
1. 生成远程型敌人在 (10, 0, 0)，等待其转向朝向玩家
2. 确认玩家位于敌人正面方向（远程型不移动，始终保持初始朝向）
3. 使用钻剑式 (ZUAN) 攻击敌人正面
4. 观察伤害值（应为 3 × 2.0 = 6 点）
5. 将玩家移动到敌人背后方向，使用钻剑式攻击
6. 观察伤害值（应为 3 点，无破绽加成）

**Expected Result**:
- 正面 + 钻剑式：伤害 = 6
- 背面 + 钻剑式：伤害 = 3

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-018：方向破绽 — 敏捷型背后 + 绕剑式 = 2x 伤害

**Precondition**: 游戏处于 COMBAT 状态，敏捷型敌人朝向玩家

**Steps**:
1. 生成敏捷型敌人在 (3, 0, 0)，等待其转向朝向玩家
2. 将玩家移动到敌人正后方（±45° 背面区域），例如 (-3, 0, 0)
3. 使用绕剑式 (RAO) 从背后攻击
4. 观察伤害值（应为 2 × 2.0 = 4 点）
5. 将玩家移动到敌人正面，使用绕剑式攻击
6. 观察伤害值（应为 2 点，无破绽加成）

**Expected Result**:
- 背面 + 绕剑式：伤害 = 4
- 正面 + 绕剑式：伤害 = 2

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-019：破绽 — 仅匹配方向不匹配剑式 = 正常伤害

**Precondition**: 游戏处于 COMBAT 状态，松韧型敌人朝向玩家

**Steps**:
1. 生成松韧型敌人，玩家位于其正面
2. 使用游剑式 (YOU) 攻击正面（方向匹配，但剑式不匹配克制剑式）
3. 观察伤害值（应为 1 点，无破绽加成）
4. 使用绕剑式 (RAO) 攻击正面（方向匹配，但剑式不匹配）
5. 观察伤害值（应为 2 点，无破绽加成）

**Expected Result**:
- 方向正确但剑式不匹配时：正常伤害，无破绽加成

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-020：破绽 — 仅匹配剑式不匹配方向 = 正常伤害

**Precondition**: 游戏处于 COMBAT 状态，松韧型敌人朝向玩家

**Steps**:
1. 生成松韧型敌人，玩家位于其正后方
2. 使用钻剑式 (ZUAN) 攻击后方（剑式匹配，但方向不匹配正面破绽）
3. 观察伤害值（应为 3 点，无破绽加成）

**Expected Result**:
- 剑式正确但方向不匹配时：正常伤害，无破绽加成

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-021：同帧击杀多个敌人 — 各自独立触发信号

**Precondition**: 游戏处于 COMBAT 状态

**Steps**:
1. 同时生成 3 个敌人：松韧型 (HP=5)、流动型 (HP=3)、远程型 (HP=2)
2. 将所有敌人聚集在玩家面前
3. 使用钻剑式 (ZUAN) 同时攻击全部 3 个敌人
4. 观察每个敌人是否各自独立触发 `enemy_died` 信号
5. 观察死亡动画是否各自独立播放
6. 调用 `get_alive_count()` 确认返回 0

**Expected Result**:
- 每个敌人独立触发死亡信号
- 各自独立播放死亡动画
- `get_alive_count()` = 0

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-022：重叠生成推离 — 生成位置与玩家重叠

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 调用 `EnemySystem.spawn_enemy("pine", Vector3(0.5, 0, 0))`（距离 < 2m 重叠阈值）
2. 观察敌人实际生成位置是否被推离到至少距玩家 2m 处
3. 调用 `EnemySystem.spawn_enemy("stone", Vector3(0, 0, 0))`（完全重叠）
4. 观察敌人是否被推离到至少 2m 处（任意方向）
5. 生成后两个敌人不应与玩家碰撞重叠

**Expected Result**:
- 距离 < 2m 的敌人被推离到 2m 处
- 完全重叠的敌人被推离到 2m 处（默认方向）
- 推离后敌人不与玩家穿模

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-023：DEATH 状态 AI 冻结

**Precondition**: 游戏处于 COMBAT 状态，松韧型敌人正在追击玩家

**Steps**:
1. 生成松韧型敌人，等待其进入 APPROACH 状态
2. 对敌人造成致死伤害（take_damage(5)）
3. 观察敌人进入 DEAD 状态后是否立即停止移动
4. 观察敌人 AI 是否不再执行任何逻辑（仅播放死亡动画）

**Expected Result**:
- DEAD 状态下敌人立即冻结，不再移动或攻击
- 仅播放死亡缩小动画

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-024：INTERMISSION 状态下敌人冻结

**Precondition**: 游戏处于 COMBAT 状态，场上有敌人正在追击

**Steps**:
1. 生成松韧型敌人，等待其进入 APPROACH 状态
2. 将游戏状态切换为 INTERMISSION
3. 观察所有敌人是否立即冻结（不移动、不攻击）
4. 将游戏状态切回 COMBAT
5. 观察敌人是否恢复 AI 行为

**Expected Result**:
- INTERMISSION 状态下敌人完全冻结
- 切回 COMBAT 后敌人恢复追击

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-025：敌人攻击伤害值验证

**Precondition**: 游戏处于 COMBAT 状态，玩家 HP = 3

**Steps**:
1. 生成松韧型敌人 (damage=1) 在玩家附近
2. 等待敌人完成一次攻击（ATTACK → RECOVER）
3. 观察玩家 HP 是否减少 1 点
4. 生成重甲型敌人 (damage=2)
5. 等待重甲型完成一次攻击
6. 观察玩家 HP 是否减少 2 点

**Expected Result**:
- 松韧型攻击造成 1 点伤害
- 重甲型攻击造成 2 点伤害

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-026：攻击冷却间隔差异化

**Precondition**: 游戏处于 COMBAT 状态

**Steps**:
1. 生成松韧型敌人 (cooldown=2.5s) 在攻击范围内
2. 观察其完成一次攻击后到下一次攻击的间隔时间
3. 生成流动型敌人 (cooldown=1.5s) 在攻击范围内
4. 观察其完成一次攻击后到下一次攻击的间隔时间
5. 对比两种敌人的攻击频率差异

**Expected Result**:
- 松韧型攻击间隔约 2.5 秒（含 ATTACK 0.3s + RECOVER 0.2s + cooldown 2.5s）
- 流动型攻击间隔约 1.5 秒，明显快于松韧型

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-027：远程型不移动行为

**Precondition**: 游戏处于 COMBAT 状态，玩家位于 (0, 0, 0)

**Steps**:
1. 生成远程型敌人在 (12, 0, 0)
2. 等待 10 秒，观察敌人位置是否改变
3. 缓慢向远程型敌人移动
4. 观察远程型在任何距离下是否都不移动

**Expected Result**:
- 远程型全程不移动（speed = 0.0）
- 在任何距离下都保持静止

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-028：远程型远程攻击（攻击范围 = 10m）

**Precondition**: 游戏处于 COMBAT 状态

**Steps**:
1. 生成远程型敌人在 (11, 0, 0)
2. 等待远程型进入 ATTACK 状态（感知范围 15m，攻击范围 10m）
3. 观察远程型在 10m 距离即可攻击玩家
4. 对比松韧型在相同距离下不会攻击（攻击范围只有 2m）

**Expected Result**:
- 远程型在 10m 距离内即可攻击
- 松韧型在 10m 距离下只会追击，不会攻击

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-029：5 种敌人同时在场

**Precondition**: 游戏处于 COMBAT 状态

**Steps**:
1. 依次生成 5 种敌人：pine、stone、water、ranged、agile
2. 等待所有敌人进入 APPROACH 状态
3. 调用 `get_alive_count()` 确认返回 5
4. 观察 5 种敌人的外观是否各有辨识度（不同颜色/形状）
5. 观察每种敌人的移动速度是否各不相同

**Expected Result**:
- 5 种敌人同时在场，`get_alive_count()` = 5
- 外观各有辨识度
- 移动速度有明显差异

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-ENEMY-030：kill_all 清除所有敌人

**Precondition**: 场上有 5 种敌人同时在场（TC-ENEMY-029 状态）

**Steps**:
1. 调用 `EnemySystem.kill_all()`
2. 观察所有敌人是否同时进入 DEAD 状态
3. 观察所有敌人的死亡动画是否正常播放
4. 等待动画结束，调用 `get_alive_count()` 确认返回 0

**Expected Result**:
- 所有敌人同时进入 DEAD 状态
- 各自播放死亡动画后销毁
- `get_alive_count()` = 0

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

## 第二部分：S03-06 核心战斗音频素材 (Audio Playtest)

### 测试前置条件（所有 S03-06 测试共用）

- Godot 4.6.2 项目已加载
- AudioManager 节点存在且 AudioContext 已初始化
- 音频资源已放置在 `assets/audio/sfx/` 和 `assets/audio/bgm/` 目录
- 系统音频设备正常（非静音状态）
- 音量设置：Master=1.0, SFX=1.0, BGM=1.0

---

### TC-AUDIO-001：游剑式命中音效辨识度（轻快感）

**Precondition**: 游戏处于 COMBAT 状态，场上有松韧型敌人

**Steps**:
1. 操控玩家使用游剑式 (YOU) 攻击敌人命中
2. 聆听命中音效
3. 使用游剑式命中不同类型材质（body、metal、wood、ink）
4. 对比每种材质的音效是否各有差异
5. 记录音效的主观感受：是否偏"轻快"风格

**Expected Result**:
- 游剑式命中时有清晰音效播放
- 不同材质有不同音色变体（body 肉感、metal 金属、wood 木感、ink 墨感）
- 整体音效风格偏轻快、灵动

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-002：钻剑式命中音效辨识度（厚重感）

**Precondition**: 游戏处于 COMBAT 状态，场上有松韧型敌人

**Steps**:
1. 操控玩家使用钻剑式 (ZUAN) 攻击敌人命中
2. 聆听命中音效
3. 使用钻剑式命中不同类型材质
4. 对比钻剑式与游剑式的音效差异
5. 记录音效的主观感受：是否偏"厚重"风格

**Expected Result**:
- 钻剑式命中时有清晰音效播放
- 与游剑式音效有明显区别
- 整体音效风格偏厚重、有力

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-003：绕剑式命中音效辨识度（柔和感）

**Precondition**: 游戏处于 COMBAT 状态，场上有松韧型敌人

**Steps**:
1. 操控玩家使用绕剑式 (RAO) 攻击敌人命中
2. 聆听命中音效
3. 使用绕剑式命中不同类型材质
4. 对比绕剑式与游剑式、钻剑式的音效差异
5. 记录音效的主观感受：是否偏"柔和"风格

**Expected Result**:
- 绕剑式命中时有清晰音效播放
- 与游剑式、钻剑式三者各有辨识度
- 整体音效风格偏柔和、环绕

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-004：三种剑式音效横向对比

**Precondition**: 游戏处于 COMBAT 状态，场上有敌人

**Steps**:
1. 依次使用游剑式、钻剑式、绕剑式攻击同一敌人
2. 每次攻击间隔 2 秒以上，确保音效不重叠
3. 记录三种音效的辨识度
4. 请第二人（未参与测试者）聆听后判断哪段是哪种剑式

**Expected Result**:
- 三种剑式音效风格明显不同：游=轻快、钻=厚重、绕=柔和
- 第二人能在无告知情况下正确区分至少 2/3 的剑式

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-005：万剑归宗触发音效高潮感

**Precondition**: 游戏处于 COMBAT 状态，连击数达到万剑归宗触发条件

**Steps**:
1. 积累连击至万剑归宗触发条件
2. 触发万剑归宗
3. 聆听触发音效
4. 记录音效是否有渐强到爆发的高潮感
5. 记录音效与顿帧（hitstop）的同步是否准确

**Expected Result**:
- 万剑归宗触发时有明显的渐强爆发音效
- 音效与画面顿帧同步
- 音效传达出"大招释放"的高潮感

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-006：BGM 循环无突兀断点

**Precondition**: 游戏处于 COMBAT 状态，BGM 正在播放

**Steps**:
1. 开始新游戏，等待 BGM 开始播放
2. 等待 BGM 完成至少 3 个完整循环周期（每个循环约 30-60 秒）
3. 专注聆听每次循环衔接点
4. 记录是否有明显断点、爆音、或静音间隔
5. 记录循环点是否自然流畅

**Expected Result**:
- BGM 循环衔接处无突兀断点
- 无爆音、卡顿、或静音间隔
- 循环听起来自然流畅

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-007：BGM Crossfade 切换

**Precondition**: 游戏正在播放 BGM

**Steps**:
1. 记录当前 BGM 曲目名称
2. 在调试控制台调用 AudioManager 的 `play_bgm("combat_loop")` 切换 BGM
3. 聆听 crossfade 过渡（约 1 秒时长）
4. 记录过渡是否平滑（旧曲淡出 + 新曲淡入同时进行）
5. 记录是否有爆音或突兀切换

**Expected Result**:
- crossfade 过渡平滑，时长约 1 秒
- 无爆音、卡顿
- 新旧 BGM 平滑交替

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-008：音量层级 — SFX 不遮盖 BGM

**Precondition**: 游戏处于 COMBAT 状态，BGM 和 SFX 均在播放

**Steps**:
1. 确保 Master=1.0, SFX=1.0, BGM=1.0
2. 连续快速攻击敌人（每秒 2-3 次），产生连续 SFX
3. 聆听 BGM 是否仍然可辨识
4. 记录 SFX 是否遮盖了 BGM 的旋律
5. 将 SFX 音量调低到 0.8，重复步骤 2-4

**Expected Result**:
- BGM 始终可辨识，即使在密集 SFX 播放时
- SFX 作为前景音效，BGM 作为背景音乐，层级分明

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-009：Web 端音频延迟检测

**Precondition**: 在浏览器中运行游戏（HTML5 导出版本）

**Steps**:
1. 打开 Web 导出的游戏（Chrome 浏览器）
2. 点击任意按钮/按键初始化 AudioContext
3. 执行第一次攻击
4. 记录从攻击动作开始到听到音效的延迟
5. 连续执行 10 次攻击，记录每次的延迟感受
6. 切换到 Firefox 重复步骤 3-5

**Expected Result**:
- 首次音频延迟 ≤ 100ms
- 后续攻击无明显延迟
- Chrome 和 Firefox 表现一致

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-010：Web 端音频卡顿检测

**Precondition**: 在浏览器中运行游戏

**Steps**:
1. 开始游戏，进入 COMBAT 状态
2. 生成 5 个敌人同时在场
3. 连续战斗 60 秒，持续攻击和闪避
4. 记录音频是否有卡顿、断续、或爆音
5. 特别关注在帧率下降时音频是否受影响
6. 在 Chrome 和 Firefox 各测试一次

**Expected Result**:
- 战斗全程音频流畅，无卡顿
- 帧率波动不会导致音频断裂
- 两浏览器表现一致

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-011：音频资源完整性检查

**Precondition**: AudioManager 已初始化

**Steps**:
1. 检查 `assets/audio/sfx/` 目录下的文件列表
2. 对照音频资源清单 (assets/audio/MANIFEST.md)，确认以下文件存在：
   - hit_you_metal.ogg, hit_you_wood.ogg, hit_you_body.ogg, hit_you_ink.ogg
   - hit_rao_metal.ogg, hit_rao_wood.ogg, hit_rao_body.ogg, hit_rao_ink.ogg
   - hit_zuan_metal.ogg, hit_zuan_wood.ogg, hit_zuan_body.ogg, hit_zuan_ink.ogg
   - hit_generic_body.ogg
   - myriad_trigger.ogg
3. 检查 `assets/audio/bgm/` 目录确认 `combat_loop.ogg` 存在
4. 检查总文件数量是否 < 30，总大小是否 < 2MB

**Expected Result**:
- 所有清单中列出的文件均存在
- 文件格式为 OGG
- 总文件数 < 30，总大小 < 2MB

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-012：SFX 实例数限制验证

**Precondition**: AudioManager 已初始化，AudioContext 已激活

**Steps**:
1. 快速连续使用游剑式攻击 10 次（每 0.1 秒一次）
2. 观察是否最多同时播放 3 个相同 SFX 实例（MAX_INSTANCES_PER_SFX = 3）
3. 同时触发不同剑式攻击，观察总 SFX 实例数是否不超过 8（MAX_TOTAL_SFX_INSTANCES = 8）
4. 记录音频是否有因限流导致的听感异常

**Expected Result**:
- 同一 SFX 最多同时 3 个实例
- 总 SFX 实例数最多 8 个
- 限流时音频仍正常，无异常杂音

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-013：破绽命中音效特殊反馈

**Precondition**: 游戏处于 COMBAT 状态，松韧型敌人朝向玩家

**Steps**:
1. 使用钻剑式 (ZUAN) 攻击松韧型正面（触发破绽，2x 伤害）
2. 聆听破绽命中与普通命中音效是否有区别
3. 如果破绽命中有特殊音效反馈，记录其特征
4. 如果没有特殊音效，记录是否建议添加

**Expected Result**:
- 破绽命中时有区别于普通命中的音效反馈
- 反馈音效应传达"弱点被击中"的成就感

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-014：音量调节功能验证

**Precondition**: AudioManager 已初始化

**Steps**:
1. 调用 `AudioManager.set_bus_volume("SFX", 0.5)` 将 SFX 音量设为 50%
2. 执行攻击，聆听 SFX 音量是否明显降低
3. 调用 `AudioManager.set_bus_volume("BGM", 0.3)` 将 BGM 音量设为 30%
4. 聆听 BGM 音量是否明显降低
5. 将两者恢复为 1.0
6. 调用 `AudioManager.set_bus_volume("Master", 0.0)` 静音
7. 确认所有音频静音
8. 恢复 Master = 1.0

**Expected Result**:
- 各总线音量调节生效，音量变化可感知
- 设为 0.0 时完全静音
- 恢复后音频正常

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

### TC-AUDIO-015：死亡音效反馈

**Precondition**: 游戏处于 COMBAT 状态，场上有松韧型敌人

**Steps**:
1. 使用剑式击杀松韧型敌人
2. 聆听敌人死亡时是否有音效（余音消散）
3. 使用不同剑式击杀不同类型的敌人
4. 记录死亡音效是否一致或有差异

**Expected Result**:
- 敌人死亡时有音效播放（余音消散效果）
- 死亡音效不刺耳，与水墨溶解视觉风格匹配

**Actual Result**: ____________________________

**Pass/Fail**: [ ]

---

## 测试用例汇总

| 编号 | 故事 | 类型 | 通过/失败 |
|------|------|------|----------|
| TC-ENEMY-001 | S03-04 | 松韧型生成 | [ ] |
| TC-ENEMY-002 | S03-04 | 重甲型生成 | [ ] |
| TC-ENEMY-003 | S03-04 | 流动型生成 | [ ] |
| TC-ENEMY-004 | S03-04 | 远程型生成 | [ ] |
| TC-ENEMY-005 | S03-04 | 敏捷型生成 | [ ] |
| TC-ENEMY-006 | S03-04 | IDLE→APPROACH | [ ] |
| TC-ENEMY-007 | S03-04 | APPROACH→ATTACK | [ ] |
| TC-ENEMY-008 | S03-04 | ATTACK→RECOVER→APPROACH | [ ] |
| TC-ENEMY-009 | S03-04 | HIT_STUN 硬直 | [ ] |
| TC-ENEMY-010 | S03-04 | DEAD + 死亡动画 | [ ] |
| TC-ENEMY-011 | S03-04 | 松韧/重甲速度对比 | [ ] |
| TC-ENEMY-012 | S03-04 | 流动型快速移动 | [ ] |
| TC-ENEMY-013 | S03-04 | 敏捷型高速移动 | [ ] |
| TC-ENEMY-014 | S03-04 | 松韧型正面破绽 | [ ] |
| TC-ENEMY-015 | S03-04 | 重甲型上方破绽 | [ ] |
| TC-ENEMY-016 | S03-04 | 流动型侧面破绽 | [ ] |
| TC-ENEMY-017 | S03-04 | 远程型正面破绽 | [ ] |
| TC-ENEMY-018 | S03-04 | 敏捷型背后破绽 | [ ] |
| TC-ENEMY-019 | S03-04 | 仅方向匹配无破绽 | [ ] |
| TC-ENEMY-020 | S03-04 | 仅剑式匹配无破绽 | [ ] |
| TC-ENEMY-021 | S03-04 | 同帧击杀多敌人 | [ ] |
| TC-ENEMY-022 | S03-04 | 重叠推离 | [ ] |
| TC-ENEMY-023 | S03-04 | DEATH AI 冻结 | [ ] |
| TC-ENEMY-024 | S03-04 | INTERMISSION AI 冻结 | [ ] |
| TC-ENEMY-025 | S03-04 | 攻击伤害值验证 | [ ] |
| TC-ENEMY-026 | S03-04 | 攻击冷却差异化 | [ ] |
| TC-ENEMY-027 | S03-04 | 远程型不移动 | [ ] |
| TC-ENEMY-028 | S03-04 | 远程型远距攻击 | [ ] |
| TC-ENEMY-029 | S03-04 | 5种敌人同场 | [ ] |
| TC-ENEMY-030 | S03-04 | kill_all | [ ] |
| TC-AUDIO-001 | S03-06 | 游剑式音效 | [ ] |
| TC-AUDIO-002 | S03-06 | 钻剑式音效 | [ ] |
| TC-AUDIO-003 | S03-06 | 绕剑式音效 | [ ] |
| TC-AUDIO-004 | S03-06 | 三式横向对比 | [ ] |
| TC-AUDIO-005 | S03-06 | 万剑归宗高潮感 | [ ] |
| TC-AUDIO-006 | S03-06 | BGM 循环无断点 | [ ] |
| TC-AUDIO-007 | S03-06 | BGM Crossfade | [ ] |
| TC-AUDIO-008 | S03-06 | 音量层级 | [ ] |
| TC-AUDIO-009 | S03-06 | Web 延迟 | [ ] |
| TC-AUDIO-010 | S03-06 | Web 卡顿 | [ ] |
| TC-AUDIO-011 | S03-06 | 资源完整性 | [ ] |
| TC-AUDIO-012 | S03-06 | SFX 实例限制 | [ ] |
| TC-AUDIO-013 | S03-06 | 破绽音效反馈 | [ ] |
| TC-AUDIO-014 | S03-06 | 音量调节功能 | [ ] |
| TC-AUDIO-015 | S03-06 | 死亡音效 | [ ] |

**总计**: 45 个测试用例 (S03-04: 30, S03-06: 15)

---

## 测试执行说明

### 环境要求

| 项目 | 要求 |
|------|------|
| 引擎 | Godot 4.6.2 stable |
| 平台 | Web (HTML5) + 桌面编辑器 |
| 浏览器 | Chrome, Firefox, Edge |
| 音频设备 | 外放或耳机（需判断立体声效果） |
| 测试人数 | 建议 2 人（一人操作 + 一人聆听记录） |

### 执行顺序建议

1. **第一轮**: 执行 TC-ENEMY-001 至 TC-ENEMY-013（生成 + 基础 AI + 移动速度）
2. **第二轮**: 执行 TC-ENEMY-014 至 TC-ENEMY-020（方向破绽系统）
3. **第三轮**: 执行 TC-ENEMY-021 至 TC-ENEMY-030（边缘情况 + 综合场景）
4. **第四轮**: 执行 TC-AUDIO-001 至 TC-AUDIO-015（音频专项）

### 阻断条件

- 如果 TC-ENEMY-001 至 TC-ENEMY-005 中 3 个以上失败，暂停后续敌人测试，优先报告生成系统问题
- 如果 TC-AUDIO-001 至 TC-AUDIO-003 全部无声效，暂停音频测试，检查资源加载
