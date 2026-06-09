extends Control
## Plinko 游戏场景
##
##玩法：点击顶部区域投放球，球经过交错钉子，落到可配置的槽位中按分值得分。
##
## 实现：自写连续物理（semi-implicit Euler积分 +固定子步圆-圆碰撞）。
##球有位置/速度，每帧：
##1)多次子步（sub-step）逐步积分位置，cap 最大速度避免隧穿
##2) 每步检测与所有钉子的重叠，按法线反弹（restitution）+切向摩擦
##3)撞钉子时生成音效 +闪烁 +角速度扰动
##4) 若 enable_targeting=true 且 target_slot>=0：额外加微弱侧向引导力
## （PID思路，靠近袋子时衰减到0，避免硬拐）
##5)球进入槽位区域时按所在 slot 计分 +渐隐
##
## 配置：通过 @export暴露槽数/分值/颜色/物理参数/引导强度，
## Inspector 可改，无需改代码。
##
##节点：
## Background —渐变背景
## BoardFrame —钉子板外框
## DropZone —顶部点击接收区 +瞄准器
## PegLayer — 程序生成的钉子
## SlotLayer — 程序生成的得分槽
## BallLayer —飞行中的球
## UI —顶栏分数/剩余球 +顶部倍率指示器
## ResultPanel —结束面板（replay/返回）
## MusicPlayer —背景音乐
## SFXPlayer —短音效
##
##节点引用都通过 add_child +引用变量，不依赖 .tscn预连接，便于脚本自举。
# ============================================================
# 节点（脚本生成）
# ============================================================
var _drop_zone: Control
var _peg_layer: Control
var _slot_layer: Control
var _ball_layer: Control
var _ui: Control
var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _result_panel: Control

# UI 标签（脚本创建）
var _score_label: Label
var _balls_label: Label
var _multiplier_label: Label
var _aim_hint: Label
var _combo_label: Label

# 资源
const SFX_DROP := preload("res://modules/plinko_game/sfx/drop.wav")
const SFX_PEG := preload("res://modules/plinko_game/sfx/peg_hit.wav")
const SFX_SCORE := preload("res://modules/plinko_game/sfx/score.wav")
const SFX_BUTTON := preload("res://modules/plinko_game/sfx/button.wav")
const SFX_WIN := preload("res://modules/plinko_game/sfx/win.wav")
const SFX_OVER := preload("res://modules/plinko_game/sfx/game_over.wav")
const MUSIC := preload("res://modules/plinko_game/plinko_background_music.mp3")

# ============================================================
# 配置（@export — Inspector /运行时可改）
# ============================================================
const SAVE_PATH := "user://plinko_save.cfg"

@export_group("Board")
@export_range(400.0,1200.0) var board_width: float =900.0
@export_range(800.0,1800.0) var board_height: float =1300.0
@export_range(80.0,400.0) var board_top: float =200.0
@export_range(3,20) var peg_rows: int =10
@export_range(50.0,150.0) var peg_spacing_x: float =100.0
@export_range(50.0,150.0) var peg_spacing_y: float =95.0
@export_range(5.0,30.0) var peg_radius: float =11.0
@export var staggered: bool = true #奇偶行错位半格（Galton board风格）

@export_group("Ball")
@export_range(10.0,60.0) var ball_radius: float =15.0
@export_range(0.0,1.0) var ball_bounce: float =0.5
@export_range(0.0,1.0) var ball_friction: float =0.25
@export_range(100.0,3000.0) var max_speed: float =900.0
@export_range(1,12) var physics_substeps: int =3 # 每帧子步数，越大越不易隧穿，但 CPU也会涨

@export_group("Physics")
@export_range(100.0,3000.0) var gravity: float =1600.0
@export_range(0.0,1.0) var peg_bounce: float =0.5
@export_range(-200.0,200.0) var horizontal_wind: float =0.0
@export_range(0.0,80.0) var drop_jitter: float =3.0 #投放初始水平扰动

@export_group("Targeting")
@export var enable_targeting: bool = false # 是否启用指定入袋
@export_range(-1,32) var target_slot: int = -1 # -1 =随机/自然物理；>=0 = 指定 slot
@export_range(0.0,1.0) var guidance_strength: float =0.55 #引导力强度
@export_range(0.50,0.99) var guidance_falloff: float =0.85 #越接近目标越弱

