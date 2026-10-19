extends Node3D

# --- ENUMS & CONSTANTS ---
enum ObjectType { TARGET_BARREL, INDUSTRIAL_CRATE, DEFENSE_BARRIER, AMMO_BOX, EXPLOSIVE_BARREL, TARGET_DUMMY, SHIPPING_CONTAINER, CONCRETE_WALL, WATCHTOWER, GENERIC, WOOD, METAL, CONCRETE, GLASS, RUBBER, FLESH}
enum WeaponType { FISTS, AK47, REMINGTON870, SNIPER_R700 }
enum FireMode { FULL_AUTO, BURST, SEMI_AUTO }
enum GameState { MAIN_MENU, INGAME }
enum MapType { TACTICAL_SANDBOX, CQB_ARENA }
enum TimeOfDay { DAY, NIGHT }
enum WeatherType { CLEAR, CLOUDY, RAIN }
var arm_left_node: MeshInstance3D
var arm_right_node: MeshInstance3D
var anim_time: float = 0.0

enum HandAnimState { IDLE, SPRINTING, RELOADING, ADS, INSPECTING }
var current_hand_state: HandAnimState = HandAnimState.IDLE

const PORT = 7777
const CHEAT_PASSWORD = "082611"
const LOCAL_PLAYER_MODEL_LAYER: int = 1 << 1
const DEFAULT_CAMERA_RENDER_MASK: int = 0xFFFFF

# --- MENU STATE & PLAYER PREFERENCES ---
var player_username: String = ""
var show_player_model_in_menu: bool = true

# UI References
var username_input: LineEdit
var leaderboard_list: VBoxContainer
var leaderboard_data: Dictionary = {}
var ingame_leaderboard_label: Label
var join_notification_label: Label
# --- ANTI-CHEAT TRACKING & PENALTIES ---

# --- MULTIPLAYER & NETWORKING ---
var enet_peer = ENetMultiplayerPeer.new()
var local_player_id: int = 1
var players: Dictionary = {}

# --- PLAYER STATS & STATES ---
var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_drain: float = 14.0
var stamina_regen: float = 22.0
var is_dead: bool = false
var death_sequence_id: int = 0
var current_state: GameState = GameState.MAIN_MENU
var current_map_type: MapType = MapType.TACTICAL_SANDBOX
var current_time_of_day: TimeOfDay = TimeOfDay.DAY
var show_damage_indicators: bool = true
var disable_zoom: bool = false
var aim_button_down: bool = false
var current_lean: float = 0.0
var last_input_was_controller: bool = false
var controller_device_id: int = -1
var controller_look_sensitivity: float = 2.4
var controller_aim_assist_enabled: bool = true
var controller_aim_assist_strength: float = 0.22
var fog_enabled: bool = true
var rain_enabled: bool = true
var high_graphics_enabled: bool = true
var rain_particles: GPUParticles3D
var weather_cycle_enabled: bool = true
var current_weather: WeatherType = WeatherType.CLEAR
var weather_cycle_timer: float = 0.0
var weather_phase_duration: float = 55.0
var weather_cloud_opacity: float = 0.30
var weather_target_cloud_opacity: float = 0.30
var aim_move_speed_multiplier: float = 0.76
var master_volume: float = 1.0
var pending_rebind_action: StringName = &""
var rebind_buttons: Dictionary = {}
var verity_replica: Node3D
var verity_replica_time: float = 0.0

const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"sprint", &"crouch", &"lean_left", &"lean_right",
	&"fire", &"aim", &"reload", &"interact", &"drop_weapon",
	&"throw_grenade", &"weapon_next", &"weapon_previous", &"weapon_1",
	&"weapon_2", &"weapon_3", &"weapon_fists", &"inspect_weapon",
	&"fire_mode", &"flashlight", &"night_vision", &"vehicle_camera",
	&"vehicle_handbrake", &"toggle_cheats", &"pause"
]
const REMAPPABLE_ACTION_LABELS: Dictionary = {
	"move_forward": "Move Forward", "move_back": "Move Back",
	"move_left": "Move Left", "move_right": "Move Right",
	"jump": "Jump", "sprint": "Sprint", "crouch": "Crouch",
	"lean_left": "Lean Left", "lean_right": "Lean Right",
	"fire": "Fire", "aim": "Aim Down Sights", "reload": "Reload",
	"interact": "Interact / Enter or Exit Car", "drop_weapon": "Drop Weapon",
	"throw_grenade": "Throw Grenade", "weapon_next": "Next Weapon",
	"weapon_previous": "Previous Weapon", "weapon_1": "Weapon Slot 1",
	"weapon_2": "Weapon Slot 2", "weapon_3": "Weapon Slot 3",
	"weapon_fists": "Fists", "inspect_weapon": "Inspect Weapon",
	"fire_mode": "Fire Mode", "flashlight": "Flashlight",
	"night_vision": "Night Vision", "vehicle_camera": "Vehicle Camera",
	"vehicle_handbrake": "Vehicle Handbrake", "toggle_cheats": "Cheat Menu",
	"pause": "Pause Menu"
}

# --- VEHICLES / DRIVING ---
var vehicles: Array = []
var active_vehicle: VehicleBody3D = null
var is_driving: bool = false
var vehicle_hint_label: Label
var controls_help_label: Label
var controls_popup: PanelContainer
var vehicle_look_offset: float = 0.0
var driving_cam_height: float = 0.98
var max_vehicle_speed: float = 42.0
# 0 = first person (cockpit), 1 = third person (chase cam). Toggled with C while driving.
var vehicle_camera_mode: int = 0
var vehicle_cam_distance: float = 6.2

# --- CHEATS & TOGGLES ---
var cheat_unlocked: bool = false
var god_mode: bool = false
var infinite_ammo: bool = false
var super_speed: bool = false
var low_gravity: bool = false
var aimbot_enabled: bool = false
var esp_enabled: bool = false
var night_mode_enabled: bool = false
var night_vision_enabled: bool = false
var flashlight_enabled: bool = false

# --- MOVEMENT ATTRIBUTES ---
@export var walk_speed: float = 3.8
@export var sprint_speed: float = 6.2
@export var crouch_speed: float = 2.0
@export var slide_speed: float = 8.5
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.0020
@export var user_base_fov: float = 90.0
@export var aim_fov: float = 78.0
@export var sprint_fov: float = 92.0
@export var camera_fov_response: float = 12.0
@export var camera_pitch_limit_degrees: float = 88.0
@export var camera_sway_amount: float = 0.22
@export var camera_roll_limit_degrees: float = 1.0

var current_speed: float = 3.8
var is_crouching: bool = false
var is_sprinting: bool = false
var is_sliding: bool = false
var was_on_floor_last_frame: bool = true
var slide_timer: float = 0.0
var was_crouch_held: bool = false
var slide_vector: Vector2 = Vector2.ZERO

# --- IMPROVED GROUND / AIR MOVEMENT ---
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_jump_held: bool = false
@export var air_control: float = 0.35
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

var default_cam_height: float = 1.65
var crouch_cam_height: float = 0.95
var target_cam_height: float = 1.65
var target_lean: float = 0.0
var gravity: float = 14.8

# --- CQB MATCH & ROUND SYSTEM ---
var cqb_score_player: int = 0
var cqb_score_enemy: int = 0
# ============================================================
# CAMERA STATE
# ============================================================

var camera_pitch: float = 0.0

var camera_sway_position: Vector3 = Vector3.ZERO
var camera_sway_rotation: Vector3 = Vector3.ZERO

var camera_shake_offset: Vector3 = Vector3.ZERO
var camera_shake_strength: float = 0.0


# --- FIRST-PERSON WEAPON PRESENTATION / ADS ---
@export var weapon_hip_position: Vector3 = Vector3(0.16, -0.14, -0.32)
@export var weapon_ads_position: Vector3 = Vector3(0.00, -0.075, -0.54)
@export var weapon_aim_response: float = 14.0
@export var weapon_sprint_lowering: float = 0.07
@export var weapon_idle_bob_amount: float = 0.008
@export var weapon_recoil_position_scale: float = 0.35
@export var weapon_recoil_rotation_scale: float = 0.45

var ads_blend: float = 0.0
var weapon_base_position: Vector3 = Vector3(0.20, -0.18, -0.42)
var weapon_recoil_visual: Vector3 = Vector3.ZERO
var weapon_recoil_visual_rotation: Vector3 = Vector3.ZERO

# --- PROCEDURAL ANIMATION & RECOIL ---
var sway_offset: Vector2 = Vector2.ZERO
var sway_rotation: Vector3 = Vector3.ZERO
var walk_cycle: float = 0.0
var idle_breath_cycle: float = 0.0
var land_impact_spring: float = 0.0

@export var cam_recoil_snappiness: float = 18.0
@export var cam_recoil_return_speed: float = 12.0
var gun_recoil_offset: Vector3 = Vector3.ZERO
var gun_recoil_vel: Vector3 = Vector3.ZERO
var gun_rot_recoil: Vector3 = Vector3.ZERO
var gun_rot_vel: Vector3 = Vector3.ZERO

var cam_recoil_rot: Vector3 = Vector3.ZERO
var cam_recoil_vel: Vector3 = Vector3.ZERO

# ============================================================
# ADVANCED WEAPON / GRAPHICS REALISM
# ============================================================


var tac_night_mode: bool = false


var tac_environment: Environment
var tac_moon_light: DirectionalLight3D



# --- REALISM GRAPHICS / WEAPON FX ---



# --- WEAPON MECHANICS & INVENTORY ---
var inventory: Array[WeaponType] = [WeaponType.AK47, WeaponType.REMINGTON870, WeaponType.SNIPER_R700]
var active_inv_index: int = 0
var current_fire_mode: FireMode = FireMode.FULL_AUTO
var burst_count_remaining: int = 0

var weapon_ammo_map = {
	WeaponType.AK47: {"current": 30, "reserve": 180, "max_mag": 30},
	WeaponType.REMINGTON870: {"current": 7, "reserve": 42, "max_mag": 7},
	WeaponType.SNIPER_R700: {"current": 5, "reserve": 30, "max_mag": 5}
}

var is_aiming: bool = false
var is_reloading: bool = false
var is_pumping: bool = false
var is_inspecting: bool = false
var is_equipping: bool = false
var fire_cooldown: float = 0.0
var cancel_reload_requested: bool = false

# --- ATTACHMENTS ---
var flashlight_node: SpotLight3D = null

# --- PHYSICS INTERACTION ---
var held_object: RigidBody3D = null
var held_object_distance: float = 3.2
var is_rotating_object: bool = false
var object_target_rotation: Basis = Basis.IDENTITY
var camera_shake: float = 0.0

# --- RUNTIME NODE REFERENCES ---
var local_player_node: CharacterBody3D
var camera_pivot: Node3D
var camera_effect_pivot: Node3D
var player_camera: Camera3D
var weapon_rig: Node3D
var weapon_mesh_root: Node3D
var weapon_rear_iron_sight: Node3D
var weapon_front_iron_sight: Node3D
var mag_mesh_node: Node3D
var charging_handle_node: Node3D
var bolt_carrier_node: Node3D
var ejection_port_marker: Node3D
var loading_port_marker: Node3D
var muzzle_flash_marker: Node3D
var muzzle_flash_light: OmniLight3D
var muzzle_flash_mesh: MeshInstance3D
var muzzle_light_tween: Tween
var muzzle_mesh_tween: Tween
var weapon_scope_root: Node3D
var weapon_red_dot_reticle: MeshInstance3D

var world_env: WorldEnvironment
var cloud_layer: MeshInstance3D
var environment_reflection_probe: ReflectionProbe
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var moon_mesh: MeshInstance3D

# --- UI NODES ---
var main_menu_ui: Control
var pause_menu_ui: Control
var settings_menu_ui: Control
var is_game_paused: bool = false
var cheat_menu_ui: Control
var cheat_auth_panel: VBoxContainer
var cheat_content_panel: VBoxContainer
var cheat_password_input: LineEdit
var is_menu_open: bool = false
var is_cheat_menu_open: bool = false

var HUD_firemode_label: Label
var cqb_score_label: Label
var HUD_health_bar: ProgressBar
var crosshair_container: Control
var crosshair_dot: ColorRect
var crosshair_lines: Array[ColorRect] = []
var crosshair_spread: float = 8.0
var scope_overlay_ui: Control
var hitmarker_ui: TextureRect
var ip_input: LineEdit
var map_select_option: OptionButton
var time_select_option: OptionButton
var primary_weapon_option: OptionButton
var secondary_weapon_option: OptionButton
var esp_overlay_node: Control
var night_vision_overlay: ColorRect

# ============================================================
# ADVANCED BALLISTICS / PHYSICS STATE
# ============================================================


var weapon_heat_level: float = 0.0
var weapon_recoil_recovery_speed: float = 16.0

var shell_casing_count: int = 0
var max_shell_casings: int = 80


const BALLISTIC_GRAVITY := 9.81

# ============================================================
# FIRE INPUT STATE
# ============================================================

var fire_pressed_this_frame: bool = false

# ============================================================
# BALLISTIC / PHYSICS TUNING
# ============================================================

const RAGDOLL_COLLISION_LAYER: int = 1 << 5
const SHELL_CASING_COLLISION_LAYER: int = 1 << 6
const BALLISTIC_DT: float = 0.006
const BULLET_COLLISION_MASK: int = 5 | RAGDOLL_COLLISION_LAYER # World/props, hitboxes, and ragdolls

# --- PROCEDURAL TEXTURE CACHE ---
var noise_cache: Dictionary = {}


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input_actions()
	load_game_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build_main_menu()

	multiplayer.peer_connected.connect(
		_on_peer_connected
	)

	multiplayer.peer_disconnected.connect(
		_on_peer_disconnected
	)

	multiplayer.server_disconnected.connect(
		_return_to_main_menu
	)

	multiplayer.connection_failed.connect(
		_return_to_main_menu
	)

func _on_connected_to_server() -> void:
	rpc_id(1, "update_player_score", player_username, 0, 0, 0)

func report_local_score(k: int, d: int, s: int) -> void:
	if not player_username.is_empty():
		rpc_id(1, "update_player_score", player_username, k, d, s)

@rpc("any_peer", "call_local")
func net_award_kill() -> void:
	report_local_score(1, 0, 100)

