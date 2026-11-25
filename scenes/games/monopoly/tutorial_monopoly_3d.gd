class_name TutorialMonopoly3D
extends "res://scenes/games/monopoly/monopoly_3d.gd"

## Offline interactive Roopoly (Monopoly) 3D board for the Library tutorial.
## Covers rolling dice, buying property (color monopoly), building 3D houses,
## Chance card event, live Auction bidding, Mortgaging to pay Rent Debt,
## Incoming Trade offers, and escaping Jail (3 methods).

signal tutorial_rolled(dice: Array)
signal tutorial_property_decided(action_name: String)
signal tutorial_house_built(tile_id: int)
signal tutorial_chance_drawn()
signal tutorial_auction_done()
signal tutorial_mortgaged(tile_id: int)
signal tutorial_debt_paid()
signal tutorial_trade_resolved(action_name: String)
signal tutorial_jail_escaped(method: String)

var tutorial_input_enabled: bool = false
var _sim_seq: int = 1
var _roll_stage: int = 0 # 0 = first roll (0->3), 1 = chance roll (3->12)


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_monopoly_state()


func _connect_monopoly_signals() -> void:
	pass


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func _make_base_tiles() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for t in MonopolyData.BOARD_TILES:
		var tid: int = int(t.get("id", 0))
		arr.append({
			"id": tid,
			"owner": 0,
			"houses": 0,
			"mortgaged": false,
		})
	return arr


func setup_tutorial_monopoly_state() -> void:
	_match_started = true
	_roll_stage = 0
	var tiles := _make_base_tiles()
	tiles[1]["owner"] = 1 # مولوی owned by You
	tiles[6]["owner"] = 2 # لاله‌زار owned by Opponent
	tiles[7]["owner"] = 2 # بهارستان owned by Opponent
	_sim_seq += 1
	_on_monopoly_event_received(Commands.Monopoly_State, {
		"players_count": 2,
		"phase": "roll",
		"state_seq": _sim_seq,
		"round_number": 1,
		"current_turn": 1,
		"last_dice": [0, 0],
		"pending_tile_id": -1,
		"players": [
			{"gamer_id": 1, "index": 1, "cash": 1500, "position": 0, "in_jail": false, "jail_turns": 0, "jail_cards": 1, "bankrupt": false},
			{"gamer_id": 2, "index": 2, "cash": 1400, "position": 5, "in_jail": false, "jail_turns": 0, "jail_cards": 0, "bankrupt": false},
		],
		"tiles": tiles,
		"buildable_tiles": [],
		"sellable_tiles": [],
		"mortgageable_tiles": [1],
		"unmortgageable_tiles": [],
	})


func setup_chance_roll_scenario() -> void:
	if is_instance_valid(portfolio_backdrop):
		portfolio_backdrop.visible = false
	_roll_stage = 1
	var p1 := _get_player_dict(1).duplicate(true)
	var p2 := _get_player_dict(2).duplicate(true)
	_sim_seq += 1
	_on_monopoly_event_received(Commands.Monopoly_State, {
		"players_count": 2,
		"phase": "roll",
		"state_seq": _sim_seq,
		"current_turn": 1,
		"players": [p1, p2],
		"tiles": tiles_state.duplicate(true),
		"buildable_tiles": [1, 3],
		"mortgageable_tiles": [1, 3],
	})


func setup_auction_scenario() -> void:
	if is_instance_valid(portfolio_backdrop):
		portfolio_backdrop.visible = false
	var p1 := _get_player_dict(1).duplicate(true)
	p1["position"] = 14 # جردن
	p1["cash"] = maxi(int(p1.get("cash", 1500)), 500)
	var p2 := _get_player_dict(2).duplicate(true)
	_sim_seq += 1
	_on_monopoly_event_received(Commands.Monopoly_State, {
		"players_count": 2,
		"phase": "auction",
		"state_seq": _sim_seq,
		"current_turn": 1,
		"players": [p1, p2],
		"tiles": tiles_state.duplicate(true),
		"auction": {
			"tile_id": 14,
			"tile_name": "جردن",
			"current_bid": 20,
			"highest_bidder": 2,
			"current_bidder": 1,
		}
	})


