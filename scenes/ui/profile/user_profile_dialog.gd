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
## - ExperienceProgress
## - PlayerActionButtons
## - RankingCard
## - FavoriteGameItem

static var active_instance: UserProfileDialog = null

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

var _subtab_bar: PanelContainer
var _subtab_row: HBoxContainer
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

	# 6. Self Sub-Tabs Bar (Overview | Cosmetics | Privacy & Blocks)
	_subtab_bar = PanelContainer.new()
	_subtab_bar.visible = false
	_subtab_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(14, 6.0, 6.0))
	root_vbox.add_child(_subtab_bar)

	_subtab_row = HBoxContainer.new()
	_subtab_row.add_theme_constant_override("separation", 6)
	_subtab_bar.add_child(_subtab_row)

	# 7. Scrollable Main Content Container
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
	if is_instance_valid(_toast_panel):
		_toast_panel.visible = false

	_rebuild_subtabs_bar()
	_render_body_tab()

	# Fetch full public profile
	if not _current_user_id.is_empty() and not _is_bot and not GameManager.token.is_empty():
		var req_uid := _current_user_id
		NetworkManager.api.get_public_profile(req_uid, func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				_public_profile = data["result"]
				_rebuild_subtabs_bar()
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
	get_tree().create_timer(3.2).timeout.connect(func():
		if is_instance_valid(_toast_panel) and is_instance_valid(_lbl_toast) and _lbl_toast.text == txt:
			_toast_panel.visible = false
	)


func _effective_data() -> Dictionary:
	if not _public_profile.is_empty():
		return _public_profile
	return _base_user_dict


func _rebuild_subtabs_bar() -> void:
	for c in _subtab_row.get_children():
		c.queue_free()

	if not _is_self or _is_bot:
		_subtab_bar.visible = false
		return

	_subtab_bar.visible = true
	var tabs := [
		{"id": "overview", "label": "نمای کلی و آمار"},
		{"id": "cosmetics", "label": "ظاهر و پروفایل"},
		{"id": "privacy", "label": "حریم خصوصی و مسدودها"},
	]
	for td in tabs:
		var tid: String = td["id"]
		var btn := CafeSocialTheme.make_subtab(td["label"], _active_self_tab == tid, 0)
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			_active_self_tab = tid
			_rebuild_subtabs_bar()
			_render_body_tab()
		)
		_subtab_row.add_child(btn)


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
# SECTION OVERVIEW: PROFILE HEADER, STATS, PROGRESSION, ACTIONS, RANKINGS, FAVORITES
# ==============================================================================

