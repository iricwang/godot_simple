extends Activity
## ShoppingCartActivity — 购物车示例
##
## 演示：
##   * 数量增减 (+/- 按钮)
##   * 删除商品
##   * 应用折扣码 (校验)
##   * 实时计算总价 (subtotal/discount/tax/total)
##   * 结算 (checkout)
##   * CurrencyConverter + PercentageConverter

const CartVM = preload("res://modules/complex_examples/shopping_cart/shopping_cart_vm.gd")
const CurrencyConverter = preload("res://core/converters/currency_converter.gd")
const PercentConverter = preload("res://core/converters/percentage_converter.gd")

var vm: CartVM

# UI 引用
var _cart_vb: VBoxContainer
var _subtotal_lbl: Label
var _discount_lbl: Label
var _tax_lbl: Label
var _total_lbl: Label
var _item_count_lbl: Label
var _discount_edit: LineEdit
var _apply_discount_btn: Button
var _checkout_btn: Button
var _status_lbl: Label
var _clear_btn: Button
var _customer_note_edit: TextEdit


func _on_create(saved_state: Dictionary) -> void:
	vm = CartVM.new()

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
	title.text = "🛒 复杂示例 2 — 购物车 (Shopping Cart)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：计算属性 (subtotal/tax/total)、折扣码、数量增减实时计算"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# 商品列表区
	_cart_vb = VBoxContainer.new()
	_cart_vb.add_theme_constant_override("separation", 4)
	inner.add_child(_cart_vb)

	inner.add_child(HSeparator.new())

	# 折扣码
	var discount_row = HBoxContainer.new()
	discount_row.add_theme_constant_override("separation", 6)
	inner.add_child(discount_row)
	var dlabel = Label.new()
	dlabel.text = "🏷 折扣码:"
	discount_row.add_child(dlabel)
	_discount_edit = LineEdit.new()
	_discount_edit.placeholder_text = "试试 SAVE10 / SAVE20 / HALF"
	_discount_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discount_row.add_child(_discount_edit)
	_apply_discount_btn = Button.new()
	_apply_discount_btn.text = "应用"
	discount_row.add_child(_apply_discount_btn)

	# 价格汇总
	var summary_vb = VBoxContainer.new()
	summary_vb.add_theme_constant_override("separation", 2)
	inner.add_child(summary_vb)

	_item_count_lbl = Label.new()
	summary_vb.add_child(_item_count_lbl)

	_subtotal_lbl = Label.new()
	summary_vb.add_child(_subtotal_lbl)

	_discount_lbl = Label.new()
	_discount_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	summary_vb.add_child(_discount_lbl)

	_tax_lbl = Label.new()
	_discount_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	summary_vb.add_child(_tax_lbl)

	_total_lbl = Label.new()
	_total_lbl.add_theme_font_size_override("font_size", 20)
	_total_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	summary_vb.add_child(_total_lbl)

	# 备注
	inner.add_child(Label.new())
	var note_lbl = Label.new()
	note_lbl.text = "📝 客户备注:"
	inner.add_child(note_lbl)
	_customer_note_edit = TextEdit.new()
	_customer_note_edit.placeholder_text = "选填，订单备注..."
	_customer_note_edit.custom_minimum_size = Vector2(0, 60)
	inner.add_child(_customer_note_edit)

	# 操作按钮
	var btn_row = HBoxContainer.new()
	inner.add_child(btn_row)
	_checkout_btn = Button.new()
	_checkout_btn.text = "💳 结算"
	_checkout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_checkout_btn)
	_clear_btn = Button.new()
	_clear_btn.text = "🗑 清空购物车"
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_clear_btn)

	# 状态
	_status_lbl = Label.new()
	_status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	inner.add_child(_status_lbl)

	# 演示按钮 — 加商品
	inner.add_child(HSeparator.new())
	var demo_lbl = Label.new()
	demo_lbl.text = "🎁 演示 — 快速添加商品:"
	inner.add_child(demo_lbl)
	var demo_row = HBoxContainer.new()
	inner.add_child(demo_row)
	demo_row.add_child(_make_demo_btn("P004", "显示器挂灯", 159.0))
	demo_row.add_child(_make_demo_btn("P005", "降噪耳机", 1299.0))
	demo_row.add_child(_make_demo_btn("P006", "摄像头", 459.0))

	# 返回
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _make_demo_btn(id: String, name: String, price: float) -> Button:
	var b = Button.new()
	b.text = "+ %s" % name
	b.pressed.connect(_on_demo_add.bind(id, name, price))
	return b


