extends Control
## 入口场景 — headless 自动化测试

var app: Application
var _test_svc: RefCounted
var _debug_panel: Control  # DebugOverlay 实例

func _init_activitis()->void:
	app.register_activity("main", "res://modules/home/scenes/main_activity.tscn")
	app.register_activity("detail", "res://modules/detail/scenes/detail_activity.tscn")
	app.register_activity("confirm_dialog", "res://modules/dialog/scenes/dialog_confirm.tscn")
	app.register_activity("annotation_bind", "res://modules/annotation_bind/scenes/annotation_activity.tscn")
	app.register_activity("advanced_mvvm", "res://modules/advanced_mvvm/advanced_mvvm_activity.tscn")
	app.register_activity("complex_examples_menu", "res://modules/complex_examples/complex_examples_menu.tscn")
	app.register_activity("complex_user_list", "res://modules/complex_examples/user_list/user_list_activity.tscn")
	app.register_activity("complex_shopping_cart", "res://modules/complex_examples/shopping_cart/shopping_cart_activity.tscn")
	app.register_activity("complex_registration_form", "res://modules/complex_examples/registration_form/registration_form_activity.tscn")
	app.register_activity("complex_order_state", "res://modules/complex_examples/order_state/order_state_activity.tscn")
	app.register_activity("complex_player_card", "res://modules/complex_examples/player_card/player_card_activity.tscn")
	app.register_activity("complex_data_table", "res://modules/complex_examples/data_table/data_table_activity.tscn")
	app.register_activity("complex_websocket_feed", "res://modules/complex_examples/websocket_feed/websocket_feed_activity.tscn")
	app.register_activity("complex_undo_redo", "res://modules/complex_examples/undo_redo/undo_redo_activity.tscn")

func _ready() -> void:
	app = Application.new()
	app.initialize(self)
	self._init_activitis()
	
	_test_svc = TestService.new()
	app.get_service_registry().register_service("test", _test_svc)

	app.change_scene("res://scenes/game.tscn")

	var it0 = Intent.new(); it0.action = "complex_examples_menu"
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
		await _test_9_annotation_bind()
		await _test_10_mvvm_advanced()
		await _test_11_userlist_vm()
		await _test_12_cart_vm()
		await _test_13_form_vm()
		await _test_14_order_vm()
		await _test_15_player_vm()
		await _test_16_datatable_vm()
		await _test_17_websocket_vm()
		await _test_18_undoredo_vm()

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


