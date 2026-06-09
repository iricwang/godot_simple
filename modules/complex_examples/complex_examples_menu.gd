extends Activity
## ComplexExamplesMenuActivity — 复杂示例选择菜单
##
## 入口：列出 8 个复杂示例，点击进入

const EXAMPLES = [
	{
		"id": "user_list",
		"title": "📋 列表渲染 (User List)",
		"desc": "集合属性变化触发列表重建 + 搜索过滤 + CRUD",
		"color": Color(0.5, 0.7, 1.0),
	},
	{
		"id": "shopping_cart",
		"title": "🛒 购物车 (Shopping Cart)",
		"desc": "计算属性 + 折扣码 + 实时总价 (subtotal/discount/tax/total)",
		"color": Color(1.0, 0.7, 0.3),
	},
	{
		"id": "registration_form",
		"title": "📝 注册表单 (Registration Form)",
		"desc": "实时校验 + 异步服务端校验 + 提交联动",
		"color": Color(0.4, 1.0, 0.5),
	},
	{
		"id": "order_state",
		"title": "📦 订单状态机 (Order State Machine)",
		"desc": "有限状态机 + 转换规则 + 历史时间线",
		"color": Color(0.7, 0.5, 1.0),
	},
	{
		"id": "player_card",
		"title": "⚔️ 玩家卡片 (Player Card)",
		"desc": "嵌套 VM + 装备槽位 + 战力计算",
		"color": Color(1.0, 0.4, 0.4),
	},
	{
		"id": "data_table",
		"title": "📊 数据表格 (Data Table)",
		"desc": "服务端风格分页 + 多列排序 + 类别过滤",
		"color": Color(0.3, 0.8, 0.9),
	},
	{
		"id": "websocket_feed",
		"title": "📡 实时推送 (WebSocket Feed)",
		"desc": "连接状态机 + 消息流 + 延迟显示 (Mock Client)",
		"color": Color(0.9, 0.6, 0.3),
	},
	{
		"id": "undo_redo",
		"title": "↩️ 撤销/重做 (Undo / Redo)",
		"desc": "快照栈 + 智能合并 + 完整 redo 失效逻辑",
		"color": Color(0.6, 0.9, 0.4),
	},
]

var _list_vb: VBoxContainer


func _on_create(saved_state: Dictionary) -> void:
	var tin = Transition.new(); tin.enter_type = Transition.FADE; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.FADE; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	_setup_ui()


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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	root_vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	inner.add_child(title_row)

	var title = Label.new()
	title.text = "🎯 复杂 MVVM 示例集"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var subtitle = Label.new()
	subtitle.text = "8 个真实业务场景演示 — 列表/计算/校验/状态机/嵌套/表格/推送/撤销"
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(subtitle)

	inner.add_child(HSeparator.new())

	_list_vb = VBoxContainer.new()
	_list_vb.add_theme_constant_override("separation", 8)
	inner.add_child(_list_vb)

	# 渲染列表
	for ex in EXAMPLES:
		_list_vb.add_child(_build_example_card(ex))

	inner.add_child(HSeparator.new())

	# 返回
	var back_btn = Button.new()
	back_btn.text = "← 返回首页"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _build_example_card(ex: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.18, 0.22)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	panel.add_child(vb)

	var title_lbl = Label.new()
	title_lbl.text = ex["title"]
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", ex["color"])
	vb.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = ex["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(desc_lbl)

	var btn = Button.new()
	btn.text = "打开示例 →"
	btn.pressed.connect(_on_open_example.bind(ex["id"]))
	vb.add_child(btn)

	return panel


# ---- 命令 ----

func _on_open_example(example_id: String) -> void:
	var it = Intent.new()
	it.action = "complex_" + example_id
	start_activity(it)


func _on_close_current_activity() -> void:
	finish()


func _on_back() -> void:
	finish()


# ---- 生命周期 stubs ----

func _on_start() -> void: pass
func _on_resume() -> void: pass
func _on_pause() -> void: pass
func _on_stop() -> void: pass
func _on_destroy() -> void: pass
func _on_back_pressed() -> bool: return false
