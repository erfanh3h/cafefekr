class_name UserProfileDialog
extends Control

## Cafe Fekr — Premium Player Profile Dialog Redesign
## Visual Identity: Dark walnut wood surfaces, emerald green primary accents,
## rich antique gold and bronze ornamental details, warm cinematic lighting,
## RTL Persian typography, and high-quality 3D mobile game UI aesthetic.
##
## Reusable components integrated:
## - ProfileHeader
## - PlayerStatistics
## - PlayerActionButtons
## - RankingCard
## - FavoriteGameItem

static var active_instance: UserProfileDialog = null
static var _cached_my_clan_id: String = ""

static func show_user(user_dict_or_id: Variant, role_text: String = "", context_node: Node = null) -> UserProfileDialog:
	var u_dict: Dictionary = {}
	if typeof(user_dict_or_id) == TYPE_STRING:
		u_dict = {"_id": user_dict_or_id, "user_id": user_dict_or_id}
	elif typeof(user_dict_or_id) == TYPE_DICTIONARY:
		u_dict = user_dict_or_id
	else:
		return null

	if is_instance_valid(active_instance) and active_instance.is_inside_tree():
		active_instance.open_for_user(u_dict, role_text)
		return active_instance

	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var found = tree.root.find_child("UserProfileDialog", true, false)
		if is_instance_valid(found) and found is UserProfileDialog:
			active_instance = found
			active_instance.open_for_user(u_dict, role_text)
			return active_instance

	var scene = load("res://scenes/ui/profile/user_profile_dialog.tscn")
	if scene and context_node and context_node.is_inside_tree():
		var dlg = scene.instantiate() as UserProfileDialog
		context_node.get_tree().root.add_child(dlg)
		active_instance = dlg
		dlg.open_for_user(u_dict, role_text)
		return dlg

	return null

signal closed()
signal change_username_requested()

var _dim_overlay: ColorRect
var panel: PanelContainer
var _lbl_title: Label
var _toast_panel: PanelContainer
var _lbl_toast: Label

var _scroll_body: ScrollContainer
var _body_vbox: VBoxContainer

var _current_user_id: String = ""
var _current_role_text: String = ""
var _is_self: bool = false
var _is_bot: bool = false

var _base_user_dict: Dictionary = {}
var _public_profile: Dictionary = {}


func _ready() -> void:
	active_instance = self
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func _build_shell() -> void:
	for c in get_children():
		c.queue_free()

	# 1. Warm cinematic vignette dim overlay
	_dim_overlay = ColorRect.new()
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.color = Color(0.02, 0.012, 0.008, 0.82)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			close()
	)
	add_child(_dim_overlay)

	# 2. Outer MarginContainer (responsive portrait margins)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 14)
	outer.add_theme_constant_override("margin_right", 14)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)

	# 3. Main Antique Walnut Board Shell
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	outer.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 12)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inner)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	inner.add_child(root_vbox)

	# 4. Top Header Bar (Close Button + Dialog Title)
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 12.0, 8.0))
	root_vbox.add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_row)

	var btn_close := TextureButton.new()
	btn_close.name = "BtnCloseTop"
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(46, 46)
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

	_lbl_title = CafeSocialTheme.make_title("مشخصات بازیکن", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_lbl_title)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(46, 46)
	top_row.add_child(top_spacer)

	# 5. Toast Feedback Banner
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	root_vbox.add_child(_toast_panel)

	_lbl_toast = CafeSocialTheme.make_body("", 21, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(_lbl_toast)

	# 6. Scrollable Main Content Container
	_scroll_body = ScrollContainer.new()
	_scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll_body)

	_body_vbox = VBoxContainer.new()
	_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_vbox.add_theme_constant_override("separation", 10)
	_scroll_body.add_child(_body_vbox)


