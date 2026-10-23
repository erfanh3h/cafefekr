extends PanelContainer

# Store Dialog Controller
# Mirrors StorePage from Flutter:
# Free coin claim timer, and Avatar selection gallery (calls /update-image)

signal closed()

@onready var avatar_grid: GridContainer = $Margin/VBox/Scroll/VBoxScroll/AvatarGrid
@onready var btn_free_coin: Button = $Margin/VBox/BtnFreeCoin
@onready var btn_close: Button = $Margin/VBox/BtnClose
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var lbl_status: Label = $Margin/VBox/LblStatus

var selected_avatar_id: int = -1
var _avatar_cards: Dictionary = {} # image_id -> card

func _ready() -> void:
	btn_free_coin.visible = false
	KenneyUI.style_button(btn_free_coin, KenneyUI.COLOR_YELLOW)
	btn_close.text = "ثبت"
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_GREEN)
	
	btn_close.pressed.connect(_on_bottom_button_pressed)
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	btn_free_coin.pressed.connect(_on_claim_free_coin)
	_populate_avatars()

func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	lbl_status.text = ""
	selected_avatar_id = GameManager.get_avatar_id()
	btn_close.text = "ثبت"
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_GREEN)
	_refresh_card_highlights()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func _update_bottom_button() -> void:
	btn_close.text = "ثبت"
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_GREEN)
	var current_saved = GameManager.get_avatar_id()
	if selected_avatar_id != current_saved and selected_avatar_id >= 0:
		lbl_status.text = "برای تایید تغییر، دکمه «ثبت» را بزنید."
		lbl_status.modulate = Color(1.0, 0.88, 0.4)
	else:
		lbl_status.text = ""

func _on_bottom_button_pressed() -> void:
	AudioManager.sfx_button()
	var current_saved = GameManager.get_avatar_id()
	if selected_avatar_id != current_saved and selected_avatar_id >= 0:
		_submit_avatar_change()
	else:
		close()

func _populate_avatars() -> void:
	for child in avatar_grid.get_children():
		child.queue_free()
	_avatar_cards.clear()
	
	var current_user_avatar = GameManager.get_avatar_id()
	if selected_avatar_id < 0:
		selected_avatar_id = current_user_avatar
	
	# Avatars range from 0 to 71 in assets/icons/Avatars
	for i in range(72):
		var path = "res://assets/icons/Avatars/%d.png" % i
		if ResourceLoader.exists(path):
			var card = PanelContainer.new()
			# Sized to perfectly fit 4 per row within 700px width with no horizontal scroll
			card.custom_minimum_size = Vector2(155, 155)
			card.pivot_offset = Vector2(77.5, 77.5)
			
			var is_selected = (i == selected_avatar_id)
			_apply_card_style(card, is_selected)
			
			var btn = TextureButton.new()
			btn.custom_minimum_size = Vector2(135, 135)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.texture_normal = load(path)
			
			var img_id = i
			btn.pressed.connect(func():
				_on_avatar_tapped(img_id, card)
			)
			card.add_child(btn)
			avatar_grid.add_child(card)
			_avatar_cards[img_id] = card
			
	_update_bottom_button()

func _apply_card_style(card: PanelContainer, is_selected: bool) -> void:
	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.28, 0.18, 0.08, 0.95)
		style.border_color = Color(1.0, 0.85, 0.3, 1.0)
		style.set_border_width_all(3)
		style.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
		style.shadow_size = 8
	else:
		style.bg_color = Color(0.14, 0.09, 0.06, 0.85)
		style.border_color = Color(0.42, 0.32, 0.2, 0.7)
		style.set_border_width_all(2)
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 4
	style.set_corner_radius_all(16)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

func _refresh_card_highlights() -> void:
	for id in _avatar_cards.keys():
		var card = _avatar_cards[id]
		if is_instance_valid(card):
			_apply_card_style(card, id == selected_avatar_id)

func _on_avatar_tapped(image_id: int, card: PanelContainer) -> void:
	AudioManager.sfx_tap()
	ActionVFXManager.animate_button_pop(card)
	selected_avatar_id = image_id
	_refresh_card_highlights()
	_update_bottom_button()

func _submit_avatar_change() -> void:
	lbl_status.text = "در حال تغییر تصویر پروفایل..."
	lbl_status.modulate = Color(1.0, 0.9, 0.4)
	btn_close.disabled = true
	
	NetworkManager.api.update_avatar(selected_avatar_id, func(success: bool, _code: int, data: Variant):
		btn_close.disabled = false
		if success:
			lbl_status.text = "تصویر پروفایل با موفقیت تغییر کرد! 🎉"
			lbl_status.modulate = Color(0.2, 0.9, 0.4)
			GameManager.user_data["image"] = selected_avatar_id
			GameManager.user_data["avatar"] = selected_avatar_id
			GameManager.set_session(GameManager.token, GameManager.user_data, true)
			GameManager.user_logged_in.emit(GameManager.user_data)
			_update_bottom_button()
			_refresh_card_highlights()
			get_tree().create_timer(1.2).timeout.connect(func():
				close()
			)
		else:
			var err = "خطا در تغییر تصویر"
			if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
				err = str(data["detail"])
			lbl_status.text = err
			lbl_status.modulate = Color(0.9, 0.3, 0.3)
	)

func _on_claim_free_coin() -> void:
	AudioManager.sfx_button()
	lbl_status.text = "در حال دریافت سکه رایگان..."
	btn_free_coin.disabled = true
	
	NetworkManager.api.claim_free_coin(func(success: bool, _code: int, data: Variant):
		btn_free_coin.disabled = false
		if success and typeof(data) == TYPE_DICTIONARY:
			var res = data.get("result", {})
			var new_coin = res.get("coin", GameManager.get_coins())
			GameManager.user_data["coin"] = new_coin
			GameManager.user_logged_in.emit(GameManager.user_data)
			lbl_status.text = "سکه رایگان دریافت شد! 🪙"
			lbl_status.modulate = Color(0.2, 0.9, 0.4)
			AudioManager.sfx_bell()
		else:
			lbl_status.text = "امروز سکه رایگان را دریافت کرده‌اید."
			lbl_status.modulate = Color(0.9, 0.7, 0.3)
	)
