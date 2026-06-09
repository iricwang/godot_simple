extends Activity
## DataTableActivity — 数据表格 + 排序 + 分页 + 搜索过滤
##
## 演示:
##   * 多控件 UI: LineEdit (搜索) + OptionButton (类别) + Button (重置)
##   * 表格: 表头点击触发排序, ↑/↓ 指示激活列
##   * 翻页: 上一页 / 下一页 / "第 N/M 页" / 每页大小调整
##   * 订阅 VM 派生属性 (paged_rows / sort_column / sort_ascending / ...)
##   * 命令方法 (sort_by / set_filter_query / set_category_filter / next/prev_page)

const DataTableVM = preload("res://modules/complex_examples/data_table/data_table_vm.gd")

var vm: DataTableVM

# === 顶部 ===
var _search_edit: LineEdit
var _category_opt: OptionButton
var _reset_btn: Button

# === 中部: 表头 + 数据行 ===
var _header_hb: HBoxContainer
var _data_vb: VBoxContainer
# 表头列: 5 个 Button 文字, 点击触发排序
var _header_btns: Dictionary = {}  # column_name -> Button

# === 底部 ===
var _prev_btn: Button
var _next_btn: Button
var _page_label: Label
var _size_opt: OptionButton

# 颜色 (按 category 上色)
const COLOR_HEADER_BG = Color(0.15, 0.18, 0.25)
const COLOR_HEADER_ACTIVE = Color(0.4, 0.7, 1.0)
const COLOR_ROW_ALT = Color(0.12, 0.12, 0.16)
const COLOR_TEXT = Color(0.9, 0.9, 0.9)
const COLOR_MUTED = Color(0.6, 0.6, 0.6)

# === 列定义 (column_key, display_name, 宽度) ===
const COLUMNS = [
	{"key": "id",         "title": "ID",       "width": 50.0},
	{"key": "name",       "title": "名称",     "width": 220.0},
	{"key": "category",   "title": "类别",     "width": 110.0},
	{"key": "price",      "title": "价格",     "width": 90.0},
	{"key": "stock",      "title": "库存",     "width": 70.0},
	{"key": "created_at", "title": "创建时间", "width": 170.0},
]