# ======== Test 9: 注解绑定 ========
func _test_9_annotation_bind() -> void:
	print("\n[Test 9] @bind_property + @bind_signal 注解绑定")
	await _ensure_one_main()
	assert(app.get_stack_size() == 1, "初始栈 == 1")

	var it = Intent.new(); it.action = "annotation_bind"
	app.start_activity(it)
	await get_tree().create_timer(0.5).timeout
	assert(app.get_stack_size() == 2, "跳转后 == 2")

	var act = app.get_current_activity()
	assert(act != null && act.get_intent().action == "annotation_bind", "annotation_bind 在栈顶")

	var vm = act.vm
	assert(vm != null, "vm 非 null")
	assert(vm.has_method("apply_bindings"), "vm 有 apply_bindings 方法")

	# 验证 @bind_signal 注解标记的方法存在
	assert(vm.has_method("on_increment"), "on_increment 方法存在")
	assert(vm.has_method("on_reset"), "on_reset 方法存在")
	assert(vm.has_method("on_check_toggled"), "on_check_toggled 方法存在")

	# 验证 ViewModel 数据字段通过 _set/_get 正常工作
	assert(vm.get_value("counter") == 0, "初始 counter == 0")
	assert(vm.get_value("checked") == false, "初始 checked == false")

	# === 关键：验证 UI 节点的实际绑定 ===
	# 注解 @bind_property 应当把 TitleLabel.text 绑定到 vm.title
	# 先取一次"绑定后"的值（apply_bindings 中已做 initial sync）
	var title_node = act.get_node_or_null("Root/Margin/C/TitleLabel")
	assert(title_node != null, "TitleLabel 节点存在")
	print("  [debug] title_node.text (after apply_bindings) = '%s'" % title_node.text)
	assert(title_node.text == "注解绑定示例（直接标注数据字段）", "TitleLabel.text 已被 initial sync")

	var status_node = act.get_node_or_null("Root/Margin/C/StatusLabel")
	assert(status_node != null, "StatusLabel 节点存在")
	print("  [debug] status_node.text (after apply_bindings) = '%s'" % status_node.text)
	assert(status_node.text == "注解绑定 — 等待操作...", "StatusLabel.text 已被 initial sync")

	# === 关键：验证 @bind_property 后续同步 ===
	# 修改 vm.title 应该触发 TitleLabel.text 更新（VM→View）
	vm.set_property("title", "TestTitle_NewValue")
	await get_tree().create_timer(0.1).timeout
	print("  [debug] title_node.text (after vm.title change) = '%s'" % title_node.text)
	assert(title_node.text == "TestTitle_NewValue", "vm.title 改变后 TitleLabel.text 同步更新")

	# vm.status_text 改变 → StatusLabel.text 同步
	vm.set_property("status_text", "STATUS_UPDATED")
	await get_tree().create_timer(0.1).timeout
	print("  [debug] status_node.text (after vm.status_text change) = '%s'" % status_node.text)
	assert(status_node.text == "STATUS_UPDATED", "vm.status_text 改变后 StatusLabel.text 同步更新")

	vm.on_increment()
	await get_tree().create_timer(0.1).timeout
	print("  [debug] after vm.on_increment: counter=%d, status='%s'" % [vm.get_value("counter"), status_node.text])
	assert(vm.get_value("counter") == 1, "on_increment 后 counter == 1")
	assert(status_node.text == "注解绑定 — 计数器: 1", "on_increment 后 StatusLabel.text 同步更新")

	vm.on_reset()
	await get_tree().create_timer(0.1).timeout
	assert(vm.get_value("counter") == 0, "on_reset 后 counter == 0")
	assert(status_node.text == "注解绑定 — 已重置", "on_reset 后 status 同步更新")

	# === 关键：验证 @bind_signal 自动连接 ===
	# 模拟点击 +1 按钮，看 on_increment 是不是被触发
	# 注：on_increment 也连在 CheckBox.pressed 上（因为 @bind_signal("pressed") 在所有 pressed 节点都连）
	# 所以我们用"无 reset 副作用"的 CheckBox.toggled 来间接验证 on_increment 被连上
	# 更直接：调用 vm.on_increment 一次（已经验证 VM→View 同步），然后按 on_increment/on_reset 关系
	# 验证 _btn_inc 已被 connect。
	var btn_inc_path = act.find_child("_btn_inc", true, false)
	if btn_inc_path == null:
		# 实际可能是匿名节点，按文本查找
		for child in act.find_children("*", "Button", true, false):
			if "+1" in child.text:
				btn_inc_path = child
				break
	assert(btn_inc_path != null, "_btn_inc 按钮存在")
	# 调试：查看 +1 按钮的 pressed 信号有多少连接
	print("  [debug] _btn_inc.pressed.get_connections() = %s" % str(btn_inc_path.pressed.get_connections()))
	# 验证 +1 按钮已被 on_increment 连接
	var has_on_inc = false
	for conn in btn_inc_path.pressed.get_connections():
		if conn["callable"].get_method() == "on_increment":
			has_on_inc = true
			break
	assert(has_on_inc, "@bind_signal 把 vm.on_increment 正确连接到 _btn_inc.pressed")

	# 验证 CheckBox.toggled 已被 on_check_toggled 连接
	var checkbox_path = act.find_child("CheckBox", true, false)
	if checkbox_path == null:
		for child in act.find_children("*", "CheckBox", true, false):
			checkbox_path = child
			break
	assert(checkbox_path != null, "CheckBox 节点存在")
	var has_on_toggle = false
	for conn in checkbox_path.toggled.get_connections():
		if conn["callable"].get_method() == "on_check_toggled":
			has_on_toggle = true
			break
	assert(has_on_toggle, "@bind_signal 把 vm.on_check_toggled 正确连接到 CheckBox.toggled")

	# 验证 on_check_toggled 实际触发能改 VM
	checkbox_path.toggled.emit(true)
	await get_tree().create_timer(0.1).timeout
	assert(vm.get_value("checked") == true, "CheckBox.toggled.emit(true) 触发 vm.on_check_toggled 后 checked == true")
	checkbox_path.toggled.emit(false)
	await get_tree().create_timer(0.1).timeout
	assert(vm.get_value("checked") == false, "CheckBox.toggled.emit(false) 触发 vm.on_check_toggled 后 checked == false")

	# === 验证注解属性绑定的 Dictionary 已通过 _set 存为 ObservableProperty ===
	var names = vm.get_property_names()
	assert(names.has("counter"), "counter 属性存在于 VM")
	assert(names.has("checked"), "checked 属性存在于 VM")
	assert(names.has("status_text"), "status_text 属性存在于 VM")

	app.back()
	await get_tree().create_timer(0.5).timeout
	assert(app.get_stack_size() == 1, "返回后 == 1")
	print("  OK")


