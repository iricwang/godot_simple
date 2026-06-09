extends Activity
## 首页 Activity — 测试 Context 便捷方法 + MVVM 绑定 + 服务发现 + 资源加载

var vm: ViewModel

# UI 引用
var _title_label: Label
var _counter_label: Label
var _progress_bar: ProgressBar
var _svc_label: Label
var _res_label: Label
var _btn_inc: Button
var _btn_dec: Button

func _on_create(saved_state: Dictionary) -> void:
	print("[MainActivity] _on_create")
	vm = preload("res://modules/home/main_vm.gd").new()

	# 转场: 从右侧滑入, 淡出退出
	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_RIGHT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.FADE; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()

	# === 测试 1: Context 静态方法做 MVVM 绑定 ===
	Context.bind_property(_title_label, "text", vm, "title")
	Context.bind_property(_counter_label, "text", vm, "status_text")
	Context.bind_property(_progress_bar, "value", vm, "progress")
	Context.bind_command(_btn_inc, "pressed", vm, "on_increment")
	Context.bind_command(_btn_dec, "pressed", vm, "on_decrement")
	print("[MainActivity] MVVM 绑定完成 ✓")

	# === 测试 2: 通过 get_context() 发现自定义服务 ===
	var svc = get_context().get_service("test")
	if svc and svc.has_method("get_info"):
		_svc_label.text = "服务: " + svc.get_info()
		print("[MainActivity] get_service('test') ✓")
	else:
		print("[MainActivity] ERROR: get_service('test') 失败")

	# === 测试 3: 资源异步加载 ===
	print("[MainActivity] 开始异步加载资源...")
	load_resource_async("res://icon.svg", func(res):
		if res:
			_res_label.text = "资源: " + res.resource_path.get_file()
			print("[MainActivity] 异步加载成功 ✓")
		else:
			_res_label.text = "资源: (无)"
			print("[MainActivity] WARN: icon.svg 不存在（demo 项目无此文件）")
	)


func _on_start() -> void:
	print("[MainActivity] _on_start")


func _on_resume() -> void:
	print("[MainActivity] _on_resume")


func _on_pause() -> void:
	print("[MainActivity] _on_pause")


func _on_stop() -> void:
	print("[MainActivity] _on_stop")


func _on_destroy() -> void:
	print("[MainActivity] _on_destroy")
	if vm:
		vm.dispose()


func _on_new_intent(intent: Intent) -> void:
	print("[MainActivity] _on_new_intent: ", intent.action)


