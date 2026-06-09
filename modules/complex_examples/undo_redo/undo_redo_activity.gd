extends Activity
## UndoRedoActivity — 简单文本编辑器 + 撤销/重做
##
## 演示：
##   * TextEdit 双向绑定到 VM.document_text
##   * 用 _suppress_text_changed 标志避免 text_changed 循环
##   * 撤销/重做按钮响应 VM 状态
##   * 显示历史栈计数和最近操作描述

const UndoRedoVM = preload("res://modules/complex_examples/undo_redo/undo_redo_vm.gd")

var vm: UndoRedoVM

# UI 引用
var _undo_btn: Button
var _redo_btn: Button
var _clear_history_btn: Button
var _counter_lbl: Label
var _text_edit: TextEdit
var _action_label_lbl: Label
var _cursor_info_lbl: Label

# 防止 TextEdit.text_changed 循环
var _suppress_text_changed: bool = false


func _on_create(saved_state: Dictionary) -> void:
	vm = UndoRedoVM.new()

	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_LEFT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.SLIDE_RIGHT; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()
	_bind_all()
	_refresh_counter(vm.undo_count, vm.redo_count)


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
	margin.add_theme_constant_override("margin_top", 32)
	root_vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	inner.add_child(title_row)

	var title = Label.new()
	title.text = "📝 复杂示例 8 — 文本编辑器 (Undo/Redo)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：双栈快照、连续编辑合并（<500ms）、move_cursor 不入栈"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# === 顶部工具栏 ===
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	inner.add_child(toolbar)

	_undo_btn = Button.new()
	_undo_btn.text = "↶ 撤销"
	_undo_btn.tooltip_text = "Ctrl+Z"
	_undo_btn.disabled = true
	toolbar.add_child(_undo_btn)

	_redo_btn = Button.new()
	_redo_btn.text = "↷ 重做"
	_redo_btn.tooltip_text = "Ctrl+Y"
	_redo_btn.disabled = true
	toolbar.add_child(_redo_btn)

	toolbar.add_child(VSeparator.new())

	_counter_lbl = Label.new()
	_counter_lbl.text = "0 / 0"
	_counter_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	toolbar.add_child(_counter_lbl)

	toolbar.add_child(VSeparator.new())

	_clear_history_btn = Button.new()
	_clear_history_btn.text = "🗑 清空历史"
	toolbar.add_child(_clear_history_btn)

	# === 文本编辑器 ===
	_text_edit = TextEdit.new()
	_text_edit.placeholder_text = "在这里输入文字…\n试试连续输入几个字符，然后按撤销/重做按钮。"
	_text_edit.custom_minimum_size = Vector2(0, 280)
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inner.add_child(_text_edit)

	# === 底部信息栏 ===
	var info_bar = HBoxContainer.new()
	info_bar.add_theme_constant_override("separation", 12)
	inner.add_child(info_bar)

	_action_label_lbl = Label.new()
	_action_label_lbl.text = "（等待操作）"
	_action_label_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_action_label_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(_action_label_lbl)

	_cursor_info_lbl = Label.new()
	_cursor_info_lbl.text = "0 / 0"
	_cursor_info_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	info_bar.add_child(_cursor_info_lbl)

	# === 演示按钮 ===
	inner.add_child(HSeparator.new())
	var demo_lbl = Label.new()
	demo_lbl.text = "🎯 演示操作："
	inner.add_child(demo_lbl)

	var demo_row = HBoxContainer.new()
	demo_row.add_theme_constant_override("separation", 6)
	inner.add_child(demo_row)
	demo_row.add_child(_make_demo_btn("📝 追加 'Hello'", _on_demo_append.bind("Hello")))
	demo_row.add_child(_make_demo_btn("🗑 删 1 字符", _on_demo_delete.bind(1)))
	demo_row.add_child(_make_demo_btn("🗑 删 3 字符", _on_demo_delete.bind(3)))
	demo_row.add_child(_make_demo_btn("🎯 移到开头", _on_demo_move.bind(0)))

	# 返回
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _make_demo_btn(label: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = label
	b.pressed.connect(cb)
	return b


# === 绑定 ===

func _bind_all() -> void:
	# 视图绑定 — VM 状态变 → UI 更新
	vm.subscribe_property("document_text", _update_document_text)
	vm.subscribe_property("cursor_pos", _update_cursor_pos)
	vm.subscribe_property("can_undo", _update_undo_btn)
	vm.subscribe_property("can_redo", _update_redo_btn)
	vm.subscribe_property("undo_count", _on_count_changed)
	vm.subscribe_property("redo_count", _on_count_changed)
	vm.subscribe_property("last_action_label", _update_action_label)

	# 命令绑定 — UI 事件 → VM
	_undo_btn.pressed.connect(_on_undo)
	_redo_btn.pressed.connect(_on_redo)
	_clear_history_btn.pressed.connect(_on_clear_history)
	_text_edit.text_changed.connect(_on_text_edit_changed)


# === 视图更新回调 ===

func _update_document_text(v) -> void:
	var new_text = str(v)
	# 关键：suppress flag 避免 text_changed 反馈回 VM
	if _text_edit.text == new_text:
		return
	_suppress_text_changed = true
	_text_edit.text = new_text
	_suppress_text_changed = false
	# 文本变化时重置 cursor_info
	_update_cursor_info_internal()


func _update_cursor_pos(_v) -> void:
	_update_cursor_info_internal()


func _update_cursor_info_internal() -> void:
	_cursor_info_lbl.text = "光标: %d / 长度: %d" % [vm.cursor_pos, vm.document_text.length()]


func _update_undo_btn(v) -> void:
	_undo_btn.disabled = not bool(v)


func _update_redo_btn(v) -> void:
	_redo_btn.disabled = not bool(v)


func _on_count_changed(_v) -> void:
	_refresh_counter(vm.undo_count, vm.redo_count)


func _refresh_counter(u: int, r: int) -> void:
	_counter_lbl.text = "📚 撤销: %d | 重做: %d" % [u, r]


func _update_action_label(v) -> void:
	_action_label_lbl.text = str(v) if not str(v).is_empty() else "（等待操作）"


# === 命令处理 ===

func _on_undo() -> void:
	vm.undo()
	if _text_edit.has_method("set_caret_column"):
		_text_edit.set_caret_column(vm.cursor_pos)


func _on_redo() -> void:
	vm.redo()
	if _text_edit.has_method("set_caret_column"):
		_text_edit.set_caret_column(vm.cursor_pos)


func _on_clear_history() -> void:
	vm.clear_history()


func _on_text_edit_changed() -> void:
	if _suppress_text_changed:
		return
	# 简化：直接比对前后文本，转化为单次 insert/delete 操作
	# 实际生产代码应做 diff（最长公共子序列），这里为示例简化
	var new_text = _text_edit.text
	var old_text = vm.document_text

	if new_text == old_text:
		return

	# 找出变化区间
	var common_prefix = 0
	var min_len = mini(old_text.length(), new_text.length())
	while common_prefix < min_len and old_text[common_prefix] == new_text[common_prefix]:
		common_prefix += 1

	var common_suffix = 0
	while common_suffix < (min_len - common_prefix) \
		and old_text[old_text.length() - 1 - common_suffix] == new_text[new_text.length() - 1 - common_suffix]:
		common_suffix += 1

	var old_mid = old_text.substr(common_prefix, old_text.length() - common_prefix - common_suffix)
	var new_mid = new_text.substr(common_prefix, new_text.length() - common_prefix - common_suffix)

	# 同步 VM 状态
	vm.begin_bulk_update()
	if old_mid.length() > 0 and new_mid.is_empty():
		# 纯删除
		vm.cursor_pos = common_prefix
		vm._record_immediate_snapshot("delete %d chars" % old_mid.length())
		vm.document_text = new_text
	elif new_mid.length() > 0 and old_mid.is_empty():
		# 纯插入
		vm.cursor_pos = common_prefix
		vm._record_immediate_snapshot("insert '%s'" % new_mid)
		vm.document_text = new_text
	else:
		# 替换 — 视作一次删除 + 一次插入
		vm.cursor_pos = common_prefix
		vm._record_immediate_snapshot("replace")
		vm.document_text = new_text
	vm.cursor_pos = common_prefix + new_mid.length()
	# 派生属性同步
	vm.can_undo = not vm._undo_stack.is_empty()
	vm.can_redo = not vm._redo_stack.is_empty()
	vm.undo_count = vm._undo_stack.size()
	vm.redo_count = vm._redo_stack.size()
	vm.end_bulk_update()


# === 演示按钮回调 ===

func _on_demo_append(text: String) -> void:
	vm.cursor_pos = vm.document_text.length()
	vm.insert_text(text)


func _on_demo_delete(count: int) -> void:
	vm.delete_chars(count)


func _on_demo_move(pos: int) -> void:
	vm.move_cursor(pos)


# === 生命周期 ===

func _on_start() -> void: pass
func _on_resume() -> void: pass
func _on_pause() -> void: pass
func _on_stop() -> void: pass
func _on_destroy() -> void:
	if vm:
		vm.dispose()
func _on_close_current_activity() -> void:
	finish()


func _on_back() -> void:
	finish()

func _on_back_pressed() -> bool:
	return false
