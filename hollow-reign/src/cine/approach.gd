class_name Approach
extends Node
## Arriving: the knight walks into the region's first stretch with the camera behind them, picking up the shot
## the Awakening ended on, and stops where the road's first stop begins. The place it builds is the place the road
## screen then uses (see Explore.adopted), so there is no cut, no rebuild and no loading screen between the two.

signal finished

const DIST := 8.0
const WALK := 1.35
const BEHIND := Vector3(0.75, 1.62, 3.3)
const AHEAD := Vector3(0.1, 1.3, -3.0)
const LAG := 0.8                 # how far the eased camera trails a walker at this pace
const HOLD_FOR_SPEECH := 14.0    # at most this long standing at the end while a line finishes

var backdrop: Backdrop
var angle := 0.0
var _walking := true
var _over := false
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
	_track(true)
	Sfx.ambience(str(region.amb))
	Sfx.music_for("explore_" + str(region.id), "menu", 2.5)
	_tw = create_tween()
	_tw.tween_property(rig, "position", Vector3.ZERO, DIST / WALK)
	_tw.tween_callback(_arrive)

func _at(v: Vector3) -> Vector3:
	return v.rotated(Vector3.UP, angle)

func _track(snap: bool = false) -> void:
	var p := backdrop.rig.position
	backdrop.move_camera(p + _at(BEHIND + (Vector3(0, 0, -LAG) if not snap else Vector3.ZERO)), p + _at(AHEAD + (Vector3(0, 0, -LAG) if not snap else Vector3.ZERO)), snap)

func _process(_dt: float) -> void:
	if _walking and not _over:
		_track()

## The walk is done: the camera settles to the road screen's own view while any line still being spoken ends.
func _arrive() -> void:
	_walking = false
	backdrop.rig.walking = false
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
	backdrop.move_camera(_at(Explore.CAM_POS), _at(Explore.CAM_LOOK), true)
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	finished.emit()
