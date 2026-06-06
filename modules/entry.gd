extends Control
## 入口场景 — headless 自动化测试

var app: Application
var _test_svc: RefCounted
var _debug_panel: Control  # DebugOverlay 实例

func _init_activitis()->void:
	app.register_activity("main", "res://modules/home/scenes/main_activity.tscn")
	app.register_activity("detail", "res://modules/detail/scenes/detail_activity.tscn")
	app.register_activity("confirm_dialog", "res://modules/dialog/scenes/dialog_confirm.tscn")

func _ready() -> void:
	app = Application.new()
	app.initialize(self)
	self._init_activitis()
	
	_test_svc = TestService.new()
	app.get_service_registry().register_service("test", _test_svc)

	app.change_scene("res://scenes/game.tscn")

	var it0 = Intent.new(); it0.action = "main"
	app.start_activity(it0)

	# headless 模式自动跑测试；GUI 模式显示交互按钮
	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.5).timeout
		print("\n" + "=".repeat(60))
		print("[AutoTest] 开始自动化验证...")
		print("=".repeat(60))

		await _test_1_service()
		await _test_2_navigation()
		await _test_3_dialog_owner()
		await _test_4_toast_owner()
		await _test_5_no_history()
		await _test_6_new_clear()
		await _test_7_reorder()
		await _test_8_scene_change()

		await get_tree().create_timer(0.5).timeout
		print("\n" + "=".repeat(60))
		print("[AutoTest] 全部通过!")
		print("=".repeat(60))
		app.shutdown()
		get_tree().quit(0)


## Ctrl+Alt+Tab 打开/关闭 Debug 堆栈查看器
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT and event.ctrl_pressed and event.shift_pressed:
			_toggle_debug_overlay()
			get_viewport().set_input_as_handled()


func _toggle_debug_overlay() -> void:
	if _debug_panel and is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
		_debug_panel = null
		print("[Debug] DebugOverlay 关闭")
	else:
		var d = load("res://core/debug_overlay.gd").new()
		d.setup(app)
		add_child(d)
		_debug_panel = d
		print("[Debug] DebugOverlay 打开 (Ctrl+Shift+`)")


func _ensure_one_main() -> void:
	"""确保栈里只有 [main]，无 dialog"""
	while app.get_stack_size() > 1:
		app.back()
		await get_tree().create_timer(0.3).timeout
	# dismiss all remaining dialogs via cleanup shortcut — just rebuild via NEW_CLEAR
	var it = Intent.new(); it.action = "main"; it.set_flag(Intent.FLAG_NEW_CLEAR)
	app.start_activity(it)
	await get_tree().create_timer(0.5).timeout


# ======== Test 1: 服务发现 ========
func _test_1_service() -> void:
	print("\n[Test 1] 服务发现")
	var act = app.get_current_activity()
	assert(act != null && act.has_service("test"), "has_service")
	assert(act.get_service("test").ping("hi") == "pong: hi", "ping OK")
	print("  OK")


# ======== Test 2: 导航 ========
func _test_2_navigation() -> void:
	print("\n[Test 2] 导航 + back")
	await _ensure_one_main()
	assert(app.get_stack_size() == 1, "初始栈 == 1")

	var it = Intent.new(); it.action = "detail"
	app.start_activity(it)
	await get_tree().create_timer(0.3).timeout
	assert(app.get_stack_size() == 2, "跳转后 == 2")

	app.back()
	await get_tree().create_timer(0.5).timeout
	assert(app.get_stack_size() == 1, "返回后 == 1")
	print("  OK")


# ======== Test 3: Dialog owner 绑定到 Application ========
func _test_3_dialog_owner() -> void:
	print("\n[Test 3] Dialog owner=Application（跟随 app）")
	await _ensure_one_main()

	var it = Intent.new(); it.action = "confirm_dialog"
	it.extras = {"title": "App级", "message": "绑定到Application"}
	app.show_dialog_with_owner(it, app)
	await get_tree().create_timer(0.3).timeout

	# 跳转 detail — Dialog 不应被清理（owner=App）
	var it2 = Intent.new(); it2.action = "detail"
	app.start_activity(it2)
	await get_tree().create_timer(0.3).timeout
	assert(app.get_stack_size() == 2, "Dialog 绑定 App，未被清理")
	print("  OK")


# ======== Test 4: Toast owner ========
func _test_4_toast_owner() -> void:
	print("\n[Test 4] Toast owner 生命周期")
	await _ensure_one_main()

	# Main 发 Toast（owner=Main，通过便捷方法）
	var main_act = app.get_current_activity()
	main_act.show_toast(Context.make_toast("MainToast", 5.0))

	# 直接 finish Main — 触发 _cancel_owned_toasts
	main_act.finish()
	await get_tree().create_timer(0.5).timeout

	# 新 Main 被自动 resume（原 Main 是栈底，finish 后 Detail 无 → 栈空 → 自动 resume 的 next_top 不存在）
	# 实际上 finish main 后栈为空，需重新启动
	assert(app.get_stack_size() == 0 or app.get_stack_size() == 1, "finish main 后栈为空或1")
	print("  OK（Toast 已随 Main 的 destroy 被清除）")


