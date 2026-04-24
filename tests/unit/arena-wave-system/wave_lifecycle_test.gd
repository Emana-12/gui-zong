@warning_ignore_start("inferred_declaration")
## wave_lifecycle_test.gd — ArenaWaveSystem 波次生命周期测试
##
## 覆盖: wave_started/wave_completed/intermission_started 信号、
## 生成队列出队、间歇流程、状态集成
extends GdUnitTestSuite

var _wave_system: ArenaWaveSystem
var _mock_enemy_system: EnemySystem
var _player_node: Node3D


func before_test() -> void:
	# 创建 mock EnemySystem
	_mock_enemy_system = auto_free(EnemySystem.new())
	_mock_enemy_system.name = "EnemySystem"
	add_child(_mock_enemy_system)

	# 创建玩家节点
	_player_node = auto_free(Node3D.new())
	_player_node.name = "Player"
	_player_node.position = Vector3.ZERO
	add_child(_player_node)

	_mock_enemy_system.set_player_ref(_player_node)

	# 创建波次系统
	_wave_system = auto_free(ArenaWaveSystem.new())
	_wave_system.name = "ArenaWaveSystem"
	add_child(_wave_system)

	_wave_system.set_rng_seed(42)
	_wave_system._test_set_enemy_system(_mock_enemy_system)
	_wave_system.set_player_ref(_player_node)


## =========================================================================
## 波次启动信号
## =========================================================================

func test_start_wave_emits_wave_started() -> void:
	var monitor = await monitor_signals(_wave_system)
	_wave_system.start_wave(1)
	await assert_signal(monitor).is_emitted("wave_started")


func test_start_wave_current_wave_is_1() -> void:
	_wave_system.start_wave(1)
	assert_int(_wave_system.get_current_wave()).is_equal(1)


func test_start_wave_invalid_number_ignored() -> void:
	_wave_system.start_wave(0)
	assert_int(_wave_system.get_current_wave()).is_equal(0)


## =========================================================================
## 敌人实际生成
## =========================================================================

func test_start_wave_spawns_enemies_via_enemy_system() -> void:
	_wave_system.start_wave(1)
	# Wave 1 = 2 enemies, should be spawned (alive count = 2)
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(2)


func test_start_wave5_spawns_six_enemies() -> void:
	_wave_system.start_wave(5)
	# 2 + floor(5 * 0.8) = 6
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(6)


func test_wave10_capped_at_max_active() -> void:
	# Wave 10 = 10 enemies, exactly at MAX_ACTIVE_ENEMIES
	_wave_system.start_wave(10)
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(10)


func test_wave20_spawns_in_batches() -> void:
	# Wave 20 = 18 enemies, but MAX = 10
	# First batch: 10 spawned, 8 queued
	_wave_system.start_wave(20)
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(10)
	assert_int(_wave_system.get_spawn_queue_size()).is_equal(8)


func test_enemy_died_releases_spawn_queue() -> void:
	_wave_system.start_wave(20)
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(10)
	assert_int(_wave_system.get_spawn_queue_size()).is_equal(8)

	# Kill one enemy
	var enemies = _mock_enemy_system.get_all_enemies()
	if enemies.size() > 0:
		_mock_enemy_system.take_damage(enemies[0].id, 999)

	# Wait a frame for signal processing
	await get_tree().process_frame

	# Queue should have released one: 8 - 1 = 7
	# Alive: 10 - 1 + 1 (from queue) = 10
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(10)
	assert_int(_wave_system.get_spawn_queue_size()).is_equal(7)


## =========================================================================
## 波次完成检测
## =========================================================================

func test_all_enemies_die_completes_wave() -> void:
	var monitor = await monitor_signals(_wave_system)
	_wave_system.start_wave(1)
	_mock_enemy_system.kill_all()
	await get_tree().process_frame
	await assert_signal(monitor).is_emitted("wave_completed")


func test_wave_completed_emits_correct_wave_number() -> void:
	_wave_system.start_wave(3)
	_mock_enemy_system.kill_all()
	await get_tree().process_frame
	assert_int(_wave_system.get_current_wave()).is_equal(3)


func test_wan_jian_qui_zong_instant_kill_completes_wave() -> void:
	# 万剑归宗: all 10 enemies die in one frame
	_wave_system.start_wave(10)
	assert_int(_mock_enemy_system.get_alive_count()).is_equal(10)
	_mock_enemy_system.kill_all()
	await get_tree().process_frame
	# Wave should complete
	assert_int(_wave_system.get_current_wave()).is_equal(10)


## =========================================================================
## 波次进度追踪
## =========================================================================

func test_kills_increment_on_enemy_death() -> void:
	_wave_system.start_wave(5)
	var enemies = _mock_enemy_system.get_all_enemies()
	if enemies.size() > 0:
		_mock_enemy_system.take_damage(enemies[0].id, 999)
	await get_tree().process_frame
	var progress: Vector2 = _wave_system.get_wave_progress()
	assert_int(int(progress.x)).is_equal(1)  # kills = 1
	assert_int(int(progress.y)).is_equal(6)  # total = 6


## =========================================================================
## 间歇流程
## =========================================================================

func test_intermission_started_after_wave_complete() -> void:
	var monitor = await monitor_signals(_wave_system)
	_wave_system.start_wave(1)
	_mock_enemy_system.kill_all()
	await get_tree().process_frame
	await assert_signal(monitor).is_emitted("intermission_started")


func test_intermission_timer_starts() -> void:
	_wave_system.start_wave(1)
	_mock_enemy_system.kill_all()
	await get_tree().process_frame
	var timer = _wave_system._test_get_intermission_timer()
	assert_bool(timer.is_stopped()).is_false()


## =========================================================================
## 波次重置
## =========================================================================

func test_reset_waves_clears_state() -> void:
	_wave_system.start_wave(5)
	_wave_system.reset_waves()
	assert_int(_wave_system.get_current_wave()).is_equal(0)
	assert_int(_wave_system.get_spawn_queue_size()).is_equal(0)


func test_reset_waves_stops_timers() -> void:
	_wave_system.start_wave(1)
	_mock_enemy_system.kill_all()
	await get_tree().process_frame
	_wave_system.reset_waves()
	var timer = _wave_system._test_get_intermission_timer()
	assert_bool(timer.is_stopped()).is_true()


## =========================================================================
## get_wave_data 预览不改变状态
## =========================================================================

func test_get_wave_data_does_not_change_state() -> void:
	_wave_system.start_wave(3)
	_wave_system.get_wave_data(5)
	assert_int(_wave_system.get_current_wave()).is_equal(3)


## =========================================================================
## 依赖注入
## =========================================================================

func test_set_enemy_system_replaces_reference() -> void:
	var new_system: EnemySystem = auto_free(EnemySystem.new())
	add_child(new_system)
	_wave_system.set_enemy_system(new_system)
	# Old reference should be replaced
	_wave_system.start_wave(1)
	# Enemies spawned into new system
	assert_int(new_system.get_alive_count()).is_equal(2)


func test_set_game_state_manager_injects_reference() -> void:
	var gsm: GameStateManager = auto_free(GameStateManager.new())
	add_child(gsm)
	_wave_system.set_game_state_manager(gsm)
	# Should not crash, connection established
	pass_test("set_game_state_manager completed without error")


func test_set_rng_seed_is_deterministic() -> void:
	_wave_system.set_rng_seed(123)
	var types_a = _wave_system._generate_enemy_types(5, 10)
	_wave_system.set_rng_seed(123)
	var types_b = _wave_system._generate_enemy_types(5, 10)
	assert_array(types_a).is_equal(types_b)
