## Headless test runner.
## Run: godot --headless --path game --fixed-fps 60 -s tests/run_tests.gd
extends SceneTree

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		failures += 1
		print("FAIL  ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	var MainScript = load("res://scripts/main.gd")
	var cfg: Dictionary = MainScript.load_balance()
	check(cfg.has("units") and cfg.has("enemies") and cfg.has("machine"), "balance.json loads with required sections")

	# --- merge rules ---
	var b := Battle.new()
	root.add_child(b)
	b.setup(cfg, null)
	for i in 3:
		b.spawn_unit("sword", 200.0)
	check(b.units.size() == 1 and b.units[0].star == 2, "3 swords merge into one 2-star sword")
	var hp2: float = b.units[0].max_hp
	check(is_equal_approx(hp2, cfg.units.sword.hp * cfg.merge.stat_mult), "2-star sword gets stat multiplier")
	for i in 6:
		b.spawn_unit("sword", 200.0)
	check(b.units.size() == 1 and b.units[0].star == 3, "9 swords merge into one 3-star sword")
	b.spawn_unit("bow", 200.0)
	b.spawn_unit("bow", 200.0)
	check(b.units.size() == 3, "different types and incomplete sets do not merge")
	b.queue_free()

	# --- full game simulation ---
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var start_bodies: int = main.body_count()
	check(start_bodies > 80 and start_bodies <= int(cfg.pieces.max_bodies), "table starts filled (%d bodies, max %d)" % [start_bodies, cfg.pieces.max_bodies])
	await _frames(int(60 * cfg.pieces.warmup_seconds) + 10)
	var start_coins: int = main.coins_left
	check(main.drop(), "drop() works with coins left")
	check(main.coins_left == start_coins - 1, "drop() spends one coin")
	for i in 40:
		main.drop()
		await _frames(12)
	await _frames(60 * 45)
	check(main.coins_fallen > 0 and main.gold > 0, "coins pushed off the edge give gold (fell %d, gold %d)" % [main.coins_fallen, main.gold])
	check(main.figures_fallen > 0 and main.battle.units_spawned > 0, "figures pushed off the edge become units (%d)" % main.figures_fallen)
	check(main.battle.wave >= 2, "waves progress (wave %d)" % main.battle.wave)
	check(main.battle.enemies_killed > 0, "units kill enemies (%d)" % main.battle.enemies_killed)
	check(main.body_count() <= int(cfg.pieces.max_bodies), "body count stays within limit (%d)" % main.body_count())
	var stray := 0
	for p in main.table.get_children():
		if p.position.x < cfg.machine.left - 5 or p.position.x > cfg.machine.right + 5:
			stray += 1
	check(stray == 0, "no pieces escape through the side walls")

	# --- no coins: button does nothing ---
	main.coins_left = 0
	check(not main.drop(), "drop() refuses when out of coins")

	print("")
	print("RESULT: %d failure(s)" % failures)
	quit(failures)
