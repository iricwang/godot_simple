extends RefCounted
class_name WebSocketFeedSelfTest
## WebSocketFeed 自检测试
##
## 演示：
##   * VM 可以脱离 Activity 单独测试 (Test Double 模式, 配合 Mock 客户端)
##   * await 在 static func 里合法 (GDScript 4)
##   * 通过一次性 await Engine.get_main_loop().process_frame 触发异步状态切换

const FeedVM = preload("res://modules/complex_examples/websocket_feed/websocket_feed_vm.gd")


static func run() -> void:
	var vm = FeedVM.new()

	# 初始断线
	assert(vm.connection_state == "DISCONNECTED", "初始断线")
	assert(not vm.is_connected, "初始 is_connected false")
	assert(vm.messages.is_empty(), "初始无消息")
	assert(vm.unread_count == 0, "初始 unread 0")
	assert(vm.server_url == "wss://example.com/feed", "默认 server_url")

	# 连接 (同步部分 — await 在测试里手动跑)
	vm.connect_to_server()
	# connect_to_server 里有 await, 调用后立即执行到 await 处
	# 我们用 OS 模拟: 等一帧
	await Engine.get_main_loop().process_frame
	assert(vm.is_connected, "连接后 is_connected")
	assert(vm.connection_state == "CONNECTED", "状态 CONNECTED")
	assert(vm.unread_count == 0, "连接成功时 unread 清零")

	# 注入消息
	vm.inject_test_message("hello")
	vm.inject_test_message("world")
	assert(vm.messages.size() == 2, "收到 2 条")
	assert(vm.unread_count == 2, "unread 2")
	assert("world" in vm.last_message_preview, "last preview 含 world")

	# 标记已读
	vm.mark_all_read()
	assert(vm.unread_count == 0, "标记已读 → 0")

	# 发送
	vm.send_text = "ping"
	vm.send_message()
	assert(vm.send_text.is_empty(), "发送后输入框清空")
	# 自己发的也算一条消息
	assert(vm.messages.size() == 3, "发送后 3 条 (2 收 + 1 发)")
	# 找自己发的
	var found_self = false
	for m in vm.messages:
		if m.get("sender") == "self" and m.get("content") == "ping":
			found_self = true
			break
	assert(found_self, "自己发的消息在列表里")

	# 断线
	vm.disconnect_from_server()
	assert(not vm.is_connected, "断线后 is_connected false")
	assert(vm.connection_state == "DISCONNECTED", "DISCONNECTED")
	assert(not vm.is_connecting, "断线后 is_connecting false")

	# 清空
	vm.clear_messages()
	assert(vm.messages.is_empty(), "清空消息")
	assert(vm.unread_count == 0, "清空后 unread 0")
	assert(vm.last_message_preview == "", "清空后 preview 空")

	vm.dispose()
	print("  OK")
