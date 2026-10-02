extends Node3D

# --- CONFIGURATION & ENUMS ---
enum ObjectType { TARGET_BARREL, INDUSTRIAL_CRATE, DEFENSE_BARRIER, AMMO_BOX, EXPLOSIVE_BARREL }

# --- PLAYER & MOVEMENT ATTRIBUTES ---
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 3.2
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.0022

var current_speed: float = 6.0
var is_crouching: bool = false
var is_sprinting: bool = false
var default_cam_height: float = 1.65
var crouch_cam_height: float = 0.95
var target_cam_height: float = 1.65

# Project Physics Environment
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- RUNTIME SCENE NODES ---
var player: CharacterBody3D
var camera_pivot: Node3D
var player_camera: Camera3D
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D

# --- PROCEDURAL PBR TEXTURES ---
var concrete_normal_tex: NoiseTexture2D
var metal_scratches_tex: NoiseTexture2D

# --- WEAPON MECHANICS & SPRING RECOIL ---
var weapon_rig: Node3D
var weapon_mesh_root: Node3D
var mag_mesh_node: Node3D
var charging_handle_node: Node3D
var ejection_port_marker: Node3D
var muzzle_flash_light: OmniLight3D
var muzzle_flash_mesh: MeshInstance3D

var current_ammo: int = 30
var reserve_ammo: int = 150
var max_magazine: int = 30
var is_aiming: bool = false
var is_reloading: bool = false
var fire_rate: float = 0.095 # ~630 RPM
var fire_cooldown: float = 0.0

# Dual Vector Recoil Spring Simulation
var recoil_offset: Vector3 = Vector3.ZERO
var recoil_velocity: Vector3 = Vector3.ZERO
var recoil_rot_offset: Vector3 = Vector3.ZERO
var recoil_rot_velocity: Vector3 = Vector3.ZERO

# Sway & Procedural Movement Interpolations
var current_weapon_pos: Vector3 = Vector3.ZERO
var sway_offset: Vector2 = Vector2.ZERO
var sway_rotation: Vector3 = Vector3.ZERO
var walk_cycle: float = 0.0
var camera_shake: float = 0.0
var camera_roll: float = 0.0

# --- PHYSICAL PROP INTERACTION ---
var held_object: RigidBody3D = null
var held_object_distance: float = 3.5
var is_rotating_object: bool = false
var object_target_rotation: Basis = Basis.IDENTITY

