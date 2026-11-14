extends RefCounted

static func apply(operator: RiftPlayer, profile) -> void:
	var armor_rank: int = profile.rank("armor")
	var capacitor_rank: int = profile.rank("capacitor")
	var buster_rank: int = profile.rank("buster")
	var dash_rank: int = profile.rank("dash")
	if armor_rank > 0:
		operator.max_health += 28.0 if armor_rank == 2 else 12.0
		operator.health = operator.max_health
		operator.armor_resistance = 0.10 if armor_rank == 2 else 0.0
	if capacitor_rank > 0:
		operator.max_energy += 32.0 if capacitor_rank == 2 else 15.0
		operator.energy = operator.max_energy
		operator.charge_cost_multiplier = 0.80 if capacitor_rank == 2 else 1.0
	if buster_rank > 0:
		operator.buster_damage_multiplier = 1.32 if buster_rank == 2 else 1.15
	if dash_rank > 0:
		operator.dash_speed *= 1.20 if dash_rank == 2 else 1.10
		operator.dash_cooldown *= 0.68 if dash_rank == 2 else 0.85
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
	operator.xp_pickup_multiplier *= float(stats.get("xp", 1.0))
	operator.healing_pickup_multiplier *= float(stats.get("healing", 1.0))
	operator.armor_resistance = minf(operator.armor_resistance, 0.68)
