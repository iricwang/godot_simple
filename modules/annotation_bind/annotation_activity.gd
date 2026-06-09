extends Activity
## 注解绑定 Activity — @bind_property + @bind_signal 全自动绑定
##
## 工作流：
##   1. VM 用 @bind_property/@bind_signal 声明所有绑定
##   2. Activity 只做 _setup_ui() + vm.apply_bindings(self)
##   3. @bind_signal 方法通过 apply_bindings 自动搜索目标节点并连接

var vm: ViewModel

# UI 引用(仅供参考，不再用于手动绑定)
var _title_label: Label
var _counter_label: Label
var _progress_bar: ProgressBar
var _check_box: CheckBox
var _btn_inc: Button
var _btn_reset: Button
var _status_label: Label

func _on_create(saved_state: Dictionary) -> void:
	print("[AnnotationActivity] _on_create")
	vm = preload("res://modules/annotation_bind/annotation_vm.gd").new()

	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_LEFT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.SLIDE_RIGHT; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()

	# 一行搞定：@bind_property + @bind_signal 全自动绑定
	vm.apply_bindings(self)
	print("[AnnotationActivity] vm.apply_bindings(self) ✓ — @bind_property + @bind_signal 全自动绑定完成")

func _on_start() -> void:
	print("[AnnotationActivity] _on_start")


func _on_resume() -> void:
	print("[AnnotationActivity] _on_resume")


func _on_pause() -> void:
	print("[AnnotationActivity] _on_pause")


func _on_stop() -> void:
	print("[AnnotationActivity] _on_stop")


func _on_destroy() -> void:
	print("[AnnotationActivity] _on_destroy")
	if vm:
		vm.dispose()


func _on_back_pressed() -> bool:
	return false


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

	var header = Label.new()
	header.text = "⚡ 注解绑定示例（全自动版）"
	header.add_theme_font_size_override("font_size", 26)
	inner.add_child(header)

	var desc = Label.new()
	desc.text = "@bind_property + @bind_signal 全自动绑定"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	var sep0 = HSeparator.new()
	inner.add_child(sep0)

	var section1 = Label.new()
	section1.text = "—— @bind_property（标注在数据字段上） ——"
	section1.add_theme_font_size_override("font_size", 14)
	section1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(section1)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "标题占位"
	_title_label.add_theme_font_size_override("font_size", 22)
	inner.add_child(_title_label)

	_counter_label = Label.new()
	_counter_label.name = "CounterLabel"
	_counter_label.text = "0"
	_counter_label.add_theme_font_size_override("font_size", 18)
	inner.add_child(_counter_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.value = 0.5
	inner.add_child(_progress_bar)

	_check_box = CheckBox.new()
	_check_box.name = "CheckBox"
	_check_box.text = "双向绑定测试 (VM <-> CheckBox)"
	inner.add_child(_check_box)

	var sep1 = HSeparator.new()
	inner.add_child(sep1)

	var section2 = Label.new()
	section2.text = "—— @bind_signal（自动搜索节点并连接） ——"
	section2.add_theme_font_size_override("font_size", 14)
	section2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(section2)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	inner.add_child(btn_row)

	_btn_inc = Button.new()
	_btn_inc.text = "+1 (on_increment)"
	_btn_inc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_btn_inc)

	_btn_reset = Button.new()
	_btn_reset.text = "重置 (on_reset)"
	_btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_btn_reset)

	var sep2 = HSeparator.new()
	inner.add_child(sep2)

	var section3 = Label.new()
	section3.text = "—— 状态输出 ——"
	section3.add_theme_font_size_override("font_size", 14)
	section3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(section3)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "状态..."
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_status_label)

	var sep3 = HSeparator.new()
	inner.add_child(sep3)

	var btn_back = Button.new()
	btn_back.text = "<- finish() 返回首页"
	btn_back.pressed.connect(_on_back)
	inner.add_child(btn_back)

	var btn_toast = Button.new()
	btn_toast.text = "◉ 显示 Toast"
	btn_toast.pressed.connect(_on_toast)
	inner.add_child(btn_toast)


func _on_back() -> void:
	finish()


func _on_toast() -> void:
	show_toast(Context.make_toast("注解绑定示例（全自动版） — 来自 AnnotationActivity", 2.0))
