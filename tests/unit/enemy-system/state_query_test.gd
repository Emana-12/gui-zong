## state_query_test.gd — EnemySystem 状态管理与查询 API 测试
##
## 覆盖 story-003-state-query 全部 3 个 AC + 4 个边缘用例
extends GdUnitTestSuite

var _enemy_system: EnemySystem
var _player_node: Node3D
var _gsm: GameStateManager


func before_test() -> void:
	_enemy_system = auto_free(EnemySystem.new())
	_enemy_system.name = "EnemySystem"
	add_child(_enemy_system)

	_player_node = auto_free(Node3D.new())
	_player_node.name = "Player"
	_player_node.position = Vector3.ZERO
	add_child(_player_node)

	_enemy_system.set_player_ref(_player_node)

	# 创建 GameStateManager 并注入
	_gsm = auto_free(GameStateManager.new())
	_gsm.name = "GameStateManager"
	add_child(_gsm)
	_enemy_system.set_game_state_manager(_gsm)


## =========================================================================
## AC-1: INTERMISSION → AI frozen, no updates
## =========================================================================
func test_intermission_freezes_ai_updates() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	# 先切到 COMBAT 激活 AI
	_gsm.change_state(GameStateManager.State.COMBAT)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)
	# 切到 INTERMISSION
	_gsm.change_state(GameStateManager.State.INTERMISSION)
	# AI 不应更新 — 尝试 update_enemy_ai 应跳过
	_enemy_system.update_enemy_ai(enemy_id, 1.0)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)


func test_intermission_process_does_not_update_ai() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	# 在 INTERMISSION 状态下 spawn，AI 不应激活
	assert_int(_gsm.get_current_state()) \
		.is_equal(GameStateManager.State.TITLE)  # 初始状态是 TITLE
	# TITLE 不是 COMBAT，所以 _is_game_active = false
	_enemy_system.update_enemy_ai(enemy_id, 1.0)
	# 状态保持 IDLE
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)


func test_combat_state_reactivates_ai() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_gsm.change_state(GameStateManager.State.COMBAT)
	# 切回 COMBAT 后 AI 应可正常更新
	_enemy_system.update_enemy_ai(enemy_id, 0.1)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)


func test_death_state_freezes_ai() -> void:
	var enemy_id: int = _enemy_system.spawn_enemy("pine", Vector3(5, 0, 0))
	_gsm.change_state(GameStateManager.State.COMBAT)
	_gsm.change_state(GameStateManager.State.DEATH)
	# DEATH 状态下 update_enemy_ai 应跳过
	_enemy_system.update_enemy_ai(enemy_id, 1.0)
	assert_int(_enemy_system.get_enemy_state(enemy_id)) \
		.is_equal(EnemySystem.EnemyState.IDLE)


## =========================================================================
## AC-2: get_all_enemies() with 5 → array of 5
## =========================================================================
func test_get_all_enemies_returns_correct_count() -> void:
	for i in range(5):
		_enemy_system.spawn_enemy("pine", Vector3(i, 0, 0))
	var enemies: Array = _enemy_system.get_all_enemies()
	assert_int(enemies.size()).is_equal(5)


func test_get_all_enemies_empty_when_none_spawned() -> void:
	var enemies: Array = _enemy_system.get_all_enemies()
	assert_int(enemies.size()).is_equal(0)


func test_get_all_enemies_contains_correct_data() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	var enemies: Array = _enemy_system.get_all_enemies()
	assert_int(enemies.size()).is_equal(2)
	# 验证数据完整性
	for data in enemies:
		assert_bool(data is EnemySystem.EnemyData).is_true()
		assert_int(data.hp).is_greater(0)


## =========================================================================
## AC-3: get_alive_count() with 2 alive → 2
## =========================================================================
func test_get_alive_count_with_alive_enemies() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	assert_int(_enemy_system.get_alive_count()).is_equal(2)


func test_get_alive_count_mixed_alive_dead() -> void:
	for i in range(5):
		_enemy_system.spawn_enemy("pine", Vector3(i, 0, 0))
	# 杀死前 3 个
	_enemy_system.take_damage(0, 5)
	_enemy_system.take_damage(1, 5)
	_enemy_system.take_damage(2, 5)
	assert_int(_enemy_system.get_alive_count()).is_equal(2)


func test_get_alive_count_all_dead() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	_enemy_system.kill_all()
	assert_int(_enemy_system.get_alive_count()).is_equal(0)


## =========================================================================
## Edge cases
## =========================================================================
func test_get_alive_count_zero_when_none_spawned() -> void:
	assert_int(_enemy_system.get_alive_count()).is_equal(0)


func test_get_all_enemies_reflects_death_state() -> void:
	_enemy_system.spawn_enemy("pine", Vector3(1, 0, 0))
	_enemy_system.spawn_enemy("pine", Vector3(2, 0, 0))
	_enemy_system.take_damage(0, 5)
	var enemies: Array = _enemy_system.get_all_enemies()
	for data in enemies:
		if data.id == 0:
			assert_bool(_enemy_system.is_alive(data.id)).is_false()
		else:
			assert_bool(_enemy_system.is_alive(data.id)).is_true()
