## 模拟 GameStateManager — 仅用于测试
##
## 提供 state_changed 信号和 get_current_state() 方法，
## 无需依赖完整的 GameStateManager autoload。
extends Node

signal state_changed(old_state: int, new_state: int)

var _current_state: int = 1  # 默认 COMBAT


func get_current_state() -> int:
	return _current_state
