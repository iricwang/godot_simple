extends Activity
## WebSocketFeedActivity — WebSocket 实时数据推送
##
## 演示：
##   * 顶部状态栏 — 状态点 + 状态文本 + 延迟 + 未读数 + 连接/断开按钮
##   * 中间消息列表 — 滚动容器, 每条一行, server / self 颜色不同
##   * 底部发送区 — LineEdit + 发送 / 标记已读 / 清空 / 注入测试
##   * 订阅 VM 属性, UI 自动更新

const FeedVM = preload("res://modules/complex_examples/websocket_feed/websocket_feed_vm.gd")

var vm: FeedVM

# UI 引用
var _state_dot: Label
var _state_text: Label
var _latency_lbl: Label
var _unread_lbl: Label
var _connect_btn: Button
var _disconnect_btn: Button
var _messages_vb: VBoxContainer
var _send_edit: LineEdit
var _send_btn: Button
var _mark_read_btn: Button
var _clear_btn: Button
var _inject_btn: Button
var _status_lbl: Label

# 颜色
const COLOR_DOT_DISCONNECTED := Color(0.7, 0.3, 0.3)  # 红
const COLOR_DOT_CONNECTING  := Color(1.0, 0.85, 0.2)  # 黄
const COLOR_DOT_CONNECTED   := Color(0.3, 0.85, 0.3)  # 绿
const COLOR_DOT_ERROR       := Color(0.5, 0.5, 0.5)  # 灰
const COLOR_MSG_SERVER      := Color(0.5, 0.85, 1.0)
const COLOR_MSG_SELF        := Color(0.7, 1.0, 0.6)
const COLOR_MSG_MUTED       := Color(0.6, 0.6, 0.6)


func _on_create(saved_state: Dictionary) -> void:
	vm = FeedVM.new()

	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_LEFT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.SLIDE_RIGHT; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()
	_bind_all()
	# 初始快照
	_refresh_state()
	_refresh_messages()


