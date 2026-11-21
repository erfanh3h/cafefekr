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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85
	visible = false
	_build_ui()
	_apply_safe_area()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_safe_area):
		get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	var insets := CafeSocialTheme.get_safe_area_insets(self)
	if is_instance_valid(top_bar_panel):
		var b_off: float = 14.0 + float(insets["bottom"])
		var h: float = 82.0
		var l_off: float = 14.0 + float(insets["left"])
		var r_off: float = 14.0 + float(insets["right"])
		if get_viewport() != null:
			var vis_w: float = get_viewport().get_visible_rect().size.x
			if vis_w > 760.0:
				var extra: float = (vis_w - 700.0) * 0.5
				l_off = maxf(l_off, extra)
				r_off = maxf(r_off, extra)
		top_bar_panel.offset_left = l_off
		top_bar_panel.offset_right = -r_off
		top_bar_panel.offset_bottom = -b_off
		top_bar_panel.offset_top = -(b_off + h)
	if is_instance_valid(end_modal_card):
		CafeSocialTheme.constrain_modal_card(end_modal_card, self, 620.0, 24.0)


func _build_ui() -> void:
	# Compact Bottom Antique Spectator Control Bar (never overlaps BaseTopHeader at top)
	top_bar_panel = PanelContainer.new()
	top_bar_panel.name = "SpectatorControlBar"
	top_bar_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	top_bar_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	top_bar_panel.offset_left = 14.0
	top_bar_panel.offset_right = -14.0
	top_bar_panel.offset_top = -92.0
	top_bar_panel.offset_bottom = -14.0
	top_bar_panel.custom_minimum_size = Vector2(0, 76)
	top_bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bar_style: StyleBox = CafeSocialTheme.create_highlight_card_style(true)
	top_bar_panel.add_theme_stylebox_override("panel", bar_style)
	add_child(top_bar_panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar_panel.add_child(hbox)

	btn_leave = CafeSocialTheme.make_button("ترک تماشا", "crimson", Vector2(132, 50), CafeSocialTheme.FONT_SIZE_BADGE)
	btn_leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_leave.pressed.connect(func():
		AudioManager.sfx_button()
		hide_match_ended()
		leave_spectate_requested.emit()
	)
	hbox.add_child(btn_leave)

	# Spectator count pill (Eye icon on left, count on right — LTR)
	var count_panel: PanelContainer = PanelContainer.new()
	count_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var count_style: StyleBoxFlat = StyleBoxFlat.new()
	count_style.bg_color = Color(0.11, 0.07, 0.04, 0.94)
	count_style.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	count_style.set_border_width_all(2)
	count_style.set_corner_radius_all(14)
	count_style.content_margin_left = 12.0
	count_style.content_margin_right = 12.0
	count_style.content_margin_top = 6.0
	count_style.content_margin_bottom = 6.0
	count_panel.add_theme_stylebox_override("panel", count_style)
	hbox.add_child(count_panel)

	var count_hbox: HBoxContainer = HBoxContainer.new()
	count_hbox.layout_direction = Control.LAYOUT_DIRECTION_LTR
	count_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	count_hbox.add_theme_constant_override("separation", 6)
	count_panel.add_child(count_hbox)

	var eye_lbl: Label = CafeSocialTheme.make_body(
		"👁",
		CafeSocialTheme.FONT_SIZE_BADGE,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	count_hbox.add_child(eye_lbl)

	lbl_spectator_count = CafeSocialTheme.make_body(
		"۱",
		CafeSocialTheme.FONT_SIZE_BADGE,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	count_hbox.add_child(lbl_spectator_count)

	# Center title: ONLY current turn ("نوبت فعلی : ...")
	var status_col: VBoxContainer = VBoxContainer.new()
	status_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(status_col)

	lbl_game_title = null
	lbl_turn_status = CafeSocialTheme.make_title(
		"نوبت فعلی : ...",
		CafeSocialTheme.FONT_SIZE_TAB_COMPACT,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	lbl_turn_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_turn_status.clip_text = true
	lbl_turn_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_col.add_child(lbl_turn_status)

	# Live Ruby Badge on the right
	var live_badge_panel: PanelContainer = PanelContainer.new()
	live_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var live_style: StyleBoxFlat = StyleBoxFlat.new()
	live_style.bg_color = Color(0.68, 0.12, 0.12, 0.96)
	live_style.border_color = Color(1.0, 0.82, 0.38, 1.0)
	live_style.set_border_width_all(2)
	live_style.set_corner_radius_all(14)
	live_style.content_margin_left = 12.0
	live_style.content_margin_right = 12.0
	live_style.content_margin_top = 8.0
	live_style.content_margin_bottom = 8.0
	live_badge_panel.add_theme_stylebox_override("panel", live_style)
	hbox.add_child(live_badge_panel)

	lbl_live_badge = CafeSocialTheme.make_title(
		"● زنده",
		CafeSocialTheme.FONT_SIZE_BADGE,
		Color(1.0, 0.96, 0.90, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	live_badge_panel.add_child(lbl_live_badge)

	# Match End Modal Overlay
	end_modal_backdrop = ColorRect.new()
	end_modal_backdrop.name = "EndModalBackdrop"
	end_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_modal_backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	end_modal_backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	end_modal_backdrop.color = Color(0.03, 0.02, 0.01, 0.80)
	end_modal_backdrop.visible = false
	end_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_modal_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_modal_backdrop.add_child(center)

	end_modal_card = PanelContainer.new()
	end_modal_card.custom_minimum_size = Vector2(620, 360)
	end_modal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	end_modal_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(end_modal_card)

	var modal_margin: MarginContainer = MarginContainer.new()
	modal_margin.add_theme_constant_override("margin_left", 24)
	modal_margin.add_theme_constant_override("margin_right", 24)
	modal_margin.add_theme_constant_override("margin_top", 28)
	modal_margin.add_theme_constant_override("margin_bottom", 28)
	end_modal_card.add_child(modal_margin)

	var modal_vbox: VBoxContainer = VBoxContainer.new()
	modal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_theme_constant_override("separation", 18)
	modal_margin.add_child(modal_vbox)

	lbl_end_title = CafeSocialTheme.make_title(
		"🏁 پایان مسابقه زنده",
		CafeSocialTheme.FONT_SIZE_CARD_TITLE,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	modal_vbox.add_child(lbl_end_title)

	lbl_end_desc = CafeSocialTheme.make_body(
		"این مسابقه به پایان رسید.",
		CafeSocialTheme.FONT_SIZE_BODY,
		CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	lbl_end_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_end_desc.custom_minimum_size = Vector2(0, 64)
	modal_vbox.add_child(lbl_end_desc)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_child(btn_row)

	btn_end_return = CafeSocialTheme.make_button("بازگشت به منو", "gold", Vector2(260, 58), CafeSocialTheme.FONT_SIZE_TAB_LABEL)
	btn_end_return.pressed.connect(func():
		AudioManager.sfx_button()
		hide_match_ended()
		leave_spectate_requested.emit()
	)
	btn_row.add_child(btn_end_return)


func open_for_match(payload: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = true
	_apply_safe_area()
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
		lbl_turn_status.text = "نوبت فعلی : %s" % p_name
	else:
		lbl_turn_status.text = "نوبت فعلی : ..."


func update_spectator_count(count: int) -> void:
	var safe_count: int = maxi(0, count)
	if is_instance_valid(lbl_spectator_count):
		lbl_spectator_count.text = GameManager.to_fa_num(safe_count)


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
