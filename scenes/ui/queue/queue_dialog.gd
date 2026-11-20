extends PanelContainer

# Queue Dialog Controller
# Features procedural matchmaking radar & orbital VFX, upright game/trophy crest,
# live 1v1 & 4-player framed avatar seat cards, capacity progress bar,
# Persian elapsed timer, and animated 15s Accept/Reject urgency flow.

signal queue_cancelled()
signal match_ready(game_id: String, game_type: String)
signal pre_game_ready(pre_game_id: String, queuers: Array)

@onready var lbl_title: Label = $Margin/VBox/TopRow/TitleBox/LblTitle
@onready var lbl_mode_pill: Label = $Margin/VBox/TopRow/TitleBox/LblModePill
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var radar_stage: Control = $Margin/VBox/RadarStage
@onready var radar_vfx: Control = $Margin/VBox/RadarStage/RadarVFX
@onready var center_crest: PanelContainer = $Margin/VBox/RadarStage/CenterCrest
@onready var center_icon: TextureRect = $Margin/VBox/RadarStage/CenterCrest/CenterIcon
@onready var capacity_box: VBoxContainer = $Margin/VBox/CapacityBox
@onready var lbl_capacity: Label = $Margin/VBox/CapacityBox/LblCapacity
@onready var capacity_bar: ProgressBar = $Margin/VBox/CapacityBox/CapacityBar
@onready var slots_container: HBoxContainer = $Margin/VBox/SlotsContainer
@onready var timer_pill: PanelContainer = $Margin/VBox/TimerBox/TimerPill
@onready var lbl_timer: Label = $Margin/VBox/TimerBox/TimerPill/LblTimer
@onready var accept_progress_bar: ProgressBar = $Margin/VBox/TimerBox/AcceptProgressBar
@onready var lbl_status: Label = $Margin/VBox/LblStatus
@onready var btn_cancel: Button = $Margin/VBox/BtnCancel

const CREST_RANK_TEX: Texture2D = preload("res://assets/images/badges/rank.png")
const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")

var elapsed_seconds: int = 0
var timer_active: bool = false
var search_timer: Timer

# Accept / Reject confirmation controls
var accept_container: HBoxContainer
var btn_accept: Button
var btn_reject: Button
var accept_countdown: int = 15
var accept_timer: Timer
var is_accept_phase: bool = false
var _local_accepted: bool = false
var is_multi_rank_mode: bool = false
var _multi_rank_game_type: String = ""
var _last_multi_count: int = 1
var _crest_tween: Tween = null
var _slot_pulse_tween: Tween = null
var _accept_bar_tween: Tween = null


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


static func _fa_digits(val: Variant) -> String:
	var s: String = str(val)
	var fa: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out: String = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_RED)
	ActionVFXManager.apply_button_juice(btn_cancel, "tap_button")
	btn_cancel.pressed.connect(_on_cancel_pressed)
	if is_instance_valid(btn_close_top):
		btn_close_top.pressed.connect(_on_cancel_pressed)

	search_timer = Timer.new()
	search_timer.wait_time = 1.0
	search_timer.timeout.connect(_on_timer_tick)
	add_child(search_timer)

	accept_timer = Timer.new()
	accept_timer.wait_time = 1.0
	accept_timer.timeout.connect(_on_accept_tick)
	add_child(accept_timer)

	_setup_accept_ui()

	NetworkManager.game_match_found.connect(_on_match_found)
	NetworkManager.queue_accept_game_received.connect(_on_accept_game_received)
	NetworkManager.pre_game_started.connect(_on_pre_game_started)
	NetworkManager.queue_game_canceled.connect(_on_game_canceled)
	NetworkManager.multi_rank_queue_status.connect(_on_multi_rank_queue_status)
	NetworkManager.multi_rank_match_ready.connect(_on_multi_rank_match_ready)
	NetworkManager.ranked_locked_received.connect(func(_data):
		stop_queue()
	)