func setup_input_actions(reset_bindings: bool = false) -> void:
	var add_default_bindings := reset_bindings or not InputMap.has_action(&"move_forward") or InputMap.action_get_events(&"move_forward").is_empty()
	var all_actions: Array[StringName] = [
		&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"crouch",
		&"lean_left", &"lean_right", &"fire", &"aim", &"reload", &"interact", &"drop_weapon",
		&"throw_grenade", &"weapon_next", &"weapon_previous", &"pause", &"toggle_cheats", &"inspect_weapon",
		&"fire_mode", &"weapon_1", &"weapon_2", &"weapon_3", &"weapon_fists", &"flashlight",
		&"night_vision", &"vehicle_camera", &"vehicle_handbrake"
	]
	for action in all_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.20)
		if reset_bindings:
			InputMap.action_erase_events(action)

	if not add_default_bindings:
		# Preserve saved remaps, but never leave the lean actions unmapped.
		if InputMap.action_get_events(&"lean_left").is_empty():
			_add_key_binding(&"lean_left", KEY_Q)
		if InputMap.action_get_events(&"lean_right").is_empty():
			_add_key_binding(&"lean_right", KEY_E)
		return

	_add_key_binding(&"move_forward", KEY_W)
	_add_key_binding(&"move_back", KEY_S)
	_add_key_binding(&"move_left", KEY_A)
	_add_key_binding(&"move_right", KEY_D)
	_add_key_binding(&"jump", KEY_SPACE)
	_add_key_binding(&"sprint", KEY_SHIFT)
	_add_key_binding(&"crouch", KEY_CTRL)
	_add_key_binding(&"crouch", KEY_C)
	_add_key_binding(&"lean_left", KEY_Q)
	_add_key_binding(&"lean_right", KEY_E)
	_add_key_binding(&"pause", KEY_TAB)
	_add_key_binding(&"pause", KEY_ESCAPE)
	_add_key_binding(&"toggle_cheats", KEY_BACKSLASH)
	_add_key_binding(&"throw_grenade", KEY_G)
	_add_key_binding(&"drop_weapon", KEY_Z)
	_add_key_binding(&"inspect_weapon", KEY_H)
	_add_key_binding(&"fire_mode", KEY_V)
	_add_key_binding(&"weapon_1", KEY_1)
	_add_key_binding(&"weapon_2", KEY_2)
	_add_key_binding(&"weapon_3", KEY_3)
	_add_key_binding(&"weapon_fists", KEY_4)
	_add_key_binding(&"flashlight", KEY_L)
	_add_key_binding(&"night_vision", KEY_N)
	_add_key_binding(&"vehicle_camera", KEY_C)
	_add_key_binding(&"interact", KEY_F)
	_add_key_binding(&"reload", KEY_R)
	_add_key_binding(&"vehicle_handbrake", KEY_SPACE)

	_add_mouse_binding(&"fire", MOUSE_BUTTON_LEFT)
	_add_mouse_binding(&"aim", MOUSE_BUTTON_RIGHT)
	_add_axis_binding(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis_binding(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis_binding(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis_binding(&"move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis_binding(&"aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_axis_binding(&"fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_add_joy_button_binding(&"jump", JOY_BUTTON_A)
	_add_joy_button_binding(&"crouch", JOY_BUTTON_B)
	_add_joy_button_binding(&"reload", JOY_BUTTON_X)
	_add_joy_button_binding(&"interact", JOY_BUTTON_Y)
	_add_joy_button_binding(&"sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button_binding(&"throw_grenade", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button_binding(&"weapon_next", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button_binding(&"weapon_previous", JOY_BUTTON_BACK)
	_add_joy_button_binding(&"lean_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button_binding(&"lean_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button_binding(&"drop_weapon", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button_binding(&"inspect_weapon", JOY_BUTTON_DPAD_UP)
	_add_joy_button_binding(&"pause", JOY_BUTTON_START)
	_add_joy_button_binding(&"vehicle_camera", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button_binding(&"vehicle_handbrake", JOY_BUTTON_B)


func _add_key_binding(action: StringName, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _add_mouse_binding(action: StringName, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_button_binding(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_axis_binding(action: StringName, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


func load_game_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://sandbox_game_settings.cfg") != OK:
		return
	user_base_fov = clampf(float(config.get_value("game", "fov", user_base_fov)), 60.0, 120.0)
	mouse_sensitivity = clampf(float(config.get_value("game", "mouse_sensitivity", mouse_sensitivity)), 0.0005, 0.008)
	controller_look_sensitivity = clampf(float(config.get_value("game", "controller_look_sensitivity", controller_look_sensitivity)), 0.5, 5.0)
	controller_aim_assist_enabled = bool(config.get_value("game", "controller_aim_assist", controller_aim_assist_enabled))
	controller_aim_assist_strength = clampf(float(config.get_value("game", "controller_aim_assist_strength", controller_aim_assist_strength)), 0.0, 0.35)
	fog_enabled = bool(config.get_value("graphics", "fog_enabled", fog_enabled))
	rain_enabled = bool(config.get_value("graphics", "rain_enabled", rain_enabled))
	high_graphics_enabled = bool(config.get_value("graphics", "high_graphics", high_graphics_enabled))
	weather_cycle_enabled = bool(config.get_value("graphics", "weather_cycle", weather_cycle_enabled))
	aim_move_speed_multiplier = clampf(float(config.get_value("game", "aim_move_speed", aim_move_speed_multiplier)), 0.4, 1.0)
	show_damage_indicators = bool(config.get_value("game", "damage_numbers", show_damage_indicators))
	show_player_model_in_menu = bool(config.get_value("game", "show_player_model_in_menu", show_player_model_in_menu))
	disable_zoom = bool(config.get_value("game", "disable_zoom", disable_zoom))
	master_volume = clampf(float(config.get_value("game", "master_volume", master_volume)), 0.0, 1.0)
	var fullscreen := bool(config.get_value("game", "fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_master_volume(master_volume)

	for action in REMAPPABLE_ACTIONS:
		var saved_events: Variant = config.get_value("controls", String(action), null)
		if saved_events is Array and not saved_events.is_empty():
			InputMap.action_erase_events(action)
			for record in saved_events:
				if record is Dictionary:
					var event := _deserialize_input_event(record)
					if event != null:
						InputMap.action_add_event(action, event)


func save_game_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "fov", user_base_fov)
	config.set_value("game", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("game", "controller_look_sensitivity", controller_look_sensitivity)
	config.set_value("game", "controller_aim_assist", controller_aim_assist_enabled)
	config.set_value("game", "controller_aim_assist_strength", controller_aim_assist_strength)
	config.set_value("graphics", "fog_enabled", fog_enabled)
	config.set_value("graphics", "rain_enabled", rain_enabled)
	config.set_value("graphics", "high_graphics", high_graphics_enabled)
	config.set_value("graphics", "weather_cycle", weather_cycle_enabled)
	config.set_value("game", "aim_move_speed", aim_move_speed_multiplier)
	config.set_value("game", "damage_numbers", show_damage_indicators)
	config.set_value("game", "show_player_model_in_menu", show_player_model_in_menu)
	config.set_value("game", "disable_zoom", disable_zoom)
	config.set_value("game", "master_volume", master_volume)
	config.set_value("game", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	for action in REMAPPABLE_ACTIONS:
		var serialized_events: Array[Dictionary] = []
		for event in InputMap.action_get_events(action):
			var record := _serialize_input_event(event)
			if not record.is_empty():
				serialized_events.append(record)
		config.set_value("controls", String(action), serialized_events)
	var error := config.save("user://sandbox_game_settings.cfg")
	if error != OK:
		push_warning("Could not save game settings: " + str(error))


func apply_graphics_settings() -> void:
	if not is_instance_valid(tac_environment):
		return
	tac_environment.fog_enabled = fog_enabled
	tac_environment.set("volumetric_fog_enabled", fog_enabled)
	tac_environment.glow_enabled = high_graphics_enabled
	tac_environment.ssao_enabled = high_graphics_enabled
	tac_environment.ssil_enabled = high_graphics_enabled
	tac_environment.ssr_enabled = high_graphics_enabled
	if high_graphics_enabled:
		tac_environment.ssr_max_steps = 64
		tac_environment.ssr_fade_in = 0.08
		tac_environment.ssr_fade_out = 2.4
		tac_environment.ssr_depth_tolerance = 0.12


func add_graphics_settings(container: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "GRAPHICS & WEATHER"
	heading.add_theme_font_size_override("font_size", 20)
	container.add_child(heading)
	var quality_check := CheckBox.new()
	quality_check.text = "High Graphics (Bloom, Ambient Occlusion, Reflections)"
	quality_check.button_pressed = high_graphics_enabled
	quality_check.toggled.connect(func(enabled: bool):
		high_graphics_enabled = enabled
		apply_graphics_settings()
		save_game_settings()
	)
	container.add_child(quality_check)
	var fog_check := CheckBox.new()
	fog_check.text = "Enable Fog"
	fog_check.button_pressed = fog_enabled
	fog_check.toggled.connect(func(enabled: bool):
		fog_enabled = enabled
		apply_graphics_settings()
		save_game_settings()
	)
	container.add_child(fog_check)
	var rain_check := CheckBox.new()
	rain_check.text = "Enable Rain and Raindrops"
	rain_check.button_pressed = rain_enabled
	rain_check.toggled.connect(func(enabled: bool):
		rain_enabled = enabled
		update_rain_effect()
		save_game_settings()
	)
	container.add_child(rain_check)
	var weather_check := CheckBox.new()
	weather_check.text = "Automatic Clear / Cloud / Rain Cycle"
	weather_check.button_pressed = weather_cycle_enabled
	weather_check.toggled.connect(func(enabled: bool):
		weather_cycle_enabled = enabled
		weather_cycle_timer = 0.0
		save_game_settings()
	)
	container.add_child(weather_check)


func update_rain_effect() -> void:
	if not rain_enabled or current_weather != WeatherType.RAIN or current_state != GameState.INGAME or not is_instance_valid(local_player_node):
		if is_instance_valid(rain_particles):
			rain_particles.queue_free()
		rain_particles = null
		return
	if not is_instance_valid(rain_particles):
		rain_particles = GPUParticles3D.new()
		rain_particles.name = "RainAndRaindrops"
		rain_particles.amount = 650
		rain_particles.lifetime = 0.85
		rain_particles.one_shot = false
		rain_particles.explosiveness = 0.0
		rain_particles.local_coords = false
		rain_particles.process_mode = Node.PROCESS_MODE_PAUSABLE
		var particle_process := ParticleProcessMaterial.new()
		particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		particle_process.emission_box_extents = Vector3(17.0, 8.0, 17.0)
		particle_process.direction = Vector3(0.0, -1.0, 0.0)
		particle_process.spread = 4.0
		particle_process.initial_velocity_min = 20.0
		particle_process.initial_velocity_max = 27.0
		particle_process.gravity = Vector3(0.0, -2.0, 0.0)
		particle_process.scale_min = 1.0
		particle_process.scale_max = 1.35
		rain_particles.process_material = particle_process
		var drop_mesh := BoxMesh.new()
		drop_mesh.size = Vector3(0.008, 0.28, 0.008)
		var drop_material := StandardMaterial3D.new()
		drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		drop_material.albedo_color = Color(0.62, 0.76, 0.92, 0.52)
		drop_material.emission_enabled = true
		drop_material.emission = Color(0.20, 0.32, 0.48)
		drop_material.emission_energy_multiplier = 0.35
		drop_mesh.material = drop_material
		rain_particles.draw_pass_1 = drop_mesh
		rain_particles.visibility_aabb = AABB(Vector3(-20.0, -15.0, -20.0), Vector3(40.0, 32.0, 40.0))
		add_child(rain_particles)
		rain_particles.emitting = true
	rain_particles.global_position = local_player_node.global_position + Vector3(0.0, 8.0, 0.0)


func setup_cloud_layer() -> void:
	if not is_instance_valid(cloud_layer):
		cloud_layer = MeshInstance3D.new()
		cloud_layer.name = "ProceduralCloudLayer"
		var cloud_plane := PlaneMesh.new()
		cloud_plane.size = Vector2(5000.0, 5000.0)
		cloud_layer.mesh = cloud_plane
		cloud_layer.position = Vector3(0.0, 130.0, 0.0)
		cloud_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud_layer.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var cloud_shader := Shader.new()
		cloud_shader.code = """
		shader_type spatial;
		render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
		uniform vec4 cloud_tint : source_color = vec4(0.94, 0.97, 1.0, 0.78);
		varying vec3 world_position;

		float cloud_hash(vec2 p) {
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}
		float cloud_noise(vec2 p) {
			vec2 cell = floor(p);
			vec2 local = fract(p);
			local = local * local * (3.0 - 2.0 * local);
			return mix(mix(cloud_hash(cell), cloud_hash(cell + vec2(1.0, 0.0)), local.x),
				mix(cloud_hash(cell + vec2(0.0, 1.0)), cloud_hash(cell + vec2(1.0, 1.0)), local.x), local.y);
		}
		float cloud_fbm(vec2 p) {
			float value = 0.0;
			float amplitude = 0.5;
			for (int i = 0; i < 5; i++) {
				value += cloud_noise(p) * amplitude;
				p = p * 2.03 + vec2(17.1, 9.2);
				amplitude *= 0.5;
			}
			return value;
		}
		void vertex() {
			world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		}
		void fragment() {
			vec2 drift = vec2(TIME * 0.012, TIME * 0.004);
			vec2 coords = world_position.xz * 0.0021;
			float broad = cloud_fbm(coords * 0.72 + drift);
			float detail = cloud_fbm(coords * 1.65 - drift * 0.58);
			float density = broad * 0.78 + detail * 0.22;
			float cloud_shape = smoothstep(0.48, 0.66, density);
			float edge_softening = smoothstep(0.22, 0.72, detail);
			ALBEDO = cloud_tint.rgb * mix(0.86, 1.08, detail);
			ALPHA = cloud_shape * edge_softening * cloud_tint.a;
		}
		"""
		var cloud_material := ShaderMaterial.new()
		cloud_material.shader = cloud_shader
		cloud_layer.material_override = cloud_material
		add_child(cloud_layer)
	var current_cloud_material := cloud_layer.material_override as ShaderMaterial
	if is_instance_valid(current_cloud_material):
		current_cloud_material.set_shader_parameter(
			"cloud_tint",
			Color(0.36, 0.43, 0.60, weather_cloud_opacity) if tac_night_mode else Color(0.94, 0.97, 1.0, weather_cloud_opacity)
		)


func setup_reflection_probe() -> void:
	if is_instance_valid(environment_reflection_probe):
		environment_reflection_probe.queue_free()
	var probe := ReflectionProbe.new()
	probe.name = "WorldReflectionProbe"
	probe.position = Vector3(0.0, 8.0, 0.0)
	probe.size = Vector3(410.0, 80.0, 410.0) if current_map_type != MapType.CQB_ARENA else Vector3(210.0, 60.0, 210.0)
	probe.max_distance = 260.0 if current_map_type != MapType.CQB_ARENA else 140.0
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	environment_reflection_probe = probe


func set_weather_state(weather: WeatherType) -> void:
	current_weather = weather
	var light_multiplier := 1.0
	var ambient_multiplier := 1.0
	var fog_multiplier := 1.0
	match current_weather:
		WeatherType.CLEAR:
			weather_target_cloud_opacity = 0.24
		WeatherType.CLOUDY:
			weather_target_cloud_opacity = 0.62
			light_multiplier = 0.84
			ambient_multiplier = 0.94
			fog_multiplier = 1.08
		WeatherType.RAIN:
			weather_target_cloud_opacity = 0.88
			light_multiplier = 0.62
			ambient_multiplier = 0.86
			fog_multiplier = 1.45

	if is_instance_valid(sun_light) and not tac_night_mode:
		sun_light.light_energy = 1.30 * light_multiplier
		if current_weather == WeatherType.RAIN:
			sun_light.light_color = Color(0.70, 0.79, 0.94)
		elif current_weather == WeatherType.CLOUDY:
			sun_light.light_color = Color(0.88, 0.92, 1.0)
		else:
			sun_light.light_color = Color(1.0, 0.91, 0.78)
	if is_instance_valid(tac_environment):
		tac_environment.ambient_light_energy = (0.18 if tac_night_mode else 0.72) * ambient_multiplier
		tac_environment.fog_density = (0.016 if tac_night_mode else 0.007) * fog_multiplier
	update_rain_effect()


func update_weather_cycle(delta: float) -> void:
	if weather_cycle_enabled and not is_game_paused and not is_menu_open:
		weather_cycle_timer += delta
		if weather_cycle_timer >= weather_phase_duration:
			weather_cycle_timer = fposmod(weather_cycle_timer, weather_phase_duration)
			match current_weather:
				WeatherType.CLEAR:
					set_weather_state(WeatherType.CLOUDY)
				WeatherType.CLOUDY:
					set_weather_state(WeatherType.RAIN)
				WeatherType.RAIN:
					set_weather_state(WeatherType.CLEAR)

	weather_cloud_opacity = lerpf(
		weather_cloud_opacity,
		weather_target_cloud_opacity,
		1.0 - exp(-0.45 * delta)
	)
	if is_instance_valid(cloud_layer):
		var cloud_material := cloud_layer.material_override as ShaderMaterial
		if is_instance_valid(cloud_material):
			var tint := Color(0.36, 0.43, 0.60, weather_cloud_opacity) if tac_night_mode else Color(0.94, 0.97, 1.0, weather_cloud_opacity)
			cloud_material.set_shader_parameter("cloud_tint", tint)

func _apply_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, -80.0 if master_volume <= 0.0001 else linear_to_db(master_volume))


func _serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {"type": "key", "physical_keycode": int(key_event.physical_keycode), "keycode": int(key_event.keycode)}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {"type": "mouse_button", "button_index": int(mouse_event.button_index)}
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return {"type": "joy_button", "button_index": int(button_event.button_index)}
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return {"type": "joy_motion", "axis": int(motion_event.axis), "axis_value": float(motion_event.axis_value)}
	return {}


func _deserialize_input_event(record: Dictionary) -> InputEvent:
	match String(record.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(record.get("physical_keycode", 0)) as Key
			key_event.keycode = int(record.get("keycode", 0)) as Key
			return key_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = int(record.get("button_index", 0)) as MouseButton
			return mouse_event
		"joy_button":
			var button_event := InputEventJoypadButton.new()
			button_event.device = -1
			button_event.button_index = int(record.get("button_index", 0)) as JoyButton
			return button_event
		"joy_motion":
			var motion_event := InputEventJoypadMotion.new()
			motion_event.device = -1
			motion_event.axis = int(record.get("axis", 0)) as JoyAxis
			motion_event.axis_value = float(record.get("axis_value", 1.0))
			return motion_event
	return null


func _input_binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	var primary_bindings: Array[String] = []
	var controller_binding := ""
	for event in events:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			controller_binding = _format_input_binding(event)
		elif primary_bindings.size() < 2:
			primary_bindings.append(_format_input_binding(event))
	var summary := " + ".join(primary_bindings)
	if not controller_binding.is_empty():
		if not summary.is_empty():
			summary += " | "
		summary += controller_binding
	return summary if not summary.is_empty() else "Unbound"


func _format_input_binding(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var key_label := OS.get_keycode_string(key_event.physical_keycode)
		if key_label.is_empty():
			key_label = OS.get_keycode_string(key_event.keycode)
		return key_label if not key_label.is_empty() else event.as_text()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "Mouse " + str(mouse_event.button_index)
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		var button_labels := {
			JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
			JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
			JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
			JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right"
		}
		return "Pad " + String(button_labels.get(joy_event.button_index, "Button " + str(joy_event.button_index)))
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		var axis_labels := {
			JOY_AXIS_LEFT_X: "Left Stick X", JOY_AXIS_LEFT_Y: "Left Stick Y",
			JOY_AXIS_RIGHT_X: "Right Stick X", JOY_AXIS_RIGHT_Y: "Right Stick Y",
			JOY_AXIS_TRIGGER_LEFT: "Left Trigger", JOY_AXIS_TRIGGER_RIGHT: "Right Trigger"
		}
		var axis_name: String = axis_labels.get(motion_event.axis, "Axis " + str(motion_event.axis))
		return "Pad " + axis_name + ("+" if motion_event.axis_value > 0.0 else "-")
	return event.as_text()


func _start_rebinding(action: StringName, button: Button) -> void:
	pending_rebind_action = action
	button.text = "Press a key / mouse / controller input…"
	button.grab_focus()


func _on_rebind_capture_gui_input(event: InputEvent, action: StringName, button: Button) -> void:
	if pending_rebind_action != action:
		return
	_capture_rebind_event(event, action, button)


func _capture_rebind_event(event: InputEvent, action: StringName, button: Button) -> void:
	var binding: InputEvent
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.is_echo():
			return
		if key_event.physical_keycode == KEY_ESCAPE:
			pending_rebind_action = &""
			button.text = _input_binding_text(action)
			return
		var key_binding := InputEventKey.new()
		key_binding.physical_keycode = key_event.physical_keycode
		key_binding.keycode = key_event.keycode
		binding = key_binding
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index > MOUSE_BUTTON_MIDDLE:
			return
		var mouse_binding := InputEventMouseButton.new()
		mouse_binding.button_index = mouse_event.button_index
		binding = mouse_binding
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		if not joy_event.pressed:
			return
		var joy_binding := InputEventJoypadButton.new()
		joy_binding.device = -1
		joy_binding.button_index = joy_event.button_index
		binding = joy_binding
	elif event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) < 0.70:
			return
		var axis_binding := InputEventJoypadMotion.new()
		axis_binding.device = -1
		axis_binding.axis = motion_event.axis
		axis_binding.axis_value = signf(motion_event.axis_value)
		binding = axis_binding
	else:
		return

	var replace_type := ""
	if binding is InputEventKey:
		replace_type = "key"
	elif binding is InputEventMouseButton:
		replace_type = "mouse"
	elif binding is InputEventJoypadButton:
		replace_type = "joy_button"
	elif binding is InputEventJoypadMotion:
		replace_type = "joy_motion"
	for old_binding in InputMap.action_get_events(action):
		if (replace_type == "key" and old_binding is InputEventKey) \
			or (replace_type == "mouse" and old_binding is InputEventMouseButton) \
			or (replace_type == "joy_button" and old_binding is InputEventJoypadButton) \
			or (replace_type == "joy_motion" and old_binding is InputEventJoypadMotion):
			InputMap.action_erase_event(action, old_binding)
	InputMap.action_add_event(action, binding)
	pending_rebind_action = &""
	save_game_settings()
	button.text = _input_binding_text(action)
	update_controls_help()
	get_viewport().set_input_as_handled()


func _restore_default_controls() -> void:
	setup_input_actions(true)
	pending_rebind_action = &""
	for action in REMAPPABLE_ACTIONS:
		if rebind_buttons.has(action) and is_instance_valid(rebind_buttons[action]):
			(rebind_buttons[action] as Button).text = _input_binding_text(action)
	save_game_settings()
	update_controls_help()


func add_rebind_controls(container: VBoxContainer) -> void:
	var separator := HSeparator.new()
	container.add_child(separator)
	var heading := Label.new()
	heading.text = "CONTROLS & CONTROLLER"
	heading.add_theme_font_size_override("font_size", 22)
	container.add_child(heading)

	var controller_note := Label.new()
	controller_note.text = "Gamepads work automatically. Controller-only aim assist and aim slowdown activate while ADS in the 1v1 Arena."
	controller_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(controller_note)

	var controller_label := Label.new()
	controller_label.text = "Controller Look Sensitivity: " + str(snappedf(controller_look_sensitivity, 0.1))
	container.add_child(controller_label)
	var controller_slider := HSlider.new()
	controller_slider.min_value = 0.5
	controller_slider.max_value = 5.0
	controller_slider.step = 0.1
	controller_slider.value = controller_look_sensitivity
	controller_slider.custom_minimum_size = Vector2(320, 28)
	controller_slider.value_changed.connect(func(value: float):
		controller_look_sensitivity = value
		controller_label.text = "Controller Look Sensitivity: " + str(snappedf(value, 0.1))
		save_game_settings()
	)
	container.add_child(controller_slider)

	var assist_check := CheckBox.new()
	assist_check.text = "Controller Aim Assist (1v1 Arena only)"
	assist_check.button_pressed = controller_aim_assist_enabled
	assist_check.toggled.connect(func(enabled: bool):
		controller_aim_assist_enabled = enabled
		save_game_settings()
	)
	container.add_child(assist_check)

	var assist_label := Label.new()
	assist_label.text = "Aim Assist Strength: " + str(int(controller_aim_assist_strength * 100.0)) + "%"
	container.add_child(assist_label)
	var assist_slider := HSlider.new()
	assist_slider.min_value = 0.0
	assist_slider.max_value = 0.35
	assist_slider.step = 0.01
	assist_slider.value = controller_aim_assist_strength
	assist_slider.custom_minimum_size = Vector2(320, 28)
	assist_slider.value_changed.connect(func(value: float):
		controller_aim_assist_strength = value
		assist_label.text = "Aim Assist Strength: " + str(int(value * 100.0)) + "%"
		save_game_settings()
	)
	container.add_child(assist_slider)

	var control_grid := GridContainer.new()
	control_grid.columns = 2
	control_grid.add_theme_constant_override("h_separation", 12)
	control_grid.add_theme_constant_override("v_separation", 5)
	container.add_child(control_grid)
	rebind_buttons.clear()
	for action in REMAPPABLE_ACTIONS:
		var action_label := Label.new()
		action_label.text = String(REMAPPABLE_ACTION_LABELS.get(String(action), String(action)))
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control_grid.add_child(action_label)
		var bind_button := Button.new()
		bind_button.text = _input_binding_text(action)
		bind_button.custom_minimum_size = Vector2(230, 34)
		bind_button.pressed.connect(_start_rebinding.bind(action, bind_button))
		bind_button.gui_input.connect(_on_rebind_capture_gui_input.bind(action, bind_button))
		control_grid.add_child(bind_button)
		rebind_buttons[action] = bind_button

	var defaults_button := Button.new()
	defaults_button.text = "Restore Default Controls"
	defaults_button.pressed.connect(_restore_default_controls)
	container.add_child(defaults_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		aim_button_down = false
		is_aiming = false
		is_rotating_object = false
		fire_pressed_this_frame = false

		if is_instance_valid(camera_effect_pivot):
			camera_effect_pivot.position = Vector3.ZERO
			camera_effect_pivot.rotation = Vector3.ZERO


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	if current_state != GameState.INGAME:
		return

	# Capture raw inputs before pause/actions can consume them. This keeps
	# rebinding working for Escape, controller buttons, and stick axes.
	if pending_rebind_action != &"" and rebind_buttons.has(pending_rebind_action):
		var capture_button := rebind_buttons[pending_rebind_action] as Button
		if is_instance_valid(capture_button) and not event is InputEventMouseMotion:
			_capture_rebind_event(event, pending_rebind_action, capture_button)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_input_was_controller = true
		controller_device_id = event.device
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.is_echo():
			last_input_was_controller = false
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		last_input_was_controller = false

	var is_echo := event is InputEventKey and (event as InputEventKey).is_echo()
	var pause_pressed: bool = event.is_action_pressed("pause") and not is_echo
	var cancel_pressed: bool = event.is_action_pressed("ui_cancel") and not is_echo

	if pause_pressed:
		get_viewport().set_input_as_handled()
		if is_cheat_menu_open:
			toggle_cheat_menu()
		elif is_instance_valid(settings_menu_ui) and settings_menu_ui.visible:
			close_settings_menu()
		else:
			toggle_pause_menu()
		return

	if is_dead and not cancel_pressed:
		return

	if cancel_pressed:
		get_viewport().set_input_as_handled()
		if is_cheat_menu_open:
			toggle_cheat_menu()
		elif is_instance_valid(settings_menu_ui) and settings_menu_ui.visible:
			close_settings_menu()
		elif is_menu_open or (is_instance_valid(pause_menu_ui) and pause_menu_ui.visible):
			toggle_pause_menu()
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if is_menu_open or is_cheat_menu_open or (is_instance_valid(settings_menu_ui) and settings_menu_ui.visible):
		fire_pressed_this_frame = false
		return

	if event.is_action_pressed("toggle_cheats") and not is_echo:
		if not is_menu_open:
			toggle_cheat_menu()
		return
	if event.is_action_pressed("throw_grenade") and not is_echo:
		throw_tactical_grenade()
		return
	if event.is_action_pressed("drop_weapon") and not is_echo:
		drop_current_weapon_to_ground()
		return
	if event.is_action_pressed("inspect_weapon") and not is_echo:
		trigger_inspect_animation()
		return
	if event.is_action_pressed("fire_mode") and not is_echo:
		toggle_fire_mode()
		return
	if event.is_action_pressed("weapon_1") and not is_echo:
		switch_weapon_slot(0)
		return
	if event.is_action_pressed("weapon_2") and not is_echo:
		switch_weapon_slot(1)
		return
	if event.is_action_pressed("weapon_3") and not is_echo:
		switch_weapon_slot(2)
		return
	if event.is_action_pressed("weapon_fists") and not is_echo:
		switch_weapon_slot(-1)
		return
	if event.is_action_pressed("weapon_next") and not is_echo:
		cycle_weapon_slot(1)
		return
	if event.is_action_pressed("weapon_previous") and not is_echo:
		cycle_weapon_slot(-1)
		return
	if event.is_action_pressed("flashlight") and not is_echo:
		toggle_flashlight()
		return
	if event.is_action_pressed("night_vision") and not is_echo:
		toggle_night_vision()
		return
	if event.is_action_pressed("vehicle_camera") and not is_echo and is_driving:
		vehicle_camera_mode = 0 if vehicle_camera_mode == 1 else 1
		return
	if event.is_action_pressed("interact") and not is_echo:
		if is_driving:
			exit_vehicle()
		elif try_enter_nearby_vehicle():
			pass
		elif is_instance_valid(held_object):
			drop_held_object()
		else:
			attempt_interact_or_pickup()
		return
	if event.is_action_pressed("reload") and not is_echo:
		execute_weapon_reload()
		return

	if event.is_action_pressed("fire"):
		if event is InputEventMouseButton and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			fire_pressed_this_frame = false
			return
		fire_pressed_this_frame = true

	if event.is_action_pressed("aim"):
		if event is InputEventMouseButton and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
		if is_instance_valid(held_object):
			is_rotating_object = true
		else:
			aim_button_down = true
			if is_reloading:
				cancel_reload_requested = true
	elif event.is_action_released("aim"):
		is_rotating_object = false
		aim_button_down = false
		is_aiming = false

	if event is InputEventMouseButton and is_instance_valid(held_object):
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			held_object_distance = clampf(held_object_distance + 0.3, 1.5, 10.0)
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			held_object_distance = clampf(held_object_distance - 0.3, 1.5, 10.0)
			return

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if is_rotating_object and is_instance_valid(held_object) and is_instance_valid(player_camera):
			var axis_y := player_camera.global_transform.basis.y
			var axis_x := player_camera.global_transform.basis.x
			object_target_rotation = object_target_rotation.rotated(axis_y, -mouse_motion.screen_relative.x * 0.005)
			object_target_rotation = object_target_rotation.rotated(axis_x, -mouse_motion.screen_relative.y * 0.005)
			object_target_rotation = object_target_rotation.orthonormalized()
			return

		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or not is_instance_valid(local_player_node) or not is_instance_valid(camera_pivot):
			return

		if is_driving:
			vehicle_look_offset = wrapf(vehicle_look_offset - mouse_motion.screen_relative.x * mouse_sensitivity, -PI, PI)
		else:
			local_player_node.rotation.y -= mouse_motion.screen_relative.x * mouse_sensitivity
		camera_pitch -= mouse_motion.screen_relative.y * mouse_sensitivity
		camera_pitch = clampf(camera_pitch, deg_to_rad(-camera_pitch_limit_degrees), deg_to_rad(camera_pitch_limit_degrees))

		var sway_mult: float = 0.08 if is_aiming else 1.0
		sway_offset.x = clampf(sway_offset.x - mouse_motion.screen_relative.x * 0.0004 * sway_mult, -0.07, 0.07)
		sway_offset.y = clampf(sway_offset.y - mouse_motion.screen_relative.y * 0.0004 * sway_mult, -0.07, 0.07)
		sway_rotation.z = clampf(sway_rotation.z + mouse_motion.screen_relative.x * 0.0008 * sway_mult, -0.1, 0.1)
		sway_rotation.x = clampf(sway_rotation.x - mouse_motion.screen_relative.y * 0.0008 * sway_mult, -0.1, 0.1)


# ============================================================
# PHYSICS / MOVEMENT / AIM / FIRING
# ============================================================

func _physics_process(delta: float) -> void:
	if get_tree().paused and is_game_paused:
		return
	if current_state != GameState.INGAME:
		return

	process_out_of_bounds_cleanup()

	if not is_instance_valid(local_player_node):
		return

	if is_dead:
		return

	if is_menu_open or is_cheat_menu_open:
		fire_pressed_this_frame = false
		return

	# ============================================================
	# VEHICLE DRIVING (replaces on-foot movement while seated)
	# ============================================================

	var lean_input := (1.0 if Input.is_action_pressed("lean_right") else 0.0) - (1.0 if Input.is_action_pressed("lean_left") else 0.0)
	target_lean = 0.0 if is_driving else 11.0 * lean_input

	if is_driving:
		update_vehicle_driving(delta)
		update_hud_display()
		if fire_cooldown > 0.0:
			fire_cooldown = maxf(fire_cooldown - delta, 0.0)
		rpc(
			"sync_player_transform",
			local_player_id,
			local_player_node.global_position,
			local_player_node.rotation.y,
			camera_pitch,
			0.0,
			true
		)
		return

	# ============================================================
	# PLAYER MOVEMENT / GRAVITY
	# ============================================================

	var player_velocity: Vector3 = (
		local_player_node.velocity
	)

	# ============================================================
	# MOVEMENT INPUT
	# ============================================================

	var move_input: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)

	var move_direction: Vector3 = Vector3.ZERO

	if move_input.length_squared() > 0.0001:
		var forward_direction: Vector3 = (
			-local_player_node.global_transform.basis.z
		)

		var right_direction: Vector3 = (
			local_player_node.global_transform.basis.x
		)

		move_direction = (
			right_direction * move_input.x
			+ forward_direction * -move_input.y
		).normalized()

	# ============================================================
	# CROUCH / SLIDE
	# ============================================================

	var crouch_held := Input.is_action_pressed("crouch")
	var slide_started := (
		crouch_held
		and not was_crouch_held
		and Input.is_action_pressed("sprint")
		and local_player_node.is_on_floor()
		and move_direction.length_squared() > 0.0001
		and stamina >= 10.0
	)
	if slide_started:
		is_sliding = true
		slide_timer = 0.62
		slide_vector = Vector2(move_direction.x, move_direction.z).normalized()
		stamina = maxf(stamina - 10.0, 0.0)
	was_crouch_held = crouch_held

	if is_sliding:
		slide_timer = maxf(slide_timer - delta, 0.0)
		if slide_timer <= 0.0 or not local_player_node.is_on_floor():
			is_sliding = false
		else:
			var steer_direction := Vector2(move_direction.x, move_direction.z)
			if steer_direction.length_squared() > 0.0001:
				slide_vector = slide_vector.lerp(steer_direction.normalized(), clampf(delta * 1.8, 0.0, 1.0)).normalized()

	is_crouching = (crouch_held or is_sliding) and not is_driving

	# ============================================================
	# SPRINT
	# ============================================================

	var wants_sprint: bool = (
		Input.is_action_pressed("sprint")
		and not aim_button_down
		and move_input.length_squared() > 0.0001
		and not is_crouching
		and not is_sliding
		and stamina > 0.0
	)

	is_sprinting = wants_sprint

	if is_sliding:
		current_speed = slide_speed
	elif is_aiming or aim_button_down:
		current_speed = walk_speed * aim_move_speed_multiplier
	elif super_speed:
		current_speed = sprint_speed * 1.75
	elif is_sprinting:
		current_speed = sprint_speed
	elif is_crouching:
		current_speed = crouch_speed
	else:
		current_speed = walk_speed

	# ============================================================
	# HORIZONTAL MOVEMENT (ground accel vs. reduced air control)
	# ============================================================

	var target_horizontal_velocity: Vector3 = move_direction * current_speed
	if is_sliding:
		target_horizontal_velocity = Vector3(slide_vector.x, 0.0, slide_vector.y) * slide_speed

	var on_floor: bool = local_player_node.is_on_floor()
	var accel_factor: float = 1.0 if on_floor else air_control
	var accel_rate: float = 28.0 * accel_factor
	var decel_rate: float = 24.0 * accel_factor

	if move_direction.length_squared() > 0.0001:
		player_velocity.x = move_toward(
			player_velocity.x,
			target_horizontal_velocity.x,
			accel_rate * delta
		)

		player_velocity.z = move_toward(
			player_velocity.z,
			target_horizontal_velocity.z,
			accel_rate * delta
		)
	else:
		player_velocity.x = move_toward(
			player_velocity.x,
			0.0,
			decel_rate * delta
		)

		player_velocity.z = move_toward(
			player_velocity.z,
			0.0,
			decel_rate * delta
		)

	# ============================================================
	# GRAVITY  (+ coyote time bookkeeping)
	# ============================================================

	var on_floor_now_pre: bool = local_player_node.is_on_floor()

	var current_gravity: float = gravity

	if low_gravity:
		current_gravity *= 0.35

	if on_floor_now_pre:
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

		# Snappier fall arc than rise arc.
		if player_velocity.y < 0.0:
			current_gravity *= 1.35

		player_velocity.y -= (
			current_gravity * delta
		)

	if on_floor_now_pre and player_velocity.y < 0.0:
		player_velocity.y = -0.5

	# ============================================================
	# JUMP  (input buffering + coyote time)
	# ============================================================

	var jump_held: bool = Input.is_action_pressed("jump")

	if jump_held and not was_jump_held:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	was_jump_held = jump_held

	var can_jump: bool = (
		coyote_timer > 0.0
		and not is_crouching
		and not is_sliding
	)

	if jump_buffer_timer > 0.0 and can_jump:
		player_velocity.y = (
			jump_velocity * 1.10
			if super_speed
			else jump_velocity
		)
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# ============================================================
	# APPLY MOVEMENT
	# ============================================================

	var air_down_speed: float = maxf(-player_velocity.y, 0.0)

	local_player_node.velocity = player_velocity
	local_player_node.move_and_slide()

	# ============================================================
	# AIM STATE
	# ============================================================

	var ads_allowed: bool = (
		aim_button_down
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		and held_object == null
		and get_current_weapon() != WeaponType.FISTS
		and (not is_sprinting or aim_button_down)
		and not is_sliding
		and not is_reloading
		and not is_pumping
		and not is_inspecting
		and not is_equipping
		and not is_dead
	)
	ads_blend = move_toward(
		ads_blend,
		1.0 if ads_allowed else 0.0,
		weapon_aim_response * delta
	)
	is_aiming = ads_blend > 0.5

	# ============================================================
	# AIMBOT
	# ============================================================

	if aimbot_enabled:
		process_aimbot_lock(delta)

	# ============================================================
	# ESP
	# ============================================================

	if is_instance_valid(esp_overlay_node):
		esp_overlay_node.queue_redraw()

	# ============================================================
	# LANDING
	# ============================================================

	var is_on_floor_now: bool = (
		local_player_node.is_on_floor()
	)

	if (
		is_on_floor_now
		and not was_on_floor_last_frame
	):
		land_impact_spring = clampf(
			-0.06 - air_down_speed * 0.018,
			-0.30,
			-0.06
		)
		camera_shake = clampf(air_down_speed * 0.008, 0.012, 0.10)
		camera_shake_strength = maxf(
			camera_shake_strength,
			camera_shake
		)

	was_on_floor_last_frame = is_on_floor_now

	land_impact_spring = lerpf(
		land_impact_spring,
		0.0,
		clampf(delta * 10.0, 0.0, 1.0)
	)

	# ============================================================
	# WEAPON HEAT
	# ============================================================

	weapon_heat_level = move_toward(
		weapon_heat_level,
		0.0,
		delta * 0.18
	)

	# ============================================================
	# STAMINA
	# ============================================================

	var horizontal_speed: float = Vector2(
		local_player_node.velocity.x,
		local_player_node.velocity.z
	).length()

	if is_sliding:
		pass
	elif (
		is_sprinting
		and horizontal_speed > 0.1
	):
		stamina = maxf(
			stamina - stamina_drain * delta,
			0.0
		)

		if stamina <= 0.0:
			is_sprinting = false
	else:
		stamina = minf(
			stamina + stamina_regen * delta,
			max_stamina
		)

	update_hud_display()

	# ============================================================
	# NETWORK TRANSFORM
	# ============================================================

	rpc(
		"sync_player_transform",
		local_player_id,
		local_player_node.global_position,
		local_player_node.rotation.y,
		camera_pitch,
		target_lean,
		is_driving
	)

	# ============================================================
	# FIRE COOLDOWN
	# ============================================================

	if fire_cooldown > 0.0:
		fire_cooldown = maxf(
			fire_cooldown - delta,
			0.0
		)

	# ============================================================
	# FIRING CONTROL
	# ============================================================

	var can_fire: bool = (
		not is_menu_open
		and not is_cheat_menu_open
		and Input.get_mouse_mode()
		== Input.MOUSE_MODE_CAPTURED
		and held_object == null
		and not is_sprinting
		and not is_sliding
		and not is_equipping
		and not is_pumping
		and not is_inspecting
		and not is_reloading
		and not is_dead
	)

	var w_type: WeaponType = get_current_weapon()

	if can_fire:
		match w_type:
			WeaponType.AK47:
				match current_fire_mode:
					FireMode.FULL_AUTO:
						if (
							Input.is_action_pressed("fire")
							and fire_cooldown <= 0.0
						):
							execute_weapon_fire()

					FireMode.BURST:
						if (
							fire_pressed_this_frame
							and burst_count_remaining == 0
							and fire_cooldown <= 0.0
						):
							burst_count_remaining = 3

					FireMode.SEMI_AUTO:
						if (
							fire_pressed_this_frame
							and fire_cooldown <= 0.0
						):
							execute_weapon_fire()

			WeaponType.REMINGTON870:
				if (
					fire_pressed_this_frame
					and fire_cooldown <= 0.0
				):
					execute_weapon_fire()

			WeaponType.SNIPER_R700:
				if (
					fire_pressed_this_frame
					and fire_cooldown <= 0.0
				):
					execute_weapon_fire()

			WeaponType.FISTS:
				if (
					fire_pressed_this_frame
					and fire_cooldown <= 0.0
				):
					execute_fist_punch()

	# ============================================================
	# THREE-ROUND BURST
	# ============================================================

	if (
		burst_count_remaining > 0
		and can_fire
		and not is_reloading
		and not is_inspecting
		and not is_pumping
		and get_current_weapon() == WeaponType.AK47
		and current_fire_mode == FireMode.BURST
		and fire_cooldown <= 0.0
	):
		execute_weapon_fire()

		if is_reloading:
			burst_count_remaining = 0
		else:
			burst_count_remaining -= 1

	# ============================================================
	# CONSUME CLICK
	# ============================================================

	fire_pressed_this_frame = false

# ============================================================
# TRACE & BALLISTIC PROJECTILE SYSTEM
# ============================================================

func execute_weapon_ballistics(muzzle_pos: Vector3, target_pos: Vector3, is_hitscan: bool) -> void:
	var distance := muzzle_pos.distance_to(target_pos)
	if distance < 0.02:
		return
	var tracer := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.012
	mesh.height = distance
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.88, 0.38, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.62, 0.12)
	material.emission_energy_multiplier = 6.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.mesh = mesh
	tracer.material_override = material
	get_tree().root.add_child(tracer)
	tracer.global_position = (muzzle_pos + target_pos) * 0.5
	tracer.look_at(target_pos, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	var fade_time := 0.060 if is_hitscan else 0.080
	var tween := tracer.create_tween().set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, fade_time)
	tween.tween_property(tracer, "scale", Vector3(0.02, 1.0, 0.02), fade_time)
	tween.chain().tween_callback(tracer.queue_free)

func spawn_verity_replica() -> void:
	if is_instance_valid(verity_replica):
		verity_replica.queue_free()
	verity_replica = Node3D.new()
	verity_replica.name = "VerityReplicaPet"
	add_child(verity_replica)

	# Verity's recognizable companion form is a simple yellow smiley sphere.
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(1.0, 0.72, 0.035)
	body_material.roughness = 0.36
	body_material.metallic = 0.0
	body_material.clearcoat_enabled = true
	body_material.clearcoat = 0.18
	body_material.emission_enabled = true
	body_material.emission = Color(0.18, 0.09, 0.005)
	body_material.emission_energy_multiplier = 0.18
	var face_material := StandardMaterial3D.new()
	face_material.albedo_color = Color(0.025, 0.018, 0.012)
	face_material.roughness = 0.25
	var tooth_material := StandardMaterial3D.new()
	tooth_material.albedo_color = Color(0.96, 0.88, 0.66)
	tooth_material.roughness = 0.48

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.36
	core_mesh.height = 0.72
	core_mesh.radial_segments = 48
	core_mesh.rings = 24
	core.mesh = core_mesh
	core.material_override = body_material
	verity_replica.add_child(core)

	# Place the eyes just above the smile and conform them to the sphere surface.
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.031
	eye_mesh.height = 0.062
	eye_mesh.radial_segments = 24
	eye_mesh.rings = 12
	for side in [-1.0, 1.0]:
		var eye_node := MeshInstance3D.new()
		eye_node.mesh = eye_mesh
		eye_node.material_override = face_material
		eye_node.position = Vector3(side * 0.105, 0.095, -0.329)
		verity_replica.add_child(eye_node)

	var mouth := MeshInstance3D.new()
	var mouth_mesh := SphereMesh.new()
	mouth_mesh.radius = 0.145
	mouth_mesh.height = 0.18
	mouth_mesh.radial_segments = 32
	mouth_mesh.rings = 16
	mouth.mesh = mouth_mesh
	mouth.scale = Vector3(1.0, 0.58, 0.14)
	mouth.position = Vector3(0.0, -0.105, -0.323)
	mouth.material_override = face_material
	verity_replica.add_child(mouth)

	var teeth := MeshInstance3D.new()
	var teeth_mesh := BoxMesh.new()
	teeth_mesh.size = Vector3(0.19, 0.022, 0.008)
	teeth.mesh = teeth_mesh
	teeth.position = Vector3(0.0, -0.070, -0.347)
	teeth.material_override = tooth_material
	verity_replica.add_child(teeth)

	verity_replica.global_position = local_player_node.global_position + Vector3(0.8, 1.4, 0.9)


func process_verity_replica(delta: float) -> void:
	if not is_instance_valid(local_player_node):
		return
	if not is_instance_valid(verity_replica):
		spawn_verity_replica()
		return
	verity_replica_time += delta
	var follow_offset := Vector3(0.82, 1.35 + sin(verity_replica_time * 2.4) * 0.11, 0.92)
	var follow_position := local_player_node.global_transform * follow_offset
	verity_replica.global_position = verity_replica.global_position.lerp(follow_position, 1.0 - exp(-4.0 * delta))
	var look_target := local_player_node.global_position + Vector3.UP * 1.2
	if verity_replica.global_position.distance_squared_to(look_target) > 0.01:
		verity_replica.look_at(look_target, Vector3.UP)


# ============================================================
# CAMERA PROCESSING
# ============================================================

func _process(delta: float) -> void:
	if get_tree().paused and is_game_paused:
		return
	if current_state != GameState.INGAME:
		return
	if not is_instance_valid(local_player_node):
		return
	if not is_instance_valid(camera_pivot):
		return
	if not is_instance_valid(camera_effect_pivot):
		return
	if not is_instance_valid(player_camera):
		return

	# Base FPS look. Yaw is on the player; pitch is on the pivot.
	update_controller_look(delta)
	process_verity_replica(delta)
	update_weather_cycle(delta)
	update_rain_effect()
	camera_pivot.rotation = Vector3(camera_pitch, 0.0, 0.0)
	current_lean = move_toward(current_lean, target_lean, 48.0 * delta)

	update_vehicle_prompt()

	# Smooth crouch height transition.
	if is_dead:
		target_cam_height = 3.2
	elif is_driving:
		target_cam_height = driving_cam_height
	else:
		target_cam_height = crouch_cam_height if is_crouching else default_cam_height
	camera_pivot.position.y = lerpf(
		camera_pivot.position.y,
		target_cam_height,
		1.0 - exp(-12.0 * delta)
	)

	# Subtle mouse-look sway smoothing.
	sway_offset = sway_offset.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * delta))
	sway_rotation = sway_rotation.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	
	# Landing impact spring decay.
	land_impact_spring = lerpf(
		land_impact_spring,
		0.0,
		1.0 - exp(-15.0 * delta)
	)

	# Positional camera shake handling.
	camera_shake_strength = move_toward(
		camera_shake_strength,
		0.0,
		0.22 * delta
	)
	if camera_shake_strength > 0.0001:
		camera_shake_offset = Vector3(
			randf_range(-camera_shake_strength, camera_shake_strength),
			randf_range(-camera_shake_strength, camera_shake_strength),
			randf_range(-camera_shake_strength * 0.2, camera_shake_strength * 0.2)
		)
	else:
		camera_shake_offset = camera_shake_offset.lerp(
			Vector3.ZERO,
			1.0 - exp(-20.0 * delta)
		)

	# --- SMOOTH RECOIL SPRING RETURN ---
	# Automatically decays camera recoil rotation back to zero smoothly
	cam_recoil_rot = cam_recoil_rot.lerp(Vector3.ZERO, 1.0 - exp(-cam_recoil_return_speed * delta))

	# Camera effect layer composition (Sway + Shake + Recoil)
	camera_sway_position = Vector3(
		sway_offset.x * camera_sway_amount,
		sway_offset.y * camera_sway_amount + land_impact_spring,
		0.0
	)
	var roll_limit: float = deg_to_rad(camera_roll_limit_degrees)
	camera_sway_rotation = Vector3(
		sway_rotation.x * camera_sway_amount,
		0.0,
		clampf(sway_rotation.z * camera_sway_amount, -roll_limit, roll_limit)
	)
	
	# Apply final transforms to the effect pivot cleanly without duplicates
	var veh_third_person: bool = (is_driving and vehicle_camera_mode == 1)
	player_camera.cull_mask = DEFAULT_CAMERA_RENDER_MASK if (veh_third_person or is_dead) else (DEFAULT_CAMERA_RENDER_MASK & ~LOCAL_PLAYER_MODEL_LAYER)
	var lean_camera_offset := Vector3(sin(deg_to_rad(current_lean)) * 0.10, 0.0, 0.0)
	if veh_third_person or is_dead:
		# Chase and death views sit behind the vehicle/player body.
		camera_effect_pivot.position = (
			camera_sway_position
			+ camera_shake_offset
			+ lean_camera_offset
			+ Vector3(0.0, 0.35, vehicle_cam_distance)
		)
	else:
		camera_effect_pivot.position = camera_sway_position + camera_shake_offset + lean_camera_offset
	camera_effect_pivot.rotation = camera_sway_rotation + cam_recoil_rot + Vector3(0.0, 0.0, deg_to_rad(current_lean))

	player_camera.position = Vector3.ZERO
	if is_dead and is_instance_valid(local_player_node):
		player_camera.look_at(local_player_node.global_position + Vector3.UP * 1.15, Vector3.UP)
	else:
		player_camera.rotation = Vector3.ZERO

	# Conventional FPS FOV transition.
	var target_fov: float = user_base_fov
	if ads_blend > 0.001 and not disable_zoom:
		# Preserve the same ADS zoom ratio at every user-selected base FOV.
		# Treating aim_fov as an absolute value made low FOV settings zoom out.
		var ads_fov_ratio := clampf(aim_fov / 90.0, 0.5, 1.0)
		var ads_target_fov := maxf(50.0, user_base_fov * ads_fov_ratio)
		target_fov = lerpf(user_base_fov, ads_target_fov, ads_blend)
	elif is_sprinting:
		# Keep sprint widening relative to the user's selected base FOV.
		target_fov = user_base_fov + (sprint_fov - 90.0)

	target_fov = clampf(target_fov, 50.0, 120.0)
	player_camera.fov = lerpf(
		player_camera.fov,
		target_fov,
		1.0 - exp(-camera_fov_response * delta)
	)

	update_first_person_weapon(delta)
	update_procedural_hand_animations(delta, is_sprinting, is_aiming)
	# Update ingame leaderboard
	if is_instance_valid(ingame_leaderboard_label):
		var text := "RANK | OPERATIVE | K | D | SCORE\n"
		var sorted := leaderboard_data.keys()
		sorted.sort_custom(func(a,b): return leaderboard_data[a]["score"] > leaderboard_data[b]["score"])
		var count := 0
		for p in sorted:
			count += 1
			var st = leaderboard_data[p]
			text += str(count) + ". " + p + " | " + str(st["kills"]) + " | " + str(st["deaths"]) + " | " + str(st["score"]) + "\n"
			if count >= 10: break
		ingame_leaderboard_label.text = text


func update_controller_look(delta: float) -> void:
	if not last_input_was_controller or is_menu_open or is_cheat_menu_open:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		return
	if not connected.has(controller_device_id):
		controller_device_id = connected[0]
	var stick := Vector2(
		Input.get_joy_axis(controller_device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(controller_device_id, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() < 0.18:
		return
	var aim_slowdown := 1.0
	if aim_button_down and is_aiming and current_map_type == MapType.CQB_ARENA and controller_aim_assist_enabled:
		aim_slowdown = get_controller_aim_slowdown()
	var look_delta := stick * controller_look_sensitivity * aim_slowdown * delta
	if is_driving:
		vehicle_look_offset = wrapf(vehicle_look_offset - look_delta.x, -PI, PI)
	else:
		local_player_node.rotation.y -= look_delta.x
	camera_pitch = clampf(
		camera_pitch - look_delta.y,
		deg_to_rad(-camera_pitch_limit_degrees),
		deg_to_rad(camera_pitch_limit_degrees)
	)
	if aim_button_down and ads_blend > 0.5:
		apply_controller_aim_assist(delta)


func apply_controller_aim_assist(delta: float) -> void:
	if not last_input_was_controller or not controller_aim_assist_enabled or current_map_type != MapType.CQB_ARENA or not aim_button_down or not is_instance_valid(local_player_node):
		return
	var yaw_basis := Basis(Vector3.UP, local_player_node.rotation.y)
	var pitch_basis := Basis(Vector3.RIGHT, camera_pitch)
	var aim_forward := (yaw_basis * pitch_basis * Vector3(0.0, 0.0, -1.0)).normalized()
	var camera_origin := player_camera.global_position
	var best_alignment := 0.0
	var best_direction := Vector3.ZERO
	var max_angle := deg_to_rad(8.0)
	var candidates: Array[Node3D] = []
	for player_id in players.keys():
		if int(player_id) == local_player_id: continue
		var player_data: Variant = players[player_id]
		if player_data is Dictionary:
			var target := player_data.get("root") as Node3D
			if is_instance_valid(target): candidates.append(target)
	for child in get_children():
		if child is Node3D and child.has_meta("is_npc"):
			candidates.append(child as Node3D)
	for target in candidates:
		if not is_instance_valid(target): continue
		var direction := target.global_position + Vector3.UP * 1.15 - camera_origin
		var distance := direction.length()
		if distance < 0.1 or distance > 45.0: continue
		direction /= distance
		var angle := aim_forward.angle_to(direction)
		if angle < max_angle:
			var alignment := 1.0 - angle / max_angle
			if alignment > best_alignment:
				best_alignment = alignment
				best_direction = direction
	if best_alignment <= 0.0: return
	var turn_step := deg_to_rad(36.0) * controller_aim_assist_strength * best_alignment * delta
	var target_yaw := atan2(-best_direction.x, -best_direction.z)
	var yaw_error := wrapf(target_yaw - local_player_node.rotation.y, -PI, PI)
	local_player_node.rotation.y += clampf(yaw_error, -turn_step, turn_step)
	var target_pitch := asin(clampf(best_direction.y, -1.0, 1.0))
	camera_pitch = clampf(camera_pitch + clampf(target_pitch - camera_pitch, -turn_step, turn_step), deg_to_rad(-camera_pitch_limit_degrees), deg_to_rad(camera_pitch_limit_degrees))


func get_controller_aim_slowdown() -> float:
	if not controller_aim_assist_enabled or current_map_type != MapType.CQB_ARENA or not is_instance_valid(player_camera):
		return 1.0
	var camera_origin := player_camera.global_position
	var aim_forward := -player_camera.global_transform.basis.z.normalized()
	var best_alignment := 0.0
	var max_angle := deg_to_rad(8.0)
	for player_id in players.keys():
		if int(player_id) == local_player_id:
			continue
		var player_data: Variant = players[player_id]
		if not player_data is Dictionary:
			continue
		var target := player_data.get("root") as Node3D
		if is_instance_valid(target):
			best_alignment = maxf(best_alignment, _aim_target_alignment(camera_origin, aim_forward, target.global_position + Vector3.UP * 1.1, max_angle))
	for child in get_children():
		if child is Node3D and child.has_meta("is_npc"):
			var npc := child as Node3D
			best_alignment = maxf(best_alignment, _aim_target_alignment(camera_origin, aim_forward, npc.global_position + Vector3.UP * 1.1, max_angle))
	return clampf(1.0 - controller_aim_assist_strength * best_alignment, 0.65, 1.0)


func _aim_target_alignment(origin: Vector3, forward: Vector3, target: Vector3, max_angle: float) -> float:
	var offset := target - origin
	var distance := offset.length()
	if distance <= 0.1 or distance > 45.0:
		return 0.0
	var angle := forward.angle_to(offset / distance)
	if angle >= max_angle:
		return 0.0
	return 1.0 - angle / max_angle


# ============================================================
# PAUSE & SETTINGS MENU SYSTEM
# ============================================================

func build_pause_and_settings_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# --- PAUSE MENU CONTAINER ---
	pause_menu_ui = Control.new()
	pause_menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu_ui.visible = false
	canvas.add_child(pause_menu_ui)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu_ui.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu_ui.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GAME PAUSED"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume Game"
	resume_btn.custom_minimum_size = Vector2(300, 46)
	resume_btn.pressed.connect(toggle_pause_menu)
	vbox.add_child(resume_btn)

	var deploy_btn := Button.new()
	deploy_btn.text = "Respawn"
	deploy_btn.custom_minimum_size = Vector2(300, 46)
	deploy_btn.pressed.connect(func():
		if is_menu_open:
			toggle_pause_menu()
		deploy_or_respawn_player()
	)
	vbox.add_child(deploy_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(300, 46)
	settings_btn.pressed.connect(open_settings_menu)
	vbox.add_child(settings_btn)

	var main_menu_btn := Button.new()
	main_menu_btn.text = "Quit to Main Menu"
	main_menu_btn.custom_minimum_size = Vector2(300, 46)
	main_menu_btn.pressed.connect(_return_to_main_menu)
	vbox.add_child(main_menu_btn)

	var quit_desktop_btn := Button.new()
	quit_desktop_btn.text = "Quit to Desktop"
	quit_desktop_btn.custom_minimum_size = Vector2(300, 46)
	quit_desktop_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_desktop_btn)

	# --- SETTINGS MENU CONTAINER ---
	settings_menu_ui = Control.new()
	settings_menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_menu_ui.visible = false
	canvas.add_child(settings_menu_ui)

	var s_bg := ColorRect.new()
	s_bg.color = Color(0.05, 0.06, 0.09, 0.95)
	s_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_menu_ui.add_child(s_bg)

	var s_center := CenterContainer.new()
	s_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_menu_ui.add_child(s_center)

	var settings_scroll := ScrollContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	settings_scroll.custom_minimum_size = Vector2(
		minf(760.0, maxf(viewport_size.x - 80.0, 400.0)),
		minf(850.0, maxf(viewport_size.y - 60.0, 320.0))
	)
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s_center.add_child(settings_scroll)

	var s_vbox := VBoxContainer.new()
	s_vbox.custom_minimum_size.x = minf(520.0, maxf(viewport_size.x - 110.0, 340.0))
	s_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_vbox.add_theme_constant_override("separation", 12)
	settings_scroll.add_child(s_vbox)

	var s_title := Label.new()
	s_title.text = "SETTINGS"
	s_title.add_theme_font_size_override("font_size", 32)
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_vbox.add_child(s_title)

	# 1. FOV Slider
	var fov_lbl := Label.new()
	fov_lbl.text = "Field of View (FOV): " + str(int(user_base_fov))
	s_vbox.add_child(fov_lbl)
	
	var fov_slider := HSlider.new()
	fov_slider.min_value = 60.0
	fov_slider.max_value = 120.0
	fov_slider.value = user_base_fov
	fov_slider.custom_minimum_size = Vector2(320, 30)
	fov_slider.value_changed.connect(func(v):
		user_base_fov = v
		fov_lbl.text = "Field of View (FOV): " + str(int(v))
		save_game_settings()
	)
	s_vbox.add_child(fov_slider)

	# 2. Mouse Sensitivity Slider
	var sens_lbl := Label.new()
	sens_lbl.text = "Mouse Sensitivity: " + str(snappedf(mouse_sensitivity, 0.0001))
	s_vbox.add_child(sens_lbl)
	
	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.008
	sens_slider.step = 0.0002
	sens_slider.value = mouse_sensitivity
	sens_slider.custom_minimum_size = Vector2(320, 30)
	sens_slider.value_changed.connect(func(v):
		mouse_sensitivity = v
		sens_lbl.text = "Mouse Sensitivity: " + str(snappedf(v, 0.0001))
		save_game_settings()
	)
	s_vbox.add_child(sens_slider)

	var aim_move_label := Label.new()
	aim_move_label.text = "Aim Move Speed: " + str(int(aim_move_speed_multiplier * 100.0)) + "%"
	s_vbox.add_child(aim_move_label)
	var aim_move_slider := HSlider.new()
	aim_move_slider.min_value = 0.4
	aim_move_slider.max_value = 1.0
	aim_move_slider.step = 0.05
	aim_move_slider.value = aim_move_speed_multiplier
	aim_move_slider.custom_minimum_size = Vector2(320, 30)
	aim_move_slider.value_changed.connect(func(value: float):
		aim_move_speed_multiplier = clampf(value, 0.4, 1.0)
		aim_move_label.text = "Aim Move Speed: " + str(int(aim_move_speed_multiplier * 100.0)) + "%"
		save_game_settings()
	)
	s_vbox.add_child(aim_move_slider)

	# 3. Master Volume Slider
	var vol_lbl := Label.new()
	vol_lbl.text = "Master Audio Volume"
	s_vbox.add_child(vol_lbl)
	
	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = master_volume
	vol_slider.custom_minimum_size = Vector2(320, 30)
	vol_slider.value_changed.connect(func(v):
		_apply_master_volume(v)
		save_game_settings()
	)
	s_vbox.add_child(vol_slider)

	# 4. Fullscreen Toggle Checkbox
	var fs_chk := CheckBox.new()
	fs_chk.text = "Fullscreen Mode"
	fs_chk.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fs_chk.toggled.connect(func(v):
		if v:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		save_game_settings()
	)
	s_vbox.add_child(fs_chk)
# 5. Damage Indicators Toggle Checkbox
	var dmg_chk := CheckBox.new()
	dmg_chk.text = "Show Damage Numbers"
	dmg_chk.button_pressed = show_damage_indicators
	dmg_chk.toggled.connect(func(v: bool):
		show_damage_indicators = v
		save_game_settings()
	)
	s_vbox.add_child(dmg_chk)
	
	# 6. Disable All Zoom Toggle Checkbox
	var zoom_chk := CheckBox.new()
	zoom_chk.text = "Disable All Zoom (No ADS Zoom)"
	zoom_chk.button_pressed = disable_zoom
	zoom_chk.toggled.connect(func(v: bool):
		disable_zoom = v
		save_game_settings()
	)
	s_vbox.add_child(zoom_chk)
	
	add_graphics_settings(s_vbox)
	add_rebind_controls(s_vbox)

	# Back Button
	var back_btn := Button.new()
	back_btn.text = "Back to Pause Menu"
	back_btn.custom_minimum_size = Vector2(320, 44)
	back_btn.pressed.connect(close_settings_menu)
	s_vbox.add_child(back_btn)

func toggle_pause_menu() -> void:
	if current_state != GameState.INGAME:
		return

	is_menu_open = not is_menu_open
	if is_instance_valid(pause_menu_ui):
		pause_menu_ui.visible = is_menu_open

	if is_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# A host with no remote peers is still effectively singleplayer.
		if multiplayer.get_peers().is_empty():
			get_tree().paused = true # Pause game in singleplayer
			is_game_paused = true
	else:
		if is_instance_valid(settings_menu_ui):
			settings_menu_ui.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if is_game_paused:
			get_tree().paused = false
			is_game_paused = false


func open_settings_menu() -> void:
	if is_instance_valid(pause_menu_ui):
		pause_menu_ui.visible = false
	if is_instance_valid(settings_menu_ui):
		settings_menu_ui.visible = true


func close_settings_menu() -> void:
	if is_instance_valid(settings_menu_ui):
		settings_menu_ui.visible = false
	pending_rebind_action = &""
	if is_instance_valid(pause_menu_ui):
		pause_menu_ui.visible = true
# ============================================================
# WEAPON ANIMATION, SWAY & ADS PRESENTATION
# ============================================================

func update_first_person_weapon(delta: float) -> void:
	if not is_instance_valid(weapon_rig):
		return
	weapon_rig.visible = not is_driving and not is_dead

	var weapon := get_current_weapon()
	crosshair_spread = get_realistic_spread_degrees(weapon)
	update_crosshair_layout()
	if weapon == WeaponType.FISTS:
		ads_blend = 0.0

	var hip := weapon_base_position
	var ads := weapon_ads_position
	var ads_rot := Vector3.ZERO
	var sight_eye_relief := 0.86
	match weapon:
		WeaponType.AK47:
			sight_eye_relief = 0.88
		WeaponType.REMINGTON870:
			sight_eye_relief = 0.84
		WeaponType.SNIPER_R700:
			sight_eye_relief = 0.92
		WeaponType.FISTS:
			pass

	if is_instance_valid(weapon_mesh_root) and is_instance_valid(weapon_rear_iron_sight) and is_instance_valid(weapon_front_iron_sight):
		var rear_sight_in_rig: Vector3 = weapon_mesh_root.transform * weapon_rear_iron_sight.position
		var front_sight_in_rig: Vector3 = weapon_mesh_root.transform * weapon_front_iron_sight.position
		var sight_axis: Vector3 = front_sight_in_rig - rear_sight_in_rig
		if sight_axis.z < -0.001:
			ads_rot.x = -atan2(sight_axis.y, -sight_axis.z)
			var sight_alignment_basis := Basis(Vector3.RIGHT, ads_rot.x)
			ads = Vector3(0.0, 0.0, -sight_eye_relief) - sight_alignment_basis * rear_sight_in_rig

	# --- IRON-SIGHT HUD PRESENTATION ---
	if is_instance_valid(scope_overlay_ui):
		# All guns use their modeled iron sights while aiming, including the R700.
		scope_overlay_ui.visible = false
	if is_instance_valid(weapon_scope_root):
		weapon_scope_root.visible = weapon != WeaponType.SNIPER_R700 or ads_blend < 0.5
	if is_instance_valid(crosshair_container):
		# Keep the dot and crosshair from covering the front post or shotgun bead.
		crosshair_container.visible = ads_blend < 0.5
	if is_instance_valid(weapon_red_dot_reticle):
		weapon_red_dot_reticle.visible = ads_blend > 0.25

	var desired_position: Vector3 = hip.lerp(ads, ads_blend)
	var desired_rotation: Vector3 = Vector3.ZERO.lerp(ads_rot, ads_blend)

	if is_sprinting and ads_blend < 0.05:
		desired_position.y -= weapon_sprint_lowering

	var speed_ratio: float = 0.0
	if is_instance_valid(local_player_node):
		speed_ratio = clampf(
			Vector2(local_player_node.velocity.x, local_player_node.velocity.z).length() / maxf(sprint_speed, 0.1),
			0.0,
			1.0
		)

	if ads_blend < 0.5 and not is_inspecting and not is_reloading:
		idle_breath_cycle += delta * 2.4
		walk_cycle += delta * lerpf(2.5, 10.0, speed_ratio)
		
		desired_position.y += sin(idle_breath_cycle) * 0.002
		desired_position.x += cos(idle_breath_cycle * 0.5) * 0.0015
		desired_position.y += abs(sin(walk_cycle * 2.0)) * weapon_idle_bob_amount * speed_ratio * 1.2
		desired_position.x += cos(walk_cycle) * weapon_idle_bob_amount * speed_ratio * 0.9

	gun_recoil_offset = gun_recoil_offset.lerp(Vector3.ZERO, 1.0 - exp(-weapon_recoil_recovery_speed * delta))
	gun_recoil_vel = gun_recoil_vel.lerp(Vector3.ZERO, 1.0 - exp(-weapon_recoil_recovery_speed * 1.1 * delta))
	gun_recoil_offset += gun_recoil_vel * delta

	gun_rot_recoil = gun_rot_recoil.lerp(Vector3.ZERO, 1.0 - exp(-weapon_recoil_recovery_speed * 1.25 * delta))
	gun_rot_vel = gun_rot_vel.lerp(Vector3.ZERO, 1.0 - exp(-weapon_recoil_recovery_speed * delta))
	gun_rot_recoil += gun_rot_vel * delta

	weapon_recoil_visual = weapon_recoil_visual.lerp(
		gun_recoil_offset * weapon_recoil_position_scale,
		1.0 - exp(-26.0 * delta)
	)
	weapon_recoil_visual_rotation = weapon_recoil_visual_rotation.lerp(
		gun_rot_recoil * weapon_recoil_rotation_scale,
		1.0 - exp(-26.0 * delta)
	)

	var ads_sway_scale := lerpf(1.0, 0.06, ads_blend)
	var target_sway_pos = Vector3(sway_offset.x * 0.4, sway_offset.y * 0.4, 0.0) * ads_sway_scale

	weapon_rig.position = weapon_rig.position.lerp(
		desired_position + target_sway_pos + weapon_recoil_visual,
		1.0 - exp(-24.0 * delta)
	)
	
	var final_rot = desired_rotation + Vector3(sway_rotation.x * 0.45, sway_rotation.z * 0.45, sway_rotation.z * 0.25) + weapon_recoil_visual_rotation
	weapon_rig.rotation = weapon_rig.rotation.lerp(final_rot, 1.0 - exp(-24.0 * delta))

	player_camera.position = Vector3.ZERO
	if is_dead and is_instance_valid(local_player_node):
		player_camera.look_at(local_player_node.global_position + Vector3.UP * 1.15, Vector3.UP)
	else:
		player_camera.rotation = Vector3.ZERO
	

# ============================================================
# AIMBOT SYSTEM
# ============================================================

func process_aimbot_lock(delta: float) -> void:
	if (
		not is_instance_valid(player_camera)
		or not is_instance_valid(local_player_node)
	):
		return

	var best_target: Node3D = null
	var min_angle: float = deg_to_rad(60.0)

	var cam_pos: Vector3 = (
		player_camera.global_position
	)

	var forward: Vector3 = (
		-player_camera.global_transform.basis.z
	)

	for child in get_children():
		if child == local_player_node:
			continue

		var is_target: bool = false
		var t_pos: Vector3 = Vector3.ZERO

		if (
			child.has_meta("is_npc")
			and int(child.get_meta("hp", 0)) > 0
		):
			is_target = true
			t_pos = (
				child.global_position
				+ Vector3(0.0, 1.4, 0.0)
			)

		elif (
			child.name.begins_with("Player_")
			and players.has(child.name.trim_prefix("Player_").to_int())
		):
			if child.visible:
				is_target = true
				t_pos = (
					child.global_position
					+ Vector3(0.0, 1.4, 0.0)
				)

		if is_target:
			var direction_to: Vector3 = (
				t_pos - cam_pos
			).normalized()

			var angle: float = (
				forward.angle_to(direction_to)
			)

			if angle < min_angle:
				min_angle = angle
				best_target = child

	if best_target != null:
		var target_head: Vector3 = (
			best_target.global_position
			+ Vector3(0.0, 1.4, 0.0)
		)

		var look_vec: Vector3 = (
			target_head
			- local_player_node.global_position
		)

		var target_y: float = atan2(
			-look_vec.x,
			-look_vec.z
		)

		local_player_node.rotation.y = lerp_angle(
			local_player_node.rotation.y,
			target_y,
			delta * 22.0
		)

		var cam_vec: Vector3 = (
			target_head
			- camera_pivot.global_position
		)

		if cam_vec.length_squared() > 0.0001:
			var target_x: float = asin(
				clampf(
					cam_vec.y / cam_vec.length(),
					-1.0,
					1.0
				)
			)

			camera_pitch = lerp_angle(
				camera_pitch,
				target_x,
				delta * 22.0
			)

			camera_pitch = clampf(
				camera_pitch,
				deg_to_rad(-camera_pitch_limit_degrees),
				deg_to_rad(camera_pitch_limit_degrees)
			)
func spawn_floating_damage_number(hit_position: Vector3, damage_value: float, is_headshot: bool = false) -> void:
	if not show_damage_indicators:
		return

	var label_3d := Label3D.new()
	label_3d.text = str(int(round(damage_value)))
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.pixel_size = 0.0035 # Controls crispness and physical scale in 3D space[cite: 3]
	label_3d.font_size = 46 if is_headshot else 34
	
	# Bright crimson for headshots, high-visibility yellow/gold for regular body hits[cite: 3]
	label_3d.modulate = Color(1.0, 0.12, 0.12, 1.0) if is_headshot else Color(1.0, 0.88, 0.22, 1.0)

	# Must add to the tree first before running tweens or setting global positions[cite: 3]
	get_tree().root.add_child(label_3d)
	
	# Position slightly randomized around the hit point so multiple hits don't overlap[cite: 3]
	label_3d.global_position = hit_position + Vector3(
		randf_range(-0.2, 0.2), 
		randf_range(0.2, 0.4), 
		randf_range(-0.2, 0.2)
	)

	# Smooth floating upward animation with an alpha fade out[cite: 3]
	var tween := label_3d.create_tween().set_parallel(true)
	tween.tween_property(label_3d, "global_position:y", label_3d.global_position.y + 0.75, 0.55)
	tween.tween_property(label_3d, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(label_3d.queue_free)

# ============================================================
# MAIN MENU
# ============================================================

func build_main_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	main_menu_ui = Control.new()
	main_menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(main_menu_ui)

	# Professional tactical dark background
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_ui.add_child(bg)

	# Main Split Container (Left: Deployment & Settings, Right: Leaderboard)
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 24)
	# Add internal padding margins using a MarginContainer wrapper
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	main_menu_ui.add_child(margin)
	margin.add_child(main_hbox)

	# ==================== LEFT COLUMN: OPERATIONS & SETUP ====================
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(460, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_scroll)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 16)
	left_scroll.add_child(left_vbox)

	# Title Header
	var title_card := VBoxContainer.new()
	var title := Label.new()
	title.text = "TACTICAL OPERATIONS"
	title.add_theme_font_size_override("font_size", 28)
	title_card.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Node FPS [BETA] 0.9.5"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = Color(0.6, 0.7, 0.8)
	title_card.add_child(subtitle)
	left_vbox.add_child(title_card)

	# --- 1. USERNAME / CALLSIGN REGISTRATION ---
	var user_box := VBoxContainer.new()
	user_box.add_theme_constant_override("separation", 6)
	var user_lbl := Label.new()
	user_lbl.text = "Username/Callsign (REQUIRED):"
	user_box.add_child(user_lbl)

	username_input = LineEdit.new()
	username_input.placeholder_text = "Enter Username or Callsign"
	username_input.custom_minimum_size = Vector2(0, 42)
	username_input.max_length = 20
	username_input.text_changed.connect(func(t): player_username = t.strip_edges())
	user_box.add_child(username_input)
	left_vbox.add_child(user_box)

	# --- 2. MISSION PARAMETERS (MAP & TIME) ---
	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 6)
	var m_lbl := Label.new()
	m_lbl.text = "MISSION PARAMETERS:"
	mission_box.add_child(m_lbl)

	map_select_option = OptionButton.new()
	map_select_option.add_item("Tactical Sandbox World", MapType.TACTICAL_SANDBOX)
	map_select_option.add_item("1V1 Arena", MapType.CQB_ARENA)
	map_select_option.custom_minimum_size = Vector2(0, 38)
	mission_box.add_child(map_select_option)

	time_select_option = OptionButton.new()
	time_select_option.add_item("Day", TimeOfDay.DAY)
	time_select_option.add_item("Night", TimeOfDay.NIGHT)
	time_select_option.custom_minimum_size = Vector2(0, 38)
	mission_box.add_child(time_select_option)
	left_vbox.add_child(mission_box)

	# --- 3. LOADOUT SELECTION ---
	var loadout_box := VBoxContainer.new()
	loadout_box.add_theme_constant_override("separation", 6)
	var l_lbl := Label.new()
	l_lbl.text = "WEAPON LOADOUT:"
	loadout_box.add_child(l_lbl)

	primary_weapon_option = OptionButton.new()
	primary_weapon_option.add_item("AK-47", WeaponType.AK47)
	primary_weapon_option.add_item("Remington 870", WeaponType.REMINGTON870)
	primary_weapon_option.add_item("Sniper R700", WeaponType.SNIPER_R700)
	primary_weapon_option.custom_minimum_size = Vector2(0, 38)
	loadout_box.add_child(primary_weapon_option)
	
	secondary_weapon_option = OptionButton.new()
	secondary_weapon_option.add_item("None (Fists)", WeaponType.FISTS)
	secondary_weapon_option.add_item("AK-47", WeaponType.AK47)
	secondary_weapon_option.add_item("Remington 870", WeaponType.REMINGTON870)
	secondary_weapon_option.add_item("Sniper R700", WeaponType.SNIPER_R700)
	secondary_weapon_option.custom_minimum_size = Vector2(0, 38)
	loadout_box.add_child(secondary_weapon_option)
	left_vbox.add_child(loadout_box)
	

	# --- 4. GRAPHICS & PLAYER MODEL SETTINGS ---
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 6)
	var set_lbl := Label.new()
	set_lbl.text = "PREFERENCES:"
	settings_box.add_child(set_lbl)

	var model_chk := CheckBox.new()
	model_chk.text = "Show First-Person Hands"
	model_chk.button_pressed = show_player_model_in_menu
	model_chk.toggled.connect(func(v):
		show_player_model_in_menu = v
		save_game_settings()
	)
	settings_box.add_child(model_chk)

	var dmg_chk := CheckBox.new()
	dmg_chk.text = "Show Floating Damage Indicators?"
	dmg_chk.button_pressed = show_damage_indicators
	dmg_chk.toggled.connect(func(v):
		show_damage_indicators = v
		save_game_settings()
	)
	settings_box.add_child(dmg_chk)
	add_graphics_settings(settings_box)
	left_vbox.add_child(settings_box)

	# --- 5. CREATE OR JOIN A GAME ---
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	var network_label := Label.new()
	network_label.text = "MULTIPLAYER (UDP PORT " + str(PORT) + ")"
	action_box.add_child(network_label)
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Server IP address (example: 127.0.0.1)"
	ip_input.custom_minimum_size = Vector2(0, 40)
	ip_input.max_length = 64
	action_box.add_child(ip_input)
	var create_game_btn := Button.new()
	create_game_btn.text = "CREATE GAME"
	create_game_btn.custom_minimum_size = Vector2(0, 48)
	create_game_btn.pressed.connect(func(): _launch_game_from_menu(true))
	action_box.add_child(create_game_btn)
	var join_game_btn := Button.new()
	join_game_btn.text = "JOIN BY IP"
	join_game_btn.custom_minimum_size = Vector2(0, 48)
	join_game_btn.pressed.connect(func(): _launch_game_from_menu(false))
	action_box.add_child(join_game_btn)
	left_vbox.add_child(action_box)

	# ==================== RIGHT COLUMN: LIVE LEADERBOARD ====================
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_panel.add_child(right_vbox)

	var lb_header := Label.new()
	lb_header.text = "LEADERBOARD"
	lb_header.add_theme_font_size_override("font_size", 20)
	right_vbox.add_child(lb_header)

	var lb_scroll := ScrollContainer.new()
	lb_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(lb_scroll)

	leaderboard_list = VBoxContainer.new()
	leaderboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_scroll.add_child(leaderboard_list)

	refresh_leaderboard_display()

# ============================================================
# MULTIPLAYER
# ============================================================

func _launch_game_from_menu(is_host: bool) -> void:
	if is_instance_valid(username_input) and not username_input.text.strip_edges().is_empty():
		player_username = username_input.text.strip_edges()
	
	if player_username.is_empty():
		player_username = "SoloOperative" if is_host else "Operative"

	update_player_score(player_username, 0, 0, 0)
	start_multiplayer(is_host)


func start_multiplayer(is_host: bool) -> void:
	# ============================================================
	# LOADOUT
	# ============================================================

	var primary_w: WeaponType = (
		primary_weapon_option.get_selected_id() as WeaponType
	)

	var secondary_w: WeaponType = (
		secondary_weapon_option.get_selected_id() as WeaponType
	)

	if primary_w != WeaponType.FISTS:
		inventory = [primary_w]

		if (
			secondary_w != WeaponType.FISTS
			and secondary_w != primary_w
		):
			inventory.append(
				secondary_w
			)
	else:
		inventory = []

	# ============================================================
	# NETWORK
	# ============================================================

	if is_host:
		var server_error: Error = (
			enet_peer.create_server(PORT)
		)

		if server_error != OK:
			push_error(
				"Failed to create server. Error: "
				+ str(server_error)
			)
			return

		multiplayer.multiplayer_peer = (
			enet_peer
		)

		local_player_id = 1

		current_map_type = (
	map_select_option.get_selected_id() as MapType
)

		current_time_of_day = (
	time_select_option.get_selected_id() as TimeOfDay
)

	else:
		var ip: String = ip_input.text.strip_edges() if is_instance_valid(ip_input) else ""
		if ip.is_empty():
			push_error("Enter the host's IP address before joining")
			return

		var client_error: Error = (
			enet_peer.create_client(
				ip,
				PORT
			)
		)

		if client_error != OK:
			push_error(
				"Failed to create client. Error: "
				+ str(client_error)
			)
			return

		multiplayer.multiplayer_peer = (
			enet_peer
		)

		local_player_id = (
			multiplayer.get_unique_id()
		)

		current_map_type = (
			MapType.TACTICAL_SANDBOX
		)

		current_time_of_day = (
			TimeOfDay.DAY
		)
		# The server sends its map and time settings before the client builds a world.
		return

	initialize_game_world()


@rpc("authority", "call_local")
func net_initialize_client(map_type: MapType, time_of_day: TimeOfDay) -> void:
	if current_state == GameState.INGAME:
		return

	current_map_type = map_type
	current_time_of_day = time_of_day
	initialize_game_world()


func initialize_game_world() -> void:
	main_menu_ui.visible = false
	current_state = GameState.INGAME
	cqb_score_player = 0
	cqb_score_enemy = 0

	tac_night_mode = current_time_of_day == TimeOfDay.NIGHT
	night_mode_enabled = tac_night_mode

	setup_world_environment()
	if current_time_of_day == TimeOfDay.NIGHT:
		apply_night_mode()
	else:
		apply_day_mode()
	weather_cycle_timer = 0.0
	set_weather_state(WeatherType.CLEAR)

	# Keep randomized map cover and vehicle names consistent on every peer.
	seed(int(current_map_type) * 1000 + int(current_time_of_day) * 100 + 8261)
	if current_map_type == MapType.CQB_ARENA:
		build_cqb_arena_map()
	else:
		build_advanced_tactical_map()
	setup_reflection_probe()

	build_advanced_gui_systems()
	build_cheat_menu_ui()
	build_night_vision_overlay()
	build_pause_and_settings_menu()

	spawn_player(local_player_id, true)
	spawn_verity_replica()
	update_rain_effect()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		rpc_id(
			id,
			"net_initialize_client",
			current_map_type,
			current_time_of_day
		)

		for existing_id in players.keys():
			rpc_id(
				id,
				"net_spawn_player",
				int(existing_id)
			)

		rpc(
			"net_spawn_player",
			id
		)


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		var player_data: Dictionary = (
			players[id]
		)

		if is_instance_valid(
			player_data["root"]
		):
			player_data["root"].queue_free()

		players.erase(id)


func _return_to_main_menu() -> void:
	get_tree().paused = false
	is_game_paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	if active_peer != null:
		active_peer.close()
	enet_peer = ENetMultiplayerPeer.new()
	get_tree().reload_current_scene()


@rpc("any_peer", "call_local")
func net_spawn_player(id: int) -> void:
	if id != local_player_id:
		spawn_player(
			id,
			false
		)

func deploy_or_respawn_player() -> void:
	if not is_instance_valid(local_player_node):
		return
	if is_driving:
		exit_vehicle()
	if is_instance_valid(held_object):
		drop_held_object()

	death_sequence_id += 1
	local_player_node.global_position = Vector3(
		randf_range(-4.0, 4.0),
		1.0,
		randf_range(8.0, 12.0)
	)
	local_player_node.velocity = Vector3.ZERO
	local_player_node.visible = true
	health = max_health
	stamina = max_stamina
	is_sliding = false
	slide_timer = 0.0
	was_crouch_held = Input.is_action_pressed("crouch")
	is_dead = false
	target_lean = 0.0
	current_lean = 0.0
	camera_pitch = 0.0
	if is_instance_valid(camera_pivot):
		camera_pivot.position = Vector3(0.0, default_cam_height, 0.0)
	if is_instance_valid(player_camera):
		player_camera.rotation = Vector3.ZERO
	fire_pressed_this_frame = false
	fire_cooldown = 0.0
	burst_count_remaining = 0
	aim_button_down = false
	is_aiming = false
	ads_blend = 0.0
	update_hud_display()

# ============================================================
# PLAYER SPAWN
# ============================================================

func spawn_player(
	id: int,
	is_local: bool
) -> void:
	var p_root := CharacterBody3D.new()

	p_root.name = (
		"Player_" + str(id)
	)

	if current_map_type == MapType.CQB_ARENA:
		p_root.position = Vector3(
			randf_range(-4.0, 4.0),
			1.0,
			randf_range(8.0, 12.0)
		)
	else:
		p_root.position = Vector3(
			randf_range(-8.0, 8.0),
			1.0,
			randf_range(10.0, 18.0)
		)

	# Layer 2 = character.
	# Mask 1 = world.

	p_root.collision_layer = 2
	p_root.collision_mask = 1

	add_child(p_root)

	# ============================================================
	# PLAYER COLLISION
	# ============================================================

	var p_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()

	capsule.radius = 0.42
	capsule.height = 1.8

	p_shape.shape = capsule
	p_shape.position.y = 0.9

	p_root.add_child(p_shape)

	# ============================================================
	# CAMERA RIG
	# ============================================================
	# Hierarchy:
	#
	# PlayerRoot (yaw)
	#   -> CameraPivot (pitch + height)
	#       -> CameraEffects (sway + recoil + shake)
	#           -> PlayerCamera
	#
	# Keeping these transforms separate prevents recoil/sway from
	# feeding back into the player's real look orientation.

	var c_pivot := Node3D.new()

	c_pivot.name = "CameraPivot"
	c_pivot.position = Vector3(
		0.0,
		default_cam_height,
		0.0
	)

	p_root.add_child(c_pivot)

	var c_effects := Node3D.new()

	c_effects.name = "CameraEffects"
	c_effects.position = Vector3.ZERO
	c_effects.rotation = Vector3.ZERO

	c_pivot.add_child(c_effects)

	# ============================================================
	# PLAYER REGISTRY
	# ============================================================

	players[id] = {
		"root": p_root,
		"pivot": c_pivot,
		"health": 100.0
	}

	# ============================================================
	# HITBOXES
	# ============================================================

	add_humanoid_hitboxes(
		p_root
	)

	# ============================================================
	# LOCAL PLAYER
	# ============================================================

	if is_local:
		var local_model := build_high_detail_humanoid(
			p_root,
			Color(0.13, 0.24, 0.32),
			Color(0.06, 0.10, 0.14),
			Color(0.72, 0.50, 0.38),
			Color(0.18, 0.50, 0.72)
		)
		p_root.set_meta("player_model", local_model)
		_set_visual_layers_recursive(local_model, LOCAL_PLAYER_MODEL_LAYER)
		local_player_node = p_root
		camera_pivot = c_pivot
		camera_effect_pivot = c_effects

		camera_pitch = 0.0

		player_camera = Camera3D.new()
		player_camera.name = "PlayerCamera"

		player_camera.position = Vector3.ZERO
		player_camera.rotation = Vector3.ZERO
		player_camera.fov = clampf(
			user_base_fov,
			50.0,
			120.0
		)
		player_camera.near = 0.03
		player_camera.far = 1000.0
		player_camera.cull_mask = DEFAULT_CAMERA_RENDER_MASK & ~LOCAL_PLAYER_MODEL_LAYER
		player_camera.current = true

		camera_effect_pivot.add_child(
			player_camera
		)

		if inventory.size() > 0:
			active_inv_index = clampi(
				active_inv_index,
				0,
				inventory.size() - 1
			)

			equip_weapon(
				inventory[active_inv_index]
			)
		else:
			active_inv_index = -1

			equip_weapon(
				WeaponType.FISTS
			)

	# ============================================================
	# REMOTE PLAYER
	# ============================================================

	else:
		var remote_model := build_high_detail_humanoid(
			p_root,
			Color(0.16, 0.19, 0.16),
			Color(0.08, 0.10, 0.11),
			Color(0.72, 0.50, 0.38),
			Color(0.10, 0.12, 0.12)
		)
		p_root.set_meta("player_model", remote_model)


@rpc("unreliable", "any_peer")
func sync_player_transform(
	id: int,
	pos: Vector3,
	rot_y: float,
	cam_x: float,
	lean: float,
	driving: bool = false
) -> void:
	if (
		id != local_player_id
		and players.has(id)
	):
		var player_data: Dictionary = (
			players[id]
		)

		if is_instance_valid(
			player_data["root"]
		):
			var root: CharacterBody3D = (
				player_data["root"]
			)

			var pivot: Node3D = (
				player_data["pivot"]
			)

			root.global_position = (
				root.global_position.lerp(
					pos,
					0.35
				)
			)

			root.rotation.y = lerp_angle(
				root.rotation.y,
				rot_y,
				0.35
			)
			var remote_model := root.get_meta("player_model", null) as Node3D
			if is_instance_valid(remote_model):
				remote_model.scale = remote_model.scale.lerp(Vector3(0.78, 0.45, 0.78) if driving else Vector3.ONE, 0.35)
				remote_model.position = remote_model.position.lerp(Vector3(0.0, -0.15, 0.0) if driving else Vector3.ZERO, 0.35)
				remote_model.rotation.x = lerpf(remote_model.rotation.x, deg_to_rad(8.0) if driving else 0.0, 0.35)

			pivot.rotation.x = lerp_angle(
				pivot.rotation.x,
				cam_x,
				0.35
			)

			pivot.rotation_degrees.z = lerp(
				pivot.rotation_degrees.z,
				lean,
				0.35
			)


# ============================================================
# WEAPON INVENTORY
# ============================================================

func get_current_weapon() -> WeaponType:
	if (
		active_inv_index < 0
		or active_inv_index >= inventory.size()
	):
		return WeaponType.FISTS

	return inventory[
		active_inv_index
	]


func switch_weapon_slot(idx: int) -> void:
	if (
		is_reloading
		or is_pumping
		or is_equipping
	):
		return

	if idx == -1:
		active_inv_index = -1
		equip_weapon(
			WeaponType.FISTS
		)
		return

	if (
		idx >= 0
		and idx < inventory.size()
	):
		active_inv_index = idx

		equip_weapon(
			inventory[
				active_inv_index
			]
		)


func cycle_weapon_slot(direction: int) -> void:
	if is_reloading or is_pumping or is_equipping:
		return
	if inventory.is_empty():
		switch_weapon_slot(-1)
		return
	if active_inv_index < 0 or active_inv_index >= inventory.size():
		active_inv_index = 0 if direction >= 0 else inventory.size() - 1
	else:
		active_inv_index = posmod(active_inv_index + direction, inventory.size())
	equip_weapon(inventory[active_inv_index])


func toggle_fire_mode() -> void:
	var active_w: WeaponType = (
		get_current_weapon()
	)

	if active_w == WeaponType.AK47:
		if (
			current_fire_mode
			== FireMode.FULL_AUTO
		):
			current_fire_mode = FireMode.BURST
		elif (
			current_fire_mode
			== FireMode.BURST
		):
			current_fire_mode = FireMode.SEMI_AUTO
		else:
			current_fire_mode = FireMode.FULL_AUTO

		update_hud_display()


func equip_weapon(w_type: WeaponType) -> void:
	is_aiming = false
	aim_button_down = false

	cam_recoil_rot = Vector3.ZERO
	cam_recoil_vel = Vector3.ZERO
	gun_recoil_offset = Vector3.ZERO
	gun_recoil_vel = Vector3.ZERO
	gun_rot_recoil = Vector3.ZERO
	gun_rot_vel = Vector3.ZERO

	if is_instance_valid(
		flashlight_node
	):
		flashlight_node.queue_free()
		flashlight_node = null

	if is_instance_valid(
		weapon_rig
	):
		weapon_rig.queue_free()

	var weapon_parent: Node3D = camera_effect_pivot if is_instance_valid(camera_effect_pivot) else camera_pivot
	build_procedural_weapon_mesh(
		weapon_parent,
		true,
		w_type
	)

	if (
		w_type == WeaponType.REMINGTON870
		or w_type == WeaponType.SNIPER_R700
	):
		current_fire_mode = (
			FireMode.SEMI_AUTO
		)
	elif w_type == WeaponType.AK47:
		current_fire_mode = (
			FireMode.FULL_AUTO
		)

	update_hud_display()
	trigger_equip_animation()


# ============================================================
# DROP WEAPON
# ============================================================

func drop_current_weapon_to_ground() -> void:
	if (
		not is_instance_valid(local_player_node)
		or is_dead
		or is_driving
		or get_current_weapon() == WeaponType.FISTS
	):
		return

	var curr_w: WeaponType = (
		get_current_weapon()
	)

	var ammo_data: Dictionary = (
		weapon_ammo_map[curr_w]
	)

	inventory.remove_at(
		active_inv_index
	)

	var drop_direction := -local_player_node.global_transform.basis.z
	drop_direction.y = 0.0
	if drop_direction.length_squared() < 0.001:
		drop_direction = Vector3.FORWARD
	drop_direction = drop_direction.normalized()
	var drop_origin: Vector3 = (
		local_player_node.global_position
		+ Vector3.UP * 0.95
		+ drop_direction * 0.85
	)

	var throw_impulse: Vector3 = (
		drop_direction * 3.4
		+ Vector3.UP * 2.4
		+ local_player_node.velocity * 0.2
	)

	rpc(
		"net_spawn_weapon_drop_item",
		drop_origin,
		throw_impulse,
		curr_w,
		int(ammo_data["current"]),
		int(ammo_data["reserve"])
	)

	if inventory.size() > 0:
		active_inv_index = clampi(active_inv_index, 0, inventory.size() - 1)
		equip_weapon(inventory[active_inv_index])
	else:
		active_inv_index = -1

		equip_weapon(
			WeaponType.FISTS
		)


@rpc("any_peer", "call_local")
func net_spawn_weapon_drop_item(
	pos: Vector3,
	impulse: Vector3,
	w_type: WeaponType,
	curr_ammo: int,
	res_ammo: int
) -> void:
	var item := RigidBody3D.new()

	item.mass = 4.0
	item.collision_layer = 1
	item.collision_mask = 1
	item.linear_damp = 0.12
	item.angular_damp = 1.8

	item.set_meta(
		"is_weapon_pickup",
		true
	)

	item.set_meta(
		"weapon_type",
		w_type
	)

	item.set_meta(
		"curr_ammo",
		curr_ammo
	)

	item.set_meta(
		"res_ammo",
		res_ammo
	)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()

	box.size = Vector3(
		0.22,
		0.18,
		0.9
	)

	col.shape = box
	item.add_child(col)

	var pivot := Node3D.new()
	item.add_child(pivot)

	build_procedural_weapon_mesh(
		pivot,
		false,
		w_type
	)

	add_child(item)
	item.global_position = pos
	item.apply_central_impulse(impulse)
# ============================================================
# INTERACTION
# ============================================================

func attempt_interact_or_pickup() -> void:
	if (
		not is_instance_valid(player_camera)
		or not is_instance_valid(local_player_node)
	):
		return

	var space: PhysicsDirectSpaceState3D = (
		get_world_3d().direct_space_state
	)

	var center: Vector2 = (
		Vector2(
			get_viewport().get_visible_rect().size
		) / 2.0
	)

	var origin: Vector3 = (
		player_camera.project_ray_origin(
			center
		)
	)

	var end: Vector3 = (
		origin
		+ player_camera.project_ray_normal(
			center
		) * 4.0
	)

	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(
			origin,
			end
		)
	)

	query.exclude = [
		local_player_node.get_rid()
	]
	for child in local_player_node.get_children():
		if child is Area3D:
			query.exclude.append(child.get_rid())

	var res: Dictionary = (
		space.intersect_ray(query)
	)

	if (
		not res.is_empty()
		and res.has("collider")
		and res["collider"] is RigidBody3D
	):
		var target: RigidBody3D = (
			res["collider"]
			as RigidBody3D
		)

		if target.has_meta(
			"is_weapon_pickup"
		):
			var w_type: WeaponType = (
				target.get_meta("weapon_type")
			)

			var c_ammo: int = int(
				target.get_meta(
					"curr_ammo"
				)
			)

			var r_ammo: int = int(
				target.get_meta(
					"res_ammo"
				)
			)

			if not inventory.has(w_type):
				inventory.append(w_type)

			weapon_ammo_map[w_type][
				"current"
			] = c_ammo

			weapon_ammo_map[w_type][
				"reserve"
			] = r_ammo

			active_inv_index = (
				inventory.find(w_type)
			)

			equip_weapon(
				w_type
			)

			target.queue_free()

		elif target.has_meta(
			"is_ammo_box"
		):
			var current_weapon: WeaponType = (
				get_current_weapon()
			)

			if weapon_ammo_map.has(
				current_weapon
			):
				weapon_ammo_map[
					current_weapon
				]["reserve"] += 60

				update_hud_display()

				target.queue_free()

		elif not target.has_meta(
			"is_static_prop"
		):
			held_object = target

			held_object_distance = (
				player_camera.global_position.distance_to(
					held_object.global_position
				)
			)

			held_object.gravity_scale = 0.0

			object_target_rotation = (
				held_object.global_transform.basis
			)


func drop_held_object() -> void:
	if held_object != null:
		held_object.gravity_scale = 1.0
		held_object = null
		is_rotating_object = false


# ============================================================
# FLASHLIGHT / NIGHT VISION
# ============================================================

func toggle_flashlight() -> void:
	flashlight_enabled = not flashlight_enabled
	if is_instance_valid(flashlight_node):
		flashlight_node.visible = flashlight_enabled


func toggle_night_vision() -> void:
	night_vision_enabled = (
		not night_vision_enabled
	)

	if is_instance_valid(
		night_vision_overlay
	):
		night_vision_overlay.visible = (
			night_vision_enabled
		)


# ============================================================
# WEAPON FIRE
# ============================================================

# ============================================================
# FIXED FIRE & ALWAYS-ON ENHANCED TRACERS
# ============================================================

func execute_weapon_fire() -> void:
	var curr_w: WeaponType = get_current_weapon()
	if curr_w == WeaponType.FISTS: return
	if is_inspecting or is_reloading or is_pumping: return
	if not weapon_ammo_map.has(curr_w): return

	var ammo: Dictionary = weapon_ammo_map[curr_w]
	if int(ammo["current"]) <= 0 and not infinite_ammo:
		burst_count_remaining = 0
		execute_weapon_reload()
		return

	var player_velocity_before_fire: Vector3 = Vector3.ZERO
	if is_instance_valid(local_player_node):
		player_velocity_before_fire = local_player_node.velocity

	if not infinite_ammo:
		ammo["current"] = int(ammo["current"]) - 1

	update_hud_display()

	match curr_w:
		WeaponType.AK47:
			fire_cooldown = 0.095
			
			# Weapon visual kick & casing ejection
			apply_recoil_impulse(Vector3(0.0, 0.045, 0.09), Vector3(0.08, 0.025, 0.01))
			animate_ejection_slot_recoil()
			spawn_ejected_shell_casing()
			
		WeaponType.REMINGTON870:
			fire_cooldown = 1.15
			apply_recoil_impulse(Vector3(0.0, 0.12, 0.22), Vector3(0.18, 0.08, 0.03))
			execute_delayed_shotgun_pump()
		WeaponType.SNIPER_R700:
			fire_cooldown = 1.45
			apply_recoil_impulse(Vector3(0.0, 0.22, 0.38), Vector3(0.32, 0.06, 0.05))
			execute_sniper_bolt_cycle()

	var recoil_profile := get_weapon_recoil_profile(curr_w)
	weapon_recoil_recovery_speed = float(recoil_profile.get("recovery_speed", 16.0))
	var camera_kick := float(recoil_profile.get("pitch_kick", 0.0))
	if is_aiming:
		camera_kick *= float(recoil_profile.get("ads_mult", 1.0))
	camera_pitch = clampf(
		camera_pitch + camera_kick,
		deg_to_rad(-camera_pitch_limit_degrees),
		deg_to_rad(camera_pitch_limit_degrees)
	)

	trigger_muzzle_flash_and_smoke()
	var profile: Dictionary = get_weapon_ballistics(curr_w)
	if profile.is_empty(): return

	var pellet_count: int = int(profile.get("pellets", 1))
	var muzzle_origin: Vector3 = muzzle_flash_marker.global_position if is_instance_valid(muzzle_flash_marker) else player_camera.global_position
	var camera_origin: Vector3 = player_camera.global_position
	var camera_forward: Vector3 = -player_camera.global_transform.basis.z
	var spread_degrees: float = get_realistic_spread_degrees(curr_w)

	weapon_heat_level = minf(weapon_heat_level + 0.085, 1.0)
	
	# Weapon recoil is angular only; firing never adds velocity to the player.

	# ALWAYS SHOW TRACER ON EVERY SHOT AS REQUESTED
	var should_show_tracer: bool = true
	var shot_body_impulses: Dictionary = {}
	var max_body_impulse_per_shot: float = 12.0

	for pellet_index in range(pellet_count):
		var shot_camera_direction: Vector3 = get_spread_direction(
			camera_forward,
			player_camera.global_transform.basis.x,
			player_camera.global_transform.basis.y,
			spread_degrees
		)

		var aim_distance: float = float(profile["max_range"])
		var aim_point: Vector3 = camera_origin + shot_camera_direction * aim_distance
		var muzzle_direction: Vector3 = (aim_point - muzzle_origin).normalized()

		var result: Dictionary = trace_ballistic_projectile(muzzle_origin, muzzle_direction, profile)
		var impact_position: Vector3 = result["position"]
		var did_hit: bool = result["hit"]

		if should_show_tracer and pellet_index == 0:
			spawn_bullet_tracer(muzzle_origin, impact_position)

		if not did_hit: continue

		var hit_normal: Vector3 = result["normal"]
		var collider: Object = result["collider"]
		var hit_distance: float = float(result["distance"])
		var hit_info: Dictionary = resolve_damage_hit(collider)

		rpc("net_spawn_impact", impact_position, hit_normal)

		var base_damage: float = float(profile["damage"])
		var minimum_damage: float = float(profile["minimum_damage"])
		var max_range: float = float(profile["max_range"])
		var effective_range: float = float(profile["effective_range"])
		var damage_ratio: float = 1.0

		if hit_distance > effective_range:
			var falloff_range: float = maxf(max_range - effective_range, 0.001)
			var falloff_t: float = clampf((hit_distance - effective_range) / falloff_range, 0.0, 1.0)
			var minimum_ratio: float = clampf(minimum_damage / maxf(base_damage, 0.001), 0.0, 1.0)
			damage_ratio = lerpf(1.0, minimum_ratio, falloff_t)

		# net_damage_target applies the hit-zone multiplier, so keep this value
		# limited to weapon damage and range falloff to avoid double scaling.
		var final_damage: float = base_damage * damage_ratio
		var target: Variant = hit_info.get("target")

		if target != null:
			trigger_hitmarker()
			spawn_blood_impact_particles(impact_position, hit_normal)
			var impulse_strength: float = float(profile["impact_force"])
			var hit_impulse: Vector3 = muzzle_direction * impulse_strength
			if target is Node:
				rpc("net_damage_target", target.get_path(), final_damage, hit_impulse, str(hit_info.get("zone", "body")))
		elif collider is RigidBody3D:
			var body: RigidBody3D = collider as RigidBody3D
			var body_id: int = body.get_instance_id()
			var applied_impulse: float = float(shot_body_impulses.get(body_id, 0.0))
			var remaining_impulse: float = maxf(max_body_impulse_per_shot - applied_impulse, 0.0)
			var impulse_strength: float = minf(float(profile["impact_force"]), remaining_impulse)
			if impulse_strength > 0.0:
				var impact_offset: Vector3 = impact_position - body.global_position
				body.apply_impulse(muzzle_direction * impulse_strength, impact_offset)
				shot_body_impulses[body_id] = applied_impulse + impulse_strength
			if (
				body.has_meta("is_explosive")
				and not bool(body.get_meta("explosion_triggered", false))
			):
				rpc("net_trigger_explosion", body.get_path())

	if is_instance_valid(local_player_node) and not is_dead:
		# Firing affects the weapon and targets, never the shooter's movement velocity.
		local_player_node.velocity = player_velocity_before_fire
		
		
func get_weapon_recoil_profile(w_type: WeaponType) -> Dictionary:
	match w_type:
		WeaponType.AK47: return {"pitch_kick": 0.038, "ads_mult": 0.58, "recovery_speed": 14.0}
		WeaponType.REMINGTON870: return {"pitch_kick": 0.072, "ads_mult": 0.52, "recovery_speed": 10.0}
		WeaponType.SNIPER_R700: return {"pitch_kick": 0.095, "ads_mult": 0.36, "recovery_speed": 8.0} 
		_: return {"pitch_kick": 0.015, "ads_mult": 0.50, "recovery_speed": 16.0}
# ============================================================
# BALLISTICS
# ============================================================

func get_weapon_ballistics(
	w_type: WeaponType
) -> Dictionary:
	match w_type:
		WeaponType.AK47:
			return {
				"muzzle_velocity": 715.0,
				"drag": 0.00011,
				"max_range": 260.0,
				"damage": 39.0,
				"minimum_damage": 20.0,
				"effective_range": 120.0,
				"hip_spread": 1.25,
				"ads_spread": 0.24,
				"crouch_spread": 0.16,
				"moving_spread": 2.10,
				"tracer_every": 4,
				"impact_force": 22.0,
				"gravity_scale": 1.0
			}

		WeaponType.REMINGTON870:
			return {
				"muzzle_velocity": 420.0,
				"drag": 0.00028,
				"max_range": 45.0,
				"damage": 22.0,            # High base damage per pellet at close range
				"minimum_damage": 3.0,     # Low minimum damage at max range
				"effective_range": 6.0,    # Distance before falloff begins
				"hip_spread": 4.8,
				"ads_spread": 3.4,
				"crouch_spread": 3.0,
				"moving_spread": 6.0,
				"tracer_every": 999999,
				"impact_force": 24.0,
				"gravity_scale": 1.0,
				"pellets": 10              # 10 pellets total
			}

		WeaponType.SNIPER_R700:
			return {
				"muzzle_velocity": 790.0,
				"drag": 0.000075,
				"max_range": 500.0,
				"damage": 118.0,
				"minimum_damage": 78.0,
				"effective_range": 260.0,
				"hip_spread": 1.8,
				"ads_spread": 0.045,
				"crouch_spread": 0.028,
				"moving_spread": 3.5,
				"tracer_every": 3,
				"impact_force": 55.0,
				"gravity_scale": 1.0
			}

		_:
			return {
				"muzzle_velocity": 0.0,
				"drag": 0.0,
				"max_range": 0.0,
				"damage": 0.0,
				"minimum_damage": 0.0,
				"effective_range": 0.0,
				"hip_spread": 0.0,
				"ads_spread": 0.0,
				"crouch_spread": 0.0,
				"moving_spread": 0.0,
				"tracer_every": 999999,
				"impact_force": 0.0,
				"gravity_scale": 1.0
			}


func get_spread_direction(
	forward: Vector3,
	right: Vector3,
	up: Vector3,
	spread_degrees: float
) -> Vector3:
	var spread_radians: float = deg_to_rad(
		maxf(
			spread_degrees,
			0.0
		)
	)

	if spread_radians <= 0.00001:
		return forward.normalized()

	var random_angle: float = randf_range(
		0.0,
		TAU
	)

	var random_radius: float = (
		sqrt(randf())
		* tan(spread_radians)
	)

	var offset: Vector3 = (
		right * cos(random_angle)
		* random_radius
		+ up * sin(random_angle)
		* random_radius
	)

	return (
		forward + offset
	).normalized()


func get_realistic_spread_degrees(
	w_type: WeaponType
) -> float:
	if not is_instance_valid(
		local_player_node
	):
		return 0.0

	var profile: Dictionary = (
		get_weapon_ballistics(
			w_type
		)
	)

	var spread: float = float(
		profile["hip_spread"]
	)

	if is_aiming:
		spread = float(
			profile["ads_spread"]
		)

	if is_crouching:
		spread = minf(
			spread,
			float(
				profile["crouch_spread"]
			)
		)

	var velocity_horizontal: float = (
		Vector2(
			local_player_node.velocity.x,
			local_player_node.velocity.z
		).length()
	)

	if velocity_horizontal > 0.15:
		var movement_ratio: float = clampf(
			velocity_horizontal
			/ maxf(
				sprint_speed,
				0.1
			),
			0.0,
			1.0
		)

		spread += (
			float(
				profile["moving_spread"]
			)
			* movement_ratio
		)

	spread += minf(
		gun_recoil_offset.length()
		* 12.0,
		1.25
	)

	spread += weapon_heat_level * 0.30

	return maxf(
		spread,
		0.001
	)


# ============================================================
# DAMAGE
# ============================================================

func register_cqb_player_kill() -> void:
	if current_map_type != MapType.CQB_ARENA:
		return
	cqb_score_player += 1
	update_hud_display()


@rpc("any_peer", "call_local")
func net_damage_target(
	target_path: NodePath,
	amount: float,
	hit_impulse: Vector3,
	hit_zone: String = "body"
) -> void:
	var target: Node = get_node_or_null(target_path)

	if target == null or not is_instance_valid(target):
		return

	var zone_multiplier: float = 1.0

	match hit_zone:
		"head":
			zone_multiplier = 2.10
		"chest":
			zone_multiplier = 0.92
		"legs":
			zone_multiplier = 0.68
		"body":
			zone_multiplier = 1.0
		_:
			zone_multiplier = 1.0

	var final_damage: float = amount * zone_multiplier
	var is_headshot: bool = (hit_zone == "head")

	# Trigger dynamic 3D damage indicator
	spawn_floating_damage_number(target.global_position + Vector3(0, 1.2, 0), final_damage, is_headshot)

	# Local Player Damage Logic
	if target == local_player_node:
		if god_mode:
			return

		# Health is the only player durability system.
		health = maxf(health - final_damage, 0.0)

		update_hud_display()

		if health <= 0.0 and not is_dead:
			die_and_spawn_ragdoll(target.global_position, hit_impulse, hit_zone)

		return

	# NPC Damage Logic
	if target.has_meta("is_npc"):
		if bool(target.get_meta("ragdoll_spawned", false)):
			return

		var current_hp: float = float(target.get_meta("hp", 100.0))
		current_hp -= final_damage
		target.set_meta("hp", current_hp)

		if current_hp <= 0.0:
			target.set_meta("ragdoll_spawned", true)
			spawn_ragdoll_at(
				target.global_position,
				Color(0.26, 0.30, 0.24),
				hit_impulse,
				hit_zone
			)
			target.queue_free()
			register_cqb_player_kill()
# ============================================================
# TRACE & BALLISTIC PROJECTILE SYSTEM
# ============================================================

func trace_ballistic_projectile(
	origin: Vector3,
	direction: Vector3,
	profile: Dictionary
) -> Dictionary:
	var muzzle_velocity: float = float(
		profile.get(
			"muzzle_velocity",
			0.0
		)
	)

	var drag: float = float(
		profile.get(
			"drag",
			0.0
		)
	)

	var max_range: float = float(
		profile.get(
			"max_range",
			0.0
		)
	)

	var gravity_scale: float = float(
		profile.get(
			"gravity_scale",
			1.0
		)
	)

	if (
		muzzle_velocity <= 0.0
		or max_range <= 0.0
	):
		return {
			"hit": false,
			"position": origin,
			"normal": Vector3.UP,
			"collider": null,
			"distance": 0.0,
			"velocity": Vector3.ZERO
		}

	var projectile_position: Vector3 = origin

	var velocity: Vector3 = direction.normalized() * muzzle_velocity

	var travelled: float = 0.0
	var elapsed: float = 0.0

	var max_time: float = (
		max_range
		/ maxf(
			muzzle_velocity,
			1.0
		)
	) * 1.75

	var space: PhysicsDirectSpaceState3D = (
		get_world_3d().direct_space_state
	)

	while (
		travelled < max_range
		and elapsed < max_time
		and velocity.length() > 1.0
	):
		var speed: float = velocity.length()

		var gravity_acceleration: Vector3 = Vector3(
			0.0,
			-BALLISTIC_GRAVITY * gravity_scale,
			0.0
		)

		var drag_acceleration: Vector3 = Vector3.ZERO

		if (
			speed > 0.01
			and drag > 0.0
		):
			drag_acceleration = (
				-velocity.normalized()
				* speed
				* speed
				* drag
			)

		var acceleration: Vector3 = (
			gravity_acceleration
			+ drag_acceleration
		)

		var next_velocity: Vector3 = (
			velocity
			+ acceleration * BALLISTIC_DT
		)

		var next_position: Vector3 = (
			projectile_position
			+ (
				velocity
				+ next_velocity
			) * 0.5 * BALLISTIC_DT
		)

		var query: PhysicsRayQueryParameters3D = (
			PhysicsRayQueryParameters3D.create(
				projectile_position,
				next_position
			)
		)

		query.collision_mask = BULLET_COLLISION_MASK
		query.collide_with_bodies = true
		query.collide_with_areas = true

		if is_instance_valid(
			local_player_node
		):
			query.exclude.append(
				local_player_node.get_rid()
			)

			for child in (
				local_player_node.get_children()
			):
				if child is Area3D:
					query.exclude.append(
						child.get_rid()
					)

		if is_instance_valid(
			held_object
		):
			query.exclude.append(
				held_object.get_rid()
			)

		var result: Dictionary = (
			space.intersect_ray(query)
		)

		if not result.is_empty():
			var hit_position: Vector3 = result["position"]

			var hit_segment_distance: float = (
				projectile_position.distance_to(
					hit_position
				)
			)

			travelled += hit_segment_distance

			return {
				"hit": true,
				"position": hit_position,
				"normal": result["normal"],
				"collider": result["collider"],
				"distance": travelled,
				"velocity": next_velocity
			}

		var travel_segment_distance: float = (
			projectile_position.distance_to(
				next_position
			)
		)

		travelled += travel_segment_distance

		projectile_position = next_position

		velocity = next_velocity

		elapsed += BALLISTIC_DT

	return {
		"hit": false,
		"position": projectile_position,
		"normal": Vector3.UP,
		"collider": null,
		"distance": travelled,
		"velocity": velocity
	}


# ============================================================
# HITMARKER
# ============================================================

func trigger_hitmarker() -> void:
	if not is_instance_valid(
		hitmarker_ui
	):
		return

	hitmarker_ui.visible = true

	hitmarker_ui.modulate = Color(
		1.0,
		0.2,
		0.2,
		1.0
	)

	var tw: Tween = create_tween()

	tw.tween_property(
		hitmarker_ui,
		"modulate:a",
		0.0,
		0.18
	)

	tw.chain().tween_callback(
		func() -> void:
			if is_instance_valid(
				hitmarker_ui
			):
				hitmarker_ui.visible = false
	)


func animate_ejection_slot_recoil() -> void:
	if not is_instance_valid(
		bolt_carrier_node
	):
		return

	var tw: Tween = (
		create_tween()
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_OUT)
	)

	tw.tween_property(
		bolt_carrier_node,
		"position:z",
		0.07,
		0.04
	)

	tw.chain().tween_property(
		bolt_carrier_node,
		"position:z",
		0.0,
		0.05
	)


# ============================================================
# BULLET TRACER
# ============================================================

func spawn_bullet_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	execute_weapon_ballistics(from_pos, to_pos, false)

# BLOOD
# ============================================================

func spawn_blood_impact_particles(
	pos: Vector3,
	normal: Vector3
) -> void:
	var hit_node := Node3D.new()

	hit_node.position = pos

	get_tree().root.add_child(
		hit_node
	)

	var mat := StandardMaterial3D.new()

	mat.albedo_color = Color(
		0.5,
		0.02,
		0.02
	)

	mat.roughness = 0.8

	for i in range(16):
		var p := MeshInstance3D.new()
		var sphere := SphereMesh.new()

		sphere.radius = randf_range(
			0.02,
			0.045
		)

		sphere.height = (
			sphere.radius * 2.0
		)

		p.mesh = sphere
		p.material_override = mat

		hit_node.add_child(
			p
		)

		var dir: Vector3 = (
			normal
			+ Vector3(
				randf_range(-0.8, 0.8),
				randf_range(-0.8, 0.8),
				randf_range(-0.8, 0.8)
			)
		).normalized()

		var dist: float = randf_range(
			0.3,
			0.8
		)

		var tw: Tween = (
			p.create_tween()
			.set_parallel(true)
		)

		tw.tween_property(
			p,
			"position",
			dir * dist
			+ Vector3(
				0.0,
				-0.2,
				0.0
			),
			0.3
		)

		tw.tween_property(
			p,
			"scale",
			Vector3.ZERO,
			0.3
		)

	get_tree().create_timer(
		0.35
	).timeout.connect(
		hit_node.queue_free
	)


# ============================================================
# FIST PUNCH
# ============================================================

func execute_fist_punch() -> void:
	fire_cooldown = 0.38

	var tw: Tween = (
		create_tween()
		.set_trans(Tween.TRANS_QUAD)
	)

	tw.tween_property(
		weapon_mesh_root,
		"position:z",
		-0.5,
		0.12
	)

	tw.parallel().tween_property(
		weapon_mesh_root,
		"rotation_degrees:y",
		-25.0,
		0.12
	)

	tw.chain().tween_property(
		weapon_mesh_root,
		"position:z",
		-0.32,
		0.15
	)

	tw.parallel().tween_property(
		weapon_mesh_root,
		"rotation_degrees:y",
		0.0,
		0.15
	)

	var space: PhysicsDirectSpaceState3D = (
		get_world_3d().direct_space_state
	)

	var center: Vector2 = (
		Vector2(
			get_viewport().get_visible_rect().size
		) / 2.0
	)

	var ray_o: Vector3 = (
		player_camera.project_ray_origin(
			center
		)
	)

	var ray_dir: Vector3 = (
		player_camera.project_ray_normal(
			center
		)
	)

	var ray_e: Vector3 = (
		ray_o + ray_dir * 2.2
	)

	var q: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(
			ray_o,
			ray_e
		)
	)

	q.exclude = [
		local_player_node.get_rid()
	]
	for child in local_player_node.get_children():
		if child is Area3D:
			q.exclude.append(child.get_rid())

	var res: Dictionary = (
		space.intersect_ray(q)
	)

	if (
		not res.is_empty()
		and res.has("collider")
	):
		var collider: Object = (
			res["collider"]
		)

		if (
			collider is CharacterBody3D
			or (
				collider != null
				and collider.has_meta("is_npc")
			)
		):
			trigger_hitmarker()

			spawn_blood_impact_particles(
				res["position"],
				res["normal"]
			)

			if collider is Node:
				rpc(
					"net_damage_target",
					(
						collider
						as Node
					).get_path(),
					25.0,
					ray_dir * 12.0,
					"body"
				)


# ============================================================
# SHOTGUN PUMP
# ============================================================

func execute_delayed_shotgun_pump() -> void:
	is_pumping = true

	get_tree().create_timer(0.22).timeout.connect(
		func() -> void:
			if not is_instance_valid(weapon_mesh_root):
				is_pumping = false
				return

			var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE)
			
			# Slight upward tilt during pump
			tw.tween_property(weapon_mesh_root, "rotation_degrees:x", 10.0, 0.10)

			# Slide pump backward safely (from rest -0.32 to -0.22, staying in front of the receiver)
			if is_instance_valid(charging_handle_node):
				tw.parallel().tween_property(charging_handle_node, "position:z", -0.22, 0.10)

			tw.chain().tween_callback(
				func() -> void:
					spawn_ejected_shell_casing()
			)

			# Return pump forward to rest position (-0.32)
			tw.chain().tween_property(weapon_mesh_root, "rotation_degrees:x", 0.0, 0.10)
			if is_instance_valid(charging_handle_node):
				tw.parallel().tween_property(charging_handle_node, "position:z", -0.32, 0.10)

			tw.chain().tween_callback(
				func() -> void:
					is_pumping = false
			)
	)
	
# ============================================================
# SNIPER BOLT
# ============================================================

func execute_sniper_bolt_cycle() -> void:
	is_pumping = true

	get_tree().create_timer(
		0.12
	).timeout.connect(
		func() -> void:
			if (
				not is_instance_valid(
					weapon_mesh_root
				)
				or not is_instance_valid(
					charging_handle_node
				)
			):
				is_pumping = false
				return

			var tw: Tween = (
				create_tween()
				.set_trans(Tween.TRANS_SINE)
				.set_ease(Tween.EASE_IN_OUT)
			)

			tw.tween_property(
				charging_handle_node,
				"rotation_degrees:z",
				65.0,
				0.12
			)

			tw.parallel().tween_property(
				weapon_mesh_root,
				"rotation_degrees:z",
				-15.0,
				0.12
			)

			tw.chain().tween_property(
				charging_handle_node,
				"position:z",
				0.12,
				0.14
			)

			if is_instance_valid(
				bolt_carrier_node
			):
				tw.parallel().tween_property(
					bolt_carrier_node,
					"position:z",
					0.12,
					0.14
				)

			tw.chain().tween_callback(
				func() -> void:
					spawn_ejected_shell_casing()
			)

			tw.chain().tween_interval(
				0.08
			)

			tw.chain().tween_property(
				charging_handle_node,
				"position:z",
				0.0,
				0.14
			)

			if is_instance_valid(
				bolt_carrier_node
			):
				tw.parallel().tween_property(
					bolt_carrier_node,
					"position:z",
					0.0,
					0.14
				)

			tw.chain().tween_property(
				charging_handle_node,
				"rotation_degrees:z",
				0.0,
				0.12
			)

			tw.parallel().tween_property(
				weapon_mesh_root,
				"rotation_degrees:z",
				0.0,
				0.12
			)

			tw.chain().tween_callback(
				func() -> void:
					is_pumping = false
			)
	)


# ============================================================
# ENHANCED CAMERA & WEAPON RECOIL
# ============================================================

func apply_recoil_impulse(pos_impulse: Vector3, rot_impulse: Vector3) -> void:
	# Apply visual gun recoil offsets locally only
	gun_recoil_vel += pos_impulse * 1.6
	gun_rot_vel += rot_impulse * 1.5

	# Keep firing recoil on the weapon; do not translate the player's camera.
	
#============================================================
# MUZZLE FLASH
# ============================================================

func trigger_muzzle_flash_and_smoke() -> void:
	var current_weapon: WeaponType = (
		get_current_weapon()
	)

	if current_weapon == WeaponType.FISTS:
		return

	trigger_realistic_muzzle_effects(
		current_weapon
	)


func trigger_realistic_muzzle_effects(
	weapon_type: WeaponType
) -> void:
	if weapon_type == WeaponType.FISTS:
		return

	if not is_instance_valid(
		muzzle_flash_marker
	):
		return


	var origin: Vector3 = (
		muzzle_flash_marker.global_position
	)

	var forward: Vector3 = (
		-muzzle_flash_marker.global_transform.basis.z
	)

	# ============================================================
	# DYNAMIC MUZZLE LIGHT
	# ============================================================

	if is_instance_valid(
		muzzle_flash_light
	):
		muzzle_flash_light.visible = true

		var light_energy: float = 6.0
		var light_range: float = 10.0

		match weapon_type:
			WeaponType.AK47:
				light_energy = 7.5
				light_range = 11.0

			WeaponType.REMINGTON870:
				light_energy = 11.0
				light_range = 13.0

			WeaponType.SNIPER_R700:
				light_energy = 13.0
				light_range = 15.0

		muzzle_flash_light.omni_range = (
			light_range
		)

		muzzle_flash_light.light_energy = (
			light_energy
		)

		if is_instance_valid(muzzle_light_tween) and muzzle_light_tween.is_running():
			muzzle_light_tween.kill()
		muzzle_light_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		muzzle_light_tween.tween_interval(0.018)
		muzzle_light_tween.tween_property(
			muzzle_flash_light,
			"light_energy",
			0.0,
			0.060
		)

		muzzle_light_tween.tween_callback(
			func() -> void:
				if is_instance_valid(
					muzzle_flash_light
				):
					muzzle_flash_light.visible = false
		)

	# ============================================================
	# FLASH MESH
	# ============================================================

	if is_instance_valid(
		muzzle_flash_mesh
	):
		muzzle_flash_mesh.visible = true
		if is_instance_valid(muzzle_mesh_tween) and muzzle_mesh_tween.is_running():
			muzzle_mesh_tween.kill()
		muzzle_flash_mesh.scale = Vector3.ONE

		var flash_scale: float = 1.0

		match weapon_type:
			WeaponType.AK47:
				flash_scale = 0.85

			WeaponType.REMINGTON870:
				flash_scale = 1.35

			WeaponType.SNIPER_R700:
				flash_scale = 1.55

		muzzle_flash_mesh.scale = Vector3(flash_scale, flash_scale * 1.7, flash_scale)
		muzzle_mesh_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		muzzle_mesh_tween.tween_interval(0.018)
		muzzle_mesh_tween.tween_property(
			muzzle_flash_mesh,
			"scale",
			Vector3(flash_scale * 0.18, flash_scale * 0.28, flash_scale * 0.18),
			0.052
		)

		muzzle_mesh_tween.tween_callback(
			func() -> void:
				if is_instance_valid(
					muzzle_flash_mesh
				):
					muzzle_flash_mesh.visible = false
		)

	# ============================================================
	# FLASH PARTICLES
	# ============================================================

	var particle_count: int = 14

	match weapon_type:
		WeaponType.AK47:
			particle_count = 11

		WeaponType.REMINGTON870:
			particle_count = 24

		WeaponType.SNIPER_R700:
			particle_count = 28

	spawn_realistic_muzzle_particles(
		origin,
		forward,
		particle_count
	)

	# ============================================================
	# SMOKE
	# ============================================================

	var smoke_amount: int = 8

	match weapon_type:
		WeaponType.AK47:
			smoke_amount = 8

		WeaponType.REMINGTON870:
			smoke_amount = 15

		WeaponType.SNIPER_R700:
			smoke_amount = 18

	spawn_realistic_muzzle_smoke(
		origin,
		forward,
		smoke_amount
	)


func spawn_realistic_muzzle_particles(
	origin: Vector3,
	forward: Vector3,
	amount: int
) -> void:
	var particles := GPUParticles3D.new()

	particles.amount = amount
	particles.lifetime = 0.11
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.65
	particles.local_coords = false

	var process_mat := ParticleProcessMaterial.new()

	process_mat.direction = forward
	process_mat.spread = 22.0
	process_mat.initial_velocity_min = 5.0
	process_mat.initial_velocity_max = 13.0
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.025
	process_mat.scale_max = 0.065

	particles.process_material = process_mat

	var flash_mesh := SphereMesh.new()

	flash_mesh.radius = 0.035
	flash_mesh.height = 0.07

	var flash_material := StandardMaterial3D.new()

	flash_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	flash_material.albedo_color = Color(
		1.0,
		0.52,
		0.08
	)

	flash_material.emission_enabled = true

	flash_material.emission = Color(
		1.0,
		0.28,
		0.03
	)

	flash_material.emission_energy_multiplier = 7.0

	flash_mesh.material = flash_material
	particles.draw_pass_1 = flash_mesh

	get_tree().root.add_child(
		particles
	)

	particles.global_position = (
		origin + forward * 0.05
	)

	particles.emitting = true

	get_tree().create_timer(
		0.25
	).timeout.connect(
		func() -> void:
			if is_instance_valid(
				particles
			):
				particles.queue_free()
	)


func spawn_realistic_muzzle_smoke(
	origin: Vector3,
	forward: Vector3,
	amount: int
) -> void:
	var particles := GPUParticles3D.new()

	particles.amount = amount
	particles.lifetime = 0.70
	particles.one_shot = true
	particles.explosiveness = 0.80
	particles.randomness = 0.85
	particles.local_coords = false

	var process_mat := ParticleProcessMaterial.new()

	process_mat.direction = forward
	process_mat.spread = 30.0
	process_mat.initial_velocity_min = 0.45
	process_mat.initial_velocity_max = 2.2

	process_mat.gravity = Vector3(
		0.0,
		0.35,
		0.0
	)

	process_mat.scale_min = 0.035
	process_mat.scale_max = 0.095

	particles.process_material = process_mat

	var smoke_mesh := QuadMesh.new()

	smoke_mesh.size = Vector2(
		0.12,
		0.12
	)

	var smoke_material := StandardMaterial3D.new()

	smoke_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)

	smoke_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	smoke_material.billboard_mode = (
		BaseMaterial3D.BILLBOARD_ENABLED
	)

	smoke_material.albedo_color = Color(
		0.18,
		0.18,
		0.18,
		0.22
	)

	smoke_material.emission_enabled = true

	smoke_material.emission = Color(
		0.025,
		0.025,
		0.025
	)

	smoke_mesh.material = smoke_material
	particles.draw_pass_1 = smoke_mesh

	get_tree().root.add_child(
		particles
	)

	particles.global_position = (
		origin + forward * 0.08
	)

	particles.emitting = true

	get_tree().create_timer(
		1.15
	).timeout.connect(
		func() -> void:
			if is_instance_valid(
				particles
			):
				particles.queue_free()
	)


# ============================================================
# INSPECT
# ============================================================

func trigger_inspect_animation() -> void:
	if (
		is_reloading
		or is_pumping
		or is_inspecting
		or get_current_weapon() == WeaponType.FISTS
	):
		return

	is_inspecting = true

	var curr_pos: Vector3 = (
		weapon_mesh_root.position
	)

	var tw: Tween = (
		create_tween()
		.set_trans(Tween.TRANS_SINE)
		.set_ease(Tween.EASE_IN_OUT)
	)

	tw.tween_property(
		weapon_mesh_root,
		"position",
		curr_pos
		+ Vector3(
			-0.14,
			0.02,
			0.08
		),
		0.4
	)

	tw.parallel().tween_property(
		weapon_mesh_root,
		"rotation_degrees",
		Vector3(
			16.0,
			-48.0,
			36.0
		),
		0.4
	)

	tw.chain().tween_interval(
		0.8
	)

	tw.chain().tween_property(
		weapon_mesh_root,
		"rotation_degrees",
		Vector3(
			-12.0,
			58.0,
			-22.0
		),
		0.5
	)

	tw.chain().tween_interval(
		0.6
	)

	tw.chain().tween_property(
		weapon_mesh_root,
		"position",
		curr_pos,
		0.35
	)

	tw.parallel().tween_property(
		weapon_mesh_root,
		"rotation_degrees",
		Vector3.ZERO,
		0.35
	)

	tw.chain().tween_callback(
		func() -> void:
			is_inspecting = false
	)


# ============================================================
# DAMAGE HITBOX RESOLUTION
# ============================================================

func resolve_damage_hit(
	collider: Object
) -> Dictionary:
	if collider == null:
		return {
			"target": null,
			"multiplier": 1.0,
			"zone": "generic"
		}

	if collider is Area3D:
		var area: Area3D = (
			collider as Area3D
		)

		if area.has_meta(
			"damage_owner_path"
		):
			var owner_path: NodePath = (
				area.get_meta(
					"damage_owner_path"
				)
			)

			var damage_owner: Node = (
				get_node_or_null(
					owner_path
				)
			)

			if damage_owner != null:
				return {
					"target": damage_owner,
					"multiplier": float(
						area.get_meta(
							"damage_multiplier",
							1.0
						)
					),
					"zone": str(
						area.get_meta(
							"hit_zone",
							"generic"
						)
					)
				}

	if collider is CharacterBody3D:
		return {
			"target": collider,
			"multiplier": 1.0,
			"zone": "body"
		}

	if collider.has_meta(
		"is_npc"
	):
		return {
			"target": collider,
			"multiplier": 1.0,
			"zone": "body"
		}

	return {
		"target": null,
		"multiplier": 1.0,
		"zone": "generic"
	}

func build_procedural_tactical_arms(weapon_rig_node: Node3D, w_type: WeaponType) -> void:
	if not show_player_model_in_menu:
		return

	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.18, 0.20, 0.17) # Tactical uniform / glove color
	arm_mat.roughness = 0.85

	# Base meshes
	var arm_r := BoxMesh.new()
	arm_r.size = Vector3(0.075, 0.075, 0.35)
	arm_right_node = MeshInstance3D.new()
	arm_right_node.mesh = arm_r
	arm_right_node.material_override = arm_mat
	arm_right_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var arm_l := BoxMesh.new()
	arm_l.size = Vector3(0.075, 0.075, 0.35)
	arm_left_node = MeshInstance3D.new()
	arm_left_node.mesh = arm_l
	arm_left_node.material_override = arm_mat
	arm_left_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# --- WEAPON-SPECIFIC GRIP OFFSETS ---
	match w_type:
		WeaponType.AK47:
			# Right hand on pistol grip / trigger
			arm_right_node.position = Vector3(0.15, -0.16, 0.08)
			arm_right_node.rotation_degrees = Vector3(-12, 5, -2)
			# Left hand on lower handguard / foregrip
			arm_left_node.position = Vector3(-0.15, -0.12, -0.26)
			arm_left_node.rotation_degrees = Vector3(12, -15, 10)

		WeaponType.REMINGTON870:
			# Right hand on shotgun grip
			arm_right_node.position = Vector3(0.15, -0.16, 0.10)
			arm_right_node.rotation_degrees = Vector3(-10, 5, -2)
			# Left hand on sliding pump handle
			arm_left_node.position = Vector3(-0.15, -0.13, -0.32)
			arm_left_node.rotation_degrees = Vector3(15, -12, 8)

		WeaponType.SNIPER_R700:
			# Right hand on bolt-action grip
			arm_right_node.position = Vector3(0.15, -0.15, 0.12)
			arm_right_node.rotation_degrees = Vector3(-8, 5, 0)
			# Left hand supporting the front stock/forend
			arm_left_node.position = Vector3(-0.14, -0.14, -0.42)
			arm_left_node.rotation_degrees = Vector3(10, -10, 6)

		WeaponType.FISTS:
			# Close in front of camera for punches
			arm_right_node.position = Vector3(0.18, -0.12, -0.15)
			arm_right_node.rotation_degrees = Vector3(0, 15, -10)
			arm_left_node.position = Vector3(-0.18, -0.12, -0.15)
			arm_left_node.rotation_degrees = Vector3(0, -15, 10)

	weapon_rig_node.add_child(arm_right_node)
	weapon_rig_node.add_child(arm_left_node)

@rpc("any_peer", "call_local")
func update_player_score(callsign: String, kills_add: int, deaths_add: int, score_add: int) -> void:
	if callsign == "":
		return
	if not leaderboard_data.has(callsign):
		leaderboard_data[callsign] = {"kills": 0, "deaths": 0, "score": 0}

	leaderboard_data[callsign]["kills"] += kills_add
	leaderboard_data[callsign]["deaths"] += deaths_add
	leaderboard_data[callsign]["score"] += score_add

	if multiplayer.is_server():
		rpc("sync_leaderboard_data", leaderboard_data)

@rpc("authority", "call_local")
func sync_leaderboard_data(data: Dictionary) -> void:
	leaderboard_data = data
	refresh_leaderboard_display()

func refresh_leaderboard_display() -> void:
	if not is_instance_valid(leaderboard_list):
		return

	for child in leaderboard_list.get_children():
		child.queue_free()

	var sorted_players := leaderboard_data.keys()
	sorted_players.sort_custom(func(a, b):
		return leaderboard_data[a]["score"] > leaderboard_data[b]["score"]
	)

	var header := HBoxContainer.new()
	header.add_child(_create_lb_cell("OPERATIVE CALLSIGN", true, 2.0))
	header.add_child(_create_lb_cell("K", true, 0.7))
	header.add_child(_create_lb_cell("D", true, 0.7))
	header.add_child(_create_lb_cell("SCORE", true, 1.0))
	leaderboard_list.add_child(header)

	for i in range(sorted_players.size()):
		var p_name: String = sorted_players[i]
		var stats: Dictionary = leaderboard_data[p_name]

		var row := HBoxContainer.new()
		row.add_child(_create_lb_cell(str(i + 1) + ". " + p_name, false, 2.0))
		row.add_child(_create_lb_cell(str(stats["kills"]), false, 0.7))
		row.add_child(_create_lb_cell(str(stats["deaths"]), false, 0.7))
		row.add_child(_create_lb_cell(str(stats["score"]), false, 1.0))
		leaderboard_list.add_child(row)

func _create_lb_cell(txt: String, is_header: bool, stretch_ratio: float) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = stretch_ratio
	
	if is_header:
		lbl.modulate = Color(0.7, 0.85, 1.0)
		lbl.add_theme_font_size_override("font_size", 13)
	else:
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.9, 0.9, 0.9)
	return lbl
	
func update_procedural_hand_animations(delta: float, is_sprinting_now: bool, is_aiming_now: bool) -> void:
	if not is_instance_valid(weapon_rig):
		return

	anim_time += delta

	if is_reloading or is_pumping:
		current_hand_state = HandAnimState.RELOADING
	elif is_sprinting_now:
		current_hand_state = HandAnimState.SPRINTING
	elif is_aiming_now:
		current_hand_state = HandAnimState.ADS
	else:
		current_hand_state = HandAnimState.IDLE

	# update_first_person_weapon owns all view-model transforms. Mutating the
	# rig here used to undo the calibrated sight pose, especially during ADS blend.
			
# ============================================================
# HUMANOID HITBOXES
# ============================================================

func add_humanoid_hitboxes(
	character_root: CharacterBody3D
) -> void:
	# ========================================================
	# HEAD
	# ========================================================

	var head_area := Area3D.new()

	head_area.name = "HeadHitbox"
	head_area.collision_layer = 4
	head_area.collision_mask = 0

	head_area.set_meta(
		"damage_owner_path",
		character_root.get_path()
	)

	head_area.set_meta(
		"damage_multiplier",
		2.10
	)

	head_area.set_meta(
		"hit_zone",
		"head"
	)

	var head_collision := CollisionShape3D.new()
	var head_shape := SphereShape3D.new()

	head_shape.radius = 0.19

	head_collision.shape = head_shape
	head_collision.position = Vector3(
		0.0,
		1.78,
		0.0
	)

	head_area.add_child(
		head_collision
	)

	character_root.add_child(
		head_area
	)

	# ========================================================
	# CHEST
	# ========================================================

	var chest_area := Area3D.new()

	chest_area.name = "ChestHitbox"
	chest_area.collision_layer = 4
	chest_area.collision_mask = 0

	chest_area.set_meta(
		"damage_owner_path",
		character_root.get_path()
	)

	chest_area.set_meta(
		"damage_multiplier",
		0.92
	)

	chest_area.set_meta(
		"hit_zone",
		"chest"
	)

	var chest_collision := CollisionShape3D.new()
	var chest_shape := BoxShape3D.new()

	chest_shape.size = Vector3(
		0.58,
		0.68,
		0.34
	)

	chest_collision.shape = chest_shape
	chest_collision.position = Vector3(
		0.0,
		1.17,
		0.0
	)

	chest_area.add_child(
		chest_collision
	)

	character_root.add_child(
		chest_area
	)

	# ========================================================
	# LEGS
	# ========================================================

	var leg_area := Area3D.new()

	leg_area.name = "LegHitbox"
	leg_area.collision_layer = 4
	leg_area.collision_mask = 0

	leg_area.set_meta(
		"damage_owner_path",
		character_root.get_path()
	)

	leg_area.set_meta(
		"damage_multiplier",
		0.68
	)

	leg_area.set_meta(
		"hit_zone",
		"legs"
	)

	var leg_collision := CollisionShape3D.new()
	var leg_shape := CapsuleShape3D.new()

	leg_shape.radius = 0.13
	leg_shape.height = 0.70

	leg_collision.shape = leg_shape
	leg_collision.position = Vector3(
		0.0,
		0.50,
		0.0
	)

	leg_area.add_child(
		leg_collision
	)

	character_root.add_child(
		leg_area
	)


# ============================================================
# EQUIP ANIMATION
# ============================================================

func trigger_equip_animation() -> void:
	if not is_instance_valid(
		weapon_mesh_root
	):
		return

	is_equipping = true

	weapon_mesh_root.position = Vector3(0.0, -0.38, 0.05)
	weapon_mesh_root.rotation_degrees = Vector3(-25.0, 0.0, 0.0)

	var tw: Tween = (
		create_tween()
		.set_trans(Tween.TRANS_BACK)
		.set_ease(Tween.EASE_OUT)
	)

	tw.tween_property(
		weapon_mesh_root,
		"position",
		Vector3.ZERO,
		0.28
	)

	tw.parallel().tween_property(
		weapon_mesh_root,
		"rotation_degrees:x",
		0.0,
		0.28
	)

	tw.chain().tween_callback(
		func() -> void:
			is_equipping = false
	)


# ============================================================
# RELOAD
# ============================================================
func execute_weapon_reload() -> void:
	var curr_w: WeaponType = get_current_weapon()

	if is_reloading or is_pumping or curr_w == WeaponType.FISTS:
		return

	if not weapon_ammo_map.has(curr_w):
		return

	var ammo: Dictionary = weapon_ammo_map[curr_w]

	if int(ammo["current"]) >= int(ammo["max_mag"]) or int(ammo["reserve"]) <= 0:
		return

	var is_empty_reload: bool = (int(ammo["current"]) == 0)

	is_reloading = true
	is_aiming = false
	aim_button_down = false
	is_inspecting = false
	cancel_reload_requested = false

	var curr_pos: Vector3 = weapon_mesh_root.position
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	match curr_w:
		WeaponType.AK47:
			# Empty reload takes longer due to locking a fresh mag and racking the charging handle
			var reload_duration: float = 1.45 if is_empty_reload else 1.10
			# Scale the whole reload animation so an empty reload reads slower/heavier.
			tw.set_speed_scale(1.10 / reload_duration)
			
			tw.tween_property(weapon_mesh_root, "position", curr_pos + Vector3(-0.08, -0.14, 0.06), 0.22)
			tw.parallel().tween_property(weapon_mesh_root, "rotation_degrees", Vector3(18.0, 28.0, -42.0), 0.22)

			# Drop old magazine
			if is_instance_valid(mag_mesh_node):
				tw.chain().tween_property(mag_mesh_node, "position", Vector3(0.0, -0.48, -0.1), 0.18)
				tw.parallel().tween_property(mag_mesh_node, "rotation_degrees", Vector3(50.0, 0.0, 0.0), 0.18)

			tw.chain().tween_callback(func() -> void:
				if is_instance_valid(mag_mesh_node):
					mag_mesh_node.position = Vector3(0.0, -0.3, 0.1)
					mag_mesh_node.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
			)

			# Insert fresh magazine
			if is_instance_valid(mag_mesh_node):
				tw.tween_property(mag_mesh_node, "position", Vector3(0.0, -0.09, -0.06), 0.22)
				tw.parallel().tween_property(mag_mesh_node, "rotation_degrees", Vector3(14.0, 0.0, 0.0), 0.22)

			# Extra cocking delay & animation if empty
			if is_empty_reload:
				tw.chain().tween_interval(0.15) # Extra time spent turning and cocking the weapon
				if is_instance_valid(bolt_carrier_node):
					tw.chain().tween_property(bolt_carrier_node, "position:z", 0.12, 0.10)
					tw.chain().tween_property(bolt_carrier_node, "position:z", 0.0, 0.08)

			tw.chain().tween_property(weapon_mesh_root, "position", curr_pos, 0.20)
			tw.parallel().tween_property(weapon_mesh_root, "rotation_degrees", Vector3.ZERO, 0.20)
			
			# GUARANTEED RESET: Ensures shooting is unlocked even if nodes shift
			tw.chain().tween_callback(func():
				var needed = int(ammo["max_mag"]) - int(ammo["current"])
				var transfer = mini(needed, int(ammo["reserve"]))
				ammo["current"] = int(ammo["current"]) + transfer
				ammo["reserve"] = int(ammo["reserve"]) - transfer
				update_hud_display()
				is_reloading = false
			)
		WeaponType.REMINGTON870:
			# Shell-by-shell shotgun reload loop (empty requires chambering first)
			if is_empty_reload and is_instance_valid(charging_handle_node):
				var tw_rack = create_tween().set_trans(Tween.TRANS_SINE)
				tw_rack.tween_property(charging_handle_node, "position:z", 0.18, 0.15)
				tw_rack.chain().tween_property(charging_handle_node, "position:z", 0.0, 0.15)
				await tw_rack.finished

			while int(ammo["current"]) < int(ammo["max_mag"]) and int(ammo["reserve"]) > 0 and not cancel_reload_requested:
				var tw_shell = create_tween().set_trans(Tween.TRANS_SINE)
				tw_shell.tween_property(weapon_mesh_root, "rotation_degrees", Vector3(28.0, 18.0, -58.0), 0.12)
				tw_shell.chain().tween_callback(func(): animate_shell_insertion_into_port())
				tw_shell.chain().tween_interval(0.18)
				tw_shell.chain().tween_callback(func():
					ammo["current"] = int(ammo["current"]) + 1
					ammo["reserve"] = int(ammo["reserve"]) - 1
					update_hud_display()
				)
				tw_shell.tween_property(weapon_mesh_root, "rotation_degrees", Vector3(20.0, 10.0, -45.0), 0.10)
				await tw_shell.finished

			var tw_exit = create_tween()
			tw_exit.tween_property(weapon_mesh_root, "rotation_degrees", Vector3.ZERO, 0.16)
			await tw_exit.finished
			is_reloading = false

		WeaponType.SNIPER_R700:
			# Bolt-action magazine reload with mandatory bolt throw if empty
			tw.tween_property(weapon_mesh_root, "position", curr_pos + Vector3(-0.06, -0.12, 0.04), 0.20)
			tw.parallel().tween_property(weapon_mesh_root, "rotation_degrees", Vector3(15.0, 32.0, -38.0), 0.20)

			if is_empty_reload and is_instance_valid(charging_handle_node):
				tw.chain().tween_property(charging_handle_node, "rotation_degrees:z", 65.0, 0.10)
				tw.chain().tween_property(charging_handle_node, "position:z", 0.14, 0.12)
				tw.chain().tween_property(charging_handle_node, "position:z", 0.0, 0.10)
				tw.chain().tween_property(charging_handle_node, "rotation_degrees:z", 0.0, 0.10)

			tw.chain().tween_property(weapon_mesh_root, "position", curr_pos, 0.20)
			tw.parallel().tween_property(weapon_mesh_root, "rotation_degrees", Vector3.ZERO, 0.20)

			tw.chain().tween_callback(func():
				var needed = int(ammo["max_mag"]) - int(ammo["current"])
				var transfer = mini(needed, int(ammo["reserve"]))
				ammo["current"] = int(ammo["current"]) + transfer
				ammo["reserve"] = int(ammo["reserve"]) - transfer
				update_hud_display()
				is_reloading = false
			)
			
func animate_shell_insertion_into_port() -> void:
	if not is_instance_valid(loading_port_marker): 
		return
	var shell = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.011
	cyl.bottom_radius = 0.011
	cyl.height = 0.038
	shell.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.12, 0.12)
	mat.metallic = 0.5
	shell.material_override = mat
	loading_port_marker.add_child(shell)

	shell.position = Vector3(0, -0.15, 0.08)
	var tw = shell.create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(shell, "position", Vector3.ZERO, 0.16)
	tw.chain().tween_callback(shell.queue_free)
	
# --- PROCEDURAL TEXTURE GENERATOR & MATERIAL CACHE ---
func get_cached_procedural_material(key: String, color: Color, roughness: float, metallic: float, noise_freq: float = 0.08, bump: float = 1.5) -> StandardMaterial3D:
	if noise_cache.has(key):
		return noise_cache[key]

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.metallic_specular = 0.5

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_freq
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.2
	noise.fractal_gain = 0.5

	var norm_tex = NoiseTexture2D.new()
	norm_tex.noise = noise
	norm_tex.as_normal_map = true
	norm_tex.bump_strength = bump
	norm_tex.width = 256
	norm_tex.height = 256
	norm_tex.seamless = true

	mat.normal_enabled = true
	mat.normal_texture = norm_tex

	# Triplanar mapping keeps procedural detail consistent across large boxes.
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(2.0, 2.0, 2.0)

	# Subtle rim light so edges read well under any lighting.
	mat.rim_enabled = true
	mat.rim = 0.35

	if metallic > 0.5:
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.25
		mat.clearcoat_roughness = 0.25
	
	noise_cache[key] = mat
	return mat

# ============================================================
# FIXED PROCEDURAL WEAPON MESH BUILDER
# ============================================================

func create_local_iron_sight_markers(
	parent: Node3D,
	rear_position: Vector3,
	front_position: Vector3
) -> void:
	if not is_instance_valid(weapon_rig) or parent != weapon_mesh_root:
		return

	weapon_rear_iron_sight = Node3D.new()
	weapon_rear_iron_sight.name = "RearIronSightMarker"
	weapon_rear_iron_sight.position = rear_position
	parent.add_child(weapon_rear_iron_sight)

	weapon_front_iron_sight = Node3D.new()
	weapon_front_iron_sight.name = "FrontIronSightMarker"
	weapon_front_iron_sight.position = front_position
	parent.add_child(weapon_front_iron_sight)

func add_red_dot_sight(parent: Node3D, spawn_position: Vector3, is_local: bool) -> void:
	var optic := Node3D.new()
	optic.name = "MicroRedDotSight"
	optic.position = spawn_position # Updated to use the renamed parameter
	parent.add_child(optic)
	
	var housing_material := get_cached_procedural_material(
		"micro_red_dot_housing",
		Color(0.055, 0.062, 0.070),
		0.30,
		0.86
	)
	
	var mount_mesh := BoxMesh.new()
	mount_mesh.size = Vector3(0.052, 0.018, 0.11)
	var mount := MeshInstance3D.new()
	mount.mesh = mount_mesh
	mount.position = Vector3(0.0, -0.050, 0.0)
	mount.material_override = housing_material
	optic.add_child(mount)

	var housing := MeshInstance3D.new()
	var housing_mesh := TorusMesh.new()
	housing_mesh.inner_radius = 0.032
	housing_mesh.outer_radius = 0.039
	housing.mesh = housing_mesh
	housing.rotation_degrees.x = 90.0
	housing.material_override = housing_material
	optic.add_child(housing)

	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color(0.50, 0.64, 0.75, 0.20)
	lens_material.metallic = 0.25
	lens_material.roughness = 0.12
	lens_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.031
	lens_mesh.bottom_radius = 0.031
	lens_mesh.height = 0.003
	lens_mesh.radial_segments = 32
	lens.mesh = lens_mesh
	lens.rotation_degrees.x = 90.0
	lens.position.z = 0.003
	lens.material_override = lens_material
	optic.add_child(lens)

	var reticle_material := StandardMaterial3D.new()
	reticle_material.albedo_color = Color(1.0, 0.035, 0.02)
	reticle_material.emission_enabled = true
	reticle_material.emission = Color(1.0, 0.02, 0.01)
	reticle_material.emission_energy_multiplier = 2.8
	
	var reticle := MeshInstance3D.new()
	reticle.name = "RedDotReticle"
	var reticle_mesh := SphereMesh.new()
	reticle_mesh.radius = 0.0045
	reticle_mesh.height = 0.009
	reticle_mesh.radial_segments = 16
	reticle_mesh.rings = 8
	reticle.mesh = reticle_mesh
	reticle.position.z = 0.006
	reticle.material_override = reticle_material
	optic.add_child(reticle)
	
	if is_local:
		weapon_red_dot_reticle = reticle
		
func build_procedural_weapon_mesh(parent_pivot: Node3D, is_local: bool, w_type: WeaponType) -> void:
	var w_rig = Node3D.new()
	parent_pivot.add_child(w_rig)
	
	var w_root = Node3D.new()
	w_rig.add_child(w_root)

	if is_local:
		weapon_rig = w_rig
		weapon_mesh_root = w_root
		weapon_rear_iron_sight = null
		weapon_front_iron_sight = null
		weapon_scope_root = null
		weapon_red_dot_reticle = null
		w_rig.position = weapon_hip_position
		w_rig.rotation = Vector3.ZERO
		weapon_base_position = weapon_hip_position
		
		# --- ADD THIS LINE TO SPAWN FIRST-PERSON HANDS & SHADOWS ---
		build_procedural_tactical_arms(w_rig, w_type)
	else:
		w_root.position = Vector3.ZERO
		w_rig.position = Vector3.ZERO
		
	# --- FISTS ---
	if w_type == WeaponType.FISTS:
		var glove_mat = get_cached_procedural_material("glove_leather", Color(0.12, 0.13, 0.14), 0.55, 0.08, 0.1, 1.2)
		var armor_mat = get_cached_procedural_material("knuckle_armor", Color(0.04, 0.04, 0.05), 0.25, 0.8, 0.15, 2.0)

		for side in [-1, 1]:
			var x_off = side * 0.18
			var hand_node = Node3D.new(); hand_node.position = Vector3(x_off, 0, 0); w_root.add_child(hand_node)

			var arm_m = BoxMesh.new(); arm_m.size = Vector3(0.08, 0.085, 0.22)
			var arm = MeshInstance3D.new(); arm.mesh = arm_m; arm.material_override = glove_mat; arm.position = Vector3(0, -0.02, 0.10); hand_node.add_child(arm)

			var palm_m = BoxMesh.new(); palm_m.size = Vector3(0.088, 0.08, 0.11)
			var palm = MeshInstance3D.new(); palm.mesh = palm_m; palm.material_override = glove_mat; palm.position = Vector3(0, 0, -0.02); hand_node.add_child(palm)

			var guard_m = BoxMesh.new(); guard_m.size = Vector3(0.086, 0.035, 0.04)
			var guard = MeshInstance3D.new(); guard.mesh = guard_m; guard.material_override = armor_mat; guard.position = Vector3(0, 0.026, -0.035); guard.rotation_degrees = Vector3(-12, 0, 0); hand_node.add_child(guard)

			for f in range(4):
				var f_m = BoxMesh.new(); f_m.size = Vector3(0.019, 0.022, 0.045)
				var finger = MeshInstance3D.new(); finger.mesh = f_m; finger.material_override = glove_mat
				finger.position = Vector3(-0.03 + (f * 0.02), -0.018, -0.075)
				finger.rotation_degrees = Vector3(18, 0, 0)
				hand_node.add_child(finger)

			var thumb_m = BoxMesh.new(); thumb_m.size = Vector3(0.024, 0.028, 0.05)
			var thumb = MeshInstance3D.new(); thumb.mesh = thumb_m; thumb.material_override = glove_mat
			thumb.position = Vector3(-side * 0.042, 0.015, -0.03)
			thumb.rotation_degrees = Vector3(15, side * 35, 0)
			hand_node.add_child(thumb)
		return

	# --- PBR HIGH-DETAIL MATERIALS ---
	var dark_steel = get_cached_procedural_material("gun_steel_dark", Color(0.08, 0.09, 0.10), 0.28, 0.92, 0.12, 1.8)
	var chrome_steel = get_cached_procedural_material("gun_steel_chrome", Color(0.65, 0.68, 0.72), 0.12, 0.98, 0.05, 0.8)
	var walnut_wood = get_cached_procedural_material("ak_walnut_wood", Color(0.32, 0.14, 0.05), 0.38, 0.0, 0.02, 1.4)
	var bakelite = get_cached_procedural_material("bakelite_polymer", Color(0.48, 0.18, 0.07), 0.32, 0.05, 0.06, 1.0)
	var glass_mat = StandardMaterial3D.new(); glass_mat.albedo_color = Color(0.1, 0.4, 0.6, 0.65); glass_mat.metallic = 0.95; glass_mat.roughness = 0.02; glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var slot_interior = StandardMaterial3D.new(); slot_interior.albedo_color = Color(0.01, 0.01, 0.01); slot_interior.roughness = 0.9

	var add_part = func(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, p_node: Node3D = w_root) -> MeshInstance3D:
		var inst = MeshInstance3D.new(); inst.mesh = mesh; inst.material_override = mat; inst.position = pos; inst.rotation_degrees = rot; p_node.add_child(inst)
		return inst

	var flash_pos = Vector3.ZERO

# ============================================================
	# 1. AK-47 (REFERENCE-MATCHED PROCEDURAL MODEL)
	# ============================================================
	if w_type == WeaponType.AK47:
		# Receiver Body, Magwell & Front Trunnion Block
		var rec = BoxMesh.new(); rec.size = Vector3(0.038, 0.062, 0.34); add_part.call(rec, dark_steel, Vector3(0, 0, 0))
		var magwell = BoxMesh.new(); magwell.size = Vector3(0.040, 0.018, 0.09); add_part.call(magwell, dark_steel, Vector3(0, -0.036, -0.03))
		var trunnion = BoxMesh.new(); trunnion.size = Vector3(0.040, 0.064, 0.06); add_part.call(trunnion, dark_steel, Vector3(0, 0, -0.15))

		# Curved Stamped Dust Cover & Rear Sight Base
		var dust_cover = CylinderMesh.new(); dust_cover.top_radius = 0.020; dust_cover.bottom_radius = 0.020; dust_cover.height = 0.27
		add_part.call(dust_cover, dark_steel, Vector3(0, 0.032, -0.015), Vector3(90, 0, 0))
		var rear_sight_base = BoxMesh.new(); rear_sight_base.size = Vector3(0.024, 0.028, 0.055); add_part.call(rear_sight_base, dark_steel, Vector3(0, 0.042, -0.135))
		# Two raised sides leave a clear center notch to see the front post through.
		var rear_sight_leaf_left = BoxMesh.new(); rear_sight_leaf_left.size = Vector3(0.004, 0.010, 0.045); add_part.call(rear_sight_leaf_left, dark_steel, Vector3(-0.006, 0.052, -0.135), Vector3(-6, 0, 0))
		var rear_sight_leaf_right = BoxMesh.new(); rear_sight_leaf_right.size = Vector3(0.004, 0.010, 0.045); add_part.call(rear_sight_leaf_right, dark_steel, Vector3(0.006, 0.052, -0.135), Vector3(-6, 0, 0))

		# Bolt Carrier & Operating Handle
		var slot_cut = BoxMesh.new(); slot_cut.size = Vector3(0.005, 0.022, 0.09); add_part.call(slot_cut, slot_interior, Vector3(0.020, 0.016, -0.02))
		var b_node = Node3D.new(); b_node.position = Vector3(0.017, 0.016, -0.02); w_root.add_child(b_node)
		if is_local: bolt_carrier_node = b_node
		var carrier = BoxMesh.new(); carrier.size = Vector3(0.007, 0.020, 0.10); add_part.call(carrier, chrome_steel, Vector3(0, 0, 0), Vector3.ZERO, b_node)
		var handle = CylinderMesh.new(); handle.top_radius = 0.0045; handle.bottom_radius = 0.0045; handle.height = 0.034
		add_part.call(handle, chrome_steel, Vector3(0.018, 0.002, 0), Vector3(0, 0, 90), b_node)

		# Wooden Fixed Stock & Steel Buttplate
		var stock = BoxMesh.new(); stock.size = Vector3(0.034, 0.078, 0.31); add_part.call(stock, walnut_wood, Vector3(0, -0.016, 0.31), Vector3(-6.5, 0, 0))
		var buttplate = BoxMesh.new(); buttplate.size = Vector3(0.036, 0.082, 0.010); add_part.call(buttplate, dark_steel, Vector3(0, -0.020, 0.46), Vector3(-6.5, 0, 0))
		var sling_loop = TorusMesh.new(); sling_loop.inner_radius = 0.008; sling_loop.outer_radius = 0.012; add_part.call(sling_loop, dark_steel, Vector3(-0.018, -0.010, 0.38), Vector3(0, 90, 0))

		# Ergonomic Bakelite Pistol Grip
		var grip = BoxMesh.new(); grip.size = Vector3(0.030, 0.10, 0.042); add_part.call(grip, bakelite, Vector3(0, -0.082, 0.11), Vector3(-18, 0, 0))

		# Barrel, Cleaning Rod, Upper & Lower Handguards
		var barrel = CylinderMesh.new(); barrel.top_radius = 0.008; barrel.bottom_radius = 0.008; barrel.height = 0.60; add_part.call(barrel, dark_steel, Vector3(0, 0.008, -0.44), Vector3(90, 0, 0))
		var cleaning_rod = CylinderMesh.new(); cleaning_rod.top_radius = 0.0025; cleaning_rod.bottom_radius = 0.0025; cleaning_rod.height = 0.52; add_part.call(cleaning_rod, dark_steel, Vector3(0, -0.016, -0.41), Vector3(90, 0, 0))

		var lower_hg = BoxMesh.new(); lower_hg.size = Vector3(0.036, 0.042, 0.20); add_part.call(lower_hg, walnut_wood, Vector3(0, -0.010, -0.26))
		var upper_hg = BoxMesh.new(); upper_hg.size = Vector3(0.030, 0.032, 0.15); add_part.call(upper_hg, walnut_wood, Vector3(0, 0.028, -0.26))
		var hg_retainer = BoxMesh.new(); hg_retainer.size = Vector3(0.038, 0.046, 0.012); add_part.call(hg_retainer, dark_steel, Vector3(0, 0.008, -0.36))

		# Gas Block, Front Sight Tower & Slant Muzzle Brake
		var gas_block = BoxMesh.new(); gas_block.size = Vector3(0.020, 0.036, 0.032); add_part.call(gas_block, dark_steel, Vector3(0, 0.018, -0.38), Vector3(-12, 0, 0))
		var front_sight_base = BoxMesh.new(); front_sight_base.size = Vector3(0.022, 0.042, 0.036); add_part.call(front_sight_base, dark_steel, Vector3(0, 0.026, -0.63))
		var sight_hood = CylinderMesh.new(); sight_hood.top_radius = 0.011; sight_hood.bottom_radius = 0.011; sight_hood.height = 0.016; add_part.call(sight_hood, dark_steel, Vector3(0, 0.052, -0.63), Vector3(90, 0, 0))
		var front_post = CylinderMesh.new(); front_post.top_radius = 0.0018; front_post.bottom_radius = 0.0018; front_post.height = 0.018; add_part.call(front_post, dark_steel, Vector3(0, 0.050, -0.63))
		add_red_dot_sight(w_root, Vector3(0.0, 0.12, -0.12), is_local)
		if is_local:
			create_local_iron_sight_markers(w_root, Vector3(0.0, 0.12, -0.07), Vector3(0.0, 0.12, -0.16))
		var slant_brake = CylinderMesh.new(); slant_brake.top_radius = 0.010; slant_brake.bottom_radius = 0.009; slant_brake.height = 0.048; add_part.call(slant_brake, dark_steel, Vector3(0, 0.008, -0.73), Vector3(90, 0, 18))

		# 3-Stage Curved Magazine Node (Accurate AK Sweep Curve)
		var m_node = Node3D.new(); m_node.position = Vector3(0, -0.080, -0.045); w_root.add_child(m_node)
		if is_local: mag_mesh_node = m_node
		var mag_upper = BoxMesh.new(); mag_upper.size = Vector3(0.028, 0.060, 0.048); add_part.call(mag_upper, dark_steel, Vector3(0, 0.0, 0), Vector3(10, 0, 0), m_node)
		var mag_mid = BoxMesh.new(); mag_mid.size = Vector3(0.027, 0.065, 0.046); add_part.call(mag_mid, dark_steel, Vector3(0, -0.052, -0.016), Vector3(24, 0, 0), m_node)
		var mag_lower = BoxMesh.new(); mag_lower.size = Vector3(0.026, 0.060, 0.044); add_part.call(mag_lower, dark_steel, Vector3(0, -0.104, -0.048), Vector3(38, 0, 0), m_node)
		var mag_floorplate = BoxMesh.new(); mag_floorplate.size = Vector3(0.029, 0.010, 0.048); add_part.call(mag_floorplate, dark_steel, Vector3(0, -0.132, -0.070), Vector3(38, 0, 0), m_node)

		# Ejection Port & Muzzle Flash Markers
		var ej_node = Node3D.new(); ej_node.position = Vector3(0.030, 0.016, -0.02); w_root.add_child(ej_node)
		if is_local: ejection_port_marker = ej_node
		flash_pos = Vector3(0, 0.008, -0.75)
	# ============================================================
	# 2. REMINGTON 870 (ADVANCED PROCEDURAL MODEL)
	# ============================================================
	if w_type == WeaponType.REMINGTON870:
		# Receiver & Under-Barrel Magazine Tube
		var rec = BoxMesh.new(); rec.size = Vector3(0.045, 0.075, 0.32); add_part.call(rec, dark_steel, Vector3(0, 0, 0))
		var mag_tube = CylinderMesh.new(); mag_tube.top_radius = 0.012; mag_tube.bottom_radius = 0.012; mag_tube.height = 0.55
		add_part.call(mag_tube, dark_steel, Vector3(0, -0.022, -0.28), Vector3(90, 0, 0))
		var barrel = CylinderMesh.new(); barrel.top_radius = 0.013; barrel.bottom_radius = 0.013; barrel.height = 0.70; add_part.call(barrel, dark_steel, Vector3(0, 0.022, -0.46), Vector3(90, 0, 0))
		
		# Rear notch and bead front sight share the barrel's sight line.
		var rear_sight_base = BoxMesh.new(); rear_sight_base.size = Vector3(0.032, 0.012, 0.032); add_part.call(rear_sight_base, dark_steel, Vector3(0, 0.020, -0.08))
		var rear_sight_left = BoxMesh.new(); rear_sight_left.size = Vector3(0.004, 0.020, 0.024); add_part.call(rear_sight_left, dark_steel, Vector3(-0.009, 0.027, -0.08))
		var rear_sight_right = BoxMesh.new(); rear_sight_right.size = Vector3(0.004, 0.020, 0.024); add_part.call(rear_sight_right, dark_steel, Vector3(0.009, 0.027, -0.08))
		# Bead Front Sight
		var bead = CylinderMesh.new(); bead.top_radius = 0.0015; bead.bottom_radius = 0.0015; bead.height = 0.01; add_part.call(bead, chrome_steel, Vector3(0, 0.032, -0.80))
		add_red_dot_sight(w_root, Vector3(0.0, 0.115, -0.12), is_local)
		if is_local:
			create_local_iron_sight_markers(w_root, Vector3(0.0, 0.115, -0.07), Vector3(0.0, 0.115, -0.17))

		# Wooden Stock & Rubber Recoil Pad
		var stock = BoxMesh.new(); stock.size = Vector3(0.038, 0.088, 0.32); add_part.call(stock, walnut_wood, Vector3(0, -0.02, 0.30), Vector3(-8, 0, 0))
		var recoil_pad = BoxMesh.new(); recoil_pad.size = Vector3(0.040, 0.092, 0.025); add_part.call(recoil_pad, get_cached_procedural_material("rubber_pad", Color(0.1, 0.1, 0.1), 0.9, 0.0), Vector3(0, -0.024, 0.46), Vector3(-8, 0, 0))
		
		# Trigger Guard & Trigger
		var guard = BoxMesh.new(); guard.size = Vector3(0.015, 0.035, 0.07); add_part.call(guard, dark_steel, Vector3(0, -0.055, 0.04))
		var trigger_item = BoxMesh.new(); trigger_item.size = Vector3(0.006, 0.022, 0.015); add_part.call(trigger_item, chrome_steel, Vector3(0, -0.048, 0.02), Vector3(15, 0, 0))

		# Sliding Pump Handle Node (Cleanly parented for pump action)
		var pump_node = Node3D.new(); pump_node.position = Vector3(0, -0.01, -0.32); w_root.add_child(pump_node)
		if is_local: charging_handle_node = pump_node
		
		var pump_m = CylinderMesh.new(); pump_m.top_radius = 0.023; pump_m.bottom_radius = 0.023; pump_m.height = 0.18
		add_part.call(pump_m, walnut_wood, Vector3(0, 0, 0), Vector3(90, 0, 0), pump_node)
		
		# Ribs on Pump Handle
		for p_rib in range(3):
			var rib_m = CylinderMesh.new(); rib_m.top_radius = 0.024; rib_m.bottom_radius = 0.024; rib_m.height = 0.012
			add_part.call(rib_m, dark_steel, Vector3(0, 0, -0.06 + (p_rib * 0.05)), Vector3(90, 0, 0), pump_node)

		# Ejection & Loading Port Markers
		var ej_node = Node3D.new(); ej_node.position = Vector3(0.026, 0.014, -0.02); w_root.add_child(ej_node)
		var load_node = Node3D.new(); load_node.position = Vector3(0, -0.042, -0.02); w_root.add_child(load_node)
		if is_local:
			ejection_port_marker = ej_node
			loading_port_marker = load_node
		flash_pos = Vector3(0, 0.022, -0.81)
	# ============================================================
	# 3. SNIPER R700 (WITH SCOPE & BARREL)
	# ============================================================
	elif w_type == WeaponType.SNIPER_R700:
		var stock = BoxMesh.new(); stock.size = Vector3(0.044, 0.08, 0.52); add_part.call(stock, dark_steel, Vector3(0, -0.02, 0.28), Vector3(-3, 0, 0))
		var rec = BoxMesh.new(); rec.size = Vector3(0.046, 0.068, 0.44); add_part.call(rec, dark_steel, Vector3(0, 0, 0))
		var barrel = CylinderMesh.new(); barrel.top_radius = 0.014; barrel.bottom_radius = 0.018; barrel.height = 0.88; add_part.call(barrel, dark_steel, Vector3(0, 0.01, -0.62), Vector3(90, 0, 0))

		# Backup iron sights give the R700 a usable sight picture with scope zoom off.
		var rear_sight_base = BoxMesh.new(); rear_sight_base.size = Vector3(0.034, 0.016, 0.038); add_part.call(rear_sight_base, dark_steel, Vector3(0, 0.018, 0.025))
		var rear_sight_left = BoxMesh.new(); rear_sight_left.size = Vector3(0.005, 0.020, 0.028); add_part.call(rear_sight_left, dark_steel, Vector3(-0.009, 0.030, 0.025))
		var rear_sight_right = BoxMesh.new(); rear_sight_right.size = Vector3(0.005, 0.020, 0.028); add_part.call(rear_sight_right, dark_steel, Vector3(0.009, 0.030, 0.025))
		# Open side ears keep the center blade visible when viewed from the rear.
		var front_sight_left = BoxMesh.new(); front_sight_left.size = Vector3(0.006, 0.032, 0.040); add_part.call(front_sight_left, dark_steel, Vector3(-0.009, 0.022, -0.99))
		var front_sight_right = BoxMesh.new(); front_sight_right.size = Vector3(0.006, 0.032, 0.040); add_part.call(front_sight_right, dark_steel, Vector3(0.009, 0.022, -0.99))
		var front_sight_post = BoxMesh.new(); front_sight_post.size = Vector3(0.004, 0.012, 0.006); add_part.call(front_sight_post, dark_steel, Vector3(0, 0.034, -0.99))
		if is_local:
			create_local_iron_sight_markers(w_root, Vector3(0.0, 0.040, 0.025), Vector3(0.0, 0.040, -0.99))

		var b_node = Node3D.new(); b_node.position = Vector3(0, 0.02, 0.02); w_root.add_child(b_node)
		if is_local: bolt_carrier_node = b_node
		var bolt_cyl = CylinderMesh.new(); bolt_cyl.top_radius = 0.012; bolt_cyl.bottom_radius = 0.012; bolt_cyl.height = 0.16
		add_part.call(bolt_cyl, chrome_steel, Vector3(0, 0, 0), Vector3(90, 0, 0), b_node)

		var bolt_handle_node = Node3D.new(); bolt_handle_node.position = Vector3(0.012, 0.02, 0.06); w_root.add_child(bolt_handle_node)
		if is_local: charging_handle_node = bolt_handle_node
		var bolt_stem = CylinderMesh.new(); bolt_stem.top_radius = 0.005; bolt_stem.bottom_radius = 0.005; bolt_stem.height = 0.06
		add_part.call(bolt_stem, chrome_steel, Vector3(0.022, 0, 0), Vector3(0, 0, 90), bolt_handle_node)

		# Keep the optic on its own node so it can clear the backup irons in ADS.
		var scope_root := Node3D.new()
		scope_root.name = "ScopeAssembly"
		w_root.add_child(scope_root)
		if is_local:
			weapon_scope_root = scope_root
		var scope_tube = CylinderMesh.new(); scope_tube.top_radius = 0.018; scope_tube.bottom_radius = 0.018; scope_tube.height = 0.32
		add_part.call(scope_tube, dark_steel, Vector3(0, 0.072, -0.06), Vector3(90, 0, 0), scope_root)
		var scope_bell = CylinderMesh.new(); scope_bell.top_radius = 0.028; scope_bell.bottom_radius = 0.018; scope_bell.height = 0.09
		add_part.call(scope_bell, dark_steel, Vector3(0, 0.072, -0.245), Vector3(90, 0, 0), scope_root)
		var scope_lens = CylinderMesh.new(); scope_lens.top_radius = 0.026; scope_lens.bottom_radius = 0.026; scope_lens.height = 0.005
		add_part.call(scope_lens, glass_mat, Vector3(0, 0.072, -0.288), Vector3(90, 0, 0), scope_root)

		var ej_node = Node3D.new(); ej_node.position = Vector3(0.032, 0.02, 0.02); w_root.add_child(ej_node)
		if is_local: ejection_port_marker = ej_node
		flash_pos = Vector3(0, 0.01, -1.12)

	# --- COMMON MUZZLE FLASH VFX SETUP ---
	var f_marker = Node3D.new(); f_marker.position = flash_pos; w_root.add_child(f_marker)
	if is_local: muzzle_flash_marker = f_marker

	var m_light = OmniLight3D.new(); m_light.light_color = Color(1.0, 0.82, 0.4); m_light.light_energy = 0.0; m_light.omni_range = 16.0; m_light.omni_attenuation = 1.8; m_light.position = flash_pos; w_root.add_child(m_light)
	if is_local: muzzle_flash_light = m_light

	var flash_m = CylinderMesh.new(); flash_m.top_radius = 0.012; flash_m.bottom_radius = 0.082; flash_m.height = 0.32
	var flash_mat = StandardMaterial3D.new(); flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flash_mat.albedo_color = Color(1.0, 0.72, 0.24, 0.95); flash_mat.emission_enabled = true; flash_mat.emission = Color(1.0, 0.42, 0.08); flash_mat.emission_energy_multiplier = 5.5; flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var m_mesh = add_part.call(flash_m, flash_mat, flash_pos, Vector3(-90.0, 0.0, 0.0)); m_mesh.visible = false
	var flash_core_mesh := SphereMesh.new()
	flash_core_mesh.radius = 0.045
	flash_core_mesh.height = 0.09
	var flash_core_mat := StandardMaterial3D.new()
	flash_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_core_mat.albedo_color = Color(1.0, 0.95, 0.62, 0.9)
	flash_core_mat.emission_enabled = true
	flash_core_mat.emission = Color(1.0, 0.76, 0.28)
	flash_core_mat.emission_energy_multiplier = 7.0
	flash_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var flash_core := MeshInstance3D.new()
	flash_core.mesh = flash_core_mesh
	flash_core.material_override = flash_core_mat
	m_mesh.add_child(flash_core)
	if is_local: muzzle_flash_mesh = m_mesh

	if is_local:
		flashlight_node = SpotLight3D.new()
		flashlight_node.name = "WeaponFlashlight"
		flashlight_node.position = flash_pos + Vector3(-0.04, 0.02, 0.12)
		flashlight_node.spot_range = 24.0
		flashlight_node.spot_angle = 32.0
		flashlight_node.light_energy = 3.0
		flashlight_node.shadow_enabled = false
		flashlight_node.visible = flashlight_enabled
		w_root.add_child(flashlight_node)
	
func spawn_ejected_shell_casing() -> void:
	if not is_instance_valid(ejection_port_marker):
		return

	if shell_casing_count >= max_shell_casings:
		return

	var weapon := get_current_weapon()

	if weapon == WeaponType.FISTS:
		return

	shell_casing_count += 1

	var casing := RigidBody3D.new()

	casing.name = "ShellCasing"

	# Debris has its own layer so shell ejection cannot bump the player.
	casing.collision_layer = SHELL_CASING_COLLISION_LAYER
	casing.collision_mask = 1

	casing.mass = 0.045

	casing.linear_damp = 0.18
	casing.angular_damp = 1.15

	casing.continuous_cd = true
	casing.can_sleep = true

	casing.global_transform = (
		ejection_port_marker.global_transform
	)

	# --------------------------------------------------------
	# PHYSICAL MATERIAL
	# --------------------------------------------------------

	var physics_material := PhysicsMaterial.new()

	physics_material.friction = 0.38
	physics_material.bounce = 0.24
	physics_material.rough = true

	casing.physics_material_override = physics_material

	get_tree().root.add_child(casing)

	# --------------------------------------------------------
	# DIMENSIONS
	# --------------------------------------------------------

	var radius := 0.005
	var height := 0.028

	match weapon:
		WeaponType.AK47:
			radius = 0.005
			height = 0.028

		WeaponType.SNIPER_R700:
			radius = 0.007
			height = 0.085

		WeaponType.REMINGTON870:
			radius = 0.011
			height = 0.045

	# --------------------------------------------------------
	# COLLISION
	# --------------------------------------------------------

	var collision := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()

	cylinder_shape.radius = radius
	cylinder_shape.height = height

	collision.shape = cylinder_shape

	casing.add_child(collision)

	# --------------------------------------------------------
	# MAIN CASING VISUAL
	# --------------------------------------------------------

	var casing_mesh := MeshInstance3D.new()
	var casing_cylinder := CylinderMesh.new()

	casing_cylinder.top_radius = radius
	casing_cylinder.bottom_radius = radius
	casing_cylinder.height = height

	casing_mesh.mesh = casing_cylinder

	var casing_material := StandardMaterial3D.new()

	if weapon == WeaponType.REMINGTON870:
		casing_material.albedo_color = Color(
			0.72,
			0.10,
			0.06
		)

		casing_material.roughness = 0.35
		casing_material.metallic = 0.05
	else:
		casing_material.albedo_color = Color(
			0.88,
			0.68,
			0.20
		)

		casing_material.roughness = 0.22
		casing_material.metallic = 0.90

	casing_mesh.material_override = casing_material

	casing.add_child(casing_mesh)

	# --------------------------------------------------------
	# BASE / PRIMER
	# --------------------------------------------------------

	if weapon != WeaponType.REMINGTON870:
		var base_mesh := MeshInstance3D.new()
		var base_cylinder := CylinderMesh.new()

		base_cylinder.top_radius = radius * 1.08
		base_cylinder.bottom_radius = radius * 1.08
		base_cylinder.height = min(
			height * 0.12,
			0.006
		)

		base_mesh.mesh = base_cylinder

		var base_material := StandardMaterial3D.new()
		base_material.albedo_color = Color(
			0.55,
			0.40,
			0.12
		)

		base_material.metallic = 0.95
		base_material.roughness = 0.18

		base_mesh.material_override = base_material

		base_mesh.position.y = -height * 0.43

		casing.add_child(base_mesh)

	# --------------------------------------------------------
	# EJECTION VELOCITY
	# --------------------------------------------------------

	var ejection_basis := casing.global_transform.basis

	var lateral := randf_range(
		3.2,
		4.8
	)

	var upward := randf_range(
		1.8,
		3.0
	)

	var forward_variance := randf_range(
		-0.5,
		0.5
	)

	var exit_velocity := (
		ejection_basis.x * lateral
		+ ejection_basis.y * upward
		+ (-ejection_basis.z) * forward_variance
	)

	if is_instance_valid(local_player_node):
		exit_velocity += (
			local_player_node.velocity
			* 0.25
		)

	casing.linear_velocity = exit_velocity

	# Realistic-looking tumble.
	casing.angular_velocity = Vector3(
		randf_range(-28.0, 28.0),
		randf_range(-28.0, 28.0),
		randf_range(-28.0, 28.0)
	)

	# --------------------------------------------------------
	# CLEANUP
	# --------------------------------------------------------

	get_tree().create_timer(
		3.5
	).timeout.connect(
		func():
			shell_casing_count = maxi(
			shell_casing_count - 1,
			0
		)

			if is_instance_valid(casing):
				casing.queue_free()
	)

func die_and_spawn_ragdoll(
	pos: Vector3,
	impulse: Vector3,
	hit_zone: String = "chest"
) -> void:
	if is_dead: return
	is_dead = true
	report_local_score(0, 1, 0)
	is_sliding = false
	slide_timer = 0.0
	was_crouch_held = Input.is_action_pressed("crouch")
	target_lean = 0.0
	current_lean = 0.0
	death_sequence_id += 1
	var current_death_sequence: int = death_sequence_id
	if is_instance_valid(local_player_node):
		local_player_node.velocity = Vector3.ZERO

	# Leave any vehicle we were driving.
	if is_driving:
		exit_vehicle()
	
	# Show player model for 3rd person spectator/death view
	if is_instance_valid(local_player_node):
		local_player_node.visible = true
		
	# Move camera back for 3rd person death view / kill cam angle
	if is_instance_valid(player_camera) and is_instance_valid(camera_pivot):
		camera_pivot.position = Vector3(0.0, 3.2, 4.0)
		player_camera.look_at(pos + Vector3(0, 1, 0), Vector3.UP)

	spawn_ragdoll_at(pos, Color(0.2, 0.4, 0.8), impulse, hit_zone)
	if current_map_type == MapType.CQB_ARENA:
		cqb_score_enemy += 1
	update_hud_display()

	# Auto respawn after delay and resume round
	get_tree().create_timer(4.0).timeout.connect(func():
		if current_death_sequence != death_sequence_id or not is_dead:
			return
		health = max_health
		stamina = max_stamina
		is_sliding = false
		slide_timer = 0.0
		was_crouch_held = Input.is_action_pressed("crouch")
		target_lean = 0.0
		current_lean = 0.0
		is_dead = false
		fire_pressed_this_frame = false
		aim_button_down = false
		ads_blend = 0.0
		
		if is_instance_valid(local_player_node):
			local_player_node.visible = true # Keep the camera-mounted weapon visible in first person.
			local_player_node.global_position = Vector3(randf_range(-4.0, 4.0), 1.0, randf_range(8.0, 12.0))
			local_player_node.velocity = Vector3.ZERO
			
		camera_pitch = 0.0
		if is_instance_valid(camera_pivot):
			camera_pivot.position = Vector3(0.0, default_cam_height, 0.0)

		update_hud_display()
	)


func spawn_ragdoll_at(
	pos: Vector3,
	col: Color,
	impulse: Vector3,
	hit_zone: String = "chest"
) -> void:
	var ragdoll := Node3D.new()
	ragdoll.name = "Ragdoll"
	add_child(ragdoll)
	ragdoll.global_position = pos
	ragdoll.rotation.y = randf_range(-PI, PI)

	# Place the blood pool on the actual surface below the corpse instead of
	# at the character root (which is usually about one meter above the floor).
	var floor_query := PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 0.3,
		pos - Vector3.UP * 5.0,
		1
	)
	floor_query.collide_with_areas = false
	var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(floor_query)
	if not floor_hit.is_empty():
		var blood_decal := MeshInstance3D.new()
		var blood_mesh := CylinderMesh.new()
		blood_mesh.top_radius = 0.8
		blood_mesh.bottom_radius = 0.8
		blood_mesh.height = 0.01

		var blood_material := StandardMaterial3D.new()
		blood_material.albedo_color = Color(0.35, 0.02, 0.02)
		blood_material.roughness = 0.90

		blood_decal.mesh = blood_mesh
		blood_decal.material_override = blood_material
		add_child(blood_decal)
		var floor_position: Vector3 = floor_hit["position"]
		blood_decal.global_position = floor_position + Vector3.UP * 0.01

		get_tree().create_timer(12.0).timeout.connect(func() -> void:
			if is_instance_valid(blood_decal): blood_decal.queue_free()
		)

	# --------------------------------------------------------
	# HUMANOID RAGDOLL (multi-part, jointed)
	# --------------------------------------------------------
	_build_humanoid_ragdoll(ragdoll, col, impulse, hit_zone)

	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		if is_instance_valid(ragdoll): ragdoll.queue_free()
	)

func _build_humanoid_ragdoll(
	ragdoll: Node3D,
	col: Color,
	impulse: Vector3,
	hit_zone: String
) -> void:
	var part_specs := [
		{"n": "Pelvis",  "p": Vector3(0.0, 0.95, 0.0),   "s": Vector3(0.32, 0.24, 0.22), "m": 8.0},
		{"n": "Torso",   "p": Vector3(0.0, 1.34, 0.0),   "s": Vector3(0.40, 0.46, 0.24), "m": 12.0},
		{"n": "Head",    "p": Vector3(0.0, 1.74, 0.0),   "s": Vector3(0.24, 0.26, 0.24), "m": 4.0},
		{"n": "ArmUpL",  "p": Vector3(-0.30, 1.50, 0.0), "s": Vector3(0.12, 0.34, 0.13), "m": 3.0},
		{"n": "ArmLoL",  "p": Vector3(-0.30, 1.12, 0.0), "s": Vector3(0.10, 0.32, 0.11), "m": 2.0},
		{"n": "ArmUpR",  "p": Vector3(0.30, 1.50, 0.0),  "s": Vector3(0.12, 0.34, 0.13), "m": 3.0},
		{"n": "ArmLoR",  "p": Vector3(0.30, 1.12, 0.0),  "s": Vector3(0.10, 0.32, 0.11), "m": 2.0},
		{"n": "LegUpL",  "p": Vector3(-0.13, 0.62, 0.0), "s": Vector3(0.16, 0.44, 0.17), "m": 6.0},
		{"n": "LegLoL",  "p": Vector3(-0.13, 0.18, 0.0), "s": Vector3(0.13, 0.42, 0.14), "m": 5.0},
		{"n": "LegUpR",  "p": Vector3(0.13, 0.62, 0.0),  "s": Vector3(0.16, 0.44, 0.17), "m": 6.0},
		{"n": "LegLoR",  "p": Vector3(0.13, 0.18, 0.0),  "s": Vector3(0.13, 0.42, 0.14), "m": 5.0},
	]

	var parts := {}
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.13, 0.16, 0.14).lerp(col, 0.16)
	cloth_mat.roughness = 0.78
	cloth_mat.metallic = 0.02
	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_color = Color(0.075, 0.09, 0.095)
	armor_mat.roughness = 0.7
	armor_mat.metallic = 0.08
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.62, 0.43, 0.32)
	skin_mat.roughness = 0.78

	for spec in part_specs:
		var body := RigidBody3D.new()
		body.name = "RagdollPart_" + str(spec["n"])
		body.position = spec["p"]
		body.mass = spec["m"]
		# Connected pieces collide with the world, but not with one another.
		body.collision_layer = RAGDOLL_COLLISION_LAYER
		body.collision_mask = 1
		body.linear_damp = 0.25
		body.angular_damp = 1.2
		body.can_sleep = true

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec["s"]
		cs.shape = box
		body.add_child(cs)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec["s"]
		mi.mesh = bm
		var part_name := str(spec["n"])
		mi.material_override = skin_mat if part_name == "Head" else (armor_mat if part_name == "Torso" else cloth_mat)
		body.add_child(mi)

		ragdoll.add_child(body)
		parts[spec["n"]] = body

	var joint_specs := [
		["Pelvis", "Torso", Vector3(0.0, 1.14, 0.0), 0.55, 0.45],
		["Torso", "Head", Vector3(0.0, 1.55, 0.0), 0.45, 0.30],
		["Torso", "ArmUpL", Vector3(-0.26, 1.52, 0.0), 1.05, 0.65],
		["ArmUpL", "ArmLoL", Vector3(-0.30, 1.29, 0.0), 0.70, 0.35],
		["Torso", "ArmUpR", Vector3(0.26, 1.52, 0.0), 1.05, 0.65],
		["ArmUpR", "ArmLoR", Vector3(0.30, 1.29, 0.0), 0.70, 0.35],
		["Pelvis", "LegUpL", Vector3(-0.13, 0.86, 0.0), 0.75, 0.45],
		["LegUpL", "LegLoL", Vector3(-0.13, 0.40, 0.0), 0.75, 0.25],
		["Pelvis", "LegUpR", Vector3(0.13, 0.86, 0.0), 0.75, 0.45],
		["LegUpR", "LegLoR", Vector3(0.13, 0.40, 0.0), 0.75, 0.25],
	]

	for js in joint_specs:
		var parent_body: RigidBody3D = parts[js[0]]
		var child_body: RigidBody3D = parts[js[1]]
		if parent_body == null or child_body == null:
			continue
		var joint := ConeTwistJoint3D.new()
		joint.name = "Joint_" + str(js[1])
		ragdoll.add_child(joint)
		joint.position = js[2]
		joint.node_a = parent_body.get_path()
		joint.node_b = child_body.get_path()
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, float(js[3]))
		joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, float(js[4]))
		joint.set_param(ConeTwistJoint3D.PARAM_BIAS, 0.65)
		joint.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.75)
		joint.set_param(ConeTwistJoint3D.PARAM_RELAXATION, 1.0)

	for pn in ["Torso", "Pelvis", "Head", "ArmUpL", "ArmUpR"]:
		var b: RigidBody3D = parts[pn]
		if b == null:
			continue
		_ragdoll_impulse(b, impulse)

	_add_ragdoll_blood_mark(parts, hit_zone)


