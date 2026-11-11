extends RefCounted

const UPGRADES := [
	{"id": "armor", "name": "Ceramic Armor II", "cost": 1500, "description": "+12 starting HP"},
	{"id": "capacitor", "name": "Flux Capacitor", "cost": 1950, "description": "+15 starting energy"},
	{"id": "buster", "name": "Buster Overdrive", "cost": 2550, "description": "+15% Buster and saber damage"},
	{"id": "dash", "name": "Vector Drive", "cost": 3100, "description": "+10% dash speed and 15% shorter cooldown; dashing is free"},
]

var path := "user://riftcore_profile.cfg"
var credits := 0
var owned: Dictionary = {}

func restore() -> void:
	var data := ConfigFile.new()
	if data.load(path) != OK:
		return
	credits = maxi(0, int(data.get_value("profile", "credits", 0)))
	for upgrade in UPGRADES:
		var id: String = upgrade.id
		if bool(data.get_value("upgrades", id, false)):
			owned[id] = true

func save() -> Error:
	var data := ConfigFile.new()
	data.set_value("profile", "credits", credits)
	for id in owned:
		data.set_value("upgrades", id, true)
	return data.save(path)

func deposit(amount: int) -> Error:
	amount = maxi(0, amount)
	if amount == 0:
		return OK
	credits += amount
	var result := save()
	if result != OK:
		credits -= amount
	return result

func buy(id: String) -> String:
	for item in UPGRADES:
		if item.id != id:
			continue
		if owned.has(id):
			return "Already installed."
		if credits < item.cost:
			return "Not enough banked credits."
		credits -= item.cost
		owned[id] = true
		if save() != OK:
			credits += item.cost
			owned.erase(id)
			return "Could not save the purchase."
		return "%s installed." % item.name
	return "Unknown upgrade."
