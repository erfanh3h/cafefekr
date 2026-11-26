extends Node

## Cafe Fekr — Global Responsive UI & Typography Manager (Autoload)
## Keeps font sizes, BiDi/RTL direction, safe-area insets, and dialog dimensions
## responsive across every screen aspect ratio, window resize, and mobile notch.

signal layout_changed(metrics: Dictionary)

const SETTINGS_PATH: String = "user://settings.cfg"

var _tracked_text_controls: Array[WeakRef] = []
var _tracked_dialogs: Array[Dictionary] = []
var _tracked_ids: Dictionary = {} # instance_id -> true
var _tracked_dialog_ids: Dictionary = {} # instance_id -> true
var _user_text_scale: float = 1.0
var _last_vp_size: Vector2 = Vector2.ZERO
var _refresh_queued: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_user_text_scale()
	_sync_viewport_metrics()

	var tree := get_tree()
	if tree != null:
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		if tree.root != null and not tree.root.size_changed.is_connected(_on_viewport_size_changed):
			tree.root.size_changed.connect(_on_viewport_size_changed)
		call_deferred("_scan_existing_tree")


func _load_user_text_scale() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key("ui", "text_scale"):
		_user_text_scale = clampf(float(cfg.get_value("ui", "text_scale", 1.0)), 0.90, 1.20)


func set_user_text_scale(scale_val: float) -> void:
	_user_text_scale = clampf(scale_val, 0.90, 1.20)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "text_scale", _user_text_scale)
	cfg.save(SETTINGS_PATH)
	_sync_viewport_metrics(true)


func get_user_text_scale() -> float:
	return _user_text_scale


func get_viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var sz := vp.get_visible_rect().size
		if sz.x > 1.0 and sz.y > 1.0:
			return sz
	return UITypography.get_viewport_size()


func get_safe_insets() -> Dictionary:
	return UITypography.get_safe_insets(get_viewport())


func get_font_scale() -> float:
	return UITypography.get_font_scale()


func get_ui_scale() -> float:
	return UITypography.get_ui_scale()


func font_size(role: int, custom_min: int = -1, custom_max: int = -1) -> int:
	return UITypography.get_role_font_size(role, custom_min, custom_max)


func scale_px(base_px: int, min_px: int = UITypography.STANDARD_MIN_FONT_PX, max_px: int = 72) -> int:
	return UITypography.scale_px(base_px, min_px, max_px)


func apply_text(ctrl: Control, role: int, options: Dictionary = {}) -> void:
	if not is_instance_valid(ctrl):
		return
	UITypography.apply_text(ctrl, role, options)
	_track_text_control(ctrl)


func apply_scaled_font(ctrl: Control, base_px: int, min_px: int = UITypography.STANDARD_MIN_FONT_PX, max_px: int = 72) -> void:
	if not is_instance_valid(ctrl):
		return
	var norm: int = UITypography.normalize_raw_px(base_px)
	ctrl.set_meta(&"_resp_base_px", norm)
	ctrl.set_meta(&"_resp_min_px", maxi(UITypography.ABSOLUTE_MIN_FONT_PX, min_px))
	ctrl.set_meta(&"_resp_max_px", maxi(min_px, max_px))
	ctrl.set_meta(&"_resp_managed", true)
	var scaled: int = UITypography.scale_px(norm, min_px, max_px)
	if ctrl is RichTextLabel:
		ctrl.add_theme_font_size_override("normal_font_size", scaled)
		ctrl.add_theme_font_size_override("bold_font_size", scaled + 2)
		ctrl.add_theme_font_size_override("italics_font_size", scaled)
	else:
		ctrl.add_theme_font_size_override("font_size", scaled)
	UITypography.configure_bidi(ctrl, false, false)
	_track_text_control(ctrl)


func register_dialog(dialog: Control, pref_w: float = 660.0, pref_h: float = 1160.0, min_w: float = 300.0, min_h: float = 220.0, center_anchored: bool = true) -> void:
	if not is_instance_valid(dialog):
		return
	var iid: int = dialog.get_instance_id()
	if not _tracked_dialog_ids.has(iid):
		_tracked_dialog_ids[iid] = true
		_tracked_dialogs.append({
			"ref": weakref(dialog),
			"pref_w": pref_w,
			"pref_h": pref_h,
			"min_w": min_w,
			"min_h": min_h,
			"center_anchored": center_anchored,
		})
	_fit_dialog_entry(dialog, pref_w, pref_h, min_w, min_h, center_anchored)