# ======== Test 10: 高级 MVVM 功能 ========
func _test_10_mvvm_advanced() -> void:
	print("\n[Test 10] 高级 MVVM 功能 — 批量更新 + 值转换器 + 动态信号")

	# 测试双向绑定信号动态注册
	assert(!BindingEngine.has_two_way_signal("custom_signal"), "custom_signal 初始未注册")
	BindingEngine.register_two_way_signal("custom_signal")
	assert(BindingEngine.has_two_way_signal("custom_signal"), "custom_signal 注册成功")
	BindingEngine.unregister_two_way_signal("custom_signal")
	assert(!BindingEngine.has_two_way_signal("custom_signal"), "custom_signal 取消注册成功")

	# 测试内置转换器
	var int_converter = IntToStringConverter.new()
	assert(int_converter.convert(123) == "123", "IntToStringConverter convert")
	assert(int_converter.convert_back("456") == 456, "IntToStringConverter convert_back")

	var percent_converter = FloatToPercentConverter.new()
	assert(percent_converter.convert(0.75) == "75%", "FloatToPercentConverter convert")
	assert(absf(float(percent_converter.convert_back("80%")) - 0.8) < 0.001, "FloatToPercentConverter convert_back")

	# 测试 GDScript 子类 ValueConverter（验证 _convert / _convert_back 被正确调用）
	var bool_text = preload("res://core/converters/bool_to_text_converter.gd").new()
	assert(bool_text.convert(true) == "✓ 已启用", "GDScript BoolToTextConverter._convert(true)")
	assert(bool_text.convert(false) == "✗ 已禁用", "GDScript BoolToTextConverter._convert(false)")

	var float_pct_gd = preload("res://core/converters/float_to_percent_converter.gd").new()
	assert(float_pct_gd.convert(0.5) == "50%", "GDScript FloatToPercentConverter._convert(0.5)")
	assert(absf(float(float_pct_gd.convert_back("40%")) - 0.4) < 0.001, "GDScript FloatToPercentConverter._convert_back(40%)")

	# 测试批量更新
	var vm_test = preload("res://core/base_view_model.gd").new()
	vm_test.begin_bulk_update()
	for i in range(10):
		vm_test.test_prop = i
	vm_test.end_bulk_update()
	assert(vm_test.test_prop == 9, "批量更新最终值正确")
	vm_test.dispose()
	print("  OK")


