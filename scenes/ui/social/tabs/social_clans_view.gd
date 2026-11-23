class_name SocialClansView
extends RefCounted

## Cafe Fekr — Complete Clan & Social System UI Redesign
##
## Implements a unified, luxurious antique board-game social experience:
## 1. Shared Clan Header & 3-Tab Navigation (Messages, Clan Overview, Members)
## 2. Redesigned Clan Chat with rich bubbles, sticker drawer, system events & game challenge cards
## 3. Clan Overview with Clan Identity hero plaque, XP progress, actions, weekly challenges & activity feed
## 4. Clan Members directory with 4-stat metric strip, real-time search, role filtering & member interactions sheet
## 5. Clan Discovery, Leaderboard & Free Clan Creation for non-members and browsing

# ------------------------------------------------------------------------------
# CONSTANTS & ASSETS
# ------------------------------------------------------------------------------

const ROLE_RANKS: Dictionary = {
	"leader": 4,
	"co_leader": 3,
	"elder": 2,
	"member": 1,
}

const ROLE_FA_MAP: Dictionary = {
	"leader": "رهبر اتحاد",
	"co_leader": "قائم‌مقام",
	"elder": "ارشد",
	"member": "عضو",
	"system": "سیستم",
}

const CACHE_TTL_MS: int = 30000
static var _lb_cache: Dictionary = {}
static var _search_cache: Dictionary = {}


static func invalidate_caches() -> void:
	_lb_cache.clear()
	_search_cache.clear()


static func get_subtab_badges(host: Control) -> Dictionary:
	var badges := {"chat": 0, "my_clan": 0, "members": 0, "leaderboard": 0, "discover": 0}
	if not is_instance_valid(host):
		return badges
	var has_clan := _check_user_has_clan(host)
	var unread_chat := int(host.get("_clan_unread_chat_count")) if host.get("_clan_unread_chat_count") != null else 0
	if has_clan:
		badges["chat"] = maxi(0, unread_chat)
		var cdict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
		var my_role := str(cdict.get("my_role", "member"))
		var pending_cnt := 0
		if my_role in ["leader", "co_leader", "elder"]:
			var reqs: Variant = cdict.get("pending_join_requests", [])
			if typeof(reqs) == TYPE_ARRAY:
				pending_cnt += (reqs as Array).size()
		var open_c: Variant = cdict.get("open_challenges", host._my_clan_data.get("open_challenges", []))
		if typeof(open_c) == TYPE_ARRAY:
			pending_cnt += (open_c as Array).size()
		badges["my_clan"] = pending_cnt
	else:
		var invs: Variant = host._my_clan_data.get("invitations", [])
		if typeof(invs) == TYPE_ARRAY:
			badges["my_clan"] = (invs as Array).size()
	return badges


static func get_clans_badge_count(host: Control) -> int:
	var b := get_subtab_badges(host)
	return int(b.get("chat", 0)) + int(b.get("my_clan", 0))


static func refresh_nav_badges(host: Control) -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.content_area):
		return
	var ca: Control = host.content_area as Control
	var shell: Node = ca.get_node_or_null("ClanShellVBox")
	if shell == null:
		return
	var old_nav: Node = shell.get_node_or_null("ClanNavTabs")
	if old_nav == null:
		return
	var nav_idx: int = old_nav.get_index()
	var has_clan := _check_user_has_clan(host)
	var fresh_nav := _build_clan_navigation_tabs(host, has_clan)
	shell.remove_child(old_nav)
	old_nav.queue_free()
	shell.add_child(fresh_nav)
	shell.move_child(fresh_nav, nav_idx)


# ------------------------------------------------------------------------------
# PRIMARY RENDER ENTRY POINT (Persistent Header + Nav Shell)
# ------------------------------------------------------------------------------

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	body_vbox.name = "ClanShellVBox"
	var has_clan := _check_user_has_clan(host)

	# Ensure current subtab is valid
	var valid_tabs: Array[String] = []
	if has_clan:
		valid_tabs = ["my_clan", "chat", "members", "discover", "leaderboard"]
		if not host.current_clans_subtab in valid_tabs:
			host.current_clans_subtab = "my_clan"
	else:
		valid_tabs = ["my_clan", "discover", "leaderboard"]
		if not host.current_clans_subtab in valid_tabs:
			host.current_clans_subtab = "my_clan"

	if has_clan and str(host.current_clans_subtab) == "chat":
		if host.get("_clan_unread_chat_count") != null and int(host.get("_clan_unread_chat_count")) > 0:
			host.set("_clan_unread_chat_count", 0)
			if host.has_method("_update_main_tab_buttons"):
				host._update_main_tab_buttons()

	# 1. Shared Header
	var header_box := _build_shared_header(host, has_clan)
	body_vbox.add_child(header_box)

	# 2. Shared Clan Navigation Tabs
	var tabs_bar := _build_clan_navigation_tabs(host, has_clan)
	body_vbox.add_child(tabs_bar)

	# 3. Content Area Holder
	var content_holder := VBoxContainer.new()
	content_holder.name = "ClanContentHolder"
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.add_theme_constant_override("separation", 10)
	body_vbox.add_child(content_holder)

	_render_clan_subtab_content(host, content_holder, has_clan)


static func switch_subtab_in_place(host: Control, new_subtab: String) -> void:
	var prev_subtab := str(host.current_clans_subtab)
	host.current_clans_subtab = new_subtab
	var has_clan := _check_user_has_clan(host)

	if has_clan and new_subtab == "chat":
		if host.get("_clan_unread_chat_count") != null and int(host.get("_clan_unread_chat_count")) > 0:
			host.set("_clan_unread_chat_count", 0)
			if host.has_method("_update_main_tab_buttons"):
				host._update_main_tab_buttons()

	if not is_instance_valid(host.content_area):
		host._refresh_current_tab()
		return
	var ca: Control = host.content_area as Control
	var shell: Node = ca.get_node_or_null("ClanShellVBox")
	var content_holder: Node = shell.get_node_or_null("ClanContentHolder") if shell != null else null
	if shell == null or content_holder == null:
		host._refresh_current_tab()
		return

	# If shell state doesn't match has_clan (e.g. NavTabs has wrong set of tabs), rebuild entire shell!
	var nav_tabs: Node = shell.get_node_or_null("ClanNavTabs")
	var has_clan_tabs: bool = (nav_tabs != null and nav_tabs.find_child("ClanTab_chat", false, false) != null)
	if has_clan != has_clan_tabs:
		host._refresh_current_tab()
		return

	# Reset per-subtab dynamic references without tearing down the persistent header/nav!
	host._clan_chat_list_vbox = null
	host._clan_chat_scroll = null
	host._clan_chat_input = null
	host._clan_chat_is_loading_older = false
	host._clan_members_online_val_lbl = null
	host._clan_member_widgets.clear()

	# Only swap header when switching between compact chat mode and standard mode
	var compact_changed: bool = has_clan and ((prev_subtab == "chat") != (new_subtab == "chat"))
	if compact_changed:
		var old_hdr: Node = shell.get_node_or_null("ClanSharedHeader")
		if old_hdr != null:
			var hdr_idx: int = old_hdr.get_index()
			shell.remove_child(old_hdr)
			old_hdr.queue_free()
			var fresh_hdr := _build_shared_header(host, has_clan)
			shell.add_child(fresh_hdr)
			shell.move_child(fresh_hdr, hdr_idx)

	# Refresh nav active pill & badges cleanly
	refresh_nav_badges(host)

	# Swap only the inner content container
	for ch in content_holder.get_children():
		ch.queue_free()
	_render_clan_subtab_content(host, content_holder as VBoxContainer, has_clan)


static func _render_clan_subtab_content(host: Control, content_holder: VBoxContainer, has_clan: bool) -> void:
	# Handle routing
	if not has_clan:
		if host.current_clans_subtab == "my_clan":
			_build_no_clan_overview(host, content_holder)
		elif host.current_clans_subtab == "leaderboard":
			_build_clan_leaderboard_inner(host, content_holder)
		else:
			_build_clan_search_inner(host, content_holder)
		return

	# User is in a clan
	if host.current_clans_subtab == "chat":
		_build_clan_chat_view(host, content_holder)
	elif host.current_clans_subtab in ["discover", "leaderboard"]:
		_build_clan_discover_view(host, content_holder)
	elif host.current_clans_subtab in ["my_clan", "members"]:
		var clan_dict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
		if clan_dict.is_empty():
			content_holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اطلاعات اتحاد..."))
			NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
				if not is_instance_valid(content_holder):
					return
				for ch in content_holder.get_children():
					ch.queue_free()
				if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
					host._my_clan_data = data["result"]
					var fresh_clan: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
					if host.has_method("_update_main_tab_buttons"):
						host._update_main_tab_buttons()
					refresh_nav_badges(host)
					if host.current_clans_subtab == "members":
						_build_clan_members_tab(host, content_holder, fresh_clan)
					else:
						_build_clan_overview_tab(host, content_holder, fresh_clan)
				else:
					content_holder.add_child(CafeSocialTheme.make_empty_state(
						CafeSocialTheme.ICO_INFO,
						"خطا در دریافت اطلاعات اتحاد",
						"لطفاً اتصال خود را بررسی کرده و دوباره تلاش کنید.",
						"تلاش مجدد", "gold", func(): host._refresh_current_tab()
					))
			)
		else:
			if host.current_clans_subtab == "members":
				_build_clan_members_tab(host, content_holder, clan_dict)
			else:
				_build_clan_overview_tab(host, content_holder, clan_dict)


static func _check_user_has_clan(host: Control) -> bool:
	if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY and not host._my_clan_data["clan"].is_empty():
		return true
	if GameManager.user_data.has("clan") and typeof(GameManager.user_data["clan"]) == TYPE_DICTIONARY and not GameManager.user_data["clan"].is_empty():
		return true
	if GameManager.user_data.has("clan_id") and not str(GameManager.user_data["clan_id"]).is_empty():
		return true
	return false


static func _get_my_clan_id(host: Control) -> String:
	if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY and not host._my_clan_data["clan"].is_empty():
		var c: Dictionary = host._my_clan_data["clan"]
		return str(c.get("clan_id", c.get("_id", "")))
	if GameManager.user_data.has("clan") and typeof(GameManager.user_data["clan"]) == TYPE_DICTIONARY:
		var c2: Dictionary = GameManager.user_data["clan"]
		var id2 := str(c2.get("clan_id", c2.get("_id", "")))
		if not id2.is_empty():
			return id2
	return str(GameManager.user_data.get("clan_id", ""))


static func _is_mobile_platform() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm and "is_mobile" in gm:
			return bool(gm.is_mobile)
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


static func _calc_modal_width(host: Control, preferred_w: float = 620.0) -> float:
	var vp_w: float = 720.0
	if is_instance_valid(host) and host.get_viewport() != null:
		vp_w = host.get_viewport_rect().size.x
	return clampf(vp_w - 32.0, 320.0, preferred_w)


static func _calc_modal_max_scroll_h(host: Control, ratio: float = 0.78) -> float:
	var vp_h: float = 1280.0
	if is_instance_valid(host) and host.get_viewport() != null:
		vp_h = host.get_viewport_rect().size.y
	return clampf(vp_h * ratio, 340.0, 1020.0)


static func _create_responsive_modal(host: Control, preferred_w: float = 620.0, z_idx: int = 50, dim_alpha: float = 0.80, scrollable: bool = true) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = z_idx

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, dim_alpha)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var modal_w := _calc_modal_width(host, preferred_w)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(modal_w, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)

	var scroll: ScrollContainer = null
	if scrollable:
		scroll = ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, 0)
		m.add_child(scroll)
		scroll.add_child(vbox)
		# Clamp scroll height cleanly after layout if content exceeds viewport safe area
		var max_h := _calc_modal_max_scroll_h(host, 0.78)
		vbox.resized.connect(func():
			if is_instance_valid(scroll) and is_instance_valid(vbox):
				var desired_h := minf(vbox.get_combined_minimum_size().y + 4.0, max_h)
				if absf(scroll.custom_minimum_size.y - desired_h) > 2.0:
					scroll.custom_minimum_size.y = desired_h
		)
	else:
		m.add_child(vbox)

	return {"overlay": overlay, "card": card, "vbox": vbox, "scroll": scroll, "width": modal_w}


# ==============================================================================
# 1. SHARED CLAN HEADER & NAVIGATION
# ==============================================================================

static func _build_shared_header(host: Control, has_clan: bool) -> PanelContainer:
	var is_chat_compact: bool = has_clan and (str(host.current_clans_subtab) == "chat")
	var card := PanelContainer.new()
	card.name = "ClanSharedHeader"
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_clan_top_header_style())

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	if not has_clan:
		var left_col := VBoxContainer.new()
		left_col.alignment = BoxContainer.ALIGNMENT_CENTER
		left_col.add_theme_constant_override("separation", 2)
		hbox.add_child(left_col)

		var b_create_quick := CafeSocialTheme.make_button("تاسیس اتحاد", "gold", Vector2(124, 42), 19)
		b_create_quick.pressed.connect(func():
			AudioManager.sfx_button()
			open_clan_create_modal(host)
		)
		left_col.add_child(b_create_quick)

		var title_col := VBoxContainer.new()
		title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_col.alignment = BoxContainer.ALIGNMENT_CENTER
		title_col.add_theme_constant_override("separation", 2)
		hbox.add_child(title_col)

		title_col.add_child(CafeSocialTheme.make_title("اتحادهای کافه فکر", 25, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))
		var sub_t := CafeSocialTheme.make_body("باشگاه اجتماعی، چالش‌های هفتگی و مسابقات گروهی", 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)
		sub_t.clip_text = true
		sub_t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_col.add_child(sub_t)

		hbox.add_child(CafeSocialTheme.make_clan_emblem(1, 52.0))
		return card

	# Has Clan — Clean, compact single-identity header (no duplicate Leaderboard shortcut)
	var cdict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var cname := str(cdict.get("name", "اتحاد من"))
	var ctag := str(cdict.get("tag", ""))
	var emb_id := int(cdict.get("emblem_id", 1))
	var clvl := int(cdict.get("clan_level", 1))
	var my_role_fa := str(cdict.get("my_role_fa", "عضو"))
	var mem_cnt := int(cdict.get("member_count", 1))
	var max_mem := int(cdict.get("max_members", 40))

	# Calculate online members count
	var online_cnt := 0
	var members_arr: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
	for m in members_arr:
		if typeof(m) == TYPE_DICTIONARY:
			var pres: Dictionary = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
			var st_str := str(pres.get("status", "offline"))
			if st_str in ["online", "in_game", "in_lobby", "in_queue"]:
				online_cnt += 1
	if online_cnt == 0:
		online_cnt = 1

	# Left: Online live pill
	var online_pill := CafeSocialTheme.make_badge_pill(
		"%s آنلاین" % GameManager.to_fa_num(online_cnt),
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		16
	)
	if online_pill.get_child_count() > 0 and online_pill.get_child(0) is Label:
		host._clan_online_pill_lbl = online_pill.get_child(0) as Label
	hbox.add_child(online_pill)

	# Center clan info (single compact row in Chat, rich 2-line in other tabs)
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 2)
	hbox.add_child(center_col)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 6)
	center_col.add_child(name_row)

	if not ctag.is_empty():
		var tag_lbl := CafeSocialTheme.make_body("[%s]" % ctag, 18 if is_chat_compact else 19, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		name_row.add_child(tag_lbl)

	var name_lbl := CafeSocialTheme.make_title(cname, 22 if is_chat_compact else 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_lbl)

	if not is_chat_compact:
		var meta_row := HBoxContainer.new()
		meta_row.alignment = BoxContainer.ALIGNMENT_END
		meta_row.add_theme_constant_override("separation", 6)
		center_col.add_child(meta_row)

		meta_row.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(clvl), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 15))
		meta_row.add_child(CafeSocialTheme.make_badge_pill(my_role_fa, CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 15))
		meta_row.add_child(CafeSocialTheme.make_body("%s/%s عضو" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

	# Right Emblem
	hbox.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 42.0 if is_chat_compact else 56.0))
	return card


static func _build_clan_navigation_tabs(host: Control, has_clan: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ClanNavTabs"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var sub_badges := get_subtab_badges(host)
	var tabs: Array[Dictionary] = []
	if has_clan:
		tabs = [
			{"id": "leaderboard", "match": ["leaderboard", "discover"], "label": "رتبه‌بندی", "badge": 0},
			{"id": "members", "match": ["members"], "label": "اعضا", "badge": 0},
			{"id": "my_clan", "match": ["my_clan"], "label": "اتحاد", "badge": int(sub_badges.get("my_clan", 0))},
			{"id": "chat", "match": ["chat"], "label": "پیام‌ها", "badge": int(sub_badges.get("chat", 0))},
		]
	else:
		tabs = [
			{"id": "leaderboard", "match": ["leaderboard"], "label": "برترین‌ها", "badge": 0},
			{"id": "discover", "match": ["discover"], "label": "جستجو", "badge": 0},
			{"id": "my_clan", "match": ["my_clan"], "label": "معرفی و دعوت", "badge": int(sub_badges.get("my_clan", 0))},
		]

	for td in tabs:
		var tid: String = td["id"]
		var match_ids: Array = td.get("match", [tid])
		var is_active: bool = (str(host.current_clans_subtab) in match_ids)
		var btn := Button.new()
		btn.name = "ClanTab_" + tid
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CafeSocialTheme.style_parlor_tab_button(btn, is_active, 21 if has_clan else 22)

		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 5)
		btn.add_child(h)

		var lbl := Label.new()
		lbl.text = td["label"]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 21 if has_clan else 22)
		lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY if is_active else Color(0.82, 0.76, 0.68, 0.85))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("shadow_outline_size", 2)
		var b_cnt := int(td.get("badge", 0))
		if b_cnt > 0:
			var b_pill := PanelContainer.new()
			b_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bp_sb := StyleBoxFlat.new()
			bp_sb.bg_color = Color(0.84, 0.18, 0.16, 0.98)
			bp_sb.border_color = CafeSocialTheme.COL_GOLD_BRIGHT
			bp_sb.set_border_width_all(1)
			bp_sb.set_corner_radius_all(9)
			bp_sb.content_margin_left = 6.0
			bp_sb.content_margin_right = 6.0
			bp_sb.content_margin_top = 1.0
			bp_sb.content_margin_bottom = 1.0
			b_pill.add_theme_stylebox_override("panel", bp_sb)
			var b_lbl := Label.new()
			b_lbl.text = GameManager.to_fa_num(b_cnt) if b_cnt <= 99 else "۹۹+"
			b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
			b_lbl.add_theme_font_size_override("font_size", 13)
			b_lbl.add_theme_color_override("font_color", Color.WHITE)
			b_pill.add_child(b_lbl)
			h.add_child(b_pill)

		h.add_child(lbl)

		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			switch_subtab_in_place(host, tid)
		)
		row.add_child(btn)

	return panel


# ==============================================================================
# 2. CLAN CHAT – MESSAGES TAB
# ==============================================================================

const CHAT_PAGE_SIZE: int = 30


static func _is_scroll_near_bottom(scroll: ScrollContainer) -> bool:
	if not is_instance_valid(scroll):
		return false
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if not bar:
		return true
	var max_scroll := bar.max_value - bar.page
	if max_scroll <= 0:
		return true
	return (scroll.scroll_vertical >= max_scroll - 160.0)


