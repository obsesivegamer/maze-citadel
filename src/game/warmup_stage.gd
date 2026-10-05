class_name WarmupStage
extends Game
## A throwaway rehearsal behind the loading screen: its own sim holding every
## tower at every level and every creep type, fighting for a moment, drawn by
## its own Units and Fx. Every shader and pipeline a match needs compiles here
## instead of mid-wave (exports made without the shader baker compile them on
## first use, which froze wave 1). Sound, HUD and the real board never see it:
## those listen to the host Game's signals, not this stage's.

const FRAMES := 75
const STEPS_PER_FRAME := 2
const TOWER_ROWS: Array[int] = [8, 10, 12, 14]
const CREEP_ROWS: Array[int] = [9, 11, 13]
const CREEP_WAVE := 10


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


## Stages the battle, renders FRAMES frames of it while reporting 0..1
## progress, then frees itself.
func run(host: Game, progress: Callable) -> void:
	camera = host.camera
	quality = host.quality
	quality_settings = host.quality_settings
	sim.countdown = -1.0
	sim.interest_timer = INF
	# The staging below is laid out for classic ranges; under adjacent reach
	# some towers would never fire and their effects would compile mid-match.
	sim.rules = &"classic"
	units = Units.new()
	add_child(units)
	units.setup(self)
	fx = Fx.new()
	add_child(fx)
	fx.setup(self)
	_stage_towers()
	_stage_creeps()
	_flush()
	for frame in FRAMES:
		for i in STEPS_PER_FRAME:
			sim.step()
			_flush()
		units.sync(1.0)
		progress.call(float(frame + 1) / FRAMES)
		await get_tree().process_frame
	queue_free()


func _stage_towers() -> void:
	var entries: Array = []
	for id in TowerDefs.BUILD_ORDER:
		for level in range(1, TowerDefs.MAX_LEVEL + 1):
			entries.append([id, level])
	for id in TowerDefs.EPICS:
		entries.append([id, 1])
	var per_row := ceili(entries.size() / float(TOWER_ROWS.size()))
	for i in entries.size():
		var tile := Vector2i(2 + (i % per_row) * 2, TOWER_ROWS[i / per_row])
		var t := SimTower.new()
		t.id = entries[i][0]
		t.level = entries[i][1]
		t.tile = tile
		t.pos = Grid.center(tile)
		sim.towers[tile] = t
		sim.grid.set_blocked(tile, true)
		sim.events.append({"type": &"built", "tile": tile, "id": t.id})


## One of every creep, parked between the tower rows so every attack, status
## and death effect plays. Ability timers are shortened so Steam Tank
## immunity, Priestess heals and Dreadlord summons all fire in time.
func _stage_creeps() -> void:
	# The Guardian is the Ogre drawn larger: the Ogre compiles its shaders.
	var types: Array = CreepDefs.CREEPS.keys()
	types.erase(&"guardian")
	var k := 0
	for row in CREEP_ROWS:
		for col in range(2, Grid.COLS - 2, 2):
			var type: StringName = types[k % types.size()]
			var element: StringName = Damage.WHEEL[k % Damage.WHEEL.size()]
			var c := sim.spawn_creep(type, element, CREEP_WAVE, Grid.center(Vector2i(col, row)))
			c.speed = 0.0
			c.ability_timer = 0.3
			k += 1