func setup_mortgage_debt_scenario() -> void:
	if is_instance_valid(portfolio_backdrop):
		portfolio_backdrop.visible = false
	var p1 := _get_player_dict(1).duplicate(true)
	# Give only $120 cash against $150 rent so player MUST mortgage a property first!
	p1["cash"] = 120
	p1["position"] = 6 # لاله‌زار (owned by Opponent -> $150 rent!)
	var p2 := _get_player_dict(2).duplicate(true)
	_sim_seq += 1
	_on_monopoly_event_received(Commands.Monopoly_State, {
		"players_count": 2,
		"phase": "debt",
		"state_seq": _sim_seq,
		"current_turn": 1,
		"players": [p1, p2],
		"tiles": tiles_state.duplicate(true),
		"debt": {"player_id": 1, "to_player_id": 2, "amount": 150, "reason": "اجاره لاله‌زار"},
		"buildable_tiles": [],
		"sellable_tiles": [],
		"mortgageable_tiles": [14, 3, 1],
		"unmortgageable_tiles": [],
	})


func setup_trade_scenario() -> void:
	if is_instance_valid(portfolio_backdrop):
		portfolio_backdrop.visible = false
	var p1 := _get_player_dict(1).duplicate(true)
	var p2 := _get_player_dict(2).duplicate(true)
	_sim_seq += 1
	_on_monopoly_event_received(Commands.Monopoly_State, {
		"players_count": 2,
		"phase": "trade",
		"state_seq": _sim_seq,
		"current_turn": 2,
		"players": [p1, p2],
		"tiles": tiles_state.duplicate(true),
		"pending_trade": {
			"from_player": 2,
			"to_player": 1,
			"offer_cash": 60,
			"offer_tiles": [7], # بهارستان
			"request_cash": 0,
			"request_tiles": [14], # جردن
		}
	})


