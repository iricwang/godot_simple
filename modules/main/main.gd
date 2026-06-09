extends Control

var app: Application

func _init() -> void:
	app = Application.new()
	app.created.connect(_onAppCreated)
	app.paused.connect(_onAppPaused)
	app.resumed.connect(_onAppResumed)

func _ready() -> void:
	app.initialize(self)
	
	app.set_design_resolution(Vector2i(1080,1920))
	app.set_window_size(Vector2i(1080,1920) * 0.5)

func _onAppCreated():
	print("app _onAppCreated")	
	
	#开始设置activity相关
	var loader = app.get_activity_manager().get_loader()
	loader.set_base_path("res://modules")

	var it0 = Intent.new();
	it0.action = "lobby"
	app.start_activity(it0)

func _onAppPaused():
	print("app _onAppPaused")	

func _onAppResumed():
	print("app _onAppResumed")	
