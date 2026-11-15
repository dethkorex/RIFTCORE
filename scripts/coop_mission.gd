extends Node3D

signal exit_requested
signal rewards_earned(xp: int, bolts: int, blueprints: Array, sector: int)
signal operator_wiped

const PLAYER := preload("res://scenes/actors/riftcore_player.tscn")
const FactoryHUD := preload("res://scripts/factory_hud.gd")
const UI := preload("res://scripts/rift_ui.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const FoundryModule := preload("res://scripts/foundry_run_module.gd")
const Miniboss := preload("res://scripts/sector_miniboss.gd")
const Details := preload("res://scripts/sector_details.gd")
const Loading := preload("res://scripts/act_loading_screen.gd")
const Equipment := preload("res://scripts/equipment_stats.gd")
const BossCache := preload("res://scripts/boss_loot_cache.gd")
const SuitReveal := preload("res://scripts/suit_reveal.gd")
const BossIntro := preload("res://scripts/boss_intro.gd")
const Story := preload("res://scripts/rift_story.gd")
const StoryDialogue := preload("res://scripts/story_dialogue.gd")
const CampaignDoor := preload("res://scripts/campaign_door.gd")
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
var arena_door: CampaignDoor
var repair_hall: Node3D
var exit_marker: Marker3D
var boss_started := false
var boss_intro_active := false
var entrance_open := false
var boss_defeated := false
var suit_reveal_playing := false
var changing_act := false
var checkpoint := Vector3.ZERO
var resetting_arena := false
var boss_position := Vector3.ZERO
var stage_props: Array[NodePath] = []
var factory_trap_clock := 0.0
var factory_relays: Array[Node3D] = []
var foundry_boulders: Array[AnimatableBody3D] = []
var personal_replicas: Dictionary[String, Area3D] = {}
var personal_rewards: Array[Dictionary] = []
var next_personal_drop := 0
var personal_bolts := 0
var moving_platforms: Array[AnimatableBody3D] = []
var props_consumed: Array[int] = []
var active_weapon_ids: Array = []
var stage_title: Label
var objective: Label
var field_briefing: CanvasLayer
var module_chooser: CanvasLayer
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
var reboot_markers: Array[Label3D] = []
var reboot_used := false
var reboot_from := -1
var reboot_target := -1
var reboot_left := 0.0
var reboot_health := 0.0
var reboot_origin := Vector3.ZERO
var return_button: Button
var pause_menu: PauseMenu
var resume_controls_pending := false
var rewards_status: Label
var stats: Label
var clock := 0.0
var outcome := ""
var team_xp := 0
var sector_seconds := 0.0
var security_defeated := 0
var lives_lost := 0
var extracted_results: Dictionary = {}
var boss_cache: BossCache
var cache_opened := false
var quick_revision := 0
var salvage_spills := {}
const SalvageOrbs := preload("res://scripts/material_pickup.gd")
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
	for index in roster.size():
		personal_rewards.append({"bolts": 0, "blueprints": [], "materials": {}, "supplies": {}})
	difficulty = (1.0 + DIFFICULTY_PER_GUEST * (roster.size() - 1)) * Difficulty.combat_scale(sector, mode)
	if host:
		for id in roster.slice(1):
			var loadout = Profile.new()
			loadout.manual_only = true
			remote_players[id] = {"profile": loadout, "loaded": false, "timeout": 0.0, "suspended": false, "input": -1, "edge": -1, "quick_revision": 0}
	for number in range(1, sector):
		active_weapon_ids.append(Catalog.info(number).reward)
	peer.expose_func(receive_input)
	peer.expose_func(receive_state)
	peer.expose_func(receive_operators)
	peer.expose_func(receive_cache_open)
	peer.expose_func(receive_salvage_spill)
	peer.expose_func(receive_recovered)
	peer.expose_func(receive_personal_loot)
	peer.expose_func(receive_personal_pickup_taken)
	peer.expose_func(receive_restore_feedback)
	peer.expose_func(receive_boss_intro)
	peer.expose_func(receive_suit_reveal)
	peer.expose_func(receive_suit_impact)
	peer.expose_func(receive_shot)
	peer.expose_func(receive_outcome)
	peer.expose_func(receive_act)
	peer.expose_func(receive_loadout)
	peer.expose_func(receive_quick_config)
	peer.expose_func(receive_reboot_request)
	peer.expose_func(receive_module_choice)
	peer.expose_func(receive_deflection)
	load_stage()
	build_hud()
	show_field_briefing.call_deferred()
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
	apply_quick_config(loadout, quick)
	var slots := {}
	for id in gear:
		if id is String and Profile.GEAR.has(id) and gear[id] == "equipped":
			var slot: String = Profile.GEAR[id].slot
			if not slots.has(slot):
				slots[slot] = true
				loadout.gear[id] = "equipped"
	for enhancement in local_profile.all_upgrades():
		loadout.owned[enhancement.id] = clampi(int(upgrades.get(enhancement.id, 0)), 0, enhancement.prices.size())
	Equipment.apply(operators[roster.find(sender)], loadout)

func apply_quick_config(loadout, quick: Array, operator: RiftPlayer = null) -> void:
	var field_stock := {} if operator == null else loadout.finish_field_supplies(operator.recovered_supplies, true) as Dictionary
	for index in 4:
		var item = quick[index] if index < quick.size() else {}
		var id := String(item.get("id", "")) if item is Dictionary else ""
		var next := {}
		if Profile.stock.has(id) and not Profile.stock[id].has("material"):
			var count := clampi(int(item.get("count", 0)), 0, Profile.QUICK_MAX)
			if count > 0:
				next = {"id": id, "count": count}
				var requested := clampi(int(item.get("field", 0)), 0, count)
				var field := mini(requested, int(field_stock.get(id, 0)))
				next.count = count - requested + field
				if field > 0:
					next.field = field
					field_stock[id] -= field
				if next.count == 0:
					next = {}
		loadout.quick_slots[index] = next
	if operator:
		operator.recovered_supplies.assign(field_stock)

func send_quick_config() -> void:
	if not host and outcome.is_empty():
		quick_revision += 1
		peer.call_func_on(peer.get_host(), receive_quick_config, quick_revision, local_profile.quick_slots)

func receive_quick_config(revision: int, quick: Array) -> void:
	var sender: int = peer.get_sender_id()
	if not host or not remote_players.has(sender) or not outcome.is_empty() or quick.size() != 4:
		return
	var remote: Dictionary = remote_players[sender]
	if not remote.loaded or revision <= remote.quick_revision:
		return
	remote.quick_revision = revision
	apply_quick_config(remote.profile, quick, operators[roster.find(sender)])

func load_stage() -> void:
	cancel_reboot()
	reboot_used = false
	reboot_markers.clear()
	var previous := []
	for operator in operators:
		previous.append([operator.health, operator.energy, operator.lives, operator.equipped_suit(), operator.recovered_supplies, operator.salvage, operator.recovered_blueprints])
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
	foundry_boulders.clear()
	personal_replicas.clear()
	factory_trap_clock = 0.0
	moving_platforms.clear()
	props_consumed.clear()
	boss_started = false
	boss_intro_active = false
	resetting_arena = false
	entrance_open = false
	boss_defeated = false
	cache_opened = false
	salvage_spills.clear()
	checkpoint = Vector3.ZERO
	last_boss_health = -1.0
	remote_checkpoint = Vector3.ZERO
	var info := Catalog.info(sector)
	var path: String = info.level if act == 1 else "res://scenes/levels/%s_act_2.tscn" % info.id
	var packed := load(path) as PackedScene
	stage = packed.instantiate() as Node3D
	add_child(stage)
	var actors := stage.get_node("Actors")
	actors.set_meta("opponent_health_scale", difficulty)
	actors.set_meta("mission_difficulty", mode)
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
			operator.unlock_sector_weapon(id, false)
		if previous.is_empty() and not active_weapon_ids.is_empty():
			operator.equip_sector_weapon(active_weapon_ids.back())
		operator.gain_experience(roundi(team_xp * operator.xp_gain_multiplier), false)
		if not previous.is_empty():
			operator.health = clampf(previous[index][0], 1.0, operator.max_health)
			operator.energy = minf(previous[index][1], operator.max_energy)
			operator.lives = previous[index][2]
			if operator.lives <= 0:
				operator.lives = 1
			operator.equip_sector_weapon(previous[index][3])
			operator.recovered_supplies = previous[index][4]
			operator.salvage = previous[index][5]
			operator.recovered_blueprints = previous[index][6]
		operator.set_physics_process(host or index == local_index)
		if not host:
			operator.set_process(false)
			operator.local_prediction = index == local_index
			operator.collision_layer = PREDICTION_LAYER if operator.local_prediction else 0
			if index != local_index:
				operator.collision_mask = 0
		else:
			operator.recovered_resources.connect(func(hp: float, eng: float):
				peer.call_func(receive_restore_feedback, act, index, hp, eng)
			)
			operator.supply_found.connect(func(id: String):
				if index == local_index:
					announce_supply(id)
				else:
					peer.call_func_on(roster[index], receive_recovered, {}, "", id)
			)
			if index != local_index:
				operator.salvage_collected.connect(func(drop: Dictionary): peer.call_func_on(roster[index], receive_recovered, drop, "", ""))
				operator.blueprint_found.connect(func(id: String): peer.call_func_on(roster[index], receive_recovered, {}, id, ""))
			operator.fell_into_pit.connect(respawn_operator.bind(operator))
			operator.died.connect(respawn_operator.bind(operator))
			operator.projectile_deflected.connect(func(id: int): peer.call_func(receive_deflection, act, id))
			operator.shot_fired.connect(send_shot)
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
		var marker := Label3D.new()
		marker.font = UI.DISPLAY
		marker.font_size = 36
		marker.pixel_size = 0.0055
		marker.outline_size = 10
		marker.modulate = Color("75ffd2")
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.hide()
		stage.add_child(marker)
		reboot_markers.append(marker)
		targets.append([])
	for node in get_tree().get_nodes_in_group(&"level_enemies"):
		if not stage.is_ancestor_of(node) or not node is WalkerBot:
			continue
		var enemy := node as WalkerBot
		enemy.mission_enemy = true
		enemy.scale_for_sector(sector, act, difficulty, mode)
		if host:
			enemy.died.connect(earn_security_rewards.bind(enemy))
		else:
			disable_replica(enemy)
		enemies.append(enemy)
	gate = stage.get_node("Gate")
	arena_door = CampaignDoor.new(gate)
	arena_door.reset()
	exit_marker = stage.get_node("MARKERS/RoomExit")
	boss = actors.get_node(info.boss_node) as Combatant
	boss_position = boss.position
	if act == 1:
		actors.remove_child(boss)
		boss.queue_free()
		var guard := Miniboss.for_sector(sector, Color(info.color), info.weak, gate.global_position, stage.get_node("ExitBarrier").global_position.x)
		guard.name = "SectorMiniboss"
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
	if host:
		stage.set_meta(&"personal_chest", send_salvage_spill)
		stage.set_meta(&"personal_drone_loot", dispatch_drone_loot)
	for node in stage.find_children("*", "Area3D", true, false):
		if node.is_in_group(&"pit_flare") or node.is_in_group(&"factory_interior_trap") or node.get_script() == preload("res://scripts/biome_zone.gd"):
			node.phase_time = func(): return factory_trap_clock
		if node.is_in_group(&"pit_flare") or node.get_script() == preload("res://scripts/foundry_vent.gd"):
			node.authority = host
		if node.scene_file_path.begins_with("res://assets/pickups/"):
			assign_map_pickup(node)
		elif node.is_in_group(&"factory_salvage_chest"):
			node.difficulty = mode
	for supply in get_tree().get_nodes_in_group(&"factory_supply_carrier"):
		if stage.is_ancestor_of(supply):
			supply.authority = host
			supply.phase_time = func(): return factory_trap_clock
			stage_props.append(stage.get_path_to(supply))
	for barricade in get_tree().get_nodes_in_group(&"factory_breakable"):
		if stage.is_ancestor_of(barricade):
			stage_props.append(stage.get_path_to(barricade))
	for platform in get_tree().get_nodes_in_group(&"factory_one_way"):
		if stage.is_ancestor_of(platform) and platform.get_script() == preload("res://scripts/phase_platform.gd"):
			platform.phase_time = func(): return factory_trap_clock
	for platform in stage.find_children("*", "AnimatableBody3D", true, false):
		if platform.is_in_group(&"foundry_boulder"):
			foundry_boulders.append(platform)
			platform.authority = host
			continue
		moving_platforms.append(platform)
		if not host:
			# Guests need the replicated platform collider for local movement prediction.
			platform.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			platform.process_mode = Node.PROCESS_MODE_DISABLED
	repair_hall = stage.get_node("ForgeHallDoor")
	repair_hall.operators = operators
	repair_hall.authority = host
	Details.new().install(stage, first, sector, act)
	correction = Vector3.ZERO
	if stage_title:
		update_hud_title()
		update_personal_hud(operators[local_index])

func scale_opponent(enemy: Combatant) -> void:
	if enemy.has_method("configure_difficulty"):
		enemy.configure_difficulty(mode)
	enemy.max_health *= (1.0 + DIFFICULTY_PER_GUEST * (roster.size() - 1)) * Difficulty.boss_health_scale(sector, mode, act)
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
		if operator.global_position.y < gate.global_position.y:
			operator.global_position.y = gate.global_position.y + operator.standing_capsule.height * 0.5 + 0.1
		if nearest_operator(gate.global_position) == null and not resetting_arena:
			resetting_arena = true
			reset_coop_arena.call_deferred()
		return
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(operator) and not changing_act and outcome.is_empty() and operator.has_meta("coop_down"):
		restore_operator(operator, respawn_point())

func respawn_point() -> Vector3:
	return stage.get_node("MARKERS/PlayerSpawn").global_position if checkpoint == Vector3.ZERO else checkpoint

func restore_operator(operator: RiftPlayer, at: Vector3, health_ratio := 1.0) -> void:
	if operator.lives <= 0 or not operator.has_meta("coop_down"):
		return
	if foundry_boulders.size() > 0 and not operators.any(func(body): return body.health > 0.0 and body.global_position.x > foundry_boulders[0].global_position.x - foundry_boulders[0].runway_length - 3.5):
		for boulder in foundry_boulders:
			boulder.reset_runway()
	operator.global_position = at
	operator.health = operator.max_health * health_ratio
	operator.velocity = Vector3.ZERO
	operator.invulnerable_time = 1.4
	operator.collision_layer = 1
	operator.remove_meta("coop_down")
	operator.show()
	operator.set_physics_process(true)

func reboot_available() -> bool:
	return outcome.is_empty() and boss_started and not boss_intro_active and not boss_defeated and not resetting_arena and not reboot_used and not changing_act

func reboot_candidate(from: RiftPlayer) -> int:
	if not reboot_available() or from.health <= 0.0 or from.controls_suspended:
		return -1
	var nearest := -1
	var distance := 2.25 * 2.25
	for index in operators.size():
		var body := operators[index]
		if body.health <= 0.0:
			var span := from.global_position.distance_squared_to(body.global_position)
			if span < distance:
				distance = span
				nearest = index
	return nearest

func receive_reboot_request(remote_act: int) -> void:
	var sender: int = peer.get_sender_id()
	if host and remote_act == act and remote_players.has(sender):
		start_reboot(roster.find(sender))

func start_reboot(index: int) -> void:
	if not host or index < 0 or index >= operators.size() or reboot_left > 0.0:
		return
	var reviver := operators[index]
	var rank: int = reviver.quick_profile.rank(Profile.FIELD_REBOOT)
	var downed := reboot_candidate(reviver)
	if rank == 0 or downed < 0 or not operators[downed].has_meta("coop_down"):
		return
	reboot_from = index
	reboot_target = downed
	reboot_health = reviver.health
	reboot_origin = reviver.global_position
	reboot_left = 0.9 if rank == 3 else 1.4

func cancel_reboot() -> void:
	reboot_from = -1
	reboot_target = -1
	reboot_left = 0.0

func tick_reboot(delta: float) -> void:
	if reboot_left <= 0.0:
		return
	var reviver := operators[reboot_from]
	var downed := operators[reboot_target]
	if not reboot_available() or reviver.health < reboot_health or reviver.controls_suspended or downed.health > 0.0 or reviver.global_position.distance_to(reboot_origin) > 0.65 or reviver.global_position.distance_to(downed.global_position) > 2.25:
		cancel_reboot()
		return
	reboot_left -= delta
	if reboot_left <= 0.0:
		var rank: int = reviver.quick_profile.rank(Profile.FIELD_REBOOT)
		reboot_used = true
		downed.lives = maxi(1, downed.lives)
		restore_operator(downed, reviver.global_position, [0.35, 0.50, 0.70][rank - 1])
		cancel_reboot()
		broadcast_state(true)

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
		var guard := Miniboss.for_sector(sector, Color(info.color), info.weak, gate.global_position, stage.get_node("ExitBarrier").global_position.x)
		guard.name = "SectorMiniboss"
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
	reboot_used = false
	cancel_reboot()
	entrance_open = false
	arena_door.reset()
	repair_hall.hold = 0.0
	repair_hall.motor.reset()
	resetting_arena = false
	update_doors()
	for operator in operators:
		restore_operator(operator, respawn_point())

func on_boss_defeated() -> void:
	boss_defeated = true
	cancel_reboot()
	RiftAudio.play_music(true, sector)
	for operator in operators:
		if operator.has_meta("coop_down"):
			operator.lives = maxi(1, operator.lives)
			restore_operator.call_deferred(operator, gate.global_position + Vector3(3.0, 1.0, 0.0))
	award_team_experience((35 if act == 1 else 80) + sector * 8)
	if act == 2:
		create_boss_cache()
		var reward: String = Catalog.info(sector).reward
		var first_unlock := not active_weapon_ids.has(reward)
		if first_unlock:
			active_weapon_ids.append(reward)
		for operator in operators:
			operator.unlock_sector_weapon(reward)
		if first_unlock:
			suit_reveal_playing = true
			peer.call_func(receive_suit_reveal, act, reward)
			play_suit_reveal.call_deferred(reward)
	update_doors()

func receive_suit_reveal(remote_act: int, reward: String) -> void:
	if not host and remote_act == act and act == 2 and reward == Catalog.info(sector).reward and peer.get_sender_id() == peer.get_host() and not suit_reveal_playing:
		suit_reveal_playing = true
		play_suit_reveal.call_deferred(reward)

func play_suit_reveal(reward: String) -> void:
	for operator in operators:
		if host or operator == operators[local_index]:
			operator.set_controls_suspended(true)
	var actor := operators[local_index]
	var until := get_tree().create_timer(5.0, false)
	if is_instance_valid(actor) and actor.health > 0.0:
		actor.unlock_sector_weapon(reward)
		var flash := SuitReveal.new()
		stage.add_child(flash)
		var floor_at := actor.global_position - Vector3.UP * (actor.standing_capsule.height * 0.5)
		camera.set_process(false)
		await flash.play(actor, camera, personal_hud.get_parent(), Catalog.info(sector), floor_at, true)
		flash.queue_free()
		camera.set_process(true)
	if until.time_left > 0.0:
		await until.timeout
	suit_reveal_playing = false
	for operator in operators:
		if host or operator == actor:
			operator.set_controls_suspended(operator == actor and is_pause_open())

func collect_personal_totals(settle_loot := false) -> void:
	for index in operators.size():
		var operator := operators[index]
		var ledger := personal_rewards[index]
		ledger.bolts += operator.credits
		operator.credits = 0
		if not settle_loot:
			continue
		for id in operator.recovered_blueprints:
			if not ledger.blueprints.has(id):
				ledger.blueprints.append(id)
		operator.recovered_blueprints.clear()
		for id in operator.salvage:
			ledger.materials[id] = int(ledger.materials.get(id, 0)) + int(operator.salvage[id])
		operator.salvage.clear()
		ledger.supplies = operator.quick_profile.finish_field_supplies(operator.recovered_supplies, true)

func watch_personal_pickup(pickup: Area3D, key: String, index: int) -> void:
	if index != local_index:
		var signal_name := "taken" if pickup.has_signal("taken") else "collected"
		pickup.connect(signal_name, func(): peer.call_func_on(roster[index], receive_personal_pickup_taken, act, key))

func assign_map_pickup(source: Area3D) -> void:
	var key := "map:" + String(stage.get_path_to(source))
	if not host:
		source.replica = true
		source.collision_mask = 0
		personal_replicas[key] = source
		return
	source.claimant = operators[local_index]
	for index in operators.size():
		if index == local_index:
			continue
		var pickup_scene := load(source.scene_file_path) as PackedScene
		var copy := pickup_scene.instantiate() as Area3D
		copy.transform = source.transform
		copy.kind = source.kind
		copy.large = source.large
		copy.full_heal = source.full_heal
		copy.expires = source.expires
		copy.claimant = operators[index]
		copy.local_copy = false
		source.get_parent().add_child(copy)
		watch_personal_pickup(copy, key, index)

func make_personal_loot(at: Vector3, rewards: Dictionary, index: int) -> Array[Area3D]:
	var terrain := stage.get_node("TERRAIN") as Node3D
	var owner: RiftPlayer = operators[index] if host else null
	if not rewards.has("pickup"):
		return SalvageOrbs.spill(terrain, at, rewards, host, owner, index == local_index)
	var name: String = rewards.pickup.get_file().get_basename()
	if not name in ["health_small", "health_large", "energy_small", "energy_large", "credits_small", "credits_large"]:
		return []
	var packed := load("res://assets/pickups/" + name + ".tscn") as PackedScene
	var orb := packed.instantiate() as Area3D
	orb.claimant = owner
	orb.replica = not host
	orb.local_copy = index == local_index
	orb.expires = rewards.get("temporary", false)
	orb.position = terrain.to_local(at)
	terrain.add_child.call_deferred(orb)
	return [orb]

func issue_personal_loot(at: Vector3, rewards: Dictionary, index: int) -> void:
	var drops := make_personal_loot(at, rewards, index)
	var keys := []
	for pickup in drops:
		var key := "drop:%d" % next_personal_drop
		next_personal_drop += 1
		keys.append(key)
		watch_personal_pickup(pickup, key, index)
	if index != local_index and not drops.is_empty():
		peer.call_func_on(roster[index], receive_personal_loot, act, at, rewards, keys)

func receive_personal_loot(remote_act: int, at: Vector3, rewards: Dictionary, keys: Array) -> void:
	if host or remote_act != act or peer.get_sender_id() != peer.get_host():
		return
	var drops := make_personal_loot(at, rewards, local_index)
	for index in mini(drops.size(), keys.size()):
		var key: String = keys[index]
		var pickup := drops[index]
		personal_replicas[key] = pickup
		pickup.tree_exited.connect(func(): personal_replicas.erase(key))

func receive_personal_pickup_taken(remote_act: int, key: String) -> void:
	if host or remote_act != act or peer.get_sender_id() != peer.get_host():
		return
	var replica := personal_replicas.get(key) as Area3D
	if is_instance_valid(replica):
		replica.queue_free()
		RiftAudio.play_effect(&"pickup")
	personal_replicas.erase(key)

func dispatch_drone_loot(at: Vector3, standard: PackedScene, adaptive: bool) -> void:
	for index in operators.size():
		var reward: Dictionary = preload("res://scripts/cargo_crate.gd").supply_loot(standard, adaptive, operators[index])
		issue_personal_loot(at, reward, index)

func send_salvage_spill(key: String, at: Vector3, chest: Area3D) -> void:
	for index in operators.size():
		var level := RiftPlayer.level_for_experience(operators[index].experience)
		issue_personal_loot(at, chest.roll_loot(level), index)
	peer.call_func(receive_salvage_spill, act, key)

func receive_salvage_spill(remote_act: int, key: String) -> void:
	if host or remote_act != act or peer.get_sender_id() != peer.get_host() or salvage_spills.has(key):
		return
	var chest := stage.get_node("TERRAIN").get_node_or_null(NodePath(key))
	if chest:
		chest.finish_open()
	salvage_spills[key] = []

func create_boss_cache() -> void:
	var actors := stage.get_node("Actors") as Node3D
	boss_cache = BossCache.new()
	boss_cache.authoritative = host
	boss_cache.position = actors.to_local(Vector3(boss_position.x, gate.global_position.y + 0.52, 0.0))
	actors.add_child.call_deferred(boss_cache)
	if host:
		boss_cache.opened.connect(func():
			cache_opened = true
			for index in operators.size():
				var level := RiftPlayer.level_for_experience(operators[index].experience)
				issue_personal_loot(boss_cache.global_position, BossCache.roll_loot(sector, mode, level), index)
			peer.call_func(receive_cache_open)
		)

func receive_cache_open() -> void:
	if host or act != 2 or peer.get_sender_id() != peer.get_host():
		return
	cache_opened = true
	if is_instance_valid(boss_cache) and boss_cache.is_inside_tree():
		boss_cache.finish_open()
	elif is_instance_valid(boss_cache):
		boss_cache.queue_free()

func receive_restore_feedback(remote_act: int, index: int, hp: float, eng: float) -> void:
	if not host and remote_act == act and peer.get_sender_id() == peer.get_host() and index >= 0 and index < operators.size():
		operators[index].play_restore_feedback.call_deferred(hp, eng)

func announce_supply(id: String) -> void:
	if is_instance_valid(personal_hud) and Profile.stock.has(id):
		personal_hud.announce(Profile.stock[id].name + "  +1", Color("75ffd2"), 22)

func receive_recovered(materials: Dictionary, blueprint: String, supply: String) -> void:
	if host or not outcome.is_empty() or peer.get_sender_id() != peer.get_host():
		return
	var operator := operators[local_index]
	if not materials.is_empty():
		operator.collect_salvage(materials)
	if Profile.GEAR.has(blueprint):
		operator.recovered_blueprints[blueprint] = true
	if Profile.stock.has(supply):
		announce_supply(supply)

func update_doors() -> void:
	if boss_defeated:
		var barrier := stage.get_node("ExitBarrier")
		if barrier.visible:
			barrier.hide()
			barrier.get_node("CollisionShape3D").set_deferred("disabled", true)

func check_campaign_progress() -> void:
	var far_edge := exit_marker.global_position.x
	if not boss_started:
		if not entrance_open and operators.all(func(operator): return arena_door.near(operator)):
			entrance_open = true
		if entrance_open and arena_door.passable and operators.all(func(operator): return arena_door.inside(operator, far_edge)):
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
	if not boss_defeated or changing_act or suit_reveal_playing:
		return
	for operator in operators:
		if operator.health > 0.0 and operator.global_position.distance_to(exit_marker.global_position) <= 1.65:
			if act == 1:
				changing_act = true
				peer.call_func(receive_act, 2, team_xp, active_weapon_ids)
				change_act.call_deferred(2)
			else:
				collect_personal_totals(true)
				for index in operators.size():
					if index != local_index:
						var ledger := personal_rewards[index]
						peer.call_func_on(roster[index], receive_outcome, true, operators[index].experience, ledger.bolts, ledger.blueprints, sector_seconds, challenge_results(index))
				extracted_results = challenge_results(local_index)
				var ledger := personal_rewards[local_index]
				finish_mission(true, operators[local_index].experience, ledger.bolts, ledger.blueprints)
			return

func receive_boss_intro(remote_act: int, track: int) -> void:
	if not host and remote_act == act and peer.get_sender_id() == peer.get_host() and not boss_intro_active:
		boss_started = true
		play_boss_intro(track)

func play_boss_intro(track: int) -> void:
	boss_intro_active = true
	if is_instance_valid(field_briefing):
		field_briefing.hide()
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

func receive_act(next: int, xp: int, weapons: Array) -> void:
	if not host and not changing_act and act == 1 and next == 2 and peer.get_sender_id() == peer.get_host():
		changing_act = true
		team_xp = xp
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
	if sector == 1 and act == 2:
		await choose_module()
	show_field_briefing()

func choose_module() -> void:
	if DisplayServer.get_name() == "headless":
		set_module(local_index, "prism")
		if not host:
			peer.call_func_on(peer.get_host(), receive_module_choice, "prism")
		return
	module_chooser = FoundryModule.new()
	add_child(module_chooser)
	module_chooser.choose()
	set_local_controls_suspended(true)
	var id: String = await module_chooser.selected
	module_chooser.queue_free()
	module_chooser = null
	set_module(local_index, id)
	if not host:
		peer.call_func_on(peer.get_host(), receive_module_choice, id)
	resume_controls_pending = true

func receive_module_choice(id: String) -> void:
	var sender: int = peer.get_sender_id()
	if host and remote_players.has(sender):
		set_module(roster.find(sender), id)

func set_module(index: int, id: String) -> void:
	if sector == 1 and act == 2 and index >= 0 and index < operators.size() and operators[index].run_module.is_empty() and FoundryModule.MODULES.has(id):
		operators[index].run_module = id

func show_field_briefing() -> void:
	if DisplayServer.get_name() == "headless" or not local_profile.claim_briefing(sector, act):
		return
	var dialogue := StoryDialogue.new()
	field_briefing = dialogue
	stage.add_child(dialogue)
	await dialogue.play(Story.deployment(sector, act), "", true)
	if field_briefing == dialogue:
		field_briefing = null
	dialogue.queue_free()

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
	objective = UI.label(content, "", 17, UI.WHITE)
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
	pause_menu.quick_edited = send_quick_config
	pause_menu.operator = func(): return operators[local_index]
	pause_menu.dismissed.connect(func(): resume_controls_pending = true)
	pause_menu.leave_requested.connect(func(): exit_requested.emit())
	add_child(pause_menu)
	update_personal_hud(operators[local_index])

func is_pause_open() -> bool:
	return is_instance_valid(module_chooser) or (is_instance_valid(pause_menu) and pause_menu.is_open())

func open_pause() -> void:
	if is_pause_open() or not outcome.is_empty() or changing_act or boss_intro_active or suit_reveal_playing:
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
	personal_hud.credits = int(personal_rewards[local_index].bolts) if host else personal_bolts
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
	if personal_hud.experience != operator.experience:
		personal_hud.set_experience(operator.experience)
	else:
		personal_hud.queue_redraw()

func get_player_axis() -> Vector2:
	if is_pause_open():
		return Vector2.ZERO
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("climb_down", "climb_up"))