func setup_jail_scenario() -> void:
	if is_instance_valid(portfolio_backdrop):
		portfolio_backdrop.visible = false
	if is_instance_valid(trade_incoming_backdrop):
		trade_incoming_backdrop.visible = false
	var p1 := _get_player_dict(1).duplicate(true)
	p1["position"] = 8
	p1["in_jail"] = true
	p1["jail_turns"] = 0
	p1["jail_cards"] = 1
	p1["cash"] = maxi(int(p1.get("cash", 1500)), 150)
	var p2 := _get_player_dict(2).duplicate(true)
	_sim_seq += 1
	_on_monopoly_event_received(Commands.Monopoly_State, {
		"players_count": 2,
		"phase": "roll",
		"state_seq": _sim_seq,
		"current_turn": 1,
		"players": [p1, p2],
		"tiles": tiles_state.duplicate(true),
		"buildable_tiles": [1, 3],
		"mortgageable_tiles": [1, 3],
	})


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	var d: Dictionary = payload as Dictionary if typeof(payload) == TYPE_DICTIONARY else {}
	var p1 := _get_player_dict(1).duplicate(true)
	var p2 := _get_player_dict(2).duplicate(true)
	var tiles_copy := tiles_state.duplicate(true)

	if command_id == Commands.Monopoly_Roll:
		if _roll_stage == 0:
			p1["position"] = 3
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_Event, {
				"event": "roll",
				"player_id": 1,
				"dice": [1, 2],
				"path": [1, 2, 3],
				"state": {
					"players_count": 2,
					"phase": "buy_or_auction",
					"state_seq": _sim_seq,
					"current_turn": 1,
					"last_dice": [1, 2],
					"pending_tile_id": 3,
					"players": [p1, p2],
					"tiles": tiles_copy,
				}
			})
			tutorial_rolled.emit([1, 2])
		else:
			p1["position"] = 12 # کارت شانس
			p1["cash"] = int(p1.get("cash", 1500)) + 100
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_Event, {
				"event": "card_drawn",
				"deck": "chance",
				"card": {"title": "سود سرمایه‌گذاری", "desc": "بانک $۱۰۰ سود سهام به شما پرداخت کرد!"},
				"player_id": 1,
				"dice": [4, 5],
				"path": [4, 5, 6, 7, 8, 9, 10, 11, 12],
				"state": {
					"players_count": 2,
					"phase": "manage",
					"state_seq": _sim_seq,
					"current_turn": 1,
					"last_dice": [4, 5],
					"players": [p1, p2],
					"tiles": tiles_copy,
					"buildable_tiles": [1, 3],
				}
			})
			tutorial_chance_drawn.emit()

	elif command_id == Commands.Monopoly_Action:
		var act: String = str(d.get("action", ""))
		if act == "buy_property":
			var tid: int = pending_tile_id if pending_tile_id >= 0 else 3
			p1["cash"] = maxi(0, int(p1.get("cash", 1500)) - 60)
			for t in tiles_copy:
				if int(t.get("id", -1)) == tid:
					t["owner"] = 1
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_State, {
				"players_count": 2,
				"phase": "manage",
				"state_seq": _sim_seq,
				"current_turn": 1,
				"pending_tile_id": -1,
				"players": [p1, p2],
				"tiles": tiles_copy,
				"buildable_tiles": [1, 3],
				"mortgageable_tiles": [1, 3],
			})
			tutorial_property_decided.emit("buy_property")

		elif act == "decline_buy":
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_State, {
				"players_count": 2,
				"phase": "auction",
				"state_seq": _sim_seq,
				"current_turn": 1,
				"players": [p1, p2],
				"tiles": tiles_copy,
				"auction": {
					"tile_id": 3,
					"tile_name": "بازار بزرگ",
					"current_bid": 20,
					"highest_bidder": 2,
					"current_bidder": 1,
				}
			})
			tutorial_property_decided.emit("decline_buy")

		elif act == "build_house":
			var tid: int = int(d.get("tile_id", 1))
			p1["cash"] = maxi(0, int(p1.get("cash", 1500)) - 50)
			for t in tiles_copy:
				if int(t.get("id", -1)) == tid:
					t["houses"] = mini(5, int(t.get("houses", 0)) + 1)
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_State, {
				"players_count": 2,
				"phase": "manage",
				"state_seq": _sim_seq,
				"current_turn": 1,
				"players": [p1, p2],
				"tiles": tiles_copy,
				"buildable_tiles": [1, 3],
				"sellable_tiles": [tid],
				"mortgageable_tiles": [1, 3],
			})
			if is_instance_valid(portfolio_backdrop):
				portfolio_backdrop.visible = false
			tutorial_house_built.emit(tid)

		elif act == "mortgage":
			var tid: int = int(d.get("tile_id", 1))
			var m_gain: int = int(MonopolyData.get_tile(tid).get("price", 60)) / 2
			p1["cash"] = int(p1.get("cash", 120)) + maxi(30, m_gain)
			for t in tiles_copy:
				if int(t.get("id", -1)) == tid:
					t["mortgaged"] = true
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_State, {
				"players_count": 2,
				"phase": phase,
				"state_seq": _sim_seq,
				"current_turn": 1,
				"players": [p1, p2],
				"tiles": tiles_copy,
				"debt": debt_state,
				"mortgageable_tiles": [],
				"unmortgageable_tiles": [tid],
			})
			if is_instance_valid(portfolio_backdrop):
				portfolio_backdrop.visible = false
			tutorial_mortgaged.emit(tid)

		elif act == "pay_debt":
			var amt: int = int(debt_state.get("amount", 150))
			p1["cash"] = maxi(0, int(p1.get("cash", 0)) - amt)
			p2["cash"] = int(p2.get("cash", 1400)) + amt
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_State, {
				"players_count": 2,
				"phase": "manage",
				"state_seq": _sim_seq,
				"current_turn": 1,
				"players": [p1, p2],
				"tiles": tiles_copy,
				"debt": {},
				"buildable_tiles": [1, 3],
			})
			tutorial_debt_paid.emit()

		elif act in ["roll_jail", "pay_bail", "use_jail_card"]:
			if act == "pay_bail":
				p1["cash"] = maxi(0, int(p1.get("cash", 150)) - 50)
			elif act == "use_jail_card":
				p1["jail_cards"] = maxi(0, int(p1.get("jail_cards", 1)) - 1)
			p1["in_jail"] = false
			p1["position"] = 11
			_sim_seq += 1
			_on_monopoly_event_received(Commands.Monopoly_Event, {
				"event": "roll",
				"player_id": 1,
				"dice": [2, 1],
				"path": [9, 10, 11],
				"state": {
					"players_count": 2,
					"phase": "manage",
					"state_seq": _sim_seq,
					"current_turn": 1,
					"last_dice": [2, 1],
					"players": [p1, p2],
					"tiles": tiles_copy,
					"buildable_tiles": [1, 3],
				}
			})
			tutorial_jail_escaped.emit(act)

	elif command_id == Commands.Monopoly_Auction:
		var dec: String = str(d.get("decision", "bid"))
		var bid_amt: int = int(d.get("amount", 30))
		var auc_tid: int = int(auction_state.get("tile_id", 14))
		if dec == "bid":
			p1["cash"] = maxi(0, int(p1.get("cash", 1500)) - bid_amt)
			for t in tiles_copy:
				if int(t.get("id", -1)) == auc_tid:
					t["owner"] = 1
		else:
			p2["cash"] = maxi(0, int(p2.get("cash", 1400)) - 20)
			for t in tiles_copy:
				if int(t.get("id", -1)) == auc_tid:
					t["owner"] = 2
		_sim_seq += 1
		_on_monopoly_event_received(Commands.Monopoly_State, {
			"players_count": 2,
			"phase": "manage",
			"state_seq": _sim_seq,
			"current_turn": 1,
			"players": [p1, p2],
			"tiles": tiles_copy,
			"auction": {},
			"buildable_tiles": [1, 3],
		})
		tutorial_auction_done.emit()

	elif command_id == Commands.Monopoly_Trade:
		var act_t: String = str(d.get("action", "accept"))
		if act_t == "accept":
			p1["cash"] = int(p1.get("cash", 100)) + 60
			p2["cash"] = maxi(0, int(p2.get("cash", 1400)) - 60)
			for t in tiles_copy:
				if int(t.get("id", -1)) == 7:
					t["owner"] = 1
				elif int(t.get("id", -1)) == 14:
					t["owner"] = 2
		_sim_seq += 1
		_on_monopoly_event_received(Commands.Monopoly_State, {
			"players_count": 2,
			"phase": "manage",
			"state_seq": _sim_seq,
			"current_turn": 1,
			"players": [p1, p2],
			"tiles": tiles_copy,
			"pending_trade": {},
		})
		tutorial_trade_resolved.emit(act_t)