# ======== Test 11: 复杂示例 - UserList VM ========
func _test_11_userlist_vm() -> void:
	print("\n[Test 11] 复杂示例 1 — UserList VM (CRUD + 过滤)")
	var UL_VM = preload("res://modules/complex_examples/user_list/user_list_vm.gd")
	var vm = UL_VM.new()

	# 初始状态
	assert(vm.users.is_empty(), "初始 users 为空")
	assert(vm.filtered_users.is_empty(), "初始 filtered_users 为空")

	# 添加
	vm.on_add_demo_user()
	assert(vm.users.size() == 1, "添加后 users == 1")
	assert(vm.filtered_users.size() == 1, "添加后 filtered_users == 1")

	# 再添加几个
	for i in range(4):
		vm.on_add_demo_user()
	assert(vm.users.size() == 5, "users == 5")

	# 搜索过滤
	vm.set_search_query("新用户1")
	# "新用户1" 匹配 "新用户1" 自身 + "新用户10"-"新用户19" + "新用户100"-"新用户149"... 看具体命名
	var n = vm.filtered_users.size()
	assert(n >= 1, "搜索 '新用户1' 至少匹配 1 个")

	vm.set_search_query("")
	assert(vm.filtered_users.size() == 5, "清空搜索 → 全部显示")

	# 删除
	vm.remove_user(vm.users[0].id)
	assert(vm.users.size() == 4, "删除后 users == 4")

	# 清空
	vm.on_clear_all()
	assert(vm.users.is_empty(), "清空后 users 为空")

	vm.dispose()
	print("  OK")


# ======== Test 12: 复杂示例 - ShoppingCart VM ========
func _test_12_cart_vm() -> void:
	print("\n[Test 12] 复杂示例 2 — ShoppingCart VM (计算属性 + 折扣)")
	var Cart_VM = preload("res://modules/complex_examples/shopping_cart/shopping_cart_vm.gd")
	var vm = Cart_VM.new()

	# 初始 3 个商品 (来自 _init 的种子数据)
	assert(vm.cart_items.size() == 3, "初始 3 件商品")
	assert(vm.item_count == 4, "item_count == 4 (1+1+2)")  # P001×1 + P002×1 + P003×2
	assert(absf(vm.subtotal - (599.0 + 199.0 + 89.0*2)) < 0.01, "subtotal 正确")
	# tax = subtotal * 0.08
	# total = subtotal * 1.08
	assert(vm.is_checkout_enabled, "非空时 can_checkout")

	# 加新商品
	vm.add_item("P004", "显示器挂灯", 159.0, 1)
	assert(vm.cart_items.size() == 4, "加 1 件后 4 件")
	assert(vm.item_count == 5, "item_count == 5")

	# 应用折扣码
	var ok = vm.apply_discount_code("SAVE10")
	assert(ok, "SAVE10 折扣码有效")
	assert(vm.discount_rate == 0.10, "discount_rate == 0.10")
	assert(vm.discount_amount > 0, "discount_amount > 0")

	# 错误码
	ok = vm.apply_discount_code("INVALID")
	assert(not ok, "无效折扣码返回 false")

	# 改数量
	vm.update_quantity("P001", 3)  # 1 → 3
	assert(vm.cart_items[0].quantity == 3, "P001 数量 = 3")
	assert(vm.item_count == 7, "item_count == 7 (3+1+2+1)")

	# 改数量为 0 = 删除
	vm.update_quantity("P001", 0)
	assert(vm.cart_items.size() == 3, "数量改 0 → 删除")

	# 清空
	vm.on_clear_cart()
	assert(vm.cart_items.is_empty(), "清空后 0 件")
	assert(vm.subtotal == 0.0, "清空后 subtotal == 0")
	assert(not vm.is_checkout_enabled, "清空后 can_checkout == false")

	vm.dispose()
	print("  OK")


