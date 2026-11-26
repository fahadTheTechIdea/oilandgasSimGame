extends Node
## Tiny SFX/music bus (Kenney audio). Autoloaded as `Sfx`.

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var _next: int = 0
## Silent until the player actually starts (difficulty chosen or save loaded),
## so boot, overlays and the starting base never make a sound.
var enabled := false
## Extra guard: ignore every sound for the first moments after the process
## starts, even if a caller enables audio early (demo/screenshot modes).
const BOOT_SILENCE_MS := 2500
var _boot_ms := 0

const NAMES := ["click", "confirm", "error", "drop"]


func _ready() -> void:
	_boot_ms = Time.get_ticks_msec()
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		players.append(p)
	for n in NAMES:
		var path := "res://assets/audio/%s.ogg" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	music = AudioStreamPlayer.new()
	music.volume_db = -80.0
	add_child(music)
	# music intentionally not started — SFX only


func enable() -> void:
	enabled = true


func play(name: String, pitch: float = 1.0) -> void:
	if not enabled or not streams.has(name):
		return
	if Time.get_ticks_msec() - _boot_ms < BOOT_SILENCE_MS:
		return
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = pitch
	p.play()
