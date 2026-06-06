extends "res://core/base_view_model.gd"


func _init() -> void:
	self.title = "确认操作"
	self.message = "您确定要执行此操作吗？"
	self.result = "pending"