func _physics_process(delta: float) -> void:
	if host and is_instance_valid(gate):
		arena_door.step(delta, boss_defeated or entrance_open and not boss_started, operators)
	elif boss_intro_active:
		arena_door.step(delta, false, [])
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
		tick_reboot(delta)
		for index in range(1, operators.size()):
			var remote: Dictionary = remote_players[roster[index]]
			remote.timeout -= delta
			if remote.timeout <= 0.0:
				operators[index].remote_axis = Vector2.ZERO
				operators[index].remote_held.clear()
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.target = nearest_operator(enemy.global_position)
		collect_personal_totals()
		if is_instance_valid(boss) and boss_started:
			boss.target = nearest_operator(boss.global_position)
		for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
			if not shot.is_queued_for_deletion() and not shot.has_meta(&"coop_sent"):
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
	if not host or suit_reveal_playing or not outcome.is_empty() or not axis.is_finite() or not remote_players.has(sender):
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

func earn_security_rewards(enemy: WalkerBot) -> void:
	security_defeated += 1
	award_team_experience(enemy.experience_reward())
	for index in operators.size():
		var reward := enemy.roll_field_drop()
		if reward:
			issue_personal_loot(enemy.find_drop_anchor().position, {"pickup": reward.resource_path, "temporary": true}, index)

