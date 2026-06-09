extends Activity
## RegistrationFormActivity — 注册表单
##
## 演示：
##   * 实时校验 (字段失焦/内容改变时)
##   * 错误提示 + 错误高亮
##   * 提交按钮根据 can_submit 自动启用/禁用
##   * 异步校验状态 (is_validating) — loading 圈
##   * 提交过程 (is_submitting)

const FormVM = preload("res://modules/complex_examples/registration_form/registration_form_vm.gd")

var vm: FormVM

# UI 引用
var _username_edit: LineEdit
var _email_edit: LineEdit
var _password_edit: LineEdit
var _confirm_edit: LineEdit
var _username_err: Label
var _email_err: Label
var _password_err: Label
var _confirm_err: Label
var _terms_check: CheckBox
var _terms_err: Label
var _submit_btn: Button
var _status_lbl: Label
var _validating_spin: Label  # 模拟 loading


const COLOR_ERROR = Color(1.0, 0.4, 0.4)
const COLOR_OK = Color(0.4, 1.0, 0.5)


func _on_create(saved_state: Dictionary) -> void:
	vm = FormVM.new()

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
	root_vb.add_theme_constant_override("separation", 6)
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
	margin.add_theme_constant_override("margin_top", 32)
	root_vb.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	margin.add_child(inner)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	inner.add_child(title_row)

	var title = Label.new()
	title.text = "📝 复杂示例 3 — 注册表单 (Registration)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：实时校验、异步服务端校验、提交按钮联动"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# 用户名
	_username_edit = _make_field(inner, "👤 用户名", "3-20 字符，字母数字下划线")
	_username_edit.text_changed.connect(vm.on_username_changed)
	_username_err = _make_err_label(inner)

	# 邮箱
	_email_edit = _make_field(inner, "📧 邮箱", "user@example.com")
	_email_edit.text_changed.connect(vm.on_email_changed)
	_email_err = _make_err_label(inner)

	# 密码
	_password_edit = _make_field(inner, "🔒 密码", "至少 8 位，含大小写+数字", true)
	_password_edit.text_changed.connect(vm.on_password_changed)
	_password_err = _make_err_label(inner)

	# 确认密码
	_confirm_edit = _make_field(inner, "🔒 确认密码", "再输一次", true)
	_confirm_edit.text_changed.connect(vm.on_confirm_changed)
	_confirm_err = _make_err_label(inner)

	# 协议
	_terms_check = CheckBox.new()
	_terms_check.text = "我已阅读并同意《服务条款》和《隐私政策》"
	_terms_check.toggled.connect(vm.on_terms_toggled)
	inner.add_child(_terms_check)
	_terms_err = _make_err_label(inner)

	# 提交按钮
	_submit_btn = Button.new()
	_submit_btn.text = "✅ 提交注册"
	_submit_btn.disabled = true
	_submit_btn.pressed.connect(_on_submit_clicked)
	inner.add_child(_submit_btn)

	# 状态
	_validating_spin = Label.new()
	_validating_spin.text = ""
	_validating_spin.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(_validating_spin)

	_status_lbl = Label.new()
	_status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	inner.add_child(_status_lbl)

	# 测试快捷按钮
	inner.add_child(HSeparator.new())
	var test_lbl = Label.new()
	test_lbl.text = "🧪 快捷填充 (用于演示):"
	inner.add_child(test_lbl)
	var test_row = HBoxContainer.new()
	inner.add_child(test_row)
	var valid_btn = Button.new()
	valid_btn.text = "✅ 有效数据"
	valid_btn.pressed.connect(_fill_valid)
	test_row.add_child(valid_btn)
	var invalid_btn = Button.new()
	invalid_btn.text = "❌ 无效数据"
	invalid_btn.pressed.connect(_fill_invalid)
	test_row.add_child(invalid_btn)
	var taken_btn = Button.new()
	taken_btn.text = "🚫 占用用户名"
	taken_btn.pressed.connect(_fill_taken_username)
	test_row.add_child(taken_btn)

	# 返回
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


func _make_field(parent: Container, label: String, placeholder: String, is_password: bool = false) -> LineEdit:
	var l = Label.new()
	l.text = label
	parent.add_child(l)
	var e = LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = is_password
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(e)
	return e


func _make_err_label(parent: Container) -> Label:
	var l = Label.new()
	l.text = ""
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COLOR_ERROR)
	parent.add_child(l)
	return l


func _bind_all() -> void:
	vm.subscribe_property("username_error", _update_username_err)
	vm.subscribe_property("email_error", _update_email_err)
	vm.subscribe_property("password_error", _update_password_err)
	vm.subscribe_property("confirm_error", _update_confirm_err)
	vm.subscribe_property("terms_error", _update_terms_err)
	vm.subscribe_property("is_validating", _update_validating)
	vm.subscribe_property("can_submit", _update_submit_btn)
	vm.subscribe_property("submit_status", _update_status)


func _update_username_err(s) -> void:
	var txt = str(s)
	_username_err.text = txt
	_username_err.visible = not txt.is_empty()


func _update_email_err(s) -> void:
	var txt = str(s)
	_email_err.text = txt
	_email_err.visible = not txt.is_empty()


func _update_password_err(s) -> void:
	var txt = str(s)
	_password_err.text = txt
	_password_err.visible = not txt.is_empty()


func _update_confirm_err(s) -> void:
	var txt = str(s)
	_confirm_err.text = txt
	_confirm_err.visible = not txt.is_empty()


func _update_terms_err(s) -> void:
	var txt = str(s)
	_terms_err.text = txt
	_terms_err.visible = not txt.is_empty()


func _update_validating(v) -> void:
	_validating_spin.text = "🔄 正在校验用户名..." if bool(v) else ""


func _update_submit_btn(v) -> void:
	_submit_btn.disabled = not bool(v)


func _update_status(s) -> void:
	_status_lbl.text = str(s)


# ---- 命令 ----

func _on_submit_clicked() -> void:
	vm.on_submit()
	if vm.is_submitting:
		# 模拟提交完成
		_status_lbl.text = "✅ 注册成功! 欢迎, " + vm.username
		vm.is_submitting = false


func _fill_valid() -> void:
	_username_edit.text = "newuser123"
	_email_edit.text = "newuser@example.com"
	_password_edit.text = "Password123"
	_confirm_edit.text = "Password123"
	_terms_check.button_pressed = true


func _fill_invalid() -> void:
	_username_edit.text = "ab"  # 太短
	_email_edit.text = "not-an-email"
	_password_edit.text = "weak"
	_confirm_edit.text = "different"
	_terms_check.button_pressed = false


func _fill_taken_username() -> void:
	_username_edit.text = "admin"  # 在 TAKEN_USERNAMES 中
	_email_edit.text = "admin@example.com"
	_password_edit.text = "Password123"
	_confirm_edit.text = "Password123"
	_terms_check.button_pressed = true


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
