extends "res://core/base_view_model.gd"
## 复杂示例 5 — 玩家卡片 + 装备 (Nested ViewModel)
##
## 演示：
##   * 嵌套 ViewModel — EquipmentItem VM 嵌套在 PlayerCardVM 内
##   * 组合数据: 玩家属性 + 多件装备
##   * 派生属性: 总战力 = 玩家基础战力 + 装备加成
##   * 增删装备
##   * 批量更新 (装备变动 → 重新计算战力)

class EquipmentItemVM extends RefCounted:
	# 注: 嵌套 VM 应该是独立的 base_view_model，但这里简化用 RefCounted + 手动通知
	# 实际项目里可以拆为独立 .gd 文件继承 base_view_model
	var slot: String = ""  # "武器"/"头盔"/"胸甲"/"鞋子"
	var name: String = ""
	var attack: int = 0
	var defense: int = 0
	var rarity: int = 1  # 1-5 星

	func _init(p_slot: String = "", p_name: String = "", p_atk: int = 0, p_def: int = 0, p_rarity: int = 1) -> void:
		slot = p_slot
		name = p_name
		attack = p_atk
		defense = p_def
		rarity = p_rarity

	func to_dict() -> Dictionary:
		return {"slot": slot, "name": name, "attack": attack, "defense": defense, "rarity": rarity}


# === 玩家属性 ===
var player_name: String = "勇者"
var player_level: int = 42
var player_exp: int = 0
var player_exp_to_next: int = 100
var base_attack: int = 100
var base_defense: int = 80
var base_hp: int = 1000
# 注: 'class_name' 是 Godot 4 关键字(声明 class 全局类型),用作变量名会冲突
# 重命名为 player_class
var player_class: String = "战士"

# 装备 (EquipmentItemVM 列表)
var equipment: Array = []  # Array[EquipmentItemVM]

# 派生属性
var total_attack: int = 0
var total_defense: int = 0
var total_hp: int = 0
var power_rating: int = 0  # 战力 (综合)
var rarity_color: Color = Color.WHITE

# 装备模板库 (用于快速添加)
const EQUIPMENT_TEMPLATES = [
	{"slot": "武器", "name": "屠龙宝刀", "attack": 80, "defense": 0, "rarity": 5},
	{"slot": "武器", "name": "精钢长剑", "attack": 35, "defense": 0, "rarity": 3},
	{"slot": "头盔", "name": "龙鳞头盔", "attack": 0, "defense": 40, "rarity": 4},
	{"slot": "头盔", "name": "皮帽", "attack": 0, "defense": 8, "rarity": 1},
	{"slot": "胸甲", "name": "神圣铠甲", "attack": 0, "defense": 60, "rarity": 5},
	{"slot": "胸甲", "name": "布衣", "attack": 0, "defense": 12, "rarity": 1},
	{"slot": "鞋子", "name": "疾风之靴", "attack": 15, "defense": 20, "rarity": 4},
	{"slot": "鞋子", "name": "草鞋", "attack": 0, "defense": 3, "rarity": 1},
]


# === 命令 ===

func on_equip(template: Dictionary) -> void:
	# 同槽位装备: 替换
	var slot = template["slot"]
	for i in range(equipment.size()):
		if equipment[i].slot == slot:
			equipment[i] = EquipmentItemVM.new(slot, template["name"], template["attack"], template["defense"], template["rarity"])
			_recompute_stats()
			return
	# 新槽位
	equipment.append(EquipmentItemVM.new(slot, template["name"], template["attack"], template["defense"], template["rarity"]))
	_recompute_stats()


func on_unequip(slot: String) -> void:
	equipment = equipment.filter(func(e): return e.slot != slot)
	_recompute_stats()


func on_level_up() -> void:
	begin_bulk_update()
	player_level += 1
	base_attack += 5
	base_defense += 4
	base_hp += 50
	_recompute_stats()
	end_bulk_update()


func on_take_damage(damage: int) -> void:
	# 演示: 直接设置玩家当前 HP (这里简化)
	pass


func on_reset() -> void:
	begin_bulk_update()
	equipment.clear()
	player_level = 42
	base_attack = 100
	base_defense = 80
	base_hp = 1000
	_recompute_stats()
	end_bulk_update()


# === 内部 ===

func _recompute_stats() -> void:
	begin_bulk_update()
	var atk_bonus = 0
	var def_bonus = 0
	var hp_bonus = 0
	var max_rarity = 0
	for e in equipment:
		atk_bonus += e.attack
		def_bonus += e.defense
		if e.attack > 0 or e.defense > 0:
			hp_bonus += e.attack + e.defense  # 简化
		if e.rarity > max_rarity:
			max_rarity = e.rarity

	total_attack = base_attack + atk_bonus
	total_defense = base_defense + def_bonus
	total_hp = base_hp + hp_bonus
	# 战力 = 攻击 * 1.5 + 防御 * 1.2 + 生命 / 10
	power_rating = int(total_attack * 1.5 + total_defense * 1.2 + total_hp / 10)
	rarity_color = _rarity_to_color(max_rarity)
	end_bulk_update()


func _rarity_to_color(r: int) -> Color:
	match r:
		1: return Color(0.7, 0.7, 0.7)  # 灰
		2: return Color(0.4, 0.8, 0.4)  # 绿
		3: return Color(0.3, 0.6, 1.0)  # 蓝
		4: return Color(0.7, 0.4, 1.0)  # 紫
		5: return Color(1.0, 0.7, 0.2)  # 橙
		_: return Color.WHITE


# 初始装备
func _init() -> void:
	on_Equip_template({"slot": "武器", "name": "精钢长剑", "attack": 35, "defense": 0, "rarity": 3})
	on_Equip_template({"slot": "头盔", "name": "皮帽", "attack": 0, "defense": 8, "rarity": 1})
	on_Equip_template({"slot": "胸甲", "name": "布衣", "attack": 0, "defense": 12, "rarity": 1})


# 用首字母大写别名兼容 GDScript
func on_Equip_template(template: Dictionary) -> void:
	on_equip(template)