func award_team_experience(base_xp: int) -> void:
	if not outcome.is_empty():
		return
	var xp := roundi(base_xp * XP_BONUS)
	team_xp += xp
	for operator in operators:
		var earned := maxi(0, roundi(team_xp * operator.xp_gain_multiplier) - operator.experience)
		if operator.health > 0.0:
			operator.gain_experience(earned)
		else:
			operator.gain_experience(earned, false)
			operator.health = 0.0

func broadcast_state(reliable_operators := false) -> void:
	var players := []
	var security := PackedFloat32Array()
	security.resize(enemies.size() * 6)
	var guards := PackedByteArray()
	guards.resize(enemies.size())
	props_consumed.clear()
	for operator in operators:
		players.append([operator.global_position, operator.model_root.rotation, operator.health, operator.energy, operator.current_animation, operator.facing, operator.equipped_suit(), operator.lives, operator.max_health, operator.max_energy, operator.velocity, operator.fire_lock, operator.charge_held, operator.melee_lock, operator.quick_profile.quick_slots if operator.quick_profile else [], operator.supplies, operator.charge_elapsed if operator.charge_held else 0.0, operator.saber_hold, remote_players.get(roster[players.size()], {}).get("quick_revision", 0), operator.recovered_supplies, operator.experience])
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
			guards[index] = enemy.guard_snapshot()
	var fractures := {}
	for index in stage_props.size():
		var prop := stage.get_node_or_null(stage_props[index])
		if not prop:
			props_consumed.append(index)
		elif prop.is_in_group(&"factory_breakable") and prop.fractures > 0:
			fractures[index] = prop.fractures
	var platform_positions: Array[Vector3] = []
	for platform in moving_platforms:
		platform_positions.append(platform.position)
	var doors := [arena_door.passable, repair_hall.motor.lift(), repair_hall.motor.passable]
	var relay_lamps := PackedByteArray()
	for relay in factory_relays:
		relay_lamps.append(maxi(0, relay.shown_power))
	var foundry_state := foundry_boulders.map(func(rock): return rock.snapshot())
	var boss_state := [Vector3.ZERO, Vector3.ZERO, 0.0, boss_started, boss_defeated, arena_door.lift(), platform_positions, entrance_open, checkpoint, factory_trap_clock, fractures, doors, relay_lamps, [], foundry_state, guards]
	boss_state.append([reboot_used, reboot_from, reboot_target, reboot_left])
	if is_instance_valid(boss):
		boss_state[0] = boss.global_position
		boss_state[1] = boss.rotation
		boss_state[2] = boss.health
		if boss.has_method("foundry_snapshot"):
			boss_state[13] = boss.foundry_snapshot()
	state_sequence += 1
	for index in range(1, roster.size()):
		var snapshot := players.duplicate()
		for other in players.size():
			if other != index:
				snapshot[other] = players[other].slice(0, 11) + [players[other][16], players[other][17]]
		var totals := [personal_rewards[index].bolts, operators[index].recovered_blueprints.size()]
		if reliable_operators:
			peer.call_func_on(roster[index], receive_operators, act, snapshot, state_sequence, totals)
		else:
			peer.call_func_on_unreliable(roster[index], receive_operators, act, snapshot, state_sequence, totals)
	peer.call_func_unreliable(receive_state, act, security, boss_state, props_consumed, team_xp, state_sequence)
	if (not boss_started and operators.any(func(operator): return operator.lives <= 0)) or (boss_started and operators.all(func(operator): return operator.health <= 0.0) and operators.any(func(operator): return operator.lives <= 0)):
		for index in range(1, roster.size()):
			peer.call_func_on(roster[index], receive_outcome, false, 0, 0, [], 0.0, {"operator_wiped": operators[index].lives <= 0})
		finish_mission(false, 0, 0, [], operators[local_index].lives <= 0)

