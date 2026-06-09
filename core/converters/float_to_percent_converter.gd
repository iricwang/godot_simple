extends ValueConverter
## 自定义值转换器示例 — 浮点数转百分比字符串
##
## 用法:
##   @bind_property("text", "PercentLabel", converter=FloatToPercentConverter.new())
##   var progress: float  # 0.75 → "75%"
##
## 反向转换:
##   "80%" → 0.8
##
## 注意: GDScript 子类实现 `_convert` / `_convert_back`(带下划线)，
## 避免与 C++ 父类的 public non-virtual `convert` / `convert_back` 重名。
## Godot 4 解析器会警告 "method overrides native class method"，因为
## GDScript 端的 "override" 不会调用到 C++ 虚函数 —— 使用 `_` 前缀规避。


func _convert(value) -> String:
	if typeof(value) == TYPE_FLOAT:
		return "%.0f%%" % (value * 100.0)
	return str(value)


func _convert_back(value) -> float:
	if typeof(value) == TYPE_STRING:
		var s = value.trim_suffix("%").strip_edges()
		return s.to_float() / 100.0
	return 0.0
