## Coin Legion prototype: coin pusher machine on top, battle lane below.
## One button (SPACE / left click, hold to repeat) drops a coin.
extends Node2D

const BALANCE_PATH := "res://data/balance.json"
const HOLD_REPEAT := 0.18
const PUSHER_DEPTH := 110.0

var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var table: Node2D
var pusher: AnimatableBody2D
var battle: Battle
var pusher_t := 0.0
var pusher_front := 0.0
var dropper_x := 0.0
var dropper_dir := 1.0
var coins_left := 0
var gold := 0
var drops := 0
var elapsed := 0.0
var hold_timer := 0.0
var chain := 0
var last_fall := -10.0
var chain_show := 0.0
var shown_chain := 0
var figures_fallen := 0
var coins_fallen := 0

# HUD
var hud: CanvasLayer
var lbl_wave: Label
var lbl_def: Label
var lbl_gold: Label
var lbl_coins: Label
var lbl_next: Label
var lbl_chain: Label
var lbl_army: Label
var lbl_center: Label

static func load_balance() -> Dictionary:
	var text := FileAccess.get_file_as_string(BALANCE_PATH)
	var data = JSON.parse_string(text)
	assert(data is Dictionary, "balance.json failed to parse")
	return data

func _ready() -> void:
	cfg = load_balance()
	rng.randomize()
	coins_left = int(cfg.economy.start_coins)
	dropper_x = (cfg.machine.left + cfg.machine.right) / 2.0
	_build_machine()
	_fill_table()
	battle = Battle.new()
	add_child(battle)
	battle.setup(cfg, self)
	battle.wave_cleared.connect(_on_wave_cleared)
	battle.wave_started.connect(func(w): _flash_center("WAVE %02d" % w, 1.2))
	battle.unit_merged.connect(func(t, s): _flash_center("%s ★%d 승급" % [cfg.units[t].name, s], 1.0))
	battle.defeated.connect(func(): _flash_center("방어선 붕괴 · R 키로 다시 시작", 999.0))
	_build_hud()

# ---------------------------------------------------------------- machine
func _build_machine() -> void:
	var m: Dictionary = cfg.machine
	var walls := StaticBody2D.new()
	add_child(walls)
	var h: float = m.edge - m.back_wall + 60.0
	_add_rect(walls, Vector2(m.left - 15.0, (m.back_wall + m.edge) / 2.0 + 20.0), Vector2(30, h))
	_add_rect(walls, Vector2(m.right + 15.0, (m.back_wall + m.edge) / 2.0 + 20.0), Vector2(30, h))
	_add_rect(walls, Vector2((m.left + m.right) / 2.0, m.back_wall - 15.0), Vector2(m.right - m.left + 60.0, 30))
	pusher = AnimatableBody2D.new()
	pusher.sync_to_physics = true
	_add_rect(pusher, Vector2.ZERO, Vector2(m.right - m.left - 2.0, PUSHER_DEPTH))
	pusher_front = m.pusher_front_min
	pusher.position = Vector2((m.left + m.right) / 2.0, pusher_front - PUSHER_DEPTH / 2.0)
	add_child(pusher)
	table = Node2D.new()
	add_child(table)