func _add_ragdoll_blood_mark(parts: Dictionary, hit_zone: String) -> void:
	var part_name: String = "Torso"
	var part_size: Vector3 = Vector3(0.40, 0.46, 0.24)
	match hit_zone:
		"head":
			part_name = "Head"
			part_size = Vector3(0.24, 0.26, 0.24)
		"legs":
			part_name = "LegUpL"
			part_size = Vector3(0.16, 0.44, 0.17)

	var body: RigidBody3D = parts.get(part_name)
	if not is_instance_valid(body):
		return

	var blood_material := StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.38, 0.015, 0.02)
	blood_material.roughness = 0.95

	# Small surface marks keep blood localized to the hit area.
	for side in [-1.0, 1.0]:
		var blood_mark := MeshInstance3D.new()
		var mark_mesh := SphereMesh.new()
		mark_mesh.radius = 0.065
		mark_mesh.height = 0.13
		blood_mark.mesh = mark_mesh
		blood_mark.material_override = blood_material
		blood_mark.scale = Vector3(1.1, 0.75, 0.16)
		blood_mark.position = Vector3(0.0, 0.0, side * (part_size.z * 0.5 + 0.002))
		body.add_child(blood_mark)


func _ragdoll_impulse(body: RigidBody3D, impulse: Vector3) -> void:
	var launch_velocity: Vector3 = (
		impulse.limit_length(14.0) * 0.45
		+ Vector3(randf_range(-1.5, 1.5), randf_range(0.6, 2.6), randf_range(-1.5, 1.5))
	)
	body.linear_velocity = launch_velocity.limit_length(8.0)
	body.angular_velocity = Vector3(
		randf_range(-4.0, 4.0),
		randf_range(-4.0, 4.0),
		randf_range(-4.0, 4.0)
	)


