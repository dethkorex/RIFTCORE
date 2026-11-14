extends Node3D

signal exit_requested
signal rewards_earned(xp: int, bolts: int, blueprints: Array, sector: int)

const PLAYER := preload("res://scenes/actors/riftcore_player.tscn")
const FactoryHUD := preload("res://scripts/factory_hud.gd")
const UI := preload("res://scripts/rift_ui.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const Miniboss := preload("res://scripts/sector_miniboss.gd")
const Details := preload("res://scripts/sector_details.gd")
const Loading := preload("res://scripts/act_loading_screen.gd")
const Equipment := preload("res://scripts/equipment_stats.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const BossCache := preload("res://scripts/boss_loot_cache.gd")
const BossIntro := preload("res://scripts/boss_intro.gd")
const INPUTS := [&"jump", &"dash", &"crouch", &"crouch_stick", &"shoot", &"melee", &"climb_down", &"swap_weapon", &"previous_suit", &"quick_0", &"quick_1", &"quick_2", &"quick_3"]
const INPUT_SUSPENDED := 1 << 30
const PauseMenu := preload("res://scripts/coop_pause_menu.gd")
const TICK := 0.05
const INPUT_INTERVAL := 1.0 / 30.0
const MAX_SNAPSHOT_LEAD := 0.10
# Terrain movement fields can see the guest prediction body. Combat and pickups use layer 1.
const PREDICTION_LAYER := 1 << 6
const DIFFICULTY_PER_GUEST := 0.25
const XP_BONUS := 1.5
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")

var host := false
var roster: Array = []
var local_index := 0
var difficulty := 1.0
var mode := 0
var remote_players: Dictionary = {}
var sector := 1
var act := 1
var local_profile
var relay_owner: Node
var stage: Node3D
var boss: Combatant
var gate: Node3D
var exit_marker: Marker3D
var boss_started := false
var boss_intro_active := false
var entrance_open := false
var boss_defeated := false
var changing_act := false
var checkpoint := Vector3.ZERO
var resetting_arena := false
var boss_position := Vector3.ZERO
var stage_props: Array[NodePath] = []
var factory_trap_clock := 0.0
var factory_relays: Array[Node3D] = []
var moving_platforms: Array[AnimatableBody3D] = []
var props_consumed: Array[int] = []
var last_gate_open := false
var active_weapon_ids: Array = []
var stage_title: Label
var personal_hud: Control
var return_timer: Timer
var last_boss_health := -1.0
var remote_checkpoint := Vector3.ZERO
var peer: Node
var operators: Array[RiftPlayer] = []
var enemies: Array[WalkerBot] = []
var room_status: Label
var partner_status: Label
var camera: SideCameraRig
var nameplates: Array[Label3D] = []
var return_button: Button
var pause_menu: PauseMenu
var resume_controls_pending := false
var rewards_status: Label
var stats: Label
var clock := 0.0
var outcome := ""
var team_xp := 0
var sector_seconds := 0.0
var team_bolts := 0
var team_blueprints: Array = []
var security_defeated := 0
var lives_lost := 0
var team_materials: Dictionary = {}
var extracted_results: Dictionary = {}
var boss_cache: BossCache
var cache_opened := false
var cache_pickups: Array[Area3D] = []
var loot_rng := RandomNumberGenerator.new()
var rewards_delivered := false
var blueprint_count := 0
var last_sent_axis := Vector2.ZERO
var snapshot_age := 0.0
var input_sequence := 0
var state_sequence := 0
var latest_state := -1
var latest_operators := -1
var correction := Vector3.ZERO
var pressed: Dictionary = {}
var released: Dictionary = {}
var targets: Array = []
var enemy_targets := PackedVector3Array()
var enemy_health := PackedFloat32Array()
var enemy_rotation := PackedVector2Array()

func _ready() -> void:
	peer = RiftRelay.relay
	if roster.is_empty():
		roster = peer.lobby_get_all_clients().duplicate()
		roster.erase(peer.get_host())
		roster.sort()
		roster.push_front(peer.get_host())
	local_index = roster.find(peer.get_client_id())
	difficulty = (1.0 + DIFFICULTY_PER_GUEST * (roster.size() - 1)) * Difficulty.combat_scale(sector, mode)
	if host:
		for id in roster.slice(1):
			var loadout = Profile.new()
			loadout.manual_only = true
			remote_players[id] = {"profile": loadout, "loaded": false, "timeout": 0.0, "suspended": false, "input": -1, "edge": -1}
	loot_rng.randomize()
	for number in range(1, sector):
		active_weapon_ids.append(Catalog.info(number).reward)
	peer.expose_func(receive_input)
	peer.expose_func(receive_state)
	peer.expose_func(receive_operators)
	peer.expose_func(receive_challenge_results)
	peer.expose_func(receive_cache_open)
	peer.expose_func(receive_cache_pickup)
	peer.expose_func(receive_boss_intro)
	peer.expose_func(receive_shot)
	peer.expose_func(receive_outcome)
	peer.expose_func(receive_act)
	peer.expose_func(receive_loadout)
	load_stage()
	build_hud()
	if not host:
		peer.call_func_on(peer.get_host(), receive_loadout, local_profile.gear, local_profile.owned, local_profile.quick_slots)

func receive_loadout(gear: Dictionary, upgrades: Dictionary, quick: Array) -> void:
	var sender: int = peer.get_sender_id()
	if not host or not remote_players.has(sender) or gear.size() > 160:
		return
	var remote: Dictionary = remote_players[sender]
	if remote.loaded:
		return
	remote.loaded = true
	var loadout = remote.profile
	for index in mini(quick.size(), 4):
		if quick[index] is Dictionary:
			var id := String(quick[index].get("id", ""))
			if Profile.stock.has(id) and not Profile.stock[id].has("material"):
				loadout.quick_slots[index] = {"id": id, "count": clampi(int(quick[index].get("count", 0)), 0, Profile.QUICK_MAX)}
	var slots := {}
	for id in gear:
		if id is String and Profile.GEAR.has(id) and gear[id] == "equipped":
			var slot: String = Profile.GEAR[id].slot
			if not slots.has(slot):
				slots[slot] = true
				loadout.gear[id] = "equipped"
	for enhancement in local_profile.all_upgrades():
		loadout.owned[enhancement.id] = clampi(int(upgrades.get(enhancement.id, 0)), 0, 2)
	Equipment.apply(operators[roster.find(sender)], loadout)

func load_stage() -> void:
	var previous := []
	for operator in operators:
		previous.append([operator.health, operator.energy, operator.lives, operator.equipped_suit()])
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
		shot.queue_free()
	operators.clear()
	enemies.clear()
	targets.clear()
	enemy_targets.clear()
	enemy_health.clear()
	enemy_rotation.clear()
	nameplates.clear()
	stage_props.clear()
	factory_relays.clear()
	factory_trap_clock = 0.0
	moving_platforms.clear()
	props_consumed.clear()
	boss_started = false
	boss_intro_active = false
	resetting_arena = false
	entrance_open = false
	boss_defeated = false
	cache_opened = false
	cache_pickups.clear()
	checkpoint = Vector3.ZERO
	last_boss_health = -1.0
	last_gate_open = false
	remote_checkpoint = Vector3.ZERO
	var info := Catalog.info(sector)
	var path: String = info.level if act == 1 else "res://scenes/levels/%s_act_2.tscn" % info.id
	var packed := load(path) as PackedScene
	stage = packed.instantiate() as Node3D
	add_child(stage)
	var actors := stage.get_node("Actors")
	actors.set_meta("loot_scale", Difficulty.LOOT[mode])
	var first := actors.get_node("RiftcoreMecha") as RiftPlayer
	for index in roster.size():
		var operator := first
		if index != 0:
			operator = PLAYER.instantiate() as RiftPlayer
			operator.name = "PartnerOperator%d" % index
			operator.position = first.position + Vector3([0.0, 0.65, -0.65, 1.3][index], 0.05, 0)
			actors.add_child(operator)
		for other in operators:
			other.add_collision_exception_with(operator)
			operator.add_collision_exception_with(other)
		var remote: Dictionary = remote_players.get(roster[index], {})
		var loadout = local_profile if index == local_index else remote.get("profile", Profile.new())
		if host:
			operator.quick_profile = loadout
		operator.pit_floor_y = first.pit_floor_y
		operator.remote_input = host and index != local_index
		operator.set_controls_suspended(remote.get("suspended", false) if operator.remote_input else is_pause_open() and index == local_index)
		operator.damage_taken_scale = difficulty
		Equipment.apply(operator, loadout)
		for id in active_weapon_ids:
			operator.unlock_sector_weapon(id)
		operator.gain_experience(team_xp, false)
		if not previous.is_empty():
			operator.health = clampf(previous[index][0], 1.0, operator.max_health)
			operator.energy = minf(previous[index][1], operator.max_energy)
			operator.lives = previous[index][2]
			if operator.lives <= 0:
				operator.lives = 1
			operator.equip_sector_weapon(previous[index][3])
		operator.set_physics_process(host or index == local_index)
		if not host:
			operator.set_process(false)
			operator.local_prediction = index == local_index
			operator.collision_layer = PREDICTION_LAYER if operator.local_prediction else 0
			if index != local_index:
				operator.collision_mask = 0
		else:
			operator.coop_xp_pickup = award_pickup_xp
			operator.fell_into_pit.connect(respawn_operator.bind(operator))
			operator.died.connect(respawn_operator.bind(operator))
		operators.append(operator)
		var plate := Label3D.new()
		plate.position.y = 1.48
		plate.font = UI.DISPLAY
		plate.font_size = 30
		plate.pixel_size = 0.0048
		plate.outline_size = 10
		plate.modulate = UI.CYAN if index == local_index else UI.VIOLET
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		operator.add_child(plate)
		nameplates.append(plate)
		targets.append([])
	for node in get_tree().get_nodes_in_group(&"level_enemies"):
		if not stage.is_ancestor_of(node) or not node is WalkerBot:
			continue
		var enemy := node as WalkerBot
		enemy.mission_enemy = true
		enemy.scale_for_sector(sector, act)
		scale_opponent(enemy)
		if host:
			enemy.died.connect(earn_security_rewards.bind(enemy.variant))
		else:
			disable_replica(enemy)
		enemies.append(enemy)
	gate = stage.get_node("Gate")
	exit_marker = stage.get_node("MARKERS/RoomExit")
	boss = actors.get_node(info.boss_node) as Combatant
	boss_position = boss.position
	if act == 1:
		actors.remove_child(boss)
		boss.queue_free()
		var guard := Miniboss.new()
		guard.name = "SectorMiniboss"
		guard.configure(sector, Color(info.color), info.weak, gate.global_position, stage.get_node("ExitBarrier").global_position.x)
		guard.position = Vector3(boss_position.x, gate.position.y + guard.chassis_height, 0.0)
		actors.add_child(guard)
		boss = guard
	scale_opponent(boss)
	boss.hide()
	if host:
		boss.died.connect(on_boss_defeated)
	else:
		disable_replica(boss)
	var level_camera := stage.get_node("CameraRig") as SideCameraRig
	camera = level_camera
	camera.target = operators[local_index]
	var bounds := stage.get_node("MARKERS/CameraBounds")
	camera.min_x = bounds.get_meta("min_x")
	camera.max_x = bounds.get_meta("max_x")
	camera.global_position = camera.target.global_position + Vector3.UP * 0.35
	for path_name in ["TERRAIN/MidpointCheckpoint", "TERRAIN/ForgeHallCheckpoint"]:
		var beacon := stage.get_node_or_null(path_name)
		if beacon and host:
			beacon.activated.connect(func(at: Vector3): checkpoint = at)
	for node in get_tree().get_nodes_in_group(&"factory_shot_relay"):
		if stage.is_ancestor_of(node):
			factory_relays.append(node)
	for node in stage.find_children("*", "Area3D", true, false):
		if node.is_in_group(&"factory_interior_trap") or node.get_script() == preload("res://scripts/biome_zone.gd"):
			node.phase_time = func(): return factory_trap_clock
		if node.scene_file_path.begins_with("res://assets/pickups/") or node.is_in_group(&"factory_salvage_chest"):
			stage_props.append(stage.get_path_to(node))
	for platform in get_tree().get_nodes_in_group(&"factory_one_way"):
		if stage.is_ancestor_of(platform) and platform.get_script() == preload("res://scripts/phase_platform.gd"):
			platform.phase_time = func(): return factory_trap_clock
	for platform in stage.find_children("*", "AnimatableBody3D", true, false):
		moving_platforms.append(platform)
		if not host:
			# Guests need the replicated platform collider for local movement prediction.
			platform.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			platform.process_mode = Node.PROCESS_MODE_DISABLED
	stage.get_node("ForgeHallDoor").target = first
	Details.new().install(stage, first, sector, act)
	correction = Vector3.ZERO
	if stage_title:
		update_hud_title()
		update_personal_hud(operators[local_index])

func scale_opponent(enemy: Combatant) -> void:
	enemy.max_health *= difficulty
	enemy.health = enemy.max_health
	enemy.health_changed.emit(enemy.health, enemy.max_health)

func disable_replica(body: Combatant) -> void:
	body.set_process(false)
	body.set_physics_process(false)
	body.collision_layer = 0
	body.collision_mask = 0

func respawn_operator(operator: RiftPlayer) -> void:
	if operator.has_meta("coop_down") or not outcome.is_empty() or changing_act:
		return
	operator.set_meta("coop_down", true)
	operator.lives -= 1
	lives_lost += 1
	operator.health = 0.0
	operator.hide()
	operator.cancel_charge()
	operator.set_physics_process(false)
	operator.set_deferred("collision_layer", 0)
	if boss_started and not boss_defeated:
		if nearest_operator(gate.global_position) == null and not resetting_arena:
			resetting_arena = true
			reset_coop_arena.call_deferred()
		return
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(operator) and not changing_act and outcome.is_empty() and operator.has_meta("coop_down"):
		restore_operator(operator, respawn_point())

func respawn_point() -> Vector3:
	return stage.get_node("MARKERS/PlayerSpawn").global_position if checkpoint == Vector3.ZERO else checkpoint

func restore_operator(operator: RiftPlayer, at: Vector3) -> void:
	if operator.lives <= 0 or not operator.has_meta("coop_down"):
		return
	operator.global_position = at
	operator.health = operator.max_health
	operator.velocity = Vector3.ZERO
	operator.invulnerable_time = 1.4
	operator.collision_layer = 1
	operator.remove_meta("coop_down")
	operator.show()
	operator.set_physics_process(true)

func reset_coop_arena() -> void:
	RiftAudio.play_music(true, sector)
	await get_tree().create_timer(1.2).timeout
	if not outcome.is_empty() or changing_act:
		resetting_arena = false
		return
	for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
		shot.queue_free()
	for minion in get_tree().get_nodes_in_group(&"arena_minions"):
		minion.queue_free()
	var actors := stage.get_node("Actors")
	boss.active = false
	actors.remove_child(boss)
	boss.queue_free()
	var info := Catalog.info(sector)
	if act == 1:
		var guard := Miniboss.new()
		guard.name = "SectorMiniboss"
		guard.configure(sector, Color(info.color), info.weak, gate.global_position, stage.get_node("ExitBarrier").global_position.x)
		guard.position = Vector3(boss_position.x, gate.position.y + guard.chassis_height, 0.0)
		boss = guard
	else:
		var packed := load(info.boss_scene) as PackedScene
		boss = packed.instantiate() as Combatant
		boss.name = info.boss_node
		boss.position = boss_position
	actors.add_child(boss)
	scale_opponent(boss)
	boss.hide()
	boss.died.connect(on_boss_defeated)
	boss_started = false
	entrance_open = false
	resetting_arena = false
	update_doors()
	for operator in operators:
		restore_operator(operator, respawn_point())

func on_boss_defeated() -> void:
	boss_defeated = true
	RiftAudio.play_music(true, sector)
	for operator in operators:
		if operator.has_meta("coop_down"):
			operator.lives = maxi(1, operator.lives)
			restore_operator.call_deferred(operator, gate.global_position + Vector3(3.0, 1.0, 0.0))
	award_shared((35 if act == 1 else 80) + sector * 8, (60 if act == 1 else 100) + sector * 8, "miniboss" if act == 1 else "")
	if act == 2:
		create_boss_cache()
		var reward: String = Catalog.info(sector).reward
		if not active_weapon_ids.has(reward):
			active_weapon_ids.append(reward)
		for operator in operators:
			operator.unlock_sector_weapon(reward)
	update_doors()

func create_boss_cache() -> void:
	var actors := stage.get_node("Actors") as Node3D
	boss_cache = BossCache.new()
	boss_cache.authoritative = host
	boss_cache.position = actors.to_local(Vector3(boss_position.x, gate.global_position.y + 0.52, 0.0))
	actors.add_child.call_deferred(boss_cache)
	if host:
		boss_cache.opened.connect(func():
			cache_opened = true
			var rewards := BossCache.roll_loot(sector, mode)
			var at := boss_cache.global_position
			cache_pickups = BossCache.spill(actors, at, rewards)
			peer.call_func(receive_cache_open, at, rewards)
			for index in cache_pickups.size():
				cache_pickups[index].collected.connect(func(): peer.call_func(receive_cache_pickup, index))
		)

func receive_cache_open(at: Vector3, rewards: Dictionary) -> void:
	if host or act != 2 or peer.get_sender_id() != peer.get_host():
		return
	cache_opened = true
	if is_instance_valid(boss_cache) and boss_cache.is_inside_tree():
		boss_cache.finish_open()
	elif is_instance_valid(boss_cache):
		boss_cache.queue_free()
	var actors := stage.get_node("Actors") as Node3D
	cache_pickups = BossCache.spill(actors, at, rewards)

func receive_cache_pickup(index: int) -> void:
	if not host and act == 2 and peer.get_sender_id() == peer.get_host() and index >= 0 and index < cache_pickups.size():
		if is_instance_valid(cache_pickups[index]):
			cache_pickups[index].queue_free()

func update_doors() -> void:
	var opened := boss_defeated or entrance_open and not boss_started
	if opened != last_gate_open:
		last_gate_open = opened
		var door := gate.get_node("Door") as Node3D
		door.position.y = 4.2 if opened else 0.0
		gate.get_node("Blocker/CollisionShape3D").set_deferred("disabled", opened)
	if boss_defeated:
		var barrier := stage.get_node("ExitBarrier")
		if barrier.visible:
			barrier.hide()
			barrier.get_node("CollisionShape3D").set_deferred("disabled", true)

func check_campaign_progress() -> void:
	var hall := stage.get_node("ForgeHallDoor") as Node3D
	hall.target = nearest_operator(hall.global_position)
	var entry := gate.global_position
	if not boss_started:
		if not entrance_open and operators.all(func(operator): return operator.health > 0.0 and absf(operator.global_position.x - entry.x) <= 4.0 and absf(operator.global_position.y - entry.y) <= 3.4):
			entrance_open = true
		if entrance_open and operators.all(func(operator): return operator.health > 0.0 and operator.global_position.x >= entry.x + 1.35):
			boss_started = true
			var track := RiftAudio.choose_boss_track()
			peer.call_func(receive_boss_intro, act, track)
			play_boss_intro(track)
	update_doors()
	if not boss_defeated and not boss_started:
		room_status.text = "Everyone must reach the boss door." if not entrance_open else "Enter the boss room together."
	elif not boss_defeated:
		room_status.text = "%s  •  %d / %d HP" % [Miniboss.TITLES[sector - 1] if act == 1 else Catalog.info(sector).boss, boss.health, boss.max_health]
	if boss_defeated and not changing_act:
		room_status.text = "Enter the Act II gate." if act == 1 else "Reach the extraction pad."
	if not boss_defeated or changing_act:
		return
	for operator in operators:
		if operator.health > 0.0 and operator.global_position.distance_to(exit_marker.global_position) <= 1.65:
			if act == 1:
				changing_act = true
				peer.call_func(receive_act, 2, team_xp, team_bolts, active_weapon_ids)
				change_act.call_deferred(2)
			else:
				extracted_results = challenge_results()
				peer.call_func(receive_challenge_results, extracted_results)
				award_shared(65 + sector * 12, 160 + (sector - 1) * 25, "")
				peer.call_func(receive_outcome, true, team_xp, team_bolts, team_blueprints, sector_seconds)
				finish_mission(true, team_xp, team_bolts, team_blueprints)
			return

func receive_boss_intro(remote_act: int, track: int) -> void:
	if not host and remote_act == act and peer.get_sender_id() == peer.get_host() and not boss_intro_active:
		boss_started = true
		play_boss_intro(track)

func play_boss_intro(track: int) -> void:
	boss_intro_active = true
	RiftAudio.play_boss_music(track)
	for operator in operators:
		operator.cancel_charge()
		operator.velocity = Vector3.ZERO
		operator.set_physics_process(false)
	var cinematic := BossIntro.new()
	stage.add_child(cinematic)
	var title: String = Miniboss.TITLES[sector - 1] if act == 1 else Catalog.info(sector).boss
	await cinematic.play(camera, boss, gate.global_position.y, title, Color(Catalog.info(sector).color), sector, act, true)
	cinematic.queue_free()
	boss_intro_active = false
	for index in operators.size():
		operators[index].set_physics_process(host or index == local_index)
	if host:
		boss.target = nearest_operator(boss.global_position)
		boss.active = true

func receive_act(next: int, xp: int, bolts: int, weapons: Array) -> void:
	if not host and not changing_act and act == 1 and next == 2 and peer.get_sender_id() == peer.get_host():
		changing_act = true
		team_xp = xp
		team_bolts = bolts
		active_weapon_ids = weapons
		change_act.call_deferred(next)

func change_act(next: int) -> void:
	var loading := Loading.new()
	add_child(loading)
	loading.show_loading(Catalog.info(sector).title)
	for operator in operators:
		operator.set_physics_process(false)
	await get_tree().create_timer(0.5).timeout
	act = next
	load_stage()
	loading.begin()
	await get_tree().create_timer(0.5).timeout
	loading.fade_out()
	changing_act = false

func update_hud_title() -> void:
	stage_title.text = "%s  /  ACT %s" % [Catalog.info(sector).title.to_upper(), "I" if act == 1 else "II"]

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	personal_hud = FactoryHUD.new()
	personal_hud.coop = true
	layer.add_child(personal_hud)
	personal_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	personal_hud.show_quick_slots(local_profile)
	var panel := PanelContainer.new()
	panel.theme = UI.theme()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -288
	panel.offset_right = -16
	panel.offset_top = 16
	var content := UI.column(panel, 5)
	stage_title = UI.label(content, "", 27, UI.CYAN)
	update_hud_title()
	stats = UI.label(content, "", 16)
	partner_status = UI.label(content, "", 16, UI.CYAN)
	room_status = UI.label(content, "%.2f× enemy health and damage  /  1.5× shared XP" % difficulty, 16, UI.MUTED)
	rewards_status = UI.label(content, "", 15, UI.CYAN)
	return_button = UI.button(content, "Pause", func():
		if outcome.is_empty():
			open_pause()
		else:
			exit_requested.emit()
	, false, 34)
	return_button.focus_mode = Control.FOCUS_NONE
	pause_menu = PauseMenu.new()
	pause_menu.in_mission = true
	pause_menu.profile = local_profile
	pause_menu.operator = func(): return operators[local_index]
	pause_menu.dismissed.connect(func(): resume_controls_pending = true)
	pause_menu.leave_requested.connect(func(): exit_requested.emit())
	add_child(pause_menu)
	update_personal_hud(operators[local_index])

func is_pause_open() -> bool:
	return is_instance_valid(pause_menu) and pause_menu.is_open()

func open_pause() -> void:
	if is_pause_open() or not outcome.is_empty() or changing_act or boss_intro_active:
		return
	pause_menu.open()
	resume_controls_pending = false
	set_local_controls_suspended(true)

func set_local_controls_suspended(suspended: bool) -> void:
	operators[local_index].set_controls_suspended(suspended)
	if not host and outcome.is_empty() and not changing_act:
		pressed.clear()
		released.clear()
		send_input(true)

func update_personal_hud(operator: RiftPlayer) -> void:
	personal_hud.health = clampf(operator.health / operator.max_health, 0.0, 1.0)
	personal_hud.energy = clampf(operator.energy / operator.max_energy, 0.0, 1.0)
	personal_hud.health_capacity = operator.max_health
	personal_hud.energy_capacity = operator.max_energy
	personal_hud.lives = operator.lives
	personal_hud.credits = team_bolts
	personal_hud.core_shards = local_profile.core_shards
	var suit := Catalog.weapon(operator.equipped_suit())
	personal_hud.weapon = String(suit.get("reward_name", "STANDARD FRAME")).to_upper()
	personal_hud.suit_tint = Color(suit.get("color", UI.CYAN))
	personal_hud.boss_visible = boss_started and not boss_intro_active and not boss_defeated and is_instance_valid(boss)
	if personal_hud.boss_visible:
		personal_hud.boss_name = String(Miniboss.TITLES[sector - 1] if act == 1 else Catalog.info(sector).boss).to_upper()
		personal_hud.boss_tint = Color(Catalog.info(sector).color)
		personal_hud.boss_health = boss.health
		personal_hud.boss_max_health = boss.max_health
	if personal_hud.experience != team_xp:
		personal_hud.set_experience(team_xp)
	else:
		personal_hud.queue_redraw()

func get_player_axis() -> Vector2:
	if is_pause_open():
		return Vector2.ZERO
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("climb_down", "climb_up"))

func _physics_process(delta: float) -> void:
	if resume_controls_pending:
		resume_controls_pending = false
		# Let this physics tick finish before gameplay can read the dismiss action.
		resume_controls.call_deferred()
		return
	if not outcome.is_empty() or changing_act or boss_intro_active or not RiftRelay.mission_active:
		return
	if not host:
		# Keep the guest responsive while the host remains authoritative.
		var local := operators[local_index]
		if local.health > 0.0 and correction.length_squared() > 0.0225:
			var step := correction * (1.0 - exp(-9.0 * delta))
			local.move_and_collide(step)
			correction -= step
		if not is_pause_open():
			for action in INPUTS:
				if Input.is_action_just_pressed(action):
					pressed[action] = true
				if Input.is_action_just_released(action):
					released[action] = true
	else:
		sector_seconds += delta
		for index in range(1, operators.size()):
			var remote: Dictionary = remote_players[roster[index]]
			remote.timeout -= delta
			if remote.timeout <= 0.0:
				operators[index].remote_axis = Vector2.ZERO
				operators[index].remote_held.clear()
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.target = nearest_operator(enemy.global_position)
		for operator in operators:
			if operator.credits > 0:
				award_shared(0, operator.credits, "")
				operator.credits = 0
			for blueprint in operator.recovered_blueprints:
				if not team_blueprints.has(blueprint):
					team_blueprints.append(blueprint)
			operator.recovered_blueprints.clear()
			for id in operator.salvage:
				team_materials[id] = int(team_materials.get(id, 0)) + int(operator.salvage[id])
			operator.salvage.clear()
		if is_instance_valid(boss) and boss_started:
			boss.target = nearest_operator(boss.global_position)
		for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
			if not shot.has_meta(&"coop_sent"):
				shot.set_meta(&"coop_sent", true)
				send_shot(shot)
		check_campaign_progress()
		if boss_intro_active or changing_act or not outcome.is_empty():
			return
	clock += delta
	factory_trap_clock += delta
	var interval := TICK if host else INPUT_INTERVAL
	var responsive_input := not host and (not pressed.is_empty() or not released.is_empty() or get_player_axis().distance_to(last_sent_axis) >= 0.15)
	if clock < interval and not responsive_input:
		return
	clock = 0.0 if responsive_input else fmod(clock, interval)
	if host:
		broadcast_state()
	else:
		send_input()

func resume_controls() -> void:
	if not is_pause_open():
		set_local_controls_suspended(false)

func nearest_operator(at: Vector3) -> RiftPlayer:
	var best: RiftPlayer
	var distance := INF
	for operator in operators:
		var gap := operator.global_position.distance_squared_to(at)
		if operator.health > 0 and gap < distance:
			best = operator
			distance = gap
	return best

func send_input(force_reliable := false) -> void:
	var suspended := is_pause_open()
	var current := INPUT_SUSPENDED if suspended else 0
	var down := 0
	var up := 0
	for index in INPUTS.size():
		var action: StringName = INPUTS[index]
		if not suspended and Input.is_action_pressed(action):
			current |= 1 << index
		if pressed.has(action):
			down |= 1 << index
		if released.has(action):
			up |= 1 << index
	pressed.clear()
	released.clear()
	var axis := get_player_axis()
	last_sent_axis = axis
	input_sequence += 1
	# Take the first arrival for action edges, with reliable delivery as a fallback.
	peer.call_func_on_unreliable(peer.get_host(), receive_input, axis, current, down, up, input_sequence)
	if force_reliable or down != 0 or up != 0:
		peer.call_func_on(peer.get_host(), receive_input, axis, current, down, up, input_sequence)

func receive_input(axis: Vector2, current: int, down: int, up: int, sequence: int) -> void:
	var sender: int = peer.get_sender_id()
	if not host or not outcome.is_empty() or not axis.is_finite() or not remote_players.has(sender):
		return
	var operator := operators[roster.find(sender)]
	var remote: Dictionary = remote_players[sender]
	if sequence > remote.input:
		remote.input = sequence
		remote.timeout = 0.45
		remote.suspended = (current & INPUT_SUSPENDED) != 0
		operator.set_controls_suspended(remote.suspended)
		operator.remote_axis = axis.clamp(Vector2(-1, -1), Vector2(1, 1))
		operator.remote_held.clear()
		for index in INPUTS.size():
			if current & (1 << index):
				operator.remote_held[INPUTS[index]] = true
		if remote.suspended:
			remote.edge = sequence
	if remote.suspended:
		return
	if (down != 0 or up != 0) and sequence > remote.edge:
		remote.edge = sequence
		for index in INPUTS.size():
			if down & (1 << index):
				operator.remote_pressed[INPUTS[index]] = true
			if up & (1 << index):
				operator.remote_released[INPUTS[index]] = true

func award_pickup_xp(amount: int) -> void:
	award_shared(amount, 0, "")

func earn_security_rewards(variant: int) -> void:
	security_defeated += 1
	var base: int = WalkerBot.XP_REWARDS[variant]
	award_shared(base + (sector - 1) * 2, 12 + floori(base * 0.5), "elite" if variant == WalkerBot.Variant.HEAVY else "enemy")

func award_shared(base_xp: int, bolts: int, source: String) -> void:
	if not outcome.is_empty():
		return
	var xp := roundi(base_xp * XP_BONUS)
	team_xp += xp
	team_bolts += bolts
	if not source.is_empty():
		var recovered := Materials.roll(sector, source, loot_rng, Difficulty.LOOT[mode])
		for id in recovered:
			team_materials[id] = int(team_materials.get(id, 0)) + int(recovered[id])
		var blueprint := Blueprints.roll(sector, source, loot_rng, Difficulty.LOOT[mode])
		if not blueprint.is_empty() and not team_blueprints.has(blueprint):
			team_blueprints.append(blueprint)
	for operator in operators:
		if operator.health > 0.0:
			operator.gain_experience(xp)
		else:
			operator.gain_experience(xp, false)
			operator.health = 0.0

func broadcast_state(reliable_operators := false) -> void:
	var players := []
	var security := PackedFloat32Array()
	security.resize(enemies.size() * 6)
	props_consumed.clear()
	for operator in operators:
		players.append([operator.global_position, operator.model_root.rotation, operator.health, operator.energy, operator.current_animation, operator.facing, operator.equipped_suit(), operator.lives, operator.max_health, operator.max_energy, operator.velocity, operator.fire_lock, operator.charge_held, operator.melee_lock, operator.quick_profile.quick_slots if operator.quick_profile else [], operator.supplies])
	for index in enemies.size():
		var enemy := enemies[index]
		if is_instance_valid(enemy) and enemy.health > 0:
			var offset := index * 6
			security[offset] = enemy.global_position.x
			security[offset + 1] = enemy.global_position.y
			security[offset + 2] = enemy.global_position.z
			security[offset + 3] = enemy.robot.rotation.y
			security[offset + 4] = enemy.robot.rotation.z
			security[offset + 5] = enemy.health
	for index in stage_props.size():
		if not stage.has_node(stage_props[index]):
			props_consumed.append(index)
	var platform_positions: Array[Vector3] = []
	for platform in moving_platforms:
		platform_positions.append(platform.position)
	var boss_state := [Vector3.ZERO, Vector3.ZERO, 0.0, boss_started, boss_defeated, gate.get_node("Door").position.y, platform_positions, entrance_open, checkpoint, factory_trap_clock]
	if is_instance_valid(boss):
		boss_state[0] = boss.global_position
		boss_state[1] = boss.rotation
		boss_state[2] = boss.health
	state_sequence += 1
	for index in range(1, roster.size()):
		var snapshot := players.duplicate()
		for other in players.size():
			if other != index:
				snapshot[other] = players[other].slice(0, 11)
		if reliable_operators:
			peer.call_func_on(roster[index], receive_operators, act, snapshot, state_sequence)
		else:
			peer.call_func_on_unreliable(roster[index], receive_operators, act, snapshot, state_sequence)
	peer.call_func_unreliable(receive_state, act, security, boss_state, props_consumed, team_xp, team_bolts, team_blueprints.size(), state_sequence)
	if (not boss_started and operators.any(func(operator): return operator.lives <= 0)) or (boss_started and operators.all(func(operator): return operator.health <= 0.0) and operators.any(func(operator): return operator.lives <= 0)):
		peer.call_func(receive_outcome, false, 0, 0, [], 0.0)
		finish_mission(false, 0, 0, [])

func receive_state(remote_act: int, security: PackedFloat32Array, arena: Array, consumed: Array, xp: int, bolts: int, blueprints_found: int, sequence: int) -> void:
	if host or changing_act or remote_act != act or not outcome.is_empty() or peer.get_sender_id() != peer.get_host() or sequence <= latest_state or security.size() != enemies.size() * 6:
		return
	latest_state = sequence
	if is_instance_valid(boss) and not boss_intro_active:
		boss.global_position = arena[0]
		boss.rotation = arena[1]
		boss.health = arena[2]
		if last_boss_health != boss.health:
			last_boss_health = boss.health
			boss.health_changed.emit(boss.health, boss.max_health)
	if not boss_intro_active:
		if (boss_started and not arena[3]) or (arena[4] and not boss_defeated):
			RiftAudio.play_music(true, sector)
		boss_started = arena[3]
	if act == 2 and arena[4] and not cache_opened and not boss_defeated and not is_instance_valid(boss_cache):
		create_boss_cache()
	boss_defeated = arena[4]
	if is_instance_valid(boss) and not boss_intro_active:
		boss.visible = boss_started and not boss_defeated
	entrance_open = arena[7]
	if boss_defeated:
		room_status.text = "Enter the Act II gate." if act == 1 else "Reach the extraction pad."
	elif boss_started:
		room_status.text = "%s  •  %d / %d HP" % [Miniboss.TITLES[sector - 1] if act == 1 else Catalog.info(sector).boss, arena[2], boss.max_health]
	else:
		room_status.text = "Enter the boss room together." if entrance_open else "Everyone must reach the boss door."
	gate.get_node("Door").position.y = arena[5]
	gate.get_node("Blocker/CollisionShape3D").set_deferred("disabled", boss_defeated or entrance_open and not boss_started)
	if arena[8] != remote_checkpoint:
		remote_checkpoint = arena[8]
		for path_name in ["TERRAIN/MidpointCheckpoint", "TERRAIN/ForgeHallCheckpoint"]:
			var beacon := stage.get_node_or_null(path_name) as Node3D
			if beacon and beacon.global_position.distance_to(remote_checkpoint - Vector3.UP * 0.88) < 0.15:
				beacon.get_node("Status").text = "CHECKPOINT ACTIVE"
	for index in mini(moving_platforms.size(), arena[6].size()):
		moving_platforms[index].position = arena[6][index]
	if arena.size() > 9:
		factory_trap_clock = float(arena[9])
	for receiver in factory_relays:
		receiver.reflect_motion()
	if boss_defeated:
		stage.get_node("ExitBarrier").hide()
		stage.get_node("ExitBarrier/CollisionShape3D").set_deferred("disabled", true)
	for index in consumed:
		if index >= 0 and index < stage_props.size():
			var prop := stage.get_node_or_null(stage_props[index])
			if prop:
				prop.hide()
	team_xp = xp
	team_bolts = bolts
	blueprint_count = blueprints_found
	enemy_targets.resize(enemies.size())
	enemy_health.resize(enemies.size())
	enemy_rotation.resize(enemies.size())
	for index in enemies.size():
		var offset := index * 6
		enemy_targets[index] = Vector3(security[offset], security[offset + 1], security[offset + 2])
		enemy_rotation[index] = Vector2(security[offset + 3], security[offset + 4])
		enemy_health[index] = security[offset + 5]

func receive_operators(remote_act: int, players: Array, sequence: int) -> void:
	if host or changing_act or remote_act != act or not outcome.is_empty() or peer.get_sender_id() != peer.get_host() or sequence <= latest_operators or players.size() != roster.size():
		return
	latest_operators = sequence
	targets = players
	snapshot_age = 0.0
	var local := operators[local_index]
	var local_data: Array = players[local_index]
	local.supplies = local_data[15].duplicate()
	var projected: Vector3 = local_data[0] + local_data[10] * TICK
	correction = projected - local.global_position
	if local_data[2] <= 0.0 or local.health <= 0.0 or correction.length() > 2.5:
		local.global_position = local_data[0]
		local.velocity = local_data[10]
		correction = Vector3.ZERO

func _process(delta: float) -> void:
	if not host:
		snapshot_age += delta
		var blend := 1.0 - exp(-19.0 * delta)
		for index in operators.size():
			var data: Array = targets[index]
			if data.is_empty():
				continue
			var operator := operators[index]
			if index != local_index:
				var projected: Vector3 = data[0]
				if operator.health > 0 and data[2] > 0 and operator.lives == data[7] and operator.global_position.distance_squared_to(projected) < 6.25:
					projected += data[10] * minf(snapshot_age + TICK * 0.5, MAX_SNAPSHOT_LEAD)
					operator.global_position = operator.global_position.lerp(projected, blend)
				else:
					operator.global_position = projected
				operator.model_root.rotation = data[1]
				operator.play_character_animation(data[4])
				operator.facing = data[5]
			else:
				operator.fire_lock = data[11]
				operator.charge_held = data[12] and not operator.controls_suspended
				operator.melee_lock = data[13]
				if data[14].size() == 4:
					for slot in 4:
						var actual: Dictionary = data[14][slot]
						var local: Dictionary = local_profile.quick_slots[slot]
						if not local.is_empty() and actual.get("id") == local.id and local.count > actual.count:
							local.count = actual.count
							local_profile.quick_changed.emit()
			operator.health = data[2]
			operator.energy = data[3]
			operator.max_health = data[8]
			operator.max_energy = data[9]
			operator.lives = data[7]
			if operator.equipped_suit() != data[6]:
				if String(data[6]).is_empty():
					operator.equip_sector_weapon("")
				else:
					operator.unlock_sector_weapon(data[6])
			operator.visible = operator.health > 0
			operator.experience = team_xp
		for index in enemy_targets.size():
			var enemy := enemies[index]
			enemy.visible = enemy_health[index] > 0.0
			if enemy.visible:
				enemy.global_position = enemy.global_position.lerp(enemy_targets[index], blend)
				enemy.robot.rotation = Vector3(0.0, enemy_rotation[index].x, enemy_rotation[index].y)
				if enemy.health != enemy_health[index]:
					enemy.health = enemy_health[index]
					enemy.health_changed.emit(enemy.health, enemy.max_health)
	var local := operators[local_index]
	var teammates := PackedStringArray()
	var view := camera.get_node("Camera3D") as Camera3D
	for index in operators.size():
		var plate := nameplates[index]
		var display_name := Profile.clean_operator_name(str(peer.player_get_data(roster[index], "operator_name", "RX-07")))
		if plate.text != display_name:
			plate.text = display_name
		if index == local_index:
			continue
		var teammate := operators[index]
		var offset := teammate.global_position.x - local.global_position.x
		if teammate.health <= 0.0:
			teammates.append("%s is down" % display_name)
		elif get_viewport().get_visible_rect().has_point(view.unproject_position(teammate.global_position)):
			teammates.append("%s is nearby" % display_name)
		else:
			teammates.append("%s  %s  %.0f m" % ["←" if offset < 0.0 else "→", display_name, absf(offset)])
	if local.health <= 0.0:
		var down := "Down / waiting for the team" if boss_started and not boss_defeated else ("Out of lives" if local.lives <= 0 else "Respawning at checkpoint")
		teammates.insert(0, down)
	partner_status.text = "\n".join(teammates)

	stats.text = "Security %d left  ·  %d blueprints" % [enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.health > 0 and enemy.visible).size(), team_blueprints.size() if host else blueprint_count]
	update_personal_hud(operators[local_index])