@export_group("Slots")
@export_range(3,21) var slot_count: int =9
@export_range(60.0,200.0) var slot_height: float =100.0
@export var slot_values: Array[int] = [100,200,500,1000,2000,1000,500,200,100]
@export var slot_colors: Array[Color] = [
	Color(0.45,0.50,0.65,0.95),
	Color(0.35,0.55,0.85,0.95),
	Color(0.25,0.70,0.55,0.95),
	Color(1.00,0.78,0.20,0.95),
	Color(1.00,0.40,0.55,0.95),
	Color(1.00,0.78,0.20,0.95),
	Color(0.25,0.70,0.55,0.95),
	Color(0.35,0.55,0.85,0.95),
	Color(0.45,0.50,0.65,0.95),
]

#派生属性（运行期随 export变化）
var board_left: float:
	get: return (1080.0 - board_width) *0.5
var board_right: float:
	get: return board_left + board_width
var pegs_per_even_row: int:
	get: return slot_count +1
var pegs_per_odd_row: int:
	get: return slot_count
var col_spacing: float:
	get: return board_width / float(slot_count)
# ============================================================
# 状态
# ============================================================
var score: int = 0
var balls_remaining: int = 10
var high_score: int = 0
var coins: int = 1000
var music_volume_db: float = -8.0
var sfx_volume_db: float = 0.0
var music_enabled: bool = true
var sfx_enabled: bool = true

var _pegs: Array[Dictionary] = []  # [{node, x, y, radius, row, col}]
var _peg_buckets: Array = []  #长度=peg_rows，每行是该行钉子列表(空间剖分)
var _slots: Array[Dictionary] = []  # [{node, label, x, y, w, h, value, index}]
var _active_balls: Array = []  # [{node, x, y, vx, vy, path:[..], on_peg_hit_cb, on_land_cb}]
var _game_over: bool = false
var _drop_locked: bool = false  # 投放互斥：一次只能投一颗


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	_setup_viewport()
	_load_save()
	_build_scene_tree()
	_build_audio()
	_build_ui()
	_build_board()
	_build_slots()
	_connect_signals()
	_refresh_topbar()
	_play_intro_animation()


func _setup_viewport() -> void:
	var vp := get_viewport()
	vp.content_scale_size = Vector2i(1080, 1920)
	vp.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	vp.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# ============================================================
# 存档
# ============================================================
func _load_save() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		high_score = int(cfg.get_value("data", "high_score", 0))
		coins = int(cfg.get_value("data", "coins", 1000))
	else:
		high_score = 0
		coins = 1000


func _save_progress() -> void:
	if score > high_score:
		high_score = score
	var cfg := ConfigFile.new()
	cfg.set_value("data", "high_score", high_score)
	cfg.set_value("data", "coins", coins)
	cfg.save(SAVE_PATH)


# ============================================================
# 场景树（脚本自举）
# ============================================================
func _build_scene_tree() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.13, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 渐变叠加（多个色块 + alpha 模拟）
	for i in range(3):
		var rect := ColorRect.new()
		var t := float(i) / 2.0
		rect.color = Color(0.18 - 0.05 * t, 0.08, 0.32 - 0.08 * t, 0.18 - 0.05 * t)
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)

	# 钉子板外框
	var frame := Panel.new()
	frame.name = "BoardFrame"
	frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
	frame.offset_left = 30
	frame.offset_top = 180
	frame.offset_right = -30
	frame.offset_bottom = 1820
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.08, 0.10, 0.16, 0.6)
	fs.border_width_left = 3
	fs.border_width_top = 3
	fs.border_width_right = 3
	fs.border_width_bottom = 3
	fs.border_color = Color(0.45, 0.55, 0.75, 0.6)
	fs.corner_radius_top_left = 22
	fs.corner_radius_top_right = 22
	fs.corner_radius_bottom_left = 22
	fs.corner_radius_bottom_right = 22
	frame.add_theme_stylebox_override("panel", fs)
	add_child(frame)

	# 钉子层
	_peg_layer = Control.new()
	_peg_layer.name = "PegLayer"
	_peg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_peg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_peg_layer)

	# 槽位层
	_slot_layer = Control.new()
	_slot_layer.name = "SlotLayer"
	_slot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot_layer)

	# 球层
	_ball_layer = Control.new()
	_ball_layer.name = "BallLayer"
	_ball_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ball_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ball_layer)

	# 投放区
	_drop_zone = Control.new()
	_drop_zone.name = "DropZone"
	_drop_zone.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_drop_zone.offset_top = 180
	_drop_zone.offset_bottom = 250  # 顶部一小条
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_drop_zone)

	# UI 层
	_ui = Control.new()
	_ui.name = "UI"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	# 玩家分倍率提示（顶部 DropZone 下方独立区域）
	_multiplier_label = Label.new()
	_multiplier_label.name = "MultiplierLabel"
	_multiplier_label.text = ""
	_multiplier_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_multiplier_label.offset_top = 260
	_multiplier_label.offset_bottom = 300
	_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplier_label.add_theme_font_size_override("font_size", 22)
	_multiplier_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.7))
	_multiplier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_multiplier_label)

	# 连击提示
	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.text = ""
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.offset_top = 320
	_combo_label.offset_bottom = 360
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 36)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30, 0.0))  # 初始透明
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_combo_label)