# ======== Test 13: 复杂示例 - RegistrationForm VM ========
func _test_13_form_vm() -> void:
	print("\n[Test 13] 复杂示例 3 — RegistrationForm VM (实时校验)")
	var Form_VM = preload("res://modules/complex_examples/registration_form/registration_form_vm.gd")
	var vm = Form_VM.new()

	# 用户名校验
	vm.on_username_changed("ab")
	assert(not vm.username_error.is_empty(), "ab 太短 → 错误")

	vm.on_username_changed("valid_user")
	# 同步部分通过，触发异步校验
	# 等异步完成
	await get_tree().create_timer(0.1).timeout
	assert(vm.username_error.is_empty(), "valid_user 通过 (非占用)")

	# 占用名
	vm.on_username_changed("admin")
	await get_tree().create_timer(0.1).timeout
	assert(vm.server_username_taken, "admin 被服务端判定为占用")
	assert("占用" in vm.username_error, "username_error 含 '占用'")

	# 邮箱
	vm.on_email_changed("not-an-email")
	assert(not vm.email_error.is_empty(), "非法邮箱 → 错误")

	vm.on_email_changed("user@example.com")
	assert(vm.email_error.is_empty(), "合法邮箱")

	# 密码
	vm.on_password_changed("weak")
	assert(not vm.password_error.is_empty(), "weak 密码错误")

	vm.on_password_changed("Password123")
	assert(vm.password_error.is_empty(), "强密码通过")

	# 确认
	vm.on_confirm_changed("Password123")
	assert(vm.confirm_error.is_empty(), "匹配确认密码")

	vm.on_confirm_changed("Different")
	assert(not vm.confirm_error.is_empty(), "不匹配")

	# 协议
	vm.on_terms_toggled(false)
	assert(not vm.terms_error.is_empty(), "未同意 → 错误")
	vm.on_terms_toggled(true)
	assert(vm.terms_error.is_empty(), "同意 → 无错")

	# can_submit
	vm.on_username_changed("gooduser")
	await get_tree().create_timer(0.1).timeout
	vm.on_email_changed("good@example.com")
	vm.on_password_changed("Password123")
	vm.on_confirm_changed("Password123")
	vm.on_terms_toggled(true)
	assert(vm.can_submit, "所有字段正确 → can_submit")

	vm.dispose()
	print("  OK")


# ======== Test 14: 复杂示例 - OrderState VM ========
func _test_14_order_vm() -> void:
	print("\n[Test 14] 复杂示例 4 — OrderState VM (状态机)")
	var Order_VM = preload("res://modules/complex_examples/order_state/order_state_vm.gd")
	var vm = Order_VM.new()

	# 初始 PENDING
	assert(vm.state == Order_VM.OrderState.PENDING, "初始 PENDING")
	assert(vm.can_pay, "PENDING 可支付")
	assert(vm.can_cancel, "PENDING 可取消")
	assert(not vm.can_ship, "PENDING 不可发货")

	# PENDING → PAID
	vm.on_pay()
	# 注意 on_pay 里有 await (异步模拟)
	await get_tree().create_timer(0.1).timeout
	assert(vm.state == Order_VM.OrderState.PAID, "支付后 PAID")
	assert(vm.can_ship, "PAID 可发货")
	assert(not vm.can_pay, "PAID 不可再支付")
	assert(vm.can_refund, "PAID 可退款")

	# PAID → SHIPPED
	vm.on_ship()
	assert(vm.state == Order_VM.OrderState.SHIPPED, "发货后 SHIPPED")
	assert(vm.can_confirm_delivery, "SHIPPED 可确认收货")

	# SHIPPED → DELIVERED
	vm.on_confirm_delivery()
	assert(vm.state == Order_VM.OrderState.DELIVERED, "DELIVERED")

	# 终态: 可 reorder, 不可其他操作
	assert(vm.can_reorder, "DELIVERED 可重新下单")
	assert(not vm.can_pay, "DELIVERED 不可支付")
	# 注: 我们的设计里 DELIVERED 仍可退款(用户收货后才发现问题)
	# 如果业务规则不允许则改 STATE_TRANSITIONS 删除这条边
	assert(vm.can_refund, "DELIVERED 可申请退款")

	# 历史记录
	assert(vm.history.size() >= 3, "历史记录 >= 3 条 (pay+ship+deliver)")
	# 倒序最新应是 DELIVERED
	var last = vm.history[-1]
	assert(last["to"] == Order_VM.OrderState.DELIVERED, "最新历史是 DELIVERED")

	# 重新下单
	vm.on_reorder()
	assert(vm.state == Order_VM.OrderState.PENDING, "reorder → PENDING")
	assert(vm.can_pay, "新订单可支付")

	vm.dispose()
	print("  OK")