func _setup_ui() -> void:
	var root_vb = VBoxContainer.new()
	root_vb.name = "Root"
	root_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vb.add_theme_constant_override("separation", 6)
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
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	root_vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	inner.add_child(title_row)

	var title = Label.new()
	title.text = "📡 复杂示例 7 — WebSocket 实时推送 (Mock)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：Mock 客户端 (Test Double) / 状态机 / 实时消息流 / 未读红点"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# 顶部状态栏
	inner.add_child(HSeparator.new())
	var status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	inner.add_child(status_row)

	_state_dot = Label.new()
	_state_dot.text = "●"
	_state_dot.add_theme_font_size_override("font_size", 24)
	_state_dot.add_theme_color_override("font_color", COLOR_DOT_DISCONNECTED)
	status_row.add_child(_state_dot)

	_state_text = Label.new()
	_state_text.text = "DISCONNECTED"
	_state_text.add_theme_font_size_override("font_size", 16)
	status_row.add_child(_state_text)

	status_row.add_child(VSeparator.new())

	_latency_lbl = Label.new()
	_latency_lbl.text = "延迟: -- ms"
	_latency_lbl.add_theme_color_override("font_color", COLOR_MSG_MUTED)
	status_row.add_child(_latency_lbl)

	_unread_lbl = Label.new()
	_unread_lbl.text = "未读: 0"
	_unread_lbl.add_theme_color_override("font_color", COLOR_MSG_MUTED)
	status_row.add_child(_unread_lbl)

	# 连接/断开按钮
	var conn_row = HBoxContainer.new()
	conn_row.add_theme_constant_override("separation", 8)
	inner.add_child(conn_row)

	_connect_btn = Button.new()
	_connect_btn.text = "🔌 连接"
	_connect_btn.pressed.connect(_on_connect_clicked)
	conn_row.add_child(_connect_btn)

	_disconnect_btn = Button.new()
	_disconnect_btn.text = "⛔ 断开"
	_disconnect_btn.pressed.connect(_on_disconnect_clicked)
	_disconnect_btn.disabled = true
	conn_row.add_child(_disconnect_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "未连接"
	_status_lbl.add_theme_color_override("font_color", COLOR_MSG_MUTED)
	conn_row.add_child(_status_lbl)

	# 消息列表
	inner.add_child(HSeparator.new())
	var list_title = Label.new()
	list_title.text = "💬 消息流:"
	list_title.add_theme_font_size_override("font_size", 14)
	inner.add_child(list_title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	_messages_vb = VBoxContainer.new()
	_messages_vb.add_theme_constant_override("separation", 2)
	_messages_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_messages_vb)

	# 底部发送区
	inner.add_child(HSeparator.new())
	var send_row = HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 6)
	inner.add_child(send_row)

	_send_edit = LineEdit.new()
	_send_edit.placeholder_text = "输入消息..."
	_send_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send_edit.text_submitted.connect(_on_send_submitted)
	send_row.add_child(_send_edit)

	_send_btn = Button.new()
	_send_btn.text = "📤 发送"
	_send_btn.pressed.connect(_on_send_clicked)
	send_row.add_child(_send_btn)

	# 操作按钮
	var act_row = HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)
	inner.add_child(act_row)

	_mark_read_btn = Button.new()
	_mark_read_btn.text = "🔔 标记已读"
	_mark_read_btn.pressed.connect(_on_mark_read_clicked)
	act_row.add_child(_mark_read_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "🧹 清空消息"
	_clear_btn.pressed.connect(_on_clear_clicked)
	act_row.add_child(_clear_btn)

	_inject_btn = Button.new()
	_inject_btn.text = "📨 注入测试消息"
	_inject_btn.pressed.connect(_on_inject_clicked)
	act_row.add_child(_inject_btn)

	# 返回
	inner.add_child(HSeparator.new())
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _bind_all() -> void:
	vm.subscribe_property("connection_state", _update_state)
	vm.subscribe_property("is_connected", _update_buttons)
	vm.subscribe_property("is_connecting", _update_buttons)
	vm.subscribe_property("messages", _refresh_messages)
	vm.subscribe_property("unread_count", _update_unread)
	vm.subscribe_property("last_message_preview", _update_preview)
	vm.subscribe_property("latency_ms", _update_latency)
	vm.subscribe_property("status_message", _update_status)
	vm.subscribe_property("send_text", _update_send_text)


# ---- 订阅回调 ----

func _update_state(_v) -> void:
	_refresh_state()


func _refresh_state() -> void:
	_state_text.text = vm.connection_state
	match vm.connection_state:
		"DISCONNECTED":
			_state_dot.add_theme_color_override("font_color", COLOR_DOT_DISCONNECTED)
		"CONNECTING":
			_state_dot.add_theme_color_override("font_color", COLOR_DOT_CONNECTING)
		"CONNECTED":
			_state_dot.add_theme_color_override("font_color", COLOR_DOT_CONNECTED)
		"ERROR":
			_state_dot.add_theme_color_override("font_color", COLOR_DOT_ERROR)
		_:
			_state_dot.add_theme_color_override("font_color", COLOR_DOT_DISCONNECTED)


func _update_buttons(_v) -> void:
	_connect_btn.disabled = vm.is_connected or vm.is_connecting
	_disconnect_btn.disabled = not vm.is_connected
	_send_btn.disabled = not vm.is_connected
	_send_edit.editable = vm.is_connected


func _refresh_messages(_v = null) -> void:
	for c in _messages_vb.get_children():
		c.queue_free()
	if vm.messages.is_empty():
		var empty = Label.new()
		empty.text = "（暂无消息 — 点击 📨 注入测试消息 或先连接后等待推送）"
		empty.add_theme_color_override("font_color", COLOR_MSG_MUTED)
		empty.add_theme_font_size_override("font_size", 11)
		_messages_vb.add_child(empty)
		return
	for msg in vm.messages:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var t = Label.new()
		t.text = "[" + str(msg.get("time", "")) + "]"
		t.add_theme_font_size_override("font_size", 11)
		t.add_theme_color_override("font_color", COLOR_MSG_MUTED)
		row.add_child(t)
		var sender_lbl = Label.new()
		var sender = str(msg.get("sender", "server"))
		sender_lbl.text = sender + ":"
		sender_lbl.add_theme_font_size_override("font_size", 12)
		if sender == "self":
			sender_lbl.add_theme_color_override("font_color", COLOR_MSG_SELF)
		else:
			sender_lbl.add_theme_color_override("font_color", COLOR_MSG_SERVER)
		row.add_child(sender_lbl)
		var content_lbl = Label.new()
		content_lbl.text = str(msg.get("content", ""))
		content_lbl.add_theme_font_size_override("font_size", 12)
		content_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(content_lbl)
		_messages_vb.add_child(row)


func _update_unread(v) -> void:
	var n = int(v)
	_unread_lbl.text = "未读: %d" % n
	if n > 0:
		_unread_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	else:
		_unread_lbl.add_theme_color_override("font_color", COLOR_MSG_MUTED)


func _update_preview(v) -> void:
	# 当前不单独显示 — 消息列表已展示
	pass


func _update_latency(v) -> void:
	var ms = int(v)
	if ms <= 0:
		_latency_lbl.text = "延迟: -- ms"
	else:
		_latency_lbl.text = "延迟: %d ms" % ms


func _update_status(v) -> void:
	_status_lbl.text = str(v)


func _update_send_text(v) -> void:
	# 外部 (VM) 主动清空时, 同步 LineEdit
	if _send_edit.text != str(v):
		_send_edit.text = str(v)


# ---- 命令 ----

func _on_connect_clicked() -> void:
	vm.connect_to_server()


func _on_disconnect_clicked() -> void:
	vm.disconnect_from_server()


func _on_send_clicked() -> void:
	# 同步输入框到 VM (用户在 UI 输入时不会直接改 VM, 走这条路径)
	vm.send_text = _send_edit.text
	vm.send_message()
	# VM 发送后 send_text 已被清空, 订阅会反向把 LineEdit 清掉


func _on_send_submitted(text: String) -> void:
	vm.send_text = text
	vm.send_message()


func _on_mark_read_clicked() -> void:
	vm.mark_all_read()


func _on_clear_clicked() -> void:
	vm.clear_messages()


func _on_inject_clicked() -> void:
	# 注入一条带时间戳的测试消息, 方便看效果
	var stamp = Time.get_time_dict_from_system()
	var text = "[server @ %02d:%02d:%02d] 你好! 这是模拟推送 #%d" % [
		stamp.hour, stamp.minute, stamp.second,
		vm.messages.size() + 1
	]
	vm.inject_test_message(text)


func _on_close_current_activity() -> void:
	finish()


func _on_back() -> void:
	finish()


# ---- 生命周期 stubs ----

func _on_start() -> void: pass
func _on_resume() -> void: pass
func _on_pause() -> void: pass
func _on_stop() -> void: pass

func _on_destroy() -> void:
	if vm:
		vm.dispose()

func _on_back_pressed() -> bool:
	return false
