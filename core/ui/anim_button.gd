@tool
extends TextureButton
## AnimButton — 带缩放 + 颜色叠加动画的可复用按钮组件
##
## 用法：
##   1. 实例化 res://core/ui/anim_button.tscn
##   2. 或将此脚本直接挂到任意 Button / TextureButton 节点上
##
## 所有动画参数均可在 Inspector 中调节，无需修改脚本。

# ─────────────────────────────────────────────
#  缩放动画
# ─────────────────────────────────────────────
@export_group("缩放动画")

## 是否启用缩放动画
@export var enable_scale_anim: bool = true

## 悬停放大倍数
@export_range(1.0, 1.5, 0.01) var hover_scale: float = 1.06

## 按下缩小倍数
@export_range(0.5, 1.0, 0.01) var press_scale: float = 0.94

## 悬停动画时长（秒）
@export_range(0.0, 1.0, 0.01) var hover_duration: float = 0.12

## 按下动画时长（秒）
@export_range(0.0, 1.0, 0.01) var press_duration: float = 0.07

## 抬起回弹总时长（秒）
@export_range(0.0, 1.0, 0.01) var release_duration: float = 0.18

# ─────────────────────────────────────────────
#  颜色叠加动画
# ─────────────────────────────────────────────
@export_group("颜色动画")

## 是否启用颜色叠加动画
@export var enable_color_overlay: bool = true

## 正常状态颜色（modulate）
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## 悬停时颜色叠加（略亮）
@export var hover_color: Color = Color(1.15, 1.15, 1.15, 1.0)

## 按下时颜色叠加（偏暗偏蓝，模拟按压感）
@export var press_color: Color = Color(0.80, 0.80, 0.95, 1.0)

## 颜色过渡时长（秒）
@export_range(0.0, 1.0, 0.01) var color_duration: float = 0.10

# ─────────────────────────────────────────────
#  内部状态
# ─────────────────────────────────────────────
var _base_scale: Vector2
var _tween_scale: Tween
var _tween_color: Tween
var _is_hovered: bool = false
var _is_pressed: bool = false


func _ready() -> void:
	_base_scale = scale
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 以按钮中心为缩放锚点，避免左上角飘移
	resized.connect(_update_pivot)
	_update_pivot()

	# 连接交互信号
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	button_down.connect(_on_press)
	button_up.connect(_on_release)


func _update_pivot() -> void:
	pivot_offset = size / 2.0


# ─────────────────────────────────────────────
#  事件处理
# ─────────────────────────────────────────────

func _on_hover_enter() -> void:
	_is_hovered = true
	if _is_pressed:
		return
	if enable_scale_anim:
		_animate_scale(_base_scale * hover_scale, hover_duration)
	if enable_color_overlay:
		_animate_color(hover_color, hover_duration)


func _on_hover_exit() -> void:
	_is_hovered = false
	if _is_pressed:
		return
	if enable_scale_anim:
		_animate_scale(_base_scale, hover_duration)
	if enable_color_overlay:
		_animate_color(normal_color, hover_duration)


func _on_press() -> void:
	_is_pressed = true
	if enable_scale_anim:
		_animate_scale(_base_scale * press_scale, press_duration)
	if enable_color_overlay:
		_animate_color(press_color, press_duration)


func _on_release() -> void:
	_is_pressed = false
	var target_scale := _base_scale * hover_scale if _is_hovered else _base_scale
	var target_color := hover_color if _is_hovered else normal_color
	if enable_scale_anim:
		_play_release_bounce(target_scale)
	if enable_color_overlay:
		_animate_color(target_color, release_duration)


# ─────────────────────────────────────────────
#  动画工具方法
# ─────────────────────────────────────────────

## 缩放到目标值（线性过渡）
func _animate_scale(target: Vector2, duration: float) -> void:
	if _tween_scale and is_instance_valid(_tween_scale):
		_tween_scale.kill()
	_tween_scale = create_tween()
	_tween_scale.tween_property(self, "scale", target, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 抬起时：先过冲再回弹，产生弹性感
func _play_release_bounce(target: Vector2) -> void:
	if _tween_scale and is_instance_valid(_tween_scale):
		_tween_scale.kill()
	_tween_scale = create_tween()
	var overshoot := target * 1.025
	# 第一段：快速超过目标
	_tween_scale.tween_property(self, "scale", overshoot, release_duration * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 第二段：弹回目标
	_tween_scale.tween_property(self, "scale", target, release_duration * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 颜色叠加过渡（通过 modulate 实现，不影响子节点 self_modulate）
func _animate_color(target: Color, duration: float) -> void:
	if _tween_color and is_instance_valid(_tween_color):
		_tween_color.kill()
	_tween_color = create_tween()
	_tween_color.tween_property(self, "modulate", target, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 公开接口：强制重置到初始视觉状态（场景切换/隐藏时调用）
func reset_anim() -> void:
	if _tween_scale and is_instance_valid(_tween_scale):
		_tween_scale.kill()
	if _tween_color and is_instance_valid(_tween_color):
		_tween_color.kill()
	_is_hovered = false
	_is_pressed = false
	scale = _base_scale
	modulate = normal_color