# --- ADVANCED DYNAMIC UI SYSTEMS ---
var is_menu_open: bool = false
var spawn_menu_ui: Control
var HUD_ammo_label: Label
var crosshair_container: Control
var crosshair_lines: Array[ColorRect] = [] # Top, Bottom, Left, Right
var crosshair_spread: float = 8.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	generate_procedural_textures()
	setup_god_rays_environment()
	build_advanced_tactical_map()
	build_3d_player()
	build_procedural_ak47() # Original model retained
	build_advanced_gui_systems()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_Q and event.pressed:
		toggle_spawn_menu()
		return

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			if not is_menu_open:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Aim Down Sights (ADS)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not is_reloading:
		if held_object:
			is_rotating_object = event.pressed
		else:
			is_aiming = event.pressed and not is_sprinting

	# Mouse Look & Weapon Sway Calculations
	if event is InputEventMouseMotion:
		if is_rotating_object and held_object:
			var axis_y = player_camera.global_transform.basis.y
			var axis_x = player_camera.global_transform.basis.x
			object_target_rotation = object_target_rotation.rotated(axis_y, -event.relative.x * 0.005)
			object_target_rotation = object_target_rotation.rotated(axis_x, -event.relative.y * 0.005)
			object_target_rotation = object_target_rotation.orthonormalized()
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and player and camera_pivot:
			player.rotate_y(-event.relative.x * mouse_sensitivity)
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-85), deg_to_rad(85))

			# High-Responsiveness Sway
			var sway_mult = 0.2 if is_aiming else 1.0
			sway_offset.x = clamp(sway_offset.x - event.relative.x * 0.0006 * sway_mult, -0.05, 0.05)
			sway_offset.y = clamp(sway_offset.y - event.relative.y * 0.0006 * sway_mult, -0.05, 0.05)
			sway_rotation.z = clamp(sway_rotation.z + event.relative.x * 0.0012 * sway_mult, -0.09, 0.09)
			sway_rotation.x = clamp(sway_rotation.x - event.relative.y * 0.0012 * sway_mult, -0.09, 0.09)

	# Prop Distance Control
	if held_object and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			held_object_distance = clamp(held_object_distance + 0.4, 1.8, 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			held_object_distance = clamp(held_object_distance - 0.4, 1.8, 12.0)

	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not is_menu_open:
		if held_object:
			drop_object()
		else:
			attempt_pickup_or_interact()

	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not is_menu_open:
		execute_weapon_reload()


func _physics_process(delta: float) -> void:
	process_void_limits()
	if not player: return

	# Weapon Cooldown
	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	# Automatic Fire Check
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0 and not is_menu_open and not held_object and not is_reloading and not is_sprinting:
		execute_weapon_fire()

	# --- OVERHAULED SPRING RECOIL SOLVER ---
	var stiffness = 180.0
	var damping = 14.0
	var force_pos = -stiffness * recoil_offset - damping * recoil_velocity
	recoil_velocity += force_pos * delta
	recoil_offset += recoil_velocity * delta

	var force_rot = -stiffness * recoil_rot_offset - damping * recoil_rot_velocity
	recoil_rot_velocity += force_rot * delta
	recoil_rot_offset += recoil_rot_velocity * delta

	# Linear decay for sway & shake
	sway_offset = sway_offset.lerp(Vector2.ZERO, delta * 9.0)
	sway_rotation = sway_rotation.lerp(Vector3.ZERO, delta * 9.0)
	camera_shake = lerp(camera_shake, 0.0, delta * 14.0)

	# Camera Shake & Dynamic Roll
	player_camera.h_offset = randf_range(-camera_shake, camera_shake)
	player_camera.v_offset = randf_range(-camera_shake, camera_shake)
	player_camera.rotation.z = lerp(player_camera.rotation.z, camera_roll, delta * 8.0)

	# ADS & Depth of Field Camera Transition
	var target_fov = 42.0 if is_aiming else (82.0 if is_sprinting else 75.0)
	player_camera.fov = lerp(player_camera.fov, target_fov, delta * 12.0)

	if world_env and world_env.camera_attributes:
		world_env.camera_attributes.dof_blur_near_enabled = is_aiming
		world_env.camera_attributes.dof_blur_near_distance = 0.65

	# Crouch Camera Height Smoothing
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_cam_height, delta * 10.0)

	# Kinematic Movement State Calculations
	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and player.is_on_floor() and Input.is_key_pressed(KEY_W) and not is_aiming and not is_crouching
	is_crouching = (Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL)) and player.is_on_floor()

	if is_crouching:
		current_speed = crouch_speed
		target_cam_height = crouch_cam_height
	else:
		target_cam_height = default_cam_height
		current_speed = sprint_speed if is_sprinting else walk_speed

	# Procedural Sway & Bobbing
	var horizontal_vel = Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and horizontal_vel > 0.1:
		walk_cycle += delta * horizontal_vel * (1.8 if is_crouching else 2.5)
	else:
		walk_cycle = lerp(walk_cycle, 0.0, delta * 6.0)

	var bob_x = sin(walk_cycle * 0.5) * (0.003 if is_aiming else (0.022 if is_sprinting else 0.012))
	var bob_y = sin(walk_cycle) * (0.002 if is_aiming else (0.018 if is_sprinting else 0.009))

	# Dynamic Weapon Offsets by Stance
	var target_gun_pos = Vector3(0.22, -0.24, -0.48) # Hipfire Base
	if is_aiming:
		target_gun_pos = Vector3(0.0, -0.165, -0.38) # Sights Aligned
	elif is_sprinting:
		target_gun_pos = Vector3(0.18, -0.32, -0.42) # Sprinting Low-Ready

	var movement_offset = Vector3(sway_offset.x + bob_x, sway_offset.y + bob_y, 0)
	current_weapon_pos = current_weapon_pos.lerp(target_gun_pos + movement_offset, delta * 16.0)

	if not is_reloading and is_instance_valid(weapon_mesh_root):
		weapon_mesh_root.transform.origin = current_weapon_pos + recoil_offset
		weapon_mesh_root.rotation = recoil_rot_offset + sway_rotation
		if is_sprinting:
			weapon_mesh_root.rotation.y += deg_to_rad(-22.0)
			weapon_mesh_root.rotation.x += deg_to_rad(-12.0)

	# Character Kinematics & Gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor() and not is_menu_open:
		player.velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if not is_menu_open and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if Input.is_key_pressed(KEY_W): input_dir.y -= 1
		if Input.is_key_pressed(KEY_S): input_dir.y += 1
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1
		if Input.is_key_pressed(KEY_D): input_dir.x += 1

	camera_roll = -input_dir.x * deg_to_rad(1.8)

	var direction := (player.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)

	player.move_and_slide()

	# Dynamic UI Crosshair Expansion
	var speed_factor = horizontal_vel / sprint_speed
	var target_spread = 8.0 + (speed_factor * 28.0) + (recoil_offset.length() * 450.0)
	if is_aiming: target_spread = 2.0
	crosshair_spread = lerp(crosshair_spread, target_spread, delta * 18.0)
	update_crosshair_layout()

	# Physics Object Interaction Engine
	if held_object:
		if not is_instance_valid(held_object):
			held_object = null
			return
		var target_pos = player_camera.global_position - (player_camera.global_transform.basis.z * held_object_distance)
		held_object.linear_velocity = (target_pos - held_object.global_position) * 28.0
		held_object.angular_velocity *= 0.82

		if is_rotating_object:
			var current_b = held_object.global_transform.basis
			held_object.global_transform.basis = current_b.slerp(object_target_rotation, delta * 12.0)


