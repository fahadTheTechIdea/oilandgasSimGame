## Wind direction and strength.
##
## The weather state sets a target speed; the wind eases toward it and its
## direction wanders slowly, so rain/snow slant, clouds drift and the HUD can
## report a believable bearing. Deterministic and saveable.
class_name WindSystem
extends RefCounted

const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const ARROWS := ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]

var direction_deg := 45.0
var speed := 3.0        # metres per second
var _t := 0.0
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 4242) -> void:
	rng.seed = seed_value


## Advance by game hours toward a weather-driven target speed (m/s).
func advance(game_hours: float, target_speed: float) -> void:
	if game_hours <= 0.0:
		return
	_t += game_hours
	var wander := sin(_t * 0.35) * 2.2 + rng.randf_range(-1.0, 1.0)
	direction_deg = fposmod(direction_deg + wander, 360.0)
	speed = lerpf(speed, maxf(0.0, target_speed), clampf(game_hours * 0.25, 0.0, 1.0))


## Horizontal wind vector in world space (x, 0, z).
func vector() -> Vector3:
	var rad := deg_to_rad(direction_deg)
	return Vector3(sin(rad), 0.0, cos(rad)) * speed


func _octant() -> int:
	return int(round(fposmod(direction_deg, 360.0) / 45.0)) % 8


func compass() -> String:
	return COMPASS[_octant()]


func arrow() -> String:
	return ARROWS[_octant()]


func label() -> String:
	return "%s %s %d km/h" % [arrow(), compass(), int(round(speed * 3.6))]


func save_data() -> Dictionary:
	return {"dir": direction_deg, "speed": speed, "t": _t, "rng": rng.state}


func load_data(d: Dictionary) -> void:
	direction_deg = fposmod(float(d.get("dir", direction_deg)), 360.0)
	speed = maxf(0.0, float(d.get("speed", speed)))
	_t = float(d.get("t", _t))
	if d.has("rng"):
		rng.state = int(d["rng"])