func _on_back_pressed() -> bool:
	print("[MainActivity] _on_back_pressed — 在首页，不消费")
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
	_title_label.text = "首页"
	_title_label.add_theme_font_size_override("font_size", 28)
	inner.add_child(_title_label)

	_counter_label = Label.new()
	_counter_label.text = "..."
	_counter_label.add_theme_font_size_override("font_size", 16)
	inner.add_child(_counter_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.value = 0.5
	inner.add_child(_progress_bar)

	_svc_label = Label.new()
	_svc_label.text = "服务: ..."
	_svc_label.add_theme_font_size_override("font_size", 13)
	_svc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_svc_label)

	_res_label = Label.new()
	_res_label.text = "资源: 加载中..."
	_res_label.add_theme_font_size_override("font_size", 13)
	inner.add_child(_res_label)

	_btn_inc = Button.new()
	_btn_inc.text = "+1 (Context.bind_command)"
	_btn_inc.pressed.connect(_on_inc)
	inner.add_child(_btn_inc)

	_btn_dec = Button.new()
	_btn_dec.text = "-1 (Context.bind_command)"
	_btn_dec.pressed.connect(_on_dec)
	inner.add_child(_btn_dec)

	var btn_detail = Button.new()
	btn_detail.text = "▶ 跳转详情 (start_activity)"
	btn_detail.pressed.connect(_on_go_detail)
	inner.add_child(btn_detail)

	var btn_dialog = Button.new()
	btn_dialog.text = "◈ 弹出 Dialog (show_dialog)"
	btn_dialog.pressed.connect(_on_show_dialog)
	inner.add_child(btn_dialog)

	var btn_toast = Button.new()
	btn_toast.text = "◉ 显示 Toast (show_toast)"
	btn_toast.pressed.connect(_on_show_toast)
	inner.add_child(btn_toast)

	var btn_svc = Button.new()
	btn_svc.text = "◎ 测试 get_service / has_service"
	btn_svc.pressed.connect(_on_test_service)
	inner.add_child(btn_svc)

	var btn_handle = Button.new()
	btn_handle.text = "▣ 测试 get_resource_handle"
	btn_handle.pressed.connect(_on_test_handle)
	inner.add_child(btn_handle)

	var btn_back = Button.new()
	btn_back.text = "← back() 返回"
	btn_back.pressed.connect(_on_back)
	inner.add_child(btn_back)

	# ==== 新增: 注解绑定示例按钮 ====

	var btn_annotation = Button.new()
	btn_annotation.text = "⚡ 注解绑定示例 (@bind_property + @bind_signal)"
	btn_annotation.pressed.connect(_on_go_annotation)
	inner.add_child(btn_annotation)

	# ==== 新增: Flag 交互测试按钮 ====

	var sep = HSeparator.new()
	inner.add_child(sep)

	var flag_label = Label.new()
	flag_label.text = "—— 新增 Flag 测试 ——"
	flag_label.add_theme_font_size_override("font_size", 14)
	flag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(flag_label)

	var btn_no_hist = Button.new()
	btn_no_hist.text = "☍ FLAG_NO_HISTORY: 打开不留痕 detail"
	btn_no_hist.pressed.connect(_on_flag_no_history)
	inner.add_child(btn_no_hist)

	var btn_new_clear = Button.new()
	btn_new_clear.text = "☒ FLAG_NEW_CLEAR: 清栈开 main"
	btn_new_clear.pressed.connect(_on_flag_new_clear)
	inner.add_child(btn_new_clear)

	var btn_reorder = Button.new()
	btn_reorder.text = "⇅ FLAG_REORDER_TO_FRONT: detail→main"
	btn_reorder.pressed.connect(_on_flag_reorder)
	inner.add_child(btn_reorder)

	var sep2 = HSeparator.new()
	inner.add_child(sep2)

	var owner_label = Label.new()
	owner_label.text = "—— Dialog/Toast owner 测试 ——"
	owner_label.add_theme_font_size_override("font_size", 14)
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(owner_label)

	var btn_dlg_app = Button.new()
	btn_dlg_app.text = "◈ show_dialog_with_owner(app) — 不随 Activity 销毁"
	btn_dlg_app.pressed.connect(_on_dialog_owner_app)
	inner.add_child(btn_dlg_app)

	var btn_toast_app = Button.new()
	btn_toast_app.text = "◉ show_toast_with_owner(app) — 不随 Activity 销毁"
	btn_toast_app.pressed.connect(_on_toast_owner_app)
	inner.add_child(btn_toast_app)

	var btn_toast_custom = Button.new()
	btn_toast_custom.text = "★ 自定义 Toast 场景 (圆角+图标)"
	btn_toast_custom.pressed.connect(_on_toast_custom)
	inner.add_child(btn_toast_custom)

	var btn_test_cleanup = Button.new()
	btn_test_cleanup.text = "▓ finish() 触发 owner 清理"
	btn_test_cleanup.pressed.connect(_on_test_cleanup)
	inner.add_child(btn_test_cleanup)


# ---- 按钮回调 ----

func _on_inc() -> void:
	vm.counter += 1
	vm.status_text = "计数器: %d" % vm.counter


func _on_dec() -> void:
	vm.counter -= 1
	vm.status_text = "计数器: %d" % vm.counter


func _on_go_annotation() -> void:
	print("[MainActivity] 跳转到注解绑定示例")
	var ita = Intent.new()
	ita.action = "annotation_bind"
	start_activity(ita)
	show_toast(Context.make_toast("注解绑定示例 — @bind_property + @bind_signal + vm.apply_bindings()", 2.5))


func _on_go_detail() -> void:
	var it = Intent.new()
	it.action = "detail"
	it.extras = {"id": 42, "from": "main"}
	it.set_flag(Intent.FLAG_SINGLE_TOP)
	# === 测试 4: Activity 便捷方法 start_activity() ===
	start_activity(it)
	print("[MainActivity] start_activity(detail) ✓")


func _on_show_dialog() -> void:
	var it = Intent.new()
	it.action = "confirm_dialog"
	it.extras = {"title": "确认操作", "message": "这是来自 MainActivity 的消息"}
	# === 测试 5: Activity 便捷方法 show_dialog() ===
	show_dialog(it)
	print("[MainActivity] show_dialog(confirm_dialog) ✓")


func _on_show_toast() -> void:
	# === 测试 6: Context.make_toast() + Activity::show_toast() ===
	show_toast(Context.make_toast("来自 Activity 便捷方法的 Toast", 2.5))
	print("[MainActivity] show_toast(...) ✓")