# --- ENVIRONMENT & GOD RAYS ENGINE ---
func setup_god_rays_environment() -> void:
	world_env = WorldEnvironment.new()
	var env = Environment.new()

	# Clear Atmospheric Sky (Clouds Completely Removed)
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.75, 0.84)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.14)
	sky_mat.ground_horizon_color = Color(0.68, 0.75, 0.84)
	sky_mat.sun_angle_max = 10.0

	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Post-Processing Pipeline
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Screen-Space Effects
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.4
	env.ssr_enabled = true
	env.ssil_enabled = true

	# Dense Volumetric Fog for God Rays & Atmosphere
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.92, 0.94, 0.98)
	env.volumetric_fog_length = 85.0
	env.volumetric_fog_detail_spread = 2.0

	world_env.environment = env

	# Depth of Field Attributes
	var cam_attrs = CameraAttributesPractical.new()
	cam_attrs.dof_blur_far_enabled = true
	cam_attrs.dof_blur_far_distance = 60.0
	cam_attrs.dof_blur_far_transition = 25.0
	cam_attrs.dof_blur_amount = 0.1
	world_env.camera_attributes = cam_attrs

	add_child(world_env)

	# Directional Sun Light (High Volumetric Fog Energy for Light Shafts)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-30, 48, 0)
	sun_light.light_color = Color(1.0, 0.92, 0.82)
	sun_light.light_energy = 2.6
	sun_light.light_volumetric_fog_energy = 4.5 # Heavy God Ray Projection
	sun_light.shadow_enabled = true
	sun_light.shadow_blur = 1.2
	add_child(sun_light)


# --- WEAPON OPERATIONS & IMPACT MECHANICS ---
func execute_weapon_fire() -> void:
	if current_ammo <= 0:
		execute_weapon_reload()
		return

	current_ammo -= 1
	update_hud_display()
	fire_cooldown = fire_rate

	# Dual Vector Recoil Impulses
	var kick = 0.035 if is_aiming else 0.08
	recoil_velocity += Vector3(randf_range(-kick * 0.35, kick * 0.35), randf_range(kick * 0.2, kick * 0.4), kick * 1.8)
	recoil_rot_velocity += Vector3(randf_range(kick * 3.5, kick * 4.8), randf_range(-kick * 1.2, kick * 1.2), randf_range(-kick * 1.5, kick * 1.5))
	camera_shake = 0.025 if is_aiming else 0.05

	# Dynamic Muzzle Light & Mesh Flash
	if muzzle_flash_light and muzzle_flash_mesh:
		muzzle_flash_light.visible = true
		muzzle_flash_mesh.visible = true
		var t = create_tween()
		t.tween_property(muzzle_flash_light, "light_energy", 0.0, 0.035).from(5.0)
		t.parallel().tween_callback(func(): muzzle_flash_mesh.visible = false)

	spawn_ejected_shell_casing()
	spawn_muzzle_smoke()

	# Precision Hitscan
	var space_state = get_world_3d().direct_space_state
	var center = Vector2(get_viewport().get_visible_rect().size) / 2.0

	# Apply spread error to raycast
	var spread_offset = Vector2(randf_range(-crosshair_spread, crosshair_spread), randf_range(-crosshair_spread, crosshair_spread)) * 0.35
	var origin = player_camera.project_ray_origin(center + spread_offset)
	var end = origin + player_camera.project_ray_normal(center + spread_offset) * 150.0

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	if held_object: query.exclude.append(held_object.get_rid())

	var result = space_state.intersect_ray(query)
	if result:
		spawn_impact_particles(result.position, result.normal)
		if result.collider is RigidBody3D:
			var force_dir = (end - origin).normalized()
			var target_body = result.collider as RigidBody3D
			target_body.apply_impulse(force_dir * 32.0, result.position - target_body.global_position)

			# Explosive Barrel Reaction
			if target_body.has_meta("is_explosive"):
				trigger_barrel_explosion(target_body)


func spawn_ejected_shell_casing() -> void:
	if not ejection_port_marker: return

	var casing = RigidBody3D.new()
	casing.mass = 0.035
	casing.global_transform = ejection_port_marker.global_transform
	get_tree().root.add_child(casing)

	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new(); cyl.top_radius = 0.005; cyl.bottom_radius = 0.005; cyl.height = 0.024
	mesh_inst.mesh = cyl

	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.94, 0.76, 0.22)
	brass_mat.metallic = 0.98
	brass_mat.roughness = 0.12
	mesh_inst.material_override = brass_mat
	casing.add_child(mesh_inst)

	var exit_dir = (casing.global_transform.basis.x * 3.6) + (casing.global_transform.basis.y * 2.1) + (casing.global_transform.basis.z * -0.3)
	casing.linear_velocity = exit_dir + (player.velocity * 0.4)
	casing.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-25, 25), randf_range(-25, 25))

	var timer = get_tree().create_timer(2.2)
	timer.timeout.connect(casing.queue_free)


