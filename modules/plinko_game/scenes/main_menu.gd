extends Control
## Plinko 主菜单
## 分辨率 1080x1920（移动端竖屏）
##
## 视觉：深蓝紫渐变背景 + 装饰钉子板预览 + 标题/最高分/金币
## 音频：背景音乐（循环）+ 按钮音效
## 玩法：开始游戏 → 跳到 game.tscn；设置 → 弹设置面板

# ---------- 节点 ----------
@onready var title_label: Label = $VBox/TitleContainer/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var play_button: Button = $VBox/MenuContainer/PlayButton
@onready var settings_button: Button = $VBox/MenuContainer/SettingsButton
@onready var high_score_label: Label = $VBox/ScoreContainer/HighScoreLabel
@onready var coins_label: Label = $VBox/ScoreContainer/CoinsLabel
@onready var background_board: Control = $BackgroundBoard
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

# ---------- 配置 ----------
const SAVE_PATH := "user://plinko_save.cfg"
const HIGH_SCORE_KEY := "high_score"
const COINS_KEY := "coins"

const SFX_BUTTON := preload("res://modules/plinko_game/sfx/button.wav")
const SFX_WIN := preload("res://modules/plinko_game/sfx/win.wav")
const MUSIC := preload("res://modules/plinko_game/plinko_background_music.mp3")

# ---------- 状态 ----------
var high_score: int = 0
var coins: int = 1000
var music_volume_db: float = -8.0
var sfx_volume_db: float = 0.0
var music_enabled: bool = true
var sfx_enabled: bool = true


func _ready() -> void:
	_setup_viewport()
	_load_save()
	_setup_audio()
	_setup_buttons()
	_setup_labels()
	_generate_peg_preview()
	_play_entrance_animation()
	_connect_signals()


# ============================================================
# 视口 / 显示
# ============================================================
func _setup_viewport() -> void:
	var vp := get_viewport()
	vp.content_scale_size = Vector2i(1080, 1920)
	vp.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	vp.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# ============================================================
# 存档（最高分 / 金币）
# ============================================================
func _load_save() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		high_score = int(cfg.get_value("data", HIGH_SCORE_KEY, 0))
		coins = int(cfg.get_value("data", COINS_KEY, 1000))
	else:
		high_score = 0
		coins = 1000


func save_progress(score: int = -1, new_coins: int = -1) -> void:
	if score >= 0 and score > high_score:
		high_score = score
	if new_coins >= 0:
		coins = new_coins
	var cfg := ConfigFile.new()
	cfg.set_value("data", HIGH_SCORE_KEY, high_score)
	cfg.set_value("data", COINS_KEY, coins)
	cfg.save(SAVE_PATH)


# ============================================================
# 音频
# ============================================================
func _setup_audio() -> void:
	music_player.stream = MUSIC
	music_player.volume_db = music_volume_db if music_enabled else -80.0
	music_player.bus = "Music"
	music_player.play()
	# 循环在 .import 文件中设置，这里只是保险
	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)

	sfx_player.bus = "SFX"
	sfx_player.volume_db = sfx_volume_db if sfx_enabled else -80.0


func _on_music_finished() -> void:
	# 保险起见手动循环（mp3.import 已有 loop=true，但兼容）
	if music_player and music_player.stream:
		music_player.play()


func play_sfx(stream: AudioStream, vol_offset_db: float = 0.0) -> void:
	if not sfx_enabled:
		return
	sfx_player.stream = stream
	sfx_player.volume_db = sfx_volume_db + vol_offset_db
	sfx_player.play()


# ============================================================
# UI
# ============================================================
func _setup_buttons() -> void:
	# Play（主按钮，金色）
	_apply_button_style(play_button,
		Color(0.95, 0.75, 0.15, 1.0),
		Color(1.0, 0.85, 0.30, 1.0),
		Color(0.80, 0.60, 0.10, 1.0),
		30, 36, Color(0.10, 0.06, 0.02, 1.0))
	# Settings（次按钮，深灰）
	_apply_button_style(settings_button,
		Color(0.18, 0.20, 0.28, 0.85),
		Color(0.28, 0.30, 0.40, 0.95),
		Color(0.10, 0.12, 0.18, 0.95),
		20, 24, Color(0.90, 0.92, 0.95, 1.0))


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
		sb.content_margin_left = 50
		sb.content_margin_right = 50
		sb.content_margin_top = 20
		sb.content_margin_bottom = 20
		btn.add_theme_stylebox_override(state_name, sb)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_font_size_override("font_size", font_size)


