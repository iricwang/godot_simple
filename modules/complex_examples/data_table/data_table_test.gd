extends RefCounted
class_name DataTableSelfTest
## DataTable 自检测试
##
## 演示:
##   * VM 纯业务逻辑, 脱离 Activity / SceneTree 也能跑
##   * 静态测试函数, 同步 (不 await), 集成任务可从 entry.gd 直接调用
##   * 覆盖: 种子数据 / 排序切换 / 过滤 / 分页 / 越界 clamp / 重置

const DataTableVM = preload("res://modules/complex_examples/data_table/data_table_vm.gd")


static func run() -> void:
	var vm = DataTableVM.new()

	# === 1. 种子数据 ===
	assert(vm.all_rows.size() >= 30, "种子数据 >= 30 行")
	assert(vm.total_filtered_count == vm.all_rows.size(), "初始 filtered_count == all_rows.size()")
	assert(vm.page_count >= 1, "page_count >= 1")
	assert(vm.paged_rows.size() > 0, "初始有数据行")
	assert(vm.current_page == 0, "初始 current_page == 0")

	# === 2. 排序 (sort_by 切换升降) ===
	vm.sort_by("price")
	assert(vm.sort_column == "price", "sort_column == 'price'")
	assert(vm.sort_ascending, "首次点 price → 升序")
	assert(vm.sorted_rows[0].price <= vm.sorted_rows[-1].price, "升序: 首行 <= 末行")

	vm.sort_by("price")
	assert(vm.sort_column == "price", "sort_column 仍是 price")
	assert(not vm.sort_ascending, "再点一次 → 降序")
	assert(vm.sorted_rows[0].price >= vm.sorted_rows[-1].price, "降序: 首行 >= 末行")

	# 切换不同列 → 重置为升序
	vm.sort_by("name")
	assert(vm.sort_column == "name", "切换到 name 列")
	assert(vm.sort_ascending, "不同列重置为升序")

	# === 3. 搜索过滤 ===
	vm.set_filter_query("xxx_unique_marker_xxx")
	assert(vm.filtered_rows.is_empty(), "无匹配关键词 → filtered_rows 空")
	assert(vm.total_filtered_count == 0, "无匹配 → total_filtered_count == 0")
	assert(vm.paged_rows.is_empty(), "无匹配 → paged_rows 空")

	vm.set_filter_query("")
	assert(vm.filtered_rows.size() == vm.all_rows.size(), "清空搜索 → 全部")
	assert(vm.total_filtered_count == vm.all_rows.size(), "清空搜索 → 总数还原")

	# 实际匹配: "键盘" 出现在第 1 行 (机械键盘, 电子产品)
	vm.set_filter_query("键盘")
	assert(vm.filtered_rows.size() >= 1, "搜索 '键盘' → 至少 1 行")
	assert(vm.filtered_rows.size() < vm.all_rows.size(), "搜索 '键盘' → 少于全部")
	for r in vm.filtered_rows:
		assert("键盘" in r.name, "匹配项名字含 '键盘'")
	vm.set_filter_query("")

	# === 4. 类别过滤 ===
	# 选 "图书" (id 9-16 在种子里, 但我们直接按 category 字段断言)
	vm.set_category_filter("图书")
	assert(vm.category_filter == "图书", "category_filter 已设置")
	assert(vm.filtered_rows.size() == 8, "图书类应有 8 行 (种子里 4 类 × 8)")
	for r in vm.filtered_rows:
		assert(r.category == "图书", "图书过滤后都是图书类")
	assert(vm.total_filtered_count == 8, "图书 total_filtered_count == 8")

	# "全部" 字符串 → 清空
	vm.set_category_filter("全部")
	assert(vm.category_filter.is_empty(), "'全部' → 清空 category_filter")
	assert(vm.filtered_rows.size() == vm.all_rows.size(), "清空类别 → 全部")

	# === 5. 分页 ===
	vm.page_size = 5
	assert(vm.page_count >= 6, "30+ 行 5/页 → 至少 6 页 (实际: %d)" % vm.page_count)
	assert(vm.paged_rows.size() == 5, "第 0 页 5 行 (实际: %d)" % vm.paged_rows.size())
	assert(not vm.has_prev_page, "第 0 页 has_prev_page = false")
	assert(vm.has_next_page, "第 0 页 has_next_page = true")

	vm.next_page()
	assert(vm.current_page == 1, "next_page → current_page == 1")
	assert(vm.has_prev_page, "第 1 页 has_prev_page = true")
	assert(vm.paged_rows.size() == 5, "第 1 页 5 行")

	# 跳到末页
	vm.go_to_page(vm.page_count - 1)
	assert(vm.current_page == vm.page_count - 1, "go_to_page(末页)")
	assert(not vm.has_next_page, "末页 has_next_page = false")
	assert(vm.has_prev_page, "末页 has_prev_page = true")

	# 越界 clamp
	vm.go_to_page(999)
	assert(vm.current_page == vm.page_count - 1, "go_to_page(999) → clamp 到末页")

	vm.go_to_page(-1)
	assert(vm.current_page == 0, "go_to_page(-1) → clamp 到 0")

	# 边界
	vm.go_to_page(0)
	assert(vm.current_page == 0, "go_to_page(0) → 0")

	# === 6. 复合: 搜索 + 排序 + 分页 ===
	vm.set_filter_query("a")  # 几乎所有名字都含 'a' (英文名 'Clean Code', 'USB-C Hub' 等)
	vm.sort_by("price")
	vm.go_to_page(0)
	assert(vm.filtered_rows.size() > 0, "搜索 'a' 至少匹配一行")
	assert(vm.sorted_rows.size() == vm.filtered_rows.size(), "sorted_rows == filtered_rows")
	assert(vm.paged_rows.size() <= vm.page_size, "paged_rows.size <= page_size")

	# === 7. 重置 ===
	vm.reset_filters()
	assert(vm.filter_query.is_empty(), "重置清空 filter_query")
	assert(vm.category_filter.is_empty(), "重置清空 category_filter")
	assert(vm.current_page == 0, "重置回到第 0 页")
	assert(vm.total_filtered_count == vm.all_rows.size(), "重置后 total == all")

	vm.dispose()
	print("  OK")