func fit_dialog(dialog: Control, pref_w: float = 660.0, pref_h: float = 1160.0, min_w: float = 300.0, min_h: float = 220.0, center_anchored: bool = true) -> void:
	_fit_dialog_entry(dialog, pref_w, pref_h, min_w, min_h, center_anchored)


func _fit_dialog_entry(dialog: Control, pref_w: float, pref_h: float, min_w: float, min_h: float, center_anchored: bool) -> void:
	if not is_instance_valid(dialog):
		return
	var vp_size := get_viewport_size()
	var insets := get_safe_insets()
	var target := UITypography.compute_dialog_size(pref_w, pref_h, vp_size, insets, min_w, min_h)

	if center_anchored:
		dialog.anchor_left = 0.5
		dialog.anchor_top = 0.5
		dialog.anchor_right = 0.5
		dialog.anchor_bottom = 0.5
		dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
		dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
		dialog.custom_minimum_size = Vector2(minf(dialog.custom_minimum_size.x, target.x) if dialog.custom_minimum_size.x > 0.0 else target.x, minf(dialog.custom_minimum_size.y, target.y) if dialog.custom_minimum_size.y > 0.0 else target.y)
		if dialog.custom_minimum_size.x < target.x:
			dialog.custom_minimum_size.x = target.x
		if dialog.custom_minimum_size.y < target.y:
			dialog.custom_minimum_size.y = target.y
		dialog.offset_left = -target.x * 0.5
		dialog.offset_right = target.x * 0.5
		dialog.offset_top = -target.y * 0.5
		dialog.offset_bottom = target.y * 0.5
		dialog.pivot_offset = target * 0.5
	else:
		dialog.custom_minimum_size.x = minf(target.x, dialog.custom_minimum_size.x) if dialog.custom_minimum_size.x > 0.0 else target.x
		dialog.custom_minimum_size.y = minf(target.y, dialog.custom_minimum_size.y) if dialog.custom_minimum_size.y > 0.0 else target.y


func _sync_viewport_metrics(force: bool = false) -> void:
	var vp_size := get_viewport_size()
	if not force and vp_size.is_equal_approx(_last_vp_size):
		return
	_last_vp_size = vp_size
	UITypography.update_viewport_metrics(vp_size, _user_text_scale)
	_refresh_all_tracked()
	layout_changed.emit({
		"viewport_size": vp_size,
		"font_scale": UITypography.get_font_scale(),
		"ui_scale": UITypography.get_ui_scale(),
		"safe_insets": get_safe_insets(),
		"is_compact_width": UITypography.is_compact_width(),
		"is_short_height": UITypography.is_short_height(),
		"is_wide_screen": UITypography.is_wide_screen(),
	})


func _on_viewport_size_changed() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_viewport_resize")


func _flush_viewport_resize() -> void:
	_refresh_queued = false
	_sync_viewport_metrics(true)


func _scan_existing_tree() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_scan_subtree(tree.root)


func _scan_subtree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		_instrument_text_control(node as Control)
	for ch in node.get_children():
		_scan_subtree(ch)


func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_instrument_text_control", node)


func _is_text_control(ctrl: Control) -> bool:
	return (ctrl is Label) or (ctrl is Button) or (ctrl is LineEdit) or (ctrl is TextEdit) or (ctrl is RichTextLabel)


func _track_text_control(ctrl: Control) -> void:
	var iid: int = ctrl.get_instance_id()
	if _tracked_ids.has(iid):
		return
	_tracked_ids[iid] = true
	_tracked_text_controls.append(weakref(ctrl))