func receive_state(remote_act: int, security: PackedFloat32Array, arena: Array, consumed: Array, xp: int, sequence: int) -> void:
	if host or changing_act or remote_act != act or not outcome.is_empty() or peer.get_sender_id() != peer.get_host() or sequence <= latest_state or security.size() != enemies.size() * 6:
		return
	latest_state = sequence
	if arena.size() > 16:
		reboot_used = arena[16][0]
		reboot_from = arena[16][1]
		reboot_target = arena[16][2]
		reboot_left = arena[16][3]
	if is_instance_valid(boss) and not boss_intro_active:
		boss.global_position = arena[0]
		boss.rotation = arena[1]
		boss.health = arena[2]
		if arena.size() > 13 and not arena[13].is_empty() and boss.has_method("apply_foundry_snapshot"):
			boss.apply_foundry_snapshot(arena[13])
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
	arena_door.apply(arena[5], arena[11][0])
	repair_hall.motor.apply(arena[11][1], arena[11][2])
	if arena[8] != remote_checkpoint:
		remote_checkpoint = arena[8]
		for path_name in ["TERRAIN/MidpointCheckpoint", "TERRAIN/ForgeHallCheckpoint"]:
			var beacon := stage.get_node_or_null(path_name) as Node3D
			if beacon and beacon.global_position.distance_to(remote_checkpoint - Vector3.UP * 0.88) < 0.15:
				beacon.set("online", true)
	for index in mini(moving_platforms.size(), arena[6].size()):
		moving_platforms[index].position = arena[6][index]
	if arena.size() > 9:
		factory_trap_clock = float(arena[9])
	if arena.size() > 14:
		for index in mini(foundry_boulders.size(), arena[14].size()):
			foundry_boulders[index].apply_snapshot(arena[14][index])
	for index in factory_relays.size():
		if arena.size() > 12 and index < arena[12].size():
			factory_relays[index].show_state(arena[12][index] != 0)
	if boss_defeated:
		stage.get_node("ExitBarrier").hide()
		stage.get_node("ExitBarrier/CollisionShape3D").set_deferred("disabled", true)
	if arena.size() > 10:
		for index in arena[10]:
			if index >= 0 and index < stage_props.size():
				var barricade := stage.get_node_or_null(stage_props[index])
				if barricade and barricade.has_method("set_fractures"):
					barricade.set_fractures(arena[10][index])
	for index in consumed:
		if index >= 0 and index < stage_props.size():
			var prop := stage.get_node_or_null(stage_props[index])
			if prop and prop.is_in_group(&"factory_supply_carrier"):
				if not prop.is_queued_for_deletion():
					prop.drop_crate()
				continue
			if prop and prop.is_in_group(&"factory_breakable"):
				prop.set_fractures(5)
			elif prop:
				prop.hide()
	team_xp = xp
	enemy_targets.resize(enemies.size())
	enemy_health.resize(enemies.size())
	enemy_rotation.resize(enemies.size())
	for index in enemies.size():
		var offset := index * 6
		enemy_targets[index] = Vector3(security[offset], security[offset + 1], security[offset + 2])
		enemy_rotation[index] = Vector2(security[offset + 3], security[offset + 4])
		enemy_health[index] = security[offset + 5]
		if arena.size() > 15 and index < arena[15].size():
			enemies[index].apply_guard_snapshot(arena[15][index])

