# VM / Activity 模式使用指南

> 适用对象: Godot 4 + GDScript 开发者, 第一次接触本项目 `gf_test` 里的 VM/Activity 模式
> 前置知识: Godot 4 基础 (Node / Control / signal / `extends`); 不需要任何 MVVM 背景
> 阅读时长: 快速浏览 5 分钟, 精读 30 分钟

---

## 目录

1. [这是什么 & 为什么用 MVVM](#1-这是什么--为什么用-mvvm)
2. [三层架构](#2-三层架构)
3. [5 分钟上手: 最简示例](#3-5-分钟上手-最简示例)
4. [核心概念](#4-核心概念)
5. [8 个示例速查表](#5-8-个示例速查表)
6. [Activity 生命周期](#6-activity-生命周期)
7. [测试怎么写](#7-测试怎么写)
8. [GDScript 4 必踩的坑 (FAQ)](#8-gdscript-4-必踩的坑-faq)
9. [进阶: 什么时候拆 converter / 拆 VM](#9-进阶-什么时候拆-converter--拆-vm)
10. [进一步阅读](#10-进一步阅读)

---

## 1. 这是什么 & 为什么用 MVVM

`gf_test` 项目用 MVVM (Model–View–ViewModel) 把 **业务逻辑** 和 **UI 渲染** 拆开, 中间靠"双向可观察"的数据绑定串起来。三方各管各的:

- **View / Activity**: 只管"画"——构造 Godot 控件, 响应用户输入, 显示数据
- **ViewModel (VM)**: 只管"算什么 / 存什么 / 改什么"——业务规则、状态机、计算
- **Model**: 业务实体 (通常以 `RefCounted` 内嵌类的形式挂在 VM 里)

**好处** (挑最重要的三个):

1. **可单测**: VM 是纯 GDScript, 不依赖场景树——一个 `VM.new()` 就能跑业务逻辑, 见 [§7 测试](#7-测试怎么写)
2. **可换皮**: Activity 只订阅 VM 的属性, 不写死 UI 风格。同一份 VM 可以配桌面 UI、移动 UI、甚至命令行
3. **不被节点树绑死**: VM 是 `RefCounted`, 不是 `Node`, 跨场景存活, 也方便在 `await` / 异步里传递

**这个框架的 VM 不是 Node**——它继承自 C++ `ViewModel` (一个 `RefCounted`)。所以你写 `var vm = MyVM.new()` 直接拿实例, 用完 `vm.dispose()` 释放订阅。

**一句话总结**:
> **UI 只管"画", VM 只管"算什么 / 存什么 / 改什么"; 改数据 → 通知 → UI 自动更新**

---

## 2. 三层架构

整个框架分三层, 上层订阅下层, 下层不知道上层存在。

```
+------------------------+
|     Activity (UI)      |  ← Godot 节点 (Control 子类), 构造 Control 树
|   订阅 VM 属性变化     |  ← 自动更新 UI
|   转发用户输入到 VM    |  ← Button.pressed / LineEdit.text_changed → VM 命令
+-----------▲------------+
            │ subscribe_property() / 直接调用 VM 方法
+-----------┴------------+
|   ViewModel (业务)     |  ← 纯 GDScript, extends "res://core/base_view_model.gd"
|   状态 / 计算属性 / 命令 |  ← self.xxx = y 自动触发订阅者收到 value_changed
+-----------▲------------+
            │ extends ViewModel
+-----------┴------------+
|  ObservableProperty    |  ← C++ ViewModel 内部: HashMap<StringName, Ref<ObservableProperty>>
|  BindingEngine         |  ← C++ 静态工具: 静态方法连接 VM 属性 ↔ 控件属性
+------------------------+
```

**关键点**:
- **数据流单向**: VM → UI 永远是 `value_changed` 推; UI → VM 永远是命令调用
- **VM 不知道有谁在监听**: 它只管改自己的 `ObservableProperty`, 谁爱订阅谁订阅
- **BindingEngine 是桥梁**: 它按 `ObjectID` 寻址目标节点, 节点 free 后自动变成 no-op, 不会悬空访问

---

## 3. 5 分钟上手: 最简示例

下面是一个**完整可跑**的最简例子: 1 个 VM (计数器) + 1 个 Activity (Label + 按钮), 跑起来会看到一个能 +1 的计数器。

### 3.1 VM 文件: `res://counter_vm.gd`

```gdscript
extends "res://core/base_view_model.gd"
## 最简 VM —— 计数器

# 直接 var 声明就行, 不需要任何装饰符
var count: int = 0

# 命令方法: Activity 调用 on_inc() 就会让 count +1
# 自增写法 count += 1 走的是 _get → _set, 自动触发订阅者
func on_inc() -> void:
	count += 1
```

### 3.2 Activity 文件: `res://counter_activity.gd`

```gdscript
extends Activity
## 最简 Activity —— 显示计数, 一个 +1 按钮

const CounterVM = preload("res://counter_vm.gd")

var vm: CounterVM
var _lbl: Label
var _btn: Button


func _on_create(saved_state: Dictionary) -> void:
	# 1) 构造 VM
	vm = CounterVM.new()

	# 2) 构造 UI
	_lbl = Label.new()
	_lbl.text = "count = 0"
	add_child(_lbl)

	_btn = Button.new()
	_btn.text = "+1"
	_btn.pressed.connect(_on_press)
	add_child(_btn)

	# 3) 订阅 VM 属性
	#    以后 vm.count 改了, _update_lbl 会被自动调用
	vm.subscribe_property("count", _update_lbl)

	# 4) 初始渲染 (可选, 但推荐)
	_update_lbl(vm.count)


# 订阅回调: 新值进来就更新 Label
func _update_lbl(v) -> void:
	_lbl.text = "count = %d" % v


# UI 事件 → VM 命令
func _on_press() -> void:
	vm.on_inc()


# ---- 生命周期 stubs (本例没用, 但 Activity 必须能跑空) ----
func _on_start() -> void: pass
func _on_resume() -> void: pass
func _on_pause() -> void: pass
func _on_stop() -> void: pass
func _on_back_pressed() -> bool:
	return false  # false = 让 ActivityManager 正常 finish

# 关键: 销毁时释放 VM 持有的订阅
func _on_destroy() -> void:
	vm.dispose()
```

### 3.3 注册 Activity 到 Application

打开 `entry.gd` 的 `_init_activitis()` 加一行:

```gdscript
func _init_activitis() -> void:
	# ... 其它注册
	app.register_activity("counter", "res://counter_activity.tscn")
```

然后在 `main` Activity 里加一个按钮跳过去就行:

```gdscript
var it = Intent.new()
it.action = "counter"
app.start_activity(it)
```

### 3.4 跑起来

```bash
# 完整 GUI
godot --path D:/AI_Temp/gf_test

# Headless (自动跑 entry.gd 里的测试, 见 §7)
godot --headless --path D:/AI_Temp/gf_test
```

> 实战里一般把 Activity 配一个 `.tscn` (根节点 = `Control`, 挂这个 `.gd` 脚本),
> 然后 `app.register_activity(name, "res://path/to/counter_activity.tscn")` 注册。
> 在本指南里我们为了简洁, 全部用代码构造 UI; 项目里的 8 个复杂示例都是这种风格。

---

## 4. 核心概念

下面把 9 个常用概念逐个拆开讲, 每个都配最小可跑代码片段。

### 4.1 属性声明

**规则**: 用普通 `var` 声明, **不需要** 任何 `@Observable` / `@bind` 装饰符。

```gdscript
extends "res://core/base_view_model.gd"

# 各种类型都行
var title: String = "Hello"
var count: int = 0
var is_loading: bool = false
var score: float = 0.0
var tags: Array = []          # Array[Variant] 也可以
var user: Dictionary = {}     # Dictionary 也能存
var items: Array = []         # Array[Object] 嵌套数据
```

**原理**: `base_view_model.gd` 的 `_set` / `_get` 把"赋值"和"读取"重定向到 C++ 端的 `ObservableProperty` map。框架在第一次访问 `xxx` 时**懒构造**属性。

```gdscript
# 这两行是等价的
vm.count = 5
vm.set_property("count", 5)
```

### 4.2 属性赋值

**规则**: `self.xxx = y` 自动触发 `value_changed`, 不需要手动 emit。

```gdscript
func on_username_changed(new_value: String) -> void:
	username = new_value  # 订阅者立即收到
```

**注意**:
- **同值不触发**: `set_value` 会比较新旧值, 相等则不通知
- **批量改值不连续通知**: 用 `begin_bulk_update()` / `end_bulk_update()` 包裹 (见 §4.5)

### 4.3 属性读取

**规则**: 直接 `vm.xxx` 读, 跟普通 GDScript 一样。

```gdscript
var n = vm.count
if vm.is_loading:
	print("loading...")
```

读取触发的是 `_get`, 内部走 `ObservableProperty::get_value()`, **不会** 通知订阅者。

### 4.4 订阅属性

**Activity 端的语法**:

```gdscript
# 订阅一个属性 — 回调签名: func(new_value) -> void
vm.subscribe_property("count", _on_count_changed)

func _on_count_changed(new_value) -> void:
	_lbl.text = "count = %d" % new_value
```

**批量订阅的常见模式**: 在 `_on_create` 里集中订阅。

```gdscript
func _bind_all() -> void:
	# 一对一
	vm.subscribe_property("count", _update_count_lbl)
	# 一对多 (一个回调里处理多个)
	vm.subscribe_property("is_loading", _update_loading_state)
	vm.subscribe_property("status_message", _update_status_lbl)
	vm.subscribe_property("filtered_users", _rebuild_list)
```

**注意**:
- 订阅是 **弱引用**, 框架在 `_on_destroy` 调 `vm.dispose()` 时一并清空
- 回调参数是 `Variant`, 必要时用 `typeof()` / `int()` 收窄
- 想精确看一个属性的当前值, 用 `vm.get_value("count")` 拿同步值 (不走通知)

### 4.5 批量更新

**场景**: 一段代码里改了 10 个属性, 你**不希望** UI 被重绘 10 次, 只想看到一次最终结果。

```gdscript
func _recompute_totals() -> void:
	begin_bulk_update()       # 开始批量
	subtotal = 123.0
	tax = 9.84
	total = 132.84
	item_count = 4
	is_checkout_enabled = true
	end_bulk_update()         # 结束批量 — C++ 端只触发一次合并通知
```

**原理** (C++ 端, `view_model.cpp`):

```
begin_bulk_update()  → 把 map 内所有 ObservableProperty 全部 wrap 到"延迟派发"模式
end_bulk_update()    → 一次性 O(N) 遍历, 触发合并后的 value_changed
```

**实战建议**:
- 任何"一组相关的派生量"重算, 都用 `begin/end` 包
- **不要** 嵌套, 会触发未定义行为
- 没有改任何属性就 end, 不会有副作用

### 4.6 命令方法

**概念**: VM 上不写 `on_xxx_clicked` 这种 UI 风格命名, 写业务动作的动词 / 名词。

```gdscript
# 业务动作 — 不带 "clicked" 后缀
func on_pay() -> void: ...
func on_cancel() -> void: ...
func apply_discount_code(code: String) -> bool: ...

# 命名约定: on_xxx 是"响应"语义, 接收者不一定知道是按钮
# vs set_xxx 是"属性 setter"语义
```

**UI 端的对应** (两种风格):

```gdscript
# 风格 A: 直接 connect, UI 名字和 VM 命令解耦
_btn.pressed.connect(_on_pay_pressed)
func _on_pay_pressed() -> void:
	vm.on_pay()

# 风格 B: 用 BindingEngine.bind_command 静态桥接
# (推荐 — Activity 不用写包装函数)
BindingEngine.bind_command(_btn, "pressed", vm, "on_pay")
```

### 4.7 计算属性 (派生属性)

**思路**: Godot 4 GDScript 没有原生的 `@computed`, 用 **普通 var + setter 触发重算** 模拟。

```gdscript
# 原始输入
var cart_items: Array = []
var discount_rate: float = 0.0

# 派生输出 (由 _recompute_totals() 维护)
var subtotal: float = 0.0
var discount_amount: float = 0.0
var tax: float = 0.0
var total: float = 0.0
var item_count: int = 0
var is_checkout_enabled: bool = false

# 命令方法触发重算
func add_item(id: String, name: String, price: float, qty: int) -> void:
	cart_items.append(CartItem.new(id, name, price, qty))
	_recompute_totals()  # 一改输入就同步派生

# 重算 (用 bulk 包裹)
func _recompute_totals() -> void:
	begin_bulk_update()
	item_count = 0
	subtotal = 0.0
	for item in cart_items:
		item_count += item.quantity
		subtotal += item.get_subtotal()
	discount_amount = subtotal * discount_rate
	tax = (subtotal - discount_amount) * 0.08
	total = subtotal - discount_amount + tax
	is_checkout_enabled = cart_items.size() > 0
	end_bulk_update()
```

**Activity 订阅派生属性**:

```gdscript
vm.subscribe_property("total", _update_total_lbl)
vm.subscribe_property("is_checkout_enabled", _update_checkout_btn)
```

**优点**:
- UI 不用知道怎么算, 只订阅"结果"
- VM 改任何输入都自动同步, UI 永远不会显示"过时的总价"
- 重算逻辑集中, 改业务规则只动一个地方

**进阶**: 派生属性链 (见 [§5 DataTable](#5-8-个示例速查表))——`filtered_rows → sorted_rows → paged_rows`, 每一层都是 var, 重算时按链路顺序写。

### 4.8 嵌套数据

**常见模式**: VM 内嵌一个 `RefCounted` 数据类表示单行 / 单个实体。

```gdscript
extends "res://core/base_view_model.gd"

# 单个用户数据 — 纯数据, RefCounted, 不入场景树
class UserItem extends RefCounted:
	var id: int
	var name: String
	var email: String
	var is_online: bool

	func _init(p_id: int = 0, p_name: String = "", p_email: String = "", p_online: bool = false) -> void:
		id = p_id
		name = p_name
		email = p_email
		is_online = p_online

# 集合 (整个 Array 是一个 ObservableProperty)
var users: Array = []              # Array[UserItem]
var filtered_users: Array = []     # 派生: 按搜索词过滤

func on_add_demo_user() -> void:
	users.append(UserItem.new(0, "新用户", "new@example.com", false))
	_apply_filter()

func _apply_filter() -> void:
	if search_query.is_empty():
		filtered_users = users.duplicate()
	else:
		filtered_users = users.filter(func(u): return search_query in u.name)
```

**注意**:
- `Array` 整体作为 `ObservableProperty`——**整个数组变了**才通知, 数组里某一项单独改不通知
- 如果需要"数组里某项改了"也通知, 让该项本身也是 `ViewModel` (见 §9 进阶)

### 4.9 ValueConverter

**什么时候用**: VM 存的是 `float`, UI 想显示 `"¥1,234.50"`; 或者 `bool` 想要 `"✓ / ✗"`; 或者 `0.85` 想要 `"85%"`。

**原理**: `ValueConverter` 是一个 C++ 类, 子类实现两个虚函数:

```gdscript
extends ValueConverter
# 注意: GDScript 子类用 _convert / _convert_back(带下划线)
# 避免和 C++ 父类的 public non-virtual convert/convert_back 重名

func _convert(value) -> String:
	if value:
		return "✓ 已启用"
	return "✗ 已禁用"

func _convert_back(value) -> bool:
	return value != "✗ 已禁用"
```

**框架自带的 4 个 Converter**:

| 名称 | 路径 | 用途 | 例子 |
|---|---|---|---|
| `BoolToTextConverter` | `res://core/converters/bool_to_text_converter.gd` | bool → 文本 | `true` → `"✓ 已启用"` |
| `CurrencyConverter` | `res://core/converters/currency_converter.gd` | float → 千分位货币 | `1234.5` → `"¥1,234.50"` |
| `PercentageConverter` | `res://core/converters/percentage_converter.gd` | 0~1 → 百分比 | `0.85` → `"85%"` |
| `FloatToPercentConverter` | `res://core/converters/float_to_percent_converter.gd` | float → 百分比 | `0.75` → `"75%"` |

**用法 (在 Activity 里直接调用)**:

```gdscript
const CurrencyConverter = preload("res://core/converters/currency_converter.gd")

func _update_total_lbl(_v) -> void:
	var conv = CurrencyConverter.new()
	_total_lbl.text = conv.convert(vm.total)  # 132.84 → "¥132.84"
```

**为什么 `_convert` 带下划线**: GDScript 子类的"override"不会调 C++ 虚函数, Godot 4 解析器会报"method overrides native class method"。用 `_` 前缀规避。

---

## 5. 8 个示例速查表

`gf_test/modules/complex_examples/` 下有 8 个**完整可跑**的示例, 每个都覆盖一个典型模式。

| # | 模式 | 示例 | 路径 |
|---|---|---|---|
| 1 | 列表 + 过滤 + CRUD | **UserList** | `modules/complex_examples/user_list/` |
| 2 | 计算属性 + 折扣 | **ShoppingCart** | `modules/complex_examples/shopping_cart/` |
| 3 | 实时校验 + 异步 | **RegistrationForm** | `modules/complex_examples/registration_form/` |
| 4 | 状态机 + 历史 | **OrderState** | `modules/complex_examples/order_state/` |
| 5 | 嵌套 VM + 装备 | **PlayerCard** | `modules/complex_examples/player_card/` |
| 6 | 表格 + 排序 + 分页 | **DataTable** | `modules/complex_examples/data_table/` |
| 7 | 实时推送 (Mock) | **WebSocketFeed** | `modules/complex_examples/websocket_feed/` |
| 8 | 撤销/重做 | **UndoRedo** | `modules/complex_examples/undo_redo/` |

### 5.1 UserList — 列表 + 过滤 + CRUD

**展示了**:
- 集合属性 `users: Array[UserItem]` 整体作为 `ObservableProperty`
- 搜索关键词 `search_query` 过滤 → 派生 `filtered_users`
- CRUD: 添加 / 删除 / 清空 / 选中
- 内嵌 `UserItem` 数据类 (`RefCounted`)
- 内嵌自定义 Converter (`OnlineStatusConverter`, bool → "在线/离线")
- 异步加载模拟 (用 `await Engine.get_main_loop().process_frame`)

**关键文件**:
- `user_list/user_list_vm.gd` — VM + 内嵌 `UserItem` / `OnlineStatusConverter`
- `user_list/user_list_activity.gd` — 列表 UI 重建 + 选中态高亮

### 5.2 ShoppingCart — 计算属性 + 折扣

**展示了**:
- 计算属性链: `cart_items` → `subtotal` / `item_count` → `tax` / `total` / `is_checkout_enabled`
- 折扣码 (Dictionary 查表 + 派生 `discount_rate`)
- `begin_bulk_update` / `end_bulk_update` 包裹重算——5 个派生量一次通知
- `CurrencyConverter` + `PercentageConverter` 组合
- 结算 (checkout) 命令——空购物车时禁用按钮

**关键文件**:
- `shopping_cart/shopping_cart_vm.gd` — 5 个派生量 + 折扣码查表
- `shopping_cart/shopping_cart_activity.gd` — 数量 +/- 按钮 + 实时总价

### 5.3 RegistrationForm — 实时校验 + 异步

**展示了**:
- 4 个字段 (用户名 / 邮箱 / 密码 / 确认) 的同步校验
- **模拟异步服务端校验**——用户名是否已被占用 (用 `await process_frame` 假延迟)
- 错误状态字符串 (`username_error` / `email_error` / ...) 派生于输入
- 派生 `can_submit` 按钮可用性——所有字段通过 + 服务端放行才 true
- 协议勾选 `agreed_to_terms` 触发 `terms_error`

**关键文件**:
- `registration_form/registration_form_vm.gd` — 5 个校验函数 + 异步 `await` 模式
- `registration_form/registration_form_activity.gd` — 错误高亮 + 按钮 disabled

**调试技巧** (这个例子的 `_simulate_server_check`):
```gdscript
# 在 VM 里模拟异步, 注意 VM 是 RefCounted 不能用 get_tree()
await Engine.get_main_loop().process_frame  # 让出主线程
```

### 5.4 OrderState — 状态机 + 历史

**展示了**:
- `enum OrderState` 6 个状态
- **状态转移图** `STATE_TRANSITIONS: Dictionary` 显式声明哪些状态可去哪些
- 派生布尔标志 `can_pay` / `can_ship` / `can_refund` ——根据当前状态机位置
- 转移历史日志 `history: Array[Dictionary]` ——包含时间 / from / to / action
- 异步状态转移 `on_pay()` ——切到 `is_processing = true`, 模拟网络, 完成

**关键文件**:
- `order_state/order_state_vm.gd` — 状态机核心
- `order_state/order_state_activity.gd` — 6 个按钮按 `can_xxx` 灰显 + 历史时间线

**模式名称**: 状态机 (State Machine), 加上审计日志 (Audit Log)。

### 5.5 PlayerCard — 嵌套 VM + 装备

**展示了**:
- 内嵌 `EquipmentItemVM extends RefCounted` ——单件装备, 简化版 (没继承 `base_view_model`)
- 玩家基础属性 + 装备列表组合数据
- **派生总战力** ——基础攻击 + 装备攻击 + 1.5× 防御 + HP/10
- 装备增删改 (同槽位替换, 新槽位追加)
- 颜色派生 (按装备最高稀有度 → 灰 / 绿 / 蓝 / 紫 / 橙)
- 升级 `on_level_up()` 触发 `begin_bulk_update` (基础属性 + 派生量同改)

**关键文件**:
- `player_card/player_card_vm.gd` — 嵌套 VM + 战力公式
- `player_card/player_card_activity.gd` — 装备槽 + 模板库按钮

**注**: 这个例子里 `EquipmentItemVM` 没继承 `base_view_model` (用了 `RefCounted` 简化)——如果装备字段改动也需要通知, 应该让装备本身也继承 `base_view_model`。详见 [§9 进阶](#9-进阶-什么时候拆-converter--拆-vm)。

### 5.6 DataTable — 表格 + 排序 + 分页

**展示了**:
- 32 行种子数据 (4 类 × 8 行)
- **派生属性链** `all_rows → filtered_rows → sorted_rows → paged_rows`
- 搜索 + 类别过滤
- 排序: 点同列翻转升降序, 点不同列重置为升序
- 分页: `page_size` / `current_page` / `page_count` ——越界自动 `clamp`
- 纯业务逻辑, 完全脱离 UI 也能跑测试 (`data_table_test.gd`)

**关键文件**:
- `data_table/data_table_vm.gd` — 派生链 + 排序比较器
- `data_table/data_table_activity.gd` — 表头点击排序 + 翻页按钮
- `data_table/data_table_test.gd` — 30+ 断言的 headless 自检

**进阶学习点**: 3 个子重算函数 (`_recompute_filtered` / `_recompute_sorted` / `_recompute_paging`) 各自只更新自己关心的派生量, 避免重复算。

### 5.7 WebSocketFeed — 实时推送 (Mock)

**展示了**:
- **Test Double 模式** ——Godot 4 的 `WebSocketPeer` 在 headless 不好测, 用内存级 `MockWebSocketClient extends RefCounted` 替代
- 连接状态机 `DISCONNECTED → CONNECTING → CONNECTED → DISCONNECTED`
- 实时消息流 `messages: Array[Dictionary]` ——`{time, content, sender}`
- 未读计数 `unread_count` + 最后消息预览 `last_message_preview`
- 双向信号 (`message_received` / `disconnected`) 通过 `signal` 桥接

**关键文件**:
- `websocket_feed/websocket_feed_vm.gd` — VM + 内嵌 `MockWebSocketClient`
- `websocket_feed/websocket_feed_activity.gd` — 消息列表 + 红点 + 发送框
- `websocket_feed/websocket_feed_test.gd` — 11 个断言, 模拟推送与断线

**注意命名**: Mock 里用 `do_disconnect()` 而不是 `disconnect()`——`disconnect` 是 `Object` 的内置方法, 会被解析器误调。详细见 [§8 FAQ](#8-gdscript-4-必踩的坑-faq)。

### 5.8 UndoRedo — 撤销/重做

**展示了**:
- **快照 (Snapshot) 内嵌类**——`{text, cursor_pos, timestamp}`
- **双栈** `_undo_stack` / `_redo_stack`
- **时间合并策略**——连续编辑间隔 < 500ms 合并为同一快照 (避免每按一个键都入栈)
- `move_cursor()` 不入栈 (光标移动不是编辑)
- 新动作清空 redo_stack (标准编辑器语义)
- `undo` / `redo` 用 `begin_bulk_update` 包裹 7 个属性
- 历史栈容量限制 `history_size_limit = 50`

**关键文件**:
- `undo_redo/undo_redo_vm.gd` — 快照合并 + 双栈算法
- `undo_redo/undo_redo_activity.gd` — TextEdit **双向绑定** + `_suppress_text_changed` 标志
- `undo_redo/undo_redo_test.gd` — 12 个测试用例

**双向绑定技巧** (TextEdit):

```gdscript
# Activity 端
var _suppress_text_changed: bool = false

func _update_document_text(v) -> void:
	var new_text = str(v)
	if _text_edit.text == new_text:
		return
	_suppress_text_changed = true    # 抑制反向传播
	_text_edit.text = new_text
	_suppress_text_changed = false

func _on_text_edit_changed() -> void:
	if _suppress_text_changed:
		return  # 自己是"主", 不回传 VM
	# ... 把 TextEdit 变化转成 vm.insert_text / vm.delete_chars
```

---

## 6. Activity 生命周期

Activity 继承自 `Control` (C++ 端, `Activity = Control + 生命周期`), 由 `ActivityManager` 调度。

### 6.1 完整生命周期表

| 钩子 | 何时调用 | 你应该做什么 | 不应该做什么 |
|---|---|---|---|
| `_on_create(saved_state)` | 第一次创建, 不可见之前 | 构造 UI 树, 实例化 VM, 设置 transition, **订阅属性** | `await` 异步 / 启动协程 |
| `_on_start()` | UI 第一次可见 | 启动动画, 加载首屏数据 | 重型同步操作 (会卡帧) |
| `_on_resume()` | 从其他 Activity 返回, **或者** 第一次 `_on_start` 之后 | 恢复动画 / 计时器, 刷新数据 | 重新构造 UI (已经构造过了) |
| `_on_pause()` | 即将被新 Activity 盖住 | 暂停动画 / 计时器, 保存临时状态 | 释放 VM |
| `_on_stop()` | 完全被盖住 (visible = false) | 释放重型资源 (Texture / AudioStream) | `dispose()` VM |
| `_on_destroy()` | 永久销毁 (finish 或 NO_HISTORY) | `vm.dispose()` 释放订阅, 关网络连接 | 触发新 Activity |
| `_on_back_pressed()` | 系统返回键 | 返回 `true` 拦截, `false` 走默认 finish | — |

**生命周期顺序**:

```
首次启动:  _on_create → _on_start → _on_resume
被盖住:    _on_pause → _on_stop
从盖住回:  _on_resume           (注意: 不再调 _on_start)
销毁:      _on_pause → _on_stop → _on_destroy
```

### 6.2 常见模板

```gdscript
extends Activity

const MyVM = preload("res://my_vm.gd")

var vm: MyVM

func _on_create(saved_state: Dictionary) -> void:
	# 1) 构造 VM
	vm = MyVM.new()

	# 2) 配置转场 (可选)
	var tin = Transition.new(); tin.enter_type = Transition.SLIDE_LEFT; tin.duration = 0.3
	var tout = Transition.new(); tout.exit_type = Transition.SLIDE_RIGHT; tout.duration = 0.25
	transition_in = tin
	transition_out = tout

	# 3) 构造 UI 树
	_setup_ui()

	# 4) 订阅属性 + 命令绑定
	_bind_all()


func _on_start() -> void:
	# 首屏数据加载 (可以从 saved_state / Intent.extras 取参数)
	vm.load_initial_data(get_intent().extras)


func _on_resume() -> void:
	# 从其它 Activity 返回时: 重启动画 / 重新拉取数据
	pass


func _on_pause() -> void:
	# 暂停动画 / 计时器
	pass


func _on_stop() -> void:
	# 释放重型资源
	pass


func _on_destroy() -> void:
	# 必须 dispose VM
	if vm:
		vm.dispose()


func _on_back_pressed() -> bool:
	# 拦截返回 (例如: 提示"放弃编辑?")
	# return true  # 拦截
	return false   # 默认 finish
```

### 6.3 关键提醒

- **`_on_create` 是构造期**——这里调 `await` 会出问题, 留给 `_on_start` 或更后面
- **`_on_destroy` 一定要 `vm.dispose()`**——否则 `ObservableProperty` 持有的 Callable 不会释放, 可能造成泄漏
- **`_on_back_pressed` 拦截返回**——例如表单未保存时拦截, 弹个确认 dialog

---

## 7. 测试怎么写

VM 是纯 `RefCounted`, 不需要场景树, **直接在 entry.gd 里写 `_test_N_xxx()` 函数**就能跑。

### 7.1 模板

```gdscript
# 写在 entry.gd 里, _ready() 中调用
func _test_11_userlist_vm() -> void:
	print("\n[Test 11] UserList VM")
	var UL_VM = preload("res://modules/complex_examples/user_list/user_list_vm.gd")
	var vm = UL_VM.new()

	# 1) 初始状态
	assert(vm.users.is_empty(), "初始 users 为空")
	assert(vm.filtered_users.is_empty(), "初始 filtered_users 为空")

	# 2) 调用命令
	vm.on_add_demo_user()
	assert(vm.users.size() == 1, "添加后 users == 1")

	# 3) 测搜索
	vm.set_search_query("xxx")
	assert(vm.filtered_users.is_empty(), "无匹配")

	# 4) 清理
	vm.dispose()
	print("  OK")
```

### 7.2 完整模板 (含异步)

```gdscript
func _test_13_form_vm() -> void:
	print("\n[Test 13] RegistrationForm VM")
	var Form_VM = preload("res://modules/complex_examples/registration_form/registration_form_vm.gd")
	var vm = Form_VM.new()

	# 同步部分
	vm.on_username_changed("ab")
	assert(not vm.username_error.is_empty(), "ab 太短 → 错误")

	# 异步部分: VM 内的 await 走的是 Engine.get_main_loop().process_frame
	# 在测试里用 timer 等
	vm.on_username_changed("valid_user")
	await get_tree().create_timer(0.1).timeout
	assert(vm.username_error.is_empty(), "valid_user 通过 (异步校验完成)")

	vm.dispose()
	print("  OK")
```

### 7.3 完全脱离场景树的纯静态测试

可以做一个 `extends RefCounted` 的工具类, 静态函数跑断言。`data_table_test.gd` 就是这个风格:

```gdscript
extends RefCounted
class_name DataTableSelfTest

const DataTableVM = preload("res://modules/complex_examples/data_table/data_table_vm.gd")

static func run() -> void:
	var vm = DataTableVM.new()
	assert(vm.all_rows.size() >= 30, "种子数据 >= 30")
	vm.sort_by("price")
	assert(vm.sort_column == "price", "sort_column == 'price'")
	# ... 30+ 断言
	vm.dispose()
	print("  OK")
```

**优点**: 不需要 `await`, 同步跑完, 集成任务可以直接调 `DataTableSelfTest.run()`。

### 7.4 Headless 模式自动跑

`godot --headless` 时, `entry.gd` 的 `_ready()` 末尾会自动跑所有 `_test_N_xxx()`:

```gdscript
# entry.gd
func _ready() -> void:
	app = Application.new()
	app.initialize(self)
	# ...

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.5).timeout
		print("\n" + "=".repeat(60))
		print("[AutoTest] 开始自动化验证...")
		print("=".repeat(60))

		await _test_1_service()
		await _test_2_navigation()
		# ... 一直到 _test_15_player_vm()

		app.shutdown()
		get_tree().quit(0)
```

**命令行**:

```bash
godot --headless --path D:/AI_Temp/gf_test
```

输出形如:

```
[Test 11] UserList VM
  OK
[Test 12] ShoppingCart VM
  OK
...
[AutoTest] 全部通过!
```

### 7.5 调试技巧

- **`print("  [debug] xxx = %s" % value)`** — 加在 assert 前后看具体值, 比单看 "assert failed" 强
- **失败时** `assert(condition, "message")` 第二个参数会变成 message, 搜 grep 就能定位
- **headless 跑挂** 时看 `entry.gd` 哪个 `_test_N_xxx()` 是最后一行被打印的

---

## 8. GDScript 4 必踩的坑 (FAQ)

### Q1: 注释 `//` 报错?

**A**: Godot 4 用 `#`, 不是 `//`。C/C++/Java 习惯会踩。

```gdscript
# 正确
# 这是一行注释

// 错误
// InvalidCommentError
```

### Q2: `condition ? a : b` 报错?

**A**: Godot 4 用 Python 风格 `a if condition else b`。

```gdscript
# 正确
var result = "在线" if is_online else "离线"
var color = COLOR_A if is_loading else COLOR_B

# 错误
var result = is_online ? "在线" : "离线"  # ParseError
```

### Q3: `vm.get_tree()` 报错?

**A**: **VM 是 `RefCounted`, 没有 `get_tree()`**。`RefCounted` 不是 `Node` 子类, 不在场景树里。

```gdscript
# 错误
var t = vm.get_tree()  # null (没有这个方法)

# 正确: 用 Engine.get_main_loop()
await Engine.get_main_loop().process_frame

# 业务上的等价物
var t = get_tree()  # 只有 Activity / Node 才有 get_tree()
```

**实战技巧**: 异步逻辑尽量放在 VM 内部, 让 VM 用 `Engine.get_main_loop()` 模拟; Activity 只调 `vm.xxx()` 不传 `await`。

### Q4: 变量名 `class_name` 报错?

**A**: `class_name` 是 Godot 4 关键字 (声明全局类型用), 不能当变量名。

```gdscript
# 错误
var class_name: String = "战士"  # ParseError

# 正确: 重命名
var player_class: String = "战士"
```

**实战**: 写 `class_name` 前先 grep `class_name`, 看到的所有 `class_name` 都是关键字, 不能作变量。

### Q5: 一次操作触发太多 UI 更新?

**A**: 用 `begin_bulk_update()` / `end_bulk_update()` 包裹。

```gdscript
# 错误: 5 次通知, UI 重绘 5 次
func _recompute_totals() -> void:
	subtotal = 0.0
	tax = 0.0
	total = 0.0
	item_count = 0
	is_checkout_enabled = true

# 正确: 1 次合并通知
func _recompute_totals() -> void:
	begin_bulk_update()
	subtotal = 0.0
	tax = 0.0
	total = 0.0
	item_count = 0
	is_checkout_enabled = true
	end_bulk_update()
```

**何时该包**: 派生属性 (多个相关量同步算) / 一组相关输入批量改 / 撤销重做。**何时不该包**: 单个属性改 (没意义, 还多调 2 个 native call)。

### Q6: 双向绑定 TextEdit 进死循环?

**A**: 用 `_suppress_xxx_changed` 标志抑制反向传播。

**症状**: TextEdit `text_changed` → VM `document_text = new_text` → 触发 VM 订阅者 → Activity `_update_document_text` → `text_edit.text = new_text` → 又触发 `text_changed` → 死循环。

**修法** (见 `undo_redo_activity.gd:24-26, 174-179, 230-232`):

```gdscript
var _suppress_text_changed: bool = false

# VM → UI 方向
func _update_document_text(v) -> void:
	if _text_edit.text == str(v):
		return
	_suppress_text_changed = true
	_text_edit.text = str(v)
	_suppress_text_changed = false

# UI → VM 方向
func _on_text_edit_changed() -> void:
	if _suppress_text_changed:
		return
	# ... 真正的编辑逻辑
```

**一般原则**: UI → VM 方向的主语是"用户编辑", VM → UI 方向是"程序同步", 后者需要抑制反馈。

### Q7: 异步用 `await` 时, `vm.get_tree()` 拿不到?

**A**: 同 Q3, 用 `Engine.get_main_loop().process_frame`。

```gdscript
# VM 内 (RefCounted)
await Engine.get_main_loop().process_frame  # 正确

# Activity 内 (Node)
await get_tree().create_timer(0.1).timeout  # 正确
```

### Q8: 内嵌类怎么引用?

**A**: 用 `外层类名.内嵌类名` 引用, 不需要单文件 `preload`。

```gdscript
# 在 user_list_vm.gd 内部
class OnlineStatusConverter extends ValueConverter:
	pass

# 在 user_list_activity.gd 引用
const UserListVM = preload("res://user_list_vm.gd")
var conv = UserListVM.OnlineStatusConverter.new()  # 通过外层类名访问
```

**注意**: 不要 `preload("res://user_list_vm.gd::OnlineStatusConverter")`——`::` 在 GDScript 里**不是**嵌套类引用语法, 那个路径解析不到。

### Q9: `dispose()` 忘了调怎么办?

**A**: 框架**不会**自动调, 你必须在 `_on_destroy` 里手动调。

```gdscript
# 必须有
func _on_destroy() -> void:
	if vm:
		vm.dispose()
```

**症状**: Activity 被反复打开 / 关闭, 内存慢慢涨; 旧的 ObservableProperty 还持有 Callable 引用, 但 Activity 节点已经 free, 调用就 crash。

### Q10: `subscribe_property` 的回调, 参数类型怎么写?

**A**: 用 `Variant` (不写类型) 就行, 内部需要时收窄。

```gdscript
# 不推荐 (会警告)
vm.subscribe_property("count", _on_count_changed)
func _on_count_changed(new_value: int) -> void:
	# 参数是 int, 但框架传的是 Variant — 类型不匹配警告
	pass

# 推荐
vm.subscribe_property("count", _on_count_changed)
func _on_count_changed(new_value) -> void:
	# 内部按需收窄
	var n = int(new_value)
	_lbl.text = "count = %d" % n

# 想要类型安全: 进函数体里再 assert / 强转
func _on_count_changed(new_value) -> void:
	assert(typeof(new_value) == TYPE_INT)
```

---

## 9. 进阶: 什么时候拆 converter / 拆 VM

### 9.1 拆 ValueConverter 的时机

**应该拆**:
- 同一格式在 3 个以上地方用 (比如 `CurrencyConverter` 至少 3 个 Activity 用)
- 转换逻辑有边界条件 / 特殊字符处理 (比如 `CurrencyConverter` 处理千分位)
- 双向转换都需要 (`_convert` + `_convert_back` 都要写)

**不该拆**:
- 只在一个地方用, 转换就是 `x * 100` 这种一行的事——直接 `.format("%.0f%%", x * 100)` 就行
- 临时 inline 调试用的, 跑通就清掉

**实践建议**: 项目根 `core/converters/` 下放通用 converter (货币 / 百分比 / bool 文本), **业务特化的 converter 放在 VM 内部的内嵌类** (见 `user_list_vm.gd::OnlineStatusConverter`)。

### 9.2 拆 VM 的时机

**应该拆** (成独立文件):
- 单一 VM 超过 ~300 行
- 多个 Activity 想共用一份业务逻辑
- VM 内部嵌了 `EquipmentItemVM` 这种"独立子业务" (见 `player_card_vm.gd`)——把它拆成独立文件, 继承 `base_view_model`

**不该拆**:
- 简单的 `CartItem` 这种纯数据, 留在 VM 里内嵌
- 拆出去会增加跨文件跳转, 但只有 1-2 个属性——不值得

**判断口诀**:
> 如果一段逻辑可以被 2 个以上 Activity 复用, 或者 1 个 VM 的 `_recompute_xxx` 函数超过 50 行, 拆。

### 9.3 命令模式 vs 直接 setter

**直接 setter** (推荐用于"输入 → 派生"):

```gdscript
# Activity
vm.discount_code = "SAVE10"  # VM 自己 _recompute_totals

# VM
var discount_code: String = ""
func _recompute_totals() -> void:
	discount_rate = DISCOUNT_CODES.get(discount_code, 0.0)
	# ...
```

**命令方法** (推荐用于"动作", 有副作用 / 校验):

```gdscript
# Activity
vm.apply_discount_code("SAVE10")  # 返回 bool 表示是否成功

# VM
func apply_discount_code(code: String) -> bool:
	discount_code = code.to_upper()
	discount_rate = DISCOUNT_CODES.get(discount_code, 0.0)
	_recompute_totals()
	return discount_rate > 0.0
```

**判断口诀**:
- 单纯改一个字段 → 直接 setter (`vm.xxx = y`)
- 改一个字段 + 重算 + 校验 + 返回状态 → 命令方法 (`vm.on_xxx() / vm.apply_xxx()`)

### 9.4 嵌套 VM (内嵌 vs 独立文件)

**`player_card_vm.gd::EquipmentItemVM`** 选了内嵌 (用 `RefCounted`, 不继承 `base_view_model`)。
**缺点**: 装备字段改了**不会**通知 VM——VM 只能等 `on_equip` 命令触发重算。

**改进方案** (当装备改动也需要细粒度通知时):

```gdscript
# 独立文件: equipment_item_vm.gd
extends "res://core/base_view_model.gd"
class_name EquipmentItemVM
var slot: String = ""
var attack: int = 0
# ...

# player_card_vm.gd 引用
const EquipmentItemVM = preload("res://equipment_item_vm.gd")
var equipment: Array = []  # Array[EquipmentItemVM]
```

这样改 `equipment[i].attack = 50` 也会自动通知。

**判断口诀**:
- 内嵌 `RefCounted` — 装备是"被 VM 整体管理的子数据", 改装备只有"换装"动作
- 独立 `extends base_view_model` — 装备有"独立 UI 编辑"的需求, 改装备内部字段也要通知

### 9.5 重构信号

如果发现:

| 症状 | 重构 |
|---|---|
| Activity `_on_create` 超过 200 行 | 拆 `_setup_ui` / `_bind_all` / `_setup_transitions` |
| VM 超过 500 行 | 按业务域拆 2-3 个子 VM, 主 VM 持有引用 |
| 同一个 setter 在 3 个以上地方被改 | 包成命令方法, 在 VM 内部加校验 |
| Activity 之间互相拿 `vm` 直接读 | 加一个 `get_view_state()` 方法, 暴露只读快照 |
| `subscribe_property` 越来越多 (>10 个) | 想想是不是该把"几个相关属性"合并成"一个状态对象" |

---

## 10. 进一步阅读

### 10.1 8 个复杂示例 (项目内)

所有 8 个示例的源代码都在:

```
D:\AI_Temp\gf_test\modules\complex_examples\
├── user_list\          # 1) 列表 + 过滤 + CRUD
├── shopping_cart\      # 2) 计算属性 + 折扣
├── registration_form\  # 3) 实时校验 + 异步
├── order_state\        # 4) 状态机 + 历史
├── player_card\        # 5) 嵌套 VM + 装备
├── data_table\         # 6) 表格 + 排序 + 分页
├── websocket_feed\     # 7) 实时推送 (Mock)
└── undo_redo\          # 8) 撤销 / 重做
```

每个目录下有 `xxx_vm.gd` (业务) + `xxx_activity.gd` (UI) + 部分有 `xxx_test.gd` (headless 自检)。

**推荐阅读顺序** (由浅入深):
1. `user_list` — 集合属性 + CRUD, 最入门
2. `shopping_cart` — 计算属性 + Converter, 模式定型
3. `order_state` — 状态机 + 历史
4. `registration_form` — 异步 + 校验
5. `data_table` — 派生链 + 排序
6. `player_card` — 嵌套 VM + 装备
7. `websocket_feed` — Test Double + 信号桥接
8. `undo_redo` — 双向绑定 + 快照合并

### 10.2 框架核心 (C++ 端)

`game_framework` 模块在:

```
D:\AI_Temp\Godot\godot-4.7-beta\modules\game_framework\
```

关键文件:
- `mvvm/view_model.h` / `view_model.cpp` — `ViewModel` 基类 (HashMap<StringName, Ref<ObservableProperty>>)
- `mvvm/observable_property.h` / `observable_property.cpp` — 单值容器, 发 `value_changed` 信号
- `mvvm/binding_engine.h` / `binding_engine.cpp` — 静态工具, 桥接 VM 属性 ↔ 控件属性
- `mvvm/value_converter.h` / `value_converter.cpp` — 转换器基类
- `application.h` / `application.cpp` — Application 容器, 持有 ActivityManager
- `doc_classes/*.xml` — Godot 编辑器内类文档 (Activity / Application / ViewModel 等)

### 10.3 GDScript 基础

- 官方文档: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html>
- 关键章节: 类型标注 / `signal` / `class_name` / `@onready` / `await` / `extends`

### 10.4 MVVM 通用知识

如果你之前没接触过 MVVM, 任何平台的入门文章都适用——核心思想是"UI 不知道业务, 业务不知道 UI, 中间靠 ObservableProperty 串起来"。本框架是这个思想在 Godot 4 + GDScript 里的一个具体实现。

### 10.5 反馈 / 改进

发现文档错误或不清楚的地方, 直接在 `docs/VM_ACTIVITY_GUIDE.md` 提 PR 或找 @coder。

---

## 附录: 速查代码片段

### A. 最小的 VM

```gdscript
extends "res://core/base_view_model.gd"
var x: int = 0
func on_change(): x += 1
```

### B. 最小的 Activity

```gdscript
extends Activity
const X = preload("res://x_vm.gd")
var vm: X
func _on_create(_s): vm = X.new()
func _on_destroy(): vm.dispose()
```

注意 `_on_destroy` 直接 `vm.dispose()`, 不需要 `bind`。

### C. 订阅 + 命令绑定一气呵成

```gdscript
func _bind_all() -> void:
	# 数据绑定 (VM → UI)
	vm.subscribe_property("count", _on_count)
	vm.subscribe_property("loading", _on_loading)
	# 命令绑定 (UI → VM) — 显式 connect
	_btn.pressed.connect(_on_btn)
	# 或用 BindingEngine (省包装函数)
	BindingEngine.bind_command(_btn, "pressed", vm, "on_change")
```

### D. 批量更新模板

```gdscript
func _recompute_derived() -> void:
	begin_bulk_update()
	# ... 改 5-10 个派生量
	end_bulk_update()
```

### E. 错误标志计算

```gdscript
var username_error: String = ""  # 空 = 无错

func on_username_changed(new_v: String) -> void:
	username = new_v
	username_error = _validate(new_v)
	_recompute_can_submit()  # 派生: 任何错都让 can_submit = false

func _recompute_can_submit() -> void:
	can_submit = (
		username_error.is_empty() and
		email_error.is_empty() and
		# ... 其它检查
		agreed_to_terms
	)
```

### F. 异步命令 (在 VM 内)

```gdscript
func on_pay() -> void:
	is_processing = true
	# 模拟网络延迟
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	# ... 完成处理
	is_processing = false
```

### G. 双向绑定 (TextEdit 抑制循环)

```gdscript
var _suppress_text_changed: bool = false

func _vm_to_ui(v):
	if _text_edit.text == str(v): return
	_suppress_text_changed = true
	_text_edit.text = str(v)
	_suppress_text_changed = false

func _on_text_edit_changed():
	if _suppress_text_changed: return
	# 真正处理编辑...
```

### H. 嵌套数据类

```gdscript
class MyItem extends RefCounted:
	var id: int
	var name: String
	func _init(p_id: int, p_name: String) -> void:
		id = p_id; name = p_name

var items: Array = []
items.append(MyItem.new(1, "Hello"))
```

### I. 自定义 Converter

```gdscript
# 文件: my_converter.gd
extends ValueConverter
func _convert(v) -> String: return "★" if v else "✗"
func _convert_back(v: String) -> bool: return "★" in v
```

```gdscript
# 使用
const MyConv = preload("res://my_converter.gd")
var conv = MyConv.new()
_lbl.text = conv.convert(vm.is_active)
```

### J. 状态机 (最小骨架)

```gdscript
enum State { IDLE, LOADING, READY }
var state: int = State.IDLE
var can_load: bool = true

func on_load():
	if state != State.IDLE: return
	state = State.LOADING
	can_load = false
	# ... 异步
	state = State.READY
	can_load = true
```

---

> 文档版本: 2026-06-09
> 维护者: @coder
> 反馈: 在 `docs/VM_ACTIVITY_GUIDE.md` 提 PR 或联系维护者
