class_name SpectatorOverlay
extends Control

signal leave_spectate_requested()

var top_bar_panel: PanelContainer = null
var lbl_live_badge: Label = null
var lbl_game_title: Label = null
var lbl_spectator_count: Label = null
var lbl_turn_status: Label = null
var btn_leave: Button = null

var end_modal_backdrop: ColorRect = null
var end_modal_card: PanelContainer = null
var lbl_end_title: Label = null
var lbl_end_desc: Label = null
var btn_end_return: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Bottom-Left / Bottom-Center Antique Spectator Control Bar (doesn't overlap BaseTopHeader at top)
	top_bar_panel = PanelContainer.new()
	top_bar_panel.name = "SpectatorControlBar"
	top_bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	top_bar_panel.offset_left = 28.0
	top_bar_panel.offset_right = -28.0
	top_bar_panel.offset_top = -126.0
	top_bar_panel.offset_bottom = -22.0
	top_bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bar_style: StyleBox = CafeSocialTheme.create_highlight_card_style(true)
	top_bar_panel.add_theme_stylebox_override("panel", bar_style)
	add_child(top_bar_panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar_panel.add_child(hbox)

	btn_leave = CafeSocialTheme.make_button("ترک تماشا", "crimson", Vector2(168, 56), 22)
	btn_leave.pressed.connect(func():
		AudioManager.sfx_button()
		hide_match_ended()
		leave_spectate_requested.emit()
	)
	hbox.add_child(btn_leave)

	# Spectator count pill
	var count_panel: PanelContainer = PanelContainer.new()
	var count_style: StyleBoxFlat = StyleBoxFlat.new()
	count_style.bg_color = Color(0.11, 0.07, 0.04, 0.94)
	count_style.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	count_style.set_border_width_all(2)
	count_style.set_corner_radius_all(14)
	count_style.content_margin_left = 16.0
	count_style.content_margin_right = 16.0
	count_style.content_margin_top = 8.0
	count_style.content_margin_bottom = 8.0
	count_panel.add_theme_stylebox_override("panel", count_style)
	hbox.add_child(count_panel)

	lbl_spectator_count = CafeSocialTheme.make_body(
		"👁 ۱ تماشاگر",
		21,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	count_panel.add_child(lbl_spectator_count)

	# Center status / turn label
	var status_col: VBoxContainer = VBoxContainer.new()
	status_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_col.alignment = BoxContainer.ALIGNMENT_CENTER
	status_col.add_theme_constant_override("separation", 2)
	hbox.add_child(status_col)

	lbl_game_title = CafeSocialTheme.make_title(
		"تماشای زنده مسابقه",
		24,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	)
	status_col.add_child(lbl_game_title)

	lbl_turn_status = CafeSocialTheme.make_body(
		"فقط قابل مشاهده • بدون امکان دخالت در بازی",
		19,
		CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	)
	status_col.add_child(lbl_turn_status)

	# Live Ruby Badge on the right
	var live_badge_panel: PanelContainer = PanelContainer.new()
	var live_style: StyleBoxFlat = StyleBoxFlat.new()
	live_style.bg_color = Color(0.68, 0.12, 0.12, 0.96)
	live_style.border_color = Color(1.0, 0.82, 0.38, 1.0)
	live_style.set_border_width_all(2)
	live_style.set_corner_radius_all(14)
	live_style.content_margin_left = 16.0
	live_style.content_margin_right = 16.0
	live_style.content_margin_top = 10.0
	live_style.content_margin_bottom = 10.0
	live_badge_panel.add_theme_stylebox_override("panel", live_style)
	hbox.add_child(live_badge_panel)

	lbl_live_badge = CafeSocialTheme.make_title(
		"● پخش زنده",
		21,
		Color(1.0, 0.96, 0.90, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	live_badge_panel.add_child(lbl_live_badge)

	# Match End Modal Overlay
	end_modal_backdrop = ColorRect.new()
	end_modal_backdrop.name = "EndModalBackdrop"
	end_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_modal_backdrop.color = Color(0.03, 0.02, 0.01, 0.80)
	end_modal_backdrop.visible = false
	end_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_modal_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_modal_backdrop.add_child(center)

	end_modal_card = PanelContainer.new()
	end_modal_card.custom_minimum_size = Vector2(680, 380)
	end_modal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	end_modal_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(end_modal_card)

	var modal_margin: MarginContainer = MarginContainer.new()
	modal_margin.add_theme_constant_override("margin_left", 40)
	modal_margin.add_theme_constant_override("margin_right", 40)
	modal_margin.add_theme_constant_override("margin_top", 34)
	modal_margin.add_theme_constant_override("margin_bottom", 34)
	end_modal_card.add_child(modal_margin)

	var modal_vbox: VBoxContainer = VBoxContainer.new()
	modal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_theme_constant_override("separation", 22)
	modal_margin.add_child(modal_vbox)

	lbl_end_title = CafeSocialTheme.make_title(
		"🏁 پایان مسابقه زنده",
		36,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	modal_vbox.add_child(lbl_end_title)

	lbl_end_desc = CafeSocialTheme.make_body(
		"این مسابقه به پایان رسید.",
		25,
		CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	lbl_end_desc.custom_minimum_size = Vector2(540, 80)
	modal_vbox.add_child(lbl_end_desc)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_child(btn_row)

	btn_end_return = CafeSocialTheme.make_button("بازگشت به منو", "gold", Vector2(240, 64), 24)
	btn_end_return.pressed.connect(func():
		AudioManager.sfx_button()
		hide_match_ended()
		leave_spectate_requested.emit()
	)
	btn_row.add_child(btn_end_return)


func open_for_match(payload: Dictionary) -> void:
	visible = true
	hide_match_ended()
	update_from_payload(payload)


func close_overlay() -> void:
	hide_match_ended()
	visible = false


func update_from_payload(payload: Dictionary) -> void:
	var g_type: String = str(payload.get("game_type", GameManager.current_game_type))
	var g_title: String = GameRegistry.get_display_name_fa(g_type) if not g_type.is_empty() else "مسابقه"
	var count_val: int = int(payload.get("spectator_count", GameManager.spectator_count))
	if count_val <= 0:
		count_val = 1
	update_spectator_count(count_val)

	var gamers_arr: Array = []
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		gamers_arr = payload["gamers"]
	elif not GameManager.match_players.is_empty():
		gamers_arr = GameManager.match_players

	var names: Array[String] = []
	for g_item in gamers_arr:
		if typeof(g_item) == TYPE_DICTIONARY:
			var gd: Dictionary = g_item
			var nm: String = str(gd.get("name", gd.get("username", "")))
			if not nm.is_empty():
				names.append(nm)

	if is_instance_valid(lbl_game_title):
		if names.size() >= 2:
			lbl_game_title.text = "تماشای زنده «%s» — %s" % [g_title, " در برابر ".join(names)]
		else:
			lbl_game_title.text = "تماشای زنده «%s»" % g_title

	var turn_id: int = int(payload.get("current_turn", 0))
	if turn_id <= 0:
		var rec_v: Variant = payload.get("reconnect_data", {})
		if typeof(rec_v) == TYPE_DICTIONARY:
			var rec_d: Dictionary = rec_v
			turn_id = int(rec_d.get("current_turn", 0))
	update_turn_indicator(turn_id)


func update_from_snapshot(payload: Dictionary) -> void:
	update_from_payload(payload)


func update_turn_display(turn_gamer_id: int) -> void:
	update_turn_indicator(turn_gamer_id)


func update_turn_indicator(turn_gamer_id: int) -> void:
	if not is_instance_valid(lbl_turn_status):
		return
	if turn_gamer_id > 0:
		var p_data: Dictionary = GameManager.get_player_data_by_gamer_id(turn_gamer_id)
		var p_name: String = str(p_data.get("name", p_data.get("username", "بازیکن %s" % GameManager.to_fa_num(turn_gamer_id))))
		lbl_turn_status.text = "🎯 نوبت فعلی: %s • حالت تماشاگر (فقط مشاهده)" % p_name
	else:
		lbl_turn_status.text = "فقط قابل مشاهده • بدون امکان دخالت در بازی"


func update_spectator_count(count: int) -> void:
	var safe_count: int = maxi(0, count)
	if is_instance_valid(lbl_spectator_count):
		lbl_spectator_count.text = "👁 %s تماشاگر" % GameManager.to_fa_num(safe_count)


func show_match_ended(payload: Dictionary) -> void:
	visible = true
	if not is_instance_valid(end_modal_backdrop):
		return
	end_modal_backdrop.visible = true

	var winner_id: int = int(payload.get("winner", 0))
	var reason_str: String = str(payload.get("reason", "finished"))
	var summary_text: String = "این مسابقه به پایان رسید."

	if winner_id > 0:
		var w_data: Dictionary = GameManager.get_player_data_by_gamer_id(winner_id)
		var w_name: String = str(w_data.get("name", w_data.get("username", "بازیکن %s" % GameManager.to_fa_num(winner_id))))
		summary_text = "🏆 برنده مسابقه: %s\nمسابقه به پایان رسید." % w_name
	elif reason_str == "aborted" or reason_str == "deleted":
		summary_text = "مسابقه توسط بازیکنان لغو شد یا به پایان رسید."

	if is_instance_valid(lbl_end_desc):
		lbl_end_desc.text = summary_text


func hide_match_ended() -> void:
	if is_instance_valid(end_modal_backdrop):
		end_modal_backdrop.visible = false
