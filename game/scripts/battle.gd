## The battle lane: our units fight waves of enemies automatically.
class_name Battle
extends Node2D

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal defeated
signal unit_merged(type: String, star: int)

var cfg: Dictionary
var main: Node = null
var wave := 0
var to_spawn := 0
var boss_pending := false
var spawn_timer := 0.0
var break_timer := 0.0
var in_break := true
var defense_hp := 100.0
var is_defeated := false
var is_victory := false
var units: Array[Fighter] = []
var enemies: Array[Fighter] = []
var enemies_killed := 0
var units_spawned := 0

func setup(p_cfg: Dictionary, p_main: Node) -> void:
	cfg = p_cfg
	main = p_main
	defense_hp = cfg.defense_hp
	break_timer = cfg.waves.break_seconds

func lane_y() -> float:
	return randf_range(cfg.lane.top + 20.0, cfg.lane.bottom - 20.0)

func spawn_unit(type: String, x: float) -> void:
	var f := Fighter.new()
	f.setup("unit", type, cfg.units[type])
	f.position = Vector2(x, lane_y())
	add_child(f)
	units.append(f)
	units_spawned += 1
	_try_merge(type)

func _try_merge(type: String) -> void:
	var need: int = cfg.merge.count
	for star in range(1, int(cfg.merge.max_star)):
		var group: Array[Fighter] = []
		for u in units:
			if u.type == type and u.star == star:
				group.append(u)
		if group.size() >= need:
			group.sort_custom(func(a, b): return a.position.x > b.position.x)
			var keep := group[0]
			for i in range(1, need):
				units.erase(group[i])
				group[i].queue_free()
			keep.apply_star(star + 1, cfg.merge.stat_mult)
			unit_merged.emit(type, star + 1)
			_try_merge(type)
			return

func _spawn_enemy(kind: String) -> void:
	var f := Fighter.new()
	var hp_mult: float = 1.0 + cfg.waves.hp_scale_per_wave * (wave - 1)
	f.setup("enemy", kind, cfg.enemies[kind], 1, hp_mult)
	f.position = Vector2(cfg.lane.enemy_spawn_x, lane_y())
	add_child(f)
	enemies.append(f)

func _start_wave() -> void:
	wave += 1
	in_break = false
	to_spawn = int(cfg.waves.base_count + cfg.waves.per_wave * (wave - 1))
	boss_pending = wave % int(cfg.waves.boss_every) == 0
	if boss_pending:
		to_spawn += 1
	spawn_timer = 0.0
	wave_started.emit(wave)

func _physics_process(delta: float) -> void:
	if is_defeated or is_victory:
		return
	# --- wave flow ---
	if in_break:
		break_timer -= delta
		if break_timer <= 0.0:
			_start_wave()
	else:
		spawn_timer -= delta
		if to_spawn > 0 and spawn_timer <= 0.0:
			if boss_pending and to_spawn == 1:
				_spawn_enemy("boss")
			else:
				_spawn_enemy("grunt")
			to_spawn -= 1
			spawn_timer = cfg.waves.spawn_interval
		if to_spawn == 0 and enemies.is_empty():
			in_break = true
			break_timer = cfg.waves.break_seconds
			wave_cleared.emit(wave)
			if wave >= int(cfg.waves.total):
				is_victory = true
				return
	# --- fighters ---
	for u in units:
		_act(u, enemies, delta)
	for e in enemies:
		_act(e, units, delta)
	# --- breaches and deaths ---
	for e in enemies.duplicate():
		if e.position.x <= cfg.lane.defense_x:
			defense_hp -= e.breach_damage
			enemies.erase(e)
			e.queue_free()
		elif e.hp <= 0.0:
			enemies.erase(e)
			enemies_killed += 1
			if main != null:
				main.gold += e.gold_reward
			e.queue_free()
	for u in units.duplicate():
		if u.hp <= 0.0:
			units.erase(u)
			u.queue_free()
	if defense_hp <= 0.0:
		defense_hp = 0.0
		is_defeated = true
		defeated.emit()

func _act(f: Fighter, foes: Array[Fighter], delta: float) -> void:
	f.cd_left -= delta
	var target: Fighter = null
	var best := INF
	for o in foes:
		var d := f.position.distance_to(o.position)
		if d < best:
			best = d
			target = o
	var reach := f.attack_range + (14.0 * (target.size if target else 1.0))
	if target and best <= reach:
		if f.cd_left <= 0.0:
			f.cd_left = f.cooldown
			if f.splash > 0.0:
				for o in foes:
					if o.position.distance_to(target.position) <= f.splash:
						o.take_hit(f.atk)
			else:
				target.take_hit(f.atk)
			f.flash_to = target.position
			f.flash_left = 0.1
		return
	# move
	var dir := 1.0 if f.team == "unit" else -1.0
	if f.team == "unit" and f.position.x >= cfg.lane.unit_max_x:
		return
	f.position.x += dir * f.speed * delta
	if target:
		f.position.y = move_toward(f.position.y, target.position.y, f.speed * 0.4 * delta)