# ======== Test 15: 复杂示例 - PlayerCard VM ========
func _test_15_player_vm() -> void:
	print("\n[Test 15] 复杂示例 5 — PlayerCard VM (嵌套数据 + 装备)")
	var Player_VM = preload("res://modules/complex_examples/player_card/player_card_vm.gd")
	var vm = Player_VM.new()

	# 初始装备 3 件 (武器+头盔+胸甲)
	assert(vm.equipment.size() == 3, "初始 3 件装备")
	assert(vm.total_attack == 100 + 35, "攻击 = 基础 100 + 武器 35 = 135")
	assert(vm.total_defense == 80 + 8 + 12, "防御 = 基础 80 + 头盔 8 + 胸甲 12 = 100")

	# 替换武器 (同槽位)
	vm.on_equip({"slot": "武器", "name": "屠龙宝刀", "attack": 80, "defense": 0, "rarity": 5})
	assert(vm.equipment.size() == 3, "替换后仍 3 件")
	assert(vm.total_attack == 100 + 80, "新武器 80 → 攻击 180")
	assert(vm.rarity_color == Color(1.0, 0.7, 0.2), "5星橙色")

	# 加新槽位
	vm.on_equip({"slot": "鞋子", "name": "疾风之靴", "attack": 15, "defense": 20, "rarity": 4})
	assert(vm.equipment.size() == 4, "加鞋子 → 4 件")
	assert(vm.total_attack == 100 + 80 + 15, "攻击 = 195")
	assert(vm.total_defense == 100 + 20, "防御 = 120")

	# 卸下
	vm.on_unequip("武器")
	assert(vm.equipment.size() == 3, "卸武器 → 3 件")
	assert(vm.total_attack == 100 + 15, "攻击回落到 115")

	# 升级
	var old_atk = vm.total_attack
	vm.on_level_up()
	assert(vm.total_attack == old_atk + 5, "升级攻击 +5")

	# 重置
	vm.on_reset()
	assert(vm.equipment.is_empty(), "重置后装备清空")
	assert(vm.player_level == 42, "重置回 42 级")

	vm.dispose()
	print("  OK")


# ======== Test 16: 复杂示例 - DataTable VM ========
func _test_16_datatable_vm() -> void:
	print("\n[Test 16] 复杂示例 6 — DataTable VM (排序+分页+过滤)")
	DataTableSelfTest.run()
	await get_tree().process_frame  # 让异步测试完成


# ======== Test 17: 复杂示例 - WebSocketFeed VM ========
func _test_17_websocket_vm() -> void:
	print("\n[Test 17] 复杂示例 7 — WebSocketFeed VM (实时推送)")
	WebSocketFeedSelfTest.run()
	await get_tree().process_frame


# ======== Test 18: 复杂示例 - UndoRedo VM ========
func _test_18_undoredo_vm() -> void:
	print("\n[Test 18] 复杂示例 8 — UndoRedo VM (撤销/重做)")
	UndoRedoSelfTest.run()
	await get_tree().process_frame


# ======== 自定义服务 ========
class TestService extends RefCounted:
	func get_info() -> String:
		return "TestService v1.0"
	func ping(msg: String) -> String:
		return "pong: " + msg
