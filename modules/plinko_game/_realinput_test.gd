extends SceneTree
## Plinko 真实输入路径自检：模拟 InputEventMouseButton 走完整 _input → _gui_input 链

func _init() -> void:
	print("[RealInputTest] starting")
	var packed: PackedScene = load("res://modules/plinko_game/scenes/game.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	print("[RealInputTest] game ready, score=%d, balls=%d" % [game.score, game.balls_remaining])
	print("[RealInputTest] _drop_zone = %s" % str(game._drop_zone))
	print("[RealInputTest] _drop_zone mouse_filter = %d (STOP=%d)" % [game._drop_zone.mouse_filter, Control.MOUSE_FILTER_STOP])
	print("[RealInputTest] _drop_zone global rect = %s" % str(game._drop_zone.get_global_rect()))
	print("[RealInputTest] viewport size = %s" % str(get_root().size))
	print("[RealInputTest] viewport content_scale_size = %s" % str(get_root().content_scale_size))
	print("[RealInputTest] viewport content_scale_mode = %s" % str(get_root().content_scale_mode))

	# 模拟真实鼠标点击：InputEventMouseButton 需要 viewport 缩放
	# 我们用 game._unhandled_input 链：调用 game._drop_zone.gui_input.emit(...) 不行（_input 是引擎）
	# 用 input_event 直接喂给 _drop_zone
	var ev := InputEventMouseButton.new()
	ev.position = Vector2(540, 200)  # 顶部 540, 200
	ev.global_position = Vector2(540, 200)
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	# 直接调 gui_input
	game._drop_zone.gui_input.emit(ev)
	print("[RealInputTest] after gui_input.emit, balls_remaining=%d, active_balls=%d" % [game.balls_remaining, game._active_balls.size()])

	# 也试一下 _input 路径（通过 Input.parse_input_event）
	var ev2 := InputEventMouseButton.new()
	ev2.position = Vector2(540, 200)
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = true
	ev2.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev2)
	await process_frame
	print("[RealInputTest] after Input.parse_input_event, balls_remaining=%d, active_balls=%d" % [game.balls_remaining, game._active_balls.size()])

	# 等球落
	var t: float = 0.0
	while t < 5.0 and not game._active_balls.is_empty():
		await create_timer(0.1).timeout
		t += 0.1
	print("[RealInputTest] waited %.1fs, score=%d, active_balls=%d" % [t, game.score, game._active_balls.size()])
	quit(0)
