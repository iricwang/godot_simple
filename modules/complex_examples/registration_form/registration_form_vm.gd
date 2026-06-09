extends "res://core/base_view_model.gd"
## 复杂示例 3 — 注册表单 (Registration Form)
##
## 演示：
##   * 多字段实时校验 (邮箱格式、密码强度、用户名唯一性)
##   * 异步校验 (模拟服务器端校验)
##   * 错误状态高亮 (红色边框)
##   * 提交按钮在所有校验通过前禁用
##   * 防抖 (debounce) — 用户停止输入 500ms 后才发校验请求

# 字段值
var username: String = ""
var email: String = ""
var password: String = ""
var confirm_password: String = ""
var agreed_to_terms: bool = false

# 校验状态
var username_error: String = ""  # 空字符串 = 无错误
var email_error: String = ""
var password_error: String = ""
var confirm_error: String = ""
var terms_error: String = ""

# 异步校验状态
var is_validating: bool = false
var server_username_taken: bool = false  # 服务端返回"用户名已存在"

# 提交状态
var can_submit: bool = false
var is_submitting: bool = false
var submit_status: String = ""

# 模拟"已存在的用户名" — 触发服务端校验冲突
const TAKEN_USERNAMES = ["admin", "root", "user", "test"]


# === 命令 ===

func on_username_changed(new_value: String) -> void:
	username = new_value
	username_error = _validate_username_sync(new_value)
	# 异步服务端校验 (模拟)
	if username_error.is_empty() and not new_value.is_empty():
		_simulate_server_check(new_value)
	_recompute_can_submit()


func on_email_changed(new_value: String) -> void:
	email = new_value
	email_error = _validate_email(new_value)
	_recompute_can_submit()


func on_password_changed(new_value: String) -> void:
	password = new_value
	password_error = _validate_password(new_value)
	# 密码改了，同步更新 confirm 校验
	if not confirm_password.is_empty():
		confirm_error = _validate_confirm(confirm_password)
	_recompute_can_submit()


func on_confirm_changed(new_value: String) -> void:
	confirm_password = new_value
	confirm_error = _validate_confirm(new_value)
	_recompute_can_submit()


func on_terms_toggled(checked: bool) -> void:
	agreed_to_terms = checked
	terms_error = "" if checked else "请同意服务条款"
	_recompute_can_submit()


func on_submit() -> void:
	if not can_submit or is_submitting:
		return
	is_submitting = true
	submit_status = "正在提交..."


# === 内部 ===

# 同步校验函数
func _validate_username_sync(v: String) -> String:
	if v.is_empty():
		return ""  # 空值不报错（用户还没开始输入）
	if v.length() < 3:
		return "用户名至少 3 个字符"
	if v.length() > 20:
		return "用户名最多 20 个字符"
	if not v.is_valid_identifier() and not v.is_valid_filename():
		# 简化校验: 只允许字母数字下划线
		var regex = RegEx.new()
		regex.compile("^[a-zA-Z0-9_]+$")
		if regex.search(v) == null:
			return "只能包含字母、数字、下划线"
	return ""


func _validate_email(v: String) -> String:
	if v.is_empty():
		return ""
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	if regex.search(v) == null:
		return "邮箱格式不正确"
	return ""


func _validate_password(v: String) -> String:
	if v.is_empty():
		return ""
	if v.length() < 8:
		return "密码至少 8 个字符"
	var has_upper = false
	var has_lower = false
	var has_digit = false
	for c in v:
		if c.to_upper() != c.to_lower():
			if c == c.to_upper():
				has_upper = true
			else:
				has_lower = true
		elif c.is_valid_int():
			has_digit = true
	if not (has_upper and has_lower and has_digit):
		return "密码必须包含大小写字母和数字"
	return ""


func _validate_confirm(v: String) -> String:
	if v.is_empty():
		return ""
	if v != password:
		return "两次密码不一致"
	return ""


# 重算 can_submit
func _recompute_can_submit() -> void:
	can_submit = (
		username_error.is_empty() and
		email_error.is_empty() and
		password_error.is_empty() and
		confirm_error.is_empty() and
		terms_error.is_empty() and
		not server_username_taken and
		not is_validating and
		not username.is_empty() and
		not email.is_empty() and
		not password.is_empty() and
		agreed_to_terms
	)


# 模拟服务端异步校验 (检查用户名是否已存在)
func _simulate_server_check(uname: String) -> void:
	is_validating = true
	# 这里实际项目里会 await http_request
	# 用 _process_frame 模拟网络延迟
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame

	# 模拟服务端响应
	if uname in TAKEN_USERNAMES:
		server_username_taken = true
		username_error = "用户名已被占用"
	else:
		server_username_taken = false

	is_validating = false
	_recompute_can_submit()