# ============================================================
# 音频
# ============================================================
func _build_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "MusicPlayer"
	_music.stream = MUSIC
	_music.bus = "Music"
	_music.volume_db = music_volume_db if music_enabled else -80.0
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	_music.play()

	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SFXPlayer"
	_sfx.bus = "SFX"
	_sfx.volume_db = sfx_volume_db if sfx_enabled else -80.0
	add_child(_sfx)


func _on_music_finished() -> void:
	if _music and _music.stream:
		_music.play()


func play_sfx(stream: AudioStream, vol_offset_db: float = 0.0) -> void:
	if not sfx_enabled or _sfx == null:
		return
	_sfx.stream = stream
	_sfx.volume_db = sfx_volume_db + vol_offset_db
	_sfx.play()


# ============================================================
# UI
# ============================================================
func _build_ui() -> void:
	# 顶栏背景
	var top := Panel.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 20
	top.offset_bottom = 130
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.08, 0.10, 0.16, 0.85)
	ts.corner_radius_top_left = 24
	ts.corner_radius_top_right = 24
	ts.corner_radius_bottom_left = 24
	ts.corner_radius_bottom_right = 24
	ts.border_width_left = 2
	ts.border_width_top = 2
	ts.border_width_right = 2
	ts.border_width_bottom = 2
	ts.border_color = Color(0.40, 0.50, 0.70, 0.5)
	top.add_theme_stylebox_override("panel", ts)
	_ui.add_child(top)

	# 顶栏内容用 HBoxContainer：左 返回 / 中 分数·球数 / 右 留空
	var top_box := HBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_box.offset_left = 20
	top_box.offset_top = 20
	top_box.offset_right = -20
	top_box.offset_bottom = 130
	top_box.add_theme_constant_override("separation", 0)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top_box)

	# 左：返回按钮
	var back := Button.new()
	back.text = "← 返回"
	back.custom_minimum_size = Vector2(220,80)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_button_style(back,
		Color(0.18, 0.20, 0.28, 0.9),
		Color(0.28, 0.32, 0.42, 1.0),
		Color(0.10, 0.12, 0.18, 1.0),
		20, 26, Color(0.95, 0.95, 1.0, 1))
	back.pressed.connect(_on_back_to_menu_pressed)
	top_box.add_child(back)

	# 中：分数 + 球数（垂直居中）
	var center_box := VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 4)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(center_box)

	_score_label = Label.new()
	_score_label.text = "★ 0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 40)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1))
	center_box.add_child(_score_label)

	_balls_label = Label.new()
	_balls_label.text = "● 10"
	_balls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balls_label.add_theme_font_size_override("font_size", 26)
	_balls_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1))
	center_box.add_child(_balls_label)

	# 右：占位（保持对称）
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(220,80)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(spacer)

	# 投放区提示（挪进 DropZone 内部居中）
	var hint := Label.new()
	hint.name = "DropHint"
	hint.text = "↑ 点击此处投放球"
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.95, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_child(hint)


func _apply_button_style(btn: Button, normal: Color, hover: Color, pressed: Color,
		radius: int, font_size: int, font_color: Color) -> void:
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var c := normal
		match state_name:
			"hover": c = hover
			"pressed": c = pressed
			"disabled": c = normal.darkened(0.4)
		sb.bg_color = c
		sb.corner_radius_top_left = radius
		sb.corner_radius_top_right = radius
		sb.corner_radius_bottom_left = radius
		sb.corner_radius_bottom_right = radius
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state_name, sb)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_font_size_override("font_size", font_size)


func _refresh_topbar() -> void:
	_score_label.text = "★ %d" % score
	_balls_label.text = "● %d" % balls_remaining


# ============================================================
# 钉子板
# ============================================================
func _build_board() -> void:
	#清理
	for c in _peg_layer.get_children():
		c.queue_free()
	_pegs.clear()

	var even_count: int = pegs_per_even_row
	var odd_count: int = pegs_per_odd_row
	var cs: float = col_spacing

	for row in range(peg_rows):
		var pegs_in_row: int = even_count if row %2 ==0 else odd_count
		var offset: float =0.0 if row %2 ==0 else (cs *0.5 if staggered else 0.0)
		for col in range(pegs_in_row):
			var px: float = board_left + offset + col * cs + cs *0.5
			var py: float = board_top + row * peg_spacing_y
			var peg := _make_peg_node(px, py)
			_peg_layer.add_child(peg)
			_pegs.append({
				"node": peg,
				"x": px,
				"y": py,
				"radius": peg_radius,
				"row": row,
				"col": col,
			})
	#space partition bucket: each row has a list
	_peg_buckets.clear()
	_peg_buckets.resize(peg_rows)
	for row in range(peg_rows):
		_peg_buckets[row] = [] as Array
	for p in _pegs:
		_peg_buckets[p["row"]].append(p)



