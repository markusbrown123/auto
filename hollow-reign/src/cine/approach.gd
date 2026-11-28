class_name Approach
extends Node
## Arriving: the knight walks into the region's first stretch, and stops where the road's first stop begins. The
## place it builds is the place the road screen then uses (see Explore.adopted), so there is no cut, no rebuild and
## no loading screen between the two.
##
## It is filmed as a route, in three shots, and what is waiting on the road is shown on purpose:
##   1  behind the knight, out of the white: the framing the Awakening ended on, so the two join on the walk
##   2  from low on the road ahead, looking back up it: the knight coming on, the place they have come out of behind
##   3  over the knight's shoulder on a long lens: whoever stands on the way onward, in the haze, turned to face them
## and then the camera settles to the road screen's own view. The foe in shot 3 stands exactly where the road screen
## will stand its own (the same marker, the same look), so when that screen takes the place over the figure does not
## move.

signal finished

const DIST := 11.0
const WALK := FighterRig.ROAD_SPEED
const BEHIND := Vector3(0.35, 1.62, 3.3)       # (Stage 4: at 0.75 across, the roadside posts went by a hand from the lens)
const AHEAD := Vector3(0.1, 1.3, -3.0)
const LAG := 0.66                # how far the eased camera trails a walker at this pace
## Where each shot begins, as how much of the walk is done (shot 1 starts at 0).
const CUT_BACK := 0.3
const CUT_REVEAL := 0.62
const HOLD_FOR_SPEECH := 14.0    # at most this long standing at the end while a line finishes

var backdrop: Backdrop
var angle := 0.0
var foe: FighterRig              # who waits on the first way onward, if it is a fight
var _walking := true
var _over := false
var _shot := 0
var _tw: Tween

func _ready() -> void:
	var region := Game.run_region()
	angle = Explore.bearing(int(Game.run.stage))
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build(region.theme)
	var rig := backdrop.rig
	rig.position = _at(Vector3(0, 0, DIST))
	rig.rotation.y = angle
	rig.walking = true
	rig.footsteps = true
	_stand_foe()
	_track(true)
	Sfx.ambience(str(region.amb))
	Sfx.music_for("explore_" + str(region.id), "menu", 2.5)
	_tw = create_tween()
	_tw.tween_property(rig, "position", Vector3.ZERO, FighterRig.road_time(DIST))
	_tw.tween_callback(_arrive)

func _at(v: Vector3) -> Vector3:
	return v.rotated(Vector3.UP, angle)

## Whoever the first fight on the way onward is against stands at its marker, as the road screen will stand them
## (Explore._stand_foe: the marker's place, 1.6 m beyond it, turned to the knight). Ours is not a child of the place,
## so it goes when this scene does, in the frame the road screen puts its own there.
func _stand_foe() -> void:
	var opts: Array = Game.stage_options()
	for i in opts.size():
		var o: Dictionary = opts[i]
		if str(o.get("type", "")) != "fight" or not o.has("foe") or not Db.foes.has(str(o.foe)):
			continue
		if str(Db.foes[str(o.foe)].rig.get("kind", "")) == "dragon":
			continue
		var x := (float(i) - (opts.size() - 1) * 0.5) * 3.2
		foe = FighterRig.new()
		add_child(foe)
		foe.build(CineActor.foe_look(str(o.foe)), true)
		foe.position = _at(Vector3(x - 0.3, 0, -4.6 - 1.6))
		foe.rotation.y = angle + PI
		foe.time_scale = 0.6
		return

func _track(snap: bool = false) -> void:
	var p := backdrop.rig.position
	var done := clampf(1.0 - p.length() / DIST, 0.0, 1.0)
	var want := 0
	if done >= CUT_REVEAL and foe != null:
		want = 2
	elif done >= CUT_BACK and done < CUT_REVEAL:
		want = 1
	var cut := snap or want != _shot
	_shot = want
	match want:
		0:
			# behind them, as the Awakening left them; it lifts a little as the place opens
			var lag := Vector3(0, 0, -LAG) if not cut else Vector3.ZERO
			var rise := smoothstep(0.0, CUT_BACK, done)
			backdrop.cam_fov = 50.0
			backdrop.move_camera(p + _at(BEHIND + Vector3(0.0, 0.25, 0.3) * rise + lag), p + _at(AHEAD + Vector3(-0.2, 0.3, -2.0) * rise + lag), cut)
		1:
			# low on the road ahead of them, looking back: the walker comes on down the middle of the frame
			var along := smoothstep(CUT_BACK, CUT_REVEAL, done)
			backdrop.cam_fov = 44.0
			backdrop.move_camera(_at(Vector3(-1.9 + 0.5 * along, 0.5, 1.6 - 0.8 * along)), p + _at(Vector3(0.0, 1.15, 0.0)), cut)
		2:
			# over the shoulder, long: the one who is waiting
			var push := smoothstep(CUT_REVEAL, 1.0, done)
			backdrop.cam_fov = lerpf(34.0, 30.0, push)
			backdrop.move_camera(p + _at(Vector3(0.95, 1.5, 2.9 - 0.3 * push)), foe.position + Vector3(0, 1.25 * foe.scale.y, 0) + _at(Vector3(-0.5, 0, 0)), cut)

func _process(_dt: float) -> void:
	if _walking and not _over:
		_track()

## The walk is done: the camera settles to the road screen's own view while any line still being spoken ends.
func _arrive() -> void:
	_walking = false
	backdrop.rig.walking = false
	backdrop.cam_fov = 50.0
	backdrop.move_camera(_at(Explore.CAM_POS), _at(Explore.CAM_LOOK))
	var left := HOLD_FOR_SPEECH
	while Story.busy and left > 0.0 and not _over:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_end()

func skip() -> void:
	if _over:
		return
	if _tw:
		_tw.kill()
	Story.stop()
	_walking = false
	backdrop.rig.position = Vector3.ZERO
	backdrop.rig.walking = false
	backdrop.cam_fov = 50.0
	backdrop.move_camera(_at(Explore.CAM_POS), _at(Explore.CAM_LOOK), true)
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	finished.emit()
