extends Dialog
## 确认对话框 — 测试 Dialog Context 便捷方法

var vm: ViewModel
var _title_label: Label
var _msg_label: Label


func _on_create(saved_state: Dictionary) -> void:
	print("[ConfirmDialog] _on_create")
	vm = preload("res://modules/dialog/dialog_vm.gd").new()

	# 转场: 缩放弹入, 淡出关闭
	var tin = Transition.new(); tin.enter_type = Transition.SCALE; tin.duration = 0.25
	var tout = Transition.new(); tout.exit_type = Transition.FADE; tout.duration = 0.2
	transition_in = tin
	transition_out = tout

	if saved_state.has("title"):
		vm.title = saved_state["title"]
	if saved_state.has("message"):
		vm.message = saved_state["message"]

	_setup_ui()

	Context.bind_property(_title_label, "text", vm, "title")
	Context.bind_property(_msg_label, "text", vm, "message")


func _on_dismiss() -> void:
	print("[ConfirmDialog] _on_dismiss")
	if vm:
		vm.dispose()


func _setup_ui() -> void:
	# 半透明遮罩
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# 居中面板
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_custom_minimum_size(Vector2(320, 200))
	add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	_title_label = Label.new()
	_title_label.text = "确认"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_title_label)

	_msg_label = Label.new()
	_msg_label.text = "..."
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_msg_label)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	inner.add_child(hbox)

	var btn_ok = Button.new()
	btn_ok.text = "确认"
	btn_ok.pressed.connect(_on_confirm)
	hbox.add_child(btn_ok)

	var btn_cancel = Button.new()
	btn_cancel.text = "取消"
	btn_cancel.pressed.connect(_on_cancel)
	hbox.add_child(btn_cancel)


func _on_confirm() -> void:
	print("[ConfirmDialog] 确认 — 发 Toast 并关闭")
	# === 测试: Dialog 便捷方法 show_toast() ===
	show_toast(Context.make_toast("操作已确认", 1.5))
	dismiss()


func _on_cancel() -> void:
	print("[ConfirmDialog] 取消")
	# === 测试: Dialog 通过 get_context() 发 Toast ===
	get_context().show_toast(Context.make_toast("操作已取消", 1.5))
	dismiss()
