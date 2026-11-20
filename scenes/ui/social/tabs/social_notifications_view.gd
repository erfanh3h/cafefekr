class_name SocialNotificationsView
extends RefCounted

## Cafe Fekr — Notifications Center View
## Icon-led antique notification cards with unread accents, formatted timestamps,
## Mark All Read, contextual one-tap actions, and persistent bottom status text
## whenever any notification is accepted, rejected, or resolved.

const STATUS_CACHE_PATH: String = "user://notif_action_statuses.json"
const MAX_CACHED_STATUSES: int = 200

static var _resolved_statuses: Dictionary = {}
static var _cache_loaded: bool = false


static func _ensure_status_cache_loaded() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	if not FileAccess.file_exists(STATUS_CACHE_PATH):
		return
	var f: FileAccess = FileAccess.open(STATUS_CACHE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_resolved_statuses = parsed as Dictionary


static func _save_status_cache() -> void:
	if _resolved_statuses.size() > MAX_CACHED_STATUSES:
		var keys: Array = _resolved_statuses.keys()
		var trim_cnt: int = _resolved_statuses.size() - MAX_CACHED_STATUSES
		for i in range(trim_cnt):
			_resolved_statuses.erase(keys[i])
	var f: FileAccess = FileAccess.open(STATUS_CACHE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_resolved_statuses))
		f.close()


static func _record_resolved_status(nid: String, action_key: String, text: String, kind: String) -> void:
	_ensure_status_cache_loaded()
	var entry: Dictionary = {"text": text, "kind": kind}
	if not nid.is_empty():
		_resolved_statuses[nid] = entry
	if not action_key.is_empty():
		_resolved_statuses[action_key] = entry
	_save_status_cache()


static func _make_action_key(ntype: String, payload: Dictionary) -> String:
	if payload.has("request_id") and not str(payload.get("request_id", "")).is_empty():
		return "%s:req:%s" % [ntype, str(payload.get("request_id", ""))]
	if payload.has("invite_id") and not str(payload.get("invite_id", "")).is_empty():
		return "%s:inv:%s" % [ntype, str(payload.get("invite_id", ""))]
	return ""


static func _status_text_for_server_value(ntype: String, raw_status: String) -> Dictionary:
	var st: String = raw_status.strip_edges().to_lower()
	if st.is_empty() or st in ["pending", "unread", "new", "open", "active", "none"]:
		return {}
	if st in ["accepted", "accept", "approved", "joined"]:
		if ntype == "friend_request_received":
			return {"text": "✓ درخواست دوستی پذیرفته شد", "kind": "accept"}
		if ntype == "clan_invitation_received":
			return {"text": "✓ دعوت به اتحاد پذیرفته شد", "kind": "accept"}
		if ntype in ["clan_join_request_received", "clan_join_request"]:
			return {"text": "✓ درخواست عضویت در اتحاد پذیرفته شد", "kind": "accept"}
		if ntype == "game_invitation_received":
			return {"text": "✓ دعوت مسابقه پذیرفته شد", "kind": "accept"}
		return {"text": "✓ پذیرفته شد", "kind": "accept"}
	if st in ["rejected", "reject", "declined", "denied", "refused"]:
		if ntype == "friend_request_received":
			return {"text": "✕ درخواست دوستی رد شد", "kind": "reject"}
		if ntype == "clan_invitation_received":
			return {"text": "✕ دعوت به اتحاد رد شد", "kind": "reject"}
		if ntype in ["clan_join_request_received", "clan_join_request"]:
			return {"text": "✕ درخواست عضویت در اتحاد رد شد", "kind": "reject"}
		if ntype == "game_invitation_received":
			return {"text": "✕ دعوت مسابقه رد شد", "kind": "reject"}
		return {"text": "✕ رد شد", "kind": "reject"}
	if st in ["cancelled", "canceled"]:
		return {"text": "✕ این درخواست لغو شده است", "kind": "neutral"}
	if st in ["expired"]:
		return {"text": "⏱ مهلت این دعوت به پایان رسیده است", "kind": "neutral"}
	if st in ["handled", "completed", "resolved", "done"]:
		return {"text": "✓ بررسی و ثبت شد", "kind": "neutral"}
	return {}


