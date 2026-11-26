## Connected weather model.
##
## One set of physical drivers — temperature, pressure, humidity, cloud cover,
## precipitation and fog — is advanced every tick. Everything else derives from
## those drivers:
##   * rain vs snow comes from precipitation + temperature
##   * wind target comes from the pressure deficit + precipitation
##   * sunlight comes from cloud/fog/precipitation
##   * production and logistics come from rain/snow/fog/temperature/pressure
##   * the screen overlay and cloud shadows read cloud/rain/snow/wind
## A small regime state machine (clear/cloudy/rain/storm/fog/heatwave/snow)
## picks seasonal targets; the drivers ease toward them, so weather feels like a
## system rather than a set of switches.
class_name WeatherSystem
extends RefCounted

enum State { CLEAR, CLOUDY, RAIN, STORM, FOG, HEATWAVE, SNOW }

const NAMES := ["Clear", "Cloudy", "Rain", "Storm", "Fog", "Heatwave", "Snow"]

var state: int = State.CLEAR
var timer_hours: float = 0.75
var rng := RandomNumberGenerator.new()

# connected drivers
var temperature_c := 18.0
var pressure_hpa := 1015.0
var humidity := 0.40
var cloud := 0.03
var precipitation := 0.0
var rain := 0.0
var snow := 0.0
var fog := 0.0


func _init(seed_value: int = 20261125) -> void:
	rng.seed = seed_value


func state_name() -> String:
	return NAMES[clampi(state, 0, NAMES.size() - 1)]


## Snap the drivers to a season/regime so a fresh game does not start at 18 °C
## in winter while the fields catch up.
func initialize(season: int, daylight: float) -> void:
	temperature_c = _season_base(season) + (daylight - 0.5) * 8.0
	_snap_drivers()
	_derive_precipitation()


## Force a named state (used by `--weather=` demo/debug launches).
## Returns false when the name is unknown so callers can report it.
func set_by_name(name: String) -> bool:
	var needle := name.strip_edges().to_lower()
	if needle.is_empty():
		return false
	for i in NAMES.size():
		if NAMES[i].to_lower() == needle:
			state = i
			timer_hours = 1.0
			temperature_c = _preview_temperature(i)
			_snap_drivers()
			_derive_precipitation()
			return true
	return false


func advance(game_hours: float, season: int, daylight: float) -> bool:
	if game_hours <= 0.0:
		return false
	_update_temperature(season, daylight, game_hours)
	timer_hours -= game_hours
	var changed := false
	if timer_hours <= 0.0:
		_pick(season)
		changed = true
	_ease_toward_state(game_hours)
	_derive_precipitation()
	return changed


func _season_base(season: int) -> float:
	match clampi(season, 0, 3):
		0:
			return -1.0
		1:
			return 12.0
		2:
			return 26.0
		_:
			return 13.0


func _state_temp_offset() -> float:
	match state:
		State.CLEAR:
			return 2.0
		State.CLOUDY:
			return 0.0
		State.RAIN:
			return -3.0
		State.STORM:
			return -5.0
		State.FOG:
			return -2.0
		State.HEATWAVE:
			return 8.0
		State.SNOW:
			return -4.0
	return 0.0


func _update_temperature(season: int, daylight: float, hours: float) -> void:
	var target := _season_base(season) + _state_temp_offset() + (daylight - 0.5) * 6.0
	temperature_c = clampf(lerpf(temperature_c, target,
		clampf(hours / 6.0, 0.0, 1.0)), -40.0, 55.0)


## Targets for the drivers, per regime.
func _targets(s: int) -> Dictionary:
	match clampi(s, 0, 6):
		0:  # clear
			return {"cloud": 0.03, "hum": 0.35, "press": 1018.0, "fog": 0.0, "precip": 0.0}
		1:  # cloudy
			return {"cloud": 0.62, "hum": 0.55, "press": 1010.0, "fog": 0.0, "precip": 0.0}
		2:  # rain
			return {"cloud": 0.90, "hum": 0.85, "press": 1002.0, "fog": 0.05, "precip": 1.0}
		3:  # storm
			return {"cloud": 1.00, "hum": 0.95, "press": 988.0, "fog": 0.0, "precip": 1.5}
		4:  # fog
			return {"cloud": 0.82, "hum": 0.95, "press": 1012.0, "fog": 0.90, "precip": 0.0}
		5:  # heatwave
			return {"cloud": 0.08, "hum": 0.25, "press": 1022.0, "fog": 0.0, "precip": 0.0}
		_:  # snow
			return {"cloud": 0.90, "hum": 0.80, "press": 1005.0, "fog": 0.10, "precip": 0.9}


func _snap_drivers() -> void:
	var t := _targets(state)
	cloud = float(t.cloud)
	humidity = float(t.hum)
	pressure_hpa = float(t.press)
	fog = float(t.fog)
	precipitation = float(t.precip)


func _ease_toward_state(hours: float) -> void:
	var t := _targets(state)
	var k := clampf(hours / 5.0, 0.0, 1.0)
	cloud = clampf(lerpf(cloud, float(t.cloud), k), 0.0, 1.0)
	humidity = clampf(lerpf(humidity, float(t.hum), k), 0.0, 1.0)
	pressure_hpa = clampf(lerpf(pressure_hpa, float(t.press), k), 950.0, 1050.0)
	fog = clampf(lerpf(fog, float(t.fog), k), 0.0, 1.0)
	precipitation = clampf(lerpf(precipitation, float(t.precip), k), 0.0, 1.6)