@rpc("any_peer", "call_local")
func net_spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var spark = Node3D.new(); spark.position = pos; get_tree().root.add_child(spark)
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.82, 0.2); mat.emission_enabled = true; mat.emission = Color(1.0, 0.6, 0.1)
	for i in range(8):
		var p = MeshInstance3D.new(); var b = BoxMesh.new(); b.size = Vector3(0.012, 0.012, 0.012); p.mesh = b; p.material_override = mat; spark.add_child(p)
		var dir = (normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))).normalized()
		var tw = p.create_tween(); tw.tween_property(p, "position", dir * randf_range(0.2, 0.6), 0.22)
	get_tree().create_timer(0.25).timeout.connect(spark.queue_free)


@rpc("any_peer", "call_local")
func net_trigger_explosion(path: NodePath) -> void:
	if has_node(path):
		var node = get_node(path)
		if node is RigidBody3D: 
			trigger_barrel_explosion(node)


func trigger_barrel_explosion(barrel: RigidBody3D) -> void:
	if not is_instance_valid(barrel) or bool(barrel.get_meta("explosion_triggered", false)):
		return
	barrel.set_meta("explosion_triggered", true)
	var explosion_position := barrel.global_position
	var source_rid := barrel.get_rid()
	barrel.queue_free()
	spawn_explosion_visual(explosion_position)

	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 7.0
	query.shape = sphere
	query.transform = Transform3D(Basis(), explosion_position)
	query.exclude = [source_rid]
	var results := space.intersect_shape(query, 48)
	
	for result in results:
		var collider: Object = result.get("collider")
		if not is_instance_valid(collider) or not collider is Node3D:
			continue
		var target := collider as Node3D
		var distance_to_explosion := explosion_position.distance_to(target.global_position)
		var damage_falloff := clampf(1.0 - distance_to_explosion / 7.0, 0.1, 1.0)
		var explosion_damage := 85.0 * damage_falloff

		if target == local_player_node and not god_mode:
			health = maxf(health - explosion_damage, 0.0)
			update_hud_display()
			
			if health <= 0.0 and not is_dead:
				var killer_id := multiplayer.get_remote_sender_id()
				if killer_id != 0 and killer_id != local_player_id:
					rpc_id(killer_id, "net_award_kill")
				die_and_spawn_ragdoll(local_player_node.global_position, (local_player_node.global_position - explosion_position).normalized() * 10.0)

		elif target.has_meta("is_npc"):
			var current_hp := float(target.get_meta("hp", 100.0)) - explosion_damage
			target.set_meta("hp", current_hp)
			
			if current_hp <= 0.0 and not bool(target.get_meta("ragdoll_spawned", false)):
				target.set_meta("ragdoll_spawned", true)
				spawn_ragdoll_at(target.global_position, Color(0.26, 0.30, 0.24), Vector3(0.0, 5.0, 0.0))
				target.queue_free()
				register_cqb_player_kill()

		elif target is RigidBody3D:
			var body := target as RigidBody3D
			var direction := body.global_position - explosion_position
			if direction.length_squared() < 0.001:
				direction = Vector3.UP
			var safe_impulse_strength := minf(35.0 * damage_falloff, 40.0)
			body.apply_central_impulse(direction.normalized() * safe_impulse_strength)
			
