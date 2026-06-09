extends "res://core/base_view_model.gd"
## 注解绑定 ViewModel — @bind_property 直接标注在真实数据字段上
##
## 语法: @bind_property("目标属性", "节点路径", 模式)
##   注解变量不分配 GDScript 成员存储，读写路由到 ViewModel 的 _set/_get
##   值统一在 _init() 中通过 self.xxx = value 初始化

@bind_property("text", "Root/Margin/C/TitleLabel", 0)
var title: String

@bind_property("text", "Root/Margin/C/StatusLabel", 0)
var status_text: String

@bind_property("value", "Root/Margin/C/ProgressBar", 0)
var progress: float

@bind_property("button_pressed", "Root/Margin/C/CheckBox", 1)
var checked: bool

# counter 不声明 var，通过 self.counter = 0 在 _init 中隐式创建

@bind_signal("pressed")
func on_increment() -> void:
	self.counter += 1
	self.status_text = "注解绑定 — 计数器: %d" % self.counter

@bind_signal("pressed")
func on_reset() -> void:
	self.counter = 0
	self.progress = 0.0
	self.checked = false
	self.status_text = "注解绑定 — 已重置"

@bind_signal("toggled")
func on_check_toggled(cb: bool) -> void:
	self.checked = cb
	self.status_text = "注解绑定 — CheckBox: %s" % ("勾选" if cb else "未勾选")

func _init() -> void:
	self.counter = 0
	self.progress = 1
	self.checked = false
	self.status_text = "注解绑定 — 等待操作..."
	self.title = "注解绑定示例（直接标注数据字段）"