func receive_operators(remote_act: int, players: Array, sequence: int, rewards: Array) -> void:
	if host or changing_act or remote_act != act or not outcome.is_empty() or peer.get_sender_id() != peer.get_host() or sequence <= latest_operators or players.size() != roster.size():
		return
	personal_bolts = int(rewards[0])
	blueprint_count = int(rewards[1])
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
				operator.reflect_saber_pose(data[4], float(data[12]) if data.size() > 12 else -1.0)
				operator.play_character_animation(data[4])
				operator.facing = data[5]
				operator.present_charge(float(data[11]), data[3] >= operator.charged_shot_cost())
			else:
				operator.fire_lock = data[11]
				operator.charge_held = data[12] and not operator.controls_suspended
				operator.present_charge(float(data[16]) if data.size() > 16 and operator.charge_held else 0.0, data[3] >= operator.charged_shot_cost())
				operator.melee_lock = data[13]
				operator.reflect_saber_pose(data[4], float(data[17]) if data.size() > 17 else -1.0)
				if operator.melee_lock > 0.0:
					operator.play_character_animation(data[4])
				if outcome.is_empty() and data[14].size() == 4 and int(data[18]) == quick_revision:
					operator.recovered_supplies.assign(data[19])
					for slot in 4:
						var actual: Dictionary = data[14][slot]
						var local: Dictionary = local_profile.quick_slots[slot]
						if local != actual:
							local_profile.quick_slots[slot] = actual.duplicate()
							local_profile.quick_changed.emit()
			operator.health = data[2]
			operator.energy = data[3]
			operator.max_health = data[8]
			operator.max_energy = data[9]
			operator.lives = data[7]
			if not (index == local_index and suit_reveal_playing) and operator.equipped_suit() != data[6]:
				if String(data[6]).is_empty():
					operator.equip_sector_weapon("")
				else:
					operator.unlock_sector_weapon(data[6])
			operator.visible = operator.health > 0
			operator.experience = int(data[20]) if data.size() > 20 else team_xp
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
		var marker := reboot_markers[index]
		marker.visible = index != local_index and operators[index].health <= 0.0 and reboot_available() and local_profile.rank(Profile.FIELD_REBOOT) > 0
		if marker.visible:
			marker.global_position = operators[index].global_position + Vector3.UP * 1.2
			marker.text = "REBOOTING" if reboot_target == index else "✚  " + display_name
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
	elif reboot_from == local_index:
		teammates.insert(0, "Rebooting ally · stay close")
	elif local_profile.rank(Profile.FIELD_REBOOT) > 0 and reboot_left <= 0.0 and reboot_candidate(local) >= 0:
		var key := RiftSettings.binding_label("field_interact", "key")
		var pad := RiftSettings.binding_label("field_interact", "pad")
		teammates.insert(0, "%s / %s  ·  Reboot ally" % [key, pad])
	partner_status.text = "\n".join(teammates)

	var blueprints: int = local.recovered_blueprints.size() if outcome.is_empty() else blueprint_count
	objective.text = Story.objective(sector, act, boss_defeated, Miniboss.TITLES[sector - 1])
	stats.text = "Security %d left  ·  %d blueprints" % [enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.health > 0 and enemy.visible).size(), blueprints]
	update_personal_hud(operators[local_index])