func _on_test_service() -> void:
	# === 测试 7: has_service / get_service ===
	if has_service("test"):
		var svc = get_service("test")
		if svc and svc.has_method("ping"):
			var result = svc.ping("hello context")
			show_toast(Context.make_toast(result, 2.0))
			print("[MainActivity] has_service/get_service ✓ ", result)
	else:
		show_toast(Context.make_toast("服务未找到!", 2.0))
		print("[MainActivity] ERROR: has_service('test') false")


func _on_test_handle() -> void:
	# === 测试 8: get_resource_handle ===
	var handle = get_resource_handle("res://project.godot")
	if handle:
		show_toast(Context.make_toast("Handle: " + handle.get_path(), 2.0))
		print("[MainActivity] get_resource_handle ✓ path=", handle.get_path())


func _on_back() -> void:
	# === 测试 9: Activity 便捷方法 back() ===
	print("[MainActivity] back()...")
	back()


# ======== 新 Flag 交互测试回调 ========

func _on_flag_no_history() -> void:
	# FLAG_NO_HISTORY: 打开 detail, detail 离开时自动销毁
	print("[MainActivity] 测试 FLAG_NO_HISTORY: 打开不留痕 detail")
	var it = Intent.new(); it.action = "detail"
	it.extras = {"id": 998, "from": "no_history_test"}
	it.set_flag(Intent.FLAG_NO_HISTORY)
	start_activity(it)
	show_toast(Context.make_toast("NO_HISTORY detail 已打开，返回时自动销毁", 2.5))


func _on_flag_new_clear() -> void:
	# FLAG_NEW_CLEAR: 清栈后打开新 main
	print("[MainActivity] 测试 FLAG_NEW_CLEAR: 清栈重启 main")
	var it = Intent.new(); it.action = "main"
	it.set_flag(Intent.FLAG_NEW_CLEAR)
	start_activity(it)
	show_toast(Context.make_toast("栈已清空，main 重新启动", 2.0))


func _on_flag_reorder() -> void:
	# FLAG_REORDER_TO_FRONT: 先跳 detail 再 REORDER 回到 main
	print("[MainActivity] 测试 FLAG_REORDER_TO_FRONT")
	# 先跳到 detail
	var it = Intent.new(); 
	it.action = "detail"
	it.extras = {"id": 500, "from": "reorder_test"}
	start_activity(it)
	show_toast(Context.make_toast("已跳 detail，在 detail 中按 REORDER 返回 main", 3.0))


# ======== Dialog/Toast owner 绑定交互测试回调 ========

func _on_dialog_owner_app() -> void:
	# show_dialog_with_owner: owner=Application, 不会随 Activity 销毁
	print("[MainActivity] 测试 show_dialog_with_owner(app)")
	var the_app = get_context().get_application()
	var it = Intent.new(); it.action = "confirm_dialog"
	it.extras = {"title": "App 级 Dialog", "message": "owner=Application\n跳转其他 Activity 不会被清理"}
	the_app.show_dialog_with_owner(it, the_app)
	show_toast(Context.make_toast("Dialog owner=App → 不受 Activity 生命周期影响", 3.0))


func _on_toast_owner_app() -> void:
	# show_toast_with_owner: owner=Application
	print("[MainActivity] 测试 show_toast_with_owner(app)")
	var the_app = get_context().get_application()
	var toast = Context.make_toast("App 级 Toast — 不受 Activity 生命周期影响", 3.0)
	the_app.show_toast_with_owner(toast, the_app)
	show_toast(Context.make_toast("额外 Activity 级 Toast（跟随本 Activity）", 2.0))


func _on_toast_custom() -> void:
	# 自定义 Toast 场景
	print("[MainActivity] 测试自定义 Toast 场景")
	var toast = Context.make_toast("★ 自定义 Toast — 圆角+图标+半透明背景", 3.0)
	toast.set_custom_scene("res://core/scenes/toast_custom.tscn")
	show_toast(toast)


func _on_test_cleanup() -> void:
	# finish() 触发 _dismiss_owned_dialogs + _cancel_owned_toasts
	print("[MainActivity] 测试 finish() 触发 owner 清理")
	# 先弹一个 Dialog（owner=this Activity）
	var it = Intent.new(); it.action = "confirm_dialog"
	it.extras = {"title": "归属 Dialog", "message": "此 Dialog 随 Activity finish 一起关闭"}
	show_dialog(it)
	# 做个延迟后 finish，可以看到 Dialog 被自动清理
	await get_tree().create_timer(1.0).timeout
	print("[MainActivity] 调用 finish()，将自动清理归属 Dialog+Toast")
	finish()
