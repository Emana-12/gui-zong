# SPDX-License-Identifier: MIT
## S03-04 敌人类型扩展单元测试
##
## 测试 5 种敌人类型的独立属性、AI 行为和边缘情况。
## 使用公开 API (ENEMY_TYPE_DATA 常量 + is_alive/spawn_enemy/take_damage)。
##
## @see design/gdd/enemy-system.md
## @see production/sprints/sprint-03.md S03-04
extends GdUnitTestSuite

var _enemy_system: EnemySystem


func before_test() -> void:
	_enemy_system = auto_free(EnemySystem.new())
	# 设置玩家引用用于 AI 测试
	var player := auto_free(CharacterBody3D.new())
	player.position = Vector3.ZERO
	_enemy_system.set_player_ref(player)


func after_test() -> void:
	_enemy_system = null


## ── 松韧型 (pine) ────────────────────────────────────────────────────────

func test_pine_config_hp() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["pine"]["hp"]).is_equal(5)

func test_pine_config_speed() -> void:
	assert_float(EnemySystem.ENEMY_TYPE_DATA["pine"]["speed"]).is_equal(2.0)

func test_pine_config_cooldown() -> void:
	assert_float(EnemySystem.ENEMY_TYPE_DATA["pine"]["attack_cooldown"]).is_equal(2.5)

func test_pine_counter_form() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["pine"]["counter_form"]).is_equal(3)

func test_pine_spawn_alive() -> void:
	var id := _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	assert_int(id).is_greater_equal(0)
	assert_bool(_enemy_system.is_alive(id)).is_true()


## ── 重甲型 (stone) ───────────────────────────────────────────────────────

func test_stone_config_hp() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["stone"]["hp"]).is_equal(8)

func test_stone_config_speed() -> void:
	assert_float(EnemySystem.ENEMY_TYPE_DATA["stone"]["speed"]).is_equal(1.0)

func test_stone_config_damage() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["stone"]["attack_damage"]).is_equal(2)

func test_stone_config_cooldown() -> void:
	assert_float(EnemySystem.ENEMY_TYPE_DATA["stone"]["attack_cooldown"]).is_equal(4.0)

func test_stone_counter_form() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["stone"]["counter_form"]).is_equal(2)

func test_stone_spawn_alive() -> void:
	var id := _enemy_system.spawn_enemy("stone", Vector3(5, 0, 0))
	assert_bool(_enemy_system.is_alive(id)).is_true()


## ── 流动型 (water) ───────────────────────────────────────────────────────

func test_water_config_hp() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["water"]["hp"]).is_equal(3)

func test_water_config_speed() -> void:
	assert_float(EnemySystem.ENEMY_TYPE_DATA["water"]["speed"]).is_equal(4.0)

func test_water_config_cooldown() -> void:
	assert_float(EnemySystem.ENEMY_TYPE_DATA["water"]["attack_cooldown"]).is_equal(1.5)

func test_water_counter_form() -> void:
	assert_int(EnemySystem.ENEMY_TYPE_DATA["water"]["counter_form"]).is_equal(1)

func test_water_spawn_alive() -> void:
	var id := _enemy_system.spawn_enemy("water", Vector3(5, 0, 0))
	assert_bool(_enemy_system.is_alive(id)).is_true()


## ── 通用行为测试 ─────────────────────────────────────────────────────────

## 各类型独立 take_damage
func test_each_type_independent_damage() -> void:
	var pine_id := _enemy_system.spawn_enemy("pine", Vector3(3, 0, 0))
	var stone_id := _enemy_system.spawn_enemy("stone", Vector3(6, 0, 0))
	var water_id := _enemy_system.spawn_enemy("water", Vector3(9, 0, 0))

	_enemy_system.take_damage(pine_id, 2)
	_enemy_system.take_damage(stone_id, 3)
	_enemy_system.take_damage(water_id, 1)

	assert_bool(_enemy_system.is_alive(pine_id)).is_true()   # pine HP 5→3
	assert_bool(_enemy_system.is_alive(stone_id)).is_true()   # stone HP 8→5
	assert_bool(_enemy_system.is_alive(water_id)).is_true()   # water HP 3→2


## 各类型独立死亡
func test_each_type_independent_death() -> void:
	var pine_id := _enemy_system.spawn_enemy("pine", Vector3(3, 0, 0))
	var water_id := _enemy_system.spawn_enemy("water", Vector3(9, 0, 0))

	_enemy_system.take_damage(pine_id, 5)
	_enemy_system.take_damage(water_id, 3)

	assert_bool(_enemy_system.is_alive(pine_id)).is_false()
	assert_bool(_enemy_system.is_alive(water_id)).is_false()


## GDD Edge Case #1 — 同一帧全部击杀，各自独立触发 enemy_died
func test_simultaneous_death_independent_signals() -> void:
	var ids: Array[int] = []
	ids.append(_enemy_system.spawn_enemy("pine", Vector3(3, 0, 0)))
	ids.append(_enemy_system.spawn_enemy("stone", Vector3(6, 0, 0)))
	ids.append(_enemy_system.spawn_enemy("water", Vector3(9, 0, 0)))

	var death_count := 0
	_enemy_system.enemy_died.connect(func(_id): death_count += 1)

	for id in ids:
		_enemy_system.take_damage(id, 99)

	assert_int(death_count).is_equal(3)


## GDD Edge Case #2 — 生成位置与玩家重叠 → 自动推离 2m
func test_spawn_overlap_pushes_away() -> void:
	var id := _enemy_system.spawn_enemy("pine", Vector3(0.5, 0, 0))
	var pos := _enemy_system.get_enemy_position(id)
	var dist := pos.distance_to(Vector3.ZERO)
	assert_float(dist).is_greater_equal(2.0)


## get_enemy_type 正确返回类型名
func test_get_enemy_type() -> void:
	var pine_id := _enemy_system.spawn_enemy("pine", Vector3(3, 0, 0))
	var stone_id := _enemy_system.spawn_enemy("stone", Vector3(6, 0, 0))
	assert_str(_enemy_system.get_enemy_type(pine_id)).is_equal("pine")
	assert_str(_enemy_system.get_enemy_type(stone_id)).is_equal("stone")


## get_enemy_type 不存在返回 ""
func test_get_enemy_type_invalid() -> void:
	assert_str(_enemy_system.get_enemy_type(-1)).is_equal("")


## 未知类型生成返回 -1
func test_spawn_unknown_type_fails() -> void:
	var id := _enemy_system.spawn_enemy("nonexistent", Vector3.ZERO)
	assert_int(id).is_equal(-1)


## DEATH 状态下 AI 更新不崩溃
func test_death_state_ai_frozen() -> void:
	var id := _enemy_system.spawn_enemy("water", Vector3(1, 0, 0))
	_enemy_system.take_damage(id, 99)
	_enemy_system.update_enemy_ai(id, 0.016)
	assert_bool(_enemy_system.is_alive(id)).is_false()