func _setup_labels() -> void:
	title_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.70, 1.0))
	title_label.add_theme_font_size_override("font_size", 88)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.8))

	subtitle_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95, 0.85))
	subtitle_label.add_theme_font_size_override("font_size", 28)

	high_score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
	high_score_label.add_theme_font_size_override("font_size", 30)

	coins_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.20, 1.0))
	coins_label.add_theme_font_size_override("font_size", 34)

	_update_score_display()


func _update_score_display() -> void:
	high_score_label.text = "★ 最高分: %d" % high_score
	coins_label.text = "💰 %d" % coins


# ============================================================
# 背景装饰
# ============================================================
func _generate_peg_preview() -> void:
	# 清理旧预览
	for c in background_board.get_children():
		c.queue_free()

	# 渐变背景（手动画）
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.13, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_board.add_child(bg)

	# 顶到底的渐变（用 Shader-less 替代：多色叠加）
	for i in range(4):
		var rect := ColorRect.new()
		var t := float(i) / 3.0
		rect.color = Color(0.12 + 0.05 * t, 0.05, 0.20 + 0.10 * t, 0.25 - 0.05 * t)
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_board.add_child(rect)

	# 边框
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 30
	frame.offset_top = 240
	frame.offset_right = -30
	frame.offset_bottom = -100
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.08, 0.10, 0.16, 0.55)
	fs.border_width_left = 3
	fs.border_width_top = 3
	fs.border_width_right = 3
	fs.border_width_bottom = 3
	fs.border_color = Color(0.40, 0.50, 0.70, 0.55)
	fs.corner_radius_top_left = 20
	fs.corner_radius_top_right = 20
	fs.corner_radius_bottom_left = 20
	fs.corner_radius_bottom_right = 20
	frame.add_theme_stylebox_override("panel", fs)
	background_board.add_child(frame)

	# 装饰钉子
	const rows := 7
	const pegs_per_row := 9
	const start_y := 320.0
	const spacing_y := 80.0
	const spacing_x := 108.0
	const start_x := 90.0
	for row in rows:
		var offset := 0.0 if row % 2 == 0 else spacing_x / 2.0
		var pegs_in_row := pegs_per_row if row % 2 == 0 else pegs_per_row - 1
		for col in pegs_in_row:
			var peg := ColorRect.new()
			peg.size = Vector2(14, 14)
			peg.color = Color(0.55, 0.62, 0.80, 0.45)
			peg.position = Vector2(start_x + col * spacing_x + offset, start_y + row * spacing_y)
			peg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.60, 0.70, 0.90, 0.40)
			s.corner_radius_top_left = 7
			s.corner_radius_top_right = 7
			s.corner_radius_bottom_left = 7
			s.corner_radius_bottom_right = 7
			peg.add_theme_stylebox_override("normal", s)
			peg.add_theme_stylebox_override("hover", s)
			background_board.add_child(peg)

	# 槽位指示器
	var slot_values := [100, 200, 500, 1000, 500, 200, 100]
	var slot_width := 1080.0 / slot_values.size()
	for i in slot_values.size():
		var slot := Label.new()
		slot.text = str(slot_values[i])
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30, 0.55))
		slot.add_theme_font_size_override("font_size", 22)
		slot.position = Vector2(i * slot_width, 920.0)
		slot.size = Vector2(slot_width, 40)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_board.add_child(slot)


# ============================================================
# 动画
# ============================================================
func _play_entrance_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.6)

	var vb := $VBox
	vb.modulate = Color(1, 1, 1, 0)
	vb.position.y += 60
	var t2 := create_tween()
	t2.tween_property(vb, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.2)
	t2.tween_property(vb, "position:y", vb.position.y - 60, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.2)


# ============================================================
# 信号
# ============================================================
func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	play_button.mouse_entered.connect(_on_play_hovered)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button.mouse_entered.connect(_on_settings_hovered)


func _on_play_hovered() -> void:
	play_sfx(SFX_BUTTON, -6.0)
	_hover_pop(play_button)


