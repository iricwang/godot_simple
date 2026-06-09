extends Activity
## OrderStateActivity — 订单状态机
##
## 演示：
##   * 状态徽章 (颜色 + 文本随状态切换)
##   * 操作按钮按状态启用/禁用
##   * 状态历史时间线

const OrderVM = preload("res://modules/complex_examples/order_state/order_state_vm.gd")
# 状态颜色通过 vm.state_color (Color) 直接订阅 + add_theme_color_override
# 不需要单独的 StateConverter

var vm: OrderVM

# UI
var _order_id_lbl: Label
var _amount_lbl: Label
var _summary_lbl: Label
var _state_badge: Label
var _process_lbl: Label
var _history_vb: VBoxContainer

var _pay_btn: Button
var _cancel_btn: Button
var _ship_btn: Button
var _confirm_btn: Button
var _refund_btn: Button
var _reorder_btn: Button


func _on_create(saved_state: Dictionary) -> void:
	vm = OrderVM.new()

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
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	inner.add_child(title_row)

	var title = Label.new()
	title.text = "📦 复杂示例 4 — 订单状态机 (Order State Machine)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：有限状态机、转换规则、可用操作联动、历史时间线"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# 订单信息
	_order_id_lbl = Label.new()
	_order_id_lbl.add_theme_font_size_override("font_size", 14)
	inner.add_child(_order_id_lbl)

	_amount_lbl = Label.new()
	inner.add_child(_amount_lbl)

	_summary_lbl = Label.new()
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_summary_lbl)

	inner.add_child(HSeparator.new())

	# 状态徽章
	_state_badge = Label.new()
	_state_badge.add_theme_font_size_override("font_size", 28)
	_state_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_state_badge)

	_process_lbl = Label.new()
	_process_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_process_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(_process_lbl)

	inner.add_child(HSeparator.new())

	# 操作按钮 (两行)
	var btn_grid = GridContainer.new()
	btn_grid.columns = 3
	btn_grid.add_theme_constant_override("h_separation", 6)
	btn_grid.add_theme_constant_override("v_separation", 6)
	inner.add_child(btn_grid)

	_pay_btn = Button.new()
	_pay_btn.text = "💰 支付"
	_pay_btn.pressed.connect(_on_pay)
	btn_grid.add_child(_pay_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "❌ 取消"
	_cancel_btn.pressed.connect(_on_cancel)
	btn_grid.add_child(_cancel_btn)

	_ship_btn = Button.new()
	_ship_btn.text = "🚚 发货"
	_ship_btn.pressed.connect(_on_ship)
	btn_grid.add_child(_ship_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "✅ 确认收货"
	_confirm_btn.pressed.connect(_on_confirm)
	btn_grid.add_child(_confirm_btn)

	_refund_btn = Button.new()
	_refund_btn.text = "💸 退款"
	_refund_btn.pressed.connect(_on_refund)
	btn_grid.add_child(_refund_btn)

	_reorder_btn = Button.new()
	_reorder_btn.text = "🔄 重新下单"
	_reorder_btn.pressed.connect(_on_reorder)
	btn_grid.add_child(_reorder_btn)

	inner.add_child(HSeparator.new())

	# 状态历史
	var h_lbl = Label.new()
	h_lbl.text = "📜 状态历史:"
	h_lbl.add_theme_font_size_override("font_size", 14)
	inner.add_child(h_lbl)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	inner.add_child(scroll)

	_history_vb = VBoxContainer.new()
	_history_vb.add_theme_constant_override("separation", 2)
	scroll.add_child(_history_vb)

	# 返回
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _bind_all() -> void:
	vm.subscribe_property("order_id", _update_order_id)
	vm.subscribe_property("amount", _update_amount)
	vm.subscribe_property("item_summary", _update_summary)
	vm.subscribe_property("state_label", _update_state_label)
	vm.subscribe_property("state_color", _update_state_color)
	vm.subscribe_property("is_processing", _update_processing)
	vm.subscribe_property("process_message", _update_process_msg)
	vm.subscribe_property("history", _rebuild_history)

	vm.subscribe_property("can_pay", _update_btn)
	vm.subscribe_property("can_cancel", _update_btn)
	vm.subscribe_property("can_ship", _update_btn)
	vm.subscribe_property("can_confirm_delivery", _update_btn)
	vm.subscribe_property("can_refund", _update_btn)
	vm.subscribe_property("can_reorder", _update_btn)


func _update_order_id(v) -> void:
	_order_id_lbl.text = "📋 订单号: " + str(v)


func _update_amount(v) -> void:
	_amount_lbl.text = "💵 金额: ¥%.2f" % float(v)


func _update_summary(v) -> void:
	_summary_lbl.text = "📦 商品: " + str(v)


func _update_state_label(v) -> void:
	_state_badge.text = str(v)


func _update_state_color(c) -> void:
	_state_badge.add_theme_color_override("font_color", c as Color)


func _update_processing(v) -> void:
	_process_lbl.text = "🔄 " + vm.process_message if bool(v) else ""


func _update_process_msg(v) -> void:
	if vm.is_processing:
		_process_lbl.text = "🔄 " + str(v)


func _rebuild_history(_v) -> void:
	for c in _history_vb.get_children():
		c.queue_free()
	if vm.history.is_empty():
		var empty = Label.new()
		empty.text = "（暂无历史）"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_history_vb.add_child(empty)
		return
	# 倒序显示
	for i in range(vm.history.size() - 1, -1, -1):
		var entry = vm.history[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var t = Label.new()
		t.text = entry["time"]
		t.add_theme_font_size_override("font_size", 11)
		t.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(t)
		var arrow = Label.new()
		arrow.text = "%s → %s" % [entry["from_label"], entry["to_label"]]
		arrow.add_theme_font_size_override("font_size", 13)
		row.add_child(arrow)
		var act = Label.new()
		act.text = "(" + entry["action"] + ")"
		act.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		act.add_theme_font_size_override("font_size", 12)
		row.add_child(act)
		_history_vb.add_child(row)


func _update_btn(_v = null) -> void:
	_pay_btn.disabled = not vm.can_pay
	_cancel_btn.disabled = not vm.can_cancel
	_ship_btn.disabled = not vm.can_ship
	_confirm_btn.disabled = not vm.can_confirm_delivery
	_refund_btn.disabled = not vm.can_refund
	_reorder_btn.disabled = not vm.can_reorder


# ---- 命令 ----

func _on_pay() -> void: vm.on_pay()
func _on_cancel() -> void: vm.on_cancel()
func _on_ship() -> void: vm.on_ship()
func _on_confirm() -> void: vm.on_confirm_delivery()
func _on_refund() -> void: vm.on_refund()
func _on_reorder() -> void: vm.on_reorder()


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
func _on_back_pressed() -> bool: return false
