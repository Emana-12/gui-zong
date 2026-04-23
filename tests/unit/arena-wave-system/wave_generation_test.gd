## wave_generation_test.gd — ArenaWaveSystem 波次生成测试
##
## 覆盖: 波次难度公式、敌人类型解锁、加权随机、生成队列
extends GdUnitTestSuite

var _wave_system: ArenaWaveSystem


func before_test() -> void:
	_wave_system = auto_free(ArenaWaveSystem.new())
	_wave_system.name = "ArenaWaveSystem"
	add_child(_wave_system)
	# 固定随机种子确保确定性
	_wave_system.set_rng_seed(42)


## =========================================================================
## 波次难度公式: enemy_count = base_count + floor(wave * scaling_factor)
## base_count = 2, scaling_factor = 0.8
## =========================================================================

func test_wave1_generates_two_enemies() -> void:
	# 2 + floor(1 * 0.8) = 2 + 0 = 2
	var count: int = _wave_system._calculate_enemy_count(1)
	assert_int(count).is_equal(2)


func test_wave5_generates_six_enemies() -> void:
	# 2 + floor(5 * 0.8) = 2 + 4 = 6
	var count: int = _wave_system._calculate_enemy_count(5)
	assert_int(count).is_equal(6)


func test_wave10_generates_ten_enemies() -> void:
	# 2 + floor(10 * 0.8) = 2 + 8 = 10
	var count: int = _wave_system._calculate_enemy_count(10)
	assert_int(count).is_equal(10)


func test_wave20_generates_eighteen_enemies() -> void:
	# 2 + floor(20 * 0.8) = 2 + 16 = 18
	var count: int = _wave_system._calculate_enemy_count(20)
	assert_int(count).is_equal(18)


func test_custom_scaling_factor() -> void:
	_wave_system.scaling_factor = 1.0
	# 2 + floor(5 * 1.0) = 2 + 5 = 7
	var count: int = _wave_system._calculate_enemy_count(5)
	assert_int(count).is_equal(7)


func test_wave0_returns_two() -> void:
	# 2 + floor(0 * 0.8) = 2
	var count: int = _wave_system._calculate_enemy_count(0)
	assert_int(count).is_equal(2)


## =========================================================================
## 敌人类型解锁
## =========================================================================

func test_wave1_only_flow_available() -> void:
	var types := _wave_system._generate_enemy_types(1, 10)
	for enemy_type in types:
		assert_str(enemy_type).is_equal("water")


func test_wave2_has_flow_and_pine() -> void:
	_wave_system.set_rng_seed(0)
	var types := _wave_system._generate_enemy_types(2, 100)
	var unique_types := {}
	for enemy_type in types:
		unique_types[enemy_type] = true
	assert_int(unique_types.size()).is_equal(2)
	assert_bool(unique_types.has("water")).is_true()
	assert_bool(unique_types.has("pine")).is_true()
	# ranged 不应在 wave 2
	assert_bool(unique_types.has("ranged")).is_false()


func test_wave4_has_flow_pine_ranged() -> void:
	_wave_system.set_rng_seed(0)
	var types := _wave_system._generate_enemy_types(4, 100)
	var unique_types := {}
	for enemy_type in types:
		unique_types[enemy_type] = true
	assert_int(unique_types.size()).is_equal(3)
	assert_bool(unique_types.has("water")).is_true()
	assert_bool(unique_types.has("pine")).is_true()
	assert_bool(unique_types.has("ranged")).is_true()


func test_wave6_has_four_types() -> void:
	_wave_system.set_rng_seed(0)
	var types := _wave_system._generate_enemy_types(6, 200)
	var unique_types := {}
	for enemy_type in types:
		unique_types[enemy_type] = true
	assert_int(unique_types.size()).is_equal(4)


func test_wave8_has_all_five_types() -> void:
	_wave_system.set_rng_seed(0)
	var types := _wave_system._generate_enemy_types(8, 500)
	var unique_types := {}
	for enemy_type in types:
		unique_types[enemy_type] = true
	assert_int(unique_types.size()).is_equal(5)


func test_generated_types_are_valid_enemy_types() -> void:
	var valid_types := ["water", "pine", "ranged", "stone", "agile"]
	var types := _wave_system._generate_enemy_types(10, 20)
	for enemy_type in types:
		assert_bool(valid_types.has(enemy_type)).is_true()


## =========================================================================
## 波次数据预览
## =========================================================================

func test_get_wave_data_returns_correct_count() -> void:
	var data: Dictionary = _wave_system.get_wave_data(5)
	assert_int(data["count"]).is_equal(6)
	assert_int((data["types"] as Array).size()).is_equal(6)


func test_get_wave_data_wave1_all_flow() -> void:
	var data: Dictionary = _wave_system.get_wave_data(1)
	assert_int(data["count"]).is_equal(2)
	for enemy_type in data["types"]:
		assert_str(enemy_type).is_equal("water")


## =========================================================================
## 生成队列
## =========================================================================

func test_spawn_queue_filled_on_start_wave() -> void:
	_wave_system.start_wave(1)
	assert_int(_wave_system.get_spawn_queue_size()).is_equal(2)


func test_spawn_queue_larger_than_max() -> void:
	# Wave 10: 10 enemies, all queued because no EnemySystem mock
	_wave_system.start_wave(10)
	assert_int(_wave_system.get_spawn_queue_size()).is_equal(10)


func test_wave_progress_on_start() -> void:
	_wave_system.start_wave(5)
	var progress: Vector2 = _wave_system.get_wave_progress()
	# x = kills, y = total
	assert_int(int(progress.y)).is_equal(6)
	assert_int(int(progress.x)).is_equal(0)