func _render_overview_tab() -> void:
	var prof := _effective_data()

	var score_val := int(prof.get("score", prof.get("user_score", 0)))
	var xp_val := int(float(prof.get("xp", prof.get("user_xp", 0))))
	var lvl_val := GameManager.calculate_level(xp_val) if xp_val > 0 else int(prof.get("level", 1))
	var friends_cnt := int(prof.get("friends_count", 0))
	var coin_val := int(prof.get("coin", prof.get("user_coin", prof.get("coins", GameManager.get_coins() if _is_self else 0))))
	var uname := str(prof.get("name", prof.get("username", "بازیکن")))
	var rel := str(prof.get("relationship", "none"))

	# --------------------------------------------------------------------------
	# A. Profile Header Component
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
	# D. Player Interactions (Action Area) - Displayed prominently for other players
	# --------------------------------------------------------------------------
	if not _is_self and not _is_bot and GameManager.is_logged_in and not GameManager.is_guest:
		var pres_dict: Dictionary = prof.get("presence", {}) if typeof(prof.get("presence")) == TYPE_DICTIONARY else {"status": str(prof.get("status", "offline"))}
		var p_info: Dictionary = CafeSocialTheme.format_presence(pres_dict)
		var is_in_game: bool = bool(p_info.get("is_in_game", false))

		var actions := PlayerActionButtons.new()
		actions.setup(rel, is_in_game, not GameManager.is_game_active, not GameManager.is_game_active, true)

		# 1. Add friend action
		actions.add_friend_pressed.connect(func():
			NetworkManager.api.send_friend_request(_current_user_id, "", func(ok: bool, _c: int, d: Variant):
				if ok:
					_public_profile["relationship"] = "request_sent"
					_show_profile_toast("درخواست دوستی ارسال شد.")
					_render_body_tab()
				else:
					var msg := str(d.get("detail", "خطا در ارسال درخواست")) if typeof(d) == TYPE_DICTIONARY else "خطا در ارسال درخواست"
					_show_profile_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)

		# 2. Accept friend request
		actions.accept_friend_pressed.connect(func():
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
							_render_body_tab()
					)
			)
		)

		# 3. Direct Message
		actions.private_message_pressed.connect(func():
			var target_uid := _current_user_id
			close()
			var s_dlg := get_tree().root.find_child("SocialDialog", true, false)
			if s_dlg and s_dlg.has_method("open_direct_message_with"):
				s_dlg.open_direct_message_with(target_uid, uname)
		)

		# 4. Game Invite
		actions.invite_to_game_pressed.connect(func():
			CafeSocialTheme.show_game_invite_modal(self, _current_user_id, uname, func(gtitle: String):
				_show_profile_toast("دعوت‌نامه «%s» برای %s ارسال شد." % [gtitle, uname])
			)
		)

		# 5. Clan Invite
		actions.invite_to_clan_pressed.connect(func():
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
			var target_uid: String = _current_user_id
			var active_gid: String = str(p_info.get("game_id", prof.get("current_game_id", prof.get("game_id", ""))))
			close()
			NetworkManager.request_spectate_game(active_gid, target_uid)
		)

		# 7. Block Player
		actions.block_player_pressed.connect(func():
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
			CafeSocialTheme.show_report_modal(self, "player", _current_user_id, uname, func(ok: bool):
				if ok:
					_show_profile_toast("گزارش شما با موفقیت ثبت شد.")
			)
		)

		_body_vbox.add_child(actions)

	# --------------------------------------------------------------------------
	# B. Player Statistics Component (Points, Level, Friends/Coins)
	# --------------------------------------------------------------------------
	var stats_component := PlayerStatistics.new()
	stats_component.setup(score_val, lvl_val, friends_cnt, _is_self, coin_val)
	_body_vbox.add_child(stats_component)

	# --------------------------------------------------------------------------
	# C. Player Progression Component (Emerald & Gold XP Bar)
	# --------------------------------------------------------------------------
	if xp_val > 0 or _is_self:
		var prog := ExperienceProgress.new()
		prog.setup(xp_val, lvl_val)
		_body_vbox.add_child(prog)

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
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("آمار و رتبه‌بندی رقابتی", CafeSocialTheme.ICO_RANKING))

	var st: Dictionary = prof.get("stats", {}) if typeof(prof.get("stats")) == TYPE_DICTIONARY else {}
	var hist: Dictionary = prof.get("history", {}) if typeof(prof.get("history")) == TYPE_DICTIONARY else {}

	var tot_wins := int(st.get("total_wins", 0))
	var tot_losses := int(st.get("total_losses", 0))
	var tot_draws := int(st.get("total_draws", 0))
	var tot_matches := int(st.get("total_matches", tot_wins + tot_losses + tot_draws))
	var win_rate := float(st.get("win_rate", 0.0))

	# 1. Overall Ranking Card
	var tier: Dictionary = prof.get("tier", {}) if typeof(prof.get("tier")) == TYPE_DICTIONARY else {}
	var tier_title := str(tier.get("title_fa", prof.get("rank_title", "تازه‌کار")))
	var score_val := int(prof.get("score", prof.get("user_score", 0)))
	var card_overall := RankingCard.new()
	card_overall.setup_mode(
		"⭐ رده‌بندی کلی و امتیاز کافه",
		"%s (%s)" % [tier_title, GameManager.to_fa_num(score_val)],
		tot_wins,
		tot_draws,
		tot_losses,
		CafeSocialTheme.ICO_STAR
	)
	_body_vbox.add_child(card_overall)

	# 2. 2-Player Rank Mode Card (رده‌بندی دو نفره)
	var win_rank := int(hist.get("win_rank", 0))
	var draw_rank := int(hist.get("draw_rank", 0))
	var lose_rank := int(hist.get("lose_rank", 0))
	if (win_rank + draw_rank + lose_rank) > 0:
		var card_rank := RankingCard.new()
		card_rank.setup_mode(
			"🏆 رده‌بندی دو نفره (Rank)",
			"حالت رقابتی",
			win_rank,
			draw_rank,
			lose_rank,
			CafeSocialTheme.ICO_CUP
		)
		_body_vbox.add_child(card_rank)

	# 3. Classic / AI Mode Card (کلاسیک تک‌نفره / هوش مصنوعی)
	var win_cr := int(hist.get("win_classic_rank", 0))
	var draw_cr := int(hist.get("draw_classic_rank", 0))
	var lose_cr := int(hist.get("lose_classic_rank", 0))
	if (win_cr + draw_cr + lose_cr) > 0:
		var card_cr := RankingCard.new()
		card_cr.setup_mode(
			"🤖 کلاسیک تک‌نفره (هوش مصنوعی)",
			"تمرین و مهارت",
			win_cr,
			draw_cr,
			lose_cr,
			CafeSocialTheme.ICO_SETTING
		)
		_body_vbox.add_child(card_cr)

	# 4. Multiplayer Ranking Card (رده‌بندی چندنفره)
	var r1 := int(hist.get("rank1_multi_rank", 0))
	var r2 := int(hist.get("rank2_multi_rank", 0))
	var rn := int(hist.get("rankn_multi_rank", 0))
	if (r1 + r2 + rn) > 0:
		var card_mr := RankingCard.new()
		card_mr.setup_multiplayer(
			"👥 رده‌بندی چندنفره (منچ، ریسک، اونو، مونوپولی)",
			"مسابقات تیمی و گروهی",
			r1,
			r2,
			rn,
			CafeSocialTheme.ICO_MULTI_RANK
		)
		_body_vbox.add_child(card_mr)

	# 5. Achievements Showcase (if unlocked)
	var achs: Array = prof.get("achievements", []) if typeof(prof.get("achievements")) == TYPE_ARRAY else []
	if not achs.is_empty():
		_render_achievements_grid(achs)