func open_for_user(user_dict: Dictionary, role_text: String = "") -> void:
	if not is_instance_valid(panel):
		_build_shell()

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

	_lbl_title.text = "مشخصات بازیکن"
	if is_instance_valid(_toast_panel):
		_toast_panel.visible = false

	# Ensure clan id is loaded to detect clanmates
	if _cached_my_clan_id.is_empty() and GameManager.is_logged_in and not GameManager.is_guest:
		NetworkManager.api.get_my_clan(func(ok: bool, _c: int, d: Variant):
			if ok and typeof(d) == TYPE_DICTIONARY and typeof(d.get("result")) == TYPE_DICTIONARY:
				var c_info = d["result"].get("clan")
				if typeof(c_info) == TYPE_DICTIONARY:
					_cached_my_clan_id = str(c_info.get("clan_id", c_info.get("_id", "")))
					if visible:
						_render_overview_tab()
		)

	_render_overview_tab()

	# Fetch full public profile
	if not _current_user_id.is_empty() and not _is_bot and not GameManager.token.is_empty():
		var req_uid := _current_user_id
		NetworkManager.api.get_public_profile(req_uid, func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				_public_profile = data["result"]
				_render_overview_tab()
			elif not _base_user_dict.has("history"):
				_fallback_load_user_history(req_uid)
		)
	elif _is_self and not _current_user_id.is_empty():
		_fallback_load_user_history(_current_user_id)

	if is_inside_tree():
		ActionVFXManager.animate_dialog_open(panel, self, true)