func challenge_results(index := 0) -> Dictionary:
	if not extracted_results.is_empty() or not host:
		return extracted_results
	var count := 0
	var ledger := personal_rewards[index]
	for amount in ledger.materials.values():
		count += int(amount)
	var health := 100.0
	var energy := 100.0
	for operator in operators:
		health = minf(health, 100.0 * operator.health / operator.max_health)
		energy = minf(energy, 100.0 * operator.energy / operator.max_energy)
	return {"act": 1, "clear": 1, "clean": int(lives_lost == 0), "kills": security_defeated,
		"materials": count, "bolts": ledger.bolts, "time": sector_seconds, "health": health, "energy": energy,
		"recovered": ledger.materials.duplicate(), "supplies": ledger.supplies.duplicate()}

func send_shot(shot: RiftProjectile) -> void:
	peer.call_func(receive_shot, shot.global_position, shot.direction, shot.speed, shot.palette, shot.is_charged, shot.is_magma, shot.owner_faction, shot.launch_profile, shot.range_remaining if is_finite(shot.range_remaining) else -1.0, shot.lifetime, shot.get_instance_id(), shot.weapon_id)
	if not shot.weapon_id.is_empty():
		var suit := shot.weapon_id
		var tint := shot.palette
		var id := shot.get_instance_id()
		shot.reward_hit.connect(func(at: Vector3, links: PackedVector3Array):
			peer.call_func(receive_suit_impact, act, id, suit, tint, at, links)
		)
		shot.reward_spent.connect(func(at: Vector3):
			peer.call_func(receive_suit_impact, act, id, suit, tint, at, PackedVector3Array())
		)

