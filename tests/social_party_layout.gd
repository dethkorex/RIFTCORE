extends SceneTree
class PeerPreview extends Node:
	var leader:=1
	func get_client_id() -> int: return 1
	func get_host() -> int: return leader
	func is_host() -> bool: return leader==1
	func lobby_get_all_clients() -> Array: return [1,2,3,4]
	func player_get_data(id: int,_key: String,_fallback: Variant=null) -> Variant:
		return ["Vanguard","Nova","Cipher","Echo"][id-1]
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	failures+=int(not ok)
func settle() -> void:
	for frame in 15: await process_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.profile.path="user://party-layout-profile.cfg"
	game.checkpoint_path="user://party-layout-run.cfg"
	root.add_child(game)
	current_scene=game
	game.profile.manual_only=true
	root.get_node("RiftSettings").show_hub_tips=false
	var relay=root.get_node("RiftRelay")
	var original=relay.relay
	var preview=PeerPreview.new()
	root.add_child(preview)
	relay.relay=preview
	relay.connected_room="QA1234ABCD"
	relay.room_size=4
	relay.available=true
	relay.local_name="Vanguard"
	relay.status="4 / 4 players connected"
	var menu=game.menu
	menu.profile=game.profile
	menu.open_station("Party")
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=resolution
		await settle()
		check(menu.relay_roster.get_child_count()==4,"four party members have separate roster rows at %s"%resolution)
		check(menu.relay_members.text=="SQUAD  /  4 OF 4","party count matches the roster")
		check(not menu.relay_join_form.visible and not menu.relay_host.visible,"joined party hides redundant create/join controls")
		check(menu.relay_copy.visible and menu.relay_deploy.visible and menu.relay_leave.visible,"leader has copy, deployment and leave actions")
		var clipped:=false
		for row in menu.relay_roster.get_children():
			for label in row.find_children("*","Label",true,false):
				var rect: Rect2=label.get_global_rect()
				clipped=clipped or not menu.get_global_rect().grow(3).encloses(rect)
		check(not clipped,"roster names and roles stay inside the menu")
		if DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().size()>0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("party-%d.png"%resolution.x))
	preview.leader=2
	menu.refresh_online_room()
	check(not menu.relay_deploy.visible,"guest cannot choose the party deployment")
	relay.connected_room=""
	relay.room_size=0
	relay.status="Start or join a party."
	menu.show_page("Party")
	await settle()
	check(menu.relay_host.visible and menu.relay_join_form.visible and not menu.relay_copy.visible,"unjoined party shows create and code entry")
	menu.relay_code.grab_focus()
	menu.relay_code.text="QA"
	relay.changed.emit()
	await settle()
	check(menu.relay_code.has_focus() and menu.relay_code.text=="QA","live presence refresh preserves room-code typing and focus")
	relay.pending="join"
	menu.refresh_online_room()
	check(not menu.relay_code.editable and menu.relay_leave.visible,"connecting state offers cancellation and locks code entry")
	relay.relay=original
	relay.connected_room=""
	relay.pending=""
	relay.available=false
	preview.queue_free()
	game.queue_free()
	current_scene=null
	await process_frame
	await process_frame
	print("SOCIAL PARTY LAYOUT RESULT failures=",failures)
	quit(int(failures>0))
