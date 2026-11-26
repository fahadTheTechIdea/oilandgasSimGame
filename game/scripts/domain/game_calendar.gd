## In-game calendar and clock.
##
## Time is stored as a single float of elapsed game days, so it survives
## save/load cheaply and can be advanced at any speed multiplier. A day is
## `day_seconds` real seconds at 1×; the default 180 s means a 28-day month is
## about 84 real minutes at 1× (and ~10 minutes at 8×).
class_name GameCalendar
extends RefCounted

const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const SEASON_NAMES := ["Winter", "Spring", "Summer", "Autumn"]

var day_seconds := 180.0
var days_per_month := 28
var months_per_year := 12
var total_days := 0.0


func _init(seconds_per_day: float = 180.0, initial_hour: float = 8.0) -> void:
	day_seconds = maxf(10.0, seconds_per_day)
	# start in daylight, never at midnight
	total_days = clampf(initial_hour, 0.0, 23.99) / 24.0


## Advance by real seconds (already multiplied by the game speed).
func advance(real_seconds: float) -> void:
	if real_seconds > 0.0:
		total_days += real_seconds / day_seconds


func day_index() -> int:
	return int(floor(total_days))


func days_per_year() -> int:
	return days_per_month * months_per_year


func year() -> int:
	return day_index() / days_per_year() + 1


func day_of_year() -> int:
	return day_index() % days_per_year()


func month() -> int:
	return day_of_year() / days_per_month + 1


func day() -> int:
	return day_of_year() % days_per_month + 1


## 0..24 with a fractional part.
func hour_float() -> float:
	return (total_days - floor(total_days)) * 24.0


func hour() -> int:
	return int(floor(hour_float()))


func minute() -> int:
	return int(floor((hour_float() - float(hour())) * 60.0))


## 0 Winter, 1 Spring, 2 Summer, 3 Autumn (northern-hemisphere months).
func season() -> int:
	var m := month()
	if m == 12 or m <= 2:
		return 0
	if m <= 5:
		return 1
	if m <= 8:
		return 2
	return 3


func season_name() -> String:
	return SEASON_NAMES[season()]


## 0 at night, 1 at solar noon, smooth through dawn and dusk.
func daylight() -> float:
	var h := hour_float()
	if h < 5.0 or h > 21.0:
		return 0.0
	return clampf(sin((h - 5.0) / 16.0 * PI), 0.0, 1.0)


## Directional-light rotation for the current hour. The sun rises in the east
## (yaw -90°) at 06:00, peaks at solar noon and sets in the west at 18:00.
func sun_rotation_deg() -> Vector3:
	var t := clampf((hour_float() - 6.0) / 12.0, 0.0, 1.0)
	var elevation := sin(t * PI) * 74.0
	var yaw := lerpf(-90.0, 90.0, t)
	return Vector3(-elevation, yaw, 0.0)


func date_label() -> String:
	return "Y%d %s %d" % [year(), MONTH_NAMES[month() - 1], day()]


func clock_label() -> String:
	return "%02d:%02d" % [hour(), minute()]


func full_label() -> String:
	return "%s · %s" % [date_label(), clock_label()]


func save_data() -> Dictionary:
	return {"total_days": total_days, "day_seconds": day_seconds}


func load_data(d: Dictionary) -> void:
	total_days = maxf(0.0, float(d.get("total_days", total_days)))
	day_seconds = maxf(10.0, float(d.get("day_seconds", day_seconds)))
