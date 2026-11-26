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
## The walker stands thirty metres up the road (the menu puts the player's knight there too): the camera is behind
## their sword shoulder, close enough that they stand a third of the frame high, and looks a little left of the way
## the road runs, so the figure is in the middle of the frame, the Ring-Gate is over their right shoulder and the
## left of the picture is open sky for the game's name.
const VISTA_S := 30.0
static func vista() -> Array:
	var h := Highland.road(VISTA_S)
	var yaw := Highland.road_yaw(VISTA_S)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(-fwd.z, 0, fwd.x)
	var eye := h - fwd * 9.0 + right * 1.6 + Vector3(0, 1.55, 0)
	var look := Basis(Vector3.UP, deg_to_rad(11.0)) * fwd
	return [eye, eye + look * 100.0 + Vector3(0, 5.0, 0), 32.0]

## One designed shot. Each puts the walker on his stretch of road and frames it.
func shot(i: int) -> void:
	match i:
		1:  # the vista: the walker in the foreground, the road ahead of them, and the Ring-Gate on the heights
			stand(VISTA_S)
			var v := vista()
			cam.follow = null
			cam.cut(v[0], v[1], v[2])
			cam.move(v[0] + Vector3(0.3, 0.5, -1.6), v[1] + Vector3(0.0, 1.5, 0.0), 14.0)
		2:  # low, through the grass, beside them: the cliff's edge, the sea and the light beyond
			stride(118.0, 134.0)
			cam.ride(hero, Vector3(-3.3, 0.72, -2.1), Vector3(0.2, 1.2, -0.6))
			cam.fov = 42.0
		3:  # the climb: in profile on a leg of the switchback, the slope folding up behind and the ring over it
			var s3 := Highland.road_at_z(196.0)
			stride(s3 - 20.0, s3 - 6.0)
			cam.ride(hero, Vector3(-6.6, 0.9, -1.2), Vector3(5.0, 3.4, -2.4))
			cam.fov = 44.0
		4:  # over the shoulder, topping the rise: the gate's foot comes up out of the ground
			var s4 := Highland.road_at_z(108.0)
			stride(s4 - 12.0, s4 + 3.0)
			cam.ride(hero, Vector3(0.85, 1.2, 3.1), Vector3(-0.3, 2.5, -8.0))
			cam.fov = 44.0
		5:  # passing the dead tree: from low behind them, the tree going by and the ring filling the sky
			var s5 := Highland.tree_s()
			stride(s5 - 9.0, s5 + 4.0)
			cam.ride(hero, Vector3(2.3, 0.7, 5.6), Vector3(-1.6, 3.6, -8.0))
			cam.fov = 44.0
		6:  # arrival: the court between the ring's feet, and the shut gate
			var s6 := Highland.road_at_z(24.0)
			stride(s6, Highland.road_length())
			cam.follow = null
			cam.cut(Vector3(3.2, 1.45, 31.5), Vector3(-0.6, 6.2, -21.0), 40.0)
			cam.move(Vector3(2.4, 1.8, 17.5), Vector3(-0.4, 6.8, -21.0), 13.0)