func spawn_muzzle_smoke() -> void:
	if not muzzle_flash_light: return
	var smoke = MeshInstance3D.new()
	var sphere = SphereMesh.new(); sphere.radius = 0.035; sphere.height = 0.07
	smoke.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.85, 0.9, 0.3)
	mat.roughness = 1.0
	smoke.material_override = mat
	smoke.global_transform = muzzle_flash_light.global_transform
	get_tree().root.add_child(smoke)

	var t = smoke.create_tween()
	t.tween_property(smoke, "global_position", smoke.global_position + Vector3(0, 0.35, -0.2), 0.38)
	t.parallel().tween_property(smoke, "scale", Vector3(3.2, 3.2, 3.2), 0.38)
	t.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.38)
	t.tween_callback(smoke.queue_free)


func spawn_impact_particles(pos: Vector3, normal: Vector3) -> void:
	var spark_container = Node3D.new()
	spark_container.position = pos
	get_tree().root.add_child(spark_container)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.15)
	mat.emission_energy_multiplier = 6.0

	for i in range(10):
		var spark = MeshInstance3D.new()
		var box = BoxMesh.new(); box.size = Vector3(0.012, 0.012, 0.012)
		spark.mesh = box
		spark.material_override = mat
		spark_container.add_child(spark)

		var dir = (normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))).normalized()
		var target_pos = dir * randf_range(0.35, 0.9)

		var t = spark.create_tween()
		t.tween_property(spark, "position", target_pos, 0.2)
		t.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.2)

	var cleanup = get_tree().create_timer(0.25)
	cleanup.timeout.connect(spark_container.queue_free)


func trigger_barrel_explosion(barrel: RigidBody3D) -> void:
	var pos = barrel.global_position
	barrel.queue_free()

	# Explosion Light Flash
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = Color(1.0, 0.5, 0.1)
	light.light_energy = 18.0
	light.omni_range = 14.0
	get_tree().root.add_child(light)

	var t = light.create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.6)
	t.tween_callback(light.queue_free)

	# Physical Shockwave Radial Impulse
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new(); sphere.radius = 8.0
	query.shape = sphere
	query.transform = Transform3D(Basis(), pos)

	var results = space_state.intersect_shape(query)
	for res in results:
		if res.collider is RigidBody3D:
			var body = res.collider as RigidBody3D
			var dir = (body.global_position - pos).normalized()
			var dist = pos.distance_to(body.global_position)
			body.apply_impulse(dir * (1.0 - dist / 8.0) * 85.0)


func execute_weapon_reload() -> void:
	if is_reloading or current_ammo == max_magazine or reserve_ammo <= 0: return

	is_reloading = true
	is_aiming = false

	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Receiver Tilt Phase
	tween.tween_property(weapon_mesh_root, "position", current_weapon_pos + Vector3(-0.08, -0.12, 0.05), 0.28)
	tween.parallel().tween_property(weapon_mesh_root, "rotation_degrees", Vector3(18.0, 25.0, -35.0), 0.28)

	# Drop Magazine
	if mag_mesh_node:
		tween.chain().tween_property(mag_mesh_node, "position", Vector3(0, -0.45, -0.1), 0.22)
		tween.parallel().tween_property(mag_mesh_node, "rotation_degrees", Vector3(45, 0, 0), 0.22)

	# Insert Magazine
	tween.chain().tween_callback(func():
		if mag_mesh_node:
			mag_mesh_node.position = Vector3(0, -0.3, 0.1)
			mag_mesh_node.rotation_degrees = Vector3(-20, 0, 0)
	)
	if mag_mesh_node:
		tween.tween_property(mag_mesh_node, "position", Vector3(0, -0.09, -0.06), 0.28)
		tween.parallel().tween_property(mag_mesh_node, "rotation_degrees", Vector3(14, 0, 0), 0.28)

	# Rack Bolt
	if charging_handle_node:
		tween.chain().tween_property(weapon_mesh_root, "rotation_degrees", Vector3(12.0, 32.0, -20.0), 0.14)
		tween.parallel().tween_property(charging_handle_node, "position:z", 0.1, 0.12)
		tween.chain().tween_property(charging_handle_node, "position:z", 0.0, 0.08)

	# Reset
	tween.chain().tween_property(weapon_mesh_root, "position", current_weapon_pos, 0.22)
	tween.parallel().tween_property(weapon_mesh_root, "rotation_degrees", Vector3.ZERO, 0.22)

	tween.chain().tween_callback(func():
		var needed = max_magazine - current_ammo
		var transfer = min(needed, reserve_ammo)
		current_ammo += transfer
		reserve_ammo -= transfer
		update_hud_display()
		is_reloading = false
	)


func attempt_pickup_or_interact() -> void:
	var space_state = get_world_3d().direct_space_state
	var center = Vector2(get_viewport().get_visible_rect().size) / 2.0
	var origin = player_camera.project_ray_origin(center)
	var end = origin + player_camera.project_ray_normal(center) * 8.0

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)

	if result and result.collider is RigidBody3D:
		var target = result.collider
		if target.has_meta("is_ammo_box"):
			reserve_ammo += 90
			update_hud_display()
			target.queue_free()
		elif not target.has_meta("is_static_prop"):
			held_object = target
			held_object_distance = player_camera.global_position.distance_to(held_object.global_position)
			held_object.gravity_scale = 0.0
			object_target_rotation = held_object.global_transform.basis