static func _scroll_clan_chat_to_bottom_smooth(host: Control) -> void:
	if not is_instance_valid(host) or not is_instance_valid(host._clan_chat_scroll):
		return
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if is_instance_valid(host._clan_chat_scroll):
		var bar: VScrollBar = host._clan_chat_scroll.get_v_scroll_bar()
		if bar:
			host._clan_chat_scroll.scroll_vertical = int(bar.max_value)


static func _build_top_pagination_widget(host: Control) -> Control:
	var holder := PanelContainer.new()
	holder.name = "TopPaginationLoader"
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxEmpty.new()
	st.content_margin_top = 4.0
	st.content_margin_bottom = 6.0
	holder.add_theme_stylebox_override("panel", st)

	var has_more: bool = (host.get("_clan_chat_has_more") != false)
	if has_more:
		var btn := Button.new()
		btn.name = "BtnLoadOlder"
		btn.text = "📜 بارگذاری پیام‌های قدیمی‌تر"
		btn.custom_minimum_size = Vector2(0, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		btn.add_theme_font_size_override("font_size", 17)
		btn.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		btn.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("muted", "normal", 10))
		btn.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("bronze", "normal", 10))
		btn.add_theme_stylebox_override("pressed", CafeSocialTheme._get_flat_btn_style("bronze", "pressed", 10))
		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			load_older_clan_chat_messages(host)
		)
		holder.add_child(btn)
	else:
		var lbl := Label.new()
		lbl.text = "🏁 ابتدای تاریخچه گفتگوهای اتحاد"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30, 0.75))
		holder.add_child(lbl)

	return holder


static func _update_top_loader_state(host: Control, is_loading: bool) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return
	var top_loader: Node = host._clan_chat_list_vbox.get_node_or_null("TopPaginationLoader")
	if not top_loader:
		return
	var btn: Button = top_loader.get_node_or_null("BtnLoadOlder")
	if btn:
		if is_loading:
			btn.text = "⏳ در حال دریافت پیام‌های قبلی..."
			btn.disabled = true
		else:
			btn.text = "📜 بارگذاری پیام‌های قدیمی‌تر"
			btn.disabled = false


static func load_older_clan_chat_messages(host: Control) -> void:
	if not is_instance_valid(host) or not is_instance_valid(host._clan_chat_list_vbox):
		return
	if host.get("_clan_chat_has_more") == false:
		return
	if bool(host.get("_clan_chat_is_loading_older")):
		return
	if host._clan_chat_messages.is_empty():
		return

	# Oldest message is at index 0 of host._clan_chat_messages
	var oldest_msg: Dictionary = host._clan_chat_messages[0] if typeof(host._clan_chat_messages[0]) == TYPE_DICTIONARY else {}
	var before_id: String = str(oldest_msg.get("message_id", oldest_msg.get("_id", "")))
	if before_id.is_empty():
		return

	host.set("_clan_chat_is_loading_older", true)
	_update_top_loader_state(host, true)

	NetworkManager.api.get_clan_chat_history("", 0, CHAT_PAGE_SIZE, before_id, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(host) or not is_instance_valid(host._clan_chat_list_vbox):
			return
		host.set("_clan_chat_is_loading_older", false)

		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var older_msgs: Array = data["result"]
			if older_msgs.size() < CHAT_PAGE_SIZE:
				host.set("_clan_chat_has_more", false)

			if older_msgs.is_empty():
				_update_top_loader_state(host, false)
				return

			var old_scroll: int = host._clan_chat_scroll.scroll_vertical
			var old_content_height: float = host._clan_chat_list_vbox.size.y

			# Remove current top loader
			var cur_top: Node = host._clan_chat_list_vbox.get_node_or_null("TopPaginationLoader")
			if cur_top:
				cur_top.queue_free()

			var my_uid := str(GameManager.get_user_id())
			var clan_d: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
			var my_role := str(clan_d.get("my_role", "member"))

			var new_bubbles: Array[Control] = []
			for m in older_msgs:
				if typeof(m) == TYPE_DICTIONARY:
					var b := _build_single_chat_bubble(host, m, my_uid, my_role)
					if b != null:
						new_bubbles.append(b)

			# Prepend into host._clan_chat_messages
			for i in range(older_msgs.size() - 1, -1, -1):
				host._clan_chat_messages.insert(0, older_msgs[i])

			# Insert bubbles into VBox at index 0..new_bubbles.size()-1
			for i in range(new_bubbles.size()):
				host._clan_chat_list_vbox.add_child(new_bubbles[i])
				host._clan_chat_list_vbox.move_child(new_bubbles[i], i)

			# Re-add top pagination widget at index 0
			var new_top := _build_top_pagination_widget(host)
			host._clan_chat_list_vbox.add_child(new_top)
			host._clan_chat_list_vbox.move_child(new_top, 0)

			# Preserve exact scroll position so view doesn't jump
			await host.get_tree().process_frame
			await host.get_tree().process_frame
			if is_instance_valid(host._clan_chat_scroll) and is_instance_valid(host._clan_chat_list_vbox):
				var new_content_height: float = host._clan_chat_list_vbox.size.y
				var height_diff := new_content_height - old_content_height
				host._clan_chat_scroll.scroll_vertical = old_scroll + int(height_diff)
		else:
			_update_top_loader_state(host, false)
	)


static func _send_clan_chat_text_direct(host: Control, raw_txt: String) -> void:
	var txt := raw_txt.strip_edges()
	if txt.is_empty():
		return
	if NetworkManager.is_social_connected or NetworkManager.is_online:
		if NetworkManager.is_social_connected:
			NetworkManager.send_clan_chat_realtime(txt)
			return
	NetworkManager.api.send_clan_chat_rest(txt, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(host):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var msg_res: Dictionary = data["result"]
			var mid := str(msg_res.get("message_id", msg_res.get("_id", "")))
			var exists := false
			for m in host._clan_chat_messages:
				if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid and not mid.is_empty():
					exists = true
					break
			if not exists:
				host._clan_chat_messages.append(msg_res)
				append_clan_chat_message(host, msg_res)
		elif typeof(data) == TYPE_DICTIONARY:
			host._show_toast(str(data.get("detail", "خطا در ارسال پیام اتحاد")), CafeSocialTheme.COL_CRIMSON_TEXT)
	)


static func _extract_chat_date_key(iso_str: String) -> String:
	var dt := GameManager.parse_server_iso_to_local(iso_str)
	if dt.is_empty() or int(dt.get("year", 0)) < 1900:
		return ""
	return "%04d-%02d-%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"])]


static func _extract_chat_minute_stamp(iso_str: String) -> int:
	var dt := GameManager.parse_server_iso_to_local(iso_str)
	if dt.is_empty() or not bool(dt.get("has_time", false)):
		return -1
	return int(dt.get("year", 0)) * 525600 + int(dt.get("month", 0)) * 44640 + int(dt.get("day", 0)) * 1440 + int(dt.get("hour", 0)) * 60 + int(dt.get("minute", 0))


static func _format_date_divider_label(iso_str: String) -> String:
	var dt := GameManager.parse_server_iso_to_local(iso_str)
	if dt.is_empty() or int(dt.get("year", 0)) < 1900:
		return ""
	var gy := int(dt["year"])
	var gm := int(dt["month"])
	var gd := int(dt["day"])
	var now_dt: Dictionary = Time.get_datetime_dict_from_system()
	if gy == int(now_dt.get("year", 0)) and gm == int(now_dt.get("month", 0)) and gd == int(now_dt.get("day", 0)):
		return "امروز"
	var msg_unix := Time.get_unix_time_from_datetime_dict({"year": gy, "month": gm, "day": gd, "hour": 12, "minute": 0, "second": 0})
	var today_unix := Time.get_unix_time_from_datetime_dict({"year": int(now_dt.get("year", 2025)), "month": int(now_dt.get("month", 1)), "day": int(now_dt.get("day", 1)), "hour": 12, "minute": 0, "second": 0})
	if today_unix - msg_unix >= 70000 and today_unix - msg_unix <= 100000:
		return "دیروز"
	var j := CafeSocialTheme.gregorian_to_jalali(gy, gm, gd)
	var month_names := ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
	var m_name: String = month_names[j["month"] - 1] if j["month"] >= 1 and j["month"] <= 12 else ""
	return "%s %s" % [GameManager.to_fa_num(j["day"]), m_name]


static func _build_date_divider_pill(label_txt: String) -> Control:
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.09, 0.05, 0.85)
	st.border_color = Color(0.50, 0.38, 0.22, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 3.0
	st.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", st)
	pill.add_child(CafeSocialTheme.make_body(label_txt, 15, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false))
	wrap.add_child(pill)
	return wrap


static func _build_pinned_challenge_strip(host: Control) -> Control:
	var cdict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var raw_chals: Variant = cdict.get("open_challenges", host._my_clan_data.get("open_challenges", []))
	var open_chals: Array = raw_chals if typeof(raw_chals) == TYPE_ARRAY else []
	if open_chals.is_empty():
		return null
	var first_c: Variant = open_chals[0]
	if typeof(first_c) != TYPE_DICTIONARY:
		return null
	var ch: Dictionary = first_c
	var gt := str(ch.get("game_type", "Monopoly"))
	var gt_fa := str(ch.get("game_title_fa", GameRegistry.get_display_name_fa(gt)))
	var p_cnt := clampi(int(ch.get("player_count", 2)), 2, 4)
	var parts: Array = ch.get("participants", []) if typeof(ch.get("participants")) == TYPE_ARRAY else []
	var cur_p := maxi(1, parts.size())

	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.12, 0.05, 0.96)
	sb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)

	var b_go := CafeSocialTheme.make_button("مشاهده", "emerald", Vector2(86, 32), 16)
	b_go.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab_in_place(host, "my_clan")
	)
	h.add_child(b_go)

	var extra_txt := " (+%s چالش دیگر)" % GameManager.to_fa_num(open_chals.size() - 1) if open_chals.size() > 1 else ""
	var lbl := CafeSocialTheme.make_body(
		"⚔️ چالش فعال: %s (%s/%s)%s" % [gt_fa, GameManager.to_fa_num(cur_p), GameManager.to_fa_num(p_cnt), extra_txt],
		17, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false
	)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(lbl)
	return bar


static func _build_clan_chat_view(host: Control, holder: VBoxContainer) -> void:
	# Optional Pinned Active Friendly Challenge Strip
	var pinned_bar := _build_pinned_challenge_strip(host)
	if pinned_bar != null:
		holder.add_child(pinned_bar)

	# A. Chat Stream Well with Floating Jump-to-Bottom Pill (strict clip_contents prevents horizontal bleed)
	var chat_overlay_wrap := Control.new()
	chat_overlay_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_overlay_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_overlay_wrap.clip_contents = true
	holder.add_child(chat_overlay_wrap)

	var chat_well := PanelContainer.new()
	chat_well.set_anchors_preset(Control.PRESET_FULL_RECT)
	chat_well.clip_contents = true
	var well_st := StyleBoxFlat.new()
	well_st.bg_color = Color(0.08, 0.05, 0.03, 0.88)
	well_st.border_color = Color(0.40, 0.28, 0.16, 0.60)
	well_st.set_border_width_all(1)
	well_st.set_corner_radius_all(14)
	well_st.content_margin_left = 8.0
	well_st.content_margin_right = 8.0
	well_st.content_margin_top = 8.0
	well_st.content_margin_bottom = 8.0
	chat_well.add_theme_stylebox_override("panel", well_st)
	chat_overlay_wrap.add_child(chat_well)

	host._clan_chat_scroll = ScrollContainer.new()
	host._clan_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._clan_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host._clan_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host._clan_chat_scroll.clip_contents = true
	chat_well.add_child(host._clan_chat_scroll)

	# Floating "Jump to bottom / New messages" pill
	var jump_btn := CafeSocialTheme.make_button("↓ رفتن به آخرین پیام", "emerald", Vector2(180, 38), 17)
	jump_btn.visible = false
	jump_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	jump_btn.offset_left = -90.0
	jump_btn.offset_right = 90.0
	jump_btn.offset_top = -48.0
	jump_btn.offset_bottom = -10.0
	jump_btn.set_meta("unread_count", 0)
	jump_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		jump_btn.set_meta("unread_count", 0)
		jump_btn.text = "↓ رفتن به آخرین پیام"
		jump_btn.visible = false
		_scroll_clan_chat_to_bottom_smooth(host)
	)
	chat_overlay_wrap.add_child(jump_btn)
	host._clan_chat_scroll.set_meta("jump_btn", jump_btn)

	# Auto-load older messages near top + toggle jump pill when scrolled up
	var v_bar: VScrollBar = host._clan_chat_scroll.get_v_scroll_bar()
	if v_bar:
		v_bar.value_changed.connect(func(val: float):
			if val <= 30.0 and host.get("_clan_chat_has_more") != false and not bool(host.get("_clan_chat_is_loading_older")):
				load_older_clan_chat_messages(host)
			if is_instance_valid(jump_btn) and is_instance_valid(host._clan_chat_scroll):
				var max_s := v_bar.max_value - v_bar.page
				if max_s > 260.0 and val < max_s - 220.0:
					jump_btn.visible = true
				else:
					jump_btn.visible = false
					jump_btn.set_meta("unread_count", 0)
					jump_btn.text = "↓ رفتن به آخرین پیام"
		)

	host._clan_chat_list_vbox = VBoxContainer.new()
	host._clan_chat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._clan_chat_list_vbox.add_theme_constant_override("separation", 6)
	host._clan_chat_scroll.add_child(host._clan_chat_list_vbox)

	# If cached messages exist, render immediately to avoid 1-second disappearance flicker!
	if not host._clan_chat_messages.is_empty():
		_populate_all_clan_chat_messages(host)
		_scroll_clan_chat_to_bottom_smooth(host)
	else:
		host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت گفتگوهای اتحاد..."))

	# B. Chat Input Composer (compact docked bar at bottom)
	var composer := PanelContainer.new()
	composer.custom_minimum_size = Vector2(0, 72)
	var comp_st := StyleBoxFlat.new()
	comp_st.bg_color = Color(0.12, 0.08, 0.04, 0.98)
	comp_st.border_color = Color(0.60, 0.45, 0.22, 0.75)
	comp_st.set_border_width_all(1)
	comp_st.set_corner_radius_all(14)
	if not _is_mobile_platform():
		comp_st.shadow_color = Color(0, 0, 0, 0.35)
		comp_st.shadow_size = 5
		comp_st.shadow_offset = Vector2(0, -2)
	comp_st.content_margin_left = 10.0
	comp_st.content_margin_right = 10.0
	comp_st.content_margin_top = 6.0
	comp_st.content_margin_bottom = 6.0
	composer.add_theme_stylebox_override("panel", comp_st)
	holder.add_child(composer)

	var inp_row := HBoxContainer.new()
	inp_row.add_theme_constant_override("separation", 8)
	inp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	composer.add_child(inp_row)

	# Send Button (icon send.png)
	var btn_send := TextureButton.new()
	btn_send.texture_normal = preload("res://assets/images/send.png")
	btn_send.custom_minimum_size = Vector2(50, 50)
	btn_send.ignore_texture_size = true
	btn_send.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_send.focus_mode = Control.FOCUS_NONE
	btn_send.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_send.tooltip_text = "ارسال پیام"
	ActionVFXManager.apply_button_juice(btn_send, "tap_button")
	btn_send.pressed.connect(func():
		AudioManager.sfx_tap()
		host._send_clan_chat_message()
	)
	inp_row.add_child(btn_send)

	# Text Input
	host._clan_chat_input = CafeSocialTheme.make_line_edit("پیام به اعضای اتحاد...", 48.0, 21)
	host._clan_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inp_row.add_child(host._clan_chat_input)

	# Sticker Drawer Toggle Button (expressive reaction sticker icon!)
	var btn_sticker := TextureButton.new()
	btn_sticker.texture_normal = preload("res://assets/icons/Reactions/1.png")
	btn_sticker.custom_minimum_size = Vector2(46, 46)
	btn_sticker.ignore_texture_size = true
	btn_sticker.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_sticker.focus_mode = Control.FOCUS_NONE
	btn_sticker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_sticker.tooltip_text = "ارسال استیکر و واکنش"
	ActionVFXManager.apply_button_juice(btn_sticker, "tap_button")
	btn_sticker.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_sticker_picker(host)
	)
	inp_row.add_child(btn_sticker)

	host._clan_chat_input.text_submitted.connect(func(_t: String): host._send_clan_chat_message())

	# Initial load: fetch first page of CHAT_PAGE_SIZE messages
	NetworkManager.api.get_clan_chat_history("", 0, CHAT_PAGE_SIZE, "", func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(host._clan_chat_list_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var fresh_arr: Array = data["result"]
			if fresh_arr.size() < CHAT_PAGE_SIZE:
				host.set("_clan_chat_has_more", false)
			else:
				host.set("_clan_chat_has_more", true)

			if host._clan_chat_messages.is_empty():
				for ch in host._clan_chat_list_vbox.get_children():
					ch.queue_free()
				host._clan_chat_messages = fresh_arr
				_populate_all_clan_chat_messages(host)
				_scroll_clan_chat_to_bottom_smooth(host)
			else:
				# Incremental sync: Only insert new messages at the end, DO NOT wipe existing ones!
				var existing_ids: Dictionary = {}
				for m in host._clan_chat_messages:
					if typeof(m) == TYPE_DICTIONARY:
						var mid := str(m.get("message_id", m.get("_id", "")))
						if not mid.is_empty():
							existing_ids[mid] = true

				var new_msgs: Array = []
				for fm in fresh_arr:
					if typeof(fm) == TYPE_DICTIONARY:
						var fmid := str(fm.get("message_id", fm.get("_id", "")))
						if fmid.is_empty() or not existing_ids.has(fmid):
							new_msgs.append(fm)
							if not fmid.is_empty():
								existing_ids[fmid] = true

				for nm in new_msgs:
					host._clan_chat_messages.append(nm)
					append_clan_chat_message(host, nm)
		else:
			if host._clan_chat_messages.is_empty():
				for ch in host._clan_chat_list_vbox.get_children():
					ch.queue_free()
				host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.BADGE_CHAT,
					"هنوز پیامی ثبت نشده است",
					"اولین پیام یا گفتگو را برای اعضای اتحاد ارسال کنید!"
				))
	)


static func render_clan_chat(host: Control) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return
	var was_near_bottom: bool = _is_scroll_near_bottom(host._clan_chat_scroll)
	for c in host._clan_chat_list_vbox.get_children():
		c.queue_free()
	_populate_all_clan_chat_messages(host)
	if was_near_bottom:
		_scroll_clan_chat_to_bottom_smooth(host)