static func _get_resolved_status(n: Dictionary, payload: Dictionary, nid: String, ntype: String) -> Dictionary:
	_ensure_status_cache_loaded()
	if not nid.is_empty() and _resolved_statuses.has(nid) and typeof(_resolved_statuses[nid]) == TYPE_DICTIONARY:
		return _resolved_statuses[nid] as Dictionary
	var akey: String = _make_action_key(ntype, payload)
	if not akey.is_empty() and _resolved_statuses.has(akey) and typeof(_resolved_statuses[akey]) == TYPE_DICTIONARY:
		return _resolved_statuses[akey] as Dictionary

	for field in ["action_status", "response_status", "decision", "status", "state", "result"]:
		if n.has(field) and typeof(n[field]) == TYPE_STRING:
			var mapped: Dictionary = _status_text_for_server_value(ntype, str(n[field]))
			if not mapped.is_empty():
				return mapped
		if payload.has(field) and typeof(payload[field]) == TYPE_STRING:
			var mapped_p: Dictionary = _status_text_for_server_value(ntype, str(payload[field]))
			if not mapped_p.is_empty():
				return mapped_p
	return {}


static func _has_ancestor_scroll(node: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


static func _notify_host_toast(host: Control, msg: String) -> void:
	if not is_instance_valid(host):
		return
	_show_bottom_center_toast(host, msg)


static func _show_bottom_center_toast(host: Control, msg: String) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	var root: Viewport = host.get_viewport()
	if not root:
		return

	var old: Node = root.find_child("SocialBottomCenterToast", false, false)
	if is_instance_valid(old):
		old.queue_free()

	var toast_layer: CanvasLayer = CanvasLayer.new()
	toast_layer.name = "SocialBottomCenterToast"
	toast_layer.layer = 120
	root.add_child(toast_layer)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 32.0
	panel.offset_right = -32.0
	panel.offset_bottom = -96.0
	panel.offset_top = -156.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.05, 0.96)
	sb.border_color = Color(0.92, 0.74, 0.30, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	toast_layer.add_child(panel)

	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	var tw: Tween = toast_layer.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.20)
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func():
		if is_instance_valid(toast_layer):
			toast_layer.queue_free()
	)


static func _refresh_host(host: Control) -> void:
	if not is_instance_valid(host):
		return
	if host.has_method("_refresh_current_tab"):
		host._refresh_current_tab()
	elif host.has_method("refresh_all"):
		host.refresh_all()


static func _set_unread_subtitle(lbl: Label, unread_cnt: int) -> void:
	if not is_instance_valid(lbl):
		return
	lbl.text = "بدون اعلان خوانده‌نشده" if unread_cnt <= 0 else "%s اعلان جدید" % GameManager.to_fa_num(unread_cnt)
	lbl.add_theme_color_override(
		"font_color",
		CafeSocialTheme.COL_EMERALD_TEXT if unread_cnt > 0 else CafeSocialTheme.COL_MUTED_SAND
	)