func spawn_explosion_visual(spawn_position: Vector3) -> void: # Renamed parameter here too
	var effect := Node3D.new()
	effect.name = "BarrelExplosionFX"
	add_child(effect)
	effect.global_position = spawn_position

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.44, 0.12)
	flash.light_energy = 20.0
	flash.omni_range = 14.0
	flash.shadow_enabled = false
	effect.add_child(flash)

	var fire_material := StandardMaterial3D.new()
	fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_material.albedo_color = Color(1.0, 0.30, 0.035, 0.92)
	fire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_material.emission_enabled = true
	fire_material.emission = Color(1.0, 0.23, 0.025)
	fire_material.emission_energy_multiplier = 3.0
	
	var fireball := MeshInstance3D.new()
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.78
	fire_mesh.height = 1.56
	fireball.mesh = fire_mesh
	fireball.material_override = fire_material
	fireball.scale = Vector3.ONE * 0.18
	effect.add_child(fireball)

	var shock_material := StandardMaterial3D.new()
	shock_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_material.albedo_color = Color(1.0, 0.64, 0.20, 0.82)
	shock_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_material.emission_enabled = true
	shock_material.emission = Color(1.0, 0.38, 0.07)
	shock_material.emission_energy_multiplier = 1.8
	
	var shockwave := MeshInstance3D.new()
	var shock_mesh := TorusMesh.new()
	shock_mesh.inner_radius = 0.72
	shock_mesh.outer_radius = 0.88
	shockwave.mesh = shock_mesh
	shockwave.rotation_degrees.x = 90.0
	shockwave.position.y = -0.38
	shockwave.scale = Vector3.ONE * 0.22
	shockwave.material_override = shock_material
	effect.add_child(shockwave)

	var base_smoke_material := StandardMaterial3D.new()
	base_smoke_material.albedo_color = Color(0.16, 0.13, 0.12, 0.55)
	base_smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_smoke_material.roughness = 1.0

	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(flash, "light_energy", 0.0, 0.42)
	tween.tween_property(fireball, "scale", Vector3.ONE * 3.2, 0.38)
	tween.tween_property(fire_material, "albedo_color:a", 0.0, 0.38)
	tween.tween_property(shockwave, "scale", Vector3.ONE * 4.4, 0.48)
	tween.tween_property(shock_material, "albedo_color:a", 0.0, 0.48)

	for i in range(4):
		var smoke := MeshInstance3D.new()
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.48
		smoke_mesh.height = 0.96
		smoke.mesh = smoke_mesh
		
		var smoke_material := base_smoke_material.duplicate() as StandardMaterial3D
		smoke.material_override = smoke_material
		
		smoke.position = Vector3(randf_range(-0.28, 0.28), randf_range(-0.08, 0.28), randf_range(-0.28, 0.28))
		smoke.scale = Vector3.ONE * 0.35
		effect.add_child(smoke)
		
		var target_pos = smoke.position + Vector3(randf_range(-0.8, 0.8), randf_range(1.4, 2.4), randf_range(-0.8, 0.8))
		tween.tween_property(smoke, "position", target_pos, 0.9)
		tween.tween_property(smoke, "scale", Vector3.ONE * randf_range(2.0, 3.0), 0.9)
		tween.tween_property(smoke_material, "albedo_color:a", 0.0, 0.9)

	tween.chain().tween_callback(effect.queue_free)