func drop_object() -> void:
	if held_object:
		held_object.gravity_scale = 1.0
		held_object = null
		is_rotating_object = false


# --- UNMODIFIED ORIGINAL AK-47 MODEL FACTORY ---
func build_procedural_ak47() -> void:
	weapon_rig = Node3D.new()
	camera_pivot.add_child(weapon_rig)

	weapon_mesh_root = Node3D.new()
	weapon_rig.add_child(weapon_mesh_root)

	var stamped_steel = StandardMaterial3D.new()
	stamped_steel.albedo_color = Color(0.1, 0.11, 0.13)
	stamped_steel.metallic = 0.94
	stamped_steel.roughness = 0.28
	if metal_scratches_tex: stamped_steel.normal_texture = metal_scratches_tex; stamped_steel.normal_enabled = true

	var dark_steel = StandardMaterial3D.new()
	dark_steel.albedo_color = Color(0.05, 0.06, 0.07)
	dark_steel.metallic = 0.98
	dark_steel.roughness = 0.18

	var wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.38, 0.17, 0.06)
	wood_material.roughness = 0.4

	var bakelite_mat = StandardMaterial3D.new()
	bakelite_mat.albedo_color = Color(0.5, 0.19, 0.08)
	bakelite_mat.roughness = 0.3

	var add_part = func(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = weapon_mesh_root) -> MeshInstance3D:
		var inst = MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = mat
		inst.position = pos
		inst.rotation_degrees = rot
		parent.add_child(inst)
		return inst

	# Stamped Receiver Box & Ribbed Dust Cover
	var rec_m = BoxMesh.new(); rec_m.size = Vector3(0.042, 0.065, 0.34)
	add_part.call(rec_m, stamped_steel, Vector3(0, 0, 0))

	var dust_m = CylinderMesh.new(); dust_m.top_radius = 0.021; dust_m.bottom_radius = 0.021; dust_m.height = 0.32
	add_part.call(dust_m, dark_steel, Vector3(0, 0.033, -0.01), Vector3(90, 0, 0))

	# Receiver Details & Trigger Guard
	var tg_m = BoxMesh.new(); tg_m.size = Vector3(0.018, 0.025, 0.08)
	add_part.call(tg_m, stamped_steel, Vector3(0, -0.042, 0.04))
	var trig_m = BoxMesh.new(); trig_m.size = Vector3(0.008, 0.02, 0.008)
	add_part.call(trig_m, dark_steel, Vector3(0, -0.038, 0.03), Vector3(-20, 0, 0))

	# Bakelite Pistol Grip
	var grip_m = BoxMesh.new(); grip_m.size = Vector3(0.032, 0.11, 0.04)
	add_part.call(grip_m, bakelite_mat, Vector3(0, -0.085, 0.11), Vector3(-22, 0, 0))

	# Curved Banana Magazine
	mag_mesh_node = Node3D.new()
	mag_mesh_node.position = Vector3(0, -0.09, -0.06)
	weapon_mesh_root.add_child(mag_mesh_node)

	var mag1 = BoxMesh.new(); mag1.size = Vector3(0.03, 0.08, 0.06)
	add_part.call(mag1, dark_steel, Vector3(0, 0, 0), Vector3(10, 0, 0), mag_mesh_node)
	var mag2 = BoxMesh.new(); mag2.size = Vector3(0.029, 0.08, 0.058)
	add_part.call(mag2, dark_steel, Vector3(0, -0.065, -0.018), Vector3(24, 0, 0), mag_mesh_node)
	var mag3 = BoxMesh.new(); mag3.size = Vector3(0.028, 0.06, 0.055)
	add_part.call(mag3, dark_steel, Vector3(0, -0.125, -0.055), Vector3(38, 0, 0), mag_mesh_node)

	# Wooden Stock Assembly
	var stock_m = BoxMesh.new(); stock_m.size = Vector3(0.038, 0.085, 0.28)
	add_part.call(stock_m, wood_material, Vector3(0, -0.015, 0.30), Vector3(-6, 0, 0))

	# Barrel & Wooden Handguards
	var barrel_m = CylinderMesh.new(); barrel_m.top_radius = 0.009; barrel_m.bottom_radius = 0.009; barrel_m.height = 0.48
	add_part.call(barrel_m, dark_steel, Vector3(0, 0.008, -0.38), Vector3(90, 0, 0))

	var lower_hg = BoxMesh.new(); lower_hg.size = Vector3(0.044, 0.048, 0.22)
	add_part.call(lower_hg, wood_material, Vector3(0, -0.01, -0.24))

	# Charging Handle & Ejection Port
	charging_handle_node = Node3D.new()
	charging_handle_node.position = Vector3(0.025, 0.02, 0.02)
	weapon_mesh_root.add_child(charging_handle_node)

	var handle_m = BoxMesh.new(); handle_m.size = Vector3(0.03, 0.015, 0.02)
	add_part.call(handle_m, dark_steel, Vector3(0, 0, 0), Vector3(0, 0, 0), charging_handle_node)

	ejection_port_marker = Node3D.new()
	ejection_port_marker.position = Vector3(0.03, 0.02, -0.02)
	weapon_mesh_root.add_child(ejection_port_marker)

	# Dynamic Muzzle Flash Setup
	var flash_pos = Vector3(0, 0.008, -0.67)
	muzzle_flash_light = OmniLight3D.new()
	muzzle_flash_light.light_color = Color(1.0, 0.75, 0.25)
	muzzle_flash_light.light_energy = 0.0
	muzzle_flash_light.omni_range = 8.0
	muzzle_flash_light.position = flash_pos
	weapon_mesh_root.add_child(muzzle_flash_light)

	var flash_m = SphereMesh.new(); flash_m.radius = 0.04; flash_m.height = 0.08
	var flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.88, 0.45)
	muzzle_flash_mesh = add_part.call(flash_m, flash_mat, flash_pos)
	muzzle_flash_mesh.visible = false