func receive_shot(at: Vector3, direction: Vector3, speed: float, tint: Color, charged: bool, magma: bool, faction: String, profile_id := 0, flight_range := -1.0, flight_time := 2.0, shot_id := 0, suit := "") -> void:
	if host or peer.get_sender_id() != peer.get_host():
		return
	var shot := RiftProjectile.new()
	shot.set_meta(&"coop_shot_id", shot_id)
	shot.collision_layer = 0
	shot.collision_mask = 0
	shot.weapon_id = suit
	shot.speed = speed
	shot.lifetime = flight_time
	add_child(shot)
	shot.global_position = at
	var sector_style := (profile_id >> 3) if profile_id >= 0 else 0
	shot.range_remaining = flight_range if flight_range >= 0.0 else INF
	shot.setup(direction, faction, tint, profile_id == -1, charged, magma, sector_style, profile_id & 7, profile_id == -2)

func receive_suit_impact(remote_act: int, shot_id: int, suit: String, tint: Color, at: Vector3, links: PackedVector3Array) -> void:
	if host or remote_act != act or peer.get_sender_id() != peer.get_host():
		return
	if not links.is_empty():
		RiftProjectile.draw_reward_hit(self, at, tint, suit, links)
		return
	for projectile in get_tree().get_nodes_in_group(&"rift_projectile"):
		if projectile.get_meta(&"coop_shot_id", 0) == shot_id:
			projectile.global_position = at
			projectile.impact()
			return

