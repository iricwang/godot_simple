extends "res://core/base_view_model.gd"
## 复杂示例 8 — 撤销/重做 (Undo Redo)
##
## 演示：
##   * 快照（Snapshot）内部类 — 捕获 text/cursor_pos/timestamp
##   * 双栈撤销/重做（_undo_stack / _redo_stack）
##   * 时间间隔合并策略 — 连续编辑（< 500ms）合并为同一快照
##   * 新动作清空 redo_stack（标准编辑器语义）
##   * move_cursor 不产生快照（光标移动不算编辑）
##   * undo/redo 用 begin_bulk_update 包裹 7 个属性
##   * 历史栈容量限制（history_size_limit）

# 快照 — 一次编辑动作的完整状态
class Snapshot extends RefCounted:
	var text: String
	var cursor_pos: int
	var timestamp: int

	func _init(t: String = "", c: int = 0) -> void:
		text = t
		cursor_pos = c
		timestamp = Time.get_ticks_msec()

	func label() -> String:
		# 截断预览避免 label 过长
		var preview = text
		if preview.length() > 20:
			preview = preview.substr(0, 20) + "…"
		return preview


# === 文档状态 ===

var document_text: String = ""
var cursor_pos: int = 0

# === 派生状态（栈空否决定能否 undo/redo）===

var can_undo: bool = false
var can_redo: bool = false
var undo_count: int = 0
var redo_count: int = 0

# === 配置 ===

var history_size_limit: int = 50
var last_action_label: String = ""

# === 内部 ===

var _undo_stack: Array = []
var _redo_stack: Array = []
var _max_snapshot_interval_ms: int = 500
var _last_modify_time: int = 0


# === 命令方法 ===

func insert_text(text: String) -> void:
	if text.is_empty():
		return
	var pos = clamp(cursor_pos, 0, document_text.length())
	# 关键：在 mutate 之前记录 pre-state — undo 时回退到这个状态
	_record_snapshot_pre("insert '%s'" % _short(text))
	document_text = document_text.substr(0, pos) + text + document_text.substr(pos)
	cursor_pos = pos + text.length()


func delete_chars(count: int) -> void:
	if count <= 0 or document_text.is_empty():
		return
	var pos = clamp(cursor_pos, 0, document_text.length())
	var start = maxi(0, pos - count)
	if start == pos:
		return
	var deleted = document_text.substr(start, pos - start)
	# 关键：在 mutate 之前记录 pre-state
	_record_snapshot_pre("delete '%s'" % _short(deleted))
	document_text = document_text.substr(0, start) + document_text.substr(pos)
	cursor_pos = start


func move_cursor(pos: int) -> void:
	var new_pos = clamp(pos, 0, document_text.length())
	if new_pos == cursor_pos:
		return
	cursor_pos = new_pos
	last_action_label = "移动光标 → %d" % new_pos


func undo() -> void:
	if _undo_stack.is_empty():
		return
	begin_bulk_update()
	var current = Snapshot.new(document_text, cursor_pos)
	_redo_stack.append(current)
	var snap: Snapshot = _undo_stack.pop_back()
	document_text = snap.text
	cursor_pos = snap.cursor_pos
	can_undo = not _undo_stack.is_empty()
	can_redo = not _redo_stack.is_empty()
	undo_count = _undo_stack.size()
	redo_count = _redo_stack.size()
	last_action_label = "← 撤销 → '%s'" % snap.label()
	end_bulk_update()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	begin_bulk_update()
	var current = Snapshot.new(document_text, cursor_pos)
	_undo_stack.append(current)
	var snap: Snapshot = _redo_stack.pop_back()
	document_text = snap.text
	cursor_pos = snap.cursor_pos
	can_undo = not _undo_stack.is_empty()
	can_redo = not _redo_stack.is_empty()
	undo_count = _undo_stack.size()
	redo_count = _redo_stack.size()
	last_action_label = "→ 重做 → '%s'" % snap.label()
	end_bulk_update()


func clear_history() -> void:
	begin_bulk_update()
	_undo_stack.clear()
	_redo_stack.clear()
	can_undo = false
	can_redo = false
	undo_count = 0
	redo_count = 0
	last_action_label = "历史已清空"
	end_bulk_update()


func load_document(text: String) -> void:
	begin_bulk_update()
	document_text = text
	cursor_pos = min(cursor_pos, text.length())
	_undo_stack.clear()
	_redo_stack.clear()
	can_undo = false
	can_redo = false
	undo_count = 0
	redo_count = 0
	last_action_label = "加载文档（历史已清空）"
	end_bulk_update()


func get_snapshot_count() -> int:
	return _undo_stack.size() + _redo_stack.size()


# === 内部 ===

func _record_immediate_snapshot(label: String = "edit") -> void:
	_push_new_snapshot(label)
	_sync_derived()


func _record_snapshot_pre(label: String) -> void:
	# 关键修改：snapshot 记录的是 pre-mutation 状态（此时 document_text/cursor_pos 尚未变更）
	# 合并策略：若上次修改距今 < 500ms, 不推新快照, 让 burst 内多次编辑共享同一个 pre-state
	if _undo_stack.is_empty() or _should_create_new_snapshot():
		_push_new_snapshot(label)
	last_action_label = label
	_redo_stack.clear()
	_sync_derived()


func _should_create_new_snapshot() -> bool:
	var now = Time.get_ticks_msec()
	return (now - _last_modify_time) >= _max_snapshot_interval_ms


func _push_new_snapshot(label: String) -> void:
	var snap = Snapshot.new(document_text, cursor_pos)
	_undo_stack.append(snap)
	_last_modify_time = Time.get_ticks_msec()
	while _undo_stack.size() > history_size_limit:
		_undo_stack.pop_front()


func _sync_derived() -> void:
	can_undo = not _undo_stack.is_empty()
	can_redo = not _redo_stack.is_empty()
	undo_count = _undo_stack.size()
	redo_count = _redo_stack.size()


func _short(s: String) -> String:
	if s.length() > 12:
		return s.substr(0, 12) + "…"
	return s