static func _populate_all_clan_chat_messages(host: Control) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return
	if host._clan_chat_messages.is_empty():
		host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.BADGE_CHAT,
			"هنوز پیامی ارسال نشده است",
			"اولین پیام یا استیکر را در چت اتحاد ثبت کنید!"
		))
		return

	# Add top pagination widget at index 0
	var top_widget := _build_top_pagination_widget(host)
	host._clan_chat_list_vbox.add_child(top_widget)

	var my_uid := str(GameManager.get_user_id())
	var clan_d: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var my_role := str(clan_d.get("my_role", "member"))

	var prev_date_key := ""
	var prev_sender_id := ""
	var prev_minute := -1

	for msg in host._clan_chat_messages:
		if typeof(msg) != TYPE_DICTIONARY:
			continue
		var created_iso := str(msg.get("created_at", ""))
		var date_key := _extract_chat_date_key(created_iso)
		if not date_key.is_empty() and date_key != prev_date_key:
			var div_lbl := _format_date_divider_label(created_iso)
			if not div_lbl.is_empty():
				host._clan_chat_list_vbox.add_child(_build_date_divider_pill(div_lbl))
			prev_date_key = date_key
			prev_sender_id = ""
			prev_minute = -1

		var mtype := str(msg.get("msg_type", "text"))
		var sender_id := str(msg.get("sender_id", ""))
		var cur_min := _extract_chat_minute_stamp(created_iso)
		var is_standard: bool = (mtype != "system" and mtype != "friendly_challenge" and not (typeof(msg.get("metadata")) == TYPE_DICTIONARY and (msg["metadata"] as Dictionary).has("challenge_id")))
		var is_grouped: bool = is_standard and not sender_id.is_empty() and (sender_id == prev_sender_id) and (prev_minute >= 0 and cur_min >= 0 and absi(cur_min - prev_minute) <= 3)

		var bubble := _build_single_chat_bubble(host, msg, my_uid, my_role, is_grouped)
		if bubble != null:
			host._clan_chat_list_vbox.add_child(bubble)
			if is_standard:
				prev_sender_id = sender_id
				prev_minute = cur_min
			else:
				prev_sender_id = ""
				prev_minute = -1

	host._clan_chat_list_vbox.set_meta("last_date_key", prev_date_key)
	host._clan_chat_list_vbox.set_meta("last_sender_id", prev_sender_id)
	host._clan_chat_list_vbox.set_meta("last_minute", prev_minute)


static func append_clan_chat_message(host: Control, msg: Dictionary) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return

	# Remove empty state or loading state placeholder if present
	for ch in host._clan_chat_list_vbox.get_children():
		if ch.name in ["EmptyState", "LoadingState"] or (ch is PanelContainer and (ch.has_node("EmptyStateVBox") or ch.has_node("LoadingVBox"))):
			ch.queue_free()

	# If top pagination widget is not present yet and messages exist, add it
	if not host._clan_chat_list_vbox.has_node("TopPaginationLoader"):
		var top_w := _build_top_pagination_widget(host)
		host._clan_chat_list_vbox.add_child(top_w)
		host._clan_chat_list_vbox.move_child(top_w, 0)

	var my_uid := str(GameManager.get_user_id())
	var clan_d: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var my_role := str(clan_d.get("my_role", "member"))

	var is_mine := (str(msg.get("sender_id", "")) == my_uid)
	var was_near_bottom: bool = _is_scroll_near_bottom(host._clan_chat_scroll)

	var created_iso := str(msg.get("created_at", ""))
	var date_key := _extract_chat_date_key(created_iso)
	var prev_date_key := str(host._clan_chat_list_vbox.get_meta("last_date_key", ""))
	var prev_sender_id := str(host._clan_chat_list_vbox.get_meta("last_sender_id", ""))
	var prev_minute := int(host._clan_chat_list_vbox.get_meta("last_minute", -1))

	if not date_key.is_empty() and date_key != prev_date_key:
		var div_lbl := _format_date_divider_label(created_iso)
		if not div_lbl.is_empty():
			host._clan_chat_list_vbox.add_child(_build_date_divider_pill(div_lbl))
		prev_date_key = date_key
		prev_sender_id = ""
		prev_minute = -1

	var mtype := str(msg.get("msg_type", "text"))
	var sender_id := str(msg.get("sender_id", ""))
	var cur_min := _extract_chat_minute_stamp(created_iso)
	var is_standard: bool = (mtype != "system" and mtype != "friendly_challenge" and not (typeof(msg.get("metadata")) == TYPE_DICTIONARY and (msg["metadata"] as Dictionary).has("challenge_id")))
	var is_grouped: bool = is_standard and not sender_id.is_empty() and (sender_id == prev_sender_id) and (prev_minute >= 0 and cur_min >= 0 and absi(cur_min - prev_minute) <= 3)

	var bubble := _build_single_chat_bubble(host, msg, my_uid, my_role, is_grouped)
	if bubble != null:
		host._clan_chat_list_vbox.add_child(bubble)
		host._clan_chat_list_vbox.set_meta("last_date_key", prev_date_key)
		host._clan_chat_list_vbox.set_meta("last_sender_id", sender_id if is_standard else "")
		host._clan_chat_list_vbox.set_meta("last_minute", cur_min if is_standard else -1)

	# Auto-scroll if mine or near bottom; otherwise show unread counter on floating jump pill!
	if is_mine or was_near_bottom:
		_scroll_clan_chat_to_bottom_smooth(host)
	elif is_instance_valid(host._clan_chat_scroll) and host._clan_chat_scroll.has_meta("jump_btn"):
		var jbtn: Button = host._clan_chat_scroll.get_meta("jump_btn")
		if is_instance_valid(jbtn):
			var ucnt := int(jbtn.get_meta("unread_count", 0)) + 1
			jbtn.set_meta("unread_count", ucnt)
			jbtn.text = "↓ %s پیام جدید" % GameManager.to_fa_num(ucnt)
			jbtn.visible = true


static func _build_single_chat_bubble(host: Control, msg: Dictionary, my_uid: String, my_role: String, is_grouped: bool = false) -> Control:
	var mtype := str(msg.get("msg_type", "text"))
	var sender_id := str(msg.get("sender_id", ""))
	var sender_name := str(msg.get("sender_name", "بازیکن"))
	var sender_role := str(msg.get("sender_role", "member"))
	var sender_img := int(msg.get("sender_image", 0))
	var sender_frame := int(msg.get("sender_profile_frame", msg.get("profile_frame", 1)))
	var text := str(msg.get("text", ""))
	var msg_id := str(msg.get("message_id", msg.get("_id", "")))
	var time_str := CafeSocialTheme.format_time_fa(str(msg.get("created_at", "")))
	var is_mine := (sender_id == my_uid)

	var is_challenge_msg: bool = (mtype == "friendly_challenge") or (mtype == "system" and typeof(msg.get("metadata")) == TYPE_DICTIONARY and msg["metadata"].has("challenge_id"))
	if is_challenge_msg:
		var meta_check: Dictionary = msg.get("metadata", {}) if typeof(msg.get("metadata")) == TYPE_DICTIONARY else {}
		var chal_st: String = str(meta_check.get("status", "open"))
		if chal_st in ["closed", "finished", "canceled", "cancelled"]:
			return null
		return _build_challenge_chat_bubble(host, meta_check, text, my_uid, my_role)

	# --- A. SYSTEM MESSAGES ---
	if mtype == "system":
		return _build_system_chat_bubble(text, time_str)

	# --- B. STANDARD CHAT BUBBLE (Authentic chat_my / chat_other frames, strictly overflow-safe) ---
	var msg_row := HBoxContainer.new()
	msg_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	msg_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_row.add_theme_constant_override("separation", 6)

	# Check if text is a sticker e.g. [استیکر X] or [sticker:X]
	var is_sticker := false
	var sticker_id := 0
	if text.begins_with("[sticker:") and text.ends_with("]"):
		sticker_id = int(text.substr(9, text.length() - 10))
		is_sticker = true
	elif text.begins_with("[استیکر ") and text.ends_with("]"):
		sticker_id = int(text.substr(9, text.length() - 10))
		is_sticker = true

	var s_tex: Texture2D = load("res://assets/icons/Reactions/%d.png" % sticker_id) if (is_sticker and sticker_id >= 1 and sticker_id <= 16) else null
	var render_as_sticker: bool = (s_tex != null)

	# Avatar (matches make_avatar_badge's actual 72x72 footprint so it NEVER spills past the right/left edge!)
	var av_slot: Control
	if is_grouped:
		var av_sp := Control.new()
		av_sp.custom_minimum_size = Vector2(72, 1)
		av_slot = av_sp
	else:
		var av_btn := Button.new()
		av_btn.flat = true
		av_btn.focus_mode = Control.FOCUS_NONE
		av_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		av_btn.custom_minimum_size = Vector2(72, 72)
		av_btn.size_flags_vertical = Control.SIZE_SHRINK_END
		var av_badge := CafeSocialTheme.make_avatar_badge(sender_img, sender_frame, 66.0)
		av_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_btn.add_child(av_badge)
		av_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			UserProfileDialog.show_user({"user_id": sender_id, "username": sender_name, "image": sender_img, "profile_frame": sender_frame}, ROLE_FA_MAP.get(sender_role, "عضو"), host)
		)
		av_slot = av_btn

	# Responsive ratio-based bubble column (never exceeds available ScrollContainer width!)
	var bubble_ratio := 0.78
	if not render_as_sticker:
		var txt_len := text.length()
		if not ("\n" in text):
			if txt_len <= 14:
				bubble_ratio = 0.50
			elif txt_len <= 32:
				bubble_ratio = 0.66
			else:
				bubble_ratio = 0.78

	var bubble_col := VBoxContainer.new()
	if render_as_sticker:
		bubble_col.size_flags_horizontal = Control.SIZE_SHRINK_END if is_mine else Control.SIZE_SHRINK_BEGIN
	else:
		bubble_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble_col.size_flags_stretch_ratio = bubble_ratio
	bubble_col.add_theme_constant_override("separation", 2)

	# Header above bubble (hidden for grouped consecutive messages from same sender!)
	if not is_grouped:
		var hdr_row := HBoxContainer.new()
		hdr_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
		hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr_row.add_theme_constant_override("separation", 6)
		bubble_col.add_child(hdr_row)

		var role_title: String = ROLE_FA_MAP.get(sender_role, "عضو")
		var role_badge := CafeSocialTheme.make_badge_pill(
			role_title,
			CafeSocialTheme.COL_GOLD_BRIGHT if sender_role == "leader" else (CafeSocialTheme.COL_EMERALD_TEXT if sender_role in ["co_leader", "elder"] else CafeSocialTheme.COL_MUTED_SAND),
			Color(0.18, 0.12, 0.05) if sender_role == "leader" else (CafeSocialTheme.COL_EMERALD_BG if sender_role in ["co_leader", "elder"] else Color(0.11, 0.07, 0.04)),
			CafeSocialTheme.COL_GOLD_ANTIQUE if sender_role == "leader" else (CafeSocialTheme.COL_EMERALD_BORDER if sender_role in ["co_leader", "elder"] else CafeSocialTheme.COL_BRONZE_BORDER),
			13
		)

		var uname_lbl := CafeSocialTheme.make_title(
			sender_name if not is_mine else "شما",
			18,
			CafeSocialTheme.COL_EMERALD_TEXT if is_mine else CafeSocialTheme.COL_GOLD_BRIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT if is_mine else HORIZONTAL_ALIGNMENT_LEFT,
			false
		)
		uname_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		uname_lbl.clip_text = true
		uname_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		if is_mine:
			hdr_row.alignment = BoxContainer.ALIGNMENT_END
			if sender_role in ["leader", "co_leader", "elder"]:
				hdr_row.add_child(role_badge)
			hdr_row.add_child(uname_lbl)
		else:
			hdr_row.alignment = BoxContainer.ALIGNMENT_BEGIN
			hdr_row.add_child(uname_lbl)
			if sender_role in ["leader", "co_leader", "elder"]:
				hdr_row.add_child(role_badge)

	# Subtle Delete button WITH confirmation modal (prevents accidental one-tap delete!)
	var del_icon_btn: TextureButton = null
	if (is_mine or my_role in ["leader", "co_leader", "elder"]) and not msg_id.is_empty():
		del_icon_btn = TextureButton.new()
		del_icon_btn.texture_normal = preload("res://assets/images/delete.png")
		del_icon_btn.custom_minimum_size = Vector2(24, 24)
		del_icon_btn.ignore_texture_size = true
		del_icon_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		del_icon_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del_icon_btn.focus_mode = Control.FOCUS_NONE
		del_icon_btn.modulate = Color(1.0, 1.0, 1.0, 0.55)
		del_icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		del_icon_btn.tooltip_text = "حذف پیام"
		ActionVFXManager.apply_button_juice(del_icon_btn, "tap_button")
		del_icon_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			CafeSocialTheme.show_confirm_modal(
				host, "حذف پیام",
				"آیا مطمئن هستید می‌خواهید این پیام را حذف کنید؟",
				"بله، حذف شود", true,
				func():
					NetworkManager.api.delete_clan_chat_message(msg_id, func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._clan_chat_messages = host._clan_chat_messages.filter(func(x): return str(x.get("message_id", x.get("_id", ""))) != msg_id)
							if is_instance_valid(msg_row):
								msg_row.queue_free()
					)
			)
		)

	# Bubble Frame — Authentic chat_my.png for own messages, chat_other.png for others!
	var bubble := PanelContainer.new()
	if render_as_sticker:
		bubble.custom_minimum_size = Vector2(0, 0)
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_mine else Control.SIZE_SHRINK_BEGIN
		bubble.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		bubble.custom_minimum_size = Vector2(140, 74)
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble.add_theme_stylebox_override("panel", CafeSocialTheme.create_chat_bubble_style(is_mine))
	bubble_col.add_child(bubble)

	var b_vbox := VBoxContainer.new()
	b_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_vbox.add_theme_constant_override("separation", 3)
	bubble.add_child(b_vbox)

	if render_as_sticker:
		var s_rect := TextureRect.new()
		s_rect.texture = s_tex
		s_rect.custom_minimum_size = Vector2(96, 96)
		s_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s_rect.size_flags_horizontal = Control.SIZE_SHRINK_END if is_mine else Control.SIZE_SHRINK_BEGIN
		b_vbox.add_child(s_rect)
	else:
		var msg_lbl := Label.new()
		msg_lbl.text = text
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		msg_lbl.add_theme_font_size_override("font_size", 20)
		# Crisp contrast: ivory on dark chat_my.png, dark walnut on parchment chat_other.png
		if is_mine:
			msg_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		else:
			msg_lbl.add_theme_color_override("font_color", Color(0.24, 0.15, 0.06, 1.0))
		b_vbox.add_child(msg_lbl)

	if not time_str.is_empty():
		var date_lbl := Label.new()
		date_lbl.text = time_str
		date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_mine else HORIZONTAL_ALIGNMENT_RIGHT
		date_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		date_lbl.add_theme_font_size_override("font_size", 14)
		if render_as_sticker:
			date_lbl.add_theme_color_override("font_color", Color(0.84, 0.78, 0.66, 0.85))
		elif is_mine:
			date_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 0.85, 0.90))
		else:
			date_lbl.add_theme_color_override("font_color", Color(0.42, 0.32, 0.20, 0.90))
		b_vbox.add_child(date_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0 - bubble_ratio

	if is_mine:
		msg_row.add_child(spacer)
		if del_icon_btn != null:
			msg_row.add_child(del_icon_btn)
		msg_row.add_child(bubble_col)
		msg_row.add_child(av_slot)
	else:
		msg_row.add_child(av_slot)
		msg_row.add_child(bubble_col)
		if del_icon_btn != null:
			msg_row.add_child(del_icon_btn)
		msg_row.add_child(spacer)

	return msg_row


static func _build_system_chat_bubble(text: String, time_str: String = "") -> Control:
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_left", 16)
	wrap.add_theme_constant_override("margin_right", 16)

	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.09, 0.05, 0.90)
	st.border_color = Color(0.68, 0.50, 0.22, 0.60)
	st.set_border_width_all(1)
	st.set_corner_radius_all(12)
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 6.0
	st.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", st)
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(pill)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 8)
	pill.add_child(h)

	var ico := TextureRect.new()
	ico.texture = CafeSocialTheme.ICO_SPARKLE
	ico.custom_minimum_size = Vector2(20, 20)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.modulate = CafeSocialTheme.COL_GOLD_BRIGHT
	h.add_child(ico)

	var full_txt := text
	if not time_str.is_empty():
		full_txt += " (%s)" % time_str
	var lbl := CafeSocialTheme.make_body(full_txt, 17, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lbl)

	return wrap


