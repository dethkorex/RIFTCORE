extends Node3D

const CampaignDoor := preload("res://scripts/campaign_door.gd")
var operators: Array = []
var motor: CampaignDoor
var authority := true
var hold := 0.0

func _ready() -> void:
	motor = CampaignDoor.new(self)
	$Shield.area_entered.connect(_protect_hall)

func _physics_process(delta: float) -> void:
	if not authority or operators.is_empty():
		return
	if operators.any(func(operator): return motor.near(operator)):
		hold = 0.36
	else:
		hold = maxf(0.0, hold - delta)
	motor.step(delta, hold > 0.0, operators)

func _protect_hall(area: Area3D) -> void:
	if authority and area.is_in_group(&"rift_projectile") and area.owner_faction == "enemy":
		area.spent = true
		area.queue_free()
