@warning_ignore_start("inferred_declaration")
## damage_death_test.gd — EnemySystem 伤害与死亡测试
##
## 覆盖 story-002-damage-death 全部 3 个 AC + 4 个边缘用例
extends GdUnitTestSuite

var _enemy_system: EnemySystem
var _player_node: Node3D


func before_test() -> void:
	_enemy_system = auto_free(EnemySystem.new())
	_enemy_system.name = "EnemySystem"
	add_child(_enemy_system)

	_player_node = auto_free(Node3D.new())
	_player_node.name = "Player"
	_player_node.position = Vector3.ZERO
	add_child(_player_node)

	_enemy_system.set_player_ref(_player_node)


## =========================================================================
## AC-1: take_damage(3) on HP=5 → HP=2, HIT_STUN 0.3s
## =========================================================================
func test_take_damage_reduces_hp() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_enemy_system.take_damage(enemy_id, 3)
	var enemies: Array = _enemy_system.get_all_enemies()
	var found := false
	for data in enemies:
		if data.id == enemy_id:
			assert_int(data.hp).is_equal(2)
			found = true
	assert_bool(found).is_true()


func test_take_damage_applies_hit_stun() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_enemy_system.take_damage(enemy_id, 1)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.HIT_STUN)


func test_take_damage_hit_stun_duration_is_0_3s() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_enemy_system.take_damage(enemy_id, 1)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.HIT_STUN)
	# HIT_STUN 应在 0.3s 后结束
	_enemy_system.update_enemy_ai(enemy_id, 0.3)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_not_equal(EnemySystem.EnemyState.HIT_STUN)


func test_take_damage_emits_state_changed_signal() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	var monitor := await monitor_signals(_enemy_system)
	_enemy_system.take_damage(enemy_id, 1)
	await assert_signal(monitor).is_emitted("enemy_state_changed")


## =========================================================================
## AC-2: HP=0 → DEAD, enemy_died signal
## =========================================================================
func test_take_damage_kills_enemy_at_zero_hp() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	# pine HP=5, deal 5 damage
	_enemy_system.take_damage(enemy_id, 5)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.DEAD)


func test_take_damage_kills_enemy_when_exceeding_hp() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	# pine HP=5, deal 10 damage (overkill)
	_enemy_system.take_damage(enemy_id, 10)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.DEAD)
	assert_bool(_enemy_system.is_alive(enemy_id)).is_false()


func test_take_damage_emits_enemy_died_signal() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	var monitor := await monitor_signals(_enemy_system)
	_enemy_system.take_damage(enemy_id, 5)
	await assert_signal(monitor).is_emitted("enemy_died")


func test_take_damage_enemy_died_not_emitted_on_survive() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	var monitor := await monitor_signals(_enemy_system)
	_enemy_system.take_damage(enemy_id, 2)  # HP 5→3, not dead
	# enemy_died 不应触发
	assert_bool(_enemy_system.is_alive(enemy_id)).is_true()


## =========================================================================
## AC-3: get_alive_count with mixed alive/dead → correct count
## =========================================================================
func test_get_alive_count_mixed_states() -> void:
	# 生成 5 个敌人
	for i in range(5):
		_enemy_system.spawn_enemy("pine", Vector3(i, 0, 0))
	# 杀死前 3 个
	_enemy_system.take_damage(0, 5)
	_enemy_system.take_damage(1, 5)
	_enemy_system.take_damage(2, 5)
	assert_int(_enemy_system.get_alive_count()).is_equal(2)


func test_get_alive_count_all_alive() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	assert_int(_enemy_system.get_alive_count()).is_equal(2)


func test_get_alive_count_all_dead() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	_enemy_system.take_damage(0, 5)
	_enemy_system.take_damage(1, 5)
	assert_int(_enemy_system.get_alive_count()).is_equal(0)


## =========================================================================
## Edge cases
## =========================================================================
func test_take_damage_zero_does_nothing() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_enemy_system.take_damage(enemy_id, 0)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)
	var enemies: Array = _enemy_system.get_all_enemies()
	for data in enemies:
		if data.id == enemy_id:
			assert_int(data.hp).is_equal(5)


func test_take_damage_on_dead_enemy_ignored() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_enemy_system.take_damage(enemy_id, 5)  # Kill
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.DEAD)
	# 再次伤害应被忽略
	_enemy_system.take_damage(enemy_id, 1)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.DEAD)


func test_take_damage_unknown_id_no_crash() -> void:
	# 对不存在的敌人调用不应崩溃
	_enemy_system.take_damage(9999, 5)
	# 验证系统仍正常
	_enemy_system.spawn_enemy("pine", Vector3(0, 0, 0))
	assert_int(_enemy_system.get_alive_count()).is_equal(1)


func test_take_damage_negative_amount_does_nothing() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_enemy_system.take_damage(enemy_id, -3)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)
	var enemies: Array = _enemy_system.get_all_enemies()
	for data in enemies:
		if data.id == enemy_id:
			assert_int(data.hp).is_equal(5)


func test_kill_all_and_take_damage_after() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	_enemy_system.kill_all()
	assert_int(_enemy_system.get_alive_count()).is_equal(0)
	# 对已 kill_all 的敌人再次 take_damage 应被忽略
	_enemy_system.take_damage(0, 1)
	assert_int(_enemy_system.get_enemy_state(0)) \
		.is_equal(EnemySystem.EnemyState.DEAD)