func throw_tactical_grenade() -> void:
	var origin = player_camera.global_position - player_camera.global_transform.basis.z * 0.5
	var vel = (-player_camera.global_transform.basis.z + Vector3(0, 0.2, 0)).normalized() * 18.0 + local_player_node.velocity
	rpc("net_spawn_grenade", origin, vel)


@rpc("any_peer", "call_local")
func net_spawn_grenade(origin: Vector3, vel: Vector3) -> void:
	var nade = RigidBody3D.new(); nade.mass = 0.8
	var col = CollisionShape3D.new(); var s = SphereShape3D.new(); s.radius = 0.1; col.shape = s; nade.add_child(col)
	var m = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 0.1; sm.height = 0.2; m.mesh = sm; nade.add_child(m)
	nade.global_position = origin; get_tree().root.add_child(nade); nade.linear_velocity = vel
	get_tree().create_timer(2.5).timeout.connect(func(): trigger_barrel_explosion(nade))


# --- NIGHT MODE, MOON, & NIGHT VISION ---
func apply_night_mode() -> void:
	if not world_env or not world_env.environment: return
	var env = world_env.environment
	var sky = env.sky
	if sky and sky.sky_material is ProceduralSkyMaterial:
		var sky_mat = sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
		sky_mat.sky_horizon_color = Color(0.08, 0.10, 0.18)
		sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
		sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.10)
		sky_mat.energy_multiplier = 0.15

	# Dim the sun drastically
	if sun_light:
		sun_light.light_energy = 0.05
		sun_light.light_color = Color(0.6, 0.7, 0.9)

	# Create moon directional light if not exists
	if not moon_light:
		moon_light = DirectionalLight3D.new()
		moon_light.rotation_degrees = Vector3(-30, -120, 0)
		moon_light.shadow_enabled = true
		moon_light.light_color = Color(0.7, 0.8, 1.0)
		moon_light.light_energy = 0.35
		moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		add_child(moon_light)
	else:
		moon_light.visible = true

	# Add a visible moon mesh in the sky
	if not moon_mesh:
		moon_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 8.0
		sphere.height = 16.0
		moon_mesh.mesh = sphere
		var moon_mat = StandardMaterial3D.new()
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_mat.albedo_color = Color(0.9, 0.9, 0.85)
		moon_mat.emission_enabled = true
		moon_mat.emission = Color(0.8, 0.8, 0.9)
		moon_mat.emission_energy_multiplier = 1.5
		moon_mesh.material_override = moon_mat
		moon_mesh.position = Vector3(-80, 120, -150) # Far away in the sky
		add_child(moon_mesh)
	else:
		moon_mesh.visible = true

	# Adjust volumetric fog for night
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.1, 0.12, 0.2)