static func _build_challenge_chat_bubble(host: Control, meta: Dictionary, desc_text: String, my_uid: String, my_role: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.11, 0.06, 0.96)
	st.border_color = Color(0.92, 0.74, 0.30, 0.90)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	if not _is_mobile_platform():
		st.shadow_color = Color(0, 0, 0, 0.35)
		st.shadow_size = 4
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", st)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(top_row)

	var chal_gt: String = str(meta.get("game_type", "Monopoly"))
	var chal_thumb := CafeSocialTheme.get_game_thumb(chal_gt)
	if chal_thumb != null:
		var tr := TextureRect.new()
		tr.texture = chal_thumb
		tr.custom_minimum_size = Vector2(54, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		top_row.add_child(tr)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	top_row.add_child(col)

	var gt_fa: String = str(meta.get("game_title_fa", GameRegistry.get_display_name_fa(chal_gt)))
	col.add_child(CafeSocialTheme.make_title("چالش دوستانه %s" % gt_fa, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	col.add_child(CafeSocialTheme.make_body(desc_text, 17, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var chal_act := _build_challenge_action_row(host, meta, my_uid, my_role, true)
	if chal_act != null:
		v.add_child(chal_act)

	return card


static func _open_sticker_picker(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 60

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.48)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	# Bottom-anchored lightweight slide-up drawer (doesn't cover whole chat!)
	var anchor_box := MarginContainer.new()
	anchor_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_box.offset_top = -390.0
	anchor_box.offset_bottom = 0.0
	anchor_box.add_theme_constant_override("margin_left", 16)
	anchor_box.add_theme_constant_override("margin_right", 16)
	anchor_box.add_theme_constant_override("margin_bottom", 14)
	overlay.add_child(anchor_box)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var drawer_sb := StyleBoxFlat.new()
	drawer_sb.bg_color = Color(0.13, 0.08, 0.04, 0.98)
	drawer_sb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	drawer_sb.set_border_width_all(2)
	drawer_sb.corner_radius_top_left = 18
	drawer_sb.corner_radius_top_right = 18
	drawer_sb.corner_radius_bottom_left = 14
	drawer_sb.corner_radius_bottom_right = 14
	drawer_sb.content_margin_left = 14.0
	drawer_sb.content_margin_right = 14.0
	drawer_sb.content_margin_top = 12.0
	drawer_sb.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", drawer_sb)
	anchor_box.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top_r := HBoxContainer.new()
	vbox.add_child(top_r)

	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(36, 36)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func(): overlay.queue_free())
	top_r.add_child(bx)

	var ttl := CafeSocialTheme.make_title("استیکرها و واکنش‌های اتحاد", 22, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_r.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(36, 36)
	top_r.add_child(sp)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for sid in range(1, 17):
		var s_btn := Button.new()
		s_btn.custom_minimum_size = Vector2(0, 88)
		s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_btn.focus_mode = Control.FOCUS_NONE
		s_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		s_btn.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(Color(0.11, 0.07, 0.04), CafeSocialTheme.COL_BRONZE_BORDER, 11, 1, 6.0, 6.0))
		s_btn.add_theme_stylebox_override("hover", CafeSocialTheme.create_card_style(Color(0.22, 0.15, 0.08), CafeSocialTheme.COL_GOLD_BRIGHT, 11, 2, 6.0, 6.0))

		var s_tex: Texture2D = load("res://assets/icons/Reactions/%d.png" % sid)
		if s_tex != null:
			var tr := TextureRect.new()
			tr.texture = s_tex
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_btn.add_child(tr)

		var chosen_id := sid
		s_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			overlay.queue_free()
			# Direct send — NEVER wipes any text currently typed in host._clan_chat_input!
			_send_clan_chat_text_direct(host, "[sticker:%d]" % chosen_id)
		)
		grid.add_child(s_btn)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


# ==============================================================================
# 3. CLAN OVERVIEW – MAIN CLAN TAB
# ==============================================================================

static func _trigger_leave_or_disband_clan(host: Control, cdict: Dictionary, my_role: String) -> void:
	if my_role == "leader":
		CafeSocialTheme.show_confirm_modal(
			host, "انحلال اتحاد",
			"آیا مطمئن هستید می‌خواهید اتحاد «%s» را منحل کنید؟ تمام اعضای اتحاد خارج خواهند شد." % str(cdict.get("name", "")),
			"بله، منحل شود", true,
			func():
				NetworkManager.api.disband_clan(func(ok: bool, _c: int, d: Variant):
					if ok:
						host._show_toast("اتحاد منحل شد.")
						host._my_clan_data = {}
						host._clan_chat_messages.clear()
						GameManager.user_data.erase("clan")
						GameManager.user_data.erase("clan_id")
						host._update_main_tab_buttons()
						host.current_clans_subtab = "my_clan"
						host._refresh_current_tab()
					elif typeof(d) == TYPE_DICTIONARY:
						host._show_toast(str(d.get("detail", "خطا در انحلال")), CafeSocialTheme.COL_CRIMSON_TEXT)
				)
		)
	else:
		CafeSocialTheme.show_confirm_modal(
			host, "خروج از اتحاد",
			"آیا می‌خواهید از اتحاد «%s» خارج شوید؟" % str(cdict.get("name", "")),
			"خروج از اتحاد", true,
			func():
				NetworkManager.api.leave_clan(func(ok: bool, _c: int, d: Variant):
					if ok:
						host._show_toast("از اتحاد خارج شدید.")
						host._my_clan_data = {}
						host._clan_chat_messages.clear()
						GameManager.user_data.erase("clan")
						GameManager.user_data.erase("clan_id")
						host._update_main_tab_buttons()
						host.current_clans_subtab = "my_clan"
						host._refresh_current_tab()
					elif typeof(d) == TYPE_DICTIONARY:
						host._show_toast(str(d.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
				)
		)


static func _open_invite_friend_to_clan_modal(host: Control, cdict: Dictionary) -> void:
	var m_res := _create_responsive_modal(host, 600.0, 55, 0.80, false)
	var overlay: Control = m_res["overlay"]
	var card: PanelContainer = m_res["card"]
	var vbox: VBoxContainer = m_res["vbox"]

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(42, 42)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_tap()
		overlay.queue_free()
	)
	top.add_child(bx)

	var ttl := CafeSocialTheme.make_title("دعوت دوستان به اتحاد", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(42, 42)
	top.add_child(sp)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(440.0, _calc_modal_max_scroll_h(host, 0.56)))
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vb := VBoxContainer.new()
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vb)

	# Build set of current member IDs so we only show invitable friends
	var member_ids: Dictionary = {}
	var mems_arr: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
	for mem in mems_arr:
		if typeof(mem) == TYPE_DICTIONARY:
			member_ids[str(mem.get("user_id", mem.get("_id", "")))] = true

	var populate_friends := func(friends_arr: Array):
		if not is_instance_valid(list_vb):
			return
		for ch in list_vb.get_children():
			ch.queue_free()
		var eligible: Array = []
		for f in friends_arr:
			if typeof(f) != TYPE_DICTIONARY:
				continue
			var fid := str(f.get("user_id", f.get("_id", "")))
			if fid.is_empty() or member_ids.has(fid):
				continue
			eligible.append(f)
		if eligible.is_empty():
			list_vb.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"دوستی برای دعوت یافت نشد",
				"همه دوستان فعلی شما عضو این اتحاد هستند یا هنوز دوستی اضافه نکرده‌اید."
			))
			return
		for f in eligible:
			var fid := str(f.get("user_id", f.get("_id", "")))
			var fname := str(f.get("username", "بازیکن"))
			var fcard := PanelContainer.new()
			var fsb := StyleBoxFlat.new()
			fsb.bg_color = Color(0.14, 0.09, 0.05, 0.95)
			fsb.border_color = Color(0.50, 0.36, 0.20, 0.65)
			fsb.set_border_width_all(1)
			fsb.set_corner_radius_all(12)
			fsb.content_margin_left = 12.0
			fsb.content_margin_right = 12.0
			fsb.content_margin_top = 8.0
			fsb.content_margin_bottom = 8.0
			fcard.add_theme_stylebox_override("panel", fsb)

			var frow := HBoxContainer.new()
			frow.alignment = BoxContainer.ALIGNMENT_CENTER
			frow.add_theme_constant_override("separation", 10)
			fcard.add_child(frow)

			var b_inv := CafeSocialTheme.make_button("دعوت", "emerald", Vector2(102, 42), 19)
			b_inv.pressed.connect(func():
				AudioManager.sfx_button()
				b_inv.disabled = true
				NetworkManager.api.invite_to_clan(fid, func(ok: bool, _c: int, res_d: Variant):
					if ok:
						if is_instance_valid(b_inv):
							b_inv.text = "✓ ارسال شد"
						host._show_toast("دعوت‌نامه اتحاد برای «%s» ارسال شد!" % fname)
					else:
						if is_instance_valid(b_inv):
							b_inv.disabled = false
						var err_msg := str(res_d.get("detail", "خطا در ارسال دعوت")) if typeof(res_d) == TYPE_DICTIONARY else "خطا در ارسال دعوت"
						host._show_toast(err_msg, CafeSocialTheme.COL_CRIMSON_TEXT)
				)
			)
			frow.add_child(b_inv)

			var fcol := VBoxContainer.new()
			fcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fcol.alignment = BoxContainer.ALIGNMENT_CENTER
			frow.add_child(fcol)
			fcol.add_child(CafeSocialTheme.make_title(fname, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false))
			var f_score := int(f.get("score", 0))
			fcol.add_child(CafeSocialTheme.make_body("امتیاز: %s" % GameManager.to_fa_num(f_score), 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

			frow.add_child(CafeSocialTheme.make_avatar_badge(int(f.get("image", 0)), int(f.get("profile_frame", 1)), 50.0))
			list_vb.add_child(fcard)

	if not host._friends_list.is_empty():
		populate_friends.call(host._friends_list)
	else:
		list_vb.add_child(CafeSocialTheme.make_loading_state("در حال دریافت فهرست دوستان..."))
		NetworkManager.api.get_friends_list(func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(host):
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				host._friends_list = data["result"]
			populate_friends.call(host._friends_list)
		)

	var b_close := CafeSocialTheme.make_button("بستن", "muted", Vector2(0, 46), 20)
	b_close.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(b_close)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _build_clan_overview_tab(host: Control, holder: VBoxContainer, cdict: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var my_role := str(cdict.get("my_role", "member"))
	var my_uid := str(GameManager.get_user_id())
	var clvl := int(cdict.get("clan_level", 1))

	# Join clan room in realtime for live events
	var cid := str(cdict.get("clan_id", cdict.get("_id", "")))
	if not cid.is_empty():
		NetworkManager.join_clan_room_realtime(cid)

	# --------------------------------------------------------------------------
	# A. FOCUSED CLAN STATUS & PROGRESS CARD (no duplicate emblem/name from header)
	# --------------------------------------------------------------------------
	var hero_card := PanelContainer.new()
	hero_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_panel_box_style(46.0, 24.0))
	vbox.add_child(hero_card)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	hero_card.add_child(hv)

	# Description + Leader + Join Type row
	var desc_row := HBoxContainer.new()
	desc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	desc_row.add_theme_constant_override("separation", 10)
	hv.add_child(desc_row)

	var leader_name := str(cdict.get("leader_name", ""))
	if leader_name.is_empty():
		var mems_check: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
		for m in mems_check:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("role", "")) == "leader":
				leader_name = str(m.get("username", ""))
				break
	if not leader_name.is_empty():
		desc_row.add_child(CafeSocialTheme.make_badge_pill("👑 %s" % leader_name, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.12, 0.07, 0.04), CafeSocialTheme.COL_BRONZE_BORDER, 16))

	var desc := str(cdict.get("description", "")).strip_edges()
	var desc_lbl := CafeSocialTheme.make_body(desc if not desc.is_empty() else "باشگاه اختصاصی بازیکنان کافه فکر", 19, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_row.add_child(desc_lbl)

	# Clan XP Progress Bar
	var cxp := int(cdict.get("clan_xp", 0))
	var next_xp: int = maxi(100, clvl * 500)
	var xp_ratio: float = float(cxp % next_xp) / float(next_xp)
	hv.add_child(CafeSocialTheme.make_xp_progress_bar(
		xp_ratio,
		"تجربه اتحاد: %s / %s XP" % [GameManager.to_fa_num(cxp % next_xp), GameManager.to_fa_num(next_xp)],
		Color(0.88, 0.70, 0.24)
	))

	# 3-Stat Strip
	var stat_strip := HBoxContainer.new()
	stat_strip.add_theme_constant_override("separation", 8)
	hv.add_child(stat_strip)

	var st1 := CafeSocialTheme.make_metric_card("امتیاز کل", GameManager.to_fa_num(int(cdict.get("clan_score", 0))), CafeSocialTheme.COL_GOLD_BRIGHT, null)
	st1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_strip.add_child(st1)

	var st2 := CafeSocialTheme.make_metric_card("فعالیت هفتگی", GameManager.to_fa_num(int(cdict.get("weekly_score", 0))), CafeSocialTheme.COL_EMERALD_TEXT, null)
	st2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_strip.add_child(st2)

	var st3 := CafeSocialTheme.make_metric_card("اعضا", "%s / %s" % [GameManager.to_fa_num(int(cdict.get("member_count", 1))), GameManager.to_fa_num(int(cdict.get("max_members", 40)))], CafeSocialTheme.COL_IVORY, null)
	st3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_strip.add_child(st3)

	# --------------------------------------------------------------------------
	# B. POSITIVE PRIMARY ACTIONS BAR (Destructive Leave/Disband moved to Settings/Bottom)
	# --------------------------------------------------------------------------
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	vbox.add_child(act_row)

	if my_role in ["leader", "co_leader"]:
		var b_settings := CafeSocialTheme.make_button("تنظیمات", "bronze", Vector2(0, 50), 21)
		b_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_settings.pressed.connect(func():
			AudioManager.sfx_tap()
			_open_clan_settings_modal(host, cdict)
		)
		act_row.add_child(b_settings)

	if my_role in ["leader", "co_leader", "elder"]:
		var b_invite := CafeSocialTheme.make_button("دعوت دوست", "gold", Vector2(0, 50), 21)
		b_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_invite.pressed.connect(func():
			AudioManager.sfx_tap()
			_open_invite_friend_to_clan_modal(host, cdict)
		)
		act_row.add_child(b_invite)

	var b_challenge := CafeSocialTheme.make_button("چالش دوستانه", "emerald", Vector2(0, 50), 22, CafeSocialTheme.ICO_LOBBY, true)
	b_challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_challenge.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_friendly_challenge_modal(host)
	)
	act_row.add_child(b_challenge)

	# --------------------------------------------------------------------------
	# C. PENDING JOIN REQUESTS (Surfaced prominently at top for Elder+!)
	# --------------------------------------------------------------------------
	var pending_reqs: Array = cdict.get("pending_join_requests", []) if typeof(cdict.get("pending_join_requests")) == TYPE_ARRAY else []
	if not pending_reqs.is_empty():
		var req_banner := PanelContainer.new()
		var rb_st := StyleBoxFlat.new()
		rb_st.bg_color = Color(0.20, 0.14, 0.05, 0.96)
		rb_st.border_color = CafeSocialTheme.COL_GOLD_BRIGHT
		rb_st.set_border_width_all(2)
		rb_st.set_corner_radius_all(12)
		rb_st.content_margin_left = 12.0
		rb_st.content_margin_right = 12.0
		rb_st.content_margin_top = 8.0
		rb_st.content_margin_bottom = 8.0
		req_banner.add_theme_stylebox_override("panel", rb_st)
		vbox.add_child(req_banner)

		var req_bv := VBoxContainer.new()
		req_bv.add_theme_constant_override("separation", 8)
		req_banner.add_child(req_bv)

		req_bv.add_child(CafeSocialTheme.make_title(
			"🔔 %s درخواست عضویت جدید در انتظار تایید شما" % GameManager.to_fa_num(pending_reqs.size()),
			21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true
		))
		for req in pending_reqs:
			if typeof(req) == TYPE_DICTIONARY:
				req_bv.add_child(_build_join_request_card(host, req))

	# --------------------------------------------------------------------------
	# D. ACTIVE FRIENDLY CHALLENGES
	# --------------------------------------------------------------------------
	var open_chals_raw: Variant = cdict.get("open_challenges", host._my_clan_data.get("open_challenges", []))
	var open_chals: Array = open_chals_raw if typeof(open_chals_raw) == TYPE_ARRAY else []
	if not open_chals.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های دوستانه فعال", CafeSocialTheme.ICO_LOBBY, "%s چالش باز در انتظار هم‌تیمی" % GameManager.to_fa_num(open_chals.size())
		))
		for ch_item in open_chals:
			if typeof(ch_item) == TYPE_DICTIONARY:
				vbox.add_child(_build_overview_challenge_card(host, ch_item, my_uid, my_role))

	# --------------------------------------------------------------------------
	# E. WEEKLY CLAN CHALLENGES (with weekly reset hint)
	# --------------------------------------------------------------------------
	var challenges: Array = cdict.get("weekly_challenges", []) if typeof(cdict.get("weekly_challenges")) == TYPE_ARRAY else []
	if not challenges.is_empty():
		var now_dt: Dictionary = Time.get_datetime_dict_from_system()
		var wday: int = int(now_dt.get("weekday", 0)) # 0=Sun..6=Sat; reset on Saturday 00:00 (Iran week)
		var days_left: int = (6 - wday) if wday < 6 else 7
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های هفتگی اتحاد", null,
			"⏳ تا بازنشانی هفتگی: %s روز  •  دریافت XP برای ارتقای سطح اتحاد" % GameManager.to_fa_num(days_left)
		))
		for ch in challenges:
			if typeof(ch) == TYPE_DICTIONARY:
				vbox.add_child(_build_weekly_challenge_card(ch))

	# --------------------------------------------------------------------------
	# F. RECENT CLAN ACTIVITY TIMELINE
	# --------------------------------------------------------------------------
	var audit_logs: Array = cdict.get("audit_logs", host._my_clan_data.get("audit_logs", [])) if typeof(cdict.get("audit_logs", host._my_clan_data.get("audit_logs", []))) == TYPE_ARRAY else []
	if not audit_logs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"رویدادها و فعالیت‌های اخیر اتحاد", CafeSocialTheme.ICO_HISTORY, "ثبت خودکار پیوستن، ارتقای درجه و دستاوردهای اعضا"
		))
		var act_card := PanelContainer.new()
		var ac_st := StyleBoxFlat.new()
		ac_st.bg_color = Color(0.12, 0.08, 0.04, 0.95)
		ac_st.border_color = Color(0.50, 0.36, 0.20, 0.65)
		ac_st.set_border_width_all(1)
		ac_st.set_corner_radius_all(14)
		ac_st.content_margin_left = 14.0
		ac_st.content_margin_right = 14.0
		ac_st.content_margin_top = 10.0
		ac_st.content_margin_bottom = 10.0
		act_card.add_theme_stylebox_override("panel", ac_st)
		vbox.add_child(act_card)

		var ac_vbox := VBoxContainer.new()
		ac_vbox.add_theme_constant_override("separation", 8)
		act_card.add_child(ac_vbox)

		for entry in audit_logs.slice(0, 6):
			if typeof(entry) == TYPE_DICTIONARY:
				ac_vbox.add_child(_build_activity_entry_row(entry))

	# --------------------------------------------------------------------------
	# G. BOTTOM DANGER ZONE (Safe separation from primary CTAs)
	# --------------------------------------------------------------------------
	var danger_sep := HSeparator.new()
	danger_sep.modulate = Color(0.65, 0.30, 0.25, 0.45)
	vbox.add_child(danger_sep)

	var danger_row := HBoxContainer.new()
	danger_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(danger_row)

	var b_leave_bottom := CafeSocialTheme.make_button(
		"انحلال اتحاد" if my_role == "leader" else "خروج از اتحاد",
		"crimson", Vector2(220, 44), 19
	)
	b_leave_bottom.pressed.connect(func():
		AudioManager.sfx_tap()
		_trigger_leave_or_disband_clan(host, cdict, my_role)
	)
	danger_row.add_child(b_leave_bottom)


