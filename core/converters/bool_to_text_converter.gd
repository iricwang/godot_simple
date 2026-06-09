extends ValueConverter
## 自定义值转换器示例 — 将布尔值转换为开关状态文本
##
## 用法:
##   @bind_property("text", "StatusLabel", converter=BoolToTextConverter.new())
##   var is_enabled: bool


func _convert(value) -> String:
	if value:
		return "✓ 已启用"
	else:
		return "✗ 已禁用"


func _convert_back(value) -> bool:
	return value !="✗ 已禁用"