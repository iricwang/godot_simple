extends ViewModel
## ViewModel GDScript 包装层 — 提供 `_set`/`_get` 使 `self.xxx = yyy` 语法可用
##
## 用法: extends "res://scripts/base_view_model.gd"
##   func _init(): self.counter = 0; self.title = "Hello"
##   func on_inc(): self.counter += 1    # 自动触发 BindingEngine 更新 UI
##
## 批量更新用法:
##   vm.begin_bulk_update()
##   vm.counter = 1
##   vm.counter = 2
##   vm.counter = 3
##   vm.end_bulk_update()  # 只触发一次 value_changed (C++ 端 O(N) 遍历)


func _set(property: StringName, value) -> bool:
	set_property(property, value)
	return true


func _get(property: StringName):
	return get_value(property)