static func _build_weekly_challenge_card(ch: Dictionary) -> PanelContainer:
	var ch_card := PanelContainer.new()
	var done := bool(ch.get("completed", false))
	ch_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_item_frame_style(46.0, 14.0))

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	ch_card.add_child(cv)

	var cr := HBoxContainer.new()
	cv.add_child(cr)

	var xp_reward := int(ch.get("reward_clan_xp", 150))
	var pill := CafeSocialTheme.make_badge_pill(
		"تکمیل شد!" if done else "+%s XP اتحاد" % GameManager.to_fa_num(xp_reward),
		CafeSocialTheme.COL_EMERALD_TEXT if done else CafeSocialTheme.COL_GOLD_BRIGHT,
		CafeSocialTheme.COL_EMERALD_BG if done else Color(0.18, 0.11, 0.04),
		CafeSocialTheme.COL_EMERALD_BORDER if done else CafeSocialTheme.COL_GOLD_ANTIQUE,
		18
	)
	cr.add_child(pill)

	var ct := CafeSocialTheme.make_title(str(ch.get("title", "")), 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
	ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(ct)

	cv.add_child(CafeSocialTheme.make_body(str(ch.get("desc", "")), 20, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var prog := int(ch.get("progress", 0))
	var targ: int = maxi(1, int(ch.get("target", 1)))
	cv.add_child(CafeSocialTheme.make_xp_progress_bar(
		float(prog) / float(targ),
		"%s از %s" % [GameManager.to_fa_num(prog), GameManager.to_fa_num(targ)],
		Color(0.38, 0.88, 0.54) if done else Color(0.88, 0.68, 0.24)
	))
	return ch_card


static func _build_join_request_card(host: Control, req: Dictionary) -> PanelContainer:
	var ru: Dictionary = req.get("user", {}) if typeof(req.get("user")) == TYPE_DICTIONARY else {}
	var rid := str(req.get("request_id", ""))
	var rcard := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.10, 0.06, 0.95)
	sb.border_color = Color(0.65, 0.48, 0.24, 0.70)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	rcard.add_theme_stylebox_override("panel", sb)

	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 10)
	rcard.add_child(rrow)

	var b_no := CafeSocialTheme.make_button("رد", "crimson", Vector2(88, 44), 20)
	b_no.pressed.connect(func():
		b_no.disabled = true
		NetworkManager.api.respond_clan_join_request(rid, "reject", func(ok: bool, _c: int, _d: Variant):
			if ok:
				host._show_toast("درخواست عضویت رد شد.")
			if host.has_method("refresh_my_clan_data"):
				host.refresh_my_clan_data(true)
			else:
				host._refresh_current_tab()
		)
	)
	rrow.add_child(b_no)

	var b_ok := CafeSocialTheme.make_button("پذیرش", "emerald", Vector2(110, 44), 20)
	b_ok.pressed.connect(func():
		b_ok.disabled = true
		NetworkManager.api.respond_clan_join_request(rid, "accept", func(ok: bool, _c: int, _d: Variant):
			if ok:
				host._show_toast("عضو جدید به اتحاد پیوست!")
			if host.has_method("refresh_my_clan_data"):
				host.refresh_my_clan_data(true)
			else:
				host._refresh_current_tab()
		)
	)
	rrow.add_child(b_ok)

	var rcol := VBoxContainer.new()
	rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rcol)
	rcol.add_child(CafeSocialTheme.make_title(str(ru.get("username", "بازیکن")), 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
	rcol.add_child(CafeSocialTheme.make_body("امتیاز: %s" % GameManager.to_fa_num(int(ru.get("score", 0))), 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	rrow.add_child(CafeSocialTheme.make_avatar_badge(int(ru.get("image", 0)), int(ru.get("profile_frame", 1)), 60.0))
	return rcard


static func _build_activity_entry_row(entry: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)

	var act := str(entry.get("action", ""))
	var meta: Dictionary = entry.get("metadata", {}) if typeof(entry.get("metadata")) == TYPE_DICTIONARY else {}
	var actor := str(entry.get("actor_name", entry.get("username", meta.get("actor_name", meta.get("username", ""))))).strip_edges()
	var target := str(entry.get("target_name", meta.get("target_name", meta.get("target_username", "")))).strip_edges()
	var new_role_raw := str(entry.get("new_role", meta.get("new_role", meta.get("role", "")))).strip_edges()
	var new_role_fa: String = ROLE_FA_MAP.get(new_role_raw, "")
	var custom_msg := str(entry.get("message", entry.get("description", ""))).strip_edges()

	var text_desc := ""
	var act_col := CafeSocialTheme.COL_WARM_CREAM
	var act_ico: Texture2D = CafeSocialTheme.ICO_SPARKLE

	match act:
		"member_joined", "join_accepted":
			var who := target if not target.is_empty() else actor
			text_desc = "«%s» به اتحاد پیوست" % who if not who.is_empty() else "عضو جدید به جمع اعضای اتحاد پیوست"
			act_col = CafeSocialTheme.COL_EMERALD_TEXT
			act_ico = CafeSocialTheme.ICO_STAR
		"member_left":
			var who := actor if not actor.is_empty() else target
			text_desc = "«%s» از اتحاد خارج شد" % who if not who.is_empty() else "یکی از اعضا از اتحاد خارج شد"
			act_col = CafeSocialTheme.COL_CRIMSON_TEXT
		"member_kicked":
			if not target.is_empty() and not actor.is_empty():
				text_desc = "«%s» توسط «%s» از اتحاد اخراج شد" % [target, actor]
			elif not target.is_empty():
				text_desc = "«%s» از اتحاد اخراج شد" % target
			else:
				text_desc = "یکی از اعضا توسط مدیر از اتحاد اخراج شد"
			act_col = CafeSocialTheme.COL_CRIMSON_TEXT
		"role_changed", "member_promoted":
			var who := target if not target.is_empty() else actor
			if not who.is_empty() and not new_role_fa.is_empty():
				text_desc = "سمت «%s» به %s تغییر یافت" % [who, new_role_fa]
			elif not who.is_empty():
				text_desc = "درجه «%s» در اتحاد تغییر یافت" % who
			else:
				text_desc = "درجه و مسئولیت یکی از اعضای اتحاد تغییر یافت"
			act_col = CafeSocialTheme.COL_GOLD_BRIGHT
			act_ico = CafeSocialTheme.ICO_KING
		"leadership_transferred":
			text_desc = "رهبری اتحاد به «%s» منتقل شد" % target if not target.is_empty() else "رهبری اتحاد با موفقیت منتقل گردید"
			act_col = CafeSocialTheme.COL_GOLD_BRIGHT
			act_ico = CafeSocialTheme.ICO_KING
		"clan_created":
			text_desc = "اتحاد توسط «%s» تاسیس شد" % actor if not actor.is_empty() else "اتحاد رسماً تاسیس شد"
			act_col = CafeSocialTheme.COL_GOLD_BRIGHT
		_:
			text_desc = custom_msg if not custom_msg.is_empty() else "رویداد جدید در اتحاد ثبت شد"

	var time_lbl := CafeSocialTheme.make_body(CafeSocialTheme.format_time_fa(str(entry.get("created_at", ""))), 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_LEFT, false)
	h.add_child(time_lbl)

	var d_lbl := CafeSocialTheme.make_body(text_desc, 18, act_col, HORIZONTAL_ALIGNMENT_RIGHT, true)
	d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(d_lbl)

	var tr := TextureRect.new()
	tr.texture = act_ico
	tr.custom_minimum_size = Vector2(22, 22)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = act_col
	h.add_child(tr)
	return h


# ==============================================================================
# 4. CLAN MEMBERS – MEMBERS TAB
# ==============================================================================

static func _build_clan_members_tab(host: Control, holder: VBoxContainer, cdict: Dictionary) -> void:
	var members: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
	var my_role := str(cdict.get("my_role", "member"))
	var my_uid := str(GameManager.get_user_id())
	var max_cap := int(cdict.get("max_members", 40))

	# A. Slim Single-Line Summary Bar (reclaims ~70px vs 4 metric cards)
	var online_cnt := 0
	var officers_cnt := 0
	var total_contrib := 0
	for m in members:
		if typeof(m) == TYPE_DICTIONARY:
			total_contrib += int(m.get("weekly_contribution", 0))
			var mr := str(m.get("role", "member"))
			if mr in ["leader", "co_leader", "elder"]:
				officers_cnt += 1
			var pres: Dictionary = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
			var st: String = str(pres.get("status", "offline"))
			if st in ["online", "in_game", "in_lobby", "in_queue"]:
				online_cnt += 1
	if online_cnt == 0 and not members.is_empty():
		online_cnt = 1

	var sum_bar := PanelContainer.new()
	var sum_sb := StyleBoxFlat.new()
	sum_sb.bg_color = Color(0.13, 0.09, 0.05, 0.94)
	sum_sb.border_color = Color(0.55, 0.40, 0.22, 0.65)
	sum_sb.set_border_width_all(1)
	sum_sb.set_corner_radius_all(10)
	sum_sb.content_margin_left = 12.0
	sum_sb.content_margin_right = 12.0
	sum_sb.content_margin_top = 6.0
	sum_sb.content_margin_bottom = 6.0
	sum_bar.add_theme_stylebox_override("panel", sum_sb)
	holder.add_child(sum_bar)

	var sum_row := HBoxContainer.new()
	sum_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sum_row.add_theme_constant_override("separation", 10)
	sum_bar.add_child(sum_row)

	var lbl_contrib := CafeSocialTheme.make_body("مشارکت: %s" % GameManager.to_fa_num(total_contrib), 17, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	sum_row.add_child(lbl_contrib)
	sum_row.add_child(CafeSocialTheme.make_body("•", 15, CafeSocialTheme.COL_BRONZE_BORDER, HORIZONTAL_ALIGNMENT_CENTER, false))

	var on_row := HBoxContainer.new()
	on_row.alignment = BoxContainer.ALIGNMENT_CENTER
	on_row.add_theme_constant_override("separation", 4)
	var lbl_on_val := CafeSocialTheme.make_title(GameManager.to_fa_num(online_cnt), 18, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	host._clan_members_online_val_lbl = lbl_on_val
	on_row.add_child(lbl_on_val)
	on_row.add_child(CafeSocialTheme.make_body("آنلاین:", 17, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	sum_row.add_child(on_row)

	sum_row.add_child(CafeSocialTheme.make_body("•", 15, CafeSocialTheme.COL_BRONZE_BORDER, HORIZONTAL_ALIGNMENT_CENTER, false))
	sum_row.add_child(CafeSocialTheme.make_body("اعضا: %s/%s" % [GameManager.to_fa_num(members.size()), GameManager.to_fa_num(max_cap)], 17, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, false))

	# B. Search + Sort Cycle + 3 Clean Filter Chips (Zero horizontal overflow!)
	var filter_card := PanelContainer.new()
	var fc_sb := StyleBoxFlat.new()
	fc_sb.bg_color = Color(0.12, 0.08, 0.04, 0.94)
	fc_sb.border_color = Color(0.50, 0.38, 0.20, 0.65)
	fc_sb.set_border_width_all(1)
	fc_sb.set_corner_radius_all(12)
	fc_sb.content_margin_left = 10.0
	fc_sb.content_margin_right = 10.0
	fc_sb.content_margin_top = 8.0
	fc_sb.content_margin_bottom = 8.0
	filter_card.add_theme_stylebox_override("panel", fc_sb)
	holder.add_child(filter_card)

	var fc_vbox := VBoxContainer.new()
	fc_vbox.add_theme_constant_override("separation", 7)
	filter_card.add_child(fc_vbox)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	fc_vbox.add_child(search_row)

	var cur_sort := ["role"] # "role" | "contrib" | "score"
	var sort_order := ["role", "contrib", "score"]
	var sort_labels := {
		"role": "مرتب‌سازی: سمت ▾",
		"contrib": "مرتب‌سازی: مشارکت ▾",
		"score": "مرتب‌سازی: امتیاز ▾",
	}
	var btn_sort := CafeSocialTheme.make_button(sort_labels["role"], "bronze", Vector2(168, 44), 17)
	search_row.add_child(btn_sort)

	var search_input := CafeSocialTheme.make_line_edit("جستجوی نام عضو...", 44.0, 19)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(search_input)

	# 3 Clean Filter Pills with live counts
	var pills_row := HBoxContainer.new()
	pills_row.add_theme_constant_override("separation", 6)
	fc_vbox.add_child(pills_row)

	var cur_filter := ["all"] # "all" | "online" | "officers"
	var pill_defs := [
		{"id": "officers", "label": "مدیران (%s)" % GameManager.to_fa_num(officers_cnt)},
		{"id": "online", "label": "آنلاین (%s)" % GameManager.to_fa_num(online_cnt)},
		{"id": "all", "label": "همه (%s)" % GameManager.to_fa_num(members.size())},
	]

	# C. Scrollable Member Cards List
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var m_vbox := VBoxContainer.new()
	m_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(m_vbox)

	# Pre-build member cards ONCE for instant zero-rebuild search/filter/sort!
	var card_nodes: Array[PanelContainer] = []
	for m_item in members:
		if typeof(m_item) != TYPE_DICTIONARY:
			continue
		var mc := _build_clan_member_card(host, m_item, my_uid, my_role)
		card_nodes.append(mc)
		m_vbox.add_child(mc)

	var empty_holder := CafeSocialTheme.make_empty_state(
		CafeSocialTheme.ICO_INFO,
		"عضوی با این مشخصات یافت نشد",
		"عبارت جستجو یا فیلتر را تغییر دهید."
	)
	empty_holder.visible = false
	m_vbox.add_child(empty_holder)

	var pill_buttons: Dictionary = {}
	var apply_sort_order := func():
		var sorted_cards: Array[PanelContainer] = card_nodes.duplicate()
		match cur_sort[0]:
			"contrib":
				sorted_cards.sort_custom(func(a: PanelContainer, b: PanelContainer):
					return int(a.get_meta("contrib", 0)) > int(b.get_meta("contrib", 0))
				)
			"score":
				sorted_cards.sort_custom(func(a: PanelContainer, b: PanelContainer):
					return int(a.get_meta("score", 0)) > int(b.get_meta("score", 0))
				)
			_:
				sorted_cards.sort_custom(func(a: PanelContainer, b: PanelContainer):
					var ra: int = int(a.get_meta("role_rank", 1))
					var rb: int = int(b.get_meta("role_rank", 1))
					if ra != rb:
						return ra > rb
					return int(a.get_meta("contrib", 0)) > int(b.get_meta("contrib", 0))
				)
		for idx in range(sorted_cards.size()):
			m_vbox.move_child(sorted_cards[idx], idx)

	var apply_filter_visibility := func():
		var q := search_input.text.strip_edges().to_lower()
		var visible_cnt := 0
		for mc in card_nodes:
			if not is_instance_valid(mc):
				continue
			var show_card := true
			if not q.is_empty() and not (q in str(mc.get_meta("uname_lower", ""))):
				show_card = false
			if show_card:
				match cur_filter[0]:
					"online":
						if not bool(mc.get_meta("is_online", false)):
							show_card = false
					"officers":
						if not bool(mc.get_meta("is_officer", false)):
							show_card = false
			mc.visible = show_card
			if show_card:
				visible_cnt += 1
		empty_holder.visible = (visible_cnt == 0)

	btn_sort.pressed.connect(func():
		AudioManager.sfx_tap()
		var idx: int = sort_order.find(cur_sort[0])
		cur_sort[0] = sort_order[(idx + 1) % sort_order.size()]
		btn_sort.text = sort_labels[cur_sort[0]]
		apply_sort_order.call()
	)

	var update_pill_styles := func():
		for pk in pill_buttons.keys():
			var pb: Button = pill_buttons[pk]
			var act: bool = (pk == cur_filter[0])
			pb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 10))
			pb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 10))

	for pd in pill_defs:
		var pid: String = pd["id"]
		var pb := CafeSocialTheme.make_button(pd["label"], "muted", Vector2(0, 38), 18)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func():
			AudioManager.sfx_tap()
			cur_filter[0] = pid
			update_pill_styles.call()
			apply_filter_visibility.call()
		)
		pill_buttons[pid] = pb
		pills_row.add_child(pb)

	search_input.text_changed.connect(func(_t: String): apply_filter_visibility.call())
	update_pill_styles.call()
	apply_sort_order.call()
	apply_filter_visibility.call()


static func _build_clan_member_card(host: Control, m_dict: Dictionary, my_uid: String, my_role: String) -> PanelContainer:
	var m_uid := str(m_dict.get("user_id", m_dict.get("_id", "")))
	var m_name := str(m_dict.get("username", "بازیکن"))
	var m_role := str(m_dict.get("role", "member"))
	var m_role_fa := str(m_dict.get("role_title", m_dict.get("role_fa", ROLE_FA_MAP.get(m_role, "عضو"))))
	var m_contrib := int(m_dict.get("weekly_contribution", 0))
	var m_score := int(m_dict.get("score", 0))
	var m_pres: Dictionary = m_dict.get("presence", {}) if typeof(m_dict.get("presence")) == TYPE_DICTIONARY else {}
	var p_info := CafeSocialTheme.format_presence(m_pres)
	var raw_st := str(m_pres.get("status", "offline"))
	var is_self: bool = (m_uid == my_uid)
	var is_online: bool = raw_st in ["online", "in_game", "in_lobby", "in_queue"]
	var is_officer: bool = m_role in ["leader", "co_leader", "elder"]
	var can_manage: bool = (not is_self) and (
		my_role == "leader"
		or (my_role == "co_leader" and m_role in ["elder", "member"])
		or (my_role == "elder" and m_role == "member")
	)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 84)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("uid", m_uid)
	card.set_meta("uname_lower", m_name.to_lower())
	card.set_meta("role_rank", int(ROLE_RANKS.get(m_role, 1)))
	card.set_meta("is_online", is_online)
	card.set_meta("is_officer", is_officer)
	card.set_meta("contrib", m_contrib)
	card.set_meta("score", m_score)

	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_item_frame_style(48.0, 14.0))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Left contextual actions (no misleading config gear for non-managers or self!)
	var act_col := HBoxContainer.new()
	act_col.alignment = BoxContainer.ALIGNMENT_CENTER
	act_col.add_theme_constant_override("separation", 6)
	row.add_child(act_col)

	if not is_self and bool(p_info.get("is_in_game", false)):
		var b_spec := CafeSocialTheme.make_button("تماشا", "emerald", Vector2(74, 34), 16)
		b_spec.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.request_spectate_game(str(p_info.get("game_id", "")), m_uid)
			host._show_toast("درخواست تماشای مسابقه ارسال شد...")
		)
		act_col.add_child(b_spec)

	if is_self:
		act_col.add_child(CafeSocialTheme.make_badge_pill("شما", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 15))
	elif can_manage:
		var b_mgr := TextureButton.new()
		b_mgr.custom_minimum_size = Vector2(38, 38)
		b_mgr.ignore_texture_size = true
		b_mgr.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b_mgr.texture_normal = preload("res://assets/images/config.png")
		b_mgr.focus_mode = Control.FOCUS_NONE
		b_mgr.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b_mgr.tooltip_text = "مدیریت و عملیات عضو"
		ActionVFXManager.apply_button_juice(b_mgr, "tap_button")
		b_mgr.pressed.connect(func():
			AudioManager.sfx_tap()
			_open_member_interaction_sheet(host, m_dict, my_role)
		)
		act_col.add_child(b_mgr)
	else:
		var b_dm_quick := TextureButton.new()
		b_dm_quick.custom_minimum_size = Vector2(38, 38)
		b_dm_quick.ignore_texture_size = true
		b_dm_quick.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b_dm_quick.texture_normal = CafeSocialTheme.BADGE_CHAT
		b_dm_quick.focus_mode = Control.FOCUS_NONE
		b_dm_quick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b_dm_quick.tooltip_text = "پیام خصوصی"
		ActionVFXManager.apply_button_juice(b_dm_quick, "tap_button")
		b_dm_quick.pressed.connect(func():
			AudioManager.sfx_tap()
			host.open_direct_message_with(m_uid, m_name)
		)
		act_col.add_child(b_dm_quick)

	# Center member details — clean 2-row balanced hierarchy
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	# Row 1: Inline Role Badge + Balanced 23px Username
	var top_info_row := HBoxContainer.new()
	top_info_row.alignment = BoxContainer.ALIGNMENT_END
	top_info_row.add_theme_constant_override("separation", 6)
	col.add_child(top_info_row)

	var role_badge := CafeSocialTheme.make_badge_pill(
		"👑 %s" % m_role_fa if m_role == "leader" else ("⭐ %s" % m_role_fa if m_role == "co_leader" else ("🛡️ %s" % m_role_fa if m_role == "elder" else m_role_fa)),
		CafeSocialTheme.COL_GOLD_BRIGHT if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_TEXT if m_role in ["co_leader", "elder"] else CafeSocialTheme.COL_MUTED_SAND),
		Color(0.20, 0.13, 0.05) if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_BG if m_role in ["co_leader", "elder"] else Color(0.11, 0.08, 0.05)),
		CafeSocialTheme.COL_GOLD_ANTIQUE if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_BORDER if m_role in ["co_leader", "elder"] else CafeSocialTheme.COL_BRONZE_BORDER),
		14
	)
	top_info_row.add_child(role_badge)

	var nm_lbl := CafeSocialTheme.make_title(
		m_name,
		23,
		CafeSocialTheme.COL_GOLD_BRIGHT if m_role == "leader" else CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	nm_lbl.clip_text = true
	nm_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_info_row.add_child(nm_lbl)

	# Row 2: Contribution & Score
	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_END
	meta_row.add_theme_constant_override("separation", 6)
	col.add_child(meta_row)

	var score_lbl := CafeSocialTheme.make_body("امتیاز: %s" % GameManager.to_fa_num(m_score), 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)
	var dot_lbl := CafeSocialTheme.make_body("•", 15, CafeSocialTheme.COL_BRONZE_BORDER, HORIZONTAL_ALIGNMENT_CENTER, false)

	var contrib_val_lbl := Label.new()
	contrib_val_lbl.text = "+%s" % GameManager.to_fa_num(m_contrib)
	contrib_val_lbl.layout_direction = Control.LAYOUT_DIRECTION_LTR
	contrib_val_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT if m_contrib > 0 else CafeSocialTheme.COL_MUTED_SAND)
	contrib_val_lbl.add_theme_font_size_override("font_size", 16)
	contrib_val_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)

	var contrib_title_lbl := CafeSocialTheme.make_body("مشارکت:", 16, CafeSocialTheme.COL_GOLD_BRIGHT if m_contrib > 0 else CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)

	meta_row.add_child(score_lbl)
	meta_row.add_child(dot_lbl)
	meta_row.add_child(contrib_val_lbl)
	meta_row.add_child(contrib_title_lbl)

	# Right: Avatar with frame (72x72 matches make_avatar_badge's actual size — zero right-edge spill!)
	var av_holder := Control.new()
	av_holder.custom_minimum_size = Vector2(72, 72)
	av_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var av_vis := CafeSocialTheme.make_avatar_badge(int(m_dict.get("image", 0)), int(m_dict.get("profile_frame", 1)), 66.0, raw_st, true)
	av_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_holder.add_child(av_vis)
	row.add_child(av_holder)
	if not m_uid.is_empty():
		host._clan_member_widgets[m_uid] = {
			"avatar_holder": av_holder,
			"card": card,
			"image": int(m_dict.get("image", 0)),
			"frame": int(m_dict.get("profile_frame", 1)),
		}

	# Tapping self opens profile directly; tapping peers opens interaction sheet
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			if is_self:
				UserProfileDialog.show_user(m_dict, m_role_fa, host)
			else:
				_open_member_interaction_sheet(host, m_dict, my_role)
	)

	return card


