extends "res://core/base_view_model.gd"
## 复杂示例 7 — WebSocket 实时数据推送 (Mock Client)
##
## 演示：
##   * 真实环境不可用时, 用内存级 Mock 替代外部依赖 (Test Double 模式)
##   * 连接状态机: DISCONNECTED → CONNECTING → CONNECTED → DISCONNECTED
##   * 实时消息流 (时间戳 / 发送方 / 内容)
##   * 未读计数 + 红点提示
##   * 异步命令 (await process_frame 模拟网络延迟)
##   * VM 内部嵌入 RefCounted 子对象 (MockWebSocketClient), 不污染节点树
##
## 注意: 这里不真的连 WebSocket — Godot 4 的 WebSocketPeer 在 headless 模式下
##       不便测试, 所以用纯 RefCounted 的 Mock 客户端模拟服务器推送行为.
##       这是常见的 Test Double 模式: 在测试 / 演示中用一个内存对象替代外部
##       系统, 但保持与真实实现相同的接口.

# === 内部类: Mock WebSocket 客户端 ===

class MockWebSocketClient extends RefCounted:
	## 内存级 WebSocket 替身. 用 RefCounted 而不是 Node, 因为它不是场景树的一部分.
	## 真实环境下应该用 WebSocketPeer + connect_to_server(), 但接口形状一样:
	##   connect / disconnect / send / 接收 message_received 信号.

	signal connected
	signal disconnected
	signal message_received(text: String)
	signal state_changed(new_state: String)

	const STATE_DISCONNECTED := "DISCONNECTED"
	const STATE_CONNECTING  := "CONNECTING"
	const STATE_CONNECTED   := "CONNECTED"
	const STATE_ERROR       := "ERROR"

	var state: String = STATE_DISCONNECTED
	var messages_sent: int = 0
	var messages_received: int = 0
	var latency_ms: int = 50
	var server_url: String = ""


	func connect_to(url: String) -> void:
		server_url = url
		_set_state(STATE_CONNECTING)
		# 真实 WebSocket 这里是异步握手 — Mock 同步切换到 CONNECTED
		_set_state(STATE_CONNECTED)
		connected.emit()


	func do_disconnect() -> void:
		# 注意: 不用 `disconnect` 作方法名 — Godot 4 Object 已有同名方法
		# (`disconnect(signal, callable)`), GDScript 解析时可能误调内置版本.
		if state == STATE_DISCONNECTED:
			return
		_set_state(STATE_DISCONNECTED)
		disconnected.emit()


	func send(text: String) -> void:
		# 真实 WebSocket send() 也是同步返回 (只是发送是异步的).
		# 注意: 真实 WebSocket 不会回显自己的发送, 所以这里不触发 message_received.
		messages_sent += 1


	func simulate_incoming(text: String) -> void:
		# 测试用: 模拟服务器推送一条消息
		if state == STATE_DISCONNECTED:
			_set_state(STATE_CONNECTED)
		messages_received += 1
		message_received.emit(text)


	func simulate_disconnect() -> void:
		# 测试用: 模拟服务器断线
		if state != STATE_DISCONNECTED:
			_set_state(STATE_DISCONNECTED)
			disconnected.emit()


	func _set_state(new_state: String) -> void:
		state = new_state
		state_changed.emit(new_state)


# === VM 属性 ===

var server_url: String = "wss://example.com/feed"
var connection_state: String = "DISCONNECTED"
var is_connected: bool = false
var is_connecting: bool = false
var messages: Array = []  # [{time, content, sender}]
var unread_count: int = 0
var last_message_preview: String = ""
var latency_ms: int = 0
var send_text: String = ""
var status_message: String = "未连接"

# Mock 客户端 — 嵌入 VM 内部
var _mock: MockWebSocketClient

# 用于计算延迟的内部时间戳
var _last_send_msec: int = -1


# === 生命周期 ===