static func render(host: Control, body_vbox: VBoxContainer) -> void:
	_ensure_status_cache_loaded()

	# Top header bar with Mark All Read
	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_margin.add_theme_constant_override("margin_left", 10)
	header_margin.add_theme_constant_override("margin_right", 10)
	body_vbox.add_child(header_margin)

	var header_bar: PanelContainer = PanelContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 118)
	header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 40.0, 18.0))
	header_margin.add_child(header_bar)

	var hrow: HBoxContainer = HBoxContainer.new()
	hrow.alignment = BoxContainer.ALIGNMENT_CENTER
	hrow.add_theme_constant_override("separation", 14)
	header_bar.add_child(hrow)

	var btn_read_all: TextureButton = TextureButton.new()
	btn_read_all.custom_minimum_size = Vector2(62, 62)
	btn_read_all.ignore_texture_size = true
	btn_read_all.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_read_all.texture_normal = preload("res://assets/images/frames/check.png")
	btn_read_all.focus_mode = Control.FOCUS_NONE
	btn_read_all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_read_all.tooltip_text = "علامت‌گذاری همه به عنوان خوانده‌شده"
	ActionVFXManager.apply_button_juice(btn_read_all, "tap_button")

	var title_col: VBoxContainer = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)

	title_col.add_child(CafeSocialTheme.make_title("مرکز اعلان‌های باشگاه", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var lbl_unread_sub: Label = CafeSocialTheme.make_body("", 20, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT)
	_set_unread_subtitle(lbl_unread_sub, NetworkManager.unread_notifications_count)
	title_col.add_child(lbl_unread_sub)

	btn_read_all.disabled = (NetworkManager.unread_notifications_count <= 0)
	btn_read_all.pressed.connect(func():
		AudioManager.sfx_button()
		btn_read_all.disabled = true
		NetworkManager.api.mark_all_notifications_read(func(ok: bool, _c: int, _d: Variant):
			if ok:
				NetworkManager.unread_notifications_count = 0
				NetworkManager.notify_social_badges_changed()
				_set_unread_subtitle(lbl_unread_sub, 0)
				if is_instance_valid(host) and host.has_method("_update_main_tab_buttons"):
					host._update_main_tab_buttons()
				_notify_host_toast(host, "تمام اعلان‌ها به عنوان خوانده‌شده علامت‌گذاری شدند.")
				_refresh_host(host)
			else:
				if is_instance_valid(btn_read_all):
					btn_read_all.disabled = false
		)
	)
	hrow.add_child(btn_read_all)
	hrow.add_child(title_col)

	var n_vbox: VBoxContainer = VBoxContainer.new()
	n_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_vbox.add_theme_constant_override("separation", 12)

	if _has_ancestor_scroll(body_vbox):
		var list_margin: MarginContainer = MarginContainer.new()
		list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_margin.add_theme_constant_override("margin_left", 6)
		list_margin.add_theme_constant_override("margin_right", 6)
		list_margin.add_child(n_vbox)
		body_vbox.add_child(list_margin)
	else:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 260)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(n_vbox)
		body_vbox.add_child(scroll)

	n_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اعلان‌ها..."))

	NetworkManager.api.get_notifications_list(false, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(n_vbox):
			return
		for c in n_vbox.get_children():
			c.queue_free()

		if not ok or typeof(data) != TYPE_DICTIONARY:
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت اعلان‌ها",
				"اتصال به سرور برقرار نشد. لطفاً دوباره تلاش کنید.",
				"تلاش مجدد", "gold", func(): _refresh_host(host)
			))
			return

		var items: Array = []
		var unread_cnt: int = NetworkManager.unread_notifications_count
		var raw_result: Variant = data.get("result", null)

		if typeof(raw_result) == TYPE_DICTIONARY:
			var res: Dictionary = raw_result as Dictionary
			if res.has("items") and typeof(res["items"]) == TYPE_ARRAY:
				items = res["items"]
			elif res.has("notifications") and typeof(res["notifications"]) == TYPE_ARRAY:
				items = res["notifications"]
			if res.has("unread_count"):
				unread_cnt = int(res.get("unread_count", 0))
			else:
				unread_cnt = _count_unread_items(items)
			if res.has("unread_dm_count"):
				NetworkManager.unread_dms_count = int(res.get("unread_dm_count", NetworkManager.unread_dms_count))
		elif typeof(raw_result) == TYPE_ARRAY:
			items = raw_result
			unread_cnt = _count_unread_items(items)
		elif data.has("items") and typeof(data["items"]) == TYPE_ARRAY:
			items = data["items"]
			unread_cnt = int(data.get("unread_count", _count_unread_items(items)))
		elif data.has("notifications") and typeof(data["notifications"]) == TYPE_ARRAY:
			items = data["notifications"]
			unread_cnt = int(data.get("unread_count", _count_unread_items(items)))
		else:
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت اعلان‌ها",
				"پاسخ سرور نامعتبر بود. لطفاً دوباره تلاش کنید.",
				"تلاش مجدد", "gold", func(): _refresh_host(host)
			))
			return

		NetworkManager.unread_notifications_count = unread_cnt
		NetworkManager.notify_social_badges_changed()
		_set_unread_subtitle(lbl_unread_sub, unread_cnt)
		if is_instance_valid(btn_read_all):
			btn_read_all.disabled = (unread_cnt <= 0 and items.is_empty())
		if is_instance_valid(host) and host.has_method("_update_main_tab_buttons"):
			host._update_main_tab_buttons()

		if items.is_empty():
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_STAR,
				"اعلانی وجود ندارد",
				"دعوت‌نامه‌های بازی، درخواست‌های دوستی و رویدادهای اتحاد شما اینجا نمایش داده می‌شوند."
			))
		else:
			var rendered_any: bool = false
			for n in items:
				if typeof(n) == TYPE_DICTIONARY:
					var nd: Dictionary = n as Dictionary
					var ex_st: Dictionary = _get_resolved_status(nd, nd.get("payload", {}), str(nd.get("notification_id", nd.get("_id", ""))), str(nd.get("type", "")))
					if not ex_st.is_empty() and str(ex_st.get("kind", "")) in ["accept", "reject"]:
						var d_nid: String = str(nd.get("notification_id", nd.get("_id", "")))
						if not d_nid.is_empty():
							NetworkManager.api.delete_notification(d_nid)
						continue
					n_vbox.add_child(_build_notification_card(host, nd, lbl_unread_sub, btn_read_all))
					rendered_any = true

			if not rendered_any:
				n_vbox.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.ICO_STAR,
					"اعلانی وجود ندارد",
					"دعوت‌نامه‌های بازی، درخواست‌های دوستی و رویدادهای اتحاد شما اینجا نمایش داده می‌شوند."
				))


		var bottom_spacer: Control = Control.new()
		bottom_spacer.custom_minimum_size = Vector2(0, 44)
		bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n_vbox.add_child(bottom_spacer)
	)


