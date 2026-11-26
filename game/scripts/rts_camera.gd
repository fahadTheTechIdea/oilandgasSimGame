extends Camera3D
## RTS camera with two modes:
##   CLASSIC — fixed orthographic isometric, C&C/AoE style: 45° yaw, 30° pitch,
##             no free rotation, edge scroll, wheel zoom.
##   ORBIT   — free 3D perspective 3/4 camera (yaw/pitch orbit + distance zoom).
enum Mode { CLASSIC, ORBIT }

@export var mode: int = Mode.CLASSIC
@export var pan_speed: float = 120.0
@export var zoom_step: float = 1.14
@export var min_dist: float = 30.0
@export var max_dist: float = 420.0
@export var ortho_size: float = 120.0
@export var ortho_min: float = 60.0
@export var ortho_max: float = 280.0
@export var edge_scroll: bool = true
@export var edge_margin: float = 10.0
@export var map_half: float = 352.0

var target: Vector3 = Vector3(0, 0, 40)
var dist: float = 220.0
var yaw: float = deg_to_rad(45.0)
var pitch: float = deg_to_rad(-30.0)

var _panning: bool = false
var _orbiting: bool = false
## Screenshot modes lock the camera so a stray mouse cannot reframe the shot.
var input_enabled: bool = true


func _ready() -> void:
	set_mode(mode)


func is_classic() -> bool:
	return mode == Mode.CLASSIC


func set_mode(m: int) -> void:
	mode = m
	if mode == Mode.CLASSIC:
		projection = PROJECTION_ORTHOGONAL
		size = ortho_size
		yaw = deg_to_rad(45.0)
		pitch = deg_to_rad(-30.0)
		# keep the camera close enough for Terrain3D's clipmap LOD to stay sharp
		dist = 220.0
	else:
		projection = PROJECTION_PERSPECTIVE
		fov = 50.0
		yaw = deg_to_rad(35.0)
		pitch = deg_to_rad(-35.0)
		dist = 150.0
	far = 2200.0
	_apply()


func toggle_mode() -> void:
	set_mode(Mode.ORBIT if mode == Mode.CLASSIC else Mode.CLASSIC)


func set_classic() -> void:
	set_mode(Mode.CLASSIC)


func set_orbit() -> void:
	set_mode(Mode.ORBIT)


func _process(delta: float) -> void:
	if not input_enabled:
		_apply()
		return
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	# C&C edge scrolling
	if edge_scroll and DisplayServer.window_is_focused():
		var vp := get_viewport().get_visible_rect().size
		var mp := get_viewport().get_mouse_position()
		if mp.x < edge_margin:
			input.x -= 1.0
		elif mp.x > vp.x - edge_margin:
			input.x += 1.0
		if mp.y < edge_margin:
			input.z -= 1.0
		elif mp.y > vp.y - edge_margin:
			input.z += 1.0
	if input.length_squared() > 0.0:
		var flat := Basis(Vector3.UP, yaw)
		var zoom := ortho_size / 120.0 if mode == Mode.CLASSIC else dist / 190.0
		target += flat * input.normalized() * pan_speed * delta * zoom
		_clamp_target()
	# free orbit only in the 3D mode; classic stays fixed like the originals
	if mode == Mode.ORBIT:
		if Input.is_key_pressed(KEY_Q):
			yaw -= 1.7 * delta
		if Input.is_key_pressed(KEY_E):
			yaw += 1.7 * delta
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(1.0 / zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed and mode == Mode.ORBIT
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			var flat := Basis(Vector3.UP, yaw)
			var drag := Vector3(mm.relative.x, 0.0, mm.relative.y)
			var drag_scale := size if is_classic() else dist
			target -= flat * drag * drag_scale * 0.0014
			_clamp_target()
		if _orbiting:
			yaw -= mm.relative.x * 0.005
			pitch = clampf(pitch - mm.relative.y * 0.004, deg_to_rad(-84.0), deg_to_rad(-5.0))
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_F:
			target = Vector3(0, 0, 40)
			if is_classic():
				ortho_size = 120.0
				size = ortho_size
			else:
				dist = 190.0
	_apply()


func _zoom(factor: float) -> void:
	if mode == Mode.CLASSIC:
		ortho_size = clampf(ortho_size * factor, ortho_min, ortho_max)
		size = ortho_size
	else:
		dist = clampf(dist * factor, min_dist, max_dist)
	_apply()


func _clamp_target() -> void:
	target.x = clampf(target.x, -map_half, map_half)
	target.z = clampf(target.z, -map_half, map_half)


func _apply() -> void:
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	position = target + b * Vector3(0, 0, dist)
	look_at(target, Vector3.UP)
