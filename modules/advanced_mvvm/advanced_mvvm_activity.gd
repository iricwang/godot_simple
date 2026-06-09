extends Activity
## 高级 MVVM 功能演示 — 批量更新 + 值转换器 + 动态信号注册
##
## 演示内容:
##   1. 批量更新: begin_bulk_update() / end_bulk_update()
##   2. 内置转换器: IntToStringConverter, FloatToPercentConverter
##   3. 自定义转换器: BoolToTextConverter
##   4. 动态注册双向绑定信号

var vm: ViewModel

func _on_create(saved_state: Dictionary) -> void:
	print("[AdvancedActivity] _on_create")
	vm = preload("res://core/base_view_model.gd").new()

	# 动态注册自定义双向绑定信号
	BindingEngine.register_two_way_signal("range_changed")

	# 演示批量更新
	vm.begin_bulk_update()
	vm.batch_counter = 0
	vm.batch_value = 0.0
	vm.batch_enabled = false
	vm.end_bulk_update()

	var tin = Transition.new()
	tin.enter_type = Transition.FADE
	tin.duration = 0.3
	var tout = Transition.new()
	tout.exit_type = Transition.FADE
	tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()
	_apply_bindings()


func _setup_ui() -> void:
	var vb = VBoxContainer.new()
	vb.name = "Root"
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 20)
	vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.name = "C"
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	# 标题
	var header = Label.new()
	header.name = "Header"
	header.text = "⚡ 高级 MVVM 功能演示"
	header.add_theme_font_size_override("font_size", 26)
	inner.add_child(header)

	# 批量更新演示
	var sep1 = HSeparator.new()
	sep1.name = "Sep1"
	inner.add_child(sep1)

	var batch_section = Label.new()
	batch_section.name = "BatchSection"
	batch_section.text = "—— 批量更新（多次赋值只触发一次通知） ——"
	batch_section.add_theme_font_size_override("font_size", 14)
	inner.add_child(batch_section)

	var batch_label = Label.new()
	batch_label.name = "BatchLabel"
	batch_label.text = "计数器: 0"
	inner.add_child(batch_label)

	var batch_slider = HSlider.new()
	batch_slider.name = "BatchSlider"
	batch_slider.min_value = 0
	batch_slider.max_value = 100
	batch_slider.step = 1
	batch_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(batch_slider)

	var batch_btn = Button.new()
	batch_btn.name = "BatchBtn"
	batch_btn.text = "批量更新 (slider → 0→100)"
	inner.add_child(batch_btn)

	# 值转换器演示
	var sep2 = HSeparator.new()
	sep2.name = "Sep2"
	inner.add_child(sep2)

	var converter_section = Label.new()
	converter_section.name = "ConverterSection"
	converter_section.text = "—— 值转换器 ——"
	converter_section.add_theme_font_size_override("font_size", 14)
	inner.add_child(converter_section)

	var percent_label = Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	inner.add_child(percent_label)

	var percent_slider = HSlider.new()
	percent_slider.name = "PercentSlider"
	percent_slider.min_value = 0
	percent_slider.max_value = 100
	percent_slider.step = 1
	percent_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	percent_slider.value = 50
	inner.add_child(percent_slider)

	# 动态信号注册演示
	var sep3 = HSeparator.new()
	sep3.name = "Sep3"
	inner.add_child(sep3)

	var signal_section = Label.new()
	signal_section.name = "SignalSection"
	signal_section.text = "—— 动态注册双向绑定信号 ——"
	signal_section.add_theme_font_size_override("font_size", 14)
	inner.add_child(signal_section)

	var custom_label = Label.new()
	custom_label.name = "CustomLabel"
	custom_label.text = "自定义信号演示"
	inner.add_child(custom_label)

	var custom_spin = SpinBox.new()
	custom_spin.name = "CustomSpin"
	custom_spin.min_value = 0
	custom_spin.max_value = 1000
	custom_spin.step = 1
	inner.add_child(custom_spin)

	# 返回按钮
	var sep4 = HSeparator.new()
	sep4.name = "Sep4"
	inner.add_child(sep4)

	var btn_back = Button.new()
	btn_back.name = "BackBtn"
	btn_back.text = "<- 返回首页"
	inner.add_child(btn_back)


func _apply_bindings() -> void:
	# 批量更新绑定
	Context.bind_property($Root/Margin/C/BatchLabel, "text", vm, "batch_counter", 0)
	Context.bind_property($Root/Margin/C/BatchSlider, "value", vm, "batch_counter", 1)
	Context.bind_command($Root/Margin/C/BatchBtn, "pressed", vm, "on_batch_update")

	# 值转换器绑定
	Context.bind_property($Root/Margin/C/PercentLabel, "text", vm, "percent_value", 1,
		preload("res://core/converters/float_to_percent_converter.gd").new())
	Context.bind_property($Root/Margin/C/PercentSlider, "value", vm, "percent_value", 1)

	# 动态信号绑定 (CustomSpin 有 value_changed，label 显示格式化文本)
	Context.bind_property($Root/Margin/C/CustomLabel, "text", vm, "custom_value", 1)


func _on_start() -> void:
	print("[AdvancedActivity] _on_start")


func _on_resume() -> void:
	print("[AdvancedActivity] _on_resume")


func _on_pause() -> void:
	print("[AdvancedActivity] _on_pause")


func _on_stop() -> void:
	print("[AdvancedActivity] _on_stop")


func _on_destroy() -> void:
	print("[AdvancedActivity] _on_destroy")
	if vm:
		vm.dispose()
	# 清理注册的信号
	BindingEngine.unregister_two_way_signal("range_changed")


func _on_back_pressed() -> bool:
	return false


# ViewModel 命令
func on_batch_update() -> void:
	# 批量更新演示: 快速连续设置值
	vm.begin_bulk_update()
	for i in range(100):
		vm.batch_counter = i
	vm.end_bulk_update()
	show_toast(Context.make_toast("批量更新完成! 100次赋值→1次通知", 2.0))
