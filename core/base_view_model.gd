extends ViewModel
## ViewModel GDScript 包装层 — 提供 `_set`/`_get` 使 `self.xxx = yyy` 语法可用
##
## 用法: extends "res://scripts/base_view_model.gd"
##   func _init(): self.counter = 0; self.title = "Hello"
##   func on_inc(): self.counter += 1    # 自动触发 BindingEngine 更新 UI


func _set(property: StringName, value) -> bool:
	set_property(property, value)
	return true


func _get(property: StringName):
	return get_value(property)