func challenge_results() -> Dictionary:
	if not extracted_results.is_empty() or not host:
		return extracted_results
	var count := 0
	for amount in team_materials.values():
		count += int(amount)
	var health := 100.0
	var energy := 100.0
	for operator in operators:
		health = minf(health, 100.0 * operator.health / operator.max_health)
		energy = minf(energy, 100.0 * operator.energy / operator.max_energy)
	return {"act": 1, "clear": 1, "clean": int(lives_lost == 0), "kills": security_defeated,
		"materials": count, "bolts": team_bolts, "time": sector_seconds, "health": health, "energy": energy,
		"recovered": team_materials.duplicate()}

func receive_challenge_results(results: Dictionary) -> void:
	if not host and peer.get_sender_id() == peer.get_host():
		extracted_results = results

func send_shot(shot: RiftProjectile) -> void:
	peer.call_func(receive_shot, shot.global_position, shot.direction, shot.speed, shot.palette, shot.is_charged, shot.is_magma, shot.owner_faction)

func receive_shot(at: Vector3, direction: Vector3, speed: float, tint: Color, charged: bool, magma: bool, faction: String) -> void:
	if host or peer.get_sender_id() != peer.get_host():
		return
	var shot := RiftProjectile.new()
	shot.collision_layer = 0
	shot.collision_mask = 0
	shot.speed = speed
	add_child(shot)
	shot.global_position = at
	shot.setup(direction, faction, tint, false, charged, magma)

