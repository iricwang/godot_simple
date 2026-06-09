extends "res://core/base_view_model.gd"
## 复杂示例 2 — 购物车 (Shopping Cart)
##
## 演示：
##   * 集合属性 (cart_items) 触发 UI 更新
##   * 计算属性模式 (subtotal, tax, total, item_count) — 通过 begin_bulk_update + setter 模拟
##   * 数据驱动 UI (数量加减实时计算总价)
##   * 折扣码 (DiscountCode) 业务规则
##   * 多 Converter 组合 (CurrencyConverter, PercentageConverter)

class CartItem extends RefCounted:
	var product_id: String
	var product_name: String
	var unit_price: float
	var quantity: int

	func _init(p_id: String = "", p_name: String = "", p_price: float = 0.0, p_qty: int = 0) -> void:
		product_id = p_id
		product_name = p_name
		unit_price = p_price
		quantity = p_qty

	func get_subtotal() -> float:
		return unit_price * quantity

	func to_string_pretty() -> String:
		return "%s × %d = ¥%.2f" % [product_name, quantity, get_subtotal()]


# 折扣规则
const DISCOUNT_CODES = {
	"SAVE10": 0.10,  # 9折
	"SAVE20": 0.20,  # 8折
	"HALF": 0.50,    # 半价
}

# === ViewModel 属性 ===

# 集合数据
var cart_items: Array = []  # Array[CartItem]
var discount_code: String = ""
var discount_rate: float = 0.0  # 由 discount_code 计算
var customer_note: String = ""

# 计算属性 (派生)
# 注: Godot 4 GDScript 没有原生的 @computed，模拟方式:
# 1. setter 触发时把派生量都重算
# 2. 用 begin_bulk_update 减少通知次数
var subtotal: float = 0.0  # 小计
var discount_amount: float = 0.0  # 折扣金额
var tax: float = 0.0  # 税 (8%)
var total: float = 0.0  # 总价
var item_count: int = 0  # 商品总数 (不是 SKU 数)

# 状态
var is_checkout_enabled: bool = false
var checkout_status: String = ""

# === 命令方法 ===

func add_item(id: String, name: String, price: float, qty: int = 1) -> void:
	# 检查是否已存在 — 如果存在则累加数量
	for item in cart_items:
		if item.product_id == id:
			item.quantity += qty
			_recompute_totals()
			return
	cart_items.append(CartItem.new(id, name, price, qty))
	_recompute_totals()


func remove_item(product_id: String) -> void:
	cart_items = cart_items.filter(func(item): return item.product_id != product_id)
	_recompute_totals()


func update_quantity(product_id: String, new_qty: int) -> void:
	if new_qty <= 0:
		remove_item(product_id)
		return
	for item in cart_items:
		if item.product_id == product_id:
			item.quantity = new_qty
			break
	_recompute_totals()


func apply_discount_code(code: String) -> bool:
	discount_code = code.to_upper()
	discount_rate = DISCOUNT_CODES.get(discount_code, 0.0)
	_recompute_totals()
	return discount_rate > 0.0


func on_clear_cart() -> void:
	begin_bulk_update()
	cart_items.clear()
	discount_code = ""
	discount_rate = 0.0
	customer_note = ""
	_recompute_totals()
	end_bulk_update()


func on_checkout() -> void:
	if not is_checkout_enabled:
		checkout_status = "❌ 购物车为空，无法结算"
		return
	# 模拟结算
	checkout_status = "✅ 订单已提交！总价: ¥%.2f (商品数: %d)" % [total, item_count]
	# 实际项目里会调用 API，然后清空购物车


# === 内部计算 ===

# 重算所有派生属性
# 用 begin_bulk_update/end_bulk_update 包装 — 5 个派生量都更新但只触发少量通知
func _recompute_totals() -> void:
	begin_bulk_update()

	item_count = 0
	subtotal = 0.0
	for item in cart_items:
		item_count += item.quantity
		subtotal += item.get_subtotal()

	discount_amount = subtotal * discount_rate
	var after_discount = subtotal - discount_amount
	tax = after_discount * 0.08  # 8% 税
	total = after_discount + tax

	is_checkout_enabled = cart_items.size() > 0
	if checkout_status.is_empty() and is_checkout_enabled:
		checkout_status = "准备结算"

	end_bulk_update()


# 种子数据 — 初始几个商品
func _init() -> void:
	add_item("P001", "机械键盘", 599.0, 1)
	add_item("P002", "无线鼠标", 199.0, 1)
	add_item("P003", "USB-C Hub", 89.0, 2)
