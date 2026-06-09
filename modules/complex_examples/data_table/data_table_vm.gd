extends "res://core/base_view_model.gd"
## 复杂示例 6 — 数据表格 + 排序 + 分页 + 搜索过滤 (DataTable)
##
## 演示:
##   * 大量行数据 (30+) 的集合属性 — 整个 Array 作为 ObservableProperty
##   * 派生属性链: filtered_rows → sorted_rows → paged_rows
##   * 搜索过滤 (按 name/category/id 模糊匹配) + 类别过滤
##   * 排序: 列点击切换升降序 (相同列翻转, 不同列重置为升序)
##   * 分页: page_size / current_page / 自动 clamp
##   * 派生属性用 begin_bulk_update / end_bulk_update 包裹重算
##   * VM 不依赖 UI/Activity — 纯业务逻辑, 可被 headless 测试加载
##
## 数据流 (订阅):
##   vm.paged_rows 变化     → Activity 重建表格数据行
##   vm.sort_column 变化    → Activity 刷新列头箭头
##   vm.current_page 变化   → Activity 刷新 "第 N/M 页" 标签
##   vm.has_prev/next 变化  → Activity 启用/禁用翻页按钮

# === 行数据模型 ===

class TableRow extends RefCounted:
	## 单行数据. RefCounted — 不在场景树里, 由 VM 持有 Array.
	var id: int
	var name: String
	var category: String
	var price: float
	var stock: int
	var created_at: String  # ISO8601 字符串, 字典序可比

	func _init(p_id: int = 0, p_name: String = "", p_category: String = "",
			p_price: float = 0.0, p_stock: int = 0, p_created_at: String = "") -> void:
		id = p_id
		name = p_name
		category = p_category
		price = p_price
		stock = p_stock
		created_at = p_created_at

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"category": category,
			"price": price,
			"stock": stock,
			"created_at": created_at,
		}


# === 原始数据 / 输入属性 ===

var all_rows: Array = []  # Array[TableRow] — 完整数据 (种子)

var filter_query: String = ""  # 搜索关键词 (按 name / category / id_str 匹配)
var category_filter: String = ""  # 类别过滤; "" 或 "全部" = 不过滤

var sort_column: String = "id"  # "id" / "name" / "price" / "stock" / "created_at"
var sort_ascending: bool = true  # true=升序, false=降序

var page_size: int = 5  # 每页行数
var current_page: int = 0  # 当前页 (从 0 开始)


# === 派生属性 (由 _recompute 维护) ===

var filtered_rows: Array = []  # 过滤后行
var sorted_rows: Array = []  # 排序后行
var paged_rows: Array = []  # 当前页行
var total_filtered_count: int = 0  # 过滤后总数
var page_count: int = 1  # 总页数 (至少 1, 即便没数据)
var has_prev_page: bool = false
var has_next_page: bool = false


# === 命令方法 ===

func set_filter_query(q: String) -> void:
	filter_query = q
	_recompute()


func set_category_filter(c: String) -> void:
	# 兼容 "全部" / "" 都视为不过滤
	if c == "全部":
		category_filter = ""
	else:
		category_filter = c
	_recompute()


func sort_by(column: String) -> void:
	## 切换升降序: 相同列则翻转, 不同列重置为升序
	if sort_column == column:
		sort_ascending = not sort_ascending
	else:
		sort_column = column
		sort_ascending = true
	_recompute()


func go_to_page(p: int) -> void:
	## 跳页 — 越界自动 clamp 到 [0, page_count-1]
	if page_count <= 0:
		current_page = 0
		_recompute_paging_only()
		return
	current_page = clamp(p, 0, page_count - 1)
	_recompute_paging_only()


func next_page() -> void:
	go_to_page(current_page + 1)


func prev_page() -> void:
	go_to_page(current_page - 1)


func set_page_size(size: int) -> void:
	## 调整每页行数 — 保持当前页大致在合理范围
	if size <= 0:
		size = 1
	page_size = size
	# 不修改 current_page, 但 clamp 一次以防越界
	_recompute()


func reset_filters() -> void:
	## 清空搜索 / 类别过滤, 回到第 0 页
	begin_bulk_update()
	filter_query = ""
	category_filter = ""
	current_page = 0
	_recompute()  # _recompute 内部已经 bulk, 这里再 wrap 一次确保 inputs 也被压成单次通知
	end_bulk_update()


# === 内部: 派生属性重算 ===

# 全部派生量重算. 用 begin_bulk_update / end_bulk_update 包裹:
# 6 个属性更新但只触发少量合并通知.
func _recompute() -> void:
	begin_bulk_update()
	_recompute_filtered()
	_recompute_sorted()
	_recompute_paging()
	end_bulk_update()


