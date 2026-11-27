## Rebindable keys (Phase 7). Input code keeps matching the default keys; a
## pressed key is first translated through the player's bindings.
class_name KeyBindings
extends RefCounted

## action -> [default key, label]
const ACTIONS: Dictionary = {
	"attack_move": [KEY_A, "Attack-move"], "reverse": [KEY_R, "Reverse"], "fire_mission": [KEY_F, "Fire mission"],
	"smoke_mission": [KEY_G, "Smoke mission"], "smoke": [KEY_X, "Smoke launchers"], "stop": [KEY_S, "Stop"],
	"hold_fire": [KEY_H, "Hold fire"], "emcon": [KEY_Z, "EMCON"], "unload": [KEY_U, "Unload"],
	"unload_at": [KEY_T, "Unload at point"], "formation": [KEY_N, "Formation"], "engage_range": [KEY_Y, "Engagement range"],
	"mines": [KEY_M, "Lay mines"], "flare": [KEY_I, "Illumination flare"], "seize": [KEY_K, "Seize"],
	"overwatch": [KEY_O, "Overwatch"], "auto_cb": [KEY_B, "Auto counter-battery"], "rotate": [KEY_J, "Crew rotation"],
	"los": [KEY_L, "Line of sight (hold)"], "idle": [KEY_PERIOD, "Next idle unit"], "hq": [KEY_HOME, "Jump to HQ"],
	"alert": [KEY_SPACE, "Jump to last alert"], "dosimetry": [KEY_D, "Dosimetry map"], "signals": [KEY_V, "Signal overlay"],
	"pause": [KEY_P, "Pause"],
}


static func key_for(action: String) -> Key:
	GraphicsSettings.load_settings()
	return int(GraphicsSettings.keys.get(action, ACTIONS[action][0])) as Key


## Translates a physically pressed key to the default key of the action bound to it.
static func translate(pressed: Key) -> Key:
	GraphicsSettings.load_settings()
	if GraphicsSettings.keys.is_empty():
		return pressed
	for action: String in GraphicsSettings.keys.keys():
		if int(GraphicsSettings.keys[action]) == pressed:
			return int(ACTIONS[action][0]) as Key
	# a default key whose action was moved elsewhere no longer fires it
	for action2: String in GraphicsSettings.keys.keys():
		if int(ACTIONS[action2][0]) == pressed:
			return KEY_NONE
	return pressed


static func is_held(action: String) -> bool:
	return Input.is_key_pressed(key_for(action))
