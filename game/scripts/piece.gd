## A physical object on the coin pusher table: a coin, a bomb coin, or a soldier figurine.
class_name Piece
extends RigidBody2D

const COLORS := {
	"sword": Color("6fa8ff"),
	"bow": Color("5fd39a"),
	"mage": Color("b58cff"),
	"guard": Color("9fb0c4"),
	"gold": Color("f3c75a"),
}

var kind: String = "coin"   # "coin", "bomb", or a unit type key ("sword", "bow", ...)
var radius: float = 17.0
var armed_time: float = -1.0  # bombs: seconds left until they detonate

func setup(p_kind: String, p_radius: float, p_mass: float, cfg: Dictionary) -> void:
	kind = p_kind
	radius = p_radius
	mass = p_mass
	gravity_scale = 0.0
	linear_damp = cfg.linear_damp
	angular_damp = cfg.angular_damp
	can_sleep = true
	var mat := PhysicsMaterial.new()
	mat.friction = cfg.friction
	mat.bounce = cfg.bounce
	physics_material_override = mat
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func is_figure() -> bool:
	return kind != "coin" and kind != "bomb"

func _draw() -> void:
	if kind == "coin" or kind == "bomb":
		var base := Color("d6a640") if kind == "coin" else Color("c8462e")
		draw_circle(Vector2(0, 2.5), radius, Color(0, 0, 0, 0.45))
		draw_circle(Vector2.ZERO, radius, base.darkened(0.35))
		draw_circle(Vector2.ZERO, radius - 2.0, base)
		draw_arc(Vector2.ZERO, radius * 0.62, 0, TAU, 24, base.lightened(0.35), 1.5, true)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.22, Color(1, 1, 1, 0.25))
		if kind == "bomb":
			draw_circle(Vector2.ZERO, 4.0, Color("ffd2c4"))
	else:
		var c: Color = COLORS.get(kind, Color.WHITE)
		var metal := Color("f3c75a") if kind == "gold" else Color("4a5363")
		draw_circle(Vector2(0, 3), radius, Color(0, 0, 0, 0.5))
		draw_circle(Vector2.ZERO, radius, c)               # team ring
		draw_circle(Vector2.ZERO, radius - 3.5, metal)       # metal base
		draw_circle(Vector2.ZERO, radius * 0.42, metal.lightened(0.25))  # head (top-down)
		draw_circle(Vector2(-3, -3), radius * 0.16, Color(1, 1, 1, 0.35))