func receive_deflection(remote_act: int, shot_id: int) -> void:
	if host or remote_act != act or peer.get_sender_id() != peer.get_host():
		return
	for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
		if shot.get_meta(&"coop_shot_id", 0) == shot_id:
			shot.queue_free()
			return

func receive_outcome(success: bool, xp: int, bolts: int, blueprints: Array, duration: float, results := {}) -> void:
	if not host and peer.get_sender_id() == peer.get_host():
		extracted_results = results
		sector_seconds = duration
		finish_mission(success, xp, bolts, blueprints, results.get("operator_wiped", false))

func finish_mission(success: bool, xp: int, bolts: int, blueprints: Array, exhausted_lives := false) -> void:
	if not outcome.is_empty():
		return
	var message := "Mission failed. An operator ran out of retries."
	var new_hard_unlock: bool = success and mode == Difficulty.NORMAL and not local_profile.hard_unlocked(sector)
	local_profile.finish_field_supplies(operators[local_index].recovered_supplies, false)
	if not success and exhausted_lives:
		operator_wiped.emit()
		message = "You ran out of lives. Your operator will return to Operations Station with a fresh run."
	if success:
		if not OS.get_cmdline_user_args().has("--verify-relay") and is_finite(sector_seconds):
			RiftSocial.record_clear(sector, sector_seconds)
		var unlocked: Array[String] = []
		for id in blueprints:
			if id is String and Profile.GEAR.has(id) and not unlocked.has(id):
				unlocked.append(id)
		xp = clampi(xp, 0, 10000)
		bolts = clampi(bolts, 0, 10000)
		team_xp = xp
		personal_bolts = bolts
		blueprint_count = unlocked.size()
		message = "Mission complete. You earned %d XP, %d bolts and %d blueprints." % [xp, bolts, unlocked.size()]
		if not rewards_delivered:
			rewards_delivered = true
			rewards_earned.emit(xp, bolts, unlocked, sector)
	outcome = message
	if is_instance_valid(module_chooser):
		module_chooser.queue_free()
		module_chooser = null
	if is_pause_open():
		pause_menu.close()
	room_status.text = message
	if success:
		var extraction_dialogue: Array = Story.hard_unlock(sector) if new_hard_unlock else []
		rewards_status.text = "Recovered items sent to Storage. Save at the System pad to keep your rewards."
		if extracted_results.get("talent_shards", 0) > 0:
			rewards_status.text += "\nShard Reclaimer · +%d Core Shards." % extracted_results.talent_shards
		if extracted_results.get("talent_packs", 0) > 0:
			rewards_status.text += "\nResupply Contract · +%d Resupply Packs." % extracted_results.talent_packs
		if not extracted_results.get("talent_blueprints", []).is_empty():
			rewards_status.text += "\nArchive Mastery · " + ", ".join(extracted_results.talent_blueprints)
		if extracted_results.has("hunt_award"):
			rewards_status.text += "\nHunt complete · %s sent to Storage." % extracted_results.hunt_award
		if sector == Catalog.SECTORS.size():
			var restored := Story.has_all_memories(local_profile.memories)
			rewards_status.text = Story.ending(restored)
			extraction_dialogue.append_array(Story.ending_exchange(restored))
		if not extraction_dialogue.is_empty() and DisplayServer.get_name() != "headless":
			var dialogue := StoryDialogue.new()
			stage.add_child(dialogue)
			play_extraction_dialogue.call_deferred(dialogue, extraction_dialogue)
	return_button.text = "Return Together" if host else "Leave Mission"
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.grab_focus()
	if success and host:
		return_timer = Timer.new()
		return_timer.one_shot = true
		add_child(return_timer)
		return_timer.timeout.connect(relay_owner.return_to_station)
		var reading_seconds := 12.0 if sector == Catalog.SECTORS.size() else 4.0
		if mode == Difficulty.NORMAL and not relay_owner.party_can_play_difficulty(sector, Difficulty.HARD):
			reading_seconds += 7.0
		return_timer.start(reading_seconds)
	for operator in operators:
		operator.set_physics_process(false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)

func play_extraction_dialogue(dialogue: CanvasLayer, lines: Array) -> void:
	await dialogue.play(lines, "", true)
	dialogue.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and not is_pause_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("pause") and not event is InputEventMouseButton and not is_pause_open():
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed("field_interact") and not is_pause_open() and local_profile.rank(Profile.FIELD_REBOOT) > 0 and reboot_candidate(operators[local_index]) >= 0:
		get_viewport().set_input_as_handled()
		if host:
			start_reboot(local_index)
		else:
			peer.call_func_on(peer.get_host(), receive_reboot_request, act)
