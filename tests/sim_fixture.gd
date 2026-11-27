## Helpers for building sim worlds in tests.
class_name SimFixture
extends RefCounted


## Flat open field (all FIELD, height 0) of w×h cells.
static func flat_grid(w: int, h: int) -> SimGrid:
	var g: SimGrid = SimGrid.new(w, h)
	g.rebuild_sectors()
	return g


## World with two players on teams 0 and 1.
static func world(grid: SimGrid, seed_value: int = 1) -> SimWorld:
	var w: SimWorld = SimWorld.new(seed_value, DefLoader.load_default(), grid)
	w.add_player(0)
	w.add_player(1)
	return w


static func spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int, heading: int = 0) -> int:
	return w.spawn_unit(w.defs.unit(def_id), w.team_of_player(player), player, x_m * 1000, y_m * 1000, heading)


static func cmd(c: SimCommand, w: SimWorld, player: int, seq: int = 0) -> SimCommand:
	c.player_id = player
	c.sequence = seq
	c.tick = w.tick
	w.queue_command(c)
	return c


static func run(w: SimWorld, ticks: int) -> void:
	for i: int in range(ticks):
		w.step()


static var _map_cache: Dictionary = {}


## Cached procedural 4×4 km map (500×500 cells) — grid is immutable during a match.
static func test_map(seed_value: int = 7) -> SimGrid:
	if not _map_cache.has(seed_value):
		_map_cache[seed_value] = MapGen.generate(seed_value, 500, 500)
	return _map_cache[seed_value]