func _make_peg_node(x: float, y: float) -> Control:
	# 用 Control + StyleBox渲染钉子
	var size: float = peg_radius *2.0
	var peg := Panel.new()
	peg.size = Vector2(size, size)
	peg.position = Vector2(x - peg_radius, y - peg_radius)
	peg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75,0.82,0.95,1)
	sb.corner_radius_top_left = peg_radius
	sb.corner_radius_top_right = peg_radius
	sb.corner_radius_bottom_left = peg_radius
	sb.corner_radius_bottom_right = peg_radius
	#简单立体感：内高光
	sb.shadow_color = Color(0.20,0.25,0.35,0.6)
	sb.shadow_size =3
	# border
	sb.border_width_left =1
	sb.border_width_top =1
	sb.border_width_right =1
	sb.border_width_bottom =1
	sb.border_color = Color(0.90,0.95,1.0,0.5)
	peg.add_theme_stylebox_override("panel", sb)
	return peg


# ============================================================
# 槽位
# ============================================================
func _build_slots() -> void:
	# 若 Inspector改了 slot_count，自动调整分值/颜色数组长度
	_ensure_slot_arrays()
	for c in _slot_layer.get_children():
		c.queue_free()
	_slots.clear()

	var slot_y: float = board_top + peg_rows * peg_spacing_y +40
	var slot_w: float = board_width / float(slot_count)
	for i in range(slot_count):
		var x: float = board_left + i * slot_w
		var panel := Panel.new()
		panel.size = Vector2(slot_w -4, slot_height)
		panel.position = Vector2(x +2, slot_y)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = slot_colors[i]
		sb.corner_radius_top_left =12
		sb.corner_radius_top_right =12
		sb.corner_radius_bottom_left =12
		sb.corner_radius_bottom_right =12
		sb.border_width_left =2
		sb.border_width_top =2
		sb.border_width_right =2
		sb.border_width_bottom =2
		sb.border_color = Color(1,1,1,0.25)
		panel.add_theme_stylebox_override("panel", sb)
		_slot_layer.add_child(panel)

		# 分值文字
		var lbl := Label.new()
		lbl.text = str(slot_values[i])
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size",28)
		lbl.add_theme_color_override("font_color", Color(1,1,1,1))
		lbl.add_theme_constant_override("outline_size",2)
		lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.5))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

		_slots.append({
			"node": panel,
			"label": lbl,
			"x": x,
			"y": slot_y,
			"w": slot_w,
			"h": slot_height,
			"value": slot_values[i],
			"index": i,
		})


func _ensure_slot_arrays() -> void:
	# 让 slot_values / slot_colors长度匹配 slot_count
	while slot_values.size() < slot_count:
		slot_values.append(100)
	while slot_values.size() > slot_count:
		slot_values.pop_back()
	var default_palette: Array[Color] = [
		Color(0.45,0.50,0.65,0.95),
		Color(0.35,0.55,0.85,0.95),
		Color(0.25,0.70,0.55,0.95),
		Color(1.00,0.78,0.20,0.95),
		Color(1.00,0.40,0.55,0.95),
	]
	while slot_colors.size() < slot_count:
		slot_colors.append(default_palette[slot_colors.size() % default_palette.size()])
	while slot_colors.size() > slot_count:
		slot_colors.pop_back()



func _connect_signals() -> void:
	_drop_zone.gui_input.connect(_on_drop_zone_input)
	_drop_zone.mouse_entered.connect(_on_drop_zone_hovered)


func _on_drop_zone_hovered() -> void:
	# 鼠标进入顶部区域时高亮瞄准线
	if _game_over or _drop_locked or balls_remaining <= 0:
		return