func _on_create(saved_state: Dictionary) -> void:
	vm = DataTableVM.new()

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
	title.text = "📊 复杂示例 6 — 数据表格 (DataTable)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示: 集合属性 + 派生过滤/排序/分页链 + bulk_update 批量通知"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	inner.add_child(HSeparator.new())

	# 顶部工具栏: 搜索 + 类别 + 重置
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	inner.add_child(toolbar)

	var search_lbl = Label.new()
	search_lbl.text = "🔍"
	toolbar.add_child(search_lbl)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索 名称 / 类别 / ID..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.custom_minimum_size = Vector2(220, 0)
	toolbar.add_child(_search_edit)

	var cat_lbl = Label.new()
	cat_lbl.text = "类别:"
	toolbar.add_child(cat_lbl)

	_category_opt = OptionButton.new()
	# "全部" 索引 0 — 实际是不过滤
	_category_opt.add_item("全部", 0)
	# 接下来 4 个类别 — 实际顺序无所谓, 但要可读
	_category_opt.add_item("电子产品", 1)
	_category_opt.add_item("图书", 2)
	_category_opt.add_item("服装", 3)
	_category_opt.add_item("食品", 4)
	toolbar.add_child(_category_opt)

	_reset_btn = Button.new()
	_reset_btn.text = "🔄 重置"
	toolbar.add_child(_reset_btn)

	inner.add_child(HSeparator.new())

	# === 表头 ===
	_header_hb = HBoxContainer.new()
	_header_hb.add_theme_constant_override("separation", 0)
	_header_hb.custom_minimum_size = Vector2(0, 36)
	var header_bg = PanelContainer.new()
	header_bg.add_theme_stylebox_override("panel", _make_bg_stylebox(COLOR_HEADER_BG))
	header_bg.add_child(_header_hb)
	inner.add_child(header_bg)

	# 5 个表头按钮
	for col in COLUMNS:
		var btn = Button.new()
		btn.text = col["title"]
		btn.custom_minimum_size = Vector2(col["width"], 0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if col["width"] >= 100.0 else Control.SIZE_SHRINK_BEGIN
		btn.pressed.connect(_on_header_clicked.bind(col["key"]))
		_header_hb.add_child(btn)
		_header_btns[col["key"]] = btn

	# === 数据行容器 (滚动) ===
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	_data_vb = VBoxContainer.new()
	_data_vb.name = "DataVB"
	_data_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_data_vb.add_theme_constant_override("separation", 1)
	scroll.add_child(_data_vb)

	# === 底部: 翻页 + 每页大小 ===
	inner.add_child(HSeparator.new())

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	inner.add_child(footer)

	_prev_btn = Button.new()
	_prev_btn.text = "← 上一页"
	footer.add_child(_prev_btn)

	_page_label = Label.new()
	_page_label.text = "第 0/0 页"
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_page_label)

	_next_btn = Button.new()
	_next_btn.text = "下一页 →"
	footer.add_child(_next_btn)

	var size_lbl = Label.new()
	size_lbl.text = "每页:"
	footer.add_child(size_lbl)

	_size_opt = OptionButton.new()
	_size_opt.add_item("5", 5)
	_size_opt.add_item("10", 10)
	_size_opt.add_item("20", 20)
	_size_opt.selected = 0
	footer.add_child(_size_opt)

	# 返回按钮
	inner.add_child(HSeparator.new())
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _make_bg_stylebox(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


func _bind_all() -> void:
	# === 命令绑定 (View → VM) ===
	_search_edit.text_changed.connect(_on_search_changed)
	_category_opt.item_selected.connect(_on_category_selected)
	_reset_btn.pressed.connect(_on_reset_pressed)
	_prev_btn.pressed.connect(_on_prev_pressed)
	_next_btn.pressed.connect(_on_next_pressed)
	_size_opt.item_selected.connect(_on_size_selected)

	# === 视图绑定 (VM → View) ===
	vm.subscribe_property("paged_rows", _rebuild_data_rows)
	vm.subscribe_property("sort_column", _update_sort_indicators)
	vm.subscribe_property("sort_ascending", _update_sort_indicators)
	vm.subscribe_property("current_page", _update_page_label)
	vm.subscribe_property("page_count", _update_page_label)
	vm.subscribe_property("has_prev_page", _update_paging_buttons)
	vm.subscribe_property("has_next_page", _update_paging_buttons)
	vm.subscribe_property("filter_query", _sync_filter_to_view)
	vm.subscribe_property("category_filter", _sync_filter_to_view)
	vm.subscribe_property("page_size", _sync_size_to_view)

	# 初始化一次
	_update_sort_indicators(null)
	_update_page_label(null)
	_update_paging_buttons(null)
	_rebuild_data_rows(null)


# === 命令: View → VM ===

func _on_search_changed(text: String) -> void:
	vm.set_filter_query(text)


func _on_category_selected(idx: int) -> void:
	var text = _category_opt.get_item_text(idx)
	vm.set_category_filter(text)


func _on_reset_pressed() -> void:
	vm.reset_filters()


func _on_prev_pressed() -> void:
	vm.prev_page()


func _on_next_pressed() -> void:
	vm.next_page()


func _on_size_selected(idx: int) -> void:
	var size = int(_size_opt.get_item_id(idx))
	vm.set_page_size(size)


func _on_header_clicked(column: String) -> void:
	vm.sort_by(column)


# === 渲染: VM → View ===

func _rebuild_data_rows(_v) -> void:
	# 清空旧行
	for child in _data_vb.get_children():
		child.queue_free()

	if vm.paged_rows.is_empty():
		var empty = Label.new()
		empty.text = "（无数据）"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		empty.custom_minimum_size = Vector2(0, 60)
		_data_vb.add_child(empty)
		return

	for i in range(vm.paged_rows.size()):
		var row = vm.paged_rows[i]
		_data_vb.add_child(_build_data_row(row, i))


func _build_data_row(row, idx: int) -> Control:
	var hb = HBoxContainer.new()
	hb.name = "Row_%d" % row.id
	hb.add_theme_constant_override("separation", 0)
	hb.custom_minimum_size = Vector2(0, 28)

	# 奇偶行底色
	var bg = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_ROW_ALT if idx % 2 == 1 else Color(0.08, 0.08, 0.12)
	bg.add_theme_stylebox_override("panel", sb)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.add_child(hb)
	# hb 的子节点需要 size_flags_horizontal = FILL, 但 PanelContainer 是 wrapper

	for col in COLUMNS:
		var lbl = Label.new()
		lbl.text = _format_cell(row, col["key"])
		lbl.custom_minimum_size = Vector2(col["width"], 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL if col["width"] >= 100.0 else Control.SIZE_SHRINK_BEGIN
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(lbl)

	# 返回外层 PanelContainer (保留奇偶行底色)
	return bg


func _format_cell(row, key: String) -> String:
	match key:
		"id":
			return "%d" % row.id
		"name":
			return row.name
		"category":
			return row.category
		"price":
			return "¥%.2f" % row.price
		"stock":
			var n = int(row.stock)
			if n < 20:
				return "%d ⚠" % n  # 低库存提示
			return "%d" % n
		"created_at":
			return row.created_at
		_:
			return ""


func _update_sort_indicators(_v) -> void:
	for col in COLUMNS:
		var btn: Button = _header_btns[col["key"]]
		var title = col["title"]
		if vm.sort_column == col["key"]:
			var arrow = " ↑" if vm.sort_ascending else " ↓"
			btn.text = title + arrow
			btn.add_theme_color_override("font_color", COLOR_HEADER_ACTIVE)
		else:
			btn.text = title
			btn.add_theme_color_override("font_color", COLOR_TEXT)


func _update_page_label(_v) -> void:
	# 显示 "第 N/M 页" — N 从 1 开始显示, 内部用 0-based
	var n = vm.current_page + 1
	if vm.page_count < 1:
		n = 0
	_page_label.text = "第 %d/%d 页  (共 %d 行)" % [n, vm.page_count, vm.total_filtered_count]


func _update_paging_buttons(_v) -> void:
	_prev_btn.disabled = not vm.has_prev_page
	_next_btn.disabled = not vm.has_next_page


func _sync_filter_to_view(_v) -> void:
	# 避免循环: 仅在 view 端 UI 与 vm 不一致时才更新
	if _search_edit.text != vm.filter_query:
		_search_edit.text = vm.filter_query
	if vm.category_filter.is_empty():
		_category_opt.selected = 0  # "全部"
	else:
		# 找匹配项
		for i in range(_category_opt.item_count):
			if _category_opt.get_item_text(i) == vm.category_filter:
				_category_opt.selected = i
				break


func _sync_size_to_view(_v) -> void:
	for i in range(_size_opt.item_count):
		if int(_size_opt.get_item_id(i)) == vm.page_size:
			_size_opt.selected = i
			break


# === 生命周期 ===

func _on_start() -> void:
	pass

func _on_resume() -> void:
	pass

func _on_pause() -> void:
	pass

func _on_stop() -> void:
	pass

func _on_destroy() -> void:
	if vm:
		vm.dispose()

func _on_back_pressed() -> bool:
	return false


func _on_close_current_activity() -> void:
	finish()


func _on_back() -> void:
	finish()
