class_name Approach
extends Node
## Arriving: the knight walks into the region's first stretch with the camera behind them, picking up the shot
## the Awakening ended on, and stops where the road's first stop begins. The place it builds is the place the road
## screen then uses (see Explore.adopted), so there is no cut, no rebuild and no loading screen between the two.

signal finished

const DIST := 11.0
const WALK := 1.35
const BEHIND := Vector3(0.75, 1.62, 3.3)
const AHEAD := Vector3(0.1, 1.3, -3.0)
const LAG := 0.8                 # how far the eased camera trails a walker at this pace
## Mid-walk the camera lifts and widens to show where the road leads, then comes back down to the walker's shoulder:
## it leaves the Awakening's framing and arrives at the road screen's, and in between the place is seen whole.
const RISE_POS := Vector3(1.1, 1.7, 2.6)
const RISE_LOOK := Vector3(-0.4, 0.9, -5.0)
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
	var k := sin(clampf(1.0 - p.length() / DIST, 0.0, 1.0) * PI)
	k *= k
	var lag := Vector3(0, 0, -LAG) if not snap else Vector3.ZERO
	backdrop.move_camera(p + _at(BEHIND + RISE_POS * k + lag), p + _at(AHEAD + RISE_LOOK * k + lag), snap)

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