func _setup_accept_ui() -> void:
	accept_container = HBoxContainer.new()
	accept_container.name = "AcceptContainer"
	accept_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_container.alignment = BoxContainer.ALIGNMENT_CENTER
	accept_container.add_theme_constant_override("separation", 12)
	accept_container.visible = false

	# Accept Button (Emerald Green)
	btn_accept = Button.new()
	btn_accept.text = "آماده‌ام"
	btn_accept.custom_minimum_size = Vector2(0, 64)
	btn_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_accept.size_flags_stretch_ratio = 1.4
	btn_accept.add_theme_font_override("font", FONT_HEKAYAT)
	btn_accept.add_theme_font_size_override("font_size", 25)
	KenneyUI.style_button(btn_accept, KenneyUI.COLOR_GREEN)
	ActionVFXManager.apply_button_juice(btn_accept, "tap_button")
	btn_accept.pressed.connect(_on_accept_pressed)
	accept_container.add_child(btn_accept)

	# Reject Button (Crimson)
	btn_reject = Button.new()
	btn_reject.text = "انصراف"
	btn_reject.custom_minimum_size = Vector2(0, 64)
	btn_reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reject.add_theme_font_override("font", FONT_HEKAYAT)
	btn_reject.add_theme_font_size_override("font_size", 24)
	KenneyUI.style_button(btn_reject, KenneyUI.COLOR_RED)
	ActionVFXManager.apply_button_juice(btn_reject, "tap_button")
	btn_reject.pressed.connect(_on_reject_pressed)
	accept_container.add_child(btn_reject)

	$Margin/VBox.add_child(accept_container)


func _apply_responsive_size() -> void:
	var vp_w: float = get_viewport_rect().size.x if get_viewport() != null else 720.0
	var target_w: float = clampf(vp_w - 36.0, 320.0, 600.0)
	custom_minimum_size = Vector2(target_w, 0.0)
	call_deferred("_recenter_dialog", target_w)


func _recenter_dialog(target_w: float) -> void:
	if not is_instance_valid(self):
		return
	reset_size()
	var h: float = maxf(size.y, get_combined_minimum_size().y)
	offset_left = -target_w * 0.5
	offset_right = target_w * 0.5
	offset_top = -h * 0.5
	offset_bottom = h * 0.5
	pivot_offset = Vector2(target_w * 0.5, h * 0.5)


func _load_game_art(game_type: String) -> Texture2D:
	if game_type.is_empty():
		return CREST_RANK_TEX
	var clean: String = GameRegistry.normalize_type(game_type).to_lower().strip_edges()
	var png_path: String = "res://assets/images/games/%s.png" % clean
	if ResourceLoader.exists(png_path):
		return load(png_path)
	var jpg_path: String = "res://assets/images/games/%s.jpg" % clean
	if ResourceLoader.exists(jpg_path):
		return load(jpg_path)
	return CREST_RANK_TEX


func _style_crest(is_emerald: bool) -> void:
	if not is_instance_valid(center_crest):
		return
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(42)
	if is_emerald:
		sb.bg_color = Color(0.08, 0.22, 0.13, 0.96)
		sb.border_color = Color(0.32, 0.98, 0.56, 1.0)
		if not _is_mobile():
			sb.shadow_color = Color(0.28, 0.96, 0.54, 0.45)
			sb.shadow_size = 12
	else:
		sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
		sb.border_color = Color(1.0, 0.82, 0.30, 0.96)
		if not _is_mobile():
			sb.shadow_color = Color(1.0, 0.78, 0.24, 0.36)
			sb.shadow_size = 10
	center_crest.add_theme_stylebox_override("panel", sb)


func _style_timer_pill(is_urgent: bool, is_emerald: bool = false) -> void:
	if not is_instance_valid(timer_pill):
		return
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	if is_urgent:
		sb.bg_color = Color(0.26, 0.07, 0.07, 0.94)
		sb.border_color = Color(1.0, 0.38, 0.34, 0.96)
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.50, 0.46))
	elif is_emerald:
		sb.bg_color = Color(0.08, 0.22, 0.13, 0.94)
		sb.border_color = Color(0.34, 0.96, 0.56, 0.95)
		lbl_timer.add_theme_color_override("font_color", Color(0.45, 0.98, 0.65))
	else:
		sb.bg_color = Color(0.085, 0.055, 0.032, 0.94)
		sb.border_color = Color(0.86, 0.68, 0.28, 0.86)
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38))
	timer_pill.add_theme_stylebox_override("panel", sb)

	if is_instance_valid(accept_progress_bar):
		var fill_sb: StyleBoxFlat = StyleBoxFlat.new()
		fill_sb.set_corner_radius_all(6)
		fill_sb.bg_color = Color(0.96, 0.34, 0.34, 1.0) if is_urgent else Color(0.28, 0.88, 0.52, 1.0)
		accept_progress_bar.add_theme_stylebox_override("fill", fill_sb)


