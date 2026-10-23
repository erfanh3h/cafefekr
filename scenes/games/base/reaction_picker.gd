extends Control

# Reaction / Emote Picker
# Displays a grid of emoji reactions that players can send during matches

signal reaction_selected(reaction_id: int)

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var grid: GridContainer = $CenterContainer/Panel/Margin/VBox/Grid
@onready var btn_close: Button = $CenterContainer/Panel/Margin/VBox/BtnClose

# Popular, expressive reaction IDs from assets/icons/Reactions (16 items for clean 4x4 layout)
const POPULAR_REACTIONS: Array[int] = [
	1, 2, 3, 4, 6, 7, 8, 10, 11, 14, 15, 18, 20, 22, 27, 36
]

func _ready() -> void:
	visible = false
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_GREY)
	btn_close.pressed.connect(close)
	_build_grid()

func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
		
	for r_id in POPULAR_REACTIONS:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(110, 110)
		card.pivot_offset = Vector2(55, 55)
		
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.13, 0.08, 0.05, 0.82)
		normal_style.set_border_width_all(2)
		normal_style.border_color = Color(0.48, 0.36, 0.22, 0.85)
		normal_style.set_corner_radius_all(16)
		normal_style.shadow_color = Color(0, 0, 0, 0.4)
		normal_style.shadow_size = 4
		card.add_theme_stylebox_override("panel", normal_style)
		
		var hover_style = normal_style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(1.0, 0.85, 0.35, 1.0)
		hover_style.bg_color = Color(0.25, 0.16, 0.08, 0.95)
		hover_style.shadow_size = 8
		
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(96, 96)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		var icon_path = "res://assets/icons/Reactions/%d.png" % r_id
		if ResourceLoader.exists(icon_path):
			btn.texture_normal = load(icon_path)
			
		card.add_child(btn)
		
		btn.mouse_entered.connect(func():
			card.add_theme_stylebox_override("panel", hover_style)
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2(1.12, 1.12), 0.1)
		)
		btn.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel", normal_style)
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2.ONE, 0.1)
		)
		
		var chosen_id = r_id
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			reaction_selected.emit(chosen_id)
			close()
		)
		
		grid.add_child(card)

func open() -> void:
	ActionVFXManager.animate_dialog_open(panel, self, true)

func close() -> void:
	ActionVFXManager.animate_dialog_close(panel, self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
