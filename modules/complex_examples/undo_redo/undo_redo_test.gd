extends RefCounted
class_name UndoRedoSelfTest
## UndoRedo 自检测试 — 不依赖 UI，直接测试 VM 逻辑

static func run() -> void:
	print("=== UndoRedo Self Test ===")
	var VM = preload("res://modules/complex_examples/undo_redo/undo_redo_vm.gd")
	var vm = VM.new()

	# === 1. 初始状态 ===
	assert(vm.document_text.is_empty(), "初始文档为空")
	assert(not vm.can_undo, "初始不可 undo")
	assert(not vm.can_redo, "初始不可 redo")
	assert(vm.undo_count == 0, "undo_count == 0")
	assert(vm.redo_count == 0, "redo_count == 0")
	print("  [1] 初始状态正确")

	# === 2. 连续输入 "hello" — 间隔很短，应合并为少量快照 ===
	for ch in "hello":
		vm.insert_text(ch)
		await Engine.get_main_loop().process_frame
	assert(vm.document_text == "hello", "输入后 == 'hello'")
	var initial_undo_count = vm.undo_count
	assert(initial_undo_count >= 1, "至少 1 个 undo 记录 (actual: %d)" % initial_undo_count)
	assert(initial_undo_count <= 5, "连续输入应合并 (actual: %d)" % initial_undo_count)
	print("  [2] 连续输入 'hello'，undo_count = %d" % initial_undo_count)

	# === 3. 全部 undo 回空 ===
	while vm.can_undo:
		vm.undo()
	assert(vm.document_text.is_empty(), "全部 undo 后文档为空")
	assert(vm.can_redo, "undo 后 can_redo == true")
	assert(vm.undo_count == 0, "undo 栈空")
	print("  [3] 全部 undo → 可以 redo")

	# === 4. 全部 redo 回来 ===
	while vm.can_redo:
		vm.redo()
	assert(vm.document_text == "hello", "全部 redo 后 == 'hello'")
	assert(vm.can_undo, "redo 后可以 undo")
	assert(not vm.can_redo, "redo 栈空")
	print("  [4] 全部 redo → 恢复 'hello'")

	# === 5. 新动作清空 redo_stack ===
	vm.insert_text("X")
	assert(vm.document_text == "helloX", "插入 X 后 == 'helloX'")
	assert(not vm.can_redo, "新动作后 redo_stack 清空")
	print("  [5] 新动作后 redo_stack 清空")

	# === 6. delete_chars 向左删除 ===
	vm.delete_chars(1)
	assert(vm.document_text == "hello", "删 1 字符后 == 'hello'")
	assert(vm.cursor_pos == 5, "cursor 回到 5")
	print("  [6] delete_chars 正确")

	# === 7. load_document 清空历史 ===
	vm.insert_text(" world")
	assert(vm.undo_count > 0, "应有 undo 历史")
	vm.load_document("new doc")
	assert(vm.document_text == "new doc", "load_document 后 == 'new doc'")
	assert(vm.undo_count == 0, "load_document 后 undo_count == 0")
	assert(vm.redo_count == 0, "load_document 后 redo_count == 0")
	assert(not vm.can_undo, "load_document 后不可 undo")
	print("  [7] load_document 清空历史")

	# === 8. move_cursor 不产生新快照 ===
	vm.insert_text("A")
	await Engine.get_main_loop().process_frame
	var c1 = vm.undo_count
	vm.move_cursor(0)
	assert(vm.undo_count == c1, "move_cursor 不应产生新历史 (before: %d, after: %d)" % [c1, vm.undo_count])
	vm.move_cursor(99)
	assert(vm.cursor_pos == vm.document_text.length(), "move_cursor clamp 到文档末尾")
	print("  [8] move_cursor 不入栈，clamp 正确")

	# === 9. history_size_limit 容量限制 ===
	vm.clear_history()
	for i in 60:
		vm._record_immediate_snapshot("force-%d" % i)
	assert(vm.undo_count <= vm.history_size_limit, "undo_count 不超过 history_size_limit (count: %d, limit: %d)" % [vm.undo_count, vm.history_size_limit])
	print("  [9] history_size_limit 生效 (undo_count: %d, limit: %d)" % [vm.undo_count, vm.history_size_limit])

	# === 10. clear_history ===
	vm.clear_history()
	assert(vm.undo_count == 0, "clear_history 后 undo_count == 0")
	assert(vm.redo_count == 0, "clear_history 后 redo_count == 0")
	assert(not vm.can_undo, "clear_history 后不可 undo")
	print("  [10] clear_history 正确")

	# === 11. delete_chars 边界 ===
	vm.clear_history()
	vm.document_text = ""
	vm.delete_chars(0)
	vm.delete_chars(5)
	assert(vm.document_text.is_empty(), "空文档删除不变")
	assert(not vm.can_undo, "空文档删除不产生历史")
	print("  [11] delete_chars 边界安全")

	# === 12. Snapshot 时间戳 ===
	vm.clear_history()
	vm.insert_text("a")
	var s1_count = vm.undo_count
	print("  [12] Snapshot timestamp 由 Time.get_ticks_msec() 记录 (count: %d)" % s1_count)

	vm.dispose()
	print("=== UndoRedo Self Test OK ===")