func _fallback_load_user_history(req_uid: String) -> void:
	NetworkManager.api.get_user_data(req_uid, func(success: bool, _code: int, data: Variant):
		if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
			return
		if success and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var res: Dictionary = data["result"]
			if res.has("history") and typeof(res["history"]) == TYPE_DICTIONARY:
				_base_user_dict["history"] = res["history"]
				_render_overview_tab()
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
	get_tree().create_timer(3.2).timeout.connect(func():
		if is_instance_valid(_toast_panel) and is_instance_valid(_lbl_toast) and _lbl_toast.text == txt:
			_toast_panel.visible = false
	)


func _effective_data() -> Dictionary:
	if not _public_profile.is_empty():
		return _public_profile
	return _base_user_dict


func _check_is_clanmate(prof: Dictionary) -> bool:
	if _is_self:
		return true
	var t_clan_d: Dictionary = prof.get("clan", {}) if typeof(prof.get("clan")) == TYPE_DICTIONARY else {}
	var t_clan_id: String = str(t_clan_d.get("clan_id", t_clan_d.get("_id", prof.get("clan_id", "")))).strip_edges()
	if t_clan_id.is_empty():
		return false

	var my_cid := ""
	if typeof(GameManager.user_data) == TYPE_DICTIONARY:
		my_cid = str(GameManager.user_data.get("clan_id", ""))
		if my_cid.is_empty() and typeof(GameManager.user_data.get("clan")) == TYPE_DICTIONARY:
			my_cid = str(GameManager.user_data["clan"].get("clan_id", GameManager.user_data["clan"].get("_id", "")))

	if not my_cid.is_empty():
		return my_cid == t_clan_id

	if not _cached_my_clan_id.is_empty():
		return _cached_my_clan_id == t_clan_id

	return false


# ==============================================================================
# UNIFIED GLOBAL USER DETAILS OVERVIEW
# ==============================================================================

func _render_overview_tab() -> void:
	for c in _body_vbox.get_children():
		c.queue_free()

	var prof := _effective_data()

	var score_val := int(prof.get("score", prof.get("user_score", 0)))
	var xp_val := int(float(prof.get("xp", prof.get("user_xp", 0))))
	var lvl_val := GameManager.calculate_level(xp_val) if xp_val > 0 else int(prof.get("level", 1))
	var friends_cnt := int(prof.get("friends_count", 0))
	var coin_val := int(prof.get("coin", prof.get("user_coin", prof.get("coins", GameManager.get_coins() if _is_self else 0))))
	var uname := str(prof.get("name", prof.get("username", "بازیکن")))
	var rel := str(prof.get("relationship", "none"))

	# --------------------------------------------------------------------------
	# A. Profile Header Component (Circle dot removed, no icon under name)
	# --------------------------------------------------------------------------
	var header := ProfileHeader.new()
	header.setup(prof, _current_role_text, _is_self, _is_bot)
	header.copy_id_requested.connect(func(copied_id: String):
		_show_profile_toast("شناسه بازیکن در حافظه کپی شد: %s" % GameManager.to_fa_num(copied_id))
	)
	header.view_clan_requested.connect(func(clan_id: String, clan_d: Dictionary):
		CafeSocialTheme.show_clan_details_modal(self, clan_id, clan_d)
	)
	_body_vbox.add_child(header)

	# --------------------------------------------------------------------------
	# D. Player Interactions (Action Area)
	# Circular icon buttons: add_friend.png, chat.png, game.png
	# Always visible; disabled if _is_self or if clanmate
	# --------------------------------------------------------------------------
	var pres_dict: Dictionary = prof.get("presence", {}) if typeof(prof.get("presence")) == TYPE_DICTIONARY else {"status": str(prof.get("status", "offline"))}
	var p_info: Dictionary = CafeSocialTheme.format_presence(pres_dict)
	var is_in_game: bool = bool(p_info.get("is_in_game", false))
	var is_clanmate: bool = _check_is_clanmate(prof)

	var actions := PlayerActionButtons.new()
	actions.setup(
		rel,
		_is_self,
		is_clanmate,
		is_in_game,
		not GameManager.is_game_active,
		not GameManager.is_game_active
	)

	# 1. Add friend action
	actions.add_friend_pressed.connect(func():
		if _is_self:
			return
		NetworkManager.api.send_friend_request(_current_user_id, "", func(ok: bool, _c: int, d: Variant):
			if ok:
				_public_profile["relationship"] = "request_sent"
				_show_profile_toast("درخواست دوستی ارسال شد.")
				_render_overview_tab()
			else:
				var msg := str(d.get("detail", "خطا در ارسال درخواست")) if typeof(d) == TYPE_DICTIONARY else "خطا در ارسال درخواست"
				_show_profile_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)

	# 2. Accept friend request
	actions.accept_friend_pressed.connect(func():
		if _is_self:
			return
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
						_show_profile_toast("«%s» به دوستان شما اضافه شد!" % uname)
						_render_overview_tab()
				)
		)
	)

	# 3. Direct Message
	actions.private_message_pressed.connect(func():
		if _is_self:
			return
		var target_uid := _current_user_id
		close()
		var s_dlg := get_tree().root.find_child("SocialDialog", true, false)
		if s_dlg and s_dlg.has_method("open_direct_message_with"):
			s_dlg.open_direct_message_with(target_uid, uname)
	)

	# 4. Game Invite
	actions.invite_to_game_pressed.connect(func():
		if _is_self:
			return
		CafeSocialTheme.show_game_invite_modal(self, _current_user_id, uname, func(gtitle: String):
			_show_profile_toast("دعوت‌نامه «%s» برای %s ارسال شد." % [gtitle, uname])
		)
	)

	# 5. Clan Invite
	actions.invite_to_clan_pressed.connect(func():
		if _is_self or is_clanmate:
			return
		NetworkManager.api.invite_to_clan(_current_user_id, func(ok: bool, _c: int, d: Variant):
			if ok:
				_show_profile_toast("دعوت‌نامه عضویت در کلن ارسال شد.")
			else:
				var msg := str(d.get("detail", "امکان دعوت به کلن وجود ندارد")) if typeof(d) == TYPE_DICTIONARY else "خطا"
				_show_profile_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)

	# 6. Spectate Live
	actions.spectate_live_pressed.connect(func():
		if _is_self:
			return
		var target_uid: String = _current_user_id
		var active_gid: String = str(p_info.get("game_id", prof.get("current_game_id", prof.get("game_id", ""))))
		close()
		NetworkManager.request_spectate_game(active_gid, target_uid)
	)

	# 7. Block Player
	actions.block_player_pressed.connect(func():
		if _is_self:
			return
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

	# 8. Report Player
	actions.report_player_pressed.connect(func():
		if _is_self:
			return
		CafeSocialTheme.show_report_modal(self, "player", _current_user_id, uname, func(ok: bool):
			if ok:
				_show_profile_toast("گزارش شما با موفقیت ثبت شد.")
		)
	)

	_body_vbox.add_child(actions)

	# --------------------------------------------------------------------------
	# B. Player Statistics Component (Zero icons in boxes)
	# --------------------------------------------------------------------------
	var stats_component := PlayerStatistics.new()
	stats_component.setup(score_val, lvl_val, friends_cnt, _is_self, coin_val)
	_body_vbox.add_child(stats_component)

	# --------------------------------------------------------------------------
	# Progression Bar removed as per requirement:
	# "we must not show current exp bar of an user to another users ! remove it ."
	# --------------------------------------------------------------------------

	# --------------------------------------------------------------------------
	# Clan Banner (If Clan Exists)
	# --------------------------------------------------------------------------
	var clan_d: Dictionary = prof.get("clan", {}) if typeof(prof.get("clan")) == TYPE_DICTIONARY else {}
	var clan_id_str := str(clan_d.get("clan_id", clan_d.get("_id", prof.get("clan_id", ""))))
	if not clan_d.is_empty() or not clan_id_str.is_empty():
		_render_clan_card(clan_id_str, clan_d)

	# --------------------------------------------------------------------------
	# E. Game Achievements & Rankings Section
	# --------------------------------------------------------------------------
	_render_rankings_and_achievements(prof)

	# --------------------------------------------------------------------------
	# F. Favorite Games Section
	# --------------------------------------------------------------------------
	_render_favorite_games_section(prof)


func _render_clan_card(clan_id: String, clan_d: Dictionary) -> void:
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("باشگاه و کلن بازیکن", CafeSocialTheme.ICO_ARMY))

	var c_card := PanelContainer.new()
	c_card.custom_minimum_size = Vector2(0, 108)
	c_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 16.0, 10.0))
	_body_vbox.add_child(c_card)

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	c_card.add_child(crow)

	var b_view_clan := CafeSocialTheme.make_button("مشاهده کلن", "gold", Vector2(110, 44), 18)
	b_view_clan.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b_view_clan.pressed.connect(func():
		AudioManager.sfx_button()
		CafeSocialTheme.show_clan_details_modal(self, clan_id, clan_d)
	)
	crow.add_child(b_view_clan)

	var cinfo := VBoxContainer.new()
	cinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinfo.alignment = BoxContainer.ALIGNMENT_CENTER
	cinfo.add_theme_constant_override("separation", 2)
	crow.add_child(cinfo)

	var cname := str(clan_d.get("name", "کلن کافه فکر"))
	var ctag := str(clan_d.get("tag", ""))
	var clvl := int(clan_d.get("clan_level", 1))
	var crole := str(clan_d.get("role", "member"))
	var crole_fa: String = str({"leader": "رهبر کلن", "co_leader": "قائم‌مقام رهبر", "elder": "ارشد کلن", "member": "عضو رسمی"}.get(crole, "عضو کلن"))

	var ctitle_row := HBoxContainer.new()
	ctitle_row.alignment = BoxContainer.ALIGNMENT_END
	ctitle_row.add_theme_constant_override("separation", 6)
	cinfo.add_child(ctitle_row)

	if not ctag.is_empty():
		ctitle_row.add_child(CafeSocialTheme.make_badge_pill("[%s]" % ctag, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.12, 0.08, 0.04), CafeSocialTheme.COL_GOLD_ANTIQUE, 16))

	var c_nm_lbl := CafeSocialTheme.make_title(cname, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	c_nm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_nm_lbl.clip_text = true
	c_nm_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ctitle_row.add_child(c_nm_lbl)

	cinfo.add_child(CafeSocialTheme.make_body("سمت: %s  •  سطح کلن: %s" % [crole_fa, GameManager.to_fa_num(clvl)], 17, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	var emb_id := int(clan_d.get("emblem_id", 1))
	var c_emb_node := CafeSocialTheme.make_clan_emblem(emb_id, 54.0)
	c_emb_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(c_emb_node)


func _render_rankings_and_achievements(prof: Dictionary) -> void:
	# Header with statistics.png icon as requested
	var stat_ico = load("res://assets/images/statistics.png")
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("آمار و رتبه‌بندی رقابتی", stat_ico))

	var st: Dictionary = prof.get("stats", {}) if typeof(prof.get("stats")) == TYPE_DICTIONARY else {}
	var hist: Dictionary = prof.get("history", {}) if typeof(prof.get("history")) == TYPE_DICTIONARY else {}

	var tot_wins := int(st.get("total_wins", 0))
	var tot_losses := int(st.get("total_losses", 0))
	var tot_draws := int(st.get("total_draws", 0))
	var tot_matches := int(st.get("total_matches", tot_wins + tot_losses + tot_draws))
	var win_rate := float(st.get("win_rate", 0.0))

	# 1. Overall Ranking Card (Icon removed as requested)
	var tier: Dictionary = prof.get("tier", {}) if typeof(prof.get("tier")) == TYPE_DICTIONARY else {}
	var tier_title := str(tier.get("title_fa", prof.get("rank_title", "تازه‌کار")))
	var score_val := int(prof.get("score", prof.get("user_score", 0)))
	var card_overall := RankingCard.new()
	card_overall.setup_mode(
		"رده‌بندی کلی و امتیاز کافه",
		"%s (%s)" % [tier_title, GameManager.to_fa_num(score_val)],
		tot_wins,
		tot_draws,
		tot_losses,
		null
	)
	_body_vbox.add_child(card_overall)

	# 2. 2-Player Rank Mode Card (Icon removed as requested)
	var win_rank := int(hist.get("win_rank", 0))
	var draw_rank := int(hist.get("draw_rank", 0))
	var lose_rank := int(hist.get("lose_rank", 0))
	if (win_rank + draw_rank + lose_rank) > 0:
		var card_rank := RankingCard.new()
		card_rank.setup_mode(
			"رده‌بندی دو نفره (Rank)",
			"حالت رقابتی",
			win_rank,
			draw_rank,
			lose_rank,
			null
		)
		_body_vbox.add_child(card_rank)

	# 3. Classic / AI Mode Card (کلاسیک تک‌نفره / هوش مصنوعی)
	var win_cr := int(hist.get("win_classic_rank", 0))
	var draw_cr := int(hist.get("draw_classic_rank", 0))
	var lose_cr := int(hist.get("lose_classic_rank", 0))
	if (win_cr + draw_cr + lose_cr) > 0:
		var card_cr := RankingCard.new()
		card_cr.setup_mode(
			"کلاسیک تک‌نفره (هوش مصنوعی)",
			"تمرین و مهارت",
			win_cr,
			draw_cr,
			lose_cr,
			null
		)
		_body_vbox.add_child(card_cr)

	# 4. Multiplayer Ranking Card (رده‌بندی چندنفره)
	var r1 := int(hist.get("rank1_multi_rank", 0))
	var r2 := int(hist.get("rank2_multi_rank", 0))
	var rn := int(hist.get("rankn_multi_rank", 0))
	if (r1 + r2 + rn) > 0:
		var card_mr := RankingCard.new()
		card_mr.setup_multiplayer(
			"رده‌بندی چندنفره (منچ، ریسک، اونو، مونوپولی)",
			"مسابقات تیمی و گروهی",
			r1,
			r2,
			rn,
			null
		)
		_body_vbox.add_child(card_mr)

	# 5. Achievements Showcase (if unlocked)
	var achs: Array = prof.get("achievements", []) if typeof(prof.get("achievements")) == TYPE_ARRAY else []
	if not achs.is_empty():
		_render_achievements_grid(achs)


func _render_achievements_grid(achs: Array) -> void:
	# Icon removed from header as requested
	var ach_header := CafeSocialTheme.make_ornate_section_header("دستاوردهای کسب‌شده", null, "%s نشان افتخار" % GameManager.to_fa_num(achs.size()))
	_body_vbox.add_child(ach_header)

	var ach_grid := GridContainer.new()
	ach_grid.columns = 2
	ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_grid.add_theme_constant_override("h_separation", 8)
	ach_grid.add_theme_constant_override("v_separation", 8)
	_body_vbox.add_child(ach_grid)

	for ach in achs:
		if typeof(ach) != TYPE_DICTIONARY:
			continue
		var ac := PanelContainer.new()
		ac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var asb := StyleBoxFlat.new()
		asb.bg_color = Color(0.14, 0.09, 0.05, 0.95)
		asb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
		asb.set_border_width_all(1)
		asb.set_corner_radius_all(10)
		asb.content_margin_left = 10.0
		asb.content_margin_right = 10.0
		asb.content_margin_top = 8.0
		asb.content_margin_bottom = 8.0
		ac.add_theme_stylebox_override("panel", asb)

		var av := VBoxContainer.new()
		av.add_theme_constant_override("separation", 2)
		ac.add_child(av)

		var atitle := "%s %s" % [str(ach.get("icon", "🎖️")), str(ach.get("title", "نشان"))]
		av.add_child(CafeSocialTheme.make_title(atitle, 19, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
		av.add_child(CafeSocialTheme.make_body(str(ach.get("desc", "")), 15, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
		ach_grid.add_child(ac)


func _render_favorite_games_section(prof: Dictionary) -> void:
	var st: Dictionary = prof.get("stats", {}) if typeof(prof.get("stats")) == TYPE_DICTIONARY else {}
	var favs: Array = st.get("most_played_games", []) if typeof(st.get("most_played_games")) == TYPE_ARRAY else []

	# If stats did not include most_played_games, calculate top games from history
	if favs.is_empty():
		favs = _compute_favorites_from_history(prof.get("history", {}))

	if favs.is_empty():
		return

	# Icon removed from header as requested
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("بازی‌های محبوب و پربازدید", null))

	# Horizontally Scrollable Carousel for Favorite Games
	var h_scroll := ScrollContainer.new()
	h_scroll.custom_minimum_size = Vector2(0, 168)
	h_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	h_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_vbox.add_child(h_scroll)

	var h_row := HBoxContainer.new()
	h_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_row.add_theme_constant_override("separation", 10)
	h_scroll.add_child(h_row)

	for fg in favs:
		if typeof(fg) != TYPE_DICTIONARY:
			continue
		var gtype := str(fg.get("game_type", ""))
		var t_matches := int(fg.get("total_matches", 0))
		var w_rate := float(fg.get("win_rate", 0.0))
		var w_wins := int(fg.get("wins", 0))

		var item := FavoriteGameItem.new()
		item.setup(gtype, t_matches, w_rate, w_wins)
		h_row.add_child(item)

	# Expandable Full Games History Breakdown
	var hist_dict: Dictionary = prof.get("history", {}) if typeof(prof.get("history")) == TYPE_DICTIONARY else {}
	if not hist_dict.is_empty():
		var full_history_box := VBoxContainer.new()
		full_history_box.visible = false
		full_history_box.add_theme_constant_override("separation", 8)
		_body_vbox.add_child(full_history_box)

		var btn_expand_hist := CafeSocialTheme.make_button("▼ مشاهده آمار تفکیکی تمامی بازی‌ها", "bronze", Vector2(0, 46), 18)
		btn_expand_hist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_expand_hist.pressed.connect(func():
			AudioManager.sfx_tap()
			full_history_box.visible = not full_history_box.visible
			btn_expand_hist.text = "▲ بستن آمار تفکیکی بازی‌ها" if full_history_box.visible else "▼ مشاهده آمار تفکیکی تمامی بازی‌ها"
			if full_history_box.visible and full_history_box.get_child_count() == 0:
				GamesHistoryViewHelper.populate_games_history(full_history_box, hist_dict)
		)
		_body_vbox.add_child(btn_expand_hist)


func _compute_favorites_from_history(hist: Dictionary) -> Array:
	var out: Array = []
	if hist == null or hist.is_empty():
		return out

	for g in GamesHistoryViewHelper.GAMES_LIST:
		var k := str(g.get("key", ""))
		var is_multi := bool(g.get("multi", false))
		var w := int(hist.get("%s_win" % k, 0))
		var d := int(hist.get("%s_draw" % k, 0))
		var l := int(hist.get("%s_lose" % k, 0))
		var r1 := int(hist.get("%s_rank1" % k, 0))
		var r2 := int(hist.get("%s_rank2" % k, 0))
		var rn := int(hist.get("%s_rankn" % k, 0))

		var total := (w + d + l + r1 + r2 + rn) if is_multi else (w + d + l)
		if total > 0:
			var wr: float = round((float(w + r1) / float(total)) * 100.0)
			out.append({
				"game_type": str(g.get("id", k)),
				"total_matches": total,
				"wins": w + r1,
				"win_rate": wr
			})

	out.sort_custom(func(a, b):
		return a["total_matches"] > b["total_matches"]
	)
	return out.slice(0, 5)