static func _open_member_interaction_sheet(host: Control, m_dict: Dictionary, my_role: String) -> void:
	var m_uid := str(m_dict.get("user_id", m_dict.get("_id", "")))
	var m_name := str(m_dict.get("username", "بازیکن"))
	var m_role := str(m_dict.get("role", "member"))
	var m_role_fa := str(m_dict.get("role_title", m_dict.get("role_fa", ROLE_FA_MAP.get(m_role, "عضو"))))
	var my_uid := str(GameManager.get_user_id())

	var m_res := _create_responsive_modal(host, 600.0, 50, 0.80, true)
	var overlay: Control = m_res["overlay"]
	var card: PanelContainer = m_res["card"]
	var vbox: VBoxContainer = m_res["vbox"]

	# Member Header inside modal
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	top_h.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_h)

	var p_col := VBoxContainer.new()
	p_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_col.alignment = BoxContainer.ALIGNMENT_CENTER
	p_col.add_theme_constant_override("separation", 3)
	top_h.add_child(p_col)

	p_col.add_child(CafeSocialTheme.make_title(m_name, 28, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false))
	p_col.add_child(CafeSocialTheme.make_body("سمت: %s • مشارکت: %s • امتیاز: %s" % [
		m_role_fa,
		GameManager.to_fa_num(int(m_dict.get("weekly_contribution", 0))),
		GameManager.to_fa_num(int(m_dict.get("score", 0)))
	], 18, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	top_h.add_child(CafeSocialTheme.make_avatar_badge(int(m_dict.get("image", 0)), int(m_dict.get("profile_frame", 1)), 72.0))

	# Action 1: View Profile
	var b_prof := CafeSocialTheme.make_button("مشاهده پروفایل بازیکن", "gold", Vector2(0, 50), 22)
	b_prof.pressed.connect(func():
		overlay.queue_free()
		UserProfileDialog.show_user(m_dict, m_role_fa, host)
	)
	vbox.add_child(b_prof)

	# Action 2: Direct Message (if not self)
	if m_uid != my_uid:
		var b_dm := CafeSocialTheme.make_button("ارسال پیام خصوصی", "emerald", Vector2(0, 50), 22)
		b_dm.pressed.connect(func():
			overlay.queue_free()
			host.open_direct_message_with(m_uid, m_name)
		)
		vbox.add_child(b_dm)

		# Action 3: Invite to Game (disabled when offline)
		var m_pres: Dictionary = m_dict.get("presence", {}) if typeof(m_dict.get("presence")) == TYPE_DICTIONARY else {}
		var m_is_online := str(m_pres.get("status", m_dict.get("status", "offline"))) != "offline"
		var b_inv := CafeSocialTheme.make_button("دعوت به بازی دوستانه", "bronze", Vector2(0, 50), 22)
		if not m_is_online:
			b_inv.disabled = true
			b_inv.modulate = Color(0.55, 0.52, 0.48, 0.50)
			b_inv.mouse_default_cursor_shape = Control.CURSOR_ARROW
			b_inv.tooltip_text = "بازیکن آفلاین است"
		b_inv.pressed.connect(func():
			if b_inv.disabled:
				return
			overlay.queue_free()
			CafeSocialTheme.show_game_invite_modal(host, m_uid, m_name, func(g_title: String):
				host._show_toast("دعوت‌نامه بازی «%s» برای «%s» ارسال شد!" % [g_title, m_name])
			)
		)
		vbox.add_child(b_inv)

	# Administrative Actions
	var can_manage: bool = (m_uid != my_uid) and (
		my_role == "leader"
		or (my_role == "co_leader" and m_role in ["elder", "member"])
		or (my_role == "elder" and m_role == "member")
	)

	if can_manage:
		var sep := HSeparator.new()
		vbox.add_child(sep)
		vbox.add_child(CafeSocialTheme.make_body("اختیارات مدیریتی شما برای این عضو:", 18, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

		# Promote actions
		if my_role in ["leader", "co_leader"] and m_role == "member":
			var b_p1 := CafeSocialTheme.make_button("ارتقا به ارشد (Elder)", "sapphire", Vector2(0, 48), 21)
			b_p1.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "elder", func(ok: bool, _c: int, _d: Variant):
					overlay.queue_free()
					if ok:
						host._show_toast("«%s» به ارشد ارتقا یافت." % m_name)
					if host.has_method("refresh_my_clan_data"):
						host.refresh_my_clan_data(true)
					else:
						host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p1)
		elif my_role == "leader" and m_role == "elder":
			var b_p2 := CafeSocialTheme.make_button("ارتقا به قائم‌مقام رهبر (Co-Leader)", "sapphire", Vector2(0, 48), 21)
			b_p2.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "co_leader", func(ok: bool, _c: int, _d: Variant):
					overlay.queue_free()
					if ok:
						host._show_toast("«%s» به قائم‌مقام ارتقا یافت." % m_name)
					if host.has_method("refresh_my_clan_data"):
						host.refresh_my_clan_data(true)
					else:
						host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p2)

		# Demote actions
		if my_role == "leader" and m_role in ["co_leader", "elder"]:
			var target_r := "member" if m_role == "elder" else "elder"
			var b_dem := CafeSocialTheme.make_button("تنزل درجه", "bronze", Vector2(0, 48), 21)
			b_dem.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, target_r, func(ok: bool, _c: int, _d: Variant):
					overlay.queue_free()
					if ok:
						host._show_toast("درجه «%s» تنزل یافت." % m_name)
					if host.has_method("refresh_my_clan_data"):
						host.refresh_my_clan_data(true)
					else:
						host._refresh_current_tab()
				)
			)
			vbox.add_child(b_dem)

		# Transfer Leadership
		if my_role == "leader":
			var b_lead := CafeSocialTheme.make_button("انتقال رهبری اتحاد به این عضو", "gold", Vector2(0, 48), 21, CafeSocialTheme.ICO_KING)
			b_lead.pressed.connect(func():
				overlay.queue_free()
				CafeSocialTheme.show_confirm_modal(
					host, "انتقال رهبری اتحاد",
					"آیا مطمئن هستید می‌خواهید رهبری اتحاد را به «%s» واگذار کنید؟ پس از این کار شما قائم‌مقام خواهید شد." % m_name,
					"انتقال رهبری", true,
					func():
						NetworkManager.api.transfer_clan_leadership(m_uid, func(ok: bool, _c: int, _d: Variant):
							if ok:
								host._show_toast("رهبری اتحاد به %s منتقل شد." % m_name)
							if host.has_method("refresh_my_clan_data"):
								host.refresh_my_clan_data(true)
							else:
								host._refresh_current_tab()
						)
				)
			)
			vbox.add_child(b_lead)

		# Kick from clan
		var b_kick := CafeSocialTheme.make_button("اخراج از اتحاد", "crimson", Vector2(0, 48), 21)
		b_kick.pressed.connect(func():
			overlay.queue_free()
			CafeSocialTheme.show_confirm_modal(
				host, "اخراج از اتحاد",
				"آیا مطمئن هستید می‌خواهید «%s» را از اتحاد اخراج کنید؟" % m_name,
				"اخراج شود", true,
				func():
					NetworkManager.api.kick_clan_member(m_uid, func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._show_toast("«%s» از اتحاد اخراج شد." % m_name)
						if host.has_method("refresh_my_clan_data"):
							host.refresh_my_clan_data(true)
						else:
							host._refresh_current_tab()
					)
			)
		)
		vbox.add_child(b_kick)

	var b_close := CafeSocialTheme.make_button("بستن", "muted", Vector2(0, 46), 20)
	b_close.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(b_close)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


# ==============================================================================
# 5. NO CLAN HERO & DISCOVERY & LEADERBOARDS
# ==============================================================================

static func _build_no_clan_overview(host: Control, holder: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Incoming Invitations surfaced FIRST so players can accept immediately!
	var invs: Array = host._my_clan_data.get("invitations", []) if typeof(host._my_clan_data.get("invitations")) == TYPE_ARRAY else []
	if not invs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"دعوت‌نامه‌های اتحاد برای شما", CafeSocialTheme.ICO_STAR,
			"%s دعوت‌نامه در انتظار پاسخ" % GameManager.to_fa_num(invs.size())
		))
		for inv in invs:
			if typeof(inv) == TYPE_DICTIONARY:
				vbox.add_child(_build_incoming_invitation_card(host, inv))

	var hero := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.14, 0.09, 0.05, 0.98)
	h_sb.border_color = Color(0.85, 0.68, 0.30, 0.90)
	h_sb.set_border_width_all(2)
	h_sb.set_corner_radius_all(16)
	if not _is_mobile_platform():
		h_sb.shadow_color = Color(0, 0, 0, 0.40)
		h_sb.shadow_size = 6
	h_sb.content_margin_left = 18.0
	h_sb.content_margin_right = 18.0
	h_sb.content_margin_top = 18.0
	h_sb.content_margin_bottom = 18.0
	hero.add_theme_stylebox_override("panel", h_sb)
	vbox.add_child(hero)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(hv)

	hv.add_child(CafeSocialTheme.make_clan_emblem(1, 88.0))
	hv.add_child(CafeSocialTheme.make_title("به یک اتحاد بپیوندید یا اتحاد خودتان را بسازید!", 29, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	hv.add_child(CafeSocialTheme.make_body(
		"در اتحادهای کافه فکر می‌توانید با دوستان خود چت کنید، چالش‌های هفتگی را فتح کرده و پاداش بگیرید، مسابقات دوستانه بسازید و نام اتحاد خود را در صدر جدول قهرمانان ثبت کنید.",
		20, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true
	))
	hv.add_child(CafeSocialTheme.make_badge_pill(
		"تاسیس اتحاد رایگان است • سهمیه: ۱ اتحاد",
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		17
	))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(btn_row)

	var b_search := CafeSocialTheme.make_button("جستجوی اتحادها", "emerald", Vector2(0, 50), 20)
	b_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_search.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab_in_place(host, "discover")
	)
	btn_row.add_child(b_search)

	var b_create := CafeSocialTheme.make_button("تاسیس اتحاد (رایگان)", "gold", Vector2(0, 50), 20)
	b_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_create.pressed.connect(func():
		AudioManager.sfx_button()
		open_clan_create_modal(host)
	)
	btn_row.add_child(b_create)


static func _build_incoming_invitation_card(host: Control, inv: Dictionary) -> PanelContainer:
	var c_sub: Dictionary = inv.get("clan", {}) if typeof(inv.get("clan")) == TYPE_DICTIONARY else {}
	var cname := str(c_sub.get("name", "اتحاد"))
	var ctag := str(c_sub.get("tag", ""))
	var emb := int(c_sub.get("emblem_id", 1))
	var inv_id := str(inv.get("invite_id", ""))

	var icard := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.95)
	sb.border_color = Color(0.70, 0.52, 0.24, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	icard.add_theme_stylebox_override("panel", sb)

	var irow := HBoxContainer.new()
	irow.alignment = BoxContainer.ALIGNMENT_CENTER
	irow.add_theme_constant_override("separation", 10)
	icard.add_child(irow)

	var b_rej := CafeSocialTheme.make_button("رد", "crimson", Vector2(88, 46), 20)
	b_rej.pressed.connect(func():
		AudioManager.sfx_tap()
		NetworkManager.api.respond_clan_invitation(inv_id, "reject", func(_ok: bool, _c: int, _d: Variant):
			if host.has_method("refresh_my_clan_data"):
				host.refresh_my_clan_data(true)
			else:
				host._refresh_current_tab()
		)
	)
	irow.add_child(b_rej)

	var b_acc := CafeSocialTheme.make_button("پذیرش", "emerald", Vector2(110, 46), 20)
	b_acc.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, _c: int, d: Variant):
			if ok:
				host._show_toast("به اتحاد «%s» خوش آمدید!" % cname)
				host.current_clans_subtab = "my_clan"
				if host.has_method("refresh_my_clan_data"):
					host.refresh_my_clan_data(true)
				else:
					host._refresh_current_tab()
			elif typeof(d) == TYPE_DICTIONARY:
				host._show_toast(str(d.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	irow.add_child(b_acc)

	var ic_col := VBoxContainer.new()
	ic_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic_col.alignment = BoxContainer.ALIGNMENT_CENTER
	irow.add_child(ic_col)
	ic_col.add_child(CafeSocialTheme.make_title("%s  [%s]" % [cname, ctag], 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
	ic_col.add_child(CafeSocialTheme.make_body("سطح %s • %s عضو" % [
		GameManager.to_fa_num(int(c_sub.get("clan_level", 1))),
		GameManager.to_fa_num(int(c_sub.get("member_count", 1)))
	], 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

	irow.add_child(CafeSocialTheme.make_clan_emblem(emb, 60.0))
	return icard


static func _build_clan_discover_view(host: Control, holder: VBoxContainer) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	holder.add_child(mode_row)

	var is_lb: bool = (str(host.current_clans_subtab) == "leaderboard")
	var btn_dir := CafeSocialTheme.make_button("جستجوی اتحادها", "gold" if not is_lb else "muted", Vector2(0, 44), 20)
	btn_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dir.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab_in_place(host, "discover")
	)
	mode_row.add_child(btn_dir)

	var btn_lb := CafeSocialTheme.make_button("برترین اتحادها", "gold" if is_lb else "muted", Vector2(0, 44), 20)
	btn_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_lb.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab_in_place(host, "leaderboard")
	)
	mode_row.add_child(btn_lb)

	if is_lb:
		_build_clan_leaderboard_inner(host, holder)
	else:
		_build_clan_search_inner(host, holder)


static func _build_clan_search_inner(host: Control, holder: VBoxContainer) -> void:
	var s_card := PanelContainer.new()
	var sc_sb := StyleBoxFlat.new()
	sc_sb.bg_color = Color(0.13, 0.09, 0.05, 0.94)
	sc_sb.border_color = Color(0.55, 0.40, 0.22, 0.65)
	sc_sb.set_border_width_all(1)
	sc_sb.set_corner_radius_all(12)
	sc_sb.content_margin_left = 12.0
	sc_sb.content_margin_right = 12.0
	sc_sb.content_margin_top = 8.0
	sc_sb.content_margin_bottom = 8.0
	s_card.add_theme_stylebox_override("panel", sc_sb)
	holder.add_child(s_card)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	s_card.add_child(sv)

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 8)
	sv.add_child(s_row)

	var btn_s := CafeSocialTheme.make_button("جستجو", "gold", Vector2(110, 52), 22)
	s_row.add_child(btn_s)

	var inp := CafeSocialTheme.make_line_edit("جستجوی نام یا تگ اتحاد (مثلاً CAFE#)...", 52.0, 21)
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_row.add_child(inp)

	var filter_jt := [""]
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	sv.add_child(filter_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var res_vbox := VBoxContainer.new()
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(res_vbox)

	var render_search_results := func(arr: Array):
		if not is_instance_valid(res_vbox):
			return
		for ch in res_vbox.get_children():
			ch.queue_free()
		if arr.is_empty():
			res_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"اتحادی با این مشخصات پیدا نشد",
				"عبارت جستجو یا فیلتر را تغییر دهید یا اتحاد جدید خود را بسازید."
			))
			return
		for cl in arr:
			if typeof(cl) == TYPE_DICTIONARY:
				res_vbox.add_child(_build_clan_directory_card(host, cl))

	var do_search := func(force_refresh: bool = false):
		var q_str := inp.text.strip_edges()
		var cache_key := "%s|%s" % [q_str.to_lower(), filter_jt[0]]
		var now_ms := Time.get_ticks_msec()
		if not force_refresh and _search_cache.has(cache_key):
			var entry: Dictionary = _search_cache[cache_key]
			if now_ms - int(entry.get("ts", 0)) < CACHE_TTL_MS:
				render_search_results.call(entry.get("data", []))
				return
		for ch in res_vbox.get_children():
			ch.queue_free()
		res_vbox.add_child(CafeSocialTheme.make_loading_state("در حال جستجوی اتحادها..."))
		NetworkManager.api.search_clans(q_str, filter_jt[0], "clan_score", func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(res_vbox):
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				var arr: Array = data["result"]
				_search_cache[cache_key] = {"ts": Time.get_ticks_msec(), "data": arr}
				render_search_results.call(arr)
			else:
				for ch in res_vbox.get_children():
					ch.queue_free()
		)

	var f_defs := [
		{"id": "", "label": "همه اتحادها"},
		{"id": "open", "label": "عضویت آزاد"},
		{"id": "request", "label": "نیازمند تایید"},
	]
	var f_btns: Dictionary = {}
	var update_f_btns := func():
		for fk in f_btns.keys():
			var fb: Button = f_btns[fk]
			var active: bool = (fk == filter_jt[0])
			fb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if active else "muted", "normal", 10))
			fb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if active else "muted", "hover", 10))

	for fd in f_defs:
		var fid: String = fd["id"]
		var fb := CafeSocialTheme.make_button(fd["label"], "muted", Vector2(0, 40), 19)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func():
			AudioManager.sfx_tap()
			filter_jt[0] = fid
			update_f_btns.call()
			do_search.call()
		)
		f_btns[fid] = fb
		filter_row.add_child(fb)
	update_f_btns.call()

	btn_s.pressed.connect(func():
		AudioManager.sfx_tap()
		do_search.call(true)
	)
	inp.text_submitted.connect(func(_t: String): do_search.call(true))
	do_search.call(false)


