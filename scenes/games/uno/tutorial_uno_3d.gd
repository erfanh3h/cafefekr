class_name TutorialUNO3D
extends "res://scenes/games/uno/uno_3d.gd"

## Offline interactive UNO 3D board for the Library tutorial.

signal tutorial_card_played(card: Dictionary)
signal tutorial_card_drawn()
signal tutorial_uno_called()
signal tutorial_wild_picker_opened()

var tutorial_input_enabled: bool = false


func _ready() -> void:
	super._ready()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	setup_tutorial_hand()


func _connect_uno_signals() -> void:
	pass


func _disconnect_uno_signals() -> void:
	pass


func setup_tutorial_hand() -> void:
	_apply_uno_state_dict({
		"my_hand": [
			{"uid": 101, "color": "red", "value": "skip"},
			{"uid": 102, "color": "red", "value": "reverse"},
			{"uid": 103, "color": "red", "value": "draw2"},
			{"uid": 104, "color": "wild", "value": "wild"},
			{"uid": 105, "color": "wild", "value": "wild_draw4"},
			{"uid": 106, "color": "red", "value": "7"}
		],
		"top_card": {"color": "red", "value": "5"},
		"current_color": "red",
		"direction": 1,
		"deck_remaining": 42,
		"hands_count": {"1": 6, "2": 6}
	})
	is_my_turn = true
	is_board_locked = false


func _refresh_action_buttons(playable_cnt: int) -> void:
	super._refresh_action_buttons(playable_cnt)
	var can_uno: bool = (my_hand.size() <= 2 and my_hand.size() >= 1) and not _has_player_called_uno(my_player_index)
	if is_instance_valid(call_uno_btn):
		call_uno_btn.visible = can_uno
	if is_instance_valid(table_3d):
		table_3d.set_uno_bell_alert(can_uno)


func _on_uno_button_pressed() -> void:
	if my_hand.size() > 2:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("🔥 دکمه و زنگ «اونو!» زمانی فعال می‌شود که ۱ یا ۲ کارت داشته باشید", Color(0.98, 0.80, 0.32), 2.0)
		return
	AudioManager.sfx_win()
	send_move(Commands.Call_Uno, {})


func _open_wild_color_modal(card_data: Dictionary) -> void:
	super._open_wild_color_modal(card_data)
	tutorial_wild_picker_opened.emit()


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	if command_id == Commands.Play_Card and typeof(payload) == TYPE_DICTIONARY:
		var d: Dictionary = payload as Dictionary
		var uid: int = int(d.get("card_uid", d.get("uid", -1)))
		var remove_idx: int = -1
		for i in range(my_hand.size()):
			var c: Dictionary = my_hand[i]
			if int(c.get("uid", -2)) == uid:
				remove_idx = i
				break
		if remove_idx < 0:
			remove_idx = int(d.get("index", 0))
		if remove_idx >= 0 and remove_idx < my_hand.size():
			var played: Dictionary = my_hand[remove_idx]
			my_hand.remove_at(remove_idx)
			var new_col: String = str(d.get("chosen_color", d.get("color", played.get("color", "red"))))
			if new_col == "wild" or new_col.is_empty():
				new_col = "red"
			var new_dir: int = -direction if str(played.get("value", "")) == "reverse" else direction
			var opp_cnt: int = int(hands_count.get("2", 6))
			if str(played.get("value", "")) == "draw2":
				opp_cnt += 2
			elif str(played.get("value", "")) == "wild_draw4":
				opp_cnt += 4
			_apply_uno_state_dict({
				"my_hand": my_hand,
				"top_card": played,
				"current_color": new_col,
				"direction": new_dir,
				"hands_count": {"1": my_hand.size(), "2": opp_cnt}
			})
			if is_instance_valid(call_uno_btn):
				call_uno_btn.visible = (my_hand.size() <= 2 and my_hand.size() >= 1)
			is_my_turn = true
			is_board_locked = false
			tutorial_card_played.emit(played)
	elif command_id == Commands.Draw_Card:
		my_hand.append({"uid": 200 + my_hand.size(), "color": "yellow", "value": "3"})
		_apply_uno_state_dict({"my_hand": my_hand, "hands_count": {"1": my_hand.size(), "2": 6}})
		is_my_turn = true
		is_board_locked = false
		tutorial_card_drawn.emit()
	elif command_id == Commands.Call_Uno:
		tutorial_uno_called.emit()


func get_hand_container() -> Control:
	return hand_scroll if is_instance_valid(hand_scroll) else hand_cards_box


func get_wild_modal_control() -> Control:
	return wild_modal_panel if is_instance_valid(wild_modal_panel) else wild_modal_backdrop


func get_uno_button() -> Control:
	return call_uno_btn


func get_uno_bell_rect() -> Rect2:
	if is_instance_valid(table_3d):
		var bell: Node3D = table_3d.find_child("UnoShoutBell3D", true, false) as Node3D
		if is_instance_valid(bell):
			var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), bell.global_position + Vector3(0.0, 0.02, 0.02), 0.11, 0.12, 92.0)
			if r.size.x > 0.0:
				return r
	if is_instance_valid(call_uno_btn) and call_uno_btn.visible:
		return call_uno_btn.get_global_rect()
	return Rect2()


func get_draw_button() -> Control:
	return draw_action_btn


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.65, 0.04)
