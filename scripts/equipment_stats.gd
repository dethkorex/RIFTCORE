extends RefCounted

static func apply(operator: RiftPlayer, profile) -> void:
	var armor_rank: int = profile.rank("armor")
	var capacitor_rank: int = profile.rank("capacitor")
	var buster_rank: int = profile.rank("buster")
	var dash_rank: int = profile.rank("dash")
	if armor_rank > 0:
		operator.max_health += [0.0, 12.0, 28.0, 46.0][armor_rank]
		operator.health = operator.max_health
		operator.armor_resistance = [0.0, 0.0, 0.10, 0.14][armor_rank]
	if capacitor_rank > 0:
		operator.max_energy += [0.0, 15.0, 32.0, 50.0][capacitor_rank]
		operator.energy = operator.max_energy
		operator.charge_cost_multiplier = [1.0, 1.0, 0.80, 0.70][capacitor_rank]
	if buster_rank > 0:
		operator.buster_damage_multiplier = 1.0 + profile.talent_bonus("buster") / 100.0
	if dash_rank > 0:
		operator.dash_speed *= [1.0, 1.10, 1.20, 1.28][dash_rank]
		operator.dash_cooldown *= [1.0, 0.85, 0.68, 0.56][dash_rank]
	operator.low_health_resistance = profile.talent_bonus("last_stand") / 100.0
	operator.contact_recoil_scale = 1.0 - profile.talent_bonus("shock_dampers") / 100.0
	operator.extra_hit_immunity = profile.talent_bonus("phase_lining")
	operator.impact_energy = profile.talent_bonus("impact_converter")
	operator.dash_guard_time = profile.talent_bonus("ghost_drive")
	operator.phoenix_recovery = profile.talent_bonus("phoenix_protocol") / 100.0
	operator.recovery_item_multiplier = 1.0 + profile.talent_bonus("recovery_circuit") / 100.0
	operator.fire_interval *= 1.0 - profile.talent_bonus("trigger_relay") / 100.0
	operator.melee_range *= 1.0 + profile.talent_bonus("saber_reach") / 100.0
	operator.standard_shot_speed = 1.0 + profile.talent_bonus("accelerator") / 100.0
	operator.charge_time_scale = 1.0 - profile.talent_bonus("snap_charge") / 100.0
	operator.burn_damage_multiplier = 1.0 + profile.talent_bonus("magma_catalyst") / 100.0
	operator.charged_damage_multiplier = 1.0 + profile.talent_bonus("overpressure") / 100.0
	operator.extra_saber_targets = int(profile.talent_bonus("ripple_edge"))
	operator.echo_power = profile.talent_bonus("echo_arsenal") / 100.0
	operator.salvage_multiplier *= 1.0 + profile.talent_bonus("salvage_appraisal") / 100.0
	operator.xp_gain_multiplier *= 1.0 + profile.talent_bonus("combat_telemetry") / 100.0
	for item in profile.enhancements:
		if profile.rank(item.id) > 0:
			apply_modifiers(operator, item.stats)
	for slot in profile.GEAR_SLOTS:
		var id: String = profile.equipped_for(slot)
		if not id.is_empty():
			apply_modifiers(operator, profile.GEAR[id].stats)
	operator.health = operator.max_health
	operator.energy = operator.max_energy

static func apply_modifiers(operator: RiftPlayer, stats: Dictionary) -> void:
	operator.armor_resistance = 1.0 - (1.0 - operator.armor_resistance) * (1.0 - float(stats.get("resist", 0.0)))
	operator.max_health += float(stats.get("hp", 0.0))
	operator.max_energy += float(stats.get("energy", 0.0))
	operator.buster_damage_multiplier *= float(stats.get("attack", 1.0))
	operator.charge_cost_multiplier *= float(stats.get("charge", 1.0))
	operator.move_speed *= float(stats.get("speed", 1.0))
	operator.dash_speed *= float(stats.get("dash", 1.0))
	operator.dash_cooldown *= float(stats.get("cooldown", 1.0))
	operator.salvage_multiplier *= float(stats.get("bolts", 1.0))
	operator.xp_gain_multiplier *= float(stats.get("xp", 1.0))
	operator.healing_pickup_multiplier *= float(stats.get("healing", 1.0))
	operator.armor_resistance = minf(operator.armor_resistance, 0.68)
