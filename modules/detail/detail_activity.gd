extends Activity
## 详情页 Activity — 测试 Intent extras 传递 + 返回栈

var vm: ViewModel
var _title_label: Label
var _desc_label: Label


func _on_create(saved_state: Dictionary) -> void:
	print("[DetailActivity] _on_create")
	vm = preload("res://modules/detail/detail_vm.gd").new()

	# 转场: 从左侧滑入, 右侧滑出
	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_LEFT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.SLIDE_RIGHT; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	var it = get_intent()
	if it and it.extras:
		vm.set_item_data(it.extras.get("id", 0), it.extras.get("from", "unknown"))
		print("[DetailActivity] intent extras: ", it.extras, " ✓")

	_setup_ui()

	Context.bind_property(_title_label, "text", vm, "title")
	Context.bind_property(_desc_label, "text", vm, "description")


func _on_start() -> void:
	print("[DetailActivity] _on_start")


func _on_resume() -> void:
	print("[DetailActivity] _on_resume")


func _on_pause() -> void:
	print("[DetailActivity] _on_pause")


func _on_stop() -> void:
	print("[DetailActivity] _on_stop")


func _on_destroy() -> void:
	print("[DetailActivity] _on_destroy")
	if vm:
		vm.dispose()


func _on_back_pressed() -> bool:
	print("[DetailActivity] _on_back_pressed — 不消费")
	return false


func _setup_ui() -> void:
	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 20)
	vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	_title_label = Label.new()
	_title_label.text = "详情"
	_title_label.add_theme_font_size_override("font_size", 28)
	inner.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.text = "..."
	_desc_label.add_theme_font_size_override("font_size", 16)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_desc_label)

	var btn_finish = Button.new()
	btn_finish.text = "← 返回 (finish)"
	btn_finish.pressed.connect(_on_finish)
	inner.add_child(btn_finish)

	var btn_toast = Button.new()
	btn_toast.text = "◉ Detail 发 Toast"
	btn_toast.pressed.connect(_on_toast)
	inner.add_child(btn_toast)

	var btn_dialog = Button.new()
	btn_dialog.text = "◈ Detail 弹出 Dialog"
	btn_dialog.pressed.connect(_on_dialog)
	inner.add_child(btn_dialog)

	# ==== 新增: Flag 测试按钮 ====

	var sep = HSeparator.new()
	inner.add_child(sep)

	var flag_label = Label.new()
	flag_label.text = "—— Flag 测试（从 Detail） ——"
	flag_label.add_theme_font_size_override("font_size", 14)
	flag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(flag_label)

	var btn_reorder = Button.new()
	btn_reorder.text = "⇅ FLAG_REORDER_TO_FRONT: 把 main 移回栈顶"
	btn_reorder.pressed.connect(_on_flag_reorder)
	inner.add_child(btn_reorder)

	var btn_no_hist = Button.new()
	btn_no_hist.text = "☍ FLAG_NO_HISTORY: 再开一个不留痕 detail"
	btn_no_hist.pressed.connect(_on_flag_no_history)
	inner.add_child(btn_no_hist)

	var btn_owner_test = Button.new()
	btn_owner_test.text = "▓ finish() 清理归属 Dialog+Toast"
	btn_owner_test.pressed.connect(_on_owner_cleanup)
	inner.add_child(btn_owner_test)


func _on_finish() -> void:
	show_toast(Context.make_toast("详情页关闭", 1.5))
	finish()


func _on_toast() -> void:
	show_toast(Context.make_toast("来自 DetailActivity 的 Toast!", 2.0))


func _on_dialog() -> void:
	var it = Intent.new()
	it.action = "confirm_dialog"
	it.extras = {"title": "来自 Detail", "message": "Detail 弹出的确认框"}
	show_dialog(it)


# ======== 从 Detail 测试 Flag/owner ========

func _on_flag_reorder() -> void:
	print("[DetailActivity] 测试 FLAG_REORDER_TO_FRONT: 把 main 移回栈顶")
	var it = Intent.new(); it.action = "main"
	it.set_flag(Intent.FLAG_REORDER_TO_FRONT)
	start_activity(it)


func _on_flag_no_history() -> void:
	print("[DetailActivity] 测试 FLAG_NO_HISTORY: 再开不留痕 detail")
	var it = Intent.new(); it.action = "detail"
	it.set_flag(Intent.FLAG_NO_HISTORY)
	it.extras = {"id": 999, "from": "no_history_from_detail"}
	start_activity(it)
	show_toast(Context.make_toast("NO_HISTORY detail, 离开时自动销毁", 2.0))


func _on_owner_cleanup() -> void:
	print("[DetailActivity] 测试 finish() 触发 owner 清理")
	# 弹 Dialog（owner=this DetailActivity）
	var it = Intent.new(); it.action = "confirm_dialog"
	it.extras = {"title": "属 Detail 的 Dialog", "message": "此 Dialog 随 Detail finish 一起关闭"}
	show_dialog(it)
	# 显示 Dialog 1 秒后 finish
	await get_tree().create_timer(1.0).timeout
	print("[DetailActivity] 调用 finish()...")
	finish()