func apply_day_mode() -> void:
	if not world_env or not world_env.environment: return
	var env = world_env.environment
	var sky = env.sky
	if sky and sky.sky_material is ProceduralSkyMaterial:
		var sky_mat = sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color = Color(0.15, 0.35, 0.68)
		sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.88)
		sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.14)
		sky_mat.ground_horizon_color = Color(0.55, 0.60, 0.65)
		sky_mat.energy_multiplier = 1.15

	if sun_light:
		sun_light.light_energy = 1.35
		sun_light.light_color = Color(1.0, 0.95, 0.86)

	if moon_light:
		moon_light.visible = false
	if moon_mesh:
		moon_mesh.visible = false

	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.75, 0.82, 0.90)


func build_night_vision_overlay() -> void:
	var cl = CanvasLayer.new(); add_child(cl)
	night_vision_overlay = ColorRect.new()
	night_vision_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_vision_overlay.visible = false
	night_vision_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(night_vision_overlay)

	# Simple green-tinted shader for night vision effect
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensity = 0.85;
uniform vec3 tint : source_color = vec3(0.15, 1.0, 0.30);
uniform float noise_amount = 0.06;
uniform float vignette_strength = 0.55;
uniform float scanline_strength = 0.08;
uniform float edge_boost = 1.4;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	vec4 scene_color = texture(screen_texture, uv);

	float luminance = luma(scene_color.rgb);

	// Light-amplification accentuates edges (cheap sobel-ish pass).
	float l_up = luma(texture(screen_texture, uv + vec2(0.0, -px.y)).rgb);
	float l_down = luma(texture(screen_texture, uv + vec2(0.0, px.y)).rgb);
	float l_left = luma(texture(screen_texture, uv + vec2(-px.x, 0.0)).rgb);
	float l_right = luma(texture(screen_texture, uv + vec2(px.x, 0.0)).rgb);
	float edge = abs(l_up - l_down) + abs(l_left - l_right);

	// Gamma-lifted amplification.
	float amplified = pow(clamp(luminance, 0.0, 1.0), 0.68) * 1.6;
	amplified += edge * edge_boost;

	vec3 night_image = tint * amplified;

	// Sensor grain / noise.
	float grain = rand(uv + fract(TIME)) - 0.5;
	night_image += grain * noise_amount;

	// Scope-style circular vignette.
	vec2 centered = uv - vec2(0.5);
	float vig = smoothstep(0.85, 0.35, length(centered));
	night_image *= mix(1.0, vig, vignette_strength);

	// Faint horizontal scanlines.
	float scan = sin(uv.y / max(px.y, 0.0001) * 3.14159265);
	night_image *= 1.0 - scanline_strength * (scan * 0.5 + 0.5);

	vec3 final_color = mix(scene_color.rgb, night_image, intensity);

	COLOR = vec4(final_color, 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.85)
	mat.set_shader_parameter("tint", Color(0.15, 1.0, 0.30))
	mat.set_shader_parameter("noise_amount", 0.06)
	mat.set_shader_parameter("vignette_strength", 0.55)
	mat.set_shader_parameter("scanline_strength", 0.08)
	mat.set_shader_parameter("edge_boost", 1.4)
	night_vision_overlay.material = mat


# ============================================================
# ADVANCED REALISTIC DAY / NIGHT ENVIRONMENT
# ============================================================