# --- MAP & ENVIRONMENT BUILDER ---
func build_advanced_tactical_map() -> void:
	# Concrete Base Floor Plane
	var ground = StaticBody3D.new(); ground.name = "GroundPlane"; add_child(ground)
	var ground_shape = CollisionShape3D.new()
	ground_shape.shape = BoxShape3D.new()
	(ground_shape.shape as BoxShape3D).size = Vector3(140, 2, 140)
	ground_shape.position.y = -1.0
	ground.add_child(ground_shape)

	var ground_mesh = MeshInstance3D.new()
	var box_m = BoxMesh.new(); box_m.size = Vector3(140, 2, 140)
	ground_mesh.mesh = box_m
	ground_mesh.position.y = -1.0

	var conc_mat = StandardMaterial3D.new()
	conc_mat.albedo_color = Color(0.2, 0.22, 0.25)
	conc_mat.roughness = 0.6
	if concrete_normal_tex:
		conc_mat.normal_texture = concrete_normal_tex
		conc_mat.normal_enabled = true
		conc_mat.uv1_scale = Vector3(14, 14, 14)
	ground_mesh.material_override = conc_mat
	ground.add_child(ground_mesh)

	# Outer Perimeter Compound Walls
	create_wall_structure(Vector3(0, 4, -70), Vector3(140, 8, 2))
	create_wall_structure(Vector3(0, 4, 70), Vector3(140, 8, 2))
	create_wall_structure(Vector3(-70, 4, 0), Vector3(2, 8, 140))
	create_wall_structure(Vector3(70, 4, 0), Vector3(2, 8, 140))

	# CQB Training Facility (Center Building with Windows and Doorways)
	build_cqb_house(Vector3(-12, 0, -10))

	# Sniper Observation Tower
	build_observation_tower(Vector3(22, 0, 18))

	# Jersey Barrier Lanes & Cover Blocks
	for i in range(5):
		spawn_sandbox_object(Vector3(-25 + (i * 3.5), 0.6, 20), ObjectType.DEFENSE_BARRIER)
		spawn_sandbox_object(Vector3(12, 0.8 + (i * 1.7), -25), ObjectType.INDUSTRIAL_CRATE)

	# Floodlight Towers
	var light_positions = [Vector3(-30, 0, -30), Vector3(30, 0, -30), Vector3(-30, 0, 30), Vector3(30, 0, 30)]
	for pos in light_positions:
		var pole = StaticBody3D.new(); pole.position = pos; add_child(pole)
		var p_mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new(); cyl.top_radius = 0.1; cyl.bottom_radius = 0.15; cyl.height = 8.0
		p_mesh.mesh = cyl
		p_mesh.position.y = 4.0
		pole.add_child(p_mesh)

		var spot = SpotLight3D.new()
		spot.position = Vector3(0, 7.8, 0)
		spot.rotation_degrees = Vector3(-60, 45, 0)
		spot.light_energy = 8.0
		spot.spot_range = 35.0
		spot.spot_angle = 45.0
		spot.shadow_enabled = true
		pole.add_child(spot)

	# Default Target Props
	for i in range(12):
		spawn_sandbox_object(Vector3(randf_range(-20, 20), randf_range(2, 8), randf_range(-35, -15)), ObjectType.TARGET_BARREL)
		spawn_sandbox_object(Vector3(randf_range(-35, 35), randf_range(2, 6), randf_range(-35, 35)), ObjectType.EXPLOSIVE_BARREL if i % 3 == 0 else ObjectType.AMMO_BOX)


func create_wall_structure(pos: Vector3, size: Vector3) -> void:
	var wall = StaticBody3D.new(); wall.position = pos; add_child(wall)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new(); box.size = size
	col.shape = box
	wall.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var b_mesh = BoxMesh.new(); b_mesh.size = size
	mesh_inst.mesh = b_mesh

	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.28, 0.3, 0.32)
	w_mat.roughness = 0.7
	mesh_inst.material_override = w_mat
	wall.add_child(mesh_inst)


