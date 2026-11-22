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
var _inner_bezel: PanelContainer
var _lbl_title: Label
var _lbl_header_sub: Label
var _status_pill: PanelContainer
var _status_dot: Panel
var _lbl_status_pill: Label
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


func _make_parlor_outer_frame_style() -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = preload("res://assets/images/frames/dialog_tall.png")
	sb.texture_margin_left = 40.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_bottom = 60.0
	return sb


func _make_parlor_inner_inlay_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	return sb


func _is_mobile() -> bool:
	return GameManager.is_mobile


func _make_header_crown_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.100, 0.056, 0.97)
	sb.border_color = Color(0.85, 0.67, 0.28, 0.62)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	sb.shadow_size = 0 if _is_mobile() else 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _make_icon_medallion_frame() -> PanelContainer:
	var wrap: PanelContainer = PanelContainer.new()
	wrap.custom_minimum_size = Vector2(46, 46)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.065, 0.036, 0.95)
	sb.border_color = Color(0.82, 0.64, 0.28, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(23)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	wrap.add_theme_stylebox_override("panel", sb)
	return wrap


func _build_shell() -> void:
	for c in get_children():
		c.queue_free()

	# 1. Warm cinematic vignette dim overlay
	_dim_overlay = ColorRect.new()
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.color = Color(0.02, 0.012, 0.008, 0.84)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			close()
	)
	add_child(_dim_overlay)

	# 2. Safe Viewport-Bounded Outer MarginContainer (never collides with screen edges)
	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 34)
	outer.add_theme_constant_override("margin_bottom", 34)
	add_child(outer)

	# 3. Sculpted Double-Beveled Antique Walnut & Gold Parlor Frame
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = false
	panel.add_theme_stylebox_override("panel", _make_parlor_outer_frame_style())
	outer.add_child(panel)

	# 3b. Inner Gold-Hairline Inlay Chamber
	_inner_bezel = PanelContainer.new()
	_inner_bezel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner_bezel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inner_bezel.clip_contents = true
	_inner_bezel.add_theme_stylebox_override("panel", _make_parlor_inner_inlay_style())
	panel.add_child(_inner_bezel)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	_inner_bezel.add_child(root_vbox)

	# 4. Sculpted Parlor Header Crown (Close Medallion + Title/Subtitle + Live Presence Pill)
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _make_header_crown_style())
	root_vbox.add_child(top_bar)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(top_row)

	var close_wrap: PanelContainer = _make_icon_medallion_frame()
	top_row.add_child(close_wrap)

	var btn_close: TextureButton = TextureButton.new()
	btn_close.name = "BtnCloseTop"
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_close.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_close.ignore_texture_size = true
	btn_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	close_wrap.add_child(btn_close)

	var title_stack: VBoxContainer = VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 1)
	top_row.add_child(title_stack)

	_lbl_title = CafeSocialTheme.make_title("مشخصات بازیکن", 27, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_lbl_title)

	_lbl_header_sub = CafeSocialTheme.make_body("پرونده رسمی کافه فکر", 15, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)
	_lbl_header_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_lbl_header_sub)

	# Presence / Identity Pill on right (balances close medallion visually)
	_status_pill = PanelContainer.new()
	_status_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st_sb: StyleBoxFlat = StyleBoxFlat.new()
	st_sb.bg_color = Color(0.10, 0.06, 0.035, 0.94)
	st_sb.border_color = Color(0.60, 0.46, 0.24, 0.72)
	st_sb.set_border_width_all(1)
	st_sb.set_corner_radius_all(14)
	st_sb.content_margin_left = 10.0
	st_sb.content_margin_right = 10.0
	st_sb.content_margin_top = 5.0
	st_sb.content_margin_bottom = 5.0
	_status_pill.add_theme_stylebox_override("panel", st_sb)
	top_row.add_child(_status_pill)

	var st_row: HBoxContainer = HBoxContainer.new()
	st_row.alignment = BoxContainer.ALIGNMENT_CENTER
	st_row.add_theme_constant_override("separation", 6)
	_status_pill.add_child(st_row)

	_lbl_status_pill = CafeSocialTheme.make_body("آفلاین", 14, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, false)
	st_row.add_child(_lbl_status_pill)

	_status_dot = Panel.new()
	_status_dot.custom_minimum_size = Vector2(9, 9)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_sb: StyleBoxFlat = StyleBoxFlat.new()
	dot_sb.bg_color = Color(0.55, 0.50, 0.45, 0.90)
	dot_sb.set_corner_radius_all(5)
	_status_dot.add_theme_stylebox_override("panel", dot_sb)
	st_row.add_child(_status_dot)

	# 4b. Ornamental Gold Hairline Accent Divider
	var divider: ColorRect = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color(0.84, 0.66, 0.28, 0.32)
	root_vbox.add_child(divider)

	# 5. Toast Feedback Banner
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	root_vbox.add_child(_toast_panel)

	_lbl_toast = CafeSocialTheme.make_body("", 19, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(_lbl_toast)

	# 6. Scrollable Main Content Container
	_scroll_body = ScrollContainer.new()
	_scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll_body)

	var scroll_pad: MarginContainer = MarginContainer.new()
	scroll_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_pad.add_theme_constant_override("margin_left", 2)
	scroll_pad.add_theme_constant_override("margin_right", 2)
	scroll_pad.add_theme_constant_override("margin_top", 2)
	scroll_pad.add_theme_constant_override("margin_bottom", 10)
	_scroll_body.add_child(scroll_pad)

	_body_vbox = VBoxContainer.new()
	_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_vbox.add_theme_constant_override("separation", 12)
	scroll_pad.add_child(_body_vbox)


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

	var uname: String = str(prof.get("name", prof.get("username", "بازیکن")))
	var rel: String = str(prof.get("relationship", "none"))
	_update_header_meta(prof)

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

	# 3. Direct Message (Only allowed if friends)
	actions.private_message_pressed.connect(func():
		if _is_self or rel != "friend":
			return
		var target_uid: String = _current_user_id
		close()
		var shell: Node = get_tree().root.find_child("MainTabShell", true, false)
		if shell and shell.has_method("open_direct_message_with"):
			shell.open_direct_message_with(target_uid, uname)
			return
		var s_dlg: Node = get_tree().root.find_child("SocialDialog", true, false)
		if s_dlg and s_dlg.has_method("open_direct_message_with"):
			s_dlg.open_direct_message_with(target_uid, uname)
	)

	# 4. Block Player (Moved to top row as icon button)
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

	# 5. Report Player (Moved to top row as icon button with uploaded medallion)
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
	# Score & Level crests are now inside ProfileHeader (Top-Left);
	# Friends/Coins box removed as requested.
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