func _add_rect(body: CollisionObject2D, pos: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = pos
	body.add_child(cs)

func _fill_table() -> void:
	var m: Dictionary = cfg.machine
	var p: Dictionary = cfg.pieces
	var spacing: float = p.grid_spacing
	var slots: Array[Vector2] = []
	var y: float = m.pusher_front_min + 22.0
	var row := 0
	while y < m.edge - 22.0:
		var x: float = m.left + 20.0 + (spacing / 2.0 if row % 2 == 1 else 0.0)
		while x < m.right - 18.0:
			slots.append(Vector2(x + rng.randf_range(-2, 2), y))
			x += spacing
		y += spacing * 0.87
		row += 1
	slots.shuffle()
	var n := int(slots.size() * float(p.initial_fill))
	n = min(n, int(p.max_bodies) - 10)
	for i in n:
		var kind := _random_figure() if i < int(p.initial_figures) else "coin"
		_spawn_piece(kind, slots[i])

func _random_figure() -> String:
	var weights: Dictionary = cfg.figure_weights
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "sword"

func _spawn_piece(kind: String, pos: Vector2) -> Piece:
	var p: Dictionary = cfg.pieces
	var piece := Piece.new()
	var is_fig := kind != "coin" and kind != "bomb"
	piece.setup(kind, p.figure_radius if is_fig else p.coin_radius, p.figure_mass if is_fig else p.coin_mass, p)
	piece.position = pos
	if kind == "bomb":
		piece.armed_time = cfg.bomb.delay
	table.add_child(piece)
	return piece

func body_count() -> int:
	return table.get_child_count()

func next_drop_kind() -> String:
	if (drops + 1) % int(cfg.economy.bomb_every) == 0:
		return "bomb"
	return "coin"

## The one button. Returns true if a coin was dropped.
func drop() -> bool:
	if battle.is_defeated or battle.is_victory or coins_left <= 0:
		return false
	if body_count() >= int(cfg.pieces.max_bodies):
		return false
	coins_left -= 1
	drops += 1
	var kind := "bomb" if drops % int(cfg.economy.bomb_every) == 0 else "coin"
	if kind == "coin" and rng.randf() < float(cfg.economy.figure_drop_chance):
		kind = _random_figure()
	_spawn_piece(kind, Vector2(dropper_x, cfg.machine.drop_y))
	return true

func _physics_process(delta: float) -> void:
	elapsed += delta
	var m: Dictionary = cfg.machine
	# pusher: smooth back-and-forth
	pusher_t += delta
	var k := 0.5 - 0.5 * cos(TAU * pusher_t / float(m.pusher_period))
	pusher_front = lerp(float(m.pusher_front_min), float(m.pusher_front_max), k)
	pusher.position.y = pusher_front - PUSHER_DEPTH / 2.0
	# dropper: sweeps left-right
	dropper_x += dropper_dir * float(m.dropper_speed) * delta
	if dropper_x > m.right - 24.0:
		dropper_x = m.right - 24.0
		dropper_dir = -1.0
	elif dropper_x < m.left + 24.0:
		dropper_x = m.left + 24.0
		dropper_dir = 1.0
	# hold-to-repeat
	if Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hold_timer -= delta
		if hold_timer <= 0.0:
			drop()
			hold_timer = HOLD_REPEAT
	else:
		hold_timer = 0.0
	# pieces: bombs, falls, strays
	for c in table.get_children():
		var p := c as Piece
		if p.is_queued_for_deletion():
			continue
		if p.armed_time > 0.0:
			p.armed_time -= delta
			if p.armed_time <= 0.0:
				_detonate(p)
		if p.position.y > m.edge:
			_on_fall(p)
		elif p.position.y < m.back_wall - 40.0 or p.position.x < m.left - 60.0 or p.position.x > m.right + 60.0:
			p.queue_free()
	if chain_show > 0.0:
		chain_show -= delta

func _detonate(bomb: Piece) -> void:
	var b: Dictionary = cfg.bomb
	for c in table.get_children():
		var p := c as Piece
		var d := p.position - bomb.position
		var dist := d.length()
		if p != bomb and dist < float(b.radius):
			var dir := d.normalized() if dist > 0.01 else Vector2.DOWN
			dir = (dir + Vector2(0, 0.6)).normalized()   # bias toward the edge
			p.sleeping = false
			p.apply_central_impulse(dir * float(b.impulse) * p.mass * (1.0 - dist / float(b.radius)))
	bomb.kind = "coin"
	bomb.queue_redraw()
	_flash_center("BOOM", 0.4)

func _on_fall(p: Piece) -> void:
	var m: Dictionary = cfg.machine
	if elapsed > float(cfg.pieces.warmup_seconds):
		if elapsed - last_fall <= float(cfg.chain.window):
			chain += 1
		else:
			chain = 1
		last_fall = elapsed
		if chain >= int(cfg.chain.min_show):
			shown_chain = chain
			chain_show = 1.2
		if p.is_figure():
			figures_fallen += 1
			var t: float = (p.position.x - m.left) / (m.right - m.left)
			battle.spawn_unit(p.kind, lerp(170.0, 460.0, t))
		else:
			coins_fallen += 1
			gold += int(cfg.economy.gold_per_coin)
	p.queue_free()

func _on_wave_cleared(_w: int) -> void:
	coins_left += int(cfg.economy.coins_per_wave)
	var m: Dictionary = cfg.machine
	for i in int(cfg.economy.figure_refill_per_wave):
		if body_count() >= int(cfg.pieces.max_bodies):
			break
		_spawn_piece(_random_figure(), Vector2(rng.randf_range(m.left + 30.0, m.right - 30.0), m.drop_y + rng.randf_range(-6, 6)))
	if battle.is_victory:
		_flash_center("승리! · R 키로 다시 시작", 999.0)
	else:
		_flash_center("웨이브 클리어 · 동전 +%d · 병사 보충" % int(cfg.economy.coins_per_wave), 1.6)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

# ---------------------------------------------------------------- drawing
func _process(_delta: float) -> void:
	queue_redraw()
	_update_hud()

func _draw() -> void:
	var m: Dictionary = cfg.machine
	var L: float = m.left
	var R: float = m.right
	var lane: Dictionary = cfg.lane
	# ambient glow behind machine
	draw_circle(Vector2((L + R) / 2.0, 330), 470, Color(0.23, 0.35, 0.54, 0.06))
	# frame
	draw_rect(Rect2(L - 34, m.back_wall - 34, R - L + 68, m.edge - m.back_wall + 48), Color("1a1f27"))
	draw_rect(Rect2(L - 30, m.back_wall - 30, 30, m.edge - m.back_wall + 40), Color("2f3642"))
	draw_rect(Rect2(R, m.back_wall - 30, 30, m.edge - m.back_wall + 40), Color("2f3642"))
	# table surface
	draw_rect(Rect2(L, m.back_wall, R - L, m.edge - m.back_wall), Color("18202c"))
	var gy: float = m.back_wall
	while gy < m.edge:
		draw_line(Vector2(L, gy), Vector2(R, gy), Color(1, 1, 1, 0.025))
		gy += 40.0
	# pusher
	var top := pusher_front - PUSHER_DEPTH
	draw_rect(Rect2(L + 1, max(top, m.back_wall), R - L - 2, pusher_front - max(top, m.back_wall)), Color("3a4250"))
	draw_line(Vector2(L + 1, pusher_front), Vector2(R - 1, pusher_front), Color("8c98aa"), 2.0)
	# edge
	draw_rect(Rect2(L - 30, m.edge, R - L + 60, 14), Color("0f1217"))
	draw_line(Vector2(L, m.edge), Vector2(R, m.edge), Color("f3c75a"), 2.0)
	# dropper rail + dropper
	draw_line(Vector2(L, m.back_wall - 18), Vector2(R, m.back_wall - 18), Color("2a313c"), 6.0)
	draw_rect(Rect2(dropper_x - 20, m.back_wall - 32, 40, 26), Color("c79a3d"))
	draw_dashed_line(Vector2(dropper_x, m.back_wall - 6), Vector2(dropper_x, m.drop_y - 18), Color(0.95, 0.78, 0.35, 0.35), 2.0, 6.0)
	draw_arc(Vector2(dropper_x, m.drop_y), 18, 0, TAU, 28, Color(0.95, 0.78, 0.35, 0.35), 1.5, true)
	# battlefield
	draw_rect(Rect2(0, lane.top - 30, 1600, lane.bottom - lane.top + 60), Color("15191e"))
	draw_rect(Rect2(900, lane.top - 30, 700, lane.bottom - lane.top + 60), Color(0.8, 0.2, 0.2, 0.06))
	draw_line(Vector2(0, lane.top - 30), Vector2(1600, lane.top - 30), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(lane.defense_x - 8, lane.top - 10, 6, lane.bottom - lane.top + 20), Color(0.95, 0.78, 0.35, 0.7))
	# drop chute from machine to lane
	draw_line(Vector2(L + 40, m.edge + 14), Vector2(170, lane.top - 30), Color(0.95, 0.78, 0.35, 0.08), 2.0)
	draw_line(Vector2(R - 40, m.edge + 14), Vector2(460, lane.top - 30), Color(0.95, 0.78, 0.35, 0.08), 2.0)

# ---------------------------------------------------------------- HUD
func _mk_label(pos: Vector2, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := 0.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if width > 0.0:
		l.size = Vector2(width, size * 1.6)
	hud.add_child(l)
	return l

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	lbl_wave = _mk_label(Vector2(40, 30), 30, Color("f1f2f4"))
	lbl_def = _mk_label(Vector2(1180, 30), 18, Color("cfd5de"))
	lbl_gold = _mk_label(Vector2(1180, 62), 24, Color("f3c75a"))
	lbl_coins = _mk_label(Vector2(40, 806), 26, Color("f1f2f4"))
	lbl_next = _mk_label(Vector2(40, 850), 16, Color("8b94a3"))
	lbl_army = _mk_label(Vector2(420, 816), 20, Color("cfd5de"))
	lbl_chain = _mk_label(Vector2(1060, 230), 40, Color("f3c75a"))
	lbl_center = _mk_label(Vector2(0, 410), 34, Color("f1f2f4"), HORIZONTAL_ALIGNMENT_CENTER, 1600)
	var hint := _mk_label(Vector2(1180, 850), 15, Color("8b94a3"))
	hint.text = "SPACE / 클릭 = 동전 넣기 (누르고 있으면 연속)   R = 재시작"

var center_left := 0.0
func _flash_center(text: String, secs: float) -> void:
	if lbl_center == null:
		return
	lbl_center.text = text
	center_left = secs

func _update_hud() -> void:
	if hud == null:
		return
	var w := battle.wave
	lbl_wave.text = "WAVE %02d / %d" % [w, int(cfg.waves.total)]
	lbl_def.text = "방어선  %d / %d" % [int(battle.defense_hp), int(cfg.defense_hp)]
	lbl_gold.text = "골드 %s" % gold
	lbl_coins.text = "남은 동전  %d" % coins_left
	lbl_next.text = "다음: %s" % ("폭발 동전" if next_drop_kind() == "bomb" else "동전")
	var counts := {}
	for u in battle.units:
		var key := "%s★%d" % [cfg.units[u.type].name, u.star]
		counts[key] = counts.get(key, 0) + 1
	var parts: PackedStringArray = []
	for key in counts:
		parts.append("%s ×%d" % [key, counts[key]])
	lbl_army.text = "내 군대   " + ("  ·  ".join(parts) if parts.size() > 0 else "아직 없음")
	if chain_show > 0.0:
		lbl_chain.text = "CHAIN ×%d" % shown_chain
		lbl_chain.modulate.a = clamp(chain_show / 0.4, 0.0, 1.0)
	else:
		lbl_chain.text = ""
	center_left -= get_process_delta_time()
	lbl_center.visible = center_left > 0.0