# ============================================================
# 投放
# ============================================================
func _on_drop_zone_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_drop(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_drop(event.position)


func _handle_drop(local_pos: Vector2) -> void:
	if _game_over or _drop_locked or balls_remaining <= 0:
		return
	if _active_balls.size() >= 3:
		# 最多同屏 3 球，避免音效混乱
		return
	_drop_locked = true
	balls_remaining -= 1
	_refresh_topbar()
	play_sfx(SFX_DROP)
	_spawn_ball(local_pos)
	# 短暂解锁（让连点也能投下一颗）
	await get_tree().create_timer(0.10).timeout
	_drop_locked = false
	if balls_remaining <= 0 and _active_balls.is_empty():
		_end_game()


# ============================================================
# 球
# ============================================================
func _spawn_ball(local_pos: Vector2) -> void:
	#钳制 x 到合理范围
	var x: float = clamp(local_pos.x, board_left + ball_radius +4, board_right - ball_radius -4)
	#投放初始水平 jitter（drop_jitter=0 时完全可复现）
	x += randf_range(-drop_jitter, drop_jitter)
	x = clamp(x, board_left + ball_radius +4, board_right - ball_radius -4)
	# 起手：球出现在钉子板上沿外（看起来像从屏外落入）
	var y: float = board_top - peg_spacing_y *0.5

	var ball := Panel.new()
	var bsize: float = ball_radius *2.0
	ball.size = Vector2(bsize, bsize)
	ball.position = Vector2(x - ball_radius, y - ball_radius)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0,0.82,0.25,1.0)
	sb.corner_radius_top_left = ball_radius
	sb.corner_radius_top_right = ball_radius
	sb.corner_radius_bottom_left = ball_radius
	sb.corner_radius_bottom_right = ball_radius
	sb.shadow_color = Color(0.6,0.45,0.0,0.6)
	sb.shadow_size =6
	sb.border_width_left =2
	sb.border_width_top =2
	sb.border_width_right =2
	sb.border_width_bottom =2
	sb.border_color = Color(1,1,0.85,0.7)
	ball.add_theme_stylebox_override("panel", sb)
	_ball_layer.add_child(ball)

	#真实物理：每帧多次子步圆-圆碰撞 + 半隐式欧拉积分
	var ball_data := {
		"node": ball,
		"x": x,
		"y": y,
		"vx": randf_range(-8.0,8.0),
		"vy":0.0,
		"hit_count":0,
		"last_peg_y": -1e9,
		"settled": false,
		"target_slot": target_slot, #投放时锁定目标，避免运行中改了影响在飞球
		"rng": RandomNumberGenerator.new(),
	}
	ball_data.rng.randomize()
	_active_balls.append(ball_data)



func _process(delta: float) -> void:
	if _active_balls.is_empty():
		return
	#限制 delta防止极大跳变（断点恢复等）
	var dt: float = min(delta,0.033)
	# 子步越小越不易隧穿；physics_substeps=6 时 dt/6 ≈2.7ms @60fps
	var n: int = max(1, physics_substeps)
	var sub_dt: float = dt / float(n)
	var snapshot: Array = _active_balls.duplicate()
	for b in snapshot:
		if b in _active_balls and not (b["settled"] as bool):
			_physics_step(b, sub_dt)
	#同步节点位置
	for b in _active_balls:
		(b["node"] as Control).position = Vector2(b["x"] - ball_radius, b["y"] - ball_radius)