static func _build_clan_directory_card(host: Control, cl: Dictionary, rank_num: int = 0) -> PanelContainer:
	var cid := str(cl.get("clan_id", cl.get("_id", "")))
	var cname := str(cl.get("name", "اتحاد"))
	var ctag := str(cl.get("tag", ""))
	var emb_id := int(cl.get("emblem_id", 1))
	var lvl := int(cl.get("clan_level", 1))
	var cscore := int(cl.get("clan_score", 0))
	var mem_cnt := int(cl.get("member_count", 1))
	var max_mem := int(cl.get("max_members", 40))
	var jtype := str(cl.get("join_type", "open"))
	var jtype_fa := "آزاد" if jtype == "open" else "با تایید"

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_item_frame_style(48.0, 14.0))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			CafeSocialTheme.show_clan_details_modal(host, cid, cl)
	)
	card.add_child(root)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	# Left metrics
	var left_col := VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 4)
	row.add_child(left_col)
	left_col.add_child(CafeSocialTheme.make_badge_pill("امتیاز %s" % GameManager.to_fa_num(cscore), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 16))
	left_col.add_child(CafeSocialTheme.make_badge_pill("%s/%s عضو" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 15))

	# Center info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var title_col := CafeSocialTheme.COL_GOLD_BRIGHT if rank_num == 1 else (Color(0.92, 0.94, 0.98) if rank_num == 2 else (Color(0.96, 0.76, 0.54) if rank_num == 3 else CafeSocialTheme.COL_IVORY))
	var title_lbl := CafeSocialTheme.make_title("%s  [%s]" % [cname, ctag], 24, title_col, HORIZONTAL_ALIGNMENT_RIGHT, false)
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title_lbl)
	info.add_child(CafeSocialTheme.make_body("سطح %s  •  عضویت: %s" % [GameManager.to_fa_num(lvl), jtype_fa], 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

	row.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 56.0))

	# Top-3 Medal Icon or Compact Rank Badge on far right
	if rank_num in [1, 2, 3]:
		var medal_tex: Texture2D = CafeSocialTheme.ICO_FIRST if rank_num == 1 else (CafeSocialTheme.ICO_SECOND if rank_num == 2 else CafeSocialTheme.ICO_THIRD)
		var medal_ico := TextureRect.new()
		medal_ico.texture = medal_tex
		medal_ico.custom_minimum_size = Vector2(36, 36)
		medal_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(medal_ico)
	elif rank_num > 3:
		row.add_child(CafeSocialTheme.make_badge_pill("#%s" % GameManager.to_fa_num(rank_num), CafeSocialTheme.COL_MUTED_SAND, Color(0.11, 0.07, 0.04), CafeSocialTheme.COL_BRONZE_BORDER, 16))

	var viewer_has_clan := _check_user_has_clan(host)
	var my_cid := _get_my_clan_id(host)
	var is_my_clan := (not my_cid.is_empty() and cid == my_cid)

	if is_my_clan:
		var mine_row := HBoxContainer.new()
		mine_row.alignment = BoxContainer.ALIGNMENT_CENTER
		mine_row.add_child(CafeSocialTheme.make_badge_pill("★ اتحاد شما", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))
		root.add_child(mine_row)
	elif viewer_has_clan:
		var b_view := CafeSocialTheme.make_button("مشاهده جزئیات اتحاد", "muted", Vector2(0, 38), 18)
		b_view.pressed.connect(func():
			AudioManager.sfx_tap()
			CafeSocialTheme.show_clan_details_modal(host, cid, cl)
		)
		root.add_child(b_view)
	else:
		var b_join := CafeSocialTheme.make_button("عضویت در اتحاد" if jtype == "open" else "ارسال درخواست عضویت", "emerald" if jtype == "open" else "bronze", Vector2(0, 42), 19)
		b_join.pressed.connect(func():
			AudioManager.sfx_button()
			b_join.disabled = true
			NetworkManager.api.join_or_request_clan(cid, "", func(ok_j: bool, _cj: int, dj: Variant):
				if ok_j:
					var res_j: Dictionary = dj.get("result", {}) if typeof(dj) == TYPE_DICTIONARY and typeof(dj.get("result")) == TYPE_DICTIONARY else {}
					var st_j := str(res_j.get("status", ""))
					if st_j == "requested":
						host._show_toast("درخواست عضویت شما برای اتحاد ارسال شد!")
						if is_instance_valid(b_join):
							b_join.text = "✓ درخواست ارسال شد"
					else:
						host._show_toast("با موفقیت به اتحاد پیوستید!")
						host.current_clans_subtab = "my_clan"
						if host.has_method("refresh_my_clan_data"):
							host.refresh_my_clan_data(true)
						else:
							host._refresh_current_tab()
				else:
					if is_instance_valid(b_join):
						b_join.disabled = false
					if typeof(dj) == TYPE_DICTIONARY:
						host._show_toast(str(dj.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		root.add_child(b_join)

	return card


static func update_member_presence(host: Control, target_uid: String, new_st: String) -> void:
	var c_dict: Variant = host._my_clan_data.get("clan", null)
	if typeof(c_dict) != TYPE_DICTIONARY:
		return
	var members_arr: Array = c_dict.get("members", []) if typeof(c_dict.get("members")) == TYPE_ARRAY else []
	var online_cnt := 0
	var my_uid := str(GameManager.get_user_id())
	for m in members_arr:
		if typeof(m) == TYPE_DICTIONARY:
			var m_id := str(m.get("user_id", m.get("_id", "")))
			var pres: Dictionary = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
			var st_s := str(pres.get("status", m.get("status", "offline")))
			if m_id == my_uid and st_s == "offline" and NetworkManager.is_social_connected:
				st_s = "online"
			if st_s in ["online", "in_game", "in_lobby", "in_queue"]:
				online_cnt += 1
	if online_cnt == 0 and not members_arr.is_empty():
		online_cnt = 1

	if is_instance_valid(host._clan_online_pill_lbl):
		host._clan_online_pill_lbl.text = "%s آنلاین" % GameManager.to_fa_num(online_cnt)
	if is_instance_valid(host._clan_members_online_val_lbl):
		host._clan_members_online_val_lbl.text = GameManager.to_fa_num(online_cnt)

	if host._clan_member_widgets.has(target_uid):
		var w: Dictionary = host._clan_member_widgets[target_uid]
		var card_ref: Control = w.get("card", null)
		if is_instance_valid(card_ref):
			card_ref.set_meta("is_online", new_st in ["online", "in_game", "in_lobby", "in_queue"])
		var av_h: Control = w.get("avatar_holder", null)
		if is_instance_valid(av_h):
			for ch in av_h.get_children():
				ch.queue_free()
			var fresh_av := CafeSocialTheme.make_avatar_badge(int(w.get("image", 0)), int(w.get("frame", 1)), 66.0, new_st, true)
			fresh_av.mouse_filter = Control.MOUSE_FILTER_IGNORE
			av_h.add_child(fresh_av)


static func _build_clan_leaderboard_inner(host: Control, holder: VBoxContainer) -> void:
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 6)
	holder.add_child(m_row)

	var modes := [
		{"id": "clans", "label": "کل امتیاز"},
		{"id": "clans_weekly", "label": "برترین‌های هفته"},
		{"id": "clans_monthly", "label": "برترین‌های ماه"},
	]
	for m in modes:
		var mid: String = m["id"]
		var act: bool = (str(host.current_clan_lb_mode) == mid)
		var b := CafeSocialTheme.make_subtab(m["label"], act, 0)
		var h_sb: StyleBoxTexture = CafeSocialTheme.create_header_banner_style(36.0, 10.0).duplicate()
		if act:
			h_sb.modulate_color = Color(1.18, 1.12, 0.92)
		else:
			h_sb.modulate_color = Color(0.72, 0.68, 0.62, 0.85)
		b.add_theme_stylebox_override("normal", h_sb)
		b.add_theme_stylebox_override("hover", h_sb)
		b.add_theme_stylebox_override("pressed", h_sb)
		b.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_clan_lb_mode = mid
			switch_subtab_in_place(host, "leaderboard")
		)
		m_row.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var lb_vbox := VBoxContainer.new()
	lb_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_vbox.add_theme_constant_override("separation", 7)
	scroll.add_child(lb_vbox)

	# Sticky "Your Clan's Rank" Footer Bar (shown when viewer belongs to a clan)
	var sticky_rank_lbl: Label = null
	var has_clan := _check_user_has_clan(host)
	var my_cid := _get_my_clan_id(host)
	if has_clan:
		var cdict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
		var sticky := PanelContainer.new()
		var st_sb := StyleBoxFlat.new()
		st_sb.bg_color = Color(0.12, 0.24, 0.16, 0.96)
		st_sb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
		st_sb.set_border_width_all(1)
		st_sb.set_corner_radius_all(12)
		st_sb.content_margin_left = 12.0
		st_sb.content_margin_right = 12.0
		st_sb.content_margin_top = 6.0
		st_sb.content_margin_bottom = 6.0
		sticky.add_theme_stylebox_override("panel", st_sb)
		holder.add_child(sticky)

		var sh := HBoxContainer.new()
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		sh.add_theme_constant_override("separation", 8)
		sticky.add_child(sh)

		var my_score := int(cdict.get("weekly_score" if host.current_clan_lb_mode == "clans_weekly" else "clan_score", 0))
		sh.add_child(CafeSocialTheme.make_badge_pill("امتیاز: %s" % GameManager.to_fa_num(my_score), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 16))
		sticky_rank_lbl = CafeSocialTheme.make_title("رتبه اتحاد شما (%s): در حال بررسی..." % str(cdict.get("name", "اتحاد من")), 19, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
		sticky_rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sticky_rank_lbl.clip_text = true
		sticky_rank_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sh.add_child(sticky_rank_lbl)
		sh.add_child(CafeSocialTheme.make_clan_emblem(int(cdict.get("emblem_id", 1)), 34.0))

	var render_lb := func(arr: Array):
		if not is_instance_valid(lb_vbox):
			return
		for ch in lb_vbox.get_children():
			ch.queue_free()
		if arr.is_empty():
			lb_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_CUP,
				"هنوز اتحادی در جدول ثبت نشده است",
				"اولین اتحاد خود را بسازید و نامش را در تاریخ کافه فکر ثبت کنید!"
			))
			if is_instance_valid(sticky_rank_lbl):
				sticky_rank_lbl.text = "رتبه اتحاد شما: ثبت نشده"
			return
		var my_found_rank := -1
		for i in range(arr.size()):
			var item = arr[i]
			if typeof(item) == TYPE_DICTIONARY:
				var rnk := int(item.get("rank", i + 1))
				var icid := str(item.get("clan_id", item.get("_id", "")))
				if not my_cid.is_empty() and icid == my_cid:
					my_found_rank = rnk
				lb_vbox.add_child(_build_clan_directory_card(host, item, rnk))
		if is_instance_valid(sticky_rank_lbl):
			var cdict2: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
			var cname2 := str(cdict2.get("name", "اتحاد شما"))
			if my_found_rank > 0:
				sticky_rank_lbl.text = "رتبه اتحاد شما (%s): #%s" % [cname2, GameManager.to_fa_num(my_found_rank)]
			else:
				sticky_rank_lbl.text = "اتحاد شما (%s): خارج از %s برتر" % [cname2, GameManager.to_fa_num(arr.size())]

	var lb_key := str(host.current_clan_lb_mode)
	var now_ms := Time.get_ticks_msec()
	if _lb_cache.has(lb_key):
		var c_entry: Dictionary = _lb_cache[lb_key]
		if now_ms - int(c_entry.get("ts", 0)) < CACHE_TTL_MS:
			render_lb.call(c_entry.get("data", []))
			return

	lb_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت جدول رتبه‌بندی اتحادها..."))
	NetworkManager.api.get_social_leaderboard(lb_key, "", "", func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(lb_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var arr: Array = data["result"]
			_lb_cache[lb_key] = {"ts": Time.get_ticks_msec(), "data": arr}
			render_lb.call(arr)
		else:
			for ch in lb_vbox.get_children():
				ch.queue_free()
	)


# ==============================================================================
# 6. FRIENDLY CHALLENGE ACTION ROW & OVERVIEW CARD
# ==============================================================================

static func _build_challenge_action_row(host: Control, meta: Dictionary, my_uid: String, my_role: String, _in_chat: bool = false) -> HBoxContainer:
	var ch_id: String = str(meta.get("challenge_id", ""))
	var chal_gt: String = str(meta.get("game_type", "Monopoly"))
	var chal_creator: String = str(meta.get("creator_id", ""))
	var chal_status: String = str(meta.get("status", "open"))
	var p_count: int = clampi(int(meta.get("player_count", 2)), 2, 4)
	var parts: Array = meta.get("participants", []) if typeof(meta.get("participants")) == TYPE_ARRAY else []

	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 8)

	if chal_status == "closed":
		act_row.add_child(CafeSocialTheme.make_badge_pill("چالش بسته شد", CafeSocialTheme.COL_CRIMSON_TEXT, Color(0.22, 0.06, 0.06, 0.94), CafeSocialTheme.COL_CRIMSON_BORDER, 17))
		return act_row

	if chal_status == "started":
		act_row.add_child(CafeSocialTheme.make_badge_pill("مسابقه شروع شد", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))
		return act_row

	var already_joined: bool = false
	for pt in parts:
		if typeof(pt) == TYPE_DICTIONARY and str(pt.get("user_id", "")) == my_uid:
			already_joined = true
			break
	if not already_joined and not chal_creator.is_empty() and chal_creator == my_uid:
		already_joined = true

	var cur_players: int = maxi(1, parts.size())
	act_row.add_child(CafeSocialTheme.make_badge_pill(
		"%s از %s نفر" % [GameManager.to_fa_num(cur_players), GameManager.to_fa_num(p_count)],
		CafeSocialTheme.COL_GOLD_BRIGHT,
		Color(0.18, 0.12, 0.04),
		CafeSocialTheme.COL_GOLD_ANTIQUE,
		17
	))

	var can_close: bool = (not ch_id.is_empty()) and (chal_creator == my_uid or my_role in ["leader", "co_leader"])
	if can_close:
		var b_close := CafeSocialTheme.make_button("بستن چالش", "crimson", Vector2(110, 40), 18)
		b_close.pressed.connect(func():
			AudioManager.sfx_tap()
			b_close.disabled = true
			NetworkManager.api.close_clan_friendly_challenge(ch_id, func(ok: bool, _c: int, res_d: Variant):
				if ok:
					host._show_toast("چالش دوستانه بسته شد.")
					host._refresh_current_tab()
				else:
					if is_instance_valid(b_close):
						b_close.disabled = false
					var err := "خطا در بستن چالش"
					if typeof(res_d) == TYPE_DICTIONARY:
						err = str(res_d.get("detail", err))
					host._show_toast(err, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		act_row.add_child(b_close)

	# When required players fill completely, game automatically starts without needing creator to tap start
	if not ch_id.is_empty() and cur_players >= p_count and chal_status == "open":
		act_row.add_child(CafeSocialTheme.make_badge_pill(
			"ظرفیت تکمیل شد • در حال آغاز بازی...",
			CafeSocialTheme.COL_EMERALD_TEXT,
			CafeSocialTheme.COL_EMERALD_BG,
			CafeSocialTheme.COL_EMERALD_BORDER,
			17
		))
		# Auto-trigger start
		NetworkManager.start_clan_challenge_realtime(ch_id)
		# Verification: check if the game really started
		if is_instance_valid(host):
			host.get_tree().create_timer(3.0).timeout.connect(func():
				if not GameManager.is_game_active and is_instance_valid(host):
					NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
						if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
							host._my_clan_data = data["result"]
							if is_instance_valid(host) and host.has_method("_refresh_current_tab"):
								host._refresh_current_tab()
					)
			)
	elif not ch_id.is_empty() and chal_creator == my_uid and cur_players >= 2 and cur_players < p_count:
		var b_start := CafeSocialTheme.make_button("شروع زودهنگام", "emerald", Vector2(120, 40), 19)
		b_start.pressed.connect(func():
			AudioManager.sfx_button()
			b_start.disabled = true
			NetworkManager.start_clan_challenge_realtime(ch_id)
			host._show_toast("در حال شروع مسابقه دوستانه...")
		)
		act_row.add_child(b_start)

	if not already_joined and cur_players < p_count:
		var b_acc := CafeSocialTheme.make_button("پیوستن به چالش", "emerald", Vector2(130, 40), 19)
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			b_acc.disabled = true
			NetworkManager.api.join_clan_friendly_challenge(ch_id, func(ok: bool, _c: int, res_d: Variant):
				if ok:
					var res_obj: Dictionary = {}
					if typeof(res_d) == TYPE_DICTIONARY:
						res_obj = res_d.get("result", res_d) if typeof(res_d.get("result", res_d)) == TYPE_DICTIONARY else {}
					var is_full: bool = bool(res_obj.get("is_full", false)) or (cur_players + 1 >= p_count)
					if is_full:
						NetworkManager.start_clan_challenge_realtime(ch_id)
						host._show_toast("ظرفیت تکمیل شد! بازی در حال آغاز است...")
						if is_instance_valid(host):
							host.get_tree().create_timer(3.0).timeout.connect(func():
								if not GameManager.is_game_active and is_instance_valid(host):
									host._refresh_current_tab()
							)
					else:
						host._show_toast("به چالش پیوستید! منتظر پیوستن سایر بازیکنان...")
						host._refresh_current_tab()
				else:
					if is_instance_valid(b_acc):
						b_acc.disabled = false
					var err := "خطا در پیوستن"
					if typeof(res_d) == TYPE_DICTIONARY:
						err = str(res_d.get("detail", err))
					host._show_toast(err, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		act_row.add_child(b_acc)
	elif already_joined and cur_players < p_count and chal_creator != my_uid:
		act_row.add_child(CafeSocialTheme.make_badge_pill("در انتظار هم‌تیمی‌ها", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))

	return act_row


static func _build_overview_challenge_card(host: Control, chal: Dictionary, my_uid: String, my_role: String) -> PanelContainer:
	var gt: String = str(chal.get("game_type", "Monopoly"))
	var gt_fa: String = str(chal.get("game_title_fa", GameRegistry.get_display_name_fa(gt)))
	var creator_name: String = str(chal.get("creator_name", "هم‌اتحادی"))
	var p_count: int = clampi(int(chal.get("player_count", 2)), 2, 4)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_item_frame_style(46.0, 14.0))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)

	info.add_child(CafeSocialTheme.make_title("چالش دوستانه %s (%s نفره)" % [gt_fa, GameManager.to_fa_num(p_count)], 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	info.add_child(CafeSocialTheme.make_body("ایجاد شده توسط %s" % creator_name, 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var thumb_tex := CafeSocialTheme.get_game_thumb(gt)
	if thumb_tex != null:
		var tr := TextureRect.new()
		tr.texture = thumb_tex
		tr.custom_minimum_size = Vector2(58, 58)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		top.add_child(tr)

	v.add_child(_build_challenge_action_row(host, chal, my_uid, my_role, false))
	return card


# ==============================================================================
# 7. MODALS: CLAN CREATION, SETTINGS & FRIENDLY CHALLENGE
# ==============================================================================

static func open_clan_create_modal(host: Control) -> void:
	var m_res := _create_responsive_modal(host, 620.0, 50, 0.82, true)
	var overlay: Control = m_res["overlay"]
	var card: PanelContainer = m_res["card"]
	var vbox: VBoxContainer = m_res["vbox"]

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(44, 44)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top.add_child(bx)

	var ttl := CafeSocialTheme.make_title("تاسیس اتحاد جدید", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(44, 44)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_badge_pill("ساخت اتحاد رایگان است • سهمیه هر بازیکن: ۱ اتحاد", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))

	# Emblem Picker
	vbox.add_child(CafeSocialTheme.make_body("نشان (لوگو) اتحاد را انتخاب کنید:", 19, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var selected_emblem := [1]
	var emb_center := CenterContainer.new()
	emb_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(emb_center)
	var emb_grid := GridContainer.new()
	emb_grid.columns = 5
	emb_grid.add_theme_constant_override("h_separation", 8)
	emb_grid.add_theme_constant_override("v_separation", 8)
	emb_center.add_child(emb_grid)

	var emb_wraps: Dictionary = {}
	var update_emb_sel := func():
		for eid in emb_wraps.keys():
			var eb: Button = emb_wraps[eid]
			var act: bool = (eid == selected_emblem[0])
			eb.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.16, 0.08) if act else Color(0.10, 0.06, 0.03),
				CafeSocialTheme.COL_GOLD_BRIGHT if act else CafeSocialTheme.COL_BRONZE_BORDER,
				12, 2 if act else 1, 6.0, 6.0
			))
			eb.add_theme_stylebox_override("hover", eb.get_theme_stylebox("normal"))

	for ecfg in CafeSocialTheme.CLAN_EMBLEMS:
		var eid: int = int(ecfg["id"])
		var eb := Button.new()
		eb.custom_minimum_size = Vector2(62, 62)
		eb.focus_mode = Control.FOCUS_NONE
		var em_vis := CafeSocialTheme.make_clan_emblem(eid, 50.0)
		em_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(em_vis)
		eb.add_child(cc)
		eb.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_emblem[0] = eid
			update_emb_sel.call()
		)
		emb_wraps[eid] = eb
		emb_grid.add_child(eb)
	update_emb_sel.call()

	var inp_name := CafeSocialTheme.make_line_edit("نام اتحاد (۳ تا ۲۴ حرف، مثلاً: عقاب‌های کافه فکر)", 56.0, 23)
	vbox.add_child(inp_name)

	var inp_tag := CafeSocialTheme.make_line_edit("تگ یکتای اتحاد (۲ تا ۱۰ حرف یا عدد، مثلاً: CAFE1)", 56.0, 23)
	vbox.add_child(inp_tag)

	var inp_desc := CafeSocialTheme.make_line_edit("معرفی کوتاه و قوانین اتحاد (اختیاری)...", 56.0, 21)
	vbox.add_child(inp_desc)

	var join_type_val := ["open"]
	var jt_row := HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 8)
	vbox.add_child(jt_row)

	var b_jt_req := CafeSocialTheme.make_button("نیازمند تایید", "muted", Vector2(0, 48), 21)
	b_jt_req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_jt_open := CafeSocialTheme.make_button("عضویت آزاد", "emerald", Vector2(0, 48), 21)
	b_jt_open.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var refresh_jt := func():
		b_jt_open.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if join_type_val[0] == "open" else "muted", "normal", 12))
		b_jt_req.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if join_type_val[0] == "request" else "muted", "normal", 12))
	b_jt_open.pressed.connect(func():
		AudioManager.sfx_tap()
		join_type_val[0] = "open"
		refresh_jt.call()
	)
	b_jt_req.pressed.connect(func():
		AudioManager.sfx_tap()
		join_type_val[0] = "request"
		refresh_jt.call()
	)
	jt_row.add_child(b_jt_req)
	jt_row.add_child(b_jt_open)
	jt_row.add_child(CafeSocialTheme.make_body("نوع عضویت:", 21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	var err_panel := PanelContainer.new()
	err_panel.visible = false
	err_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.28, 0.08, 0.08, 0.96), CafeSocialTheme.COL_CRIMSON_TEXT, 12, 1, 10.0, 6.0))
	var err_lbl := CafeSocialTheme.make_body("", 20, CafeSocialTheme.COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	err_panel.add_child(err_lbl)
	vbox.add_child(err_panel)

	var b_submit := CafeSocialTheme.make_button("تاسیس اتحاد (رایگان)", "gold", Vector2(0, 58), 25, CafeSocialTheme.ICO_CHECK, true)
	b_submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_submit.pressed.connect(func():
		AudioManager.sfx_button()
		err_panel.visible = false
		var c_name := inp_name.text.strip_edges()
		var c_tag := inp_tag.text.strip_edges().lstrip("#").strip_edges()
		if c_name.length() < 3:
			err_lbl.text = "نام اتحاد باید حداقل ۳ حرف باشد."
			err_panel.visible = true
			return
		if c_tag.length() < 2 or c_tag.length() > 10:
			err_lbl.text = "تگ اتحاد باید بین ۲ تا ۱۰ حرف یا عدد باشد."
			err_panel.visible = true
			return

		b_submit.disabled = true
		var payload := {
			"name": c_name,
			"tag": c_tag,
			"description": inp_desc.text.strip_edges(),
			"emblem_id": selected_emblem[0],
			"language": "fa",
			"join_type": join_type_val[0],
			"min_score": 0,
			"min_level": 1
		}
		NetworkManager.api.create_clan(payload, func(ok: bool, _c: int, data: Variant):
			if ok:
				if is_instance_valid(overlay):
					overlay.queue_free()
				host._show_toast("اتحاد شما با موفقیت تاسیس شد!")
				host.current_clans_subtab = "my_clan"
				if host.has_method("refresh_my_clan_data"):
					host.refresh_my_clan_data(true)
				else:
					host._refresh_current_tab()
			else:
				if is_instance_valid(b_submit):
					b_submit.disabled = false
				var detail := str(data.get("detail", "خطا در ساخت اتحاد")) if typeof(data) == TYPE_DICTIONARY else "خطا در ساخت اتحاد"
				if is_instance_valid(err_lbl) and is_instance_valid(err_panel):
					err_lbl.text = detail
					err_panel.visible = true
				host._show_toast(detail, CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	vbox.add_child(b_submit)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _open_clan_settings_modal(host: Control, cdict: Dictionary) -> void:
	var m_res := _create_responsive_modal(host, 600.0, 50, 0.80, true)
	var overlay: Control = m_res["overlay"]
	var card: PanelContainer = m_res["card"]
	var vbox: VBoxContainer = m_res["vbox"]

	vbox.add_child(CafeSocialTheme.make_title("تنظیمات اتحاد %s" % str(cdict.get("name", "")), 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))

	var inp_desc := CafeSocialTheme.make_line_edit("توضیحات و قوانین اتحاد...", 52.0, 21)
	inp_desc.text = str(cdict.get("description", ""))
	vbox.add_child(inp_desc)

	var raw_jt := str(cdict.get("join_type", "open"))
	var jt_val := [raw_jt if raw_jt in ["open", "request"] else "open"]
	var jt_row := HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 8)
	vbox.add_child(jt_row)

	var jt_defs := [
		{"id": "request", "label": "با تایید"},
		{"id": "open", "label": "آزاد"},
	]
	var jt_btns: Dictionary = {}
	var ref_jt := func():
		for jk in jt_btns.keys():
			var b: Button = jt_btns[jk]
			b.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if jk == jt_val[0] else "muted", "normal", 11))

	for jd in jt_defs:
		var jid: String = jd["id"]
		var jb := CafeSocialTheme.make_button(jd["label"], "muted", Vector2(0, 46), 21)
		jb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jb.pressed.connect(func():
			AudioManager.sfx_tap()
			jt_val[0] = jid
			ref_jt.call()
		)
		jt_btns[jid] = jb
		jt_row.add_child(jb)
	ref_jt.call()

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var b_cancel := CafeSocialTheme.make_button("بستن", "bronze", Vector2(0, 52), 22)
	b_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_cancel.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(b_cancel)

	var b_save := CafeSocialTheme.make_button("ذخیره تغییرات", "emerald", Vector2(0, 52), 22, CafeSocialTheme.ICO_CHECK)
	b_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_save.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.api.update_clan_settings({
			"description": inp_desc.text.strip_edges(),
			"join_type": jt_val[0]
		}, func(ok: bool, _c: int, _d: Variant):
			overlay.queue_free()
			if ok:
				host._show_toast("تنظیمات اتحاد بروزرسانی شد.")
				if host.has_method("refresh_my_clan_data"):
					host.refresh_my_clan_data(true)
				else:
					host._refresh_current_tab()
		)
	)
	btn_row.add_child(b_save)

	# Danger Zone inside Settings Modal
	var dz_sep := HSeparator.new()
	dz_sep.modulate = Color(0.75, 0.30, 0.25, 0.55)
	vbox.add_child(dz_sep)

	var my_role := str(cdict.get("my_role", "member"))
	var dz_lbl := CafeSocialTheme.make_body("ناحیه خطر", 17, CafeSocialTheme.COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	vbox.add_child(dz_lbl)

	var b_danger := CafeSocialTheme.make_button(
		"انحلال کامل اتحاد" if my_role == "leader" else "خروج از اتحاد",
		"crimson", Vector2(0, 46), 20
	)
	b_danger.pressed.connect(func():
		AudioManager.sfx_tap()
		overlay.queue_free()
		_trigger_leave_or_disband_clan(host, cdict, my_role)
	)
	vbox.add_child(b_danger)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _open_friendly_challenge_modal(host: Control) -> void:
	var m_res := _create_responsive_modal(host, 620.0, 50, 0.82, false)
	var overlay: Control = m_res["overlay"]
	var card: PanelContainer = m_res["card"]
	var vbox: VBoxContainer = m_res["vbox"]

	var top := HBoxContainer.new()
	vbox.add_child(top)

	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(44, 44)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top.add_child(bx)

	var ttl := CafeSocialTheme.make_title("ایجاد چالش دوستانه در اتحاد", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(44, 44)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_body("بازی مورد نظر و تعداد بازیکنان را انتخاب کنید:", 18, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	# Quick Search & Game Category Filter Chips
	var g_search := CafeSocialTheme.make_line_edit("جستجوی نام بازی...", 42.0, 18)
	vbox.add_child(g_search)

	var g_filter_row := HBoxContainer.new()
	g_filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(g_filter_row)

	var g_filter := ["all"] # "all" | "multi" | "duo"
	var g_filter_btns: Dictionary = {}

	var selected_gid: Array = [GameTypes.MONOPOLY]
	var selected_pcount: Array = [2]
	var game_cards: Dictionary = {}
	var pcount_btns: Dictionary = {}

	var g_scroll := ScrollContainer.new()
	g_scroll.custom_minimum_size = Vector2(0, minf(360.0, _calc_modal_max_scroll_h(host, 0.44)))
	g_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(g_scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	g_scroll.add_child(grid)

	var apply_game_filter := func():
		var q := g_search.text.strip_edges().to_lower()
		for gk in game_cards.keys():
			var gbtn: Button = game_cards[gk]
			if not is_instance_valid(gbtn):
				continue
			var show_g := true
			if not q.is_empty() and not (q in str(gbtn.get_meta("title_lower", ""))) and not (q in str(gk).to_lower()):
				show_g = false
			if show_g:
				var is_m := bool(gbtn.get_meta("is_multi", false))
				if g_filter[0] == "multi" and not is_m:
					show_g = false
				elif g_filter[0] == "duo" and is_m:
					show_g = false
			gbtn.visible = show_g

	var update_g_filter_btns := func():
		for fk in g_filter_btns.keys():
			var fb: Button = g_filter_btns[fk]
			var act: bool = (fk == g_filter[0])
			fb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 10))
			fb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 10))

	for gfd in [{"id": "duo", "label": "دونفره"}, {"id": "multi", "label": "چندنفره"}, {"id": "all", "label": "همه بازی‌ها"}]:
		var gfid: String = gfd["id"]
		var fb := CafeSocialTheme.make_button(gfd["label"], "muted", Vector2(0, 36), 17)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func():
			AudioManager.sfx_tap()
			g_filter[0] = gfid
			update_g_filter_btns.call()
			apply_game_filter.call()
		)
		g_filter_btns[gfid] = fb
		g_filter_row.add_child(fb)
	update_g_filter_btns.call()
	g_search.text_changed.connect(func(_t: String): apply_game_filter.call())

	# Player count selector panel
	var pcount_panel := PanelContainer.new()
	pcount_panel.custom_minimum_size = Vector2(0, 72)
	var pc_sb := StyleBoxFlat.new()
	pc_sb.bg_color = Color(0.12, 0.08, 0.04, 0.95)
	pc_sb.border_color = Color(0.50, 0.38, 0.20, 0.65)
	pc_sb.set_border_width_all(1)
	pc_sb.set_corner_radius_all(12)
	pc_sb.content_margin_left = 12.0
	pc_sb.content_margin_right = 12.0
	pcount_panel.add_theme_stylebox_override("panel", pc_sb)
	vbox.add_child(pcount_panel)

	var pcount_row := HBoxContainer.new()
	pcount_row.add_theme_constant_override("separation", 10)
	pcount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pcount_panel.add_child(pcount_row)

	var p_btns_row := HBoxContainer.new()
	p_btns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_btns_row.add_theme_constant_override("separation", 8)
	pcount_row.add_child(p_btns_row)

	var p_lbl := CafeSocialTheme.make_title("تعداد بازیکنان:", 22, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	pcount_row.add_child(p_lbl)

	var refresh_pcount_ui := func():
		var cur_gid: String = str(selected_gid[0])
		var is_multi: bool = GameRegistry.is_multiplayer_game(cur_gid)
		pcount_panel.visible = is_multi
		if not is_multi:
			selected_pcount[0] = 2
		for cnt_key in pcount_btns.keys():
			var pb: Button = pcount_btns[cnt_key]
			var act: bool = (int(cnt_key) == int(selected_pcount[0]))
			pb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 11))
			pb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 11))
		for gk in game_cards.keys():
			var gbtn: Button = game_cards[gk]
			var g_act: bool = (str(gk) == cur_gid)
			gbtn.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.17, 0.08, 0.98) if g_act else Color(0.12, 0.08, 0.04, 0.95),
				CafeSocialTheme.COL_GOLD_BRIGHT if g_act else CafeSocialTheme.COL_BRONZE_BORDER,
				12, 2 if g_act else 1, 8.0, 8.0
			))
			gbtn.add_theme_stylebox_override("hover", gbtn.get_theme_stylebox("normal"))

	var cnt_labels: Dictionary = {2: "۲ نفره", 3: "۳ نفره", 4: "۴ نفره"}
	for cnt in [2, 3, 4]:
		var chosen_cnt: int = int(cnt)
		var pb := CafeSocialTheme.make_button(str(cnt_labels[cnt]), "muted", Vector2(0, 44), 21)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_pcount[0] = chosen_cnt
			refresh_pcount_ui.call()
		)
		pcount_btns[chosen_cnt] = pb
		p_btns_row.add_child(pb)

	for gid in _get_all_challenge_games():
		var g_str: String = str(gid)
		var g_title: String = GameRegistry.get_display_name_fa(g_str)
		var is_multi_g: bool = GameRegistry.is_multiplayer_game(g_str)

		var gbtn := Button.new()
		gbtn.custom_minimum_size = Vector2(0, 96)
		gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gbtn.focus_mode = Control.FOCUS_NONE
		gbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var hm := MarginContainer.new()
		hm.set_anchors_preset(Control.PRESET_FULL_RECT)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hm.add_theme_constant_override("margin_left", 10)
		hm.add_theme_constant_override("margin_right", 10)
		hm.add_theme_constant_override("margin_top", 8)
		hm.add_theme_constant_override("margin_bottom", 8)
		gbtn.add_child(hm)

		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		hm.add_child(h)

		var g_info := VBoxContainer.new()
		g_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_info.alignment = BoxContainer.ALIGNMENT_CENTER
		g_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_info.add_theme_constant_override("separation", 2)
		h.add_child(g_info)

		var g_lbl := CafeSocialTheme.make_title(g_title, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
		g_lbl.clip_text = true
		g_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		g_info.add_child(g_lbl)

		var p_badge := CafeSocialTheme.make_badge_pill(
			"۲ تا ۴ نفره" if is_multi_g else "۲ نفره",
			CafeSocialTheme.COL_GOLD_BRIGHT if is_multi_g else CafeSocialTheme.COL_MUTED_SAND,
			Color(0.14, 0.09, 0.04),
			CafeSocialTheme.COL_GOLD_ANTIQUE if is_multi_g else CafeSocialTheme.COL_BRONZE_BORDER,
			15
		)
		p_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		g_info.add_child(p_badge)

		var th_tex := CafeSocialTheme.get_game_thumb(g_str)
		if th_tex != null:
			var th := TextureRect.new()
			th.texture = th_tex
			th.custom_minimum_size = Vector2(66, 66)
			th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			th.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(th)

		gbtn.set_meta("title_lower", g_title.to_lower())
		gbtn.set_meta("is_multi", is_multi_g)
		gbtn.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_gid[0] = g_str
			refresh_pcount_ui.call()
		)
		game_cards[g_str] = gbtn
		grid.add_child(gbtn)

	refresh_pcount_ui.call()
	apply_game_filter.call()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var bc := CafeSocialTheme.make_button("انصراف", "muted", Vector2(160, 52), 22)
	bc.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(bc)

	var b_submit := CafeSocialTheme.make_button("ارسال چالش دوستانه", "emerald", Vector2(280, 52), 23)
	b_submit.pressed.connect(func():
		AudioManager.sfx_button()
		b_submit.disabled = true
		var gid_s: String = str(selected_gid[0])
		var cnt_i: int = int(selected_pcount[0])
		NetworkManager.api.create_clan_friendly_challenge(gid_s, cnt_i, func(ok: bool, _c: int, _d: Variant):
			if ok:
				overlay.queue_free()
				host._show_toast("چالش دوستانه «%s» در چت اتحاد اعلام شد!" % GameRegistry.get_display_name_fa(gid_s))
				host.current_clans_subtab = "chat"
				host._refresh_current_tab()
			else:
				if is_instance_valid(b_submit):
					b_submit.disabled = false
				host._show_toast("خطا در ایجاد چالش دوستانه", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	btn_row.add_child(b_submit)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _get_all_challenge_games() -> Array[String]:
	# Flagship / popular multiplayer & board games first for fast access
	return [
		GameTypes.MONOPOLY,
		GameTypes.UNO,
		GameTypes.COUP,
		GameTypes.RISK,
		GameTypes.QUIZ,
		GameTypes.QUORIDOR,
		GameTypes.CHESS,
		GameTypes.BACKGAMMON,
		GameTypes.LUDO,
		GameTypes.BATTLESHIP,
		GameTypes.OTHELLO,
		GameTypes.FOURINROW,
		GameTypes.CHECKERS,
		GameTypes.PENTAGO,
		GameTypes.YINSH,
		GameTypes.YATZY,
		GameTypes.DOTBOX,
		GameTypes.MILL,
		GameTypes.FEKRBEKR,
		GameTypes.TIC_TAC_TOE,
		GameTypes.RPC,
		GameTypes.SUDOKU,
		GameTypes.BOXFOUR,
		GameTypes.MNUMBERS,
		GameTypes.MSWEEPER,
	]