func _update_header_meta(prof: Dictionary) -> void:
	if not is_instance_valid(_lbl_header_sub) or not is_instance_valid(_status_pill):
		return
	var tier_d: Dictionary = prof.get("tier", {}) if typeof(prof.get("tier")) == TYPE_DICTIONARY else {}
	var tier_fa: String = str(tier_d.get("title_fa", prof.get("rank_title", ""))).strip_edges()
	if _is_bot:
		_lbl_header_sub.text = "حریف هوشمند کافه فکر"
	elif _is_self:
		_lbl_header_sub.text = "پرونده شخصی شما" if tier_fa.is_empty() else "پرونده شما  •  %s" % tier_fa
	elif not _current_role_text.is_empty():
		_lbl_header_sub.text = _current_role_text
	elif not tier_fa.is_empty():
		_lbl_header_sub.text = "رتبه: %s" % tier_fa
	else:
		_lbl_header_sub.text = "پرونده رسمی بازیکن"

	var pres_dict: Dictionary = prof.get("presence", {}) if typeof(prof.get("presence")) == TYPE_DICTIONARY else {"status": str(prof.get("status", "online" if _is_self else "offline"))}
	var p_info: Dictionary = CafeSocialTheme.format_presence(pres_dict)
	var st_key: String = str(pres_dict.get("status", "online" if _is_self else "offline")).strip_edges().to_lower()
	var pill_txt: String = "آفلاین"
	var dot_col: Color = Color(0.55, 0.50, 0.45, 0.90)
	var border_col: Color = Color(0.52, 0.42, 0.28, 0.65)
	var text_col: Color = CafeSocialTheme.COL_MUTED_SAND

	if _is_bot:
		pill_txt = "ربات"
		dot_col = Color(0.45, 0.78, 0.98, 1.0)
		border_col = Color(0.40, 0.68, 0.90, 0.75)
		text_col = Color(0.75, 0.90, 1.0, 1.0)
	elif bool(p_info.get("is_in_game", false)) or st_key == "in_game":
		pill_txt = "در بازی"
		dot_col = CafeSocialTheme.COL_GOLD_BRIGHT
		border_col = CafeSocialTheme.COL_GOLD_ANTIQUE
		text_col = CafeSocialTheme.COL_GOLD_BRIGHT
	elif st_key == "online" or st_key == "in_lobby" or st_key == "in_queue" or _is_self:
		pill_txt = "آنلاین"
		dot_col = Color(0.32, 0.90, 0.52, 1.0)
		border_col = CafeSocialTheme.COL_EMERALD_BORDER
		text_col = CafeSocialTheme.COL_EMERALD_TEXT

	_lbl_status_pill.text = pill_txt
	_lbl_status_pill.add_theme_color_override("font_color", text_col)
	var dot_sb: StyleBoxFlat = StyleBoxFlat.new()
	dot_sb.bg_color = dot_col
	dot_sb.set_corner_radius_all(5)
	_status_dot.add_theme_stylebox_override("panel", dot_sb)
	var pill_sb: StyleBoxFlat = StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.10, 0.06, 0.035, 0.94)
	pill_sb.border_color = border_col
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(14)
	pill_sb.content_margin_left = 10.0
	pill_sb.content_margin_right = 10.0
	pill_sb.content_margin_top = 5.0
	pill_sb.content_margin_bottom = 5.0
	_status_pill.add_theme_stylebox_override("panel", pill_sb)


