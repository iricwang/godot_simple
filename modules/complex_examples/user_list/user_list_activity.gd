extends Activity
## UserListActivity — 列表渲染示例
##
## 完整展示：
##   * 异步加载 (load_users_async)
##   * 列表重新渲染 (rebuild_list)
##   * 搜索过滤 (on_search_changed)
##   * 选中/删除/添加
##   * 加载状态显示

const UserListVM = preload("res://modules/complex_examples/user_list/user_list_vm.gd")
# OnlineStatusConverter 是 UserListVM 里的内嵌类
# 通过 UserListVM.OnlineStatusConverter 引用
# (不要单独 preload 路径，文件不存在)

var vm: UserListVM

# UI 引用
var _user_list_vb: VBoxContainer
var _search_edit: LineEdit
var _load_btn: Button
var _add_btn: Button
var _clear_btn: Button
var _status_label: Label
var _selected_label: Label

# 颜色 (用于在线状态)
const COLOR_ONLINE = Color(0.4, 1.0, 0.5)
const COLOR_OFFLINE = Color(0.6, 0.6, 0.6)
const COLOR_SELECTED_BG = Color(0.2, 0.4, 0.8, 0.3)


func _on_create(saved_state: Dictionary) -> void:
	vm = UserListVM.new()

	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_LEFT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.SLIDE_RIGHT; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()
	_bind_all()


func _setup_ui() -> void:
	var root_vb = VBoxContainer.new()
	root_vb.name = "Root"
	root_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vb.add_theme_constant_override("separation", 8)
	add_child(root_vb)

	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.07, 0.08, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 32)
	root_vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	margin.add_child(inner)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	inner.add_child(title_row)

	var title = Label.new()
	title.text = "📋 复杂示例 1 — 列表渲染 (User List)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：集合属性变化触发列表重建、搜索过滤、CRUD 操作"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# 工具栏
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	inner.add_child(toolbar)

	_load_btn = Button.new()
	_load_btn.text = "🔄 加载用户"
	toolbar.add_child(_load_btn)

	_add_btn = Button.new()
	_add_btn.text = "➕ 添加"
	toolbar.add_child(_add_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "🗑 清空"
	toolbar.add_child(_clear_btn)

	# 搜索框
	var search_row = HBoxContainer.new()
	inner.add_child(search_row)
	var search_lbl = Label.new()
	search_lbl.text = "🔍 搜索:"
	search_row.add_child(search_lbl)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "输入名字或邮箱过滤..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(_search_edit)

	# 状态标签
	_status_label = Label.new()
	_status_label.text = "准备..."
	inner.add_child(_status_label)

	# 选中显示
	_selected_label = Label.new()
	_selected_label.text = "(未选中)"
	_selected_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	inner.add_child(_selected_label)

	inner.add_child(HSeparator.new())

	# 滚动列表
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	_user_list_vb = VBoxContainer.new()
	_user_list_vb.name = "UserListVB"
	_user_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_user_list_vb.add_theme_constant_override("separation", 4)
	scroll.add_child(_user_list_vb)

	# 返回按钮
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _bind_all() -> void:
	# 命令绑定
	_load_btn.pressed.connect(_on_load_pressed)
	_add_btn.pressed.connect(_on_add_pressed)
	_clear_btn.pressed.connect(_on_clear_pressed)
	_search_edit.text_changed.connect(_on_search_changed)

	# 视图绑定 (单向：VM → View)
	# 监听 filtered_users 变化 → 重建列表
	vm.subscribe_property("filtered_users", _rebuild_list)
	vm.subscribe_property("status_message", _update_status)
	vm.subscribe_property("selected_user_id", _update_selected_label)


func _rebuild_list(_value) -> void:
	# 清空旧条目
	for child in _user_list_vb.get_children():
		child.queue_free()

	# 重新渲染
	if vm.filtered_users.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "（列表为空）"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_user_list_vb.add_child(empty_lbl)
		return

	for user in vm.filtered_users:
		_user_list_vb.add_child(_build_user_row(user))


func _build_user_row(user) -> Control:
	var row = HBoxContainer.new()
	row.name = "UserRow_%d" % user.id
	row.add_theme_constant_override("separation", 8)

	# 背景 (选中态)
	var bg = PanelContainer.new()
	bg.name = "BG"
	if user.id == vm.selected_user_id:
		var sb = StyleBoxFlat.new()
		sb.bg_color = COLOR_SELECTED_BG
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		bg.add_theme_stylebox_override("panel", sb)
	row.add_child(bg)

	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	bg.add_child(content)

	# 头像 (用首字母代替)
	var avatar = Label.new()
	avatar.text = "[%s]" % user.name.substr(0, 1)
	avatar.add_theme_font_size_override("font_size", 18)
	avatar.custom_minimum_size = Vector2(40, 0)
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(avatar)

	# 名字 + 邮箱
	var info_vb = VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info_vb)

	var name_lbl = Label.new()
	name_lbl.text = user.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	info_vb.add_child(name_lbl)

	var email_lbl = Label.new()
	email_lbl.text = user.email
	email_lbl.add_theme_font_size_override("font_size", 12)
	email_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vb.add_child(email_lbl)

	# 在线状态 (用 converter)
	var status_lbl = Label.new()
	# 直接调用 converter，避免 BindingEngine 开销（一次性渲染）
	var conv = UserListVM.OnlineStatusConverter.new()
	status_lbl.text = conv.convert(user.is_online)
	status_lbl.add_theme_color_override("font_color", COLOR_ONLINE if user.is_online else COLOR_OFFLINE)
	content.add_child(status_lbl)

	# 操作按钮
	var select_btn = Button.new()
	select_btn.text = "选中"
	select_btn.pressed.connect(_on_row_select.bind(user.id))
	content.add_child(select_btn)

	var del_btn = Button.new()
	del_btn.text = "删除"
	del_btn.pressed.connect(_on_row_delete.bind(user.id))
	content.add_child(del_btn)

	return row


func _update_status(msg) -> void:
	_status_label.text = str(msg)


func _update_selected_label(id) -> void:
	if typeof(id) != TYPE_INT or id < 0:
		_selected_label.text = "(未选中)"
		return
	_selected_label.text = "已选中用户 #%d" % id


# ---- 命令实现 ----

func _on_load_pressed() -> void:
	# 不能直接 await 跨方法 — 用普通函数调用，VM 内部用 await
	# 注意: 异步操作要在 VM 内部完成；这里只是触发
	if vm.is_loading:
		return
	# 启动异步加载
	_run_load_async()


func _run_load_async() -> void:
	# 触发 vm 异步加载。vm.load_users_async() 内部用 await。
	# 用 call_deferred 避免阻塞主线程
	vm.load_users_async()


func _on_add_pressed() -> void:
	vm.on_add_demo_user()


func _on_clear_pressed() -> void:
	vm.on_clear_all()


func _on_search_changed(text: String) -> void:
	vm.set_search_query(text)


func _on_row_select(id: int) -> void:
	vm.select_user(id)


func _on_row_delete(id: int) -> void:
	vm.remove_user(id)
	# 重建列表以移除该行
	_rebuild_list(null)


func _on_close_current_activity() -> void:
	finish()


func _on_back() -> void:
	finish()


# ---- 生命周期 ----

func _on_start() -> void:
	pass

func _on_resume() -> void:
	pass

func _on_pause() -> void:
	pass

func _on_stop() -> void:
	pass

func _on_destroy() -> void:
	if vm:
		vm.dispose()

func _on_back_pressed() -> bool:
	return false