func _render_achievements_grid(achs: Array) -> void:
	var ach_header := CafeSocialTheme.make_ornate_section_header("دستاوردهای کسب‌شده", CafeSocialTheme.ICO_FIRST, "%s نشان افتخار" % GameManager.to_fa_num(achs.size()))
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

	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("بازی‌های محبوب و پربازدید", CafeSocialTheme.ICO_CUP))

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


# ==============================================================================
# TAB 2 (SELF): COSMETICS, AVATAR, TITLE, STATUS & USERNAME
# ==============================================================================

func _render_self_cosmetics_tab() -> void:
	var prof := _effective_data()

	# Account Card: Change Username
	var acc_card := PanelContainer.new()
	acc_card.custom_minimum_size = Vector2(0, 92)
	acc_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 14.0, 10.0))
	_body_vbox.add_child(acc_card)

	var acc_row := HBoxContainer.new()
	acc_row.add_theme_constant_override("separation", 10)
	acc_card.add_child(acc_row)

	var btn_rename := CafeSocialTheme.make_button("تغییر نام", "gold", Vector2(130, 44), 18)
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

	acc_col.add_child(CafeSocialTheme.make_title("حساب کاربری: %s" % GameManager.get_username(), 22, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var ph := GameManager.get_phone()
	acc_col.add_child(CafeSocialTheme.make_body("شماره همراه: %s" % (GameManager.to_fa_num(ph) if not ph.is_empty() else "ثبت‌شده"), 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

	# Avatar Picker (27 avatars in responsive grid)
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("انتخاب تصویر پروفایل (آواتار)", CafeSocialTheme.ICO_SPARKLE, "تصویر دلخواه خود را برای نمایش در بازی‌ها انتخاب کنید"))

	var av_card := PanelContainer.new()
	av_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 14.0, 12.0))
	_body_vbox.add_child(av_card)

	var av_vbox := VBoxContainer.new()
	av_vbox.add_theme_constant_override("separation", 10)
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
		ab.custom_minimum_size = Vector2(96, 96)
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

	var b_save_av := CafeSocialTheme.make_button("ذخیره تصویر انتخاب‌شده", "emerald", Vector2(0, 50), 20, CafeSocialTheme.ICO_CHECK)
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
				_show_profile_toast("تصویر پروفایل با موفقیت تغییر یافت!")
			else:
				_show_profile_toast("خطا در تغییر تصویر پروفایل", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	av_vbox.add_child(b_save_av)

	# Frame, Title, Status Customization
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("قاب آواتار، لقب افتخاری و وضعیت", CafeSocialTheme.ICO_KING))

	var cos_card := PanelContainer.new()
	cos_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 14.0, 12.0))
	_body_vbox.add_child(cos_card)

	var cos_v := VBoxContainer.new()
	cos_v.add_theme_constant_override("separation", 10)
	cos_card.add_child(cos_v)

	cos_v.add_child(CafeSocialTheme.make_body("قاب نمایشی آواتار (۲۰ مدل لوکس و شاهانه):", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var cur_f_init = int(prof.get("profile_frame", prof.get("avatar_frame", 1)))
	var sel_frame := [cur_f_init if cur_f_init >= 1 else 1]
	var my_av_id: int = GameManager.get_avatar_id()
	var frame_grid := GridContainer.new()
	frame_grid.columns = 5
	frame_grid.add_theme_constant_override("h_separation", 10)
	frame_grid.add_theme_constant_override("v_separation", 10)
	cos_v.add_child(frame_grid)

	var frame_btns: Dictionary = {}
	var refresh_frames := func():
		for fid in frame_btns.keys():
			var fb: PanelContainer = frame_btns[fid]
			var is_sel: bool = (fid == sel_frame[0])
			fb.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(
				Color(0.28, 0.18, 0.08, 0.98) if is_sel else CafeSocialTheme.COL_WALNUT_DEEP,
				Color(1.0, 0.85, 0.32, 1.0) if is_sel else Color(0.40, 0.30, 0.20, 0.8),
				14, 3 if is_sel else 1, 6.0, 6.0
			))

	for fid in range(1, 21):
		var p_btn := PanelContainer.new()
		p_btn.custom_minimum_size = Vector2(92, 92)
		p_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p_btn.focus_mode = Control.FOCUS_NONE
		var badge := CafeSocialTheme.make_avatar_badge(my_av_id, fid, 72.0)
		p_btn.add_child(badge)

		var current_fid = fid
		p_btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				AudioManager.sfx_tap()
				sel_frame[0] = current_fid
				refresh_frames.call()
		)
		frame_btns[fid] = p_btn
		frame_grid.add_child(p_btn)
	refresh_frames.call()

	cos_v.add_child(CafeSocialTheme.make_body("لقب افتخاری شما:", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var inp_title := CafeSocialTheme.make_line_edit("مثلاً: استاد منچ و مونوپولی", 48.0, 19)
	inp_title.text = str(prof.get("profile_title", ""))
	cos_v.add_child(inp_title)

	# Quick Honor Title presets
	var title_chips := HBoxContainer.new()
	title_chips.add_theme_constant_override("separation", 6)
	cos_v.add_child(title_chips)
	for preset in ["استاد استراتژی", "قهرمان کافه", "گرگ مونوپولی", "سلطان شطرنج"]:
		var pt: String = preset
		var pb := CafeSocialTheme.make_button(pt, "bronze", Vector2(0, 38), 17)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func():
			AudioManager.sfx_tap()
			inp_title.text = pt
		)
		title_chips.add_child(pb)

	cos_v.add_child(CafeSocialTheme.make_body("پیام وضعیت شخصی شما:", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var inp_status := CafeSocialTheme.make_line_edit("مثلاً: آماده یک رقابت دو نفره جذاب!", 48.0, 19)
	inp_status.text = str(prof.get("status_message", ""))
	cos_v.add_child(inp_status)

	var b_save_cos := CafeSocialTheme.make_button("ذخیره ظاهر و مشخصات", "gold", Vector2(0, 50), 20, CafeSocialTheme.ICO_CHECK, true)
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
				GameManager.user_data["profile_frame"] = sel_frame[0]
				GameManager.user_data["avatar_frame"] = sel_frame[0]
				GameManager.set_session(GameManager.token, GameManager.user_data, true)
				_show_profile_toast("ظاهر پروفایل با موفقیت ذخیره شد!")
			else:
				_show_profile_toast("خطا در ذخیره ظاهر پروفایل", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	cos_v.add_child(b_save_cos)


# ==============================================================================
# TAB 3 (SELF): PRIVACY SETTINGS, NOTIFICATIONS & BLOCKED PLAYERS
# ==============================================================================

func _render_self_privacy_tab() -> void:
	var prof := _effective_data()
	var priv: Dictionary = prof.get("privacy", {}) if typeof(prof.get("privacy")) == TYPE_DICTIONARY else {}

	# Privacy Settings Card
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("تنظیمات حریم خصوصی", CafeSocialTheme.ICO_SETTING, "کنترل پیام‌ها، درخواست‌ها و نمایش فعالیت به دیگران"))

	var priv_card := PanelContainer.new()
	priv_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 18.0, 14.0))
	_body_vbox.add_child(priv_card)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
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
	dm_row.add_theme_constant_override("separation", 6)
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
		var db := CafeSocialTheme.make_button(dd["l"], "muted", Vector2(0, 44), 19)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.pressed.connect(func():
			AudioManager.sfx_tap()
			dm_policy[0] = did
			refresh_dm_btns.call()
		)
		dm_btns[did] = db
		dm_row.add_child(db)
	refresh_dm_btns.call()

	pv.add_child(CafeSocialTheme.make_body("چه کسانی بتوانند بازی‌های زنده شما را تماشا کنند؟", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var spec_policy := [str(priv.get("allow_spectators", "everyone"))]
	if spec_policy[0] not in ["everyone", "friends", "clan", "none"]:
		spec_policy[0] = "everyone"

	var spec_row := HBoxContainer.new()
	spec_row.add_theme_constant_override("separation", 6)
	pv.add_child(spec_row)
	var spec_btns: Dictionary = {}
	var refresh_spec_btns := func():
		for sk in spec_btns.keys():
			var sb: Button = spec_btns[sk]
			var s_act: bool = (sk == spec_policy[0])
			sb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if s_act else "muted", "normal", 12))
			sb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if s_act else "muted", "hover", 12))

	for sd in [{"id": "none", "l": "هیچ‌کس"}, {"id": "clan", "l": "هم‌کلنی‌ها"}, {"id": "friends", "l": "دوستان"}, {"id": "everyone", "l": "همه"}]:
		var sid: String = sd["id"]
		var sbtn := CafeSocialTheme.make_button(sd["l"], "muted", Vector2(0, 44), 18)
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.pressed.connect(func():
			AudioManager.sfx_tap()
			spec_policy[0] = sid
			refresh_spec_btns.call()
		)
		spec_btns[sid] = sbtn
		spec_row.add_child(sbtn)
	refresh_spec_btns.call()

	var b_save_priv := CafeSocialTheme.make_button("ذخیره تنظیمات حریم خصوصی", "gold", Vector2(0, 50), 20, CafeSocialTheme.ICO_CHECK)
	b_save_priv.pressed.connect(func():
		AudioManager.sfx_button()
		b_save_priv.disabled = true
		NetworkManager.api.customize_my_profile({
			"privacy": {
				"allow_friend_requests": chk_freq.button_pressed,
				"allow_dms": dm_policy[0],
				"allow_spectators": spec_policy[0],
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

	# Notification Preferences Card
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("تنظیمات اعلان‌ها", CafeSocialTheme.ICO_STAR))

	var np_card := PanelContainer.new()
	np_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 18.0, 14.0))
	_body_vbox.add_child(np_card)

	var npv := VBoxContainer.new()
	npv.add_theme_constant_override("separation", 8)
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

	var b_save_np := CafeSocialTheme.make_button("ذخیره ترجیحات اعلان‌ها", "emerald", Vector2(0, 48), 20, CafeSocialTheme.ICO_CHECK)
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

	# Blocked Players List Card
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("بازیکنان مسدودشده", CafeSocialTheme.ICO_CANCEL, "مدیریت کاربرانی که مسدود کرده‌اید"))

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
			card.custom_minimum_size = Vector2(0, 84)
			card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 20.0, 10.0))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			card.add_child(row)

			var b_un := CafeSocialTheme.make_button("رفع مسدودیت", "emerald", Vector2(130, 42), 18)
			b_un.pressed.connect(func():
				AudioManager.sfx_tap()
				NetworkManager.api.unblock_player(bu_uid, func(ok_u: bool, _cu: int, _du: Variant):
					if ok_u:
						_show_profile_toast("مسدودیت «%s» برداشته شد." % bu_name)
						_render_body_tab()
				)
			)
			row.add_child(b_un)

			var nm := CafeSocialTheme.make_title(bu_name, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)

			row.add_child(CafeSocialTheme.make_avatar_badge(int(bu.get("image", 0)), int(bu.get("profile_frame", 1)), 58.0))
			blk_holder.add_child(card)
	)
