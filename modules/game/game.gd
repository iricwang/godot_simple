extends Control

var app: Application

func _ready() -> void:
	app = Application.new()
	app.initialize(self)