func _render_clan_card(clan_id: String, clan_d: Dictionary) -> void:
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("اتحاد بازیکن", CafeSocialTheme.ICO_ARMY))

	var c_card: PanelContainer = PanelContainer.new()
	c_card.custom_minimum_size = Vector2(0, 96)
	var c_sb: StyleBoxFlat = StyleBoxFlat.new()
	c_sb.bg_color = Color(0.155, 0.095, 0.054, 0.96)
	c_sb.border_color = Color(0.82, 0.64, 0.28, 0.78)
	c_sb.border_width_left = 1
	c_sb.border_width_right = 1
	c_sb.border_width_bottom = 1
	c_sb.border_width_top = 2
	c_sb.set_corner_radius_all(16)
	c_sb.content_margin_left = 14.0
	c_sb.content_margin_right = 14.0
	c_sb.content_margin_top = 12.0
	c_sb.content_margin_bottom = 12.0
	c_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	c_sb.shadow_size = 0 if _is_mobile() else 6
	c_sb.shadow_offset = Vector2(0, 3)
	c_card.add_theme_stylebox_override("panel", c_sb)
	_body_vbox.add_child(c_card)

	var crow: HBoxContainer = HBoxContainer.new()
	crow.add_theme_constant_override("separation", 12)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	c_card.add_child(crow)

	var b_view_clan: Button = CafeSocialTheme.make_button("مشاهده اتحاد", "gold", Vector2(118, 44), 17)
	b_view_clan.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b_view_clan.pressed.connect(func():
		AudioManager.sfx_button()
		CafeSocialTheme.show_clan_details_modal(self, clan_id, clan_d)
	)
	crow.add_child(b_view_clan)

	var cinfo: VBoxContainer = VBoxContainer.new()
	cinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinfo.alignment = BoxContainer.ALIGNMENT_CENTER
	cinfo.add_theme_constant_override("separation", 3)
	crow.add_child(cinfo)

	var cname: String = str(clan_d.get("name", "اتحاد کافه فکر"))
	var ctag: String = str(clan_d.get("tag", ""))
	var clvl: int = int(clan_d.get("clan_level", 1))
	var crole: String = str(clan_d.get("role", "member"))
	var crole_fa: String = str({"leader": "رهبر اتحاد", "co_leader": "قائم‌مقام رهبر", "elder": "ارشد اتحاد", "member": "عضو رسمی"}.get(crole, "عضو اتحاد"))

	var ctitle_row: HBoxContainer = HBoxContainer.new()
	ctitle_row.alignment = BoxContainer.ALIGNMENT_END
	ctitle_row.add_theme_constant_override("separation", 6)
	cinfo.add_child(ctitle_row)

	if not ctag.is_empty():
		ctitle_row.add_child(CafeSocialTheme.make_badge_pill("[%s]" % ctag, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.12, 0.08, 0.04), CafeSocialTheme.COL_GOLD_ANTIQUE, 15))

	var c_nm_lbl: Label = CafeSocialTheme.make_title(cname, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	c_nm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_nm_lbl.clip_text = true
	c_nm_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ctitle_row.add_child(c_nm_lbl)

	cinfo.add_child(CafeSocialTheme.make_body("سمت: %s  •  سطح %s" % [crole_fa, GameManager.to_fa_num(clvl)], 16, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	var emb_id: int = int(clan_d.get("emblem_id", 1))
	var c_emb_node: Control = CafeSocialTheme.make_clan_emblem(emb_id, 54.0)
	c_emb_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(c_emb_node)


func _render_rankings_and_achievements(prof: Dictionary) -> void:
	var stat_ico: Texture2D = load("res://assets/images/statistics.png")
	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("آمار و رتبه‌بندی رقابتی", stat_ico))

	var st: Dictionary = prof.get("stats", {}) if typeof(prof.get("stats")) == TYPE_DICTIONARY else {}
	var hist: Dictionary = prof.get("history", {}) if typeof(prof.get("history")) == TYPE_DICTIONARY else {}

	var win_rank: int = int(hist.get("win_rank", 0))
	var draw_rank: int = int(hist.get("draw_rank", 0))
	var lose_rank: int = int(hist.get("lose_rank", 0))

	var win_cr: int = int(hist.get("win_classic_rank", 0))
	var draw_cr: int = int(hist.get("draw_classic_rank", 0))
	var lose_cr: int = int(hist.get("lose_classic_rank", 0))

	var r1: int = int(hist.get("rank1_multi_rank", 0))
	var r2: int = int(hist.get("rank2_multi_rank", 0))
	var rn: int = int(hist.get("rankn_multi_rank", 0))

	var fallback_wins: int = win_rank + win_cr + r1
	var fallback_draws: int = draw_rank + draw_cr + r2
	var fallback_losses: int = lose_rank + lose_cr + rn

	var tot_wins: int = int(st.get("total_wins", fallback_wins))
	var tot_losses: int = int(st.get("total_losses", fallback_losses))
	var tot_draws: int = int(st.get("total_draws", fallback_draws))
	var tot_matches: int = int(st.get("total_matches", tot_wins + tot_losses + tot_draws))
	if tot_matches < (tot_wins + tot_losses + tot_draws):
		tot_matches = tot_wins + tot_losses + tot_draws
	var wr_pct: int = int(round(float(st.get("win_rate", (float(tot_wins) / float(max(1, tot_matches))) * 100.0)))) if tot_matches > 0 else 0

	# 1. Executive KPI Overview Banner
	var tier: Dictionary = prof.get("tier", {}) if typeof(prof.get("tier")) == TYPE_DICTIONARY else {}
	var tier_title: String = str(tier.get("title_fa", prof.get("rank_title", "تازه‌کار")))
	var score_val: int = int(prof.get("score", prof.get("user_score", 0)))
	_body_vbox.add_child(_build_profile_kpi_summary_card(tier_title, score_val, tot_matches, tot_wins, tot_draws, tot_losses, wr_pct))

	# 2. 2-Player Rank Mode Card
	if (win_rank + draw_rank + lose_rank) > 0:
		var card_rank: RankingCard = RankingCard.new()
		card_rank.setup_mode(
			"رده‌بندی دو نفره",
			"رقابتی آنلاین",
			win_rank,
			draw_rank,
			lose_rank,
			null
		)
		_body_vbox.add_child(card_rank)

	# 3. Classic / AI Mode Card
	if (win_cr + draw_cr + lose_cr) > 0:
		var card_cr: RankingCard = RankingCard.new()
		card_cr.setup_mode(
			"کلاسیک تک‌نفره",
			"هوش مصنوعی",
			win_cr,
			draw_cr,
			lose_cr,
			null
		)
		_body_vbox.add_child(card_cr)

	# 4. Multiplayer Ranking Card
	if (r1 + r2 + rn) > 0:
		var card_mr: RankingCard = RankingCard.new()
		card_mr.setup_multiplayer(
			"رده‌بندی چندنفره",
			"رقابت گروهی",
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


func _build_profile_kpi_summary_card(
	tier_title: String,
	score_val: int,
	total_matches: int,
	wins: int,
	draws: int,
	losses: int,
	win_rate_pct: int
) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.10, 0.06, 0.97)
	sb.border_color = Color(0.84, 0.67, 0.30, 0.88)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_width_top = 2
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	sb.shadow_size = 0 if _is_mobile() else 6
	sb.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", sb)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	# Header: Tier Pill + Summary Heading
	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hdr)

	var tier_pill: PanelContainer = CafeSocialTheme.make_badge_pill(
		"%s  •  %s امتیاز" % [tier_title, GameManager.to_fa_num(score_val)],
		CafeSocialTheme.COL_GOLD_BRIGHT,
		Color(0.24, 0.17, 0.06, 0.96),
		CafeSocialTheme.COL_GOLD_ANTIQUE,
		15
	)
	hdr.add_child(tier_pill)

	var lbl_h: Label = CafeSocialTheme.make_title("کارنامه کلی", 21, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	lbl_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(lbl_h)

	# 3 Executive KPI Wells (RTL order: Win Rate left, Wins center, Total Matches right)
	var kpi_row: HBoxContainer = HBoxContainer.new()
	kpi_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kpi_row.add_theme_constant_override("separation", 8)
	vb.add_child(kpi_row)

	var wr_col: Color = CafeSocialTheme.COL_MUTED_SAND
	if total_matches > 0:
		if win_rate_pct >= 55:
			wr_col = CafeSocialTheme.COL_EMERALD_TEXT
		elif win_rate_pct >= 35:
			wr_col = CafeSocialTheme.COL_GOLD_BRIGHT
		else:
			wr_col = CafeSocialTheme.COL_CRIMSON_TEXT

	kpi_row.add_child(_make_kpi_well("%s٪" % GameManager.to_fa_num(win_rate_pct), "نرخ برد کل", wr_col))
	kpi_row.add_child(_make_kpi_well(GameManager.to_fa_num(wins), "پیروزی‌ها", CafeSocialTheme.COL_EMERALD_TEXT))
	kpi_row.add_child(_make_kpi_well(GameManager.to_fa_num(total_matches), "کل مسابقات", CafeSocialTheme.COL_GOLD_BRIGHT))

	# Overall Segmented Win/Draw/Loss Bar
	var bar_track: PanelContainer = PanelContainer.new()
	bar_track.custom_minimum_size = Vector2(0, 10)
	bar_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_track.clip_contents = true
	var track_sb: StyleBoxFlat = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.07, 0.04, 0.02, 0.94)
	track_sb.border_color = Color(0.45, 0.34, 0.19, 0.65)
	track_sb.set_border_width_all(1)
	track_sb.set_corner_radius_all(5)
	track_sb.content_margin_left = 1.0
	track_sb.content_margin_right = 1.0
	track_sb.content_margin_top = 1.0
	track_sb.content_margin_bottom = 1.0
	bar_track.add_theme_stylebox_override("panel", track_sb)
	vb.add_child(bar_track)

	var seg_row: HBoxContainer = HBoxContainer.new()
	seg_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seg_row.add_theme_constant_override("separation", 2)
	bar_track.add_child(seg_row)

	var sum_wl: int = wins + draws + losses
	if sum_wl > 0:
		var seg_vals: Array[int] = [losses, draws, wins]
		var seg_cols: Array[Color] = [
			Color(0.86, 0.34, 0.34, 0.92),
			Color(0.94, 0.76, 0.28, 0.92),
			Color(0.30, 0.84, 0.48, 0.96)
		]
		for i in range(seg_vals.size()):
			if seg_vals[i] <= 0:
				continue
			var seg: Panel = Panel.new()
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.size_flags_vertical = Control.SIZE_EXPAND_FILL
			seg.size_flags_stretch_ratio = float(seg_vals[i])
			var seg_sb: StyleBoxFlat = StyleBoxFlat.new()
			seg_sb.bg_color = seg_cols[i]
			seg_sb.set_corner_radius_all(3)
			seg.add_theme_stylebox_override("panel", seg_sb)
			seg_row.add_child(seg)

	# Compact W/D/L Legend
	var legend_lbl: Label = CafeSocialTheme.make_body(
		"برد: %s  •  مساوی: %s  •  باخت: %s" % [GameManager.to_fa_num(wins), GameManager.to_fa_num(draws), GameManager.to_fa_num(losses)],
		15,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	vb.add_child(legend_lbl)
	return card


func _make_kpi_well(val_txt: String, caption_txt: String, accent_col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.06, 0.03, 0.94)
	st.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.42)
	st.set_border_width_all(1)
	st.set_corner_radius_all(12)
	st.content_margin_left = 6.0
	st.content_margin_right = 6.0
	st.content_margin_top = 8.0
	st.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", st)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)

	vb.add_child(CafeSocialTheme.make_title(val_txt, 24, accent_col, HORIZONTAL_ALIGNMENT_CENTER, false))
	vb.add_child(CafeSocialTheme.make_body(caption_txt, 14, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, false))
	return p


func _render_achievements_grid(achs: Array) -> void:
	var ach_header: PanelContainer = CafeSocialTheme.make_ornate_section_header("دستاوردهای کسب‌شده", null, "%s نشان افتخار" % GameManager.to_fa_num(achs.size()))
	_body_vbox.add_child(ach_header)

	var ach_grid: GridContainer = GridContainer.new()
	ach_grid.columns = 2
	ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_grid.add_theme_constant_override("h_separation", 8)
	ach_grid.add_theme_constant_override("v_separation", 8)
	_body_vbox.add_child(ach_grid)

	for ach in achs:
		if typeof(ach) != TYPE_DICTIONARY:
			continue
		var ach_d: Dictionary = ach as Dictionary
		var ac: PanelContainer = PanelContainer.new()
		ac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var asb: StyleBoxFlat = StyleBoxFlat.new()
		asb.bg_color = Color(0.14, 0.09, 0.05, 0.95)
		asb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
		asb.set_border_width_all(1)
		asb.set_corner_radius_all(12)
		asb.content_margin_left = 10.0
		asb.content_margin_right = 10.0
		asb.content_margin_top = 8.0
		asb.content_margin_bottom = 8.0
		ac.add_theme_stylebox_override("panel", asb)

		var av: VBoxContainer = VBoxContainer.new()
		av.add_theme_constant_override("separation", 2)
		ac.add_child(av)

		var raw_title: String = str(ach_d.get("title", "نشان افتخار"))
		av.add_child(CafeSocialTheme.make_title(raw_title, 18, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
		av.add_child(CafeSocialTheme.make_body(str(ach_d.get("desc", "")), 14, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
		ach_grid.add_child(ac)


func _render_favorite_games_section(prof: Dictionary) -> void:
	var st: Dictionary = prof.get("stats", {}) if typeof(prof.get("stats")) == TYPE_DICTIONARY else {}
	var favs: Array = st.get("most_played_games", []) if typeof(st.get("most_played_games")) == TYPE_ARRAY else []

	if favs.is_empty():
		favs = _compute_favorites_from_history(prof.get("history", {}))

	if favs.is_empty():
		return

	_body_vbox.add_child(CafeSocialTheme.make_ornate_section_header("بازی‌های محبوب و پربازی", null))

	# Horizontally Scrollable Carousel for Favorite Games (202px tall to fit 188px cards + shadow)
	var h_scroll: ScrollContainer = ScrollContainer.new()
	h_scroll.custom_minimum_size = Vector2(0, 202)
	h_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	h_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_vbox.add_child(h_scroll)

	var h_row: HBoxContainer = HBoxContainer.new()
	h_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_row.add_theme_constant_override("separation", 10)
	h_scroll.add_child(h_row)

	for fg in favs:
		if typeof(fg) != TYPE_DICTIONARY:
			continue
		var fgd: Dictionary = fg as Dictionary
		var gtype: String = str(fgd.get("game_type", ""))
		var t_matches: int = int(fgd.get("total_matches", 0))
		var w_rate: float = float(fgd.get("win_rate", 0.0))
		var w_wins: int = int(fgd.get("wins", 0))

		var item: FavoriteGameItem = FavoriteGameItem.new()
		item.setup(gtype, t_matches, w_rate, w_wins)
		h_row.add_child(item)

	# Expandable Full Games History Breakdown (deduplicated: mode cards already rendered above)
	var hist_dict: Dictionary = prof.get("history", {}) if typeof(prof.get("history")) == TYPE_DICTIONARY else {}
	if not hist_dict.is_empty():
		var full_history_box: VBoxContainer = VBoxContainer.new()
		full_history_box.visible = false
		full_history_box.add_theme_constant_override("separation", 8)
		_body_vbox.add_child(full_history_box)

		var btn_expand_hist: Button = CafeSocialTheme.make_button("مشاهده آمار تفکیکی همه بازی‌ها", "bronze", Vector2(0, 48), 18)
		btn_expand_hist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_expand_hist.pressed.connect(func():
			AudioManager.sfx_tap()
			full_history_box.visible = not full_history_box.visible
			btn_expand_hist.text = "بستن آمار تفکیکی بازی‌ها" if full_history_box.visible else "مشاهده آمار تفکیکی همه بازی‌ها"
			if full_history_box.visible and full_history_box.get_child_count() == 0:
				GamesHistoryViewHelper.populate_games_history(full_history_box, hist_dict, false)
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