## Rain vs snow is a consequence of temperature; not a separate switch.
func _derive_precipitation() -> void:
	precipitation = clampf(precipitation, 0.0, 1.6)
	if temperature_c <= 2.5:
		snow = clampf(precipitation, 0.0, 1.2)
		rain = 0.0
	else:
		rain = clampf(precipitation, 0.0, 1.6)
		snow = 0.0


func _pick(season: int) -> void:
	var table := _seasonal_weights(season)
	var total := 0.0
	for w in table.values():
		total += float(w)
	var roll := rng.randf() * total
	var acc := 0.0
	for key in table.keys():
		acc += float(table[key])
		if roll <= acc:
			state = int(key)
			break
	timer_hours = rng.randf_range(0.5, 1.5)


func _seasonal_weights(season: int) -> Dictionary:
	match clampi(season, 0, 3):
		0:  # Winter
			return {State.CLEAR: 28, State.CLOUDY: 20, State.SNOW: 34,
				State.FOG: 12, State.STORM: 6}
		1:  # Spring
			return {State.CLEAR: 30, State.CLOUDY: 24, State.RAIN: 30,
				State.STORM: 8, State.FOG: 8}
		2:  # Summer
			return {State.CLEAR: 44, State.CLOUDY: 15, State.RAIN: 10,
				State.STORM: 6, State.HEATWAVE: 25}
		_:  # Autumn
			return {State.CLEAR: 30, State.CLOUDY: 20, State.RAIN: 25,
				State.STORM: 12, State.FOG: 13}


func _preview_temperature(s: int) -> float:
	match clampi(s, 0, 6):
		6:
			return -2.0
		5:
			return 34.0
		3:
			return 8.0
		2:
			return 11.0
		4:
			return 5.0
		1:
			return 14.0
	return 20.0


func cloud_cover() -> float:
	return clampf(cloud, 0.0, 1.0)


func rain_intensity() -> float:
	return clampf(rain, 0.0, 1.6)


func snow_intensity() -> float:
	return clampf(snow, 0.0, 1.2)


func fog_intensity() -> float:
	return clampf(fog, 0.0, 1.0)


## Sunlight after cloud, fog and precipitation.
func solar_factor() -> float:
	var s := 1.0 - cloud * 0.65 - fog * 0.25 - rain * 0.15 - snow * 0.10
	return clampf(s, 0.15, 1.15)


## Pressure deficit stands in for wind/storm energy when deriving modifiers.
func _pressure_deficit() -> float:
	return maxf(0.0, 1013.0 - pressure_hpa)


func wind_target_ms() -> float:
	return clampf(2.0 + _pressure_deficit() * 0.32 + precipitation * 2.2, 0.5, 20.0)


func production_factor() -> float:
	var f := 1.0
	f -= rain * 0.08
	f -= snow * 0.12
	f -= fog * 0.05
	f -= maxf(0.0, absf(temperature_c - 18.0) - 16.0) * 0.008
	f -= _pressure_deficit() * 0.004
	return clampf(f, 0.62, 1.05)


func logistics_factor() -> float:
	var f := 1.0
	f -= rain * 0.10
	f -= snow * 0.16
	f -= fog * 0.12
	f -= _pressure_deficit() * 0.006
	return clampf(f, 0.50, 1.0)


func describe() -> String:
	var parts: Array[String] = []
	var p := int(round((production_factor() - 1.0) * 100.0))
	var l := int(round((logistics_factor() - 1.0) * 100.0))
	if p != 0:
		parts.append("prod %+d%%" % p)
	if l != 0:
		parts.append("logi %+d%%" % l)
	var head := "%s %.0f°C" % [state_name(), temperature_c]
	if parts.is_empty():
		return head
	return "%s · %s" % [head, ", ".join(parts)]


## Compact string for the HUD chip.
func hud_label() -> String:
	var worst := mini(int(round((production_factor() - 1.0) * 100.0)),
		int(round((logistics_factor() - 1.0) * 100.0)))
	if worst == 0:
		return "%s %.0f°C" % [state_name(), temperature_c]
	return "%s %.0f°C %+d%%" % [state_name(), temperature_c, worst]


func severity_color() -> Color:
	match state:
		State.STORM, State.SNOW:
			return Color(1.0, 0.55, 0.40)
		State.RAIN, State.FOG:
			return Color(0.75, 0.86, 1.0)
		State.HEATWAVE:
			return Color(1.0, 0.72, 0.35)
		State.CLOUDY:
			return Color(0.78, 0.82, 0.84)
	return Color(0.78, 0.94, 0.70)


func save_data() -> Dictionary:
	return {
		"state": state, "timer": timer_hours, "rng": rng.state,
		"temp": temperature_c, "pressure": pressure_hpa, "humidity": humidity,
		"cloud": cloud, "precip": precipitation, "fog": fog,
	}


func load_data(d: Dictionary) -> void:
	state = clampi(int(d.get("state", State.CLEAR)), 0, NAMES.size() - 1)
	timer_hours = maxf(0.5, float(d.get("timer", timer_hours)))
	temperature_c = clampf(float(d.get("temp", temperature_c)), -40.0, 55.0)
	pressure_hpa = clampf(float(d.get("pressure", pressure_hpa)), 950.0, 1050.0)
	humidity = clampf(float(d.get("humidity", humidity)), 0.0, 1.0)
	cloud = clampf(float(d.get("cloud", cloud)), 0.0, 1.0)
	precipitation = clampf(float(d.get("precip", precipitation)), 0.0, 1.6)
	fog = clampf(float(d.get("fog", fog)), 0.0, 1.0)
	if d.has("rng"):
		rng.state = int(d["rng"])
	_derive_precipitation()
