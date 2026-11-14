extends Control

## Cafe Fekr — Unified Player Profile, Cosmetics, Stats, Privacy & Blocked Players Dialog
## Used both from main menu (UserHeader / Ranking / SocialHub) and in-game HUD (BaseGameHUD).
## Preserves: closed(), change_username_requested(), open_for_user(user_dict, role_text), close().

signal closed()
signal change_username_requested()

var _dim_overlay: ColorRect
var panel: PanelContainer
var _lbl_title: Label
var _btn_copy_id: Button
var _toast_panel: PanelContainer
var _lbl_toast: Label

var _hero_holder: VBoxContainer
var _subtab_bar: PanelContainer
var _subtab_row: HBoxContainer
var _other_actions_holder: VBoxContainer
var _scroll_body: ScrollContainer
var _body_vbox: VBoxContainer

var _current_user_id: String = ""
var _current_role_text: String = ""
var _is_self: bool = false
var _is_bot: bool = false
var _active_self_tab: String = "overview" # "overview" | "cosmetics" | "privacy"

var _base_user_dict: Dictionary = {}
var _public_profile: Dictionary = {}
var _notif_prefs: Dictionary = {
	"friend_requests": true,
	"direct_messages": true,
	"game_invitations": true,
	"clan_events": true,
	"clan_chat_mentions": true
}
var _notif_prefs_loaded: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()


func _build_shell() -> void:
	for c in get_children():
		c.queue_free()

	_dim_overlay = ColorRect.new()
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.color = Color(0.03, 0.015, 0.01, 0.80)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			close()
	)
	add_child(_dim_overlay)

	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 24)
	outer.add_theme_constant_override("margin_right", 24)
	outer.add_theme_constant_override("margin_top", 56)
	outer.add_theme_constant_override("margin_bottom", 56)
	add_child(outer)

	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	outer.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 28)
	inner.add_theme_constant_override("margin_right", 28)
	inner.add_theme_constant_override("margin_top", 26)
	inner.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(inner)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	inner.add_child(root_vbox)

	# 1. Top Bar
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 12.0, 10.0))
	root_vbox.add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_row)

	var btn_close := TextureButton.new()
	btn_close.name = "BtnCloseTop"
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(54, 54)
	btn_close.ignore_texture_size = true
	btn_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	top_row.add_child(btn_close)

	_lbl_title = CafeSocialTheme.make_title("مشخصات بازیکن", 34, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_lbl_title)

	_btn_copy_id = CafeSocialTheme.make_button("کپی شناسه", "bronze", Vector2(146, 50), 19)
	_btn_copy_id.pressed.connect(func():
		AudioManager.sfx_tap()
		if not _current_user_id.is_empty():
			DisplayServer.clipboard_set(_current_user_id)
			_show_profile_toast("شناسه بازیکن در حافظه کپی شد.")
	)
	top_row.add_child(_btn_copy_id)

	# 2. Toast Banner
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	root_vbox.add_child(_toast_panel)

	_lbl_toast = CafeSocialTheme.make_body("", 20, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(_lbl_toast)

	# 3. Hero Plaque Holder
	_hero_holder = VBoxContainer.new()
	_hero_holder.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_hero_holder)

	# 4. Self Sub-Tabs Bar (Overview | Cosmetics | Privacy & Blocks)
	_subtab_bar = PanelContainer.new()
	_subtab_bar.visible = false
	_subtab_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(14, 8.0, 8.0))
	root_vbox.add_child(_subtab_bar)

	_subtab_row = HBoxContainer.new()
	_subtab_row.add_theme_constant_override("separation", 8)
	_subtab_bar.add_child(_subtab_row)

	# 5. Other Player Social Action Bar
	_other_actions_holder = VBoxContainer.new()
	_other_actions_holder.visible = false
	_other_actions_holder.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_other_actions_holder)

	# 6. Scrollable Main Body
	_scroll_body = ScrollContainer.new()
	_scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll_body)

	_body_vbox = VBoxContainer.new()
	_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_vbox.add_theme_constant_override("separation", 12)
	_scroll_body.add_child(_body_vbox)


func open_for_user(user_dict: Dictionary, role_text: String = "") -> void:
	z_index = maxi(z_index, 60)
	move_to_front()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_base_user_dict = user_dict.duplicate(true)
	_public_profile = {}
	_current_role_text = role_text
	_current_user_id = str(user_dict.get("_id", user_dict.get("id", user_dict.get("user_id", ""))))
	var my_uid := str(GameManager.get_user_id())
	_is_self = (_current_user_id == my_uid or _current_user_id.is_empty()) and GameManager.is_logged_in and not GameManager.is_guest
	_is_bot = _current_user_id.begins_with("bot_") or _current_user_id.begins_with("test_bot")
	if _is_self and _current_user_id.is_empty():
		_current_user_id = my_uid

	_active_self_tab = "overview"
	_lbl_title.text = "پروفایل من" if _is_self else "مشخصات بازیکن"
	_btn_copy_id.visible = not _current_user_id.is_empty() and not _is_bot
	if is_instance_valid(_toast_panel):
		_toast_panel.visible = false

	_render_hero_plaque(_base_user_dict)
	_rebuild_controls_bar()
	_render_body_tab()

	if not _current_user_id.is_empty() and not _is_bot and not GameManager.token.is_empty():
		var req_uid := _current_user_id
		NetworkManager.api.get_public_profile(req_uid, func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				_public_profile = data["result"]
				_render_hero_plaque(_public_profile)
				_rebuild_controls_bar()
				_render_body_tab()
			elif not _base_user_dict.has("history"):
				_fallback_load_user_history(req_uid)
		)
	elif _is_self and not _current_user_id.is_empty():
		_fallback_load_user_history(_current_user_id)

	ActionVFXManager.animate_dialog_open(panel, self, true)


