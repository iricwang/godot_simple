extends "res://core/base_view_model.gd"

func _init() -> void:
	self.counter = 0
	self.title = "首页"
	self.progress = 0.5
	self.loading = false
	self.status_text = "等待操作..."

func on_increment() -> void:
	self.counter = self.counter + 1
	self.status_text = "计数器: %d" % self.counter


func on_decrement() -> void:
	self.counter = self.counter - 1
	self.status_text = "计数器: %d" % self.counter