static func _count_unread_items(items: Array) -> int:
	var count: int = 0
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and not bool(item.get("is_read", false)):
			count += 1
	return count


static func _get_notif_icon(ntype: String) -> Texture2D:
	if ntype.begins_with("friend"):
		return CafeSocialTheme.ICO_LOBBY
	if ntype.begins_with("clan"):
		return CafeSocialTheme.ICO_RANK
	if ntype.begins_with("direct_message"):
		return CafeSocialTheme.BADGE_CHAT
	if ntype.begins_with("game_"):
		return CafeSocialTheme.ICO_CUP
	return CafeSocialTheme.ICO_SPARKLE


static func _make_card_style(is_read: bool) -> StyleBoxFlat:
	var card_style: StyleBoxFlat = CafeSocialTheme.create_card_style(
		Color(0.14, 0.09, 0.05, 0.94) if is_read else Color(0.18, 0.12, 0.06, 0.97),
		CafeSocialTheme.COL_BRONZE_BORDER if is_read else Color("#F5C542"),
		16, 1 if is_read else 2, 16.0, 14.0
	)
	if not is_read:
		card_style.border_width_right = 5
	return card_style


static func _build_status_banner(text: String, kind: String) -> PanelContainer:
	var banner: PanelContainer = PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.custom_minimum_size = Vector2(0, 44)

	var bg_col: Color = Color(0.15, 0.10, 0.06, 0.92)
	var bdr_col: Color = CafeSocialTheme.COL_BRONZE_BORDER
	var txt_col: Color = CafeSocialTheme.COL_GOLD_BRIGHT
	if kind == "accept":
		bg_col = Color(0.10, 0.25, 0.15, 0.94)
		bdr_col = Color(0.32, 0.80, 0.48, 0.92)
		txt_col = Color(0.55, 0.98, 0.68, 1.0)
	elif kind == "reject":
		bg_col = Color(0.28, 0.09, 0.10, 0.94)
		bdr_col = Color(0.86, 0.34, 0.34, 0.92)
		txt_col = Color(1.0, 0.60, 0.58, 1.0)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = bdr_col
	sb.set_border_width_all(1)
	sb.border_width_right = 4
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	banner.add_theme_stylebox_override("panel", sb)

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 21)
	lbl.add_theme_color_override("font_color", txt_col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	banner.add_child(lbl)
	return banner


static func _set_buttons_disabled(act_row: HBoxContainer, disabled: bool) -> void:
	if not is_instance_valid(act_row):
		return
	for ch in act_row.get_children():
		if ch is BaseButton:
			(ch as BaseButton).disabled = disabled


static func _show_notification_result(act_row: HBoxContainer, text: String, kind: String) -> void:
	if not is_instance_valid(act_row):
		return
	for ch in act_row.get_children():
		ch.queue_free()
	act_row.add_child(_build_status_banner(text, kind))


static func _mark_card_read_ui(
	card: PanelContainer,
	was_unread_ref: Array,
	lbl_unread_sub: Label,
	btn_read_all: TextureButton,
	host: Control
) -> void:
	if is_instance_valid(card):
		card.add_theme_stylebox_override("panel", _make_card_style(true))
	if was_unread_ref.size() > 0 and bool(was_unread_ref[0]):
		was_unread_ref[0] = false
		NetworkManager.unread_notifications_count = max(0, NetworkManager.unread_notifications_count - 1)
		NetworkManager.notify_social_badges_changed()
		_set_unread_subtitle(lbl_unread_sub, NetworkManager.unread_notifications_count)
		if is_instance_valid(btn_read_all) and NetworkManager.unread_notifications_count <= 0:
			btn_read_all.disabled = true
		if is_instance_valid(host) and host.has_method("_update_main_tab_buttons"):
			host._update_main_tab_buttons()


static func _commit_notification_status(
	card: PanelContainer,
	act_row: HBoxContainer,
	nid: String,
	action_key: String,
	status_text: String,
	kind: String,
	was_unread_ref: Array,
	lbl_unread_sub: Label,
	btn_read_all: TextureButton,
	host: Control
) -> void:
	_record_resolved_status(nid, action_key, status_text, kind)
	_show_notification_result(act_row, status_text, kind)
	_mark_card_read_ui(card, was_unread_ref, lbl_unread_sub, btn_read_all, host)
	if not nid.is_empty():
		NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)