func build_cqb_house(origin: Vector3) -> void:
	# Outer walls with doorway and window voids
	create_wall_structure(origin + Vector3(-8, 3, 0), Vector3(0.4, 6, 16))
	create_wall_structure(origin + Vector3(8, 3, 0), Vector3(0.4, 6, 16))
	create_wall_structure(origin + Vector3(0, 3, -8), Vector3(16, 6, 0.4))

	# Front Wall with Doorway Split
	create_wall_structure(origin + Vector3(-5, 3, 8), Vector3(6, 6, 0.4))
	create_wall_structure(origin + Vector3(5, 3, 8), Vector3(6, 6, 0.4))
	create_wall_structure(origin + Vector3(0, 5, 8), Vector3(4, 2, 0.4)) # Door Header

	# Roof Slab
	create_wall_structure(origin + Vector3(0, 6.1, 0), Vector3(16.4, 0.2, 16.4))


func build_observation_tower(origin: Vector3) -> void:
	# Support Pillars
	var p_offsets = [Vector3(-2.5, 3, -2.5), Vector3(2.5, 3, -2.5), Vector3(-2.5, 3, 2.5), Vector3(2.5, 3, 2.5)]
	for off in p_offsets:
		create_wall_structure(origin + off, Vector3(0.3, 6, 0.3))

	# Platform Deck
	create_wall_structure(origin + Vector3(0, 6, 0), Vector3(6, 0.3, 6))

	# Guard Rails
	create_wall_structure(origin + Vector3(0, 6.6, -2.9), Vector3(6, 1, 0.1))
	create_wall_structure(origin + Vector3(-2.9, 6.6, 0), Vector3(0.1, 1, 6))
	create_wall_structure(origin + Vector3(2.9, 6.6, 0), Vector3(0.1, 1, 6))


# --- PROCEDURAL TEXTURES & PROPS ---
func generate_procedural_textures() -> void:
	var n_gen = FastNoiseLite.new()
	n_gen.noise_type = FastNoiseLite.TYPE_PERLIN
	n_gen.frequency = 0.08

	concrete_normal_tex = NoiseTexture2D.new()
	concrete_normal_tex.noise = n_gen
	concrete_normal_tex.as_normal_map = true
	concrete_normal_tex.bump_strength = 5.0

	var scr_gen = FastNoiseLite.new()
	scr_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX
	scr_gen.frequency = 0.18

	metal_scratches_tex = NoiseTexture2D.new()
	metal_scratches_tex.noise = scr_gen
	metal_scratches_tex.as_normal_map = true
	metal_scratches_tex.bump_strength = 3.0


func spawn_sandbox_object(spawn_position: Vector3, type: ObjectType) -> void:
	var block = RigidBody3D.new()
	block.mass = 6.0
	block.position = spawn_position
	add_child(block)

	var b_shape = CollisionShape3D.new()
	var b_mesh = MeshInstance3D.new()
	var mat = StandardMaterial3D.new(); mat.roughness = 0.35

	match type:
		ObjectType.TARGET_BARREL:
			var shape = CylinderShape3D.new(); shape.radius = 0.55; shape.height = 1.6
			b_shape.shape = shape
			var mesh = CylinderMesh.new(); mesh.top_radius = 0.55; mesh.bottom_radius = 0.55; mesh.height = 1.6
			b_mesh.mesh = mesh
			mat.albedo_color = Color(0.72, 0.16, 0.12)
			mat.metallic = 0.65

		ObjectType.INDUSTRIAL_CRATE:
			var shape = BoxShape3D.new(); shape.size = Vector3(1.6, 1.6, 1.6)
			b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size
			b_mesh.mesh = mesh
			mat.albedo_color = Color(0.2, 0.38, 0.2)

		ObjectType.DEFENSE_BARRIER:
			var shape = BoxShape3D.new(); shape.size = Vector3(3.0, 1.2, 0.8)
			b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size
			b_mesh.mesh = mesh
			mat.albedo_color = Color(0.4, 0.42, 0.45)
			block.mass = 35.0

		ObjectType.AMMO_BOX:
			var shape = BoxShape3D.new(); shape.size = Vector3(0.7, 0.4, 0.4)
			b_shape.shape = shape
			var mesh = BoxMesh.new(); mesh.size = shape.size
			b_mesh.mesh = mesh
			mat.albedo_color = Color(0.68, 0.52, 0.12)
			mat.metallic = 0.85
			block.set_meta("is_ammo_box", true)

		ObjectType.EXPLOSIVE_BARREL:
			var shape = CylinderShape3D.new(); shape.radius = 0.55; shape.height = 1.6
			b_shape.shape = shape
			var mesh = CylinderMesh.new(); mesh.top_radius = 0.55; mesh.bottom_radius = 0.55; mesh.height = 1.6
			b_mesh.mesh = mesh
			mat.albedo_color = Color(0.9, 0.2, 0.05)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.05, 0.0)
			block.set_meta("is_explosive", true)

	b_mesh.material_override = mat
	block.add_child(b_shape)
	block.add_child(b_mesh)


