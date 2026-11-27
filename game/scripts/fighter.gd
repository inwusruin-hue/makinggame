## A unit or enemy fighting in the battle lane. Combat logic lives in battle.gd.
class_name Fighter
extends Node2D

const TEAM_COLORS := Piece.COLORS

var team: String = "unit"      # "unit" or "enemy"
var type: String = "sword"     # unit type key, or "grunt"/"boss"
var star: int = 1
var max_hp: float = 1.0
var hp: float = 1.0
var atk: float = 1.0
var attack_range: float = 30.0
var speed: float = 50.0
var cooldown: float = 1.0
var splash: float = 0.0
var gold_reward: int = 0
var breach_damage: float = 0.0
var cd_left: float = 0.0
var flash_to: Vector2 = Vector2.ZERO
var flash_left: float = 0.0
var hit_left: float = 0.0
var size: float = 1.0

func setup(p_team: String, p_type: String, stats: Dictionary, p_star := 1, hp_mult := 1.0) -> void:
	team = p_team
	type = p_type
	star = p_star
	max_hp = stats.hp * hp_mult
	hp = max_hp
	atk = stats.atk
	attack_range = stats.range
	speed = stats.speed
	cooldown = stats.cooldown
	splash = stats.get("splash", 0.0)
	gold_reward = int(stats.get("gold", 0))
	breach_damage = stats.get("breach_damage", 0.0)
	size = 2.4 if p_type == "boss" else 1.0
	cd_left = randf() * cooldown

func apply_star(new_star: int, mult: float) -> void:
	var steps := new_star - star
	for i in steps:
		max_hp *= mult
		atk *= mult
	star = new_star
	hp = max_hp
	queue_redraw()

func take_hit(dmg: float) -> void:
	hp -= dmg
	hit_left = 0.12
	queue_redraw()

func _process(delta: float) -> void:
	if flash_left > 0.0 or hit_left > 0.0:
		flash_left = max(0.0, flash_left - delta)
		hit_left = max(0.0, hit_left - delta)
		queue_redraw()

func _draw() -> void:
	var s := size
	draw_set_transform(Vector2.ZERO)
	# shadow
	draw_circle(Vector2(0, 14 * s), 12 * s, Color(0, 0, 0, 0.35))
	if team == "unit":
		var c: Color = TEAM_COLORS.get(type, Color.WHITE)
		var metal := Color("f3c75a") if type == "gold" else Color("596474")
		if hit_left > 0.0:
			metal = Color.WHITE
		draw_colored_polygon(PackedVector2Array([Vector2(-11, 13), Vector2(-6, -1), Vector2(6, -1), Vector2(11, 13)]), metal)
		draw_line(Vector2(-12, 14), Vector2(12, 14), c, 3.0)
		match type:
			"bow":
				draw_colored_polygon(PackedVector2Array([Vector2(-5, -1), Vector2(0, -20), Vector2(5, -1)]), metal)
			"mage":
				draw_colored_polygon(PackedVector2Array([Vector2(-6, -1), Vector2(0, -26), Vector2(6, -1)]), metal)
				draw_circle(Vector2(0, -16), 2.5, c)
			"guard":
				draw_rect(Rect2(-7, -17, 14, 16), metal)
			_:
				draw_circle(Vector2(0, -8), 7, metal)
		for i in star - 1:
			draw_circle(Vector2(-4 + i * 8, -34), 3, Color("f3c75a"))
		if flash_left > 0.0:
			draw_line(Vector2(0, -6), flash_to - position, c.lightened(0.3), 2.0)
	else:
		var body := Color("1a1416") if hit_left <= 0.0 else Color("6a3030")
		draw_colored_polygon(PackedVector2Array([Vector2(-11 * s, 15 * s), Vector2(-9 * s, -4 * s), Vector2(0, -18 * s), Vector2(9 * s, -4 * s), Vector2(11 * s, 15 * s)]), body)
		draw_line(Vector2(-9 * s, -4 * s), Vector2(-15 * s, -12 * s), Color("3a1c1c"), 2.5 * s)
		draw_line(Vector2(9 * s, -4 * s), Vector2(15 * s, -12 * s), Color("3a1c1c"), 2.5 * s)
		draw_rect(Rect2(-6 * s, -6 * s, 4 * s, 2.2 * s), Color("ff4a3a"))
		draw_rect(Rect2(2 * s, -6 * s, 4 * s, 2.2 * s), Color("ff4a3a"))
	# hp bar
	var w := 26.0 * s
	var y := -40.0 * s if team == "unit" else -28.0 * s
	draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.6))
	var col := Color("e8eaee") if team == "unit" else Color("ff4a3a")
	draw_rect(Rect2(-w / 2, y, w * clamp(hp / max_hp, 0.0, 1.0), 3), col)