func _instrument_text_control(ctrl: Control) -> void:
	if not is_instance_valid(ctrl) or not _is_text_control(ctrl):
		return
	if ctrl.has_meta(&"_resp_raw") and bool(ctrl.get_meta(&"_resp_raw")):
		return

	UITypography.configure_bidi(ctrl, false, false)

	if ctrl.has_meta(&"_resp_managed") and bool(ctrl.get_meta(&"_resp_managed")):
		_track_text_control(ctrl)
		_refresh_single_text_control(ctrl)
		return

	if ctrl.has_meta(&"_resp_role"):
		_track_text_control(ctrl)
		_refresh_single_text_control(ctrl)
		return

	# Inspect existing override or theme font size so legacy controls automatically gain
	# minimum legibility floors and responsive scaling across screen sizes.
	var base_px: int = 0
	if ctrl is RichTextLabel:
		var rtl := ctrl as RichTextLabel
		if rtl.has_theme_font_size_override("normal_font_size"):
			base_px = rtl.get_theme_font_size("normal_font_size")
		else:
			base_px = rtl.get_theme_font_size("normal_font_size")
	elif ctrl.has_theme_font_size_override("font_size"):
		base_px = ctrl.get_theme_font_size("font_size")
	else:
		base_px = ctrl.get_theme_font_size("font_size")

	if base_px <= 0:
		base_px = 19

	var normalized: int = UITypography.normalize_raw_px(base_px)
	var min_px: int = UITypography.COMPACT_MIN_FONT_PX if base_px <= 15 else UITypography.STANDARD_MIN_FONT_PX
	ctrl.set_meta(&"_resp_base_px", normalized)
	ctrl.set_meta(&"_resp_min_px", min_px)
	ctrl.set_meta(&"_resp_max_px", maxi(72, normalized))
	_track_text_control(ctrl)
	_refresh_single_text_control(ctrl)


func _refresh_single_text_control(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	if ctrl.has_meta(&"_resp_raw") and bool(ctrl.get_meta(&"_resp_raw")):
		return
	var target_px: int = 0
	if ctrl.has_meta(&"_resp_role"):
		var role: int = int(ctrl.get_meta(&"_resp_role"))
		var cmin: int = int(ctrl.get_meta(&"_resp_min_px")) if ctrl.has_meta(&"_resp_min_px") else -1
		var cmax: int = int(ctrl.get_meta(&"_resp_max_px")) if ctrl.has_meta(&"_resp_max_px") else -1
		target_px = UITypography.get_role_font_size(role, cmin, cmax)
	elif ctrl.has_meta(&"_resp_base_px"):
		var base_px: int = int(ctrl.get_meta(&"_resp_base_px"))
		var cmin2: int = int(ctrl.get_meta(&"_resp_min_px")) if ctrl.has_meta(&"_resp_min_px") else UITypography.ABSOLUTE_MIN_FONT_PX
		var cmax2: int = int(ctrl.get_meta(&"_resp_max_px")) if ctrl.has_meta(&"_resp_max_px") else 72
		target_px = UITypography.scale_px(base_px, cmin2, cmax2)
	else:
		return

	if ctrl is RichTextLabel:
		var rtl := ctrl as RichTextLabel
		rtl.add_theme_font_size_override("normal_font_size", target_px)
		rtl.add_theme_font_size_override("bold_font_size", target_px + 2)
		rtl.add_theme_font_size_override("italics_font_size", target_px)
	else:
		ctrl.add_theme_font_size_override("font_size", target_px)


func _refresh_all_tracked() -> void:
	var alive_ctrls: Array[WeakRef] = []
	var new_ids: Dictionary = {}
	for wr in _tracked_text_controls:
		var obj: Object = wr.get_ref()
		if obj != null and is_instance_valid(obj) and obj is Control:
			var ctrl := obj as Control
			_refresh_single_text_control(ctrl)
			alive_ctrls.append(wr)
			new_ids[ctrl.get_instance_id()] = true
	_tracked_text_controls = alive_ctrls
	_tracked_ids = new_ids

	var alive_dlgs: Array[Dictionary] = []
	var new_dlg_ids: Dictionary = {}
	for entry in _tracked_dialogs:
		var wr_d: WeakRef = entry["ref"]
		var obj_d: Object = wr_d.get_ref()
		if obj_d != null and is_instance_valid(obj_d) and obj_d is Control:
			var dlg := obj_d as Control
			_fit_dialog_entry(
				dlg,
				float(entry["pref_w"]),
				float(entry["pref_h"]),
				float(entry["min_w"]),
				float(entry["min_h"]),
				bool(entry["center_anchored"])
			)
			alive_dlgs.append(entry)
			new_dlg_ids[dlg.get_instance_id()] = true
	_tracked_dialogs = alive_dlgs
	_tracked_dialog_ids = new_dlg_ids