func _physics_step(b: Dictionary, sub_dt: float) -> void:
	#1) 应用力（重力 +风力 +引导力）
	var ax: float = horizontal_wind
	var ay: float = gravity
	if enable_targeting and (b["target_slot"] as int) >=0:
		_apply_guidance(b, sub_dt)
	#2)积分（semi-implicit Euler）
	var vx: float = (b["vx"] as float) + ax * sub_dt
	var vy: float = (b["vy"] as float) + ay * sub_dt
	# cap 最大速度
	var sp2: float = vx * vx + vy * vy
	var max2: float = max_speed * max_speed
	if sp2 > max2:
		var s: float = max_speed / sqrt(sp2)
		vx *= s
		vy *= s
	#3)推进位置
	var x: float = (b["x"] as float) + vx * sub_dt
	var y: float = (b["y"] as float) + vy * sub_dt
	#4) 左右墙
	if x < board_left + ball_radius:
		x = board_left + ball_radius
		vx = -vx * ball_bounce
	elif x > board_right - ball_radius:
		x = board_right - ball_radius
		vx = -vx * ball_bounce
	#5)钉子碰撞（空间剖分：只检测球当前 y附近的 ±1 行钉子）
	#球当前所在的 row估计（按 y）
	var cur_row: int = int((y - board_top) / peg_spacing_y)
	cur_row = clamp(cur_row,0, peg_rows -1)
	#只检测当前行 +上下各一行（球跨行时漏1帧几乎无影响）
	var row_lo: int = max(0, cur_row -1)
	var row_hi: int = min(peg_rows -1, cur_row +1)
	var ball_r: float = ball_radius
	#预计算常用值
	var ax2: float = ax
	var ay2: float = ay
	for row_idx in range(row_lo, row_hi +1):
		var bucket = _peg_buckets[row_idx]
		if bucket == null: continue
		for p in bucket:
			var dx: float = x - (p["x"] as float)
			var dy: float = y - (p["y"] as float)
			var min_d: float = ball_r + (p["radius"] as float)
			var d2: float = dx * dx + dy * dy
			if d2 >= min_d * min_d: continue
			var d: float = (sqrt(d2),0.0001)[d2 <=1e-9]
			var nx: float = dx / d
			var ny: float = dy / d
			#位置修正（推到刚好接触）
			x = (p["x"] as float) + nx * min_d
			y = (p["y"] as float) + ny * min_d
			# 法向分量反射
			var vn: float = vx * nx + vy * ny
			if vn <0.0:
				vx -= (1.0 + peg_bounce) * vn * nx
				vy -= (1.0 + peg_bounce) * vn * ny
			#切向摩擦
			var vn_dot: float = vx * nx + vy * ny
			var vt_x: float = vx - vn_dot * nx
			var vt_y: float = vy - vn_dot * ny
			vx -= vt_x * ball_friction
			vy -= vt_y * ball_friction
			#扰动（让球有"擦边"感）
			vx += nx *6.0 * b["rng"].randf_range(-1.0,1.0)
			#撞钉音效 +闪烁
			b["hit_count"] = (b["hit_count"] as int) +1
			var py_v: float = p["y"] as float
			if abs(py_v - (b["last_peg_y"] as float)) >6.0:
				play_sfx(SFX_PEG, b["rng"].randf_range(-2.0,2.0))
				b["last_peg_y"] = py_v
				_pulse_peg(p["x"], py_v)
	#6)写入
	b["x"] = x
	b["y"] = y
	b["vx"] = vx
	b["vy"] = vy
	#7) 是否已经落到槽位区？
	var slot_top_y: float = board_top + peg_rows * peg_spacing_y +40
	if y > slot_top_y - ball_radius *0.5:
		b["settled"] = true
		_land_ball(b)


func _apply_guidance(b: Dictionary, sub_dt: float) -> void:
	#软引导：把球轻推向目标 slot 的中心 x。
	# 力随球远离目标而增大；靠近目标区域时按 falloff衰减（避免硬拐）。
	var slot_idx: int = b["target_slot"] as int
	if slot_idx <0 or slot_idx >= slot_count:
		return
	var slot_w: float = board_width / float(slot_count)
	var target_x: float = board_left + slot_idx * slot_w + slot_w *0.5
	var cur_x: float = b["x"] as float
	var dx: float = target_x - cur_x
	#距离越大力越大（线性限幅）
	var dist_norm: float = clamp(abs(dx) / (board_width *0.5),0.0,1.0)
	var force_mag: float = guidance_strength *800.0 * dist_norm
	#越接近袋子（垂直距离越短）力越弱
	var slot_top_y: float = board_top + peg_rows * peg_spacing_y +40
	var remain_norm: float = clamp((slot_top_y - (b["y"] as float)) / max(1.0, slot_top_y - board_top),0.0,1.0)
	force_mag *= pow(remain_norm,1.0 - guidance_falloff)
	#推力方向
	var sign: float =1.0 if dx >0.0 else (-1.0 if dx <0.0 else 0.0)
	b["vx"] = (b["vx"] as float) + sign * force_mag * sub_dt



func _pulse_peg(x: float, y: float) -> void:
	# 找到最近的钉子，闪烁一下
	var best: Control = null
	var best_d: float = 1e9
	var PEG_SIZE = 20
	for p in _pegs:
		var dx: float = p["x"] - x
		var dy: float = p["y"] - y
		var d2: float = dx * dx + dy * dy
		if d2 < best_d and d2 < (PEG_SIZE * 1.5) * (PEG_SIZE * 1.5):
			best_d = d2
			best = p["node"]
	if best == null:
		return
	var original_color := Color(0.75, 0.82, 0.95, 1)
	var flash_color := Color(1.0, 0.95, 0.5, 1.0)
	# 修改 StyleBox 颜色
	var sb: StyleBoxFlat = best.get_theme_stylebox("panel")
	if sb:
		sb.bg_color = flash_color
		var t := create_tween()
		t.tween_property(sb, "bg_color", original_color, 0.18)


# ============================================================
# 落点
# ============================================================
func _land_ball(b: Dictionary) -> void:
	#找到 x 对应哪个 slot
	var idx: int = _slot_index_for_x(b["x"])
	if idx <0:
		idx =0
	elif idx >= slot_count:
		idx = slot_count -1
	var slot: Dictionary = _slots[idx]
	var points: int = int(slot["value"])

	# 把球移动到槽中心 y
	var target_y: float = slot["y"] + slot_height *0.5
	_settle_into_slot(b, target_y, idx, points)



