extends Control
## Debug 堆栈查看器 — Ctrl+Shift+` 打开/关闭
## 显示 Activity 栈、Dialog 列表、Toast 队列、Application 状态

var _app: Application
var _info_label: RichTextLabel
var _timer: SceneTreeTimer

func setup(p_app: Application) -> void:
	_app = p_app
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 半透明遮罩
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 居中面板
	var panel = PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.set_custom_minimum_size(Vector2(640, 500))
	add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	# 标题栏
	var hdr = HBoxContainer.new()
	inner.add_child(hdr)
	var title = Label.new()
	title.text = "Context Stack Debugger"
	title.add_theme_font_size_override("font_size", 20)
	hdr.add_child(title)
	hdr.add_child(_make_spacer())
	var hint = Label.new()
	hint.text = "Ctrl+Shift+` / Esc 关闭"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hdr.add_child(hint)

	var sep = HSeparator.new()
	inner.add_child(sep)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	_info_label.add_theme_font_size_override("normal_font_size", 13)
	inner.add_child(_info_label)

	var sep2 = HSeparator.new()
	inner.add_child(sep2)

	var btn = Button.new()
	btn.text = "关闭 (Esc)"
	btn.pressed.connect(_on_close)
	inner.add_child(btn)

	_refresh()
	# 每秒自动刷新
	_timer = get_tree().create_timer(1.0)
	_timer.timeout.connect(_auto_refresh)


func _auto_refresh() -> void:
	if not is_instance_valid(self):
		return
	_refresh()
	_timer = get_tree().create_timer(1.0)
	_timer.timeout.connect(_auto_refresh)


func _refresh() -> void:
	var am = _app.get_activity_manager()
	var bb = "[table=5]"

	# ---- Activity 堆栈 ----
	bb += _section("Activity Stack (top last)", "stack_size=%d" % am.get_stack_size())
	bb += "[tr][td][b]Idx[/b][/td][td][b]Action[/b][/td][td][b]Class[/b][/td][td][b]Visible[/b][/td][td][b]NoHistory[/b][/td][/tr]"
	for i in range(am.get_stack_size()):
		var act = am.get_stack_activity(i)
		var action = act.get_intent().action if act.get_intent() else "(none)"
		var cls = act.get_script().resource_path.get_file() if act.get_script() else act.get_class()
		var visible = str(act.visible)
		var no_hist = str(act.get_no_history())
		var is_top = (i == am.get_stack_size() - 1)
		var color = "[color=#88ff88]" if is_top else "[color=#aaaaaa]"
		bb += "[tr][td]%s%d[/td][td]%s[/td][td]%s[/td][td]%s[/td][td]%s[/td][/tr][/color]" % [color, i, action, cls, visible, no_hist]

	# ---- Dialog 列表 ----
	bb += _section("Dialogs", "count=%d" % am.get_dialog_count())
	if am.get_dialog_count() == 0:
		bb += "[tr][td][color=#666666](none)[/color][/td][/tr]"
	else:
		bb += "[tr][td][b]Idx[/b][/td][td][b]Action[/b][/td][td][b]Owner[/b][/td][td][b]Context[/b][/td][td][/td][/tr]"
		for i in range(am.get_dialog_count()):
			var d = am.get_dialog(i)
			var action = d.get_intent().action if d.get_intent() else "(none)"
			var owner_obj = d.get_lifecycle_owner()
			var owner_str = owner_obj.get_class() if owner_obj else "(null)"
			var ctx = d.get_context()
			var ctx_str = "[color=#88aaff]Application[/color]" if ctx == _app else ctx.get_class()
			bb += "[tr][td]%d[/td][td]%s[/td][td]%s[/td][td]%s[/td][/tr]" % [i, action, owner_str, ctx_str]

	# ---- Toast 队列 ----
	bb += _section("Toast Queue", "count=%d, active=%s" % [am.get_toast_queue_count(), am.is_toast_active()])
	if am.get_toast_queue_count() == 0:
		bb += "[tr][td][color=#666666](empty)[/color][/td][/tr]"
	else:
		bb += "[tr][td][b]Idx[/b][/td][td][b]Text[/b][/td][td][b]Duration[/b][/td][td][b]Custom[/b][/td][td][b]OwnerID[/b][/td][/tr]"
		for i in range(am.get_toast_queue_count()):
			var t = am.get_toast_queue_item(i)
			var txt = t.get_text().substr(0, 40) + ("..." if t.get_text().length() > 40 else "")
			var dur = "%.1fs" % t.get_duration()
			var custom = "[color=#ffaa00]yes[/color]" if not t.get_custom_scene().is_empty() else "no"
			var oid = t.get_owner().get_class() if t.get_owner() else "(none)"
			bb += "[tr][td]%d[/td][td]%s[/td][td]%s[/td][td]%s[/td][td]%s[/td][/tr]" % [i, txt, dur, custom, oid]

	# ---- Application ----
	bb += _section("Application", "")
	var root = am.get_root()
	bb += "[tr][td]Root[/td][td]%s[/td][/tr]" % ("[color=#88ff88]set[/color]" if root else "[color=#ff4444]null[/color]")
	bb += "[tr][td]Service Count[/td][td]%d[/td][/tr]" % _app.get_service_registry().get_service_names().size()

	bb += "[/table]"
	_info_label.text = bb


func _section(title: String, subtitle: String) -> String:
	var s = "[tr][td][b][color=#55ccff]━━━ %s[/color][/b] [color=#888888]%s[/color][/td][/tr]" % [title, subtitle]
	return s


func _make_spacer() -> Control:
	var c = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()


func _on_close() -> void:
	queue_free()