func receive_outcome(success: bool, xp: int, bolts: int, blueprints: Array, duration: float) -> void:
	if not host and peer.get_sender_id() == peer.get_host():
		sector_seconds = duration
		finish_mission(success, xp, bolts, blueprints)

func finish_mission(success: bool, xp: int, bolts: int, blueprints: Array) -> void:
	if not outcome.is_empty():
		return
	var message := "Mission failed. The team is out of retries."
	if success:
		if not OS.get_cmdline_user_args().has("--verify-relay") and is_finite(sector_seconds):
			RiftSocial.record_clear(sector, sector_seconds)
		var unlocked: Array[String] = []
		for id in blueprints:
			if id is String and Profile.GEAR.has(id) and Profile.GEAR[id].get("sector", 0) == sector and not unlocked.has(id):
				unlocked.append(id)
		xp = clampi(xp, 0, 10000)
		bolts = clampi(bolts, 0, 10000)
		team_xp = xp
		team_bolts = bolts
		blueprint_count = unlocked.size()
		message = "Mission complete. Each player earned %d XP, %d bolts and %d blueprints." % [xp, bolts, unlocked.size()]
		if not rewards_delivered:
			rewards_delivered = true
			rewards_earned.emit(xp, bolts, unlocked, sector)
	outcome = message
	if is_pause_open():
		pause_menu.close()
	room_status.text = message
	if success:
		rewards_status.text = "Save at the System pad to keep your rewards."
	return_button.text = "Return Together" if host else "Leave Mission"
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.grab_focus()
	if success and host:
		return_timer = Timer.new()
		return_timer.one_shot = true
		add_child(return_timer)
		return_timer.timeout.connect(relay_owner.return_to_station)
		return_timer.start(4.0)
	for operator in operators:
		operator.set_physics_process(false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and not is_pause_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("pause") and not event is InputEventMouseButton and not is_pause_open():
		get_viewport().set_input_as_handled()
		open_pause()
