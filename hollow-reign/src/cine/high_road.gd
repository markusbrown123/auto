class_name HighRoad
extends Node3D
## The high road as a film set: the place (Highland, in one generation's state), a camera, one walker, and the
## six designed shots of the climb. The prologue, the time jump and the heir's arrival are all filmed on it, so the
## same compositions come back in every generation with what is in them changed.

const WALK := 1.38
## How long each shot is worth, in seconds (index = shot).
const HOLD := [0.0, 11.0, 9.5, 9.0, 10.5, 7.5, 9.0]

var arena: Arena
var cam: CineCam
var hero: CineActor
var gen := 1
var s := 0.0                      # where the walker is on the road, metres from its foot
var on_road := false

func setup(generation: int) -> void:
	gen = generation
	arena = Arena.new()
	add_child(arena)
	arena.build("highland")
	Highland.generation(arena, gen)
	cam = CineCam.new()
	add_child(cam)
	cam.far = 6000.0
	cam.drift = 0.03
	Sfx.ambience("wind")

func walker(look: Dictionary) -> CineActor:
	hero = CineActor.new()
	add_child(hero)
	hero.build(look, false)
	hero.footsteps = true
	return hero

## Sets the walker going along the road from `a` to `b`.
func stride(a: float, b: float) -> void:
	s = a
	on_road = true
	hero.walking = true
	_place()
	create_tween().tween_property(self, "s", b, absf(b - a) / WALK)

func stand(at: float) -> void:
	s = at
	on_road = true
	hero.walking = false
	_place()

func _place() -> void:
	hero.position = Highland.road(s)
	hero.rotation.y = Highland.road_yaw(s)

func _process(_delta: float) -> void:
	if on_road and hero:
		_place()
	Highland.follow(arena, cam.global_position)

## The one composition that comes back in every generation: [camera, what it looks at, field of view].
static func vista() -> Array:
	var h := Highland.road(30.0)
	return [Highland.on_ground(h.x + 8.0, h.z + 34.0, 4.2), Vector3(-80.0, -14.0, 0.0), 27.0]

## One designed shot. Each puts the walker on his stretch of road and frames it.
func shot(i: int) -> void:
	match i:
		1:  # the vista: a small figure, the road ahead, and the Ring-Gate on the heights with the sun beside it
			stand(30.0)
			var v := vista()
			cam.follow = null
			cam.cut(v[0], v[1], v[2])
			cam.move(v[0] + Vector3(-1.0, 0.5, -6.0), v[1] + Vector3(4.0, 2.0, 0.0), 14.0)
		2:  # low, through the grass, beside him: the sea and the light beyond
			stride(118.0, 134.0)
			cam.ride(hero, Vector3(-4.8, 0.62, -2.4), Vector3(0.0, 1.25, -1.0))
			cam.fov = 40.0
		3:  # the climb, whole: the road folding up the slope, the walker small on it, the ring above
			var s3 := Highland.road_at_z(196.0)
			stride(s3 - 20.0, s3 - 6.0)
			var eye := Highland.on_ground(-64.0, 262.0, 9.0)
			cam.follow = null
			cam.cut(eye, Vector3(4.0, -16.0, 150.0), 38.0)
			cam.move(eye + Vector3(3.0, 1.0, -4.0), Vector3(4.0, -14.0, 150.0), 9.0)
		4:  # over the shoulder, topping the rise: the gate's foot comes up out of the ground
			var s4 := Highland.road_at_z(108.0)
			stride(s4 - 12.0, s4 + 3.0)
			cam.ride(hero, Vector3(0.62, 0.95, 2.5), Vector3(-0.25, 2.3, -8.0))
			cam.fov = 44.0
		5:  # passing the dead tree, the ring filling the sky behind it
			var s5 := Highland.tree_s()
			stride(s5 - 7.0, s5 + 5.0)
			var t := Highland.road(s5, -5.5)
			var low := Highland.on_ground(t.x - 5.5, t.z + 12.0, 0.7)
			cam.follow = null
			cam.cut(low, t + Vector3(3.5, 7.0, -16.0), 46.0)
			cam.move(low + Vector3(1.2, 0.15, -0.8), t + Vector3(3.5, 7.4, -16.0), 9.0)
		6:  # arrival: the court between the ring's feet, and the shut gate
			var s6 := Highland.road_at_z(30.0)
			stride(s6, Highland.road_length())
			cam.follow = null
			cam.cut(Vector3(8.5, 5.4, 36.0), Vector3(-1.0, 5.5, -12.0), 44.0)
			cam.move(Vector3(6.5, 3.6, 28.0), Vector3(-1.0, 6.5, -12.0), 12.0)
