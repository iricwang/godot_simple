extends Activity
## PlayerCardActivity — 玩家卡片 + 装备槽
##
## 演示：
##   * 玩家基础属性 vs 装备加成
##   * 槽位装备 (同槽位替换)
##   * 总战力 (派生属性) 实时计算
##   * 装备稀有度颜色编码

const PlayerVM = preload("res://modules/complex_examples/player_card/player_card_vm.gd")

var vm: PlayerVM

# UI
var _name_lbl: Label
var _class_lbl: Label
var _level_lbl: Label
var _atk_lbl: Label
var _def_lbl: Label
var _hp_lbl: Label
var _power_lbl: Label
var _power_progress: ProgressBar
var _slot_btns: Dictionary = {}  # {"武器": Button, ...}
var _template_menu: PopupMenu


func _on_create(saved_state: Dictionary) -> void:
	vm = PlayerVM.new()

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
	title.text = "⚔️ 复杂示例 5 — 玩家卡片 (Nested ViewModel)"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭当前 Activity"
	close_btn.pressed.connect(_on_close_current_activity)
	title_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = "演示：嵌套数据、装备槽位、战力实时计算、稀有度颜色"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	inner.add_child(desc)

	# 玩家卡片
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.2)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	inner.add_child(card)

	var card_vb = VBoxContainer.new()
	card_vb.add_theme_constant_override("separation", 4)
	card.add_child(card_vb)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 22)
	card_vb.add_child(_name_lbl)

	_class_lbl = Label.new()
	_class_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	card_vb.add_child(_class_lbl)

	_level_lbl = Label.new()
	card_vb.add_child(_level_lbl)

	card_vb.add_child(HSeparator.new())

	_atk_lbl = Label.new()
	card_vb.add_child(_atk_lbl)

	_def_lbl = Label.new()
	card_vb.add_child(_def_lbl)

	_hp_lbl = Label.new()
	card_vb.add_child(_hp_lbl)

	# 战力
	var power_row = HBoxContainer.new()
	card_vb.add_child(power_row)
	_power_lbl = Label.new()
	_power_lbl.add_theme_font_size_override("font_size", 18)
	power_row.add_child(_power_lbl)
	_power_progress = ProgressBar.new()
	_power_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_progress.min_value = 0
	_power_progress.max_value = 5000
	_power_progress.show_percentage = false
	power_row.add_child(_power_progress)

	# 操作
	var op_row = HBoxContainer.new()
	op_row.add_theme_constant_override("separation", 4)
	inner.add_child(op_row)
	var lvl_btn = Button.new()
	lvl_btn.text = "⬆ 升级"
	lvl_btn.pressed.connect(_on_level_up)
	op_row.add_child(lvl_btn)
	var reset_btn = Button.new()
	reset_btn.text = "🔄 重置"
	reset_btn.pressed.connect(_on_reset)
	op_row.add_child(reset_btn)

	inner.add_child(HSeparator.new())

	# 装备槽
	var eq_lbl = Label.new()
	eq_lbl.text = "🎒 装备槽:"
	eq_lbl.add_theme_font_size_override("font_size", 14)
	inner.add_child(eq_lbl)

	var slot_grid = GridContainer.new()
	slot_grid.columns = 2
	slot_grid.add_theme_constant_override("h_separation", 6)
	slot_grid.add_theme_constant_override("v_separation", 6)
	inner.add_child(slot_grid)

	for slot_name in ["武器", "头盔", "胸甲", "鞋子"]:
		var slot_panel = PanelContainer.new()
		var ssb = StyleBoxFlat.new()
		ssb.bg_color = Color(0.2, 0.2, 0.25)
		ssb.corner_radius_top_left = 4
		ssb.corner_radius_top_right = 4
		ssb.corner_radius_bottom_left = 4
		ssb.corner_radius_bottom_right = 4
		ssb.content_margin_left = 8
		ssb.content_margin_right = 8
		ssb.content_margin_top = 6
		ssb.content_margin_bottom = 6
		slot_panel.add_theme_stylebox_override("panel", ssb)
		slot_grid.add_child(slot_panel)

		var slot_vb = VBoxContainer.new()
		slot_panel.add_child(slot_vb)

		var slot_title = Label.new()
		slot_title.text = slot_name
		slot_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot_vb.add_child(slot_title)

		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		slot_vb.add_child(btn_row)

		var equip_btn = Button.new()
		equip_btn.text = "装备..."
		equip_btn.pressed.connect(_on_slot_equip.bind(slot_name))
		btn_row.add_child(equip_btn)

		var unequip_btn = Button.new()
		unequip_btn.text = "✕"
		unequip_btn.pressed.connect(_on_slot_unequip.bind(slot_name))
		btn_row.add_child(unequip_btn)

		_slot_btns[slot_name] = {
			"title": slot_title,
			"equip_btn": equip_btn,
			"unequip_btn": unequip_btn,
		}

	# 模板菜单
	_template_menu = PopupMenu.new()
	_template_menu.id_pressed.connect(_on_template_chosen)
	for i in range(vm.EQUIPMENT_TEMPLATES.size()):
		var t = vm.EQUIPMENT_TEMPLATES[i]
		var stars = ""
		for _s in range(t["rarity"]):
			stars += "★"
		_template_menu.add_item("[%s] %s %s (atk:%d def:%d)" % [t["slot"], stars, t["name"], t["attack"], t["defense"]], i)
	add_child(_template_menu)

	# 返回
	var back_btn = Button.new()
	back_btn.text = "← 返回示例列表"
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)