func get_dock_control() -> Control:
	return dock_panel if is_instance_valid(dock_panel) else bottom_dock


func get_actions_vbox_control() -> Control:
	return actions_vbox if is_instance_valid(actions_vbox) else get_dock_control()


func get_action_button_matching(keywords: Array[String]) -> Control:
	var root_search: Control = actions_vbox if is_instance_valid(actions_vbox) else dock_panel
	if is_instance_valid(root_search):
		var found := _find_btn_with_text(root_search, keywords)
		if is_instance_valid(found):
			return found
	return get_dock_control()


func get_build_target_control() -> Control:
	if is_instance_valid(portfolio_backdrop) and portfolio_backdrop.visible:
		if is_instance_valid(portfolio_list_vbox):
			var btn := _find_btn_with_text(portfolio_list_vbox, ["+خانه", "+هتل", "خانه"])
			if is_instance_valid(btn):
				return btn
		if is_instance_valid(_portfolio_panel):
			return _portfolio_panel
	return get_action_button_matching(["ساخت‌وساز", "مدیریت املاک"])


func get_mortgage_target_control() -> Control:
	if is_instance_valid(portfolio_backdrop) and portfolio_backdrop.visible:
		if is_instance_valid(portfolio_list_vbox):
			var btn := _find_btn_with_text(portfolio_list_vbox, ["رهن"])
			if is_instance_valid(btn):
				return btn
		if is_instance_valid(_portfolio_panel):
			return _portfolio_panel
	return get_action_button_matching(["فروش / رهن"])


func get_trade_target_control() -> Control:
	if is_instance_valid(trade_incoming_backdrop) and trade_incoming_backdrop.visible:
		if is_instance_valid(_trade_incoming_panel):
			return _trade_incoming_panel
	return get_dock_control()


func _find_btn_with_text(node: Node, keywords: Array[String]) -> Control:
	if node is Button and (node as Button).visible:
		if _node_contains_any_text(node, keywords):
			return node as Control
	for ch in node.get_children():
		var res := _find_btn_with_text(ch, keywords)
		if is_instance_valid(res):
			return res
	return null


func _node_contains_any_text(node: Node, keywords: Array[String]) -> bool:
	if node is Label:
		var t: String = (node as Label).text
		for kw in keywords:
			if kw in t:
				return true
	elif node is Button:
		var bt: String = (node as Button).text
		for kw in keywords:
			if kw in bt:
				return true
	for ch in node.get_children():
		if _node_contains_any_text(ch, keywords):
			return true
	return false


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