func _settle_into_slot(b: Dictionary, target_y: float, slot_idx: int, points: int) -> void:
	#球的控制权交还给 settle，移除 _active_balls
	_active_balls.erase(b)
	var node: Control = b["node"]

	# 平滑过渡到槽位中心
	var slot: Dictionary = _slots[slot_idx]
	var target_x: float = slot["x"] + slot["w"] *0.5
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(node, "position:x", target_x - ball_radius,0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position:y", target_y - ball_radius,0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished



func _slot_index_for_x(x: float) -> int:
	for i in range(slot_count):
		var s: Dictionary = _slots[i]
		if x >= s["x"] and x < s["x"] + s["w"]:
			return i
	return 0



func _flash_slot(idx: int, points: int) -> void:
	var slot: Dictionary = _slots[idx]
	var node: Control = slot["node"]
	var sb: StyleBoxFlat = node.get_theme_stylebox("panel")
	if sb:
		var original: Color = sb.bg_color
		sb.bg_color = Color(1, 1, 1, 1)
		var t := create_tween()
		t.tween_property(sb, "bg_color", original, 0.30)
	# 缩放弹一下
	node.scale = Vector2(1, 1)
	var t2 := create_tween()
	t2.tween_property(node, "scale", Vector2(1.10, 1.10), 0.10)
	t2.tween_property(node, "scale", Vector2(1.0, 1.0), 0.15)


func _show_score_popup(points: int, x: float, y: float) -> void:
	var lbl := Label.new()
	lbl.text = "+%d" % points
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.55, 1))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0, 0, 0.8))
	lbl.position = Vector2(x - 60, y)
	lbl.size = Vector2(120, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(1, 1, 1, 0)
	_ball_layer.add_child(lbl)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "modulate:a", 1.0, 0.10)
	t.tween_property(lbl, "position:y", y - 80, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fade := create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(lbl, "modulate:a", 0.0, 0.30)
	await fade.finished
	lbl.queue_free()


func _show_combo_text(text: String, color: Color) -> void:
	_combo_label.text = text
	_combo_label.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_combo_label, "modulate:a", 1.0, 0.15)
	var t2 := create_tween()
	t2.tween_interval(0.8)
	t2.tween_property(_combo_label, "modulate:a", 0.0, 0.4)
	await t2.finished
	if _combo_label.text == text:
		_combo_label.text = ""


# ============================================================
# 结束
# ============================================================
func _end_game() -> void:
	if _game_over:
		return
	_game_over = true
	play_sfx(SFX_OVER)
	_save_progress()
	_show_result_panel()


func _show_result_panel() -> void:
	# 半透明遮罩
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	# 弹窗
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(820, 700)
	panel.position = Vector2(-410, -350)
	panel.scale = Vector2(0.85, 0.85)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	ps.corner_radius_top_left = 32
	ps.corner_radius_top_right = 32
	ps.corner_radius_bottom_left = 32
	ps.corner_radius_bottom_right = 32
	ps.border_width_left = 3
	ps.border_width_top = 3
	ps.border_width_right = 3
	ps.border_width_bottom = 3
	ps.border_color = Color(0.50, 0.60, 0.85, 0.8)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(dim, "modulate:a", 1.0, 0.20)

	# 标题
	var title := Label.new()
	title.text = "🏁 本局结束"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_bottom = 130
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	# 本局得分
	var score_lbl := Label.new()
	score_lbl.text = "本局: %d" % score
	score_lbl.add_theme_font_size_override("font_size", 50)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40, 1))
	score_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_lbl.offset_top = 160
	score_lbl.offset_bottom = 240
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(score_lbl)

	# 最高分
	var hi_lbl := Label.new()
	hi_lbl.text = "★ 最高: %d" % high_score
	hi_lbl.add_theme_font_size_override("font_size", 36)
	hi_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1))
	hi_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hi_lbl.offset_top = 250
	hi_lbl.offset_bottom = 310
	hi_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hi_lbl)

	# 新纪录？
	if score == high_score and score > 0:
		var new_hi := Label.new()
		new_hi.text = "🎉 新纪录!"
		new_hi.add_theme_font_size_override("font_size", 32)
		new_hi.add_theme_color_override("font_color", Color(1, 0.40, 0.55, 1))
		new_hi.set_anchors_preset(Control.PRESET_TOP_WIDE)
		new_hi.offset_top = 320
		new_hi.offset_bottom = 380
		new_hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(new_hi)
		play_sfx(SFX_WIN, -2.0)
		_blink(new_hi)

	# 按钮容器（HBoxContainer 居中管理）
	var btn_box := HBoxContainer.new()
	btn_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	btn_box.offset_left = 80
	btn_box.offset_top = 470
	btn_box.offset_right = -80
	btn_box.offset_bottom = 580
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 40)
	panel.add_child(btn_box)

	# Replay 按钮
	var replay := Button.new()
	replay.text = "↻ 再来一局"
	replay.custom_minimum_size = Vector2(280, 100)
	_apply_button_style(replay,
		Color(0.95, 0.75, 0.15, 1.0),
		Color(1.0, 0.85, 0.30, 1.0),
		Color(0.80, 0.60, 0.10, 1.0),
		24, 36, Color(0.10, 0.06, 0.02, 1))
	replay.pressed.connect(_on_replay_pressed)
	btn_box.add_child(replay)

	# 返回菜单
	var back := Button.new()
	back.text = "← 主菜单"
	back.custom_minimum_size = Vector2(280, 100)
	_apply_button_style(back,
		Color(0.18, 0.20, 0.28, 0.95),
		Color(0.28, 0.32, 0.42, 1.0),
		Color(0.10, 0.12, 0.18, 1.0),
		24, 32, Color(0.95, 0.95, 1.0, 1))
	back.pressed.connect(_on_back_to_menu_pressed)
	btn_box.add_child(back)