func process_void_limits() -> void:
	for child in get_children():
		if child is RigidBody3D and child.position.y < -30.0:
			if child == held_object: drop_object()
			child.position = Vector3(randf_range(-6, 6), randf_range(8, 16), randf_range(-6, 6))
			child.linear_velocity = Vector3.ZERO


func build_3d_player() -> void:
	player = CharacterBody3D.new(); player.position = Vector3(0, 2, 14); add_child(player)
	var p_shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new(); capsule.radius = 0.45; capsule.height = 1.8
	p_shape.shape = capsule
	p_shape.position.y = 0.9
	player.add_child(p_shape)

	camera_pivot = Node3D.new(); camera_pivot.position.y = default_cam_height; player.add_child(camera_pivot)
	player_camera = Camera3D.new(); camera_pivot.add_child(player_camera)
	player_camera.make_current()


# --- GUI & DYNAMIC CROSSHAIR SYSTEMS ---
func build_advanced_gui_systems() -> void:
	var cl = CanvasLayer.new(); add_child(cl)

	# Dynamic 4-Line Crosshair Container
	crosshair_container = Control.new()
	crosshair_container.set_anchors_preset(Control.PRESET_CENTER)
	cl.add_child(crosshair_container)

	for i in range(4):
		var line = ColorRect.new()
		line.color = Color(0.1, 1.0, 0.4, 0.85)
		crosshair_container.add_child(line)
		crosshair_lines.append(line)

	update_crosshair_layout()

	# Ammo Display
	HUD_ammo_label = Label.new()
	HUD_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	HUD_ammo_label.offset_left = -220
	HUD_ammo_label.offset_top = -60
	cl.add_child(HUD_ammo_label)
	update_hud_display()

	# Keybind Hint Overlay
	var help_lbl = Label.new()
	help_lbl.text = "[W,A,S,D] Move [Shift] Sprint [C/Ctrl] Crouch [L-Click] Fire [R-Click] ADS / Rotate Prop [R] Reload [Q] Menu [E] Grab Prop"
	help_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help_lbl.offset_left = 25
	help_lbl.offset_top = -45
	cl.add_child(help_lbl)

	# Sandbox Spawn Menu
	spawn_menu_ui = Control.new(); spawn_menu_ui.visible = false; spawn_menu_ui.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(spawn_menu_ui)

	var bg_panel = Panel.new(); bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style = StyleBoxFlat.new(); panel_style.bg_color = Color(0.02, 0.03, 0.05, 0.9)
	bg_panel.add_theme_stylebox_override("panel", panel_style)
	spawn_menu_ui.add_child(bg_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	spawn_menu_ui.add_child(main_vbox)

	var title = Label.new()
	title.text = "TACTICAL SANDBOX PROP CONSOLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var grid = GridContainer.new(); grid.columns = 2
	main_vbox.add_child(grid)

	for key in ObjectType.keys():
		var btn = Button.new()
		btn.text = " Spawn " + str(key).capitalize() + " "
		btn.custom_minimum_size = Vector2(200, 48)
		btn.pressed.connect(_on_spawn_button_pressed.bind(ObjectType[key]))
		grid.add_child(btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear All Dynamic Props"
	clear_btn.pressed.connect(clear_all_spawned_objects)
	main_vbox.add_child(clear_btn)


func update_crosshair_layout() -> void:
	if crosshair_lines.size() < 4: return
	var thickness = 2.0
	var length = 10.0

	# Top Line
	crosshair_lines[0].size = Vector2(thickness, length)
	crosshair_lines[0].position = Vector2(-thickness / 2.0, -crosshair_spread - length)

	# Bottom Line
	crosshair_lines[1].size = Vector2(thickness, length)
	crosshair_lines[1].position = Vector2(-thickness / 2.0, crosshair_spread)

	# Left Line
	crosshair_lines[2].size = Vector2(length, thickness)
	crosshair_lines[2].position = Vector2(-crosshair_spread - length, -thickness / 2.0)

	# Right Line
	crosshair_lines[3].size = Vector2(length, thickness)
	crosshair_lines[3].position = Vector2(crosshair_spread, -thickness / 2.0)


func toggle_spawn_menu() -> void:
	is_menu_open = not is_menu_open
	spawn_menu_ui.visible = is_menu_open
	crosshair_container.visible = not is_menu_open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_menu_open else Input.MOUSE_MODE_CAPTURED)
	if held_object: drop_object()


func update_hud_display() -> void:
	if HUD_ammo_label:
		HUD_ammo_label.text = "AMMO: %d / %d" % [current_ammo, reserve_ammo]


func _on_spawn_button_pressed(type: ObjectType) -> void:
	var spawn_pos = player.global_position - (player.global_transform.basis.z * 3.5) + Vector3(0, 0.8, 0)
	spawn_sandbox_object(spawn_pos, type)
	toggle_spawn_menu()


func clear_all_spawned_objects() -> void:
	for child in get_children():
		if child is RigidBody3D and child.name != "GroundPlane":
			child.queue_free()
	held_object = null
	toggle_spawn_menu()