func _init() -> void:
	_mock = MockWebSocketClient.new()
	# 把 mock 的信号接到 VM 的内部方法
	_mock.state_changed.connect(_on_mock_state_changed)
	_mock.message_received.connect(_on_mock_message_received)
	_mock.disconnected.connect(_on_mock_disconnected)
	_recompute_status()


# === 命令 ===

func connect_to_server() -> void:
	## 异步连接 — 切到 CONNECTING, 等 1 帧, 切到 CONNECTED
	if is_connected or is_connecting:
		return
	is_connecting = true
	connection_state = "CONNECTING"
	status_message = "正在连接 " + server_url + "..."

	# 模拟网络握手延迟 (1 帧 ≈ 16ms)
	await Engine.get_main_loop().process_frame

	# 调用 mock 完成握手
	_mock.connect_to(server_url)
	# 同步部分: _on_mock_state_changed 会把 is_connecting/is_connected 处理好
	is_connecting = false
	is_connected = true
	connection_state = "CONNECTED"
	# 连接成功 → 未读清零
	unread_count = 0
	status_message = "已连接 — " + server_url
	latency_ms = _mock.latency_ms


func disconnect_from_server() -> void:
	if not is_connected:
		return
	_mock.do_disconnect()
	# _on_mock_state_changed / _on_mock_disconnected 会处理后续


func send_message() -> void:
	## 发送 send_text 内容, 发送后清空输入框
	if not is_connected:
		status_message = "未连接, 无法发送"
		return
	if send_text.is_empty():
		return
	var text = send_text
	_last_send_msec = Time.get_ticks_msec()
	_mock.send(text)
	# 自己发的消息也立即显示 (真实 WebSocket 通常会等服务端回 ack, 这里直接显示)
	messages.append({
		"time": Time.get_time_string_from_system(),
		"content": text,
		"sender": "self",
	})
	last_message_preview = _make_preview(text)
	status_message = "已发送"
	# 清空输入框
	send_text = ""


func mark_all_read() -> void:
	unread_count = 0


func clear_messages() -> void:
	messages.clear()
	last_message_preview = ""
	unread_count = 0


func inject_test_message(text: String) -> void:
	## 测试用: 模拟服务器推送一条消息
	# 走 mock 接口, 这样计数 / 信号路径和真实环境一致
	_mock.simulate_incoming(text)


# === 内部: mock 信号回调 ===

func _on_mock_state_changed(new_state: String) -> void:
	connection_state = new_state
	if new_state == MockWebSocketClient.STATE_CONNECTED:
		is_connected = true
		is_connecting = false
	elif new_state == MockWebSocketClient.STATE_DISCONNECTED:
		is_connected = false
		is_connecting = false
	elif new_state == MockWebSocketClient.STATE_CONNECTING:
		is_connecting = true
	elif new_state == MockWebSocketClient.STATE_ERROR:
		is_connected = false
		is_connecting = false
	_recompute_status()


func _on_mock_message_received(text: String) -> void:
	_on_incoming(text, "server")


func _on_mock_disconnected() -> void:
	# mock 自己断了
	is_connected = false
	is_connecting = false
	_recompute_status()


# === 内部: 收消息统一入口 ===

func _on_incoming(text: String, sender: String) -> void:
	messages.append({
		"time": Time.get_time_string_from_system(),
		"content": text,
		"sender": sender,
	})
	last_message_preview = _make_preview(text)
	# 只有"非自己"的消息算未读
	if sender != "self":
		unread_count += 1
	# 模拟往返延迟
	if _last_send_msec >= 0:
		var now = Time.get_ticks_msec()
		latency_ms = now - _last_send_msec
		_last_send_msec = -1
	else:
		latency_ms = _mock.latency_ms


func _make_preview(text: String) -> String:
	if text.length() <= 30:
		return text
	return text.substr(0, 30) + "..."


func _recompute_status() -> void:
	if is_connected:
		status_message = "已连接 — " + server_url
	elif is_connecting:
		status_message = "正在连接..."
	else:
		status_message = "未连接"
