extends Control

# Procedural Matchmaking Radar & Orbital VFX
# Renders layered sonar pulse waves, counter-rotating compass arcs, a radar sweep cone,
# orbiting beacon dots, and drifting starlight motes in a single lightweight _draw() pass.
# Replaces the old spinning logo with a regal, mobile-friendly matchmaking centerpiece.

var _time: float = 0.0
var _redraw_accum: float = 0.0
var _accent_color: Color = Color(1.0, 0.80, 0.28, 1.0)
var _target_accent: Color = Color(1.0, 0.80, 0.28, 1.0)
var _is_match_found: bool = false
var _is_multi_mode: bool = false
var _filled_slots: int = 1
var _total_slots: int = 2

var _burst_t: float = 1.0
var _burst_color: Color = Color(0.30, 0.96, 0.56, 1.0)

var _motes: Array[Dictionary] = []

func _is_mobile() -> bool:
	return GameManager.is_mobile or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_motes()
	set_process(false)

func _init_motes() -> void:
	_motes.clear()
	var count: int = 6 if _is_mobile() else 10
	for i in range(count):
		var frac: float = float(i) / float(count)
		_motes.append({
			"angle": frac * TAU,
			"speed": 0.28 + fmod(float(i) * 0.17, 0.35),
			"radius": 58.0 + fmod(float(i) * 19.0, 42.0),
			"phase": frac * TAU * 1.7,
			"size": 2.0 + fmod(float(i) * 0.9, 1.8)
		})

func set_searching_mode(is_multi: bool, filled: int = 1, total: int = 2) -> void:
	_is_multi_mode = is_multi
	_is_match_found = false
	_filled_slots = clampi(filled, 1, maxi(2, total))
	_total_slots = maxi(2, total)
	if is_multi and _filled_slots >= 2:
		_target_accent = Color(0.38, 0.92, 0.68, 1.0)
	else:
		_target_accent = Color(1.0, 0.80, 0.28, 1.0)
	set_process(true)
	queue_redraw()

func set_match_found_mode() -> void:
	_is_match_found = true
	_target_accent = Color(0.28, 0.98, 0.54, 1.0)
	trigger_pulse_burst(Color(0.32, 1.0, 0.58, 1.0))
	set_process(true)
	queue_redraw()

func trigger_pulse_burst(col: Color) -> void:
	_burst_t = 0.0
	_burst_color = col
	queue_redraw()

