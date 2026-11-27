class_name Corridor
extends RefCounted
## The walking corridor: the strip of ground the knight walks along (and the second metre of air beside it for the
## sword arm and the shield) in which nothing may stand. A scene that knows where the knight will walk adds a lane
## before its place is built (`add`); the kit then asks `clear` for every piece it stands near a lane and is told
## where it may stand instead, or that it may not stand at all. What was moved is logged in `moves` (and printed by
## `report`), so what a walk changed is never a surprise. A lane is a line on the ground (x, z), not a volume:
## anything higher than HEAD above the ground is overhead and is let be (a span, a gantry, a leaning rib).

const HALF := 1.5          # metres either side of the line of travel that stay clear
const GAP := 0.3           # and a hand's breadth more between the corridor and whatever was moved out of it
const REMOVE_BEYOND := 4.5 # a piece that would have to move further than this is taken out instead
const HEAD := 3.0

static var lanes: Array = []     # [{a: Vector2, b: Vector2, half: float}]
static var moves: Array = []     # [{id, from, to, removed}]

static func reset() -> void:
	lanes.clear()
	moves.clear()

## A lane from `a` to `b` (ground points; y is ignored).
static func add(a: Vector3, b: Vector3, half: float = HALF) -> void:
	lanes.append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "half": half})

static func _nearest(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t

## How far a piece at `p` with this footprint radius is inside the nearest lane (positive: it intrudes).
static func intrusion(p: Vector3, radius: float) -> float:
	var worst := -1e9
	for l: Dictionary in lanes:
		var c := _nearest(Vector2(p.x, p.z), l.a, l.b)
		worst = maxf(worst, float(l.half) + radius - Vector2(p.x, p.z).distance_to(c))
	return worst

## Where a piece at `pos` with this footprint radius may stand: `pos` if it is clear, a point pushed sideways out of the
## lane if it is not, `Vector3.INF` if it has to go. `id` names it in the log.
static func clear(pos: Vector3, radius: float, id: String = "") -> Vector3:
	if lanes.is_empty():
		return pos
	var p := pos
	for pass_i in 3:
		var moved_now := false
		for l: Dictionary in lanes:
			var q := Vector2(p.x, p.z)
			var c := _nearest(q, l.a, l.b)
			var need := float(l.half) + radius + GAP
			var d := q.distance_to(c)
			if d >= need - GAP:
				continue
			var away := (q - c)
			if away.length() < 0.05:
				var ab: Vector2 = (l.b as Vector2) - (l.a as Vector2)
				away = Vector2(-ab.y, ab.x)
			away = away.normalized()
			q = c + away * need
			p = Vector3(q.x, p.y, q.y)
			moved_now = true
		if not moved_now:
			break
	if p.distance_to(pos) < 0.01:
		return pos
	if p.distance_to(pos) > REMOVE_BEYOND:
		moves.append({"id": id, "from": pos, "to": Vector3.INF, "removed": true})
		return Vector3.INF
	moves.append({"id": id, "from": pos, "to": p, "removed": false})
	return p

## A sideways offset from a road's middle line, pushed out so that a piece of this radius stands outside the corridor.
static func side(off: float, radius: float) -> float:
	var need := HALF + radius + GAP
	return off if absf(off) >= need else (need if off >= 0.0 else -need)

static func report() -> String:
	var out := "corridor: %d lane(s), %d piece(s) moved or removed" % [lanes.size(), moves.size()]
	for m: Dictionary in moves:
		out += "\n  %s %s" % [("removed" if m.removed else "moved"), str(m.id)]
		if not m.removed:
			out += "  (%.1f, %.1f) -> (%.1f, %.1f)" % [m.from.x, m.from.z, m.to.x, m.to.z]
		else:
			out += "  at (%.1f, %.1f)" % [m.from.x, m.from.z]
	return out