# 只重算过滤 (filter_query / category_filter 改变时用)
func _recompute_filtered() -> void:
	var q = filter_query.strip_edges().to_lower()
	var cat = category_filter

	if q.is_empty() and cat.is_empty():
		filtered_rows = all_rows.duplicate()
		total_filtered_count = filtered_rows.size()
		return

	var result: Array = []
	for row in all_rows:
		if cat != "" and row.category != cat:
			continue
		if not q.is_empty():
			# 匹配 name / category / id(转字符串)
			var hit = false
			if q in row.name.to_lower():
				hit = true
			elif q in row.category.to_lower():
				hit = true
			elif q in str(row.id):
				hit = true
			if not hit:
				continue
		result.append(row)
	filtered_rows = result
	total_filtered_count = filtered_rows.size()


# 只重算排序 (sort_column / sort_ascending 改变时用)
func _recompute_sorted() -> void:
	sorted_rows = filtered_rows.duplicate()
	if sorted_rows.size() <= 1:
		return
	match sort_column:
		"id":
			sorted_rows.sort_custom(_cmp_id)
		"name":
			sorted_rows.sort_custom(_cmp_name)
		"price":
			sorted_rows.sort_custom(_cmp_price)
		"stock":
			sorted_rows.sort_custom(_cmp_stock)
		"created_at":
			sorted_rows.sort_custom(_cmp_created_at)
		_:
			sorted_rows.sort_custom(_cmp_id)
	# 翻转: sort_custom 是升序, 降序时 reverse
	if not sort_ascending:
		sorted_rows.reverse()


# 只重算分页 (current_page 改变时用 — 不重算 filter/sort)
func _recompute_paging_only() -> void:
	begin_bulk_update()
	_recompute_paging()
	end_bulk_update()


func _recompute_paging() -> void:
	# 总页数: ceil(total / page_size), 至少 1
	if total_filtered_count <= 0:
		page_count = 1
	else:
		page_count = int(ceil(float(total_filtered_count) / float(page_size)))
		if page_count < 1:
			page_count = 1

	# clamp current_page
	if current_page >= page_count:
		current_page = page_count - 1
	if current_page < 0:
		current_page = 0

	# 切当前页
	if total_filtered_count <= 0:
		paged_rows = []
	else:
		var start = current_page * page_size
		var end = start + page_size
		if end > sorted_rows.size():
			end = sorted_rows.size()
		if start < 0:
			start = 0
		paged_rows = sorted_rows.slice(start, end)

	has_prev_page = current_page > 0
	has_next_page = current_page < page_count - 1


# === 排序比较函数 ===
# GDScript 4: sort_custom 需要 (a, b) -> bool 表示 "a 是否应排在 b 之前"
# 升序时 a.field < b.field → true; 降序时我们用 reverse() 翻一下

func _cmp_id(a, b) -> bool:
	return a.id < b.id

func _cmp_name(a, b) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

func _cmp_price(a, b) -> bool:
	return a.price < b.price

func _cmp_stock(a, b) -> bool:
	return a.stock < b.stock

func _cmp_created_at(a, b) -> bool:
	return a.created_at < b.created_at


# === 种子数据 ===

const CATEGORIES = ["电子产品", "图书", "服装", "食品"]
const PRODUCT_NAMES = {
	"电子产品": ["机械键盘", "无线鼠标", "4K显示器", "USB-C Hub", "蓝牙耳机", "移动电源", "智能手表", "录音笔"],
	"图书":     ["深入理解计算机系统", "Clean Code", "设计模式", "算法导论", "人类简史", "三体", "代码大全", "编译原理"],
	"服装":     ["纯棉T恤", "牛仔裤", "羽绒服", "运动鞋", "棒球帽", "围巾", "皮手套", "羊毛袜"],
	"食品":     ["云南咖啡豆", "法式面包", "意大利面", "黑巧克力", "抹茶饼干", "蜂蜜柚子茶", "坚果礼盒", "海苔卷"],
}


func _init() -> void:
	# 生成 32 行种子数据 (4 类 × 8 行), 时间分布在 2026-01 到 2026-05 之间
	all_rows = []
	var next_id := 1
	var base_month := 1
	var base_day := 1
	for cat in CATEGORIES:
		var name_list: Array = PRODUCT_NAMES[cat]
		for i in range(name_list.size()):
			var name = name_list[i]
			# 月份递增 (跨类也递增), 制造不同 created_at
			var m = ((base_month + i) % 5) + 1
			var d = ((base_day + i * 3) % 28) + 1
			var hh = (i * 7 + 10) % 24
			var mm = (i * 13) % 60
			var iso = "2026-%02d-%02dT%02d:%02d:00" % [m, d, hh, mm]
			# 价格 / 库存随 id 略变
			var price = 19.9 + (next_id * 37 % 980) / 1.0  # 19.9 ~ 999.9
			var stock = (next_id * 11) % 200
			all_rows.append(TableRow.new(next_id, name, cat, price, stock, iso))
			next_id += 1
		base_month += 1
		base_day += 2
	_recompute()