func _on_settings_hovered() -> void:
	play_sfx(SFX_BUTTON, -6.0)
	_hover_pop(settings_button)


func _hover_pop(btn: Button) -> void:
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)


func _on_play_pressed() -> void:
	play_sfx(SFX_BUTTON)
	_click_anim(play_button)
	await get_tree().create_timer(0.20).timeout
	get_tree().change_scene_to_file("res://modules/plinko_game/scenes/game.tscn")


func _on_settings_pressed() -> void:
	play_sfx(SFX_BUTTON)
	_click_anim(settings_button)
	await get_tree().create_timer(0.20).timeout
	_show_settings_popup()


func _click_anim(btn: Button) -> void:
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)


# ============================================================
# 设置弹窗
# ============================================================
func _show_settings_popup() -> void:
	var popup := Control.new()
	popup.name = "SettingsPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.modulate = Color(1, 1, 1, 0)
	# 半透明遮罩
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim)
	add_child(popup)
	# 弹窗出现
	var t := create_tween()
	t.tween_property(popup, "modulate", Color(1, 1, 1, 1), 0.20)

	# 弹窗主体
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(720, 600)
	panel.position.x = -360
	panel.position.y = -300
	panel.scale = Vector2(0.85, 0.85)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.12, 0.18, 0.98)
	ps.corner_radius_top_left = 28
	ps.corner_radius_top_right = 28
	ps.corner_radius_bottom_left = 28
	ps.corner_radius_bottom_right = 28
	ps.border_width_left = 2
	ps.border_width_top = 2
	ps.border_width_right = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.50, 0.60, 0.85, 0.7)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)
	var t_scale := create_tween()
	t_scale.tween_property(panel, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 标题
	var title := Label.new()
	title.text = "⚙ 设置"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	title.position = Vector2(40, 30)
	title.size = Vector2(640, 60)
	panel.add_child(title)

	# 音乐开关
	var music_toggle := CheckBox.new()
	music_toggle.text = "🎵 背景音乐"
	music_toggle.button_pressed = music_enabled
	music_toggle.position = Vector2(60, 130)
	music_toggle.size = Vector2(280, 50)
	music_toggle.add_theme_font_size_override("font_size", 28)
	music_toggle.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1))
	music_toggle.toggled.connect(func(on: bool):
		music_enabled = on
		music_player.volume_db = music_volume_db if on else -80.0)
	panel.add_child(music_toggle)

	# 音效开关
	var sfx_toggle := CheckBox.new()
	sfx_toggle.text = "🔊 音效"
	sfx_toggle.button_pressed = sfx_enabled
	sfx_toggle.position = Vector2(60, 210)
	sfx_toggle.size = Vector2(280, 50)
	sfx_toggle.add_theme_font_size_override("font_size", 28)
	sfx_toggle.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1))
	sfx_toggle.toggled.connect(func(on: bool):
		sfx_enabled = on
		sfx_player.volume_db = sfx_volume_db if on else -80.0)
	panel.add_child(sfx_toggle)

	# 音乐音量
	var music_label := Label.new()
	music_label.text = "音乐音量"
	music_label.add_theme_font_size_override("font_size", 26)
	music_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1))
	music_label.position = Vector2(60, 300)
	panel.add_child(music_label)

	var music_slider := HSlider.new()
	music_slider.min_value = -40.0
	music_slider.max_value = 6.0
	music_slider.value = music_volume_db
	music_slider.step = 1.0
	music_slider.position = Vector2(60, 340)
	music_slider.size = Vector2(600, 30)
	music_slider.value_changed.connect(func(v: float):
		music_volume_db = v
		if music_enabled:
			music_player.volume_db = v)
	panel.add_child(music_slider)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(260, 470)
	close_btn.size = Vector2(200, 70)
	_apply_button_style(close_btn,
		Color(0.30, 0.20, 0.10, 1.0),
		Color(0.45, 0.30, 0.15, 1.0),
		Color(0.20, 0.13, 0.05, 1.0),
		18, 30, Color(1, 0.93, 0.7, 1))
	close_btn.pressed.connect(func():
		play_sfx(SFX_BUTTON)
		var fade := create_tween()
		fade.tween_property(popup, "modulate", Color(1, 1, 1, 0), 0.18)
		await fade.finished
		popup.queue_free())
	panel.add_child(close_btn)
