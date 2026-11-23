class_name TutorialStep
extends RefCounted

## Data-driven tutorial step descriptor used by TutorialCoachOverlay and
## TutorialCoordinator. Designed for easy extension to future games, modals,
## and onboarding tours without modifying overlay rendering code.

var id: String = ""
var badge_text: String = ""
var title: String = ""
var body: String = ""
var cta_text: String = "بعدی"
var interactive_hint: String = "روی بخش مشخص‌شده لمس کنید"

## Callable returning either a Control, a Rect2 in viewport coordinates, or null.
var target_provider: Callable = Callable()

## Visual spotlight customization
var padding: float = 10.0
var corner_radius: float = 18.0
var card_placement: String = "auto" # "auto" | "top" | "bottom" | "center"

## Interaction model
## - allow_target_passthrough: lets touch/click events inside the spotlight reach the target control / 3D board.
## - require_target_action: hides the primary CTA button so the user advances by performing the highlighted action.
## - show_next_with_passthrough: keeps the CTA button visible even while target passthrough is enabled.
var allow_target_passthrough: bool = false
var require_target_action: bool = false
var show_next_with_passthrough: bool = false

## Optional lifecycle hooks invoked by TutorialCoordinator
var on_enter: Callable = Callable()
var on_exit: Callable = Callable()


static func create(step_id: String, step_title: String, step_body: String) -> TutorialStep:
	var s := TutorialStep.new()
	s.id = step_id
	s.title = step_title
	s.body = step_body
	return s


func with_badge(text: String) -> TutorialStep:
	badge_text = text
	return self


func with_cta(text: String) -> TutorialStep:
	cta_text = text
	return self


func with_hint(text: String) -> TutorialStep:
	interactive_hint = text
	return self


func with_target(provider: Callable, spot_padding: float = 10.0, radius: float = 18.0) -> TutorialStep:
	target_provider = provider
	padding = spot_padding
	corner_radius = radius
	return self


func with_placement(placement: String) -> TutorialStep:
	card_placement = placement
	return self


func with_interactive(require_action: bool = true, allow_next_button: bool = false) -> TutorialStep:
	allow_target_passthrough = true
	require_target_action = require_action
	show_next_with_passthrough = allow_next_button
	return self


func with_hooks(enter_cb: Callable = Callable(), exit_cb: Callable = Callable()) -> TutorialStep:
	on_enter = enter_cb
	on_exit = exit_cb
	return self