var _pending_slot: String = ""

func _bind_all() -> void:
	vm.subscribe_property("player_name", _update_name)
	vm.subscribe_property("player_class", _update_class)
	vm.subscribe_property("player_level", _update_level)
	vm.subscribe_property("total_attack", _update_atk)
	vm.subscribe_property("total_defense", _update_def)
	vm.subscribe_property("total_hp", _update_hp)
	vm.subscribe_property("power_rating", _update_power)
	vm.subscribe_property("equipment", _rebuild_slots)
	vm.subscribe_property("rarity_color", _update_rarity_color)


func _update_name(v) -> void:
	_name_lbl.text = str(v)


func _update_class(v) -> void:
	_class_lbl.text = "⚔️ 职业: " + str(v)


func _update_level(v) -> void:
	_level_lbl.text = "⭐ 等级: %d" % int(v)


func _update_atk(v) -> void:
	_atk_lbl.text = "⚔️ 攻击: %d" % int(v)


func _update_def(v) -> void:
	_def_lbl.text = "🛡️ 防御: %d" % int(v)


func _update_hp(v) -> void:
	_hp_lbl.text = "❤️ 生命: %d" % int(v)


func _update_power(v) -> void:
	var p = int(v)
	_power_lbl.text = "💪 战力: %d" % p
	_power_progress.value = p


func _update_rarity_color(c) -> void:
	_power_lbl.add_theme_color_override("font_color", c as Color)


func _rebuild_slots(_v) -> void:
	# 找出每个槽位当前装备
	for slot_name in _slot_btns.keys():
		var info = _slot_btns[slot_name]
		var equipped = null
		for e in vm.equipment:
			if e.slot == slot_name:
				equipped = e
				break
		if equipped:
			var stars = ""
			for _s in range(equipped.rarity):
				stars += "★"
			info["title"].text = "%s  %s %s" % [slot_name, stars, equipped.name]
			info["unequip_btn"].disabled = false
		else:
			info["title"].text = "%s  (空)" % slot_name
			info["unequip_btn"].disabled = true


# ---- 命令 ----

func _on_slot_equip(slot: String) -> void:
	_pending_slot = slot
	# 弹出模板菜单，过滤该槽位
	_template_menu.clear()
	for i in range(vm.EQUIPMENT_TEMPLATES.size()):
		var t = vm.EQUIPMENT_TEMPLATES[i]
		if t["slot"] != slot:
			continue
		var stars = ""
		for _s in range(t["rarity"]):
			stars += "★"
		_template_menu.add_item("%s %s (atk:%d def:%d)" % [stars, t["name"], t["attack"], t["defense"]], i)
	# 重新映射 index 到原始 templates 数组
	_template_menu.popup(Rect2(Vector2(100, 100), Vector2(400, 300)))


func _on_template_chosen(id: int) -> void:
	# id 已经是原始 templates 索引
	if id < 0 or id >= vm.EQUIPMENT_TEMPLATES.size():
		return
	var t = vm.EQUIPMENT_TEMPLATES[id]
	vm.on_equip(t)


func _on_slot_unequip(slot: String) -> void:
	vm.on_unequip(slot)


func _on_level_up() -> void:
	vm.on_level_up()


func _on_reset() -> void:
	vm.on_reset()


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
func _on_back_pressed() -> bool: return false