func _blink(node: Control) -> void:
	var t := create_tween().set_loops(3)
	t.tween_property(node, "modulate:a", 0.3, 0.20)
	t.tween_property(node, "modulate:a", 1.0, 0.20)


# ============================================================
# 按钮
# ============================================================
func _on_replay_pressed() -> void:
	play_sfx(SFX_BUTTON)
	_click_pop(get_viewport().gui_get_focus_owner())
	await get_tree().create_timer(0.18).timeout
	get_tree().reload_current_scene()


func _on_back_to_menu_pressed() -> void:
	play_sfx(SFX_BUTTON)
	_click_pop(get_viewport().gui_get_focus_owner())
	await get_tree().create_timer(0.18).timeout
	get_tree().change_scene_to_file("res://modules/plinko_game/scenes/main_menu.tscn")


func _click_pop(btn) -> void:
	if btn and btn is Button:
		var b: Button = btn
		var t := create_tween()
		t.tween_property(b, "scale", Vector2(0.92, 0.92), 0.06)
		t.tween_property(b, "scale", Vector2(1.0, 1.0), 0.10)


# ============================================================
#运行时 API — 指定入袋
# ============================================================
## 设置下一次投放的目标 slot（-1 =随机/自然物理）
func set_target_slot(idx: int) -> void:
	if idx < -1 or idx >= slot_count:
		push_warning("set_target_slot: out of range, expected -1..%d, got %d" % [slot_count -1, idx])
		return
	target_slot = idx
	enable_targeting = idx >=0

##投放一颗球，指定它进 idx袋（一次性，不改全局 target_slot）
func drop_ball_to_slot(idx: int) -> void:
	if _game_over or _drop_locked or balls_remaining <=0:
		return
	if _active_balls.size() >=3:
		return
	if idx <0 or idx >= slot_count:
		idx = clamp(idx,0, slot_count -1)
	_drop_locked = true
	balls_remaining -=1
	_refresh_topbar()
	play_sfx(SFX_DROP)
	var saved_target: int = target_slot
	target_slot = idx
	_spawn_ball(Vector2(board_left + board_width *0.5, board_top - peg_spacing_y *0.5))
	target_slot = saved_target
	await get_tree().create_timer(0.10).timeout
	_drop_locked = false
	if balls_remaining <=0 and _active_balls.is_empty():
		_end_game()


# ============================================================
# 入场动画
# ============================================================
func _play_intro_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

	# 钉子层从上到下淡入
	for p in _pegs:
		var n: Control = p["node"]
		n.modulate = Color(1, 1, 1, 0)
		var delay: float = 0.05 + (p["row"] as int) * 0.04
		var tt := create_tween()
		tt.tween_property(n, "modulate", Color(1, 1, 1, 1), 0.25).set_delay(delay)

	# 槽位从左到右弹入
	for s in _slots:
		var n: Control = s["node"]
		n.modulate = Color(1, 1, 1, 0)
		n.position.y += 30
		var delay: float = 0.4 + (s["index"] as int) * 0.05
		var tt := create_tween().set_parallel(true)
		tt.tween_property(n, "modulate", Color(1, 1, 1, 1), 0.30).set_delay(delay)
		tt.tween_property(n, "position:y", s["y"], 0.30).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