func stop_vfx() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		set_process(false)
		return
	_time += delta
	_accent_color = _accent_color.lerp(_target_accent, clampf(delta * 5.0, 0.0, 1.0))
	if _burst_t < 1.0:
		_burst_t = minf(1.0, _burst_t + delta * 1.65)

	# Smooth 30fps redraw cadence on mobile, full 60fps on desktop
	var step: float = 0.033 if _is_mobile() else 0.016
	_redraw_accum += delta
	if _redraw_accum >= step:
		_redraw_accum = 0.0
		queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var max_r: float = minf(size.x, size.y) * 0.47
	if max_r < 24.0:
		return

	var col := _accent_color

	# 1. Soft Ambient Glow Discs behind center crest
	draw_circle(c, max_r * 0.72, Color(col.r, col.g, col.b, 0.06))
	draw_circle(c, max_r * 0.52, Color(col.r, col.g, col.b, 0.10))

	# 2. Expanding Sonar Pulse Waves (3 staggered rings)
	var wave_count: int = 2 if _is_mobile() else 3
	for i in range(wave_count):
		var phase: float = fmod(_time * (0.58 if not _is_match_found else 0.85) + float(i) / float(wave_count), 1.0)
		var eased: float = 1.0 - pow(1.0 - phase, 2.0)
		var r: float = lerpf(max_r * 0.40, max_r * 0.98, eased)
		var alpha: float = (1.0 - phase) * (0.48 if not _is_match_found else 0.65)
		var width: float = lerpf(2.8, 1.0, phase)
		draw_arc(c, r, 0.0, TAU, 44, Color(col.r, col.g, col.b, alpha), width, true)

	# 3. Radar Sweep Cone (subtle scanning beam during search)
	if not _is_match_found:
		var sweep_angle: float = _time * 1.75
		var cone_span: float = 0.75
		var segs: int = 10
		var r_inner: float = max_r * 0.44
		var r_outer: float = max_r * 0.84
		for s in range(segs):
			var f0: float = float(s) / float(segs)
			var f1: float = float(s + 1) / float(segs)
			var a0: float = sweep_angle - cone_span * (1.0 - f0)
			var a1: float = sweep_angle - cone_span * (1.0 - f1)
			var cone_alpha: float = f1 * f1 * 0.22
			var poly := PackedVector2Array([
				c + Vector2(cos(a0), sin(a0)) * r_inner,
				c + Vector2(cos(a0), sin(a0)) * r_outer,
				c + Vector2(cos(a1), sin(a1)) * r_outer,
				c + Vector2(cos(a1), sin(a1)) * r_inner
			])
			draw_colored_polygon(poly, Color(col.r, col.g, col.b, cone_alpha))
		# Crisp leading radar line & glowing tip beacon
		var tip_dir := Vector2(cos(sweep_angle), sin(sweep_angle))
		draw_line(c + tip_dir * r_inner, c + tip_dir * r_outer, Color(1.0, 0.96, 0.80, 0.72), 2.2, true)
		draw_circle(c + tip_dir * r_outer, 4.2, Color(1.0, 0.95, 0.78, 0.95))
		draw_circle(c + tip_dir * r_outer, 8.0, Color(col.r, col.g, col.b, 0.28))

	# 4. Counter-Rotating Segmented Orbital Compass Rings
	var outer_r: float = max_r * 0.84
	var inner_r: float = max_r * 0.60
	var rot_cw: float = _time * (0.45 if not _is_match_found else 0.9)
	var rot_ccw: float = -_time * (0.72 if not _is_match_found else 1.15)

	# Outer 6-arc compass ring
	var outer_arcs: int = 6
	for k in range(outer_arcs):
		var a_start: float = rot_cw + float(k) * (TAU / float(outer_arcs))
		var a_end: float = a_start + (TAU / float(outer_arcs)) * 0.62
		draw_arc(c, outer_r, a_start, a_end, 14, Color(col.r, col.g, col.b, 0.58), 2.4, true)

	# Inner 3-arc accent ring
	var inner_arcs: int = 3
	for k in range(inner_arcs):
		var a_start: float = rot_ccw + float(k) * (TAU / float(inner_arcs))
		var a_end: float = a_start + (TAU / float(inner_arcs)) * 0.55
		draw_arc(c, inner_r, a_start, a_end, 14, Color(1.0, 0.94, 0.75, 0.52), 2.0, true)

	# 4b. Segmented Multi-Player Capacity Arcs (highlights filled seats around crest)
	if _is_multi_mode and _total_slots >= 2:
		var cap_r: float = max_r * 0.50
		var gap: float = 0.16
		var slice: float = TAU / float(_total_slots)
		for s in range(_total_slots):
			var sa0: float = -PI * 0.5 + float(s) * slice + gap * 0.5
			var sa1: float = sa0 + slice - gap
			var is_seat_ready: bool = _is_match_found or (s < _filled_slots)
			var seg_col: Color = Color(0.32, 0.98, 0.58, 0.92) if is_seat_ready else Color(col.r, col.g, col.b, 0.22)
			draw_arc(c, cap_r, sa0, sa1, 16, seg_col, 3.6 if is_seat_ready else 2.0, true)

	# 5. Orbiting Player Beacons on the Outer Ring (2 for 1v1, 4 for Multi-Rank)
	var beacon_n: int = clampi(_total_slots, 2, 4)
	for b in range(beacon_n):
		var ba: float = rot_cw * 0.75 + float(b) * (TAU / float(beacon_n)) - PI * 0.5
		var pos: Vector2 = c + Vector2(cos(ba), sin(ba)) * outer_r
		var is_active_seat: bool = _is_match_found or (b < _filled_slots)
		if is_active_seat:
			var bcol: Color = Color(0.35, 1.0, 0.62, 0.98) if (_is_match_found or (_is_multi_mode and b < _filled_slots)) else Color(1.0, 0.88, 0.36, 0.98)
			draw_circle(pos, 8.5, Color(bcol.r, bcol.g, bcol.b, 0.28))
			draw_circle(pos, 4.6, bcol)
			draw_circle(pos, 2.2, Color(1.0, 1.0, 1.0, 0.95))
		else:
			draw_circle(pos, 4.2, Color(0.22, 0.16, 0.12, 0.92))
			draw_arc(pos, 4.4, 0.0, TAU, 12, Color(col.r, col.g, col.b, 0.65), 1.5, true)

	# 6. Floating Starlight Motes
	for m in _motes:
		var ang: float = float(m["angle"]) + _time * float(m["speed"])
		var rad: float = (float(m["radius"]) / 100.0) * max_r
		var twinkle: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 2.8 + float(m["phase"])))
		var mp: Vector2 = c + Vector2(cos(ang), sin(ang)) * rad
		var sz: float = float(m["size"])
		draw_circle(mp, sz, Color(1.0, 0.94, 0.72, twinkle * 0.75))

	# 7. High-Energy Shockwave Burst (on Match Found or Player Join)
	if _burst_t < 1.0:
		var bt: float = 1.0 - pow(1.0 - _burst_t, 3.0)
		var br: float = lerpf(max_r * 0.35, max_r * 1.04, bt)
		var ba: float = (1.0 - _burst_t) * 0.92
		draw_arc(c, br, 0.0, TAU, 48, Color(_burst_color.r, _burst_color.g, _burst_color.b, ba), lerpf(5.5, 1.2, bt), true)