static func _extract_api_error(data: Variant) -> String:
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data as Dictionary
		var detail: String = str(d.get("detail", d.get("message", d.get("error", "")))).strip_edges()
		if not detail.is_empty():
			return detail
	return ""


static func _delete_and_remove_card(
	card: PanelContainer,
	nid: String,
	was_unread_ref: Array,
	lbl_unread_sub: Label,
	btn_read_all: TextureButton,
	host: Control
) -> void:
	if not nid.is_empty():
		NetworkManager.api.delete_notification(nid, func(_o, _c2, _d2): pass)
	if was_unread_ref.size() > 0 and bool(was_unread_ref[0]):
		was_unread_ref[0] = false
		NetworkManager.unread_notifications_count = max(0, NetworkManager.unread_notifications_count - 1)
		NetworkManager.notify_social_badges_changed()
		_set_unread_subtitle(lbl_unread_sub, NetworkManager.unread_notifications_count)
		if is_instance_valid(btn_read_all) and NetworkManager.unread_notifications_count <= 0:
			btn_read_all.disabled = true
		if is_instance_valid(host) and host.has_method("_update_main_tab_buttons"):
			host._update_main_tab_buttons()
	if is_instance_valid(card):
		var p_node: Node = card.get_parent()
		card.queue_free()
		if is_instance_valid(p_node) and is_instance_valid(p_node.get_tree()):
			p_node.get_tree().process_frame.connect(func():
				if not is_instance_valid(p_node):
					return
				var card_count: int = 0
				for ch in p_node.get_children():
					if ch is PanelContainer and not ch.is_queued_for_deletion():
						card_count += 1
				if card_count == 0:
					for ch in p_node.get_children():
						ch.queue_free()
					p_node.add_child(CafeSocialTheme.make_empty_state(
						CafeSocialTheme.ICO_STAR,
						"اعلانی وجود ندارد",
						"دعوت‌نامه‌های بازی، درخواست‌های دوستی و رویدادهای اتحاد شما اینجا نمایش داده می‌شوند."
					))
			, Object.CONNECT_ONE_SHOT)