func _start_crest_hover() -> void:
	_stop_crest_hover()
	if not is_instance_valid(center_crest):
		return
	center_crest.pivot_offset = center_crest.custom_minimum_size * 0.5
	center_crest.scale = Vector2.ONE
	center_crest.offset_top = -41.0
	center_crest.offset_bottom = 41.0
	_crest_tween = create_tween().set_loops()
	if _is_mobile():
		_crest_tween.tween_property(center_crest, "scale", Vector2(1.045, 1.045), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_crest_tween.tween_property(center_crest, "scale", Vector2(0.98, 0.98), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_crest_tween.tween_property(center_crest, "scale", Vector2(1.06, 1.06), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_crest_tween.parallel().tween_property(center_crest, "offset_top", -45.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_crest_tween.parallel().tween_property(center_crest, "offset_bottom", 37.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_crest_tween.tween_property(center_crest, "scale", Vector2(0.98, 0.98), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_crest_tween.parallel().tween_property(center_crest, "offset_top", -38.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_crest_tween.parallel().tween_property(center_crest, "offset_bottom", 44.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_crest_hover() -> void:
	if _crest_tween and _crest_tween.is_valid():
		_crest_tween.kill()
		_crest_tween = null
	if _slot_pulse_tween and _slot_pulse_tween.is_valid():
		_slot_pulse_tween.kill()
		_slot_pulse_tween = null
	if _accept_bar_tween and _accept_bar_tween.is_valid():
		_accept_bar_tween.kill()
		_accept_bar_tween = null


func _clear_slots() -> void:
	if not is_instance_valid(slots_container):
		return
	for ch in slots_container.get_children():
		ch.queue_free()


func _make_slot_card(title_txt: String, sub_txt: String, is_filled: bool, is_me: bool, av_id: int = -1, frame_id: int = 0, is_compact: bool = false, is_confirmed: bool = false) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.border_width_left = 1
	sb.border_width_top = 3 if (is_filled or is_me) else 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.content_margin_left = 6.0 if is_compact else 10.0
	sb.content_margin_right = 6.0 if is_compact else 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 8.0
	if is_confirmed:
		sb.bg_color = Color(0.08, 0.24, 0.14, 0.96)
		sb.border_color = Color(0.32, 0.98, 0.56, 1.0)
	elif is_me:
		sb.bg_color = Color(0.11, 0.18, 0.24, 0.94)
		sb.border_color = Color(0.38, 0.82, 1.0, 0.92)
	elif is_filled:
		sb.bg_color = Color(0.09, 0.22, 0.14, 0.95)
		sb.border_color = Color(0.34, 0.94, 0.56, 0.95)
	else:
		sb.bg_color = Color(0.14, 0.095, 0.06, 0.80)
		sb.border_color = Color(0.55, 0.43, 0.26, 0.52)
	card.add_theme_stylebox_override("panel", sb)

	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	# Avatar / Waiting Emblem
	var av_sz: float = 42.0 if is_compact else 52.0
	if is_filled and av_id >= 0:
		var av_badge: Control = CafeSocialTheme.make_avatar_badge(av_id, frame_id, av_sz)
		av_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(av_badge)
	else:
		var badge: PanelContainer = PanelContainer.new()
		badge.custom_minimum_size = Vector2(av_sz, av_sz)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var bsb: StyleBoxFlat = StyleBoxFlat.new()
		bsb.set_corner_radius_all(int(av_sz * 0.5))
		bsb.set_border_width_all(2)
		if is_filled:
			bsb.bg_color = Color(0.12, 0.34, 0.20, 0.95)
			bsb.border_color = Color(0.38, 0.98, 0.60, 0.98)
		else:
			bsb.bg_color = Color(0.16, 0.11, 0.07, 0.90)
			bsb.border_color = Color(0.75, 0.60, 0.34, 0.55)
		badge.add_theme_stylebox_override("panel", bsb)
		var q_lbl: Label = Label.new()
		q_lbl.text = "✓" if is_filled else "؟"
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q_lbl.add_theme_font_override("font", FONT_HEKAYAT)
		q_lbl.add_theme_font_size_override("font_size", 20 if is_compact else 24)
		q_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65) if is_filled else Color(1.0, 0.86, 0.45, 0.80))
		badge.add_child(q_lbl)
		v.add_child(badge)

	var t_lbl: Label = Label.new()
	t_lbl.text = title_txt
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.clip_text = true
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	t_lbl.add_theme_font_size_override("font_size", 16 if is_compact else 19)
	t_lbl.add_theme_color_override("font_color", Color(0.984, 0.953, 0.894) if is_filled else Color(0.82, 0.74, 0.62, 0.84))
	v.add_child(t_lbl)

	if not sub_txt.is_empty():
		var s_lbl: Label = Label.new()
		s_lbl.text = sub_txt
		s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.clip_text = true
		s_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s_lbl.add_theme_font_override("font", FONT_VAZIR)
		s_lbl.add_theme_font_size_override("font_size", 11 if is_compact else 12)
		var sub_col: Color = Color(0.45, 0.98, 0.65) if is_confirmed else (Color(0.48, 0.90, 1.0) if is_me else (Color(0.45, 0.98, 0.65) if is_filled else Color(0.74, 0.65, 0.53, 0.78)))
		s_lbl.add_theme_color_override("font_color", sub_col)
		v.add_child(s_lbl)

	if not is_filled and not _is_mobile():
		var tw: Tween = card.create_tween().set_loops()
		tw.tween_property(card, "modulate:a", 0.68, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return card


func _rebuild_1v1_slots(opponent_found: bool) -> void:
	_clear_slots()
	if not is_instance_valid(slots_container):
		return
	slots_container.add_theme_constant_override("separation", 10)

	var my_name: String = GameManager.get_username()
	if my_name.is_empty():
		my_name = "شما"
	var my_av: int = GameManager.get_avatar_id()
	var my_fid: int = GameManager.get_frame_id()

	var my_sub: String = "تأیید شد ✓" if _local_accepted else ("در انتظار تأیید شما" if opponent_found else "آماده (شما)")
	var my_card: PanelContainer = _make_slot_card(my_name, my_sub, true, true, my_av, my_fid, false, _local_accepted)
	slots_container.add_child(my_card)

	var vs_disc: PanelContainer = PanelContainer.new()
	vs_disc.custom_minimum_size = Vector2(44, 44)
	vs_disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vs_sb: StyleBoxFlat = StyleBoxFlat.new()
	vs_sb.bg_color = Color(0.10, 0.24, 0.14, 0.96) if opponent_found else Color(0.18, 0.115, 0.055, 0.96)
	vs_sb.border_color = Color(0.34, 0.98, 0.58, 0.96) if opponent_found else Color(0.92, 0.76, 0.30, 0.90)
	vs_sb.set_border_width_all(2)
	vs_sb.set_corner_radius_all(22)
	vs_disc.add_theme_stylebox_override("panel", vs_sb)

	var vs_lbl: Label = Label.new()
	vs_lbl.text = "VS"
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	vs_lbl.add_theme_font_size_override("font_size", 20)
	vs_lbl.add_theme_color_override("font_color", Color(0.42, 1.0, 0.65) if opponent_found else Color(1.0, 0.86, 0.36))
	vs_disc.add_child(vs_lbl)
	slots_container.add_child(vs_disc)

	var opp_card: PanelContainer = _make_slot_card(
		"حریف پیدا شد!" if opponent_found else "در جستجوی حریف",
		"منتظر تأیید..." if opponent_found else "هم‌سطح شما",
		opponent_found,
		false,
		-1,
		0,
		false,
		false
	)
	slots_container.add_child(opp_card)

	if opponent_found:
		opp_card.pivot_offset = opp_card.size * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(opp_card, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(opp_card, "scale", Vector2.ONE, 0.18)


func _rebuild_multi_slots(filled_count: int, required_count: int, queuers: Array = []) -> void:
	_clear_slots()
	if not is_instance_valid(slots_container):
		return
	var total: int = clampi(required_count, 2, 4)
	var filled: int = clampi(filled_count, 1, total)
	slots_container.add_theme_constant_override("separation", 6)

	if is_instance_valid(capacity_box):
		capacity_box.visible = true
	if is_instance_valid(lbl_capacity):
		lbl_capacity.text = "ظرفیت اتاق: %s از %s بازیکن آماده" % [_fa_digits(filled), _fa_digits(total)]
	if is_instance_valid(capacity_bar):
		capacity_bar.max_value = float(total)
		capacity_bar.value = float(filled)

	var my_id: String = str(GameManager.get_user_id())
	var my_name: String = GameManager.get_username()
	if my_name.is_empty():
		my_name = "شما"
	var my_av: int = GameManager.get_avatar_id()
	var my_fid: int = GameManager.get_frame_id()

	var parsed_players: Array[Dictionary] = []
	for q in queuers:
		if typeof(q) == TYPE_DICTIONARY:
			parsed_players.append(q as Dictionary)

	for i in range(total):
		var is_seat_filled: bool = i < filled
		var is_me_seat: bool = false
		var p_name: String = ""
		var p_sub: String = ""
		var p_av: int = -1
		var p_fid: int = 0

		if i < parsed_players.size():
			var pd: Dictionary = parsed_players[i]
			var uid: String = str(pd.get("user_id", pd.get("id", "")))
			is_me_seat = (not my_id.is_empty() and uid == my_id)
			p_name = str(pd.get("username", pd.get("name", "بازیکن %s" % _fa_digits(i + 1))))
			p_sub = "شما" if is_me_seat else "آماده"
			p_av = int(pd.get("image", pd.get("user_image", my_av if is_me_seat else -1)))
			p_fid = GameManager.get_player_frame_id(pd)
			is_seat_filled = true
		elif i == 0:
			is_me_seat = true
			p_name = my_name
			p_sub = "شما"
			p_av = my_av
			p_fid = my_fid
			is_seat_filled = true
		elif is_seat_filled:
			p_name = "بازیکن %s" % _fa_digits(i + 1)
			p_sub = "آماده"
			p_av = -1
		else:
			p_name = "جایگاه %s" % _fa_digits(i + 1)
			p_sub = "در انتظار"
			p_av = -1

		var card: PanelContainer = _make_slot_card(p_name, p_sub, is_seat_filled, is_me_seat, p_av, p_fid, true, false)
		slots_container.add_child(card)


func start_queue(requested_game_type: String = "") -> void:
	is_multi_rank_mode = false
	_multi_rank_game_type = requested_game_type
	_local_accepted = false
	_apply_responsive_size()
	ActionVFXManager.animate_dialog_open(self, null, true)
	elapsed_seconds = 0
	timer_active = true
	is_accept_phase = false

	lbl_title.text = "جستجوی حریف آنلاین"
	if is_instance_valid(lbl_mode_pill):
		lbl_mode_pill.text = "مسابقه رده‌بندی دو نفره"
	if is_instance_valid(capacity_box):
		capacity_box.visible = false
	if is_instance_valid(accept_progress_bar):
		accept_progress_bar.visible = false
	radar_stage.visible = true
	slots_container.visible = true
	btn_cancel.visible = true
	btn_cancel.disabled = false
	if is_instance_valid(btn_close_top):
		btn_close_top.visible = true
	accept_container.visible = false
	btn_accept.disabled = false
	btn_reject.disabled = false

	if is_instance_valid(center_icon):
		center_icon.texture = _load_game_art(requested_game_type)
	_style_crest(false)
	_style_timer_pill(false, false)
	_start_crest_hover()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("set_searching_mode", false, 1, 2)
	_rebuild_1v1_slots(false)
	_update_timer_label()

	if not requested_game_type.is_empty():
		GameManager.set_game_type(requested_game_type)
		var g_info: Dictionary = GameRegistry.get_game_info(requested_game_type)
		var g_name: String = str(g_info.get("name_fa", requested_game_type))
		lbl_title.text = "صف رنک %s" % g_name
		lbl_status.text = "در حال یافتن حریف هم‌سطح برای %s..." % g_name
		lbl_status.modulate = Color(1.0, 0.94, 0.65)
		search_timer.start()
		AudioManager.play_queue_music()
		NetworkManager.join_matchmaking_queue(requested_game_type)
	else:
		lbl_status.text = "در حال جستجوی حریف هم‌سطح در رده‌بندی..."
		lbl_status.modulate = Color(1.0, 0.94, 0.65)
		search_timer.start()
		AudioManager.play_queue_music()
		NetworkManager.join_matchmaking_queue()


func start_multi_rank_queue(requested_game_type: String) -> void:
	var norm_type: String = GameRegistry.normalize_type(requested_game_type)
	is_multi_rank_mode = true
	_multi_rank_game_type = norm_type
	_last_multi_count = 1
	_local_accepted = false
	GameManager.set_game_type(norm_type)
	_apply_responsive_size()
	ActionVFXManager.animate_dialog_open(self, null, true)
	elapsed_seconds = 0
	timer_active = true
	is_accept_phase = false

	var g_info: Dictionary = GameRegistry.get_game_info(norm_type)
	var g_name: String = str(g_info.get("name_fa", norm_type))
	lbl_title.text = "رقابت ۴ نفره — %s" % g_name
	if is_instance_valid(lbl_mode_pill):
		lbl_mode_pill.text = "مسابقه رده‌بندی چندنفره آنلاین"
	if is_instance_valid(accept_progress_bar):
		accept_progress_bar.visible = false
	radar_stage.visible = true
	slots_container.visible = true
	btn_cancel.visible = true
	btn_cancel.disabled = false
	if is_instance_valid(btn_close_top):
		btn_close_top.visible = true
	accept_container.visible = false
	btn_accept.disabled = false
	btn_reject.disabled = false

	if is_instance_valid(center_icon):
		center_icon.texture = _load_game_art(norm_type)
	_style_crest(false)
	_style_timer_pill(false, false)
	_start_crest_hover()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("set_searching_mode", true, 1, 4)
	_rebuild_multi_slots(1, 4, [])
	_update_timer_label()

	lbl_status.text = "با تکمیل ظرفیت ۴ بازیکن، مسابقه به‌صورت خودکار آغاز می‌شود"
	lbl_status.modulate = Color(0.92, 0.85, 0.72)
	search_timer.start()
	AudioManager.play_queue_music()
	NetworkManager.join_multi_rank_queue(norm_type)


func _on_multi_rank_queue_status(queuers_count: int, required_count: int, game_type: String, queuers: Array) -> void:
	if not is_multi_rank_mode or not timer_active:
		return
	var norm_type: String = GameRegistry.normalize_type(game_type if not game_type.is_empty() else _multi_rank_game_type)
	var g_info: Dictionary = GameRegistry.get_game_info(norm_type)
	var g_name: String = str(g_info.get("name_fa", norm_type))
	var cnt: int = maxi(1, queuers_count)
	var req: int = maxi(4, required_count)
	lbl_status.text = "در انتظار پیوستن %s بازیکن دیگر برای شروع %s..." % [_fa_digits(maxi(0, req - cnt)), g_name]
	lbl_status.modulate = Color(0.45, 0.98, 0.65) if cnt >= 2 else Color(0.94, 0.88, 0.72)

	_rebuild_multi_slots(cnt, req, queuers)
	if is_instance_valid(radar_vfx):
		radar_vfx.call("set_searching_mode", true, cnt, req)
		if cnt > _last_multi_count:
			radar_vfx.call("trigger_pulse_burst", Color(0.35, 0.98, 0.62, 1.0))
	_last_multi_count = cnt


func _on_multi_rank_match_ready(game_id: String, game_type: String) -> void:
	if not is_multi_rank_mode:
		return
	is_multi_rank_mode = false
	timer_active = false
	is_accept_phase = false
	search_timer.stop()
	accept_timer.stop()
	_stop_crest_hover()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("set_match_found_mode")
	_style_crest(true)
	lbl_title.text = "ظرفیت تکمیل شد! (۴ از ۴)"
	lbl_status.text = "هر ۴ بازیکن آماده هستند — ورود به میز مسابقه..."
	lbl_status.modulate = Color(0.35, 0.98, 0.58)
	AudioManager.sfx_queue_found()
	AudioManager.stop_music()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("stop_vfx")
	visible = false
	var target_type: String = game_type if not game_type.is_empty() else _multi_rank_game_type
	match_ready.emit(game_id, target_type)


func stop_queue() -> void:
	var was_multi: bool = is_multi_rank_mode
	is_multi_rank_mode = false
	timer_active = false
	is_accept_phase = false
	_local_accepted = false
	search_timer.stop()
	accept_timer.stop()
	_stop_crest_hover()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("stop_vfx")
	AudioManager.play_theme_music()
	if was_multi:
		NetworkManager.leave_multi_rank_queue()
	else:
		NetworkManager.leave_matchmaking_queue()
	queue_cancelled.emit()
	ActionVFXManager.animate_dialog_close(self, null, func():
		visible = false
	)


func _on_timer_tick() -> void:
	elapsed_seconds += 1
	_update_timer_label()


func _update_timer_label() -> void:
	var mins: int = elapsed_seconds / 60
	var secs: int = elapsed_seconds % 60
	lbl_timer.text = _fa_digits("%02d:%02d" % [mins, secs])


func _on_cancel_pressed() -> void:
	AudioManager.sfx_button()
	stop_queue()


func _on_accept_game_received() -> void:
	search_timer.stop()
	is_accept_phase = true
	_local_accepted = false

	AudioManager.sfx_queue_found()
	AudioManager.play_queue_music()

	lbl_title.text = "حریف پیدا شد!"
	if is_instance_valid(lbl_mode_pill):
		lbl_mode_pill.text = "تأیید ورود به مسابقه"
	lbl_status.text = "مسابقه آماده است — برای شروع رقابت تأیید کنید"
	lbl_status.modulate = Color(0.45, 0.98, 0.65)

	radar_stage.visible = true
	if is_instance_valid(radar_vfx):
		radar_vfx.call("set_match_found_mode")
	_style_crest(true)
	_style_timer_pill(false, true)
	_rebuild_1v1_slots(true)

	ActionVFXManager.spawn_dialog_sparkle_burst(global_position + size * 0.5)

	btn_cancel.visible = false
	if is_instance_valid(btn_close_top):
		btn_close_top.visible = false
	accept_container.visible = true
	btn_accept.disabled = false
	btn_reject.disabled = false

	accept_countdown = 15
	lbl_timer.text = "%s ثانیه" % _fa_digits(accept_countdown)
	if is_instance_valid(accept_progress_bar):
		accept_progress_bar.visible = true
		accept_progress_bar.max_value = 15.0
		accept_progress_bar.value = 15.0
		if _accept_bar_tween and _accept_bar_tween.is_valid():
			_accept_bar_tween.kill()
		_accept_bar_tween = create_tween()
		_accept_bar_tween.tween_property(accept_progress_bar, "value", 0.0, 15.0)
	accept_timer.start()


func _on_accept_tick() -> void:
	accept_countdown -= 1
	var rem: int = maxi(0, accept_countdown)
	lbl_timer.text = "%s ثانیه" % _fa_digits(rem)
	if rem <= 5 and rem > 0:
		_style_timer_pill(true, false)
	if accept_countdown <= 0:
		accept_timer.stop()
		_on_reject_pressed()


func _on_accept_pressed() -> void:
	AudioManager.sfx_button()
	_local_accepted = true
	btn_accept.disabled = true
	btn_reject.disabled = true
	lbl_status.text = "تأیید شما ثبت شد — در انتظار تأیید حریف..."
	lbl_status.modulate = Color(1.0, 0.88, 0.45)
	_rebuild_1v1_slots(true)
	if is_instance_valid(radar_vfx):
		radar_vfx.call("trigger_pulse_burst", Color(0.42, 0.96, 1.0, 1.0))
	NetworkManager.send_queue_accept()


func _on_reject_pressed() -> void:
	AudioManager.sfx_button()
	accept_timer.stop()
	NetworkManager.send_queue_reject()
	stop_queue()


func _on_pre_game_started(pre_game_id: String, queuers: Array) -> void:
	accept_timer.stop()
	timer_active = false
	is_accept_phase = false
	_stop_crest_hover()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("stop_vfx")

	lbl_status.text = "ورود به مرحله انتخاب و حذف بازی‌ها..."
	lbl_status.modulate = Color(0.35, 0.98, 0.55)

	await get_tree().create_timer(0.5).timeout
	visible = false
	pre_game_ready.emit(pre_game_id, queuers)


func _on_game_canceled() -> void:
	accept_timer.stop()
	search_timer.stop()
	lbl_status.text = "مسابقه لغو شد."
	lbl_status.modulate = Color(1.0, 0.48, 0.48)
	await get_tree().create_timer(1.2).timeout
	stop_queue()


func _on_match_found(game_id: String) -> void:
	if not timer_active and not is_accept_phase:
		return
	timer_active = false
	is_accept_phase = false
	search_timer.stop()
	accept_timer.stop()
	_stop_crest_hover()
	if is_instance_valid(radar_vfx):
		radar_vfx.call("stop_vfx")
	lbl_status.text = "حریف پیدا شد! ورود به میز..."
	lbl_status.modulate = Color(0.28, 0.96, 0.52)

	AudioManager.sfx_queue_found()
	AudioManager.stop_music()
	visible = false
	match_ready.emit(game_id, GameTypes.TIC_TAC_TOE)