func setup_world_environment() -> void:
	# Prevent duplicate environments.
	if is_instance_valid(world_env):
		world_env.queue_free()
		world_env = null

	if is_instance_valid(sun_light):
		sun_light.queue_free()
		sun_light = null

	if is_instance_valid(tac_moon_light):
		tac_moon_light.queue_free()
		tac_moon_light = null

	world_env = WorldEnvironment.new()
	tac_environment = Environment.new()

	var env := tac_environment

	# --------------------------------------------------------
	# SKY
	# --------------------------------------------------------

	var sky_material := ProceduralSkyMaterial.new()

	if tac_night_mode:
		sky_material.sky_top_color = Color(
			0.003,
			0.006,
			0.022
		)

		sky_material.sky_horizon_color = Color(
			0.025,
			0.045,
			0.090
		)

		sky_material.ground_horizon_color = Color(
			0.015,
			0.020,
			0.030
		)

		sky_material.ground_bottom_color = Color(
			0.003,
			0.004,
			0.007
		)
	else:
		sky_material.sky_top_color = Color(
			0.055,
			0.17,
			0.45
		)

		sky_material.sky_horizon_color = Color(
			0.58,
			0.70,
			0.88
		)

		sky_material.ground_horizon_color = Color(
			0.43,
			0.45,
			0.40
		)

		sky_material.ground_bottom_color = Color(
			0.075,
			0.070,
			0.060
		)

	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky

	# --------------------------------------------------------
	# BACKGROUND
	# --------------------------------------------------------

	env.background_mode = Environment.BG_SKY

	# --------------------------------------------------------
	# TONEMAPPING
	# --------------------------------------------------------

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	if tac_night_mode:
		env.tonemap_exposure = 0.72
	else:
		env.tonemap_exposure = 1.05

	# --------------------------------------------------------
	# AMBIENT LIGHT
	# --------------------------------------------------------

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	if tac_night_mode:
		env.ambient_light_energy = 0.18
		env.ambient_light_color = Color(
			0.12,
			0.17,
			0.31
		)
		env.ambient_light_sky_contribution = 0.95
	else:
		env.ambient_light_energy = 0.72
		env.ambient_light_color = Color(
			0.93,
			0.95,
			1.0
		)
		env.ambient_light_sky_contribution = 0.82

	# --------------------------------------------------------
	# BLOOM
	# --------------------------------------------------------

	env.glow_enabled = true
	env.glow_intensity = 0.82
	env.glow_bloom = 0.18

	# --------------------------------------------------------
	# SSAO
	# --------------------------------------------------------

	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.ssao_sharpness = 0.9

	# --------------------------------------------------------
	# SSIL
	# --------------------------------------------------------

	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.ssil_sharpness = 1.0
	env.ssil_normal_rejection = 0.9

	# --------------------------------------------------------
	# SCREEN SPACE REFLECTIONS
	# --------------------------------------------------------

	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.10
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.20

	# --------------------------------------------------------
	# ATMOSPHERIC FOG
	# --------------------------------------------------------

	env.fog_enabled = fog_enabled

	if tac_night_mode:
		env.fog_light_color = Color(
			0.08,
			0.11,
			0.20
		)

		env.fog_light_energy = 0.45
		env.fog_density = 0.016
		env.fog_height = 1.3
		env.fog_height_density = 0.045
		env.fog_sky_affect = 0.70
	else:
		env.fog_light_color = Color(
			0.72,
			0.79,
			0.88
		)

		env.fog_light_energy = 0.68
		env.fog_density = 0.007
		env.fog_height = 1.0
		env.fog_height_density = 0.025
		env.fog_sky_affect = 0.26

	env.fog_aerial_perspective = 0.65

	# --------------------------------------------------------
	# COLOR GRADING
	# --------------------------------------------------------

	env.adjustment_enabled = true

	if tac_night_mode:
		env.adjustment_brightness = 0.92
		env.adjustment_contrast = 1.15
		env.adjustment_saturation = 0.82
	else:
		env.adjustment_brightness = 1.02
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.04

	# --------------------------------------------------------
	# ADVANCED POST-PROCESSING / VOLUMETRICS OVERHAUL
	# --------------------------------------------------------

	env.set("background_energy_multiplier", 1.0 if not tac_night_mode else 0.30)
	env.set("tonemap_white", 6.0)

	# Glow / bloom with per-level tuning.
	env.glow_enabled = true
	env.glow_intensity = 1.05
	env.glow_strength = 1.15
	env.glow_bloom = 0.22
	env.set("glow_normalized", true)
	env.set("glow_hdr_threshold", 0.85)
	env.set("glow_hdr_scale", 2.0)
	env.set("glow_blend_mode", Environment.GLOW_BLEND_MODE_SCREEN)
	env.set("glow_levels/1", 0.4)
	env.set("glow_levels/2", 0.6)
	env.set("glow_levels/3", 0.85)
	env.set("glow_levels/4", 0.7)
	env.set("glow_levels/5", 0.5)
	env.set("glow_levels/6", 0.3)
	env.set("glow_levels/7", 0.2)

	# Ambient occlusion (detailed, horizon based off for cleaner look).
	env.set("ssao_detail", 0.5)
	env.set("ssao_light_affect", 0.25)
	env.set("ssao_ao_channel_affect", 0.0)
	env.set("ssao_horizon_based", false)

	# Volumetric fog / god rays.
	env.set("volumetric_fog_enabled", fog_enabled)
	env.set("volumetric_fog_length", 180.0)
	env.set("volumetric_fog_anisotropy", 0.35)
	env.set("volumetric_fog_detail_spread", 2.0)
	env.set("volumetric_fog_gi_inject", 1.0)
	env.set("volumetric_fog_ambient_inject", 0.25)
	env.set("volumetric_fog_temporal_reprojection_enabled", true)
	env.set("volumetric_fog_temporal_reprojection_amount", 0.90)
	if tac_night_mode:
		env.set("volumetric_fog_emission", Color(0.02, 0.03, 0.06))
		env.set("volumetric_fog_emission_energy", 0.4)
	else:
		env.set("volumetric_fog_emission", Color(0.02, 0.02, 0.02))
		env.set("volumetric_fog_emission_energy", 0.1)

	# --------------------------------------------------------
	# FINALIZE ENVIRONMENT
	# --------------------------------------------------------

	world_env.environment = env
	add_child(world_env)
	setup_cloud_layer()
	apply_graphics_settings()

	# --------------------------------------------------------
	# SUN
	# --------------------------------------------------------

	sun_light = DirectionalLight3D.new()

	if tac_night_mode:
		sun_light.rotation_degrees = Vector3(
			-20.0,
			135.0,
			0.0
		)

		sun_light.light_color = Color(
			0.08,
			0.12,
			0.25
		)

		sun_light.light_energy = 0.015
	else:
		sun_light.rotation_degrees = Vector3(
			-48.0,
			42.0,
			0.0
		)

		sun_light.light_color = Color(
			1.0,
			0.91,
			0.78
		)

		sun_light.light_energy = 1.30

	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 220.0
	sun_light.set("directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	sun_light.set("directional_shadow_split_1", 0.10)
	sun_light.set("directional_shadow_split_2", 0.25)
	sun_light.set("directional_shadow_split_3", 0.55)
	sun_light.shadow_bias = 0.05
	sun_light.shadow_normal_bias = 1.5
	sun_light.shadow_blur = 1.2
	sun_light.light_angular_distance = 1.0
	sun_light.set("light_volumetric_fog_energy", 1.6)

	add_child(sun_light)

	# --------------------------------------------------------
	# MOON
	# --------------------------------------------------------

	tac_moon_light = DirectionalLight3D.new()

	tac_moon_light.rotation_degrees = Vector3(
		-34.0,
		-40.0,
		0.0
	)

	tac_moon_light.shadow_enabled = true
	tac_moon_light.directional_shadow_max_distance = 180.0
	tac_moon_light.shadow_bias = 0.05
	tac_moon_light.shadow_normal_bias = 1.5
	tac_moon_light.set("shadow_blur", 1.2)
	tac_moon_light.set("light_volumetric_fog_energy", 1.0)

	if tac_night_mode:
		tac_moon_light.light_color = Color(
			0.30,
			0.42,
			0.90
		)

		tac_moon_light.light_energy = 0.28
		tac_moon_light.visible = true
	else:
		tac_moon_light.light_energy = 0.0
		tac_moon_light.visible = false

	add_child(tac_moon_light)

func build_cqb_arena_map() -> void:
	# Large polished indoor arena floor
	create_wall_structure(Vector3(0, -1, 0), Vector3(200, 2, 200), Color(0.20, 0.22, 0.25), 0.2, 0.8)
	# Outer perimeter walls (taller for bigger arena)
	create_wall_structure(Vector3(0, 6, -100), Vector3(200, 12, 1), Color(0.28, 0.30, 0.34))
	create_wall_structure(Vector3(0, 6, 100), Vector3(200, 12, 1), Color(0.28, 0.30, 0.34))
	create_wall_structure(Vector3(-100, 6, 0), Vector3(1, 12, 200), Color(0.28, 0.30, 0.34))
	create_wall_structure(Vector3(100, 6, 0), Vector3(1, 12, 200), Color(0.28, 0.30, 0.34))
	
	# Central structure cluster
	create_wall_structure(Vector3(0, 2, -15), Vector3(24, 4, 1), Color(0.32, 0.36, 0.40))
	create_wall_structure(Vector3(-15, 2, 10), Vector3(1, 4, 30), Color(0.32, 0.36, 0.40))
	create_wall_structure(Vector3(15, 2, 10), Vector3(1, 4, 30), Color(0.32, 0.36, 0.40))
	
	# Flanking rooms / buildings
	create_wall_structure(Vector3(-40, 3, -30), Vector3(16, 6, 16), Color(0.35, 0.38, 0.42))
	create_wall_structure(Vector3(40, 3, -30), Vector3(16, 6, 16), Color(0.35, 0.38, 0.42))
	create_wall_structure(Vector3(-40, 3, 40), Vector3(20, 6, 12), Color(0.33, 0.36, 0.40))
	create_wall_structure(Vector3(40, 3, 40), Vector3(20, 6, 12), Color(0.33, 0.36, 0.40))
	
	# Elevated platforms / sniper perches
	create_wall_structure(Vector3(0, 4, 70), Vector3(30, 0.5, 20), Color(0.25, 0.28, 0.32))
	create_wall_structure(Vector3(-60, 5, 0), Vector3(0.5, 10, 40), Color(0.30, 0.33, 0.36))
	create_wall_structure(Vector3(60, 5, 0), Vector3(0.5, 10, 40), Color(0.30, 0.33, 0.36))
	
	# Ramp to elevated platform
	var ramp2 = StaticBody3D.new(); ramp2.position = Vector3(0, 2, 55); ramp2.rotation_degrees = Vector3(-15, 0, 0); add_child(ramp2)
	var rc2 = CollisionShape3D.new(); var rb2 = BoxShape3D.new(); rb2.size = Vector3(8, 0.4, 16); rc2.shape = rb2; ramp2.add_child(rc2)
	var rm2 = MeshInstance3D.new(); var rbm2 = BoxMesh.new(); rbm2.size = rb2.size; rm2.mesh = rbm2
	rm2.material_override = get_cached_procedural_material("ramp_mat_cqb", Color(0.25, 0.28, 0.30), 0.5, 0.2)
	ramp2.add_child(rm2)
	
	# Cover blocks scattered
	for i in range(12):
		create_wall_structure(Vector3(randf_range(-70, 70), 1.2, randf_range(-80, 80)), Vector3(2.5, 2.5, 2.5), Color(0.40, 0.38, 0.35), 0.6, 0.1)

	# Vehicles
	vehicles.clear()
	build_car(Vector3(0, 0.42, 30), 0.0)
	build_car(Vector3(22, 0.42, 24), 180.0)

	if multiplayer.is_server():
		for i in range(20): spawn_sandbox_object(Vector3(randf_range(-60, 60), 1, randf_range(-60, 60)), ObjectType.EXPLOSIVE_BARREL if i % 3 == 0 else (ObjectType.AMMO_BOX if i % 3 == 1 else ObjectType.INDUSTRIAL_CRATE))
		for i in range(12): spawn_sandbox_object(Vector3(randf_range(-80, 80), 1, randf_range(-80, 80)), ObjectType.TARGET_DUMMY)


func build_advanced_tactical_map() -> void:
	# Much larger ground plane
	create_wall_structure(Vector3(0, -1, 0), Vector3(400, 2, 400), Color(0.18, 0.22, 0.16), 0.8, 0.0)
	# Perimeter walls
	create_wall_structure(Vector3(0, 8, -200), Vector3(400, 16, 2), Color(0.24, 0.26, 0.28))
	create_wall_structure(Vector3(0, 8, 200), Vector3(400, 16, 2), Color(0.24, 0.26, 0.28))
	create_wall_structure(Vector3(-200, 8, 0), Vector3(2, 16, 400), Color(0.24, 0.26, 0.28))
	create_wall_structure(Vector3(200, 8, 0), Vector3(2, 16, 400), Color(0.24, 0.26, 0.28))

	# Central fort structure
	create_wall_structure(Vector3(0, 5, -60), Vector3(18, 0.5, 18), Color(0.30, 0.32, 0.35))
	create_wall_structure(Vector3(-8.5, 8, -60), Vector3(1, 6, 18), Color(0.22, 0.24, 0.26))
	create_wall_structure(Vector3(8.5, 8, -60), Vector3(1, 6, 18), Color(0.22, 0.24, 0.26))

	# Ramp to fort
	var ramp = StaticBody3D.new(); ramp.position = Vector3(0, 2.5, -45); ramp.rotation_degrees = Vector3(18, 0, 0); add_child(ramp)
	var r_col = CollisionShape3D.new(); var r_box = BoxShape3D.new(); r_box.size = Vector3(6, 0.4, 20); r_col.shape = r_box; ramp.add_child(r_col)
	var r_mesh = MeshInstance3D.new(); var r_bm = BoxMesh.new(); r_bm.size = r_box.size; r_mesh.mesh = r_bm
	r_mesh.material_override = get_cached_procedural_material("ramp_mat", Color(0.25, 0.28, 0.30), 0.5, 0.2)
	ramp.add_child(r_mesh)

	# Long-range firing lanes
	for dist in [10, 25, 50, 80, 120, 150, 180]:
		create_wall_structure(Vector3(45, 1.5, -dist + 20), Vector3(16, 3, 0.4), Color(0.42, 0.36, 0.28))

	# Colorful container buildings
	create_wall_structure(Vector3(-45, 2.5, -20), Vector3(6, 5, 14), Color(0.12, 0.32, 0.62), 0.3, 0.7)
	create_wall_structure(Vector3(-55, 2.5, -15), Vector3(14, 5, 6), Color(0.68, 0.22, 0.15), 0.3, 0.7)
	create_wall_structure(Vector3(-35, 2.5, 30), Vector3(6, 5, 14), Color(0.22, 0.48, 0.25), 0.3, 0.7)
	
	# New: additional structures spread across larger map
	create_wall_structure(Vector3(60, 3, 60), Vector3(20, 6, 20), Color(0.30, 0.34, 0.38)) # Big building SE
	create_wall_structure(Vector3(-60, 3, 60), Vector3(18, 6, 18), Color(0.28, 0.32, 0.36)) # Building SW
	create_wall_structure(Vector3(80, 4, -80), Vector3(25, 8, 25), Color(0.26, 0.30, 0.34)) # Large warehouse NE
	create_wall_structure(Vector3(-80, 4, -80), Vector3(22, 8, 22), Color(0.32, 0.36, 0.40)) # Warehouse NW
	
	# Tower / watchtower like structures
	create_wall_structure(Vector3(120, 8, 0), Vector3(6, 16, 6), Color(0.34, 0.38, 0.42))
	create_wall_structure(Vector3(-120, 8, 0), Vector3(6, 16, 6), Color(0.34, 0.38, 0.42))
	create_wall_structure(Vector3(0, 8, 120), Vector3(6, 16, 6), Color(0.34, 0.38, 0.42))
	create_wall_structure(Vector3(0, 8, -120), Vector3(6, 16, 6), Color(0.34, 0.38, 0.42))
	
	# Scattered rock/concrete cover across the field
	for i in range(25):
		create_wall_structure(
			Vector3(randf_range(-150, 150), randf_range(1.0, 3.0), randf_range(-150, 150)),
			Vector3(randf_range(3, 8), randf_range(2, 5), randf_range(3, 8)),
			Color(randf_range(0.2, 0.4), randf_range(0.2, 0.35), randf_range(0.2, 0.3)),
			0.7, 0.05
		)

	# Vehicles
	vehicles.clear()
	build_car(Vector3(0, 0.42, 42), 0.0)
	build_car(Vector3(26, 0.42, 34), 180.0)
	build_car(Vector3(-26, 0.42, 34), 90.0)

	if multiplayer.is_server():
		for i in range(25): spawn_sandbox_object(Vector3(-20 + (i * 6), 1, 15), ObjectType.DEFENSE_BARRIER)
		for i in range(40): spawn_sandbox_object(Vector3(randf_range(-90, 90), 2, randf_range(-90, 90)), ObjectType.EXPLOSIVE_BARREL if i % 2 == 0 else ObjectType.AMMO_BOX)
		for i in range(12): spawn_sandbox_object(Vector3(45, 1, -10 - (i * 15)), ObjectType.TARGET_DUMMY)
		for i in range(15): spawn_sandbox_object(Vector3(randf_range(-120, 120), 3, randf_range(-120, 120)), ObjectType.SHIPPING_CONTAINER if i % 3 == 0 else ObjectType.INDUSTRIAL_CRATE)


func create_wall_structure(pos: Vector3, size: Vector3, color: Color = Color(0.24, 0.27, 0.3), roughness: float = 0.6, metallic: float = 0.1) -> void:
	var wall = StaticBody3D.new(); wall.position = pos; add_child(wall)
	var col = CollisionShape3D.new(); var box = BoxShape3D.new(); box.size = size; col.shape = box; wall.add_child(col)
	var m = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = size; m.mesh = bm
	m.material_override = get_cached_procedural_material("wall_" + str(color.to_html()), color, roughness, metallic)
	wall.add_child(m)


@rpc("any_peer", "call_local")
func rpc_spawn_sandbox_object(spawn_position: Vector3, type: ObjectType, node_name: String) -> void:
	if type == ObjectType.TARGET_DUMMY:
		spawn_enemy_npc(spawn_position, node_name)
		return

	var block = RigidBody3D.new(); block.mass = 6.0; block.position = spawn_position; block.name = node_name; add_child(block)
	var b_shape = CollisionShape3D.new(); var b_mesh = MeshInstance3D.new()
	var mat: StandardMaterial3D

	match type:
		ObjectType.TARGET_BARREL:
			var shape = CylinderShape3D.new(); shape.radius = 0.55; shape.height = 1.6; b_shape.shape = shape
			var mesh = CylinderMesh.new(); mesh.top_radius = 0.55; mesh.bottom_radius = 0.55; mesh.height = 1.6; b_mesh.mesh = mesh
			mat = get_cached_procedural_material("barrel_mat", Color(0.72, 0.15, 0.12), 0.3, 0.8)
		ObjectType.INDUSTRIAL_CRATE:
			var shape = BoxShape3D.new(); shape.size = Vector3(1.6, 1.6, 1.6); b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size; b_mesh.mesh = mesh
			mat = get_cached_procedural_material("crate_mat", Color(0.22, 0.36, 0.20), 0.7, 0.0)
		ObjectType.DEFENSE_BARRIER:
			var shape = BoxShape3D.new(); shape.size = Vector3(3.0, 1.2, 0.8); b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size; b_mesh.mesh = mesh
			mat = get_cached_procedural_material("barrier_mat", Color(0.42, 0.42, 0.45), 0.8, 0.0); block.mass = 40.0
		ObjectType.AMMO_BOX:
			var shape = BoxShape3D.new(); shape.size = Vector3(0.7, 0.4, 0.4); b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size; b_mesh.mesh = mesh
			mat = get_cached_procedural_material("ammobox_mat", Color(0.75, 0.58, 0.15), 0.4, 0.6); block.set_meta("is_ammo_box", true)
		ObjectType.EXPLOSIVE_BARREL:
			var shape = CylinderShape3D.new(); shape.radius = 0.55; shape.height = 1.6; b_shape.shape = shape
			var mesh = CylinderMesh.new(); mesh.top_radius = 0.55; mesh.bottom_radius = 0.55; mesh.height = 1.6; b_mesh.mesh = mesh
			mat = get_cached_procedural_material("explosive_mat", Color(0.92, 0.22, 0.05), 0.25, 0.8); block.set_meta("is_explosive", true)
		ObjectType.SHIPPING_CONTAINER:
			var shape = BoxShape3D.new(); shape.size = Vector3(2.5, 2.6, 6.0); b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size; b_mesh.mesh = mesh
			mat = get_cached_procedural_material("container_mat", Color(0.15, 0.32, 0.62), 0.35, 0.75); block.mass = 200.0

	b_mesh.material_override = mat; block.add_child(b_shape); block.add_child(b_mesh)


func spawn_enemy_npc(
	pos: Vector3,
	node_name: String
) -> void:
	var npc := CharacterBody3D.new()

	npc.name = node_name
	var map_limit := 98.0 if current_map_type == MapType.CQB_ARENA else 197.0
	npc.position = Vector3(
		clampf(pos.x, -map_limit, map_limit),
		maxf(pos.y, 1.0),
		clampf(pos.z, -map_limit, map_limit)
	)

	npc.collision_layer = 2
	npc.collision_mask = 1

	npc.set_meta(
		"is_npc",
		true
	)

	npc.set_meta(
		"hp",
		100.0
	)

	# --------------------------------------------------------
	# MAIN BODY COLLISION
	# --------------------------------------------------------

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()

	capsule.radius = 0.40
	capsule.height = 1.8

	collision.shape = capsule
	collision.position.y = 0.9

	npc.add_child(collision)

	add_child(npc)

	# --------------------------------------------------------
	# DETAILED NPC MODEL
	# --------------------------------------------------------

	build_high_detail_humanoid(
		npc,
		Color(0.32, 0.11, 0.10),
		Color(0.08, 0.09, 0.10),
		Color(0.72, 0.50, 0.38),
		Color(0.18, 0.04, 0.03)
	)

	# --------------------------------------------------------
	# HEAD / CHEST / LEG HITBOXES
	# --------------------------------------------------------

	add_humanoid_hitboxes(npc)


func spawn_sandbox_object(spawn_position: Vector3, type: ObjectType) -> void:
	var prop_name = "Prop_" + str(randi())
	rpc("rpc_spawn_sandbox_object", spawn_position, type, prop_name)


func process_out_of_bounds_cleanup() -> void:
	var map_limit := 98.0 if current_map_type == MapType.CQB_ARENA else 197.0
	for child in get_children():
		if child is Node3D and child.has_meta("is_npc"):
			var npc := child as Node3D
			if absf(npc.global_position.x) > map_limit or absf(npc.global_position.z) > map_limit or npc.global_position.y < -30.0:
				npc.queue_free()
			continue
		if child is RigidBody3D and child.position.y < -30.0:
			if child == held_object: drop_held_object()
			child.position = Vector3(randf_range(-6, 6), randf_range(8, 16), randf_range(-6, 6))
			child.linear_velocity = Vector3.ZERO

# ============================================================
# VEHICLES / DRIVING
# ============================================================

func build_car(spawn_position: Vector3, yaw_degrees: float = 0.0) -> VehicleBody3D:
	var car_variant: int = vehicles.size() % 3
	var model_names: Array[String] = ["Sentinel Sedan", "Ranger Utility", "Vortex Sport"]
	var paint_colors: Array[Color] = [Color(0.52, 0.08, 0.09), Color(0.20, 0.34, 0.20), Color(0.06, 0.22, 0.62)]
	var car := VehicleBody3D.new()
	car.name = model_names[car_variant].replace(" ", "_") + "_" + str(randi())
	car.set_meta("vehicle_model", model_names[car_variant])
	car.mass = 1300.0
	car.linear_damp = 0.08
	car.angular_damp = 1.8
	car.position = spawn_position
	car.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	car.collision_layer = 1
	car.collision_mask = 1
	add_child(car)
	car.continuous_cd = true

	# --- Shared materials ---
	var paint := get_cached_procedural_material("car_paint_" + str(car_variant), paint_colors[car_variant], 0.28, 0.80)
	var trim := get_cached_procedural_material("car_trim", Color(0.05, 0.05, 0.06), 0.55, 0.30)
	var chrome := get_cached_procedural_material("car_chrome", Color(0.75, 0.77, 0.80), 0.12, 1.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.16, 0.22, 0.28, 0.45)
	glass.metallic = 0.35
	glass.roughness = 0.05
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	# --- Collision (lower body + cabin volume) ---
	var col_low := CollisionShape3D.new()
	var shape_low := BoxShape3D.new()
	shape_low.size = Vector3(1.90, 0.62, 4.30)
	col_low.shape = shape_low
	col_low.position = Vector3(0.0, 0.50, 0.0)
	car.add_child(col_low)

	var col_cabin := CollisionShape3D.new()
	var shape_cabin := BoxShape3D.new()
	shape_cabin.size = Vector3(1.60, 0.60, 1.90)
	col_cabin.shape = shape_cabin
	col_cabin.position = Vector3(0.0, 1.10, -0.18)
	car.add_child(col_cabin)

	# VehicleBody3D drives along local +Z. The older mesh was authored facing
	# -Z, so turn the visual shell once and keep physics, headlights, wheels,
	# steering, and camera direction in the same forward axis.
	var visual_root := Node3D.new()
	visual_root.name = "CarVisuals"
	visual_root.rotation.y = PI
	car.add_child(visual_root)

	# --- Body shell ---
	_add_car_box(car, Vector3(0.0, 0.52, 0.0), Vector3(1.86, 0.58, 3.98), paint)
	_add_car_box(car, Vector3(0.0, 0.30, 0.0), Vector3(1.72, 0.24, 3.60), trim)
	_add_car_box(car, Vector3(0.0, 0.87, -1.34), Vector3(1.70, 0.20, 1.24), paint)
	_add_car_box(car, Vector3(0.0, 0.90, 1.42), Vector3(1.70, 0.22, 1.06), paint)
	_add_car_box(car, Vector3(0.0, 0.56, -0.20), Vector3(1.88, 0.30, 1.30), trim)

	# --- Cabin glass, seats and dashboard ---
	_add_car_box(car, Vector3(0.0, 1.22, -0.68), Vector3(1.38, 0.48, 0.045), glass, Vector3(16.0, 0.0, 0.0))
	_add_car_box(car, Vector3(0.0, 1.22, 1.08), Vector3(1.38, 0.44, 0.045), glass, Vector3(-18.0, 0.0, 0.0))
	_add_car_box(car, Vector3(-0.77, 1.22, 0.20), Vector3(0.04, 0.42, 1.28), glass)
	_add_car_box(car, Vector3(0.77, 1.22, 0.20), Vector3(0.04, 0.42, 1.28), glass)
	_add_car_box(car, Vector3(0.0, 1.49, 0.22), Vector3(1.62, 0.10, 1.78), paint)
	_add_car_box(car, Vector3(0.0, 0.91, -0.73), Vector3(1.52, 0.18, 0.28), trim)
	for seat_x in [-0.43, 0.43]:
		_add_car_box(car, Vector3(seat_x, 0.49, 0.18), Vector3(0.42, 0.14, 0.50), trim)
		_add_car_box(car, Vector3(seat_x, 0.79, 0.46), Vector3(0.42, 0.58, 0.16), trim, Vector3(-8.0, 0.0, 0.0))
	var steering_wheel := MeshInstance3D.new()
	var steering_wheel_mesh := TorusMesh.new()
	steering_wheel_mesh.inner_radius = 0.12
	steering_wheel_mesh.outer_radius = 0.15
	steering_wheel.mesh = steering_wheel_mesh
	steering_wheel.position = Vector3(-0.43, 1.02, -0.54)
	steering_wheel.material_override = chrome
	visual_root.add_child(steering_wheel)

	for pz in [-0.74, 1.12]:
		for px in [-0.76, 0.76]:
			_add_car_box(car, Vector3(px, 1.22, pz), Vector3(0.10, 0.58, 0.16), trim)

	# --- Bumpers / spoiler / mirrors ---
	_add_car_box(car, Vector3(0.0, 0.46, -2.08), Vector3(1.90, 0.36, 0.30), trim)
	_add_car_box(car, Vector3(0.0, 0.46, 2.08), Vector3(1.90, 0.36, 0.30), trim)
	_add_car_box(car, Vector3(0.0, 1.02, 2.05), Vector3(1.50, 0.06, 0.34), paint)
	_add_car_box(car, Vector3(-0.62, 0.92, 2.05), Vector3(0.08, 0.20, 0.16), trim)
	_add_car_box(car, Vector3(0.62, 0.92, 2.05), Vector3(0.08, 0.20, 0.16), trim)
	_add_car_box(car, Vector3(-0.96, 1.20, -0.52), Vector3(0.24, 0.10, 0.14), trim)
	_add_car_box(car, Vector3(0.96, 1.20, -0.52), Vector3(0.24, 0.10, 0.14), trim)

	if car_variant == 1:
		# Utility model: add a lined cargo bed and raised side rails.
		_add_car_box(car, Vector3(0.0, 1.025, 1.46), Vector3(1.20, 0.07, 0.86), trim)
		for bed_side in [-1.0, 1.0]:
			_add_car_box(car, Vector3(bed_side * 0.68, 1.20, 1.46), Vector3(0.10, 0.34, 0.92), paint)
		_add_car_box(car, Vector3(0.0, 1.18, 1.94), Vector3(1.32, 0.32, 0.10), paint)
	elif car_variant == 2:
		# Sport model: add low side skirts, a front splitter, and a raised rear wing.
		var sport_trim := get_cached_procedural_material("car_sport_accent", Color(0.02, 0.025, 0.035), 0.38, 0.45)
		for skirt_side in [-1.0, 1.0]:
			_add_car_box(car, Vector3(skirt_side * 0.93, 0.36, 0.0), Vector3(0.12, 0.14, 2.70), sport_trim)
		_add_car_box(car, Vector3(0.0, 0.40, -2.12), Vector3(1.92, 0.10, 0.42), sport_trim)
		_add_car_box(car, Vector3(0.0, 1.21, 2.02), Vector3(1.56, 0.08, 0.34), paint)
		for wing_side in [-1.0, 1.0]:
			_add_car_box(car, Vector3(wing_side * 0.50, 1.10, 1.98), Vector3(0.08, 0.34, 0.08), trim)

	# --- Lights ---
	for hx in [-0.62, 0.62]:
		_add_car_emissive(car, Vector3(hx, 0.64, -2.02), Vector3(0.42, 0.20, 0.10), Color(1.0, 0.96, 0.82), 2.4)
	for tx in [-0.66, 0.66]:
		_add_car_emissive(car, Vector3(tx, 0.74, 2.02), Vector3(0.34, 0.18, 0.10), Color(1.0, 0.10, 0.08), 1.8)

	for hx2 in [-0.62, 0.62]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(hx2, 0.62, -2.05)
		spot.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		spot.light_color = Color(1.0, 0.96, 0.85)
		spot.light_energy = 3.0
		spot.spot_range = 40.0
		spot.spot_angle = 38.0
		spot.spot_angle_attenuation = 0.7
		spot.shadow_enabled = true
		visual_root.add_child(spot)

	_add_car_box(car, Vector3(-0.55, 0.32, 2.16), Vector3(0.12, 0.12, 0.18), chrome)
	_add_car_box(car, Vector3(0.55, 0.32, 2.16), Vector3(0.12, 0.12, 0.18), chrome)

	# Wheels: front pair steers, rear pair drives. They use VehicleBody3D's
	# native +Z forward axis while the visual shell above matches that axis.
	_add_car_wheel(car, Vector3(-0.88, 0.30, 1.42), true, false)
	_add_car_wheel(car, Vector3(0.88, 0.30, 1.42), true, false)
	_add_car_wheel(car, Vector3(-0.88, 0.30, -1.46), false, true)
	_add_car_wheel(car, Vector3(0.88, 0.30, -1.46), false, true)

	vehicles.append(car)
	return car


func _add_car_box(car: Node3D, pos: Vector3, size: Vector3, mat: Material, rotation_degrees_value: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rotation_degrees_value
	mi.material_override = mat
	var visual_parent := car.get_node_or_null("CarVisuals") as Node3D
	(visual_parent if is_instance_valid(visual_parent) else car).add_child(mi)


func _add_car_emissive(car: Node3D, pos: Vector3, size: Vector3, col: Color, energy: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	mi.material_override = m
	var visual_parent := car.get_node_or_null("CarVisuals") as Node3D
	(visual_parent if is_instance_valid(visual_parent) else car).add_child(mi)


func _add_car_wheel(car: VehicleBody3D, wheel_pos: Vector3, steer: bool, traction: bool) -> void:
	var wheel := VehicleWheel3D.new()
	wheel.position = wheel_pos
	wheel.use_as_steering = steer
	wheel.use_as_traction = traction
	wheel.wheel_radius = 0.44
	# Wheel origin is above the road. Include enough suspension reach for the
	# radius + rest length to meet the road when the car spawns at ride height.
	wheel.wheel_rest_length = 0.30
	wheel.wheel_friction_slip = 5.0
	wheel.suspension_travel = 0.30
	wheel.suspension_stiffness = 36.0
	wheel.suspension_max_force = 9000.0
	wheel.damping_compression = 0.6
	wheel.damping_relaxation = 0.9
	wheel.wheel_roll_influence = 0.08
	car.add_child(wheel)

	# Tyre.
	var vis := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.44
	cyl.bottom_radius = 0.44
	cyl.height = 0.32
	cyl.radial_segments = 24
	vis.mesh = cyl
	vis.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	vis.position = Vector3(0.0, -wheel.wheel_rest_length, 0.0)
	vis.material_override = get_cached_procedural_material("car_tyre", Color(0.03, 0.03, 0.035), 0.9, 0.0)
	wheel.add_child(vis)

	# Rim.
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.27
	rim_mesh.bottom_radius = 0.27
	rim_mesh.height = 0.34
	rim_mesh.radial_segments = 20
	rim.mesh = rim_mesh
	rim.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rim.position = Vector3(0.0, -wheel.wheel_rest_length, 0.0)
	rim.material_override = get_cached_procedural_material("car_rim", Color(0.72, 0.74, 0.78), 0.15, 1.0)
	wheel.add_child(rim)


func get_nearest_vehicle(max_distance: float = 4.0) -> VehicleBody3D:
	if not is_instance_valid(local_player_node):
		return null
	var best: VehicleBody3D = null
	var best_dist: float = max_distance
	for v in vehicles:
		if not is_instance_valid(v):
			continue
		var d: float = local_player_node.global_position.distance_to(v.global_position)
		if d < best_dist:
			best_dist = d
			best = v
	return best


func try_enter_nearby_vehicle() -> bool:
	if is_driving:
		return false
	if is_instance_valid(held_object):
		drop_held_object()
	var v := get_nearest_vehicle()
	if v == null:
		return false

	active_vehicle = v
	is_driving = true
	vehicle_look_offset = 0.0

	# Hide the first-person weapon while seated.
	if is_instance_valid(weapon_mesh_root):
		weapon_mesh_root.visible = false
	if is_instance_valid(crosshair_container):
		crosshair_container.visible = false

	if is_instance_valid(local_player_node):
		local_player_node.rotation.y = active_vehicle.rotation.y + PI
		local_player_node.velocity = Vector3.ZERO
		local_player_node.collision_layer = 0
		var local_model := local_player_node.get_meta("player_model", null) as Node3D
		if is_instance_valid(local_model):
			local_model.scale = Vector3(0.78, 0.45, 0.78)
			local_model.position = Vector3(0.0, -0.15, 0.0)
			local_model.rotation.x = deg_to_rad(8.0)
		local_player_node.collision_mask = 0

	if is_instance_valid(camera_pivot):
		camera_pivot.position.y = driving_cam_height
	if is_instance_valid(local_player_node):
		local_player_node.global_position = active_vehicle.global_transform * Vector3(-0.42, 0.42, -0.12)

	if is_instance_valid(vehicle_hint_label):
		vehicle_hint_label.visible = true

	return true


func exit_vehicle() -> void:
	if not is_driving:
		return
	is_driving = false

	if is_instance_valid(weapon_mesh_root):
		weapon_mesh_root.visible = true
	if is_instance_valid(crosshair_container):
		crosshair_container.visible = true

	if is_instance_valid(local_player_node):
		local_player_node.collision_layer = 2
		local_player_node.collision_mask = 1
		local_player_node.velocity = Vector3.ZERO
		var local_model := local_player_node.get_meta("player_model", null) as Node3D
		if is_instance_valid(local_model):
			local_model.scale = Vector3.ONE
			local_model.position = Vector3.ZERO
			local_model.rotation = Vector3.ZERO
		if is_instance_valid(active_vehicle):
			local_player_node.global_position = (
				active_vehicle.global_position
				+ active_vehicle.global_transform.basis.x * -2.0
				+ Vector3(0.0, 0.65, 0.0)
			)

	if is_instance_valid(camera_pivot):
		camera_pivot.position.y = default_cam_height

	if is_instance_valid(vehicle_hint_label):
		vehicle_hint_label.visible = false

	active_vehicle = null


func update_vehicle_driving(delta: float) -> void:
	if not is_instance_valid(active_vehicle):
		exit_vehicle()
		return

	var steer: float = Input.get_axis("move_left", "move_right")
	var throttle: float = Input.get_axis("move_back", "move_forward")

	var speed: float = active_vehicle.linear_velocity.length()

	# Steering tightens at low speed, calms down at high speed.
	var speed_ratio: float = clampf(speed / maxf(max_vehicle_speed, 1.0), 0.0, 1.0)
	var steer_limit: float = lerpf(0.58, 0.17, speed_ratio)

	active_vehicle.steering = lerpf(
		active_vehicle.steering,
		steer * steer_limit,
		1.0 - exp(-12.0 * delta)
	)

	active_vehicle.brake = 0.0
	# CarVisuals is aligned to VehicleBody3D's local +Z forward axis, so W
	# now drives toward the visible nose with the standard positive force sign.
	active_vehicle.engine_force = throttle * 80.0

	if Input.is_action_pressed("vehicle_handbrake"):
		# Handbrake.
		active_vehicle.brake = 34.0
		active_vehicle.engine_force = 0.0
	elif throttle < 0.0:
		var signed_forward_speed := active_vehicle.linear_velocity.dot(active_vehicle.global_transform.basis.z)
		if signed_forward_speed > 1.5:
			# Braking while the car is still moving forward.
			active_vehicle.brake = 22.0
			active_vehicle.engine_force = 0.0
		else:
			# Keep applying reverse force after the car starts moving backward.
			active_vehicle.brake = 0.0
			active_vehicle.engine_force = -60.0

	# Downforce keeps the car planted and reduces flipping at speed.
	active_vehicle.apply_central_force(
		-active_vehicle.global_transform.basis.y * speed * 110.0
	)

	# Soft speed cap.
	if active_vehicle.linear_velocity.length() > max_vehicle_speed:
		active_vehicle.linear_velocity = active_vehicle.linear_velocity.limit_length(max_vehicle_speed)

	# Seat the player in the driver position and apply free-look yaw.
	if is_instance_valid(local_player_node):
		local_player_node.global_position = (
			active_vehicle.global_transform * Vector3(-0.42, 0.42, -0.12)
		)
		local_player_node.rotation.y = active_vehicle.rotation.y + PI + vehicle_look_offset
		local_player_node.velocity = Vector3.ZERO


func update_vehicle_prompt() -> void:
	if not is_instance_valid(vehicle_hint_label):
		return
	if is_driving:
		var cam_name: String = "cockpit" if vehicle_camera_mode == 0 else "chase"
		var model_name := str(active_vehicle.get_meta("vehicle_model", "Vehicle"))
		vehicle_hint_label.text = (
			"DRIVING " + model_name + " (" + cam_name + ")  |  throttle "
			+ _input_binding_text(&"move_forward") + "  |  steer "
			+ _input_binding_text(&"move_left") + "/" + _input_binding_text(&"move_right")
			+ "  |  brake " + _input_binding_text(&"vehicle_handbrake")
			+ "  |  camera " + _input_binding_text(&"vehicle_camera")
			+ "  |  exit " + _input_binding_text(&"interact")
		)
		vehicle_hint_label.visible = true
	else:
		var v := get_nearest_vehicle(4.0)
		vehicle_hint_label.visible = v != null
		if v != null:
			var model_name := str(v.get_meta("vehicle_model", "Vehicle"))
			vehicle_hint_label.text = "Press " + _input_binding_text(&"interact") + " to drive " + model_name


# ============================================================
# PROCEDURAL HIGH-DETAIL HUMANOID
# ============================================================

func create_box_part(
	parent: Node3D,
	part_name: String,
	size: Vector3,
	part_position: Vector3,
	material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var node := MeshInstance3D.new()

	node.name = part_name

	var mesh := BoxMesh.new()
	mesh.size = size

	node.mesh = mesh
	node.material_override = material

	node.position = part_position
	node.rotation_degrees = rotation_degrees_value

	parent.add_child(node)

	return node

func create_capsule_part(
	parent: Node3D,
	part_name: String,
	radius: float,
	height: float,
	part_position: Vector3,
	material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var node := MeshInstance3D.new()

	node.name = part_name

	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height

	node.mesh = mesh
	node.material_override = material

	node.position = part_position
	node.rotation_degrees = rotation_degrees_value

	parent.add_child(node)

	return node
	
func create_sphere_part(
	parent: Node3D,
	part_name: String,
	radius: float,
	part_position: Vector3,
	material: Material
) -> MeshInstance3D:
	var node := MeshInstance3D.new()

	node.name = part_name

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0

	node.mesh = mesh
	node.material_override = material

	node.position = part_position

	parent.add_child(node)

	return node
	
func _set_visual_layers_recursive(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		_set_visual_layers_recursive(child, layer_mask)


func build_high_detail_humanoid(
	parent: Node3D,
	uniform_color: Color,
	armor_color: Color,
	skin_color: Color,
	accent_color: Color
) -> Node3D:
	var model := Node3D.new()
	model.name = "DetailedHumanoid"
	parent.add_child(model)

	# --------------------------------------------------------
	# MATERIALS
	# --------------------------------------------------------

	var uniform_mat := StandardMaterial3D.new()
	uniform_mat.albedo_color = uniform_color
	uniform_mat.roughness = 0.78

	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_color = armor_color
	armor_mat.metallic = 0.22
	armor_mat.roughness = 0.58

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin_color
	skin_mat.roughness = 0.72

	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(
		0.025,
		0.028,
		0.030
	)
	boot_mat.roughness = 0.92

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = accent_color
	accent_mat.roughness = 0.60

	# --------------------------------------------------------
	# PELVIS
	# --------------------------------------------------------

	create_box_part(
		model,
		"Pelvis",
		Vector3(
			0.48,
			0.24,
			0.30
		),
		Vector3(
			0,
			0.82,
			0
		),
		uniform_mat
	)

	# --------------------------------------------------------
	# TORSO
	# --------------------------------------------------------

	create_box_part(
		model,
		"Torso",
		Vector3(
			0.58,
			0.68,
			0.34
		),
		Vector3(
			0,
			1.20,
			0
		),
		uniform_mat
	)

	# --------------------------------------------------------
	# PLATE CARRIER
	# --------------------------------------------------------

	create_box_part(
		model,
		"PlateCarrier",
		Vector3(
			0.53,
			0.42,
			0.38
		),
		Vector3(
			0,
			1.25,
			-0.025
		),
		armor_mat
	)

	# Front magazine pouches.
	for pouch_x in [-0.14, 0.0, 0.14]:
		create_box_part(
			model,
			"MagazinePouch",
			Vector3(
				0.105,
				0.13,
				0.075
			),
			Vector3(
				pouch_x,
				1.11,
				-0.235
			),
			accent_mat
		)

	# --------------------------------------------------------
	# NECK
	# --------------------------------------------------------

	create_capsule_part(
		model,
		"Neck",
		0.105,
		0.18,
		Vector3(
			0,
			1.60,
			0
		),
		skin_mat
	)

	# --------------------------------------------------------
	# HEAD
	# --------------------------------------------------------

	create_sphere_part(
		model,
		"Head",
		0.18,
		Vector3(
			0,
			1.77,
			0
		),
		skin_mat
	)

	# --------------------------------------------------------
	# HELMET
	# --------------------------------------------------------

	create_sphere_part(
		model,
		"Helmet",
		0.205,
		Vector3(
			0,
			1.825,
			0
		),
		armor_mat
	)

	create_box_part(
		model,
		"HelmetFront",
		Vector3(
			0.31,
			0.075,
			0.11
		),
		Vector3(
			0,
			1.80,
			-0.15
		),
		armor_mat
	)

	# --------------------------------------------------------
	# ARMS
	# --------------------------------------------------------

	for side in [-1.0, 1.0]:

		create_sphere_part(
			model,
			"Elbow",
			0.105,
			Vector3(
				side * 0.39,
				1.00,
				-0.01
			),
			uniform_mat
		)

		create_capsule_part(
			model,
			"Forearm",
			0.08,
			0.39,
			Vector3(
				side * 0.40,
				0.83,
				-0.01
			),
			uniform_mat
		)

		create_sphere_part(
			model,
			"Hand",
			0.09,
			Vector3(
				side * 0.40,
				0.62,
				-0.03
			),
			skin_mat
		)

	# --------------------------------------------------------
	# LEGS
	# --------------------------------------------------------

	for side in [-1.0, 1.0]:
		create_capsule_part(
			model,
			"Thigh",
			0.125,
			0.53,
			Vector3(
				side * 0.16,
				0.48,
				0
			),
			uniform_mat
		)

		create_sphere_part(
			model,
			"Knee",
			0.11,
			Vector3(
				side * 0.16,
				0.18,
				0
			),
			uniform_mat
		)

		create_capsule_part(
			model,
			"Calf",
			0.105,
			0.45,
			Vector3(
				side * 0.16,
				-0.04,
				0
			),
			uniform_mat
		)

		create_box_part(
			model,
			"Boot",
			Vector3(
				0.19,
				0.12,
				0.36
			),
			Vector3(
				side * 0.16,
				-0.31,
				-0.055
			),
			boot_mat
		)

	# --------------------------------------------------------
	# BACKPACK
	# --------------------------------------------------------

	create_box_part(
		model,
		"Backpack",
		Vector3(
			0.42,
			0.54,
			0.18
		),
		Vector3(
			0,
			1.20,
			0.25
		),
		accent_mat
	)

	# --------------------------------------------------------
	# SHOULDER PADS
	# --------------------------------------------------------

	for side in [-1.0, 1.0]:
		create_sphere_part(
			model,
			"ShoulderPad",
			0.12,
			Vector3(
				side * 0.34,
				1.45,
				0
			),
			armor_mat
		)

	return model
func update_controls_help() -> void:
	if not is_instance_valid(controls_help_label):
		return
	controls_help_label.text = (
		"CONTROLS\n"
		+ "WASD / left stick .... Move\n"
		+ _input_binding_text(&"sprint") + " .... Sprint\n"
		+ _input_binding_text(&"crouch") + " .... Crouch / slide\n"
		+ _input_binding_text(&"jump") + " .... Jump\n"
		+ "Mouse / right stick .... Look\n"
		+ _input_binding_text(&"fire") + " .... Fire\n"
		+ _input_binding_text(&"aim") + " .... Aim\n"
		+ _input_binding_text(&"reload") + " .... Reload\n"
		+ "1-4 / bumpers .... Weapons\n"
		+ _input_binding_text(&"throw_grenade") + " .... Grenade\n"
		+ _input_binding_text(&"drop_weapon") + " .... Drop weapon\n"
		+ _input_binding_text(&"lean_left") + " / " + _input_binding_text(&"lean_right") + " .... Lean\n"
		+ _input_binding_text(&"interact") + " .... Interact / Drive\n"
		+ _input_binding_text(&"pause") + " .... Pause / settings\n"
		+ "\nCAR: WASD / left stick drive\n"
		+ _input_binding_text(&"vehicle_handbrake") + " .... Handbrake"
	)


# --- GUI, HUD, ESP OVERLAY & SPAWN/CHEAT MENUS ---
func build_advanced_gui_systems() -> void:
	var cl = CanvasLayer.new(); add_child(cl)
	
	esp_overlay_node = Control.new()
	esp_overlay_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	esp_overlay_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esp_overlay_node.draw.connect(_on_esp_draw)
	cl.add_child(esp_overlay_node)

	crosshair_container = Control.new(); crosshair_container.set_anchors_preset(Control.PRESET_CENTER); cl.add_child(crosshair_container)
	
	# --- ADD THIS: Procedurally build the crosshair dot ---
	crosshair_dot = ColorRect.new()
	crosshair_dot.name = "CrosshairDot"
	crosshair_dot.color = Color(0.1, 1.0, 0.4, 0.85) # Matching the line colors
	crosshair_dot.custom_minimum_size = Vector2(4, 4) # 4x4 pixel square dot
	crosshair_container.add_child(crosshair_dot)
	# -----------------------------------------------------

	for i in range(4): var line = ColorRect.new(); line.color = Color(0.1, 1.0, 0.4, 0.85); crosshair_container.add_child(line); crosshair_lines.append(line)
	update_crosshair_layout()

# --- REFINED TACTICAL SNIPER SCOPE OVERLAY ---
	scope_overlay_ui = Control.new()
	scope_overlay_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay_ui.visible = false
	cl.add_child(scope_overlay_ui)

	# Outer dark vignette ring
	var scope_vignette = ColorRect.new()
	scope_vignette.color = Color(0.01, 0.02, 0.03, 0.85)
	scope_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay_ui.add_child(scope_vignette)

	# Lens center glass window
	var lens_center = ColorRect.new()
	lens_center.color = Color(0.02, 0.04, 0.03, 0.15)
	lens_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lens_center.position = Vector2(-360.0, -360.0)
	lens_center.size = Vector2(720.0, 720.0)
	scope_overlay_ui.add_child(lens_center)

	# Precision Reticle Lines
	var scope_line_v = ColorRect.new()
	scope_line_v.color = Color(0.05, 0.95, 0.15, 0.9)
	scope_line_v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scope_line_v.position = Vector2(-1.0, -360.0)
	scope_line_v.size = Vector2(2.0, 720.0)
	scope_overlay_ui.add_child(scope_line_v)

	var scope_line_h = ColorRect.new()
	scope_line_h.color = Color(0.05, 0.95, 0.15, 0.9)
	scope_line_h.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scope_line_h.position = Vector2(-360.0, -1.0)
	scope_line_h.size = Vector2(720.0, 2.0)
	scope_overlay_ui.add_child(scope_line_h)
	
	var hud_panel = VBoxContainer.new()
	hud_panel.anchor_left = 0.0
	hud_panel.anchor_top = 1.0
	hud_panel.anchor_right = 0.0
	hud_panel.anchor_bottom = 1.0
	hud_panel.offset_left = 30.0
	hud_panel.offset_top = -54.0
	hud_panel.offset_right = 270.0
	hud_panel.offset_bottom = -20.0
	cl.add_child(hud_panel)
	HUD_health_bar = ProgressBar.new()
	HUD_health_bar.custom_minimum_size = Vector2(240, 20)
	HUD_health_bar.value = 100
	hud_panel.add_child(HUD_health_bar)

	HUD_firemode_label = Label.new()
	HUD_firemode_label.anchor_left = 0.5
	HUD_firemode_label.anchor_top = 1.0
	HUD_firemode_label.anchor_right = 0.5
	HUD_firemode_label.anchor_bottom = 1.0
	HUD_firemode_label.offset_left = -140.0
	HUD_firemode_label.offset_top = -104.0
	HUD_firemode_label.offset_right = 140.0
	HUD_firemode_label.offset_bottom = -76.0
	HUD_firemode_label.add_theme_font_size_override("font_size", 20)
	cl.add_child(HUD_firemode_label)

	cqb_score_label = Label.new()
	cqb_score_label.anchor_left = 0.5
	cqb_score_label.anchor_top = 0.0
	cqb_score_label.anchor_right = 0.5
	cqb_score_label.anchor_bottom = 0.0
	cqb_score_label.offset_left = -180.0
	cqb_score_label.offset_top = 22.0
	cqb_score_label.offset_right = 180.0
	cqb_score_label.offset_bottom = 54.0
	cqb_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cqb_score_label.add_theme_font_size_override("font_size", 22)
	cqb_score_label.visible = current_map_type == MapType.CQB_ARENA
	cl.add_child(cqb_score_label)

	hitmarker_ui = TextureRect.new(); hitmarker_ui.set_anchors_preset(Control.PRESET_CENTER); hitmarker_ui.visible = false; cl.add_child(hitmarker_ui)
	
	# Ingame mini leaderboard top-right
	ingame_leaderboard_label = Label.new()
	ingame_leaderboard_label.anchor_left = 1.0
	ingame_leaderboard_label.anchor_top = 0.0
	ingame_leaderboard_label.anchor_right = 1.0
	ingame_leaderboard_label.anchor_bottom = 0.0
	ingame_leaderboard_label.offset_left = -360.0
	ingame_leaderboard_label.offset_top = 40.0
	ingame_leaderboard_label.offset_right = -30.0
	ingame_leaderboard_label.offset_bottom = 240.0
	ingame_leaderboard_label.add_theme_font_size_override("font_size", 16)
	cl.add_child(ingame_leaderboard_label)
	
	join_notification_label = Label.new()
	join_notification_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	join_notification_label.position = Vector2(30, 30)
	join_notification_label.add_theme_font_size_override("font_size", 18)
	join_notification_label.visible = false
	cl.add_child(join_notification_label)

	# Vehicle interaction hint / driving controls.
	vehicle_hint_label = Label.new()
	vehicle_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vehicle_hint_label.position = Vector2(-220, -80)
	vehicle_hint_label.add_theme_font_size_override("font_size", 18)
	vehicle_hint_label.visible = false
	cl.add_child(vehicle_hint_label)

	# --------------------------------------------------------
	# CONTROLS POPUP (bottom-right)
	# --------------------------------------------------------
	controls_popup = PanelContainer.new()
	controls_popup.anchor_left = 1.0
	controls_popup.anchor_top = 1.0
	controls_popup.anchor_right = 1.0
	controls_popup.anchor_bottom = 1.0
	controls_popup.offset_left = -350.0
	controls_popup.offset_top = -340.0
	controls_popup.offset_right = -20.0
	controls_popup.offset_bottom = -20.0
	controls_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.05, 0.06, 0.09, 0.60)
	cstyle.border_color = Color(0.62, 0.76, 0.96, 0.55)
	cstyle.set_border_width_all(1)
	cstyle.set_corner_radius_all(6)
	cstyle.set_content_margin_all(12)
	controls_popup.add_theme_stylebox_override("panel", cstyle)

	controls_help_label = Label.new()
	controls_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_help_label.add_theme_font_size_override("font_size", 14)
	controls_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_help_label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	controls_popup.add_child(controls_help_label)
	cl.add_child(controls_popup)
	update_controls_help()
	
	update_hud_display()



func update_crosshair_layout() -> void:
	if is_instance_valid(crosshair_dot):
		crosshair_dot.position = Vector2(-2.0, -2.0)
		crosshair_dot.size = Vector2(4.0, 4.0)
	if crosshair_lines.size() < 4:
		return

	var gap: float = 5.0 + clampf(crosshair_spread * 0.2, 0.0, 8.0)
	var line_length: float = 8.0
	var thickness: float = 2.0
	var line_rects: Array[Rect2] = [
		Rect2(-thickness * 0.5, -gap - line_length, thickness, line_length),
		Rect2(-thickness * 0.5, gap, thickness, line_length),
		Rect2(-gap - line_length, -thickness * 0.5, line_length, thickness),
		Rect2(gap, -thickness * 0.5, line_length, thickness)
	]
	for i in range(4):
		crosshair_lines[i].position = line_rects[i].position
		crosshair_lines[i].size = line_rects[i].size

func update_hud_display() -> void:
	if is_instance_valid(HUD_health_bar):
		HUD_health_bar.value = health

	if is_instance_valid(cqb_score_label):
		cqb_score_label.visible = current_map_type == MapType.CQB_ARENA
		cqb_score_label.text = "YOU " + str(cqb_score_player) + "  |  OPFOR " + str(cqb_score_enemy)

	if is_instance_valid(HUD_firemode_label):
		match current_fire_mode:
			FireMode.FULL_AUTO: HUD_firemode_label.text = "[FULL AUTO]"
			FireMode.BURST: HUD_firemode_label.text = "[BURST 3-RD]"
			FireMode.SEMI_AUTO: HUD_firemode_label.text = "[SEMI AUTO]"


func toggle_cheat_menu() -> void:
	if not is_cheat_menu_open and is_menu_open:
		return

	is_cheat_menu_open = not is_cheat_menu_open
	if is_instance_valid(cheat_menu_ui): cheat_menu_ui.visible = is_cheat_menu_open
	if is_cheat_menu_open: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif is_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func build_cheat_menu_ui() -> void:
	var canvas = CanvasLayer.new(); add_child(canvas)
	cheat_menu_ui = Control.new(); cheat_menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cheat_menu_ui.visible = false; canvas.add_child(cheat_menu_ui)
	var bg = ColorRect.new(); bg.color = Color(0.08, 0.08, 0.12, 0.92); bg.set_anchors_preset(Control.PRESET_CENTER); bg.position = Vector2(-210, -260); bg.size = Vector2(420, 520); cheat_menu_ui.add_child(bg)

	cheat_auth_panel = VBoxContainer.new(); cheat_auth_panel.set_anchors_preset(Control.PRESET_CENTER); cheat_auth_panel.position = Vector2(-120, -50); cheat_auth_panel.size = Vector2(240, 100); cheat_menu_ui.add_child(cheat_auth_panel)
	var lbl = Label.new(); lbl.text = "ENTER CHEAT PASSWORD:"; cheat_auth_panel.add_child(lbl)
	cheat_password_input = LineEdit.new(); cheat_password_input.secret = true; cheat_password_input.custom_minimum_size = Vector2(240, 36); cheat_auth_panel.add_child(cheat_password_input)
	var sub_btn = Button.new(); sub_btn.text = "Unlock Cheats"; sub_btn.pressed.connect(_verify_cheat_password); cheat_auth_panel.add_child(sub_btn)

	cheat_content_panel = VBoxContainer.new(); cheat_content_panel.set_anchors_preset(Control.PRESET_CENTER); cheat_content_panel.position = Vector2(-150, -200); cheat_content_panel.size = Vector2(300, 400); cheat_content_panel.visible = false; cheat_menu_ui.add_child(cheat_content_panel)
	
	var god_chk = CheckBox.new(); god_chk.text = "God Mode"; god_chk.toggled.connect(func(v): god_mode = v); cheat_content_panel.add_child(god_chk)
	var inf_chk = CheckBox.new(); inf_chk.text = "Infinite Ammo"; inf_chk.toggled.connect(func(v): infinite_ammo = v); cheat_content_panel.add_child(inf_chk)
	var spd_chk = CheckBox.new(); spd_chk.text = "Super Speed"; spd_chk.toggled.connect(func(v): super_speed = v); cheat_content_panel.add_child(spd_chk)
	var grav_chk = CheckBox.new(); grav_chk.text = "Low Gravity"; grav_chk.toggled.connect(func(v): low_gravity = v); cheat_content_panel.add_child(grav_chk)
	var aim_chk = CheckBox.new(); aim_chk.text = "Aimbot Lock"; aim_chk.toggled.connect(func(v): aimbot_enabled = v); cheat_content_panel.add_child(aim_chk)
	var esp_chk = CheckBox.new(); esp_chk.text = "ESP Overlay"; esp_chk.toggled.connect(func(v): esp_enabled = v); cheat_content_panel.add_child(esp_chk)
	
	# New: Night Mode toggle
	var night_chk = CheckBox.new(); night_chk.text = "Night Mode"; night_chk.toggled.connect(func(v):
		night_mode_enabled = v
		if v: apply_night_mode()
		else: apply_day_mode()
	); cheat_content_panel.add_child(night_chk)
	
	# New: Night Vision toggle
	var nv_chk = CheckBox.new(); nv_chk.text = "Night Vision Goggles"; nv_chk.toggled.connect(func(v): 
		night_vision_enabled = v
		if is_instance_valid(night_vision_overlay): night_vision_overlay.visible = v
	); cheat_content_panel.add_child(nv_chk)
	
	# New: Flashlight toggle
	var fl_chk = CheckBox.new(); fl_chk.text = "Weapon Flashlight"; fl_chk.toggled.connect(func(v):
		flashlight_enabled = v
		if is_instance_valid(flashlight_node):
			flashlight_node.visible = v
	); cheat_content_panel.add_child(fl_chk)


func _verify_cheat_password() -> void:
	if cheat_password_input.text == CHEAT_PASSWORD:
		cheat_unlocked = true
		cheat_auth_panel.visible = false
		cheat_content_panel.visible = true


func _on_esp_draw() -> void:
	if not esp_enabled or not is_instance_valid(player_camera): return
	for child in get_children():
		if child == local_player_node: continue
		if child.has_meta("is_npc") or (child.name.begins_with("Player_") and child.visible):
			var pos = child.global_position + Vector3(0, 1.0, 0)
			if not player_camera.is_position_behind(pos):
				var screen_pos = player_camera.unproject_position(pos)
				esp_overlay_node.draw_rect(Rect2(screen_pos.x - 20, screen_pos.y - 40, 40, 80), Color(1, 0, 0, 0.8), false, 2.0)
