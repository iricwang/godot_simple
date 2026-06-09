extends "res://core/base_view_model.gd"
## 复杂示例 4 — 订单状态机 (Order State Machine)
##
## 演示：
##   * 枚举式状态 (PENDING/PAID/SHIPPED/DELIVERED/CANCELLED)
##   * 状态机转换规则 (哪些状态可以转到哪些状态)
##   * 状态相关的可用操作 (按钮启用/禁用)
##   * 状态切换历史 (audit log)
##   * 异步状态转换 (支付请求 → 等待 → 完成/失败)

enum OrderState {
	PENDING,      # 待支付
	PAID,         # 已支付
	SHIPPED,      # 已发货
	DELIVERED,    # 已送达
	CANCELLED,    # 已取消
	REFUNDED,     # 已退款
}

# 状态转移图: 允许的状态转移
const STATE_TRANSITIONS = {
	OrderState.PENDING:   [OrderState.PAID, OrderState.CANCELLED],
	OrderState.PAID:      [OrderState.SHIPPED, OrderState.REFUNDED],
	OrderState.SHIPPED:   [OrderState.DELIVERED, OrderState.REFUNDED],
	OrderState.DELIVERED: [OrderState.REFUNDED],
	OrderState.CANCELLED: [],
	OrderState.REFUNDED:  [],
}

const STATE_LABELS = {
	OrderState.PENDING:   "⏳ 待支付",
	OrderState.PAID:      "💰 已支付",
	OrderState.SHIPPED:   "🚚 已发货",
	OrderState.DELIVERED: "✅ 已送达",
	OrderState.CANCELLED: "❌ 已取消",
	OrderState.REFUNDED:  "💸 已退款",
}

const STATE_COLORS = {
	OrderState.PENDING:   Color.YELLOW,
	OrderState.PAID:      Color(0.4, 0.7, 1.0),
	OrderState.SHIPPED:   Color(0.4, 0.8, 1.0),
	OrderState.DELIVERED: Color(0.4, 1.0, 0.5),
	OrderState.CANCELLED: Color(0.7, 0.7, 0.7),
	OrderState.REFUNDED:  Color(1.0, 0.5, 0.5),
}

# === 属性 ===
var order_id: String = "ORD-2024-00001"
var state: int = OrderState.PENDING
var state_label: String = STATE_LABELS[OrderState.PENDING]
var state_color: Color = STATE_COLORS[OrderState.PENDING]
var amount: float = 0.0
var item_summary: String = ""

# 可用操作
var can_pay: bool = true
var can_cancel: bool = true
var can_ship: bool = false
var can_confirm_delivery: bool = false
var can_refund: bool = false
var can_reorder: bool = false

# 异步操作状态
var is_processing: bool = false
var process_message: String = ""

# 历史日志
var history: Array = []  # [{time: str, from: int, to: int, action: str}]


# === 命令 ===

func on_pay() -> void:
	if not _can_transition(OrderState.PAID):
		return
	_log_transition(OrderState.PAID, "支付")
	# 模拟异步支付
	is_processing = true
	process_message = "正在连接支付网关..."
	# 实际项目里 await http_request
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	# 模拟成功
	is_processing = false
	process_message = "支付成功!"
	_apply_state(OrderState.PAID)


func on_cancel() -> void:
	if not _can_transition(OrderState.CANCELLED):
		return
	_log_transition(OrderState.CANCELLED, "用户取消")
	_apply_state(OrderState.CANCELLED)


func on_ship() -> void:
	if not _can_transition(OrderState.SHIPPED):
		return
	_log_transition(OrderState.SHIPPED, "商家发货")
	_apply_state(OrderState.SHIPPED)


func on_confirm_delivery() -> void:
	if not _can_transition(OrderState.DELIVERED):
		return
	_log_transition(OrderState.DELIVERED, "确认收货")
	_apply_state(OrderState.DELIVERED)


func on_refund() -> void:
	if not _can_transition(OrderState.REFUNDED):
		return
	_log_transition(OrderState.REFUNDED, "申请退款")
	_apply_state(OrderState.REFUNDED)


func on_reorder() -> void:
	# 重新下单: 重置状态为 PENDING
	_log_transition(OrderState.PENDING, "重新下单")
	_apply_state(OrderState.PENDING)


# === 内部 ===

func _can_transition(target: int) -> bool:
	if is_processing:
		return false
	return target in STATE_TRANSITIONS.get(state, [])


func _apply_state(new_state: int) -> void:
	begin_bulk_update()
	state = new_state
	state_label = STATE_LABELS[new_state]
	state_color = STATE_COLORS[new_state]
	_recompute_available_actions()
	end_bulk_update()


func _recompute_available_actions() -> void:
	can_pay = _can_transition(OrderState.PAID)
	can_cancel = _can_transition(OrderState.CANCELLED)
	can_ship = _can_transition(OrderState.SHIPPED)
	can_confirm_delivery = _can_transition(OrderState.DELIVERED)
	can_refund = _can_transition(OrderState.REFUNDED)
	# 终态可重新下单
	can_reorder = (state == OrderState.CANCELLED or state == OrderState.DELIVERED or state == OrderState.REFUNDED)


func _log_transition(target: int, action: String) -> void:
	var from = state
	var entry = {
		"time": Time.get_time_string_from_system(),
		"from": from,
		"to": target,
		"action": action,
		"from_label": STATE_LABELS[from],
		"to_label": STATE_LABELS[target],
	}
	history.append(entry)


# 种子
func _init() -> void:
	amount = 1289.0
	item_summary = "机械键盘 × 1, 无线鼠标 × 1, USB-C Hub × 2"
	history = []  # 初始为空
	_recompute_available_actions()