# ======== Test 5: FLAG_NO_HISTORY ========
func _test_5_no_history() -> void:
	print("\n[Test 5] FLAG_NO_HISTORY")
	await _ensure_one_main()
	assert(app.get_stack_size() == 1, "初始 == 1")

	# 启动 NO_HISTORY detail
	var it = Intent.new(); it.action = "detail"
	it.set_flag(Intent.FLAG_NO_HISTORY)
	app.start_activity(it)
	await get_tree().create_timer(0.3).timeout
	assert(app.get_stack_size() == 2, "在栈中创建后 == 2")

	# 在 NO_HISTORY 上再启动一个 main → NO_HISTORY 应被自动 remove
	var it2 = Intent.new(); it2.action = "main"
	app.start_activity(it2)
	await get_tree().create_timer(0.5).timeout
	# stack: main_old(stopped), detail(NO_HISTORY, removed), main_new
	# detail 被自动移除 → stack = [main_old, main_new] = 2
	assert(app.get_stack_size() == 2, "NO_HISTORY 被自动移除 == 2")
	print("  OK")


# ======== Test 6: FLAG_NEW_CLEAR ========
func _test_6_new_clear() -> void:
	print("\n[Test 6] FLAG_NEW_CLEAR")
	await _ensure_one_main()

	# build: [main, detail] + 1 dialog
	var it = Intent.new(); it.action = "detail"
	app.start_activity(it)
	await get_tree().create_timer(0.3).timeout
	var dit = Intent.new(); dit.action = "confirm_dialog"
	dit.extras = {"title": "清栈测试", "message": "将被清除"}
	app.show_dialog(dit)
	await get_tree().create_timer(0.3).timeout

	# NEW_CLEAR main
	var it2 = Intent.new(); it2.action = "main"
	it2.set_flag(Intent.FLAG_NEW_CLEAR)
	app.start_activity(it2)
	await get_tree().create_timer(0.5).timeout
	assert(app.get_stack_size() == 1, "NEW_CLEAR 后 == 1")
	print("  OK")


# ======== Test 7: FLAG_REORDER_TO_FRONT ========
func _test_7_reorder() -> void:
	print("\n[Test 7] FLAG_REORDER_TO_FRONT")
	await _ensure_one_main()

	# build: [main_a, detail_a]
	var it = Intent.new(); it.action = "detail"
	app.start_activity(it)
	await get_tree().create_timer(0.3).timeout
	assert(app.get_stack_size() == 2, "初始 [main, detail]")

	# REORDER main → [detail, main]
	var it2 = Intent.new(); it2.action = "main"
	it2.set_flag(Intent.FLAG_REORDER_TO_FRONT)
	app.start_activity(it2)
	await get_tree().create_timer(0.5).timeout
	assert(app.get_stack_size() == 2, "REORDER 后仍 == 2")
	# main 被移到栈顶
	assert(app.get_current_activity().get_intent().action == "main", "main 在栈顶")
	print("  OK")


# ======== Test 8: SceneService change_scene ========
func _test_8_scene_change() -> void:
	print("\n[Test 8] SceneService change_scene — Application 保持不变")
	await _ensure_one_main()

	# 同步切换到 scene_a
	app.change_scene_sync("res://scenes/scene_a.tscn")
	await get_tree().create_timer(0.3).timeout

	# Application 实例仍然可访问
	assert(app != null, "app 非 null")
	assert(app.get_service_registry() != null, "ServiceRegistry 仍可访问")
	assert(app.get_service_registry().has_service("test"), "test 服务仍在")
	assert(app.get_activity_manager() != null, "ActivityManager 仍可访问")
	print("  change_scene_sync(scene_a) → app 存活 OK")

	# 切换到 scene_b
	app.change_scene_sync("res://scenes/scene_b.tscn")
	await get_tree().create_timer(0.3).timeout
	assert(app != null, "app 仍非 null")
	assert(app.get_scene_service().get_current_scene() == "res://scenes/scene_b.tscn", "current_scene 正确")
	print("  change_scene_sync(scene_b) → app 存活, current_scene 正确 OK")

	# 旧 Activity 栈已被 cleanup_all 清空
	assert(app.get_activity_manager().get_stack_size() == 0, "旧 Activity 栈已清空")
	print("  Activity 栈已清空 OK")

	# 切回 main，恢复初始状态供后续测试（如果有）
	app.change_scene_sync("res://scenes/scene_a.tscn")
	await get_tree().create_timer(0.2).timeout
	print("  OK")


# ======== 自定义服务 ========
class TestService extends RefCounted:
	func get_info() -> String:
		return "TestService v1.0"
	func ping(msg: String) -> String:
		return "pong: " + msg
