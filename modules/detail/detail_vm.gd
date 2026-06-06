extends "res://core/base_view_model.gd"


func _init() -> void:
	self.title = "详情页"
	self.item_id = 0
	self.from_page = ""
	self.description = "无数据"


func set_item_data(id: int, p_from: String) -> void:
	self.item_id = id
	self.from_page = p_from
	self.description = "来自 %s 的 ID=%d" % [self.from_page, id]
