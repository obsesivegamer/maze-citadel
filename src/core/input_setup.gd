class_name InputSetup
extends RefCounted
## Registers the game's input actions in code (GDD §10), so no subsystem
## needs to edit project.godot.

const KEYS := {
	&"pause": [KEY_SPACE],
	&"speed": [KEY_F],
	&"deselect": [KEY_ESCAPE],
	&"sell": [KEY_X],
	&"upgrade": [KEY_U],
	&"fuse": [KEY_G],
	&"next_wave": [KEY_N],
	&"hero_view": [KEY_R],
	&"camera_preset": [KEY_C],
	&"boss_track": [KEY_B],
	&"field_guide": [KEY_H],
	&"cam_left": [KEY_A, KEY_LEFT],
	&"cam_right": [KEY_D, KEY_RIGHT],
	&"cam_forward": [KEY_W, KEY_UP],
	&"cam_back": [KEY_S, KEY_DOWN],
	&"cam_rotate_left": [KEY_Q],
	&"cam_rotate_right": [KEY_E],
	# eletd: while a pick waits, E opens the pick panel instead of turning.
	&"element_picks": [KEY_E],
}
const BUILD_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]


static func register() -> void:
	for action in KEYS:
		_add(action, KEYS[action])
	for i in BUILD_KEYS.size():
		_add(StringName("build_%d" % i), [BUILD_KEYS[i]])


static func _add(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
