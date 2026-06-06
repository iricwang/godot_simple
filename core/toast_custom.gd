extends MarginContainer
## 自定义 Toast 示例 — 圆角 + 图标 + 半透明渐变背景

var _text_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 半透明圆角面板
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _make_stylebox())
	add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	hbox.add_child(margin)

	var inner = HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	# 图标（用 Unicode 字符代替）
	var icon = Label.new()
	icon.text = "★"
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	inner.add_child(icon)

	_text_label = Label.new()
	_text_label.text = "Loading..."
	_text_label.add_theme_font_size_override("font_size", 15)
	_text_label.add_theme_color_override("font_color", Color(1, 1, 1))
	inner.add_child(_text_label)

func _on_start(toast: Toast) -> void:
	# 传入 toast 可直接读取数据
	var txt = toast.get_text()
	var dur = toast.get_duration()
	_text_label.text = txt
	print("[CustomToast] _on_start: '%s' (duration=%.1f)" % [txt, dur])

func _make_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1.0, 0.85, 0.25, 0.6)
	return sb