static func _build_notification_card(
	host: Control,
	n: Dictionary,
	lbl_unread_sub: Label = null,
	btn_read_all: TextureButton = null
) -> PanelContainer:
	var nid: String = str(n.get("notification_id", n.get("_id", n.get("id", ""))))
	var ntype: String = str(n.get("type", ""))
	var is_read: bool = bool(n.get("is_read", false))
	var payload: Dictionary = n.get("payload", {}) if typeof(n.get("payload")) == TYPE_DICTIONARY else {}
	var actor_id: String = str(n.get("actor_id", ""))
	var actor_name: String = str(n.get("actor_name", "بازیکن"))
	var time_str: String = CafeSocialTheme.format_shamsi_datetime_fa(str(n.get("created_at", "")))
	var action_key: String = _make_action_key(ntype, payload)
	var existing_status: Dictionary = _get_resolved_status(n, payload, nid, ntype)
	var was_unread_ref: Array = [not is_read]

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(is_read or not existing_status.is_empty()))

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	if not time_str.is_empty():
		var pill_time: PanelContainer = CafeSocialTheme.make_badge_pill(
			time_str, CafeSocialTheme.COL_MUTED_SAND, Color(0.08, 0.05, 0.03, 0.9), CafeSocialTheme.COL_BRONZE_BORDER, 17
		)
		pill_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_row.add_child(pill_time)

	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	top_row.add_child(text_col)

	text_col.add_child(CafeSocialTheme.make_title(
		str(n.get("title", "اعلان")),
		25,
		CafeSocialTheme.COL_WARM_CREAM if is_read else CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	))
	text_col.add_child(CafeSocialTheme.make_body(
		str(n.get("body", "")),
		20,
		CafeSocialTheme.COL_MUTED_SAND if is_read else CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	))

	# Top right icon per type removed per user request

	# Bottom action / status row
	var act_row: HBoxContainer = HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	var has_acts: bool = false

	# If this notification already has a recorded or server-resolved status, show it directly at bottom
	if not existing_status.is_empty():
		has_acts = true
		act_row.add_child(_build_status_banner(
			str(existing_status.get("text", "✓ بررسی شد")),
			str(existing_status.get("kind", "neutral"))
		))

	elif ntype == "friend_request_received" and payload.has("request_id"):
		has_acts = true
		var rid: String = str(payload.get("request_id", ""))
		var b_acc: Button = CafeSocialTheme.make_button("پذیرش دوستی", "emerald", Vector2(0, 46), 22)
		b_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			_set_buttons_disabled(act_row, true)
			NetworkManager.api.respond_friend_request(rid, "accept", func(ok: bool, code: int, d: Variant):
				if ok:
					NetworkManager.incoming_friend_requests_count = max(0, NetworkManager.incoming_friend_requests_count - 1)
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "درخواست دوستی پذیرفته شد!")
				elif code >= 400 and code < 500:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "این درخواست دوستی قبلاً بررسی یا لغو شده است")
				else:
					_set_buttons_disabled(act_row, false)
					_notify_host_toast(host, "خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.")
			)
		)
		act_row.add_child(b_acc)

		var b_rej: Button = CafeSocialTheme.make_button("رد", "crimson", Vector2(110, 46), 22)
		b_rej.pressed.connect(func():
			AudioManager.sfx_tap()
			_set_buttons_disabled(act_row, true)
			NetworkManager.api.respond_friend_request(rid, "reject", func(ok: bool, code: int, d: Variant):
				if ok:
					NetworkManager.incoming_friend_requests_count = max(0, NetworkManager.incoming_friend_requests_count - 1)
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "درخواست دوستی رد شد.")
				elif code >= 400 and code < 500:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "این درخواست دوستی قبلاً بررسی یا لغو شده است")
				else:
					_set_buttons_disabled(act_row, false)
					_notify_host_toast(host, "خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.")
			)
		)
		act_row.add_child(b_rej)

	elif ntype == "clan_invitation_received" and payload.has("invite_id"):
		has_acts = true
		var inv_id: String = str(payload.get("invite_id", ""))
		var b_join: Button = CafeSocialTheme.make_button("پیوستن به اتحاد", "emerald", Vector2(0, 46), 22)
		b_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_join.pressed.connect(func():
			AudioManager.sfx_button()
			_set_buttons_disabled(act_row, true)
			NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, code: int, d: Variant):
				if ok:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "به اتحاد خوش آمدید!")
				elif code >= 400 and code < 500:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "این دعوت‌نامه قبلاً بررسی یا منقضی شده است")
				else:
					_set_buttons_disabled(act_row, false)
					_notify_host_toast(host, "خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.")
			)
		)
		act_row.add_child(b_join)

		var b_crej: Button = CafeSocialTheme.make_button("رد دعوت", "crimson", Vector2(110, 46), 22)
		b_crej.pressed.connect(func():
			AudioManager.sfx_tap()
			_set_buttons_disabled(act_row, true)
			NetworkManager.api.respond_clan_invitation(inv_id, "reject", func(ok: bool, code: int, d: Variant):
				if ok:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "دعوت به اتحاد رد شد.")
				elif code >= 400 and code < 500:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "این دعوت‌نامه قبلاً بررسی یا منقضی شده است")
				else:
					_set_buttons_disabled(act_row, false)
					_notify_host_toast(host, "خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.")
			)
		)
		act_row.add_child(b_crej)

	elif ntype in ["clan_join_request_received", "clan_join_request"] and payload.has("request_id"):
		has_acts = true
		var c_req_id: String = str(payload.get("request_id", ""))
		var b_cacc: Button = CafeSocialTheme.make_button("پذیرش عضویت", "emerald", Vector2(0, 46), 22)
		b_cacc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_cacc.pressed.connect(func():
			AudioManager.sfx_button()
			_set_buttons_disabled(act_row, true)
			NetworkManager.api.respond_clan_join_request(c_req_id, "accept", func(ok: bool, code: int, d: Variant):
				if ok:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "درخواست عضویت در اتحاد پذیرفته شد!")
				elif code >= 400 and code < 500:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "این درخواست عضویت قبلاً بررسی شده است")
				else:
					_set_buttons_disabled(act_row, false)
					_notify_host_toast(host, "خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.")
			)
		)
		act_row.add_child(b_cacc)

		var b_cjrej: Button = CafeSocialTheme.make_button("رد درخواست", "crimson", Vector2(120, 46), 22)
		b_cjrej.pressed.connect(func():
			AudioManager.sfx_tap()
			_set_buttons_disabled(act_row, true)
			NetworkManager.api.respond_clan_join_request(c_req_id, "reject", func(ok: bool, code: int, d: Variant):
				if ok:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "درخواست عضویت در اتحاد رد شد.")
				elif code >= 400 and code < 500:
					_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
					_notify_host_toast(host, "این درخواست عضویت قبلاً بررسی شده است")
				else:
					_set_buttons_disabled(act_row, false)
					_notify_host_toast(host, "خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.")
			)
		)
		act_row.add_child(b_cjrej)

	elif ntype == "direct_message_received" and not actor_id.is_empty():
		has_acts = true
		var b_open_dm: Button = CafeSocialTheme.make_button("مشاهده گفتگو", "sapphire", Vector2(0, 46), 22)
		b_open_dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_open_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			_commit_notification_status(
				card, act_row, nid, action_key,
				"✓ گفتگو مشاهده شد", "neutral",
				was_unread_ref, lbl_unread_sub, btn_read_all, host
			)
			if is_instance_valid(host) and host.has_method("open_direct_message_with"):
				host.open_direct_message_with(actor_id, actor_name)
			else:
				_notify_host_toast(host, "برای پاسخ، بخش دوستان و گفتگوها را باز کنید.")
		)
		act_row.add_child(b_open_dm)

	elif ntype == "game_invitation_received" and payload.has("invite_id"):
		has_acts = true
		var g_inv_id: String = str(payload.get("invite_id", ""))
		var b_gacc: Button = CafeSocialTheme.make_button("قبول دعوت بازی", "emerald", Vector2(0, 46), 22)
		b_gacc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_gacc.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.respond_game_invite_realtime(g_inv_id, "accept")
			_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
			_notify_host_toast(host, "دعوت مسابقه پذیرفته شد!")
		)
		act_row.add_child(b_gacc)

		var b_grej: Button = CafeSocialTheme.make_button("رد دعوت", "crimson", Vector2(140, 46), 22)
		b_grej.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.respond_game_invite_realtime(g_inv_id, "reject")
			_delete_and_remove_card(card, nid, was_unread_ref, lbl_unread_sub, btn_read_all, host)
			_notify_host_toast(host, "دعوت مسابقه رد شد.")
		)
		act_row.add_child(b_grej)

	elif not is_read:

		has_acts = true
		var b_mark: Button = CafeSocialTheme.make_button("خوانده شد", "bronze", Vector2(140, 46), 22)
		b_mark.pressed.connect(func():
			AudioManager.sfx_tap()
			_commit_notification_status(
				card, act_row, nid, action_key,
				"✓ به عنوان خوانده‌شده ثبت شد", "neutral",
				was_unread_ref, lbl_unread_sub, btn_read_all, host
			)
		)
		act_row.add_child(b_mark)

	if has_acts:
		vbox.add_child(act_row)

	return card
