extends "res://core/base_view_model.gd"
## 复杂示例 1 — 列表渲染 (User List)
##
## 演示：
##   * ObservableProperty 的"集合属性" — 整个 Array 作为单一 ObservableProperty
##   * 增删改 (CRUD) 触发 UI 重新渲染
##   * 嵌套数据 — 每个 UserItem 也是一个独立数据对象
##   * 自定义 ValueConverter (状态文本转换)
##
## 数据流：
##   vm.users (Array[UserItem]) 变化
##   → 触发 users ObservableProperty 的 value_changed
##   → Activity 监听 → 重新构建 VBoxContainer 子节点
##   → 每个 UserItem 渲染为一行

# 单个用户数据
class UserItem extends RefCounted:
	var id: int
	var name: String
	var email: String
	var is_online: bool

	func _init(p_id: int = 0, p_name: String = "", p_email: String = "", p_online: bool = false) -> void:
		id = p_id
		name = p_name
		email = p_email
		is_online = p_online

	func to_dict() -> Dictionary:
		return {"id": id, "name": name, "email": email, "is_online": is_online}

	# 模拟"异步加载" — 实际项目里会发 HTTP 请求
	static func fetch_all() -> Array:
		await Engine.get_main_loop().process_frame  # 让出主线程
		return [
			UserItem.new(1, "张三", "zhang@example.com", true),
			UserItem.new(2, "李四", "li@example.com", false),
			UserItem.new(3, "王五", "wang@example.com", true),
			UserItem.new(4, "赵六", "zhao@example.com", true),
			UserItem.new(5, "钱七", "qian@example.com", false),
		]

# 状态文本转换器 (Bool → "在线"/"离线")
class OnlineStatusConverter:
	extends ValueConverter

	func _convert(value) -> String:
		if typeof(value) != TYPE_BOOL:
			return "?"
		return "🟢 在线" if value else "⚫ 离线"

	func _convert_back(value) -> bool:
		return "在线" in str(value)


# ---- ViewModel ----

var users: Array = []  # 完整用户列表
var filtered_users: Array = []  # 过滤后（按搜索关键词）
var search_query: String = ""
var selected_user_id: int = -1
var is_loading: bool = false
var status_message: String = "点击「加载用户」开始"

# 命令方法
func load_users_async() -> void:
	is_loading = true
	status_message = "正在加载用户列表..."
	# 模拟异步 — VM 是 RefCounted 不能 get_tree()，用 Engine.get_main_loop()
	# 实际项目里 VM 的异步加载应该通过 Activity 包装
	await Engine.get_main_loop().process_frame
	users = await UserItem.fetch_all()
	_apply_filter()
	is_loading = false
	status_message = "已加载 %d 个用户" % users.size()


func set_search_query(q: String) -> void:
	search_query = q
	_apply_filter()


func _apply_filter() -> void:
	if search_query.is_empty():
		filtered_users = users.duplicate()
	else:
		filtered_users = users.filter(func(u): return search_query in u.name or search_query in u.email)
	status_message = "显示 %d / %d 用户" % [filtered_users.size(), users.size()]


func select_user(id: int) -> void:
	selected_user_id = id


func remove_user(id: int) -> void:
	users = users.filter(func(u): return u.id != id)
	_apply_filter()
	status_message = "已删除用户 #%d" % id


func on_add_demo_user() -> void:
	var next_id = 0
	for u in users:
		if u.id >= next_id:
			next_id = u.id + 1
	users.append(UserItem.new(next_id, "新用户%d" % next_id, "new%d@example.com" % next_id, false))
	_apply_filter()
	status_message = "已添加新用户"


func on_clear_all() -> void:
	users.clear()
	_apply_filter()
	status_message = "已清空"