func _fallback_load_user_history(req_uid: String) -> void:
	NetworkManager.api.get_user_data(req_uid, func(success: bool, _code: int, data: Variant):
		if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
			return
		if success and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var res: Dictionary = data["result"]
			if res.has("history") and typeof(res["history"]) == TYPE_DICTIONARY:
				_base_user_dict["history"] = res["history"]
				if _active_self_tab == "overview":
					_render_body_tab()
	)


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(panel, self, func():
		visible = false
		closed.emit()
	)


func _show_profile_toast(txt: String, col: Color = CafeSocialTheme.COL_EMERALD_TEXT) -> void:
	if not is_instance_valid(_toast_panel) or not is_instance_valid(_lbl_toast):
		return
	_lbl_toast.text = txt
	_lbl_toast.add_theme_color_override("font_color", col)
	_toast_panel.visible = true
	get_tree().create_timer(3.4).timeout.connect(func():
		if is_instance_valid(_toast_panel) and is_instance_valid(_lbl_toast) and _lbl_toast.text == txt:
			_toast_panel.visible = false
	)


func _effective_data() -> Dictionary:
	if not _public_profile.is_empty():
		return _public_profile
	return _base_user_dict


func _render_hero_plaque(src: Dictionary) -> void:
	for c in _hero_holder.get_children():
		c.queue_free()

	var uname := str(src.get("name", src.get("username", "بازیکن کافه فکر")))
	var av_id := int(src.get("image", src.get("user_image", src.get("avatar", 0))))
	var frame_id := int(src.get("profile_frame", 0))
	var score_val := int(src.get("score", src.get("user_score", 0)))
	var xp_val := int(float(src.get("xp", src.get("user_xp", 0))))
	var lvl_val := GameManager.calculate_level(xp_val) if xp_val > 0 else int(src.get("level", 1))
	var lvl_info := GameManager.get_level_info(xp_val)
	var coin_val := int(src.get("coin", src.get("user_coin", src.get("coins", GameManager.get_coins() if _is_self else 0))))
	var p_title := str(src.get("profile_title", ""))
	var p_status := str(src.get("status_message", ""))
	var friends_cnt := int(src.get("friends_count", 0))

	var pres: Dictionary = src.get("presence", {}) if typeof(src.get("presence")) == TYPE_DICTIONARY else {}
	var pres_status := str(pres.get("status", src.get("status", "online" if _is_self else "offline")))
	var p_info := CafeSocialTheme.format_presence(pres if not pres.is_empty() else {"status": pres_status})

	var tier: Dictionary = src.get("tier", {}) if typeof(src.get("tier")) == TYPE_DICTIONARY else {}
	var tier_txt := "%s %s" % [str(tier.get("icon", "")), str(tier.get("title_fa", ""))] if not tier.is_empty() else ""

	var clan_d: Dictionary = src.get("clan", {}) if typeof(src.get("clan")) == TYPE_DICTIONARY else {}

	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false))
	_hero_holder.add_child(plaque)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	plaque.add_child(pv)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	pv.add_child(top_row)

	# Left Info Column
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 5)
	top_row.add_child(info_col)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 8)
	info_col.add_child(name_row)

	if not _is_bot and not _is_self:
		name_row.add_child(CafeSocialTheme.make_badge_pill(p_info["text"], p_info["color"], Color(0.08, 0.05, 0.03), p_info["dot_color"], 17))

	var nm_lbl := CafeSocialTheme.make_title(uname, 32, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
	nm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nm_lbl)

	if not _current_role_text.is_empty():
		var r_col := CafeSocialTheme.COL_GOLD_BRIGHT
		if _current_role_text.contains("قرمز") or _current_role_text.contains("۱"):
			r_col = Color(1.0, 0.48, 0.48)
		elif _current_role_text.contains("آبی") or _current_role_text.contains("۲"):
			r_col = Color(0.48, 0.80, 1.0)
		info_col.add_child(CafeSocialTheme.make_body(_current_role_text, 20, r_col, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var tags_row := HBoxContainer.new()
	tags_row.alignment = BoxContainer.ALIGNMENT_END
	tags_row.add_theme_constant_override("separation", 8)
	var has_tag := false
	if not p_title.is_empty():
		has_tag = true
		tags_row.add_child(CafeSocialTheme.make_badge_pill(p_title, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.14, 0.09, 0.04), CafeSocialTheme.COL_GOLD_ANTIQUE, 18))
	if not tier_txt.strip_edges().is_empty():
		has_tag = true
		tags_row.add_child(CafeSocialTheme.make_badge_pill(tier_txt.strip_edges(), CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 18))
	if not clan_d.is_empty():
		has_tag = true
		var c_str := "%s [%s]" % [str(clan_d.get("name", "")), str(clan_d.get("tag", ""))]
		tags_row.add_child(CafeSocialTheme.make_badge_pill(c_str, CafeSocialTheme.COL_WARM_CREAM, Color(0.18, 0.12, 0.07), CafeSocialTheme.COL_BRONZE_BORDER, 18))
	if has_tag:
		info_col.add_child(tags_row)

	if not p_status.is_empty():
		info_col.add_child(CafeSocialTheme.make_body("«%s»" % p_status, 19, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	# Right Avatar Plaque
	top_row.add_child(CafeSocialTheme.make_avatar_badge(av_id, frame_id, 114.0, pres_status, not _is_bot))

	# Bottom Stat Medallions Strip (Score, Level, Coins if self / Friends if public)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 10)
	pv.add_child(stat_row)

	var make_stat_chip := func(label_txt: String, val_txt: String, icon_tex: Texture2D, accent: Color) -> PanelContainer:
		var sp := PanelContainer.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(14, 10.0, 8.0))
		var sr := HBoxContainer.new()
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.add_theme_constant_override("separation", 8)
		sp.add_child(sr)
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 0)
		sv.add_child(CafeSocialTheme.make_title(val_txt, 25, accent, HORIZONTAL_ALIGNMENT_CENTER, false))
		sv.add_child(CafeSocialTheme.make_body(label_txt, 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false))
		sr.add_child(sv)
		if icon_tex != null:
			var ic := TextureRect.new()
			ic.texture = icon_tex
			ic.custom_minimum_size = Vector2(36, 36)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sr.add_child(ic)
		return sp

	stat_row.add_child(make_stat_chip.call("امتیاز کافه", GameManager.to_fa_num(score_val), CafeSocialTheme.ICO_CUP, CafeSocialTheme.COL_GOLD_BRIGHT))
	stat_row.add_child(make_stat_chip.call("سطح بازیکن", GameManager.to_fa_num(lvl_val), CafeSocialTheme.BADGE_LEVEL, CafeSocialTheme.COL_EMERALD_TEXT))
	if _is_self:
		stat_row.add_child(make_stat_chip.call("سکه شما", GameManager.to_fa_num(coin_val), CafeSocialTheme.ICO_COIN, CafeSocialTheme.COL_GOLD_BRIGHT))
	else:
		stat_row.add_child(make_stat_chip.call("دوستان", GameManager.to_fa_num(friends_cnt), CafeSocialTheme.ICO_LOBBY, CafeSocialTheme.COL_WARM_CREAM))

	if xp_val > 0:
		pv.add_child(CafeSocialTheme.make_xp_progress_bar(
			float(lvl_info.get("progress", 0.0)),
			"پیشرفت سطح %s: %s٪" % [GameManager.to_fa_num(lvl_val), GameManager.to_fa_num(int(lvl_info.get("percent_int", 0)))],
			Color(0.32, 0.82, 0.48)
		))


func _rebuild_controls_bar() -> void:
	for c in _subtab_row.get_children():
		c.queue_free()
	for c in _other_actions_holder.get_children():
		c.queue_free()

	if _is_bot:
		_subtab_bar.visible = false
		_other_actions_holder.visible = false
		return

	if _is_self:
		_subtab_bar.visible = true
		_other_actions_holder.visible = false
		var tabs := [
			{"id": "overview", "label": "آمار و افتخارات"},
			{"id": "cosmetics", "label": "ظاهر و پروفایل"},
			{"id": "privacy", "label": "حریم خصوصی و مسدودها"},
		]
		for td in tabs:
			var tid: String = td["id"]
			var btn := CafeSocialTheme.make_subtab(td["label"], _active_self_tab == tid, 0)
			btn.pressed.connect(func():
				AudioManager.sfx_tap()
				_active_self_tab = tid
				_rebuild_controls_bar()
				_render_body_tab()
			)
			_subtab_row.add_child(btn)
	else:
		_subtab_bar.visible = false
		_other_actions_holder.visible = true
		_build_other_player_actions()


func _build_other_player_actions() -> void:
	if not GameManager.is_logged_in or GameManager.is_guest:
		return

	var prof := _effective_data()
	var uname := str(prof.get("username", prof.get("name", "بازیکن")))
	var rel := str(prof.get("relationship", "none"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_other_actions_holder.add_child(row)

	var extra_row := HBoxContainer.new()
	extra_row.visible = false
	extra_row.add_theme_constant_override("separation", 8)

	var b_more := CafeSocialTheme.make_button("بیشتر", "muted", Vector2(96, 52), 20)
	b_more.pressed.connect(func():
		AudioManager.sfx_tap()
		extra_row.visible = not extra_row.visible
	)
	row.add_child(b_more)

	# Contextual relationship button
	if rel == "friend":
		var p_fr := CafeSocialTheme.make_badge_pill("✓ دوست شما", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 20)
		p_fr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p_fr)
	elif rel == "request_sent":
		var p_sent := CafeSocialTheme.make_badge_pill("درخواست ارسال شد", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.14, 0.06), CafeSocialTheme.COL_GOLD_ANTIQUE, 19)
		p_sent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p_sent)
	elif rel == "request_received":
		var b_acc := CafeSocialTheme.make_button("پذیرش دوستی", "emerald", Vector2(0, 52), 20, CafeSocialTheme.ICO_CHECK)
		b_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			b_acc.disabled = true
			NetworkManager.api.get_friend_requests(func(ok: bool, _c: int, data: Variant):
				var req_id := ""
				if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
					var inc: Array = data["result"].get("incoming", [])
					for r in inc:
						if typeof(r) == TYPE_DICTIONARY and typeof(r.get("user")) == TYPE_DICTIONARY:
							if str(r["user"].get("user_id", "")) == _current_user_id:
								req_id = str(r.get("request_id", ""))
								break
				if not req_id.is_empty():
					NetworkManager.api.respond_friend_request(req_id, "accept", func(ok2: bool, _c2: int, _d2: Variant):
						if ok2:
							_public_profile["relationship"] = "friend"
							_rebuild_controls_bar()
							_show_profile_toast("«%s» به دوستان شما اضافه شد!" % uname)
					)
				else:
					b_acc.disabled = false
			)
		)
		row.add_child(b_acc)
	else:
		var b_add := CafeSocialTheme.make_button("افزودن دوست", "emerald", Vector2(0, 52), 20, CafeSocialTheme.BADGE_PLUS)
		b_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_add.pressed.connect(func():
			AudioManager.sfx_button()
			b_add.disabled = true
			NetworkManager.api.send_friend_request(_current_user_id, "", func(ok: bool, _c: int, d: Variant):
				if ok:
					_public_profile["relationship"] = "request_sent"
					_rebuild_controls_bar()
					_show_profile_toast("درخواست دوستی ارسال شد.")
				else:
					b_add.disabled = false
					var msg := str(d.get("detail", "خطا در ارسال درخواست")) if typeof(d) == TYPE_DICTIONARY else "خطا در ارسال درخواست"
					_show_profile_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		row.add_child(b_add)

	if not GameManager.is_game_active:
		var b_dm := CafeSocialTheme.make_button("پیام خصوصی", "sapphire", Vector2(0, 52), 20, CafeSocialTheme.BADGE_CHAT)
		b_dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			var target_uid := _current_user_id
			close()
			var s_dlg := get_tree().root.find_child("SocialDialog", true, false)
			if s_dlg and s_dlg.has_method("open_direct_message_with"):
				s_dlg.open_direct_message_with(target_uid, uname)
		)
		row.add_child(b_dm)

		var b_ginv := CafeSocialTheme.make_button("دعوت بازی", "gold", Vector2(0, 52), 20, CafeSocialTheme.ICO_RANK)
		b_ginv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_ginv.pressed.connect(func():
			AudioManager.sfx_tap()
			CafeSocialTheme.show_game_invite_modal(self, _current_user_id, uname, func(gtitle: String):
				_show_profile_toast("دعوت‌نامه «%s» برای %s ارسال شد." % [gtitle, uname])
			)
		)
		row.add_child(b_ginv)

	_other_actions_holder.add_child(extra_row)

	var b_clan := CafeSocialTheme.make_button("دعوت به کلن من", "bronze", Vector2(0, 48), 19, CafeSocialTheme.ICO_ARMY)
	b_clan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_clan.pressed.connect(func():
		AudioManager.sfx_tap()
		NetworkManager.api.invite_to_clan(_current_user_id, func(ok: bool, _c: int, d: Variant):
			if ok:
				_show_profile_toast("دعوت‌نامه عضویت در کلن ارسال شد.")
			else:
				var msg := str(d.get("detail", "امکان دعوت به کلن وجود ندارد")) if typeof(d) == TYPE_DICTIONARY else "خطا"
				_show_profile_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	extra_row.add_child(b_clan)

	var b_blk := CafeSocialTheme.make_button("مسدود کردن", "muted", Vector2(0, 48), 19)
	b_blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_blk.pressed.connect(func():
		CafeSocialTheme.show_confirm_modal(
			self, "مسدود کردن بازیکن",
			"آیا می‌خواهید «%s» را مسدود کنید؟ امکان پیام و دعوت بازی بین شما بسته خواهد شد." % uname,
			"مسدود شود", true,
			func():
				NetworkManager.api.block_player(_current_user_id, "Blocked from profile", func(ok: bool, _c: int, _d: Variant):
					if ok:
						_show_profile_toast("«%s» مسدود شد." % uname)
						get_tree().create_timer(1.0).timeout.connect(func():
							if is_instance_valid(self) and visible:
								close()
						)
				)
		)
	)
	extra_row.add_child(b_blk)

	var b_rep := CafeSocialTheme.make_button("گزارش تخلف", "crimson", Vector2(0, 48), 19)
	b_rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rep.pressed.connect(func():
		CafeSocialTheme.show_report_modal(self, "player", _current_user_id, uname, func(ok: bool):
			if ok:
				_show_profile_toast("گزارش شما با موفقیت ثبت شد.")
		)
	)
	extra_row.add_child(b_rep)


func _render_body_tab() -> void:
	for c in _body_vbox.get_children():
		c.queue_free()

	if _is_self:
		match _active_self_tab:
			"cosmetics":
				_render_self_cosmetics_tab()
			"privacy":
				_render_self_privacy_tab()
			_:
				_render_overview_tab()
	else:
		_render_overview_tab()


# ==============================================================================
# TAB 1: OVERVIEW, STATS, ACHIEVEMENTS & MATCH HISTORY
# ==============================================================================

func _render_overview_tab() -> void:
	var prof := _effective_data()

	# 1. Social & Competitive Summary Strip
	if typeof(prof.get("stats")) == TYPE_DICTIONARY and not prof["stats"].is_empty():
		var st: Dictionary = prof["stats"]
		_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"خلاصه عملکرد", CafeSocialTheme.ICO_RANKING
		))

		var sum_row := HBoxContainer.new()
		sum_row.add_theme_constant_override("separation", 8)
		_body_vbox.add_child(sum_row)

		var sum_items := [
			{"l": "مسابقات", "v": GameManager.to_fa_num(int(st.get("total_matches", 0))), "c": CafeSocialTheme.COL_IVORY},
			{"l": "پیروزی‌ها", "v": GameManager.to_fa_num(int(st.get("total_wins", 0))), "c": CafeSocialTheme.COL_EMERALD_TEXT},
			{"l": "نرخ برد", "v": "%s٪" % GameManager.to_fa_num(st.get("win_rate", 0)), "c": CafeSocialTheme.COL_GOLD_BRIGHT},
			{"l": "دوستان", "v": GameManager.to_fa_num(int(prof.get("friends_count", 0))), "c": CafeSocialTheme.COL_WARM_CREAM},
		]
		for si in sum_items:
			var c := PanelContainer.new()
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14, 2, 10.0, 10.0))
			var cv := VBoxContainer.new()
			cv.alignment = BoxContainer.ALIGNMENT_CENTER
			cv.add_child(CafeSocialTheme.make_title(si["v"], 26, si["c"], HORIZONTAL_ALIGNMENT_CENTER, false))
			cv.add_child(CafeSocialTheme.make_body(si["l"], 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false))
			c.add_child(cv)
			sum_row.add_child(c)

		# Most Played Games
		var favs: Array = st.get("most_played_games", []) if typeof(st.get("most_played_games")) == TYPE_ARRAY else []
		if not favs.is_empty():
			_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("بازی‌های محبوب", CafeSocialTheme.ICO_CUP))
			var fav_row := HBoxContainer.new()
			fav_row.add_theme_constant_override("separation", 8)
			_body_vbox.add_child(fav_row)
			for fg in favs:
				if typeof(fg) != TYPE_DICTIONARY:
					continue
				var gtype := str(fg.get("game_type", ""))
				var g_card := PanelContainer.new()
				g_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				g_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
				var gr := HBoxContainer.new()
				gr.add_theme_constant_override("separation", 10)
				g_card.add_child(gr)
				var gv := VBoxContainer.new()
				gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				gv.add_child(CafeSocialTheme.make_title(GameRegistry.get_display_name_fa(gtype), 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
				gv.add_child(CafeSocialTheme.make_body("%s بازی • %s٪ برد" % [
					GameManager.to_fa_num(int(fg.get("total_matches", 0))),
					GameManager.to_fa_num(fg.get("win_rate", 0))
				], 17, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, true))
				gr.add_child(gv)
				var th := TextureRect.new()
				th.texture = CafeSocialTheme.get_game_thumb(gtype)
				th.custom_minimum_size = Vector2(48, 48)
				th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				gr.add_child(th)
				fav_row.add_child(g_card)

	# 2. Achievements
	var achs: Array = prof.get("achievements", []) if typeof(prof.get("achievements")) == TYPE_ARRAY else []
	if not achs.is_empty():
		_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"دستاوردهای کسب‌شده", CafeSocialTheme.ICO_FIRST, "%s مدال افتخار" % GameManager.to_fa_num(achs.size())
		))
		var ach_grid := GridContainer.new()
		ach_grid.columns = 2
		ach_grid.add_theme_constant_override("h_separation", 8)
		ach_grid.add_theme_constant_override("v_separation", 8)
		_body_vbox.add_child(ach_grid)
		for ach in achs:
			if typeof(ach) != TYPE_DICTIONARY:
				continue
			var ac := PanelContainer.new()
			ac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ac.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false))
			var av := VBoxContainer.new()
			av.add_theme_constant_override("separation", 4)
			ac.add_child(av)
			av.add_child(CafeSocialTheme.make_title(str(ach.get("title", "")), 22, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
			av.add_child(CafeSocialTheme.make_body(str(ach.get("desc", "")), 17, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
			ach_grid.add_child(ac)

	# 3. Detailed Games History Matrix (Existing Cafe Fekr Helper)
	var hist_dict: Dictionary = prof.get("history", {}) if typeof(prof.get("history")) == TYPE_DICTIONARY else {}
	if not hist_dict.is_empty():
		var hist_wrap := PanelContainer.new()
		hist_wrap.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_DEEP, CafeSocialTheme.COL_BRONZE_BORDER, 18, 2, 16.0, 14.0))
		_body_vbox.add_child(hist_wrap)
		var hist_vbox := VBoxContainer.new()
		hist_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hist_vbox.add_theme_constant_override("separation", 12)
		hist_wrap.add_child(hist_vbox)
		GamesHistoryViewHelper.populate_games_history(hist_vbox, hist_dict)
	elif not _is_bot:
		_body_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت آمار بازی‌ها..."))


# ==============================================================================
# TAB 2 (SELF): COSMETICS, AVATAR, TITLE, STATUS & USERNAME
# ==============================================================================

func _render_self_cosmetics_tab() -> void:
	var prof := _effective_data()

	# Account Card: Change Username
	var acc_card := PanelContainer.new()
	acc_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	_body_vbox.add_child(acc_card)
	var acc_row := HBoxContainer.new()
	acc_row.add_theme_constant_override("separation", 12)
	acc_card.add_child(acc_row)

	var btn_rename := CafeSocialTheme.make_button("تغییر نام کاربری", "gold", Vector2(210, 56), 21, CafeSocialTheme.ICO_SETTING)
	btn_rename.pressed.connect(func():
		AudioManager.sfx_tap()
		close()
		change_username_requested.emit()
	)
	acc_row.add_child(btn_rename)

	var acc_col := VBoxContainer.new()
	acc_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc_col.alignment = BoxContainer.ALIGNMENT_CENTER
	acc_row.add_child(acc_col)
	acc_col.add_child(CafeSocialTheme.make_title("حساب کاربری: %s" % GameManager.get_username(), 25, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var ph := GameManager.get_phone()
	acc_col.add_child(CafeSocialTheme.make_body("شماره همراه: %s" % (GameManager.to_fa_num(ph) if not ph.is_empty() else "ثبت‌شده"), 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

	# 27-Avatar Selector Grid
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"انتخاب تصویر پروفایل (آواتار)", CafeSocialTheme.ICO_SPARKLE, "آواتار دلخواه خود را انتخاب و ذخیره کنید"
	))
	var av_card := PanelContainer.new()
	av_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	_body_vbox.add_child(av_card)

	var av_vbox := VBoxContainer.new()
	av_vbox.add_theme_constant_override("separation", 12)
	av_card.add_child(av_vbox)

	var sel_avatar := [GameManager.get_avatar_id()]
	var av_grid := GridContainer.new()
	av_grid.columns = 5
	av_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av_grid.add_theme_constant_override("h_separation", 10)
	av_grid.add_theme_constant_override("v_separation", 10)
	av_vbox.add_child(av_grid)

	var av_btns: Dictionary = {}
	var refresh_av := func():
		for aid in av_btns.keys():
			var ab: Button = av_btns[aid]
			var is_sel: bool = (aid == sel_avatar[0])
			ab.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.16, 0.08) if is_sel else Color(0.10, 0.06, 0.03),
				CafeSocialTheme.COL_GOLD_BRIGHT if is_sel else CafeSocialTheme.COL_BRONZE_BORDER,
				14, 3 if is_sel else 1, 6.0, 6.0
			))
			ab.add_theme_stylebox_override("hover", ab.get_theme_stylebox("normal"))

	for idx in range(27):
		var av_p := "res://assets/icons/Avatars/%d.png" % idx
		if not ResourceLoader.exists(av_p):
			continue
		var ab := Button.new()
		ab.custom_minimum_size = Vector2(118, 118)
		ab.focus_mode = Control.FOCUS_NONE
		ab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.texture = load(av_p)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ab.add_child(tr)
		ab.pressed.connect(func():
			AudioManager.sfx_tap()
			sel_avatar[0] = idx
			refresh_av.call()
		)
		av_btns[idx] = ab
		av_grid.add_child(ab)
	refresh_av.call()

	var b_save_av := CafeSocialTheme.make_button("ذخیره تصویر انتخاب‌شده", "emerald", Vector2(0, 56), 22, CafeSocialTheme.ICO_CHECK)
	b_save_av.pressed.connect(func():
		AudioManager.sfx_button()
		b_save_av.disabled = true
		var chosen: int = sel_avatar[0]
		NetworkManager.api.update_avatar(chosen, func(ok: bool, _c: int, _d: Variant):
			if is_instance_valid(b_save_av):
				b_save_av.disabled = false
			if ok:
				GameManager.user_data["image"] = chosen
				GameManager.user_data["avatar"] = chosen
				GameManager.set_session(GameManager.token, GameManager.user_data, true)
				_base_user_dict["image"] = chosen
				if not _public_profile.is_empty():
					_public_profile["image"] = chosen
				_render_hero_plaque(_effective_data())
				_show_profile_toast("تصویر پروفایل با موفقیت تغییر یافت!")
			else:
				_show_profile_toast("خطا در تغییر تصویر پروفایل", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	av_vbox.add_child(b_save_av)

	# Frame, Title, Status Message Customization
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"قاب آواتار، لقب افتخاری و وضعیت", CafeSocialTheme.ICO_KING
	))
	var cos_card := PanelContainer.new()
	cos_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	_body_vbox.add_child(cos_card)

	var cos_v := VBoxContainer.new()
	cos_v.add_theme_constant_override("separation", 12)
	cos_card.add_child(cos_v)

	# Frame Picker
	cos_v.add_child(CafeSocialTheme.make_body("قاب نمایشی پروفایل:", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var sel_frame := [int(prof.get("profile_frame", 0))]
	var frame_grid := GridContainer.new()
	frame_grid.columns = 3
	frame_grid.add_theme_constant_override("h_separation", 8)
	frame_grid.add_theme_constant_override("v_separation", 8)
	cos_v.add_child(frame_grid)

	var frame_btns: Dictionary = {}
	var refresh_frames := func():
		for fid in frame_btns.keys():
			var fb: Button = frame_btns[fid]
			var is_sel: bool = (fid == sel_frame[0])
			var fcfg: Dictionary = CafeSocialTheme.PROFILE_FRAMES[clampi(fid, 0, CafeSocialTheme.PROFILE_FRAMES.size() - 1)]
			fb.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.22, 0.14, 0.08) if is_sel else CafeSocialTheme.COL_WALNUT_DEEP,
				fcfg["border"] if is_sel else CafeSocialTheme.COL_BRONZE_BORDER,
				12, 3 if is_sel else 1, 10.0, 10.0
			))
			fb.add_theme_stylebox_override("hover", fb.get_theme_stylebox("normal"))

	for fcfg in CafeSocialTheme.PROFILE_FRAMES:
		var fid: int = int(fcfg["id"])
		var fb := CafeSocialTheme.make_button(str(fcfg["name"]), "muted", Vector2(0, 52), 19)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func():
			AudioManager.sfx_tap()
			sel_frame[0] = fid
			refresh_frames.call()
		)
		frame_btns[fid] = fb
		frame_grid.add_child(fb)
	refresh_frames.call()

	cos_v.add_child(CafeSocialTheme.make_body("لقب افتخاری (نمایش در کنار نام شما):", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var inp_title := CafeSocialTheme.make_line_edit("مثلاً: استاد منچ و مونوپولی", 58.0, 21)
	inp_title.text = str(prof.get("profile_title", ""))
	cos_v.add_child(inp_title)

	# Quick Honor Title presets
	var title_chips := HBoxContainer.new()
	title_chips.add_theme_constant_override("separation", 6)
	cos_v.add_child(title_chips)
	for preset in ["استاد استراتژی", "قهرمان کافه", "گرگ مونوپولی", "سلطان شطرنج"]:
		var pt: String = preset
		var pb := CafeSocialTheme.make_button(pt, "bronze", Vector2(0, 42), 17)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func():
			AudioManager.sfx_tap()
			inp_title.text = pt
		)
		title_chips.add_child(pb)

	cos_v.add_child(CafeSocialTheme.make_body("پیام وضعیت شخصی:", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var inp_status := CafeSocialTheme.make_line_edit("مثلاً: آماده یک رقابت دو نفره جذاب!", 58.0, 21)
	inp_status.text = str(prof.get("status_message", ""))
	cos_v.add_child(inp_status)

	var b_save_cos := CafeSocialTheme.make_button("ذخیره ظاهر و مشخصات", "gold", Vector2(0, 62), 24, CafeSocialTheme.ICO_CHECK, true)
	b_save_cos.pressed.connect(func():
		AudioManager.sfx_button()
		b_save_cos.disabled = true
		NetworkManager.api.customize_my_profile({
			"profile_frame": sel_frame[0],
			"profile_title": inp_title.text.strip_edges(),
			"status_message": inp_status.text.strip_edges()
		}, func(ok: bool, _c: int, data: Variant):
			if is_instance_valid(b_save_cos):
				b_save_cos.disabled = false
			if ok:
				if typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
					_public_profile = data["result"]
				_render_hero_plaque(_effective_data())
				_show_profile_toast("ظاهر پروفایل با موفقیت ذخیره شد!")
			else:
				_show_profile_toast("خطا در ذخیره ظاهر پروفایل", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	cos_v.add_child(b_save_cos)


# ==============================================================================
# TAB 3 (SELF): PRIVACY SETTINGS, NOTIFICATION PREFS & BLOCKED PLAYERS
# ==============================================================================

func _render_self_privacy_tab() -> void:
	var prof := _effective_data()
	var priv: Dictionary = prof.get("privacy", {}) if typeof(prof.get("privacy")) == TYPE_DICTIONARY else {}

	# 1. Privacy Card
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"تنظیمات حریم خصوصی", CafeSocialTheme.ICO_SETTING, "کنترل پیام‌ها، درخواست‌ها و نمایش فعالیت"
	))
	var priv_card := PanelContainer.new()
	priv_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	_body_vbox.add_child(priv_card)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	priv_card.add_child(pv)

	var make_check := func(txt: String, checked: bool) -> CheckBox:
		var chk := CheckBox.new()
		chk.text = txt
		chk.button_pressed = checked
		chk.focus_mode = Control.FOCUS_NONE
		chk.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		chk.add_theme_font_size_override("font_size", 21)
		chk.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		return chk

	var chk_freq: CheckBox = make_check.call("دریافت درخواست دوستی از بازیکنان", bool(priv.get("allow_friend_requests", true)))
	var chk_last: CheckBox = make_check.call("نمایش وضعیت آنلاین و آخرین بازدید به دیگران", bool(priv.get("show_last_seen", true)))
	var chk_game: CheckBox = make_check.call("نمایش بازی فعال و اجازه تماشا توسط دوستان", bool(priv.get("show_current_game", true)))
	var chk_hist: CheckBox = make_check.call("نمایش سوابق و تاریخچه مسابقات در پروفایل عمومی", bool(priv.get("show_match_history", true)))
	pv.add_child(chk_freq)
	pv.add_child(chk_last)
	pv.add_child(chk_game)
	pv.add_child(chk_hist)

	pv.add_child(CafeSocialTheme.make_body("چه کسانی بتوانند برای شما پیام خصوصی بفرستند؟", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var dm_policy := [str(priv.get("allow_dms", "everyone"))]
	if dm_policy[0] not in ["everyone", "friends", "none"]:
		dm_policy[0] = "everyone"

	var dm_row := HBoxContainer.new()
	dm_row.add_theme_constant_override("separation", 8)
	pv.add_child(dm_row)
	var dm_btns: Dictionary = {}
	var refresh_dm_btns := func():
		for dk in dm_btns.keys():
			var b: Button = dm_btns[dk]
			var act: bool = (dk == dm_policy[0])
			b.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 12))
			b.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 12))

	for dd in [{"id": "none", "l": "هیچ‌کس"}, {"id": "friends", "l": "فقط دوستان"}, {"id": "everyone", "l": "همه بازیکنان"}]:
		var did: String = dd["id"]
		var db := CafeSocialTheme.make_button(dd["l"], "muted", Vector2(0, 48), 19)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.pressed.connect(func():
			AudioManager.sfx_tap()
			dm_policy[0] = did
			refresh_dm_btns.call()
		)
		dm_btns[did] = db
		dm_row.add_child(db)
	refresh_dm_btns.call()

	var b_save_priv := CafeSocialTheme.make_button("ذخیره تنظیمات حریم خصوصی", "gold", Vector2(0, 56), 22, CafeSocialTheme.ICO_CHECK)
	b_save_priv.pressed.connect(func():
		AudioManager.sfx_button()
		b_save_priv.disabled = true
		NetworkManager.api.customize_my_profile({
			"privacy": {
				"allow_friend_requests": chk_freq.button_pressed,
				"allow_dms": dm_policy[0],
				"show_last_seen": chk_last.button_pressed,
				"show_current_game": chk_game.button_pressed,
				"show_match_history": chk_hist.button_pressed,
			}
		}, func(ok: bool, _c: int, data: Variant):
			if is_instance_valid(b_save_priv):
				b_save_priv.disabled = false
			if ok:
				if typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
					_public_profile = data["result"]
				_show_profile_toast("تنظیمات حریم خصوصی ذخیره شد.")
		)
	)
	pv.add_child(b_save_priv)

	# 2. Notification Preferences Card
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"تنظیمات اعلان‌ها", CafeSocialTheme.ICO_STAR
	))
	var np_card := PanelContainer.new()
	np_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	_body_vbox.add_child(np_card)

	var npv := VBoxContainer.new()
	npv.add_theme_constant_override("separation", 10)
	np_card.add_child(npv)

	var chk_n_fr: CheckBox = make_check.call("اعلان درخواست‌های دوستی", bool(_notif_prefs.get("friend_requests", true)))
	var chk_n_dm: CheckBox = make_check.call("اعلان پیام‌های خصوصی", bool(_notif_prefs.get("direct_messages", true)))
	var chk_n_gm: CheckBox = make_check.call("اعلان دعوت‌نامه‌های بازی", bool(_notif_prefs.get("game_invitations", true)))
	var chk_n_cl: CheckBox = make_check.call("اعلان رویدادها و دعوت کلن", bool(_notif_prefs.get("clan_events", true)))
	var chk_n_mn: CheckBox = make_check.call("اعلان اشاره (@) در چت کلن", bool(_notif_prefs.get("clan_chat_mentions", true)))
	npv.add_child(chk_n_fr)
	npv.add_child(chk_n_dm)
	npv.add_child(chk_n_gm)
	npv.add_child(chk_n_cl)
	npv.add_child(chk_n_mn)

	if not _notif_prefs_loaded:
		NetworkManager.api.get_notifications_list(false, func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				var prefs: Variant = data["result"].get("preferences")
				if typeof(prefs) == TYPE_DICTIONARY:
					_notif_prefs = prefs
					_notif_prefs_loaded = true
					if is_instance_valid(chk_n_fr):
						chk_n_fr.button_pressed = bool(_notif_prefs.get("friend_requests", true))
						chk_n_dm.button_pressed = bool(_notif_prefs.get("direct_messages", true))
						chk_n_gm.button_pressed = bool(_notif_prefs.get("game_invitations", true))
						chk_n_cl.button_pressed = bool(_notif_prefs.get("clan_events", true))
						chk_n_mn.button_pressed = bool(_notif_prefs.get("clan_chat_mentions", true))
		)

	var b_save_np := CafeSocialTheme.make_button("ذخیره ترجیحات اعلان‌ها", "emerald", Vector2(0, 54), 21, CafeSocialTheme.ICO_CHECK)
	b_save_np.pressed.connect(func():
		AudioManager.sfx_button()
		var payload := {
			"friend_requests": chk_n_fr.button_pressed,
			"direct_messages": chk_n_dm.button_pressed,
			"game_invitations": chk_n_gm.button_pressed,
			"clan_events": chk_n_cl.button_pressed,
			"clan_chat_mentions": chk_n_mn.button_pressed,
		}
		NetworkManager.api.update_notification_preferences(payload, func(ok: bool, _c: int, _d: Variant):
			if ok:
				_notif_prefs = payload
				_show_profile_toast("ترجیحات اعلان‌ها ذخیره شد.")
		)
	)
	npv.add_child(b_save_np)

	# 3. Blocked Players List
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"بازیکنان مسدودشده", CafeSocialTheme.ICO_CANCEL, "مدیریت بازیکنانی که مسدود کرده‌اید"
	))
	var blk_holder := VBoxContainer.new()
	blk_holder.add_theme_constant_override("separation", 8)
	blk_holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت فهرست مسدودها..."))
	_body_vbox.add_child(blk_holder)

	NetworkManager.api.get_blocked_players(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(blk_holder):
			return
		for c in blk_holder.get_children():
			c.queue_free()
		var arr: Array = data.get("result", []) if (ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY) else []
		if arr.is_empty():
			blk_holder.add_child(CafeSocialTheme.make_body("هیچ بازیکنی در فهرست مسدودهای شما نیست.", 20, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
			return
		for bu in arr:
			if typeof(bu) != TYPE_DICTIONARY:
				continue
			var bu_uid := str(bu.get("user_id", bu.get("_id", "")))
			var bu_name := str(bu.get("username", "بازیکن"))
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)

			var b_un := CafeSocialTheme.make_button("رفع مسدودیت", "emerald", Vector2(165, 48), 19)
			b_un.pressed.connect(func():
				AudioManager.sfx_tap()
				NetworkManager.api.unblock_player(bu_uid, func(ok_u: bool, _cu: int, _du: Variant):
					if ok_u:
						_show_profile_toast("مسدودیت «%s» برداشته شد." % bu_name)
						_render_body_tab()
				)
			)
			row.add_child(b_un)

			var nm := CafeSocialTheme.make_title(bu_name, 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)

			row.add_child(CafeSocialTheme.make_avatar_badge(int(bu.get("image", 0)), 0, 56.0))
			blk_holder.add_child(card)
	)
