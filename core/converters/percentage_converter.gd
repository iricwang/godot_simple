extends ValueConverter
## 百分比格式化 (0.85 → "85%")
##
## 用法:
##   @bind_property("text", "PercentLabel", converter=PercentageConverter.new())
##   var rate: float  # 0.85 → "85%"


func _convert(value) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return "%.0f%%" % (float(value) * 100.0)
	return str(value)


func _convert_back(value) -> float:
	if typeof(value) != TYPE_STRING:
		return 0.0
	var s = str(value).trim_suffix("%").strip_edges()
	return s.to_float() / 100.0
