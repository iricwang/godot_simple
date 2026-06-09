extends ValueConverter
## 货币格式化 (¥)
##
## 用法:
##   @bind_property("text", "PriceLabel", converter=CurrencyConverter.new())
##   var price: float  # 1234.5 → "¥1,234.50"


func _convert(value) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var v = float(value)
		# 千分位
		var sign = "-" if v < 0 else ""
		v = abs(v)
		var int_part = int(floor(v))
		var dec_part = int(round((v - int_part) * 100))
		var int_str = str(int_part)
		# 反向插入逗号
		var result = ""
		for i in range(int_str.length()):
			if i > 0 and (int_str.length() - i) % 3 == 0:
				result += ","
			result += int_str[i]
		return "%s¥%s.%02d" % [sign, result, dec_part]
	return str(value)


func _convert_back(value) -> float:
	if typeof(value) != TYPE_STRING:
		return 0.0
	var s = str(value).replace("¥", "").replace(",", "").strip_edges()
	return s.to_float()