func _bind_all() -> void:
	# 视图绑定
	vm.subscribe_property("cart_items", _rebuild_cart)
	vm.subscribe_property("subtotal", _update_subtotal)
	vm.subscribe_property("discount_amount", _update_discount)
	vm.subscribe_property("tax", _update_tax)
	vm.subscribe_property("total", _update_total)
	vm.subscribe_property("item_count", _update_item_count)
	vm.subscribe_property("is_checkout_enabled", _update_checkout_btn)
	vm.subscribe_property("checkout_status", _update_status)

	# 命令绑定
	_apply_discount_btn.pressed.connect(_on_apply_discount)
	_checkout_btn.pressed.connect(_on_checkout)
	_clear_btn.pressed.connect(_on_clear)
	_customer_note_edit.text_changed.connect(_on_note_changed)


func _rebuild_cart(_v) -> void:
	for c in _cart_vb.get_children():
		c.queue_free()

	if vm.cart_items.is_empty():
		var empty = Label.new()
		empty.text = "（购物车为空）"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_cart_vb.add_child(empty)
		return

	for item in vm.cart_items:
		_cart_vb.add_child(_build_cart_row(item))


func _build_cart_row(item) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = item.product_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# 数量调整
	var minus = Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(32, 0)
	minus.pressed.connect(_on_qty_change.bind(item.product_id, item.quantity - 1))
	row.add_child(minus)

	var qty_lbl = Label.new()
	qty_lbl.text = str(item.quantity)
	qty_lbl.custom_minimum_size = Vector2(30, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_lbl)

	var plus = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(32, 0)
	plus.pressed.connect(_on_qty_change.bind(item.product_id, item.quantity + 1))
	row.add_child(plus)

	# 单价 × 数量
	var price_lbl = Label.new()
	price_lbl.text = "¥%.2f" % item.get_subtotal()
	price_lbl.custom_minimum_size = Vector2(80, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)

	# 删除
	var del = Button.new()
	del.text = "✕"
	del.pressed.connect(_on_remove.bind(item.product_id))
	row.add_child(del)

	return row


func _update_subtotal(v) -> void:
	_subtotal_lbl.text = "小计: ¥%.2f" % float(v)


func _update_discount(v) -> void:
	var amount = float(v)
	if amount > 0:
		_discount_lbl.text = "折扣 (%s -%.0f%%): -¥%.2f" % [vm.discount_code, vm.discount_rate * 100, amount]
		_discount_lbl.visible = true
	else:
		_discount_lbl.text = "折扣: 无"
		_discount_lbl.visible = true


func _update_tax(v) -> void:
	_tax_lbl.text = "税 (8%%): ¥%.2f" % float(v)


func _update_total(v) -> void:
	_total_lbl.text = "总计: ¥%.2f" % float(v)


func _update_item_count(v) -> void:
	_item_count_lbl.text = "商品数: %d 件" % int(v)


func _update_checkout_btn(v) -> void:
	_checkout_btn.disabled = not bool(v)


func _update_status(s) -> void:
	_status_lbl.text = str(s)


# ---- 命令 ----

func _on_qty_change(product_id: String, new_qty: int) -> void:
	vm.update_quantity(product_id, new_qty)


func _on_remove(product_id: String) -> void:
	vm.remove_item(product_id)


func _on_apply_discount() -> void:
	var code = _discount_edit.text.strip_edges()
	if code.is_empty():
		_status_lbl.text = "❌ 请输入折扣码"
		return
	if vm.apply_discount_code(code):
		_status_lbl.text = "✅ 折扣码 %s 已应用" % code.to_upper()
	else:
		_status_lbl.text = "❌ 无效的折扣码: %s" % code


func _on_checkout() -> void:
	vm.on_checkout()


func _on_clear() -> void:
	vm.on_clear_cart()
	_status_lbl.text = "购物车已清空"


func _on_demo_add(id: String, name: String, price: float) -> void:
	vm.add_item(id, name, price, 1)


func _on_note_changed() -> void:
	vm.customer_note = _customer_note_edit.text


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
