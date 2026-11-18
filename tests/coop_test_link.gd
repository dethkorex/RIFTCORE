extends Node
## Test-only application-message impairment; never alters the machine's network.
var real_peer: Node
var latency_ms := 0
var jitter_ms := 0
var loss_percent := 0
var blacked_out_until := 0
var sent := 0
var dropped := 0
var delivered := 0
var queue: Array = []
var reliable_deadline := 0
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 63520

func get_client_id() -> int: return real_peer.get_client_id()
func get_host() -> int: return real_peer.get_host()
func get_sender_id() -> int: return real_peer.get_sender_id()
func lobby_get_all_clients() -> Array: return real_peer.lobby_get_all_clients()
func player_get_data(id: int,key: String,fallback=null): return real_peer.player_get_data(id,key,fallback)
func expose_func(method: Callable) -> void: real_peer.expose_func(method)

func enqueue(method: String, reliable: bool, args: Array) -> void:
	while args.size()>0 and args[-1]==null:
		args.pop_back()
	sent += 1
	if not reliable and (Time.get_ticks_msec()<blacked_out_until or random.randi_range(1,100)<=loss_percent):
		dropped += 1
		return
	var due := Time.get_ticks_msec()+latency_ms+random.randi_range(0,jitter_ms)
	if reliable:
		due = maxi(due,maxi(blacked_out_until,reliable_deadline))
		reliable_deadline = due
	queue.append([due,method,args.duplicate(true)])

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var i := 0
	while i<queue.size():
		if queue[i][0]<=now:
			var packet: Array = queue[i]
			queue.remove_at(i)
			real_peer.callv(packet[1],packet[2])
			delivered += 1
		else:
			i += 1

func call_func(f:Callable,a=null,b=null,c=null,d=null,e=null,g=null,h=null,i=null,j=null,k=null,l=null,m=null) -> void:
	enqueue("call_func",true,[f,a,b,c,d,e,g,h,i,j,k,l,m])
func call_func_unreliable(f:Callable,a=null,b=null,c=null,d=null,e=null,g=null,h=null,i=null,j=null,k=null,l=null,m=null) -> void:
	enqueue("call_func_unreliable",false,[f,a,b,c,d,e,g,h,i,j,k,l,m])
func call_func_on(id:int,f:Callable,a=null,b=null,c=null,d=null,e=null,g=null,h=null,i=null,j=null,k=null,l=null,m=null) -> void:
	enqueue("call_func_on",true,[id,f,a,b,c,d,e,g,h,i,j,k,l,m])
func call_func_on_unreliable(id:int,f:Callable,a=null,b=null,c=null,d=null,e=null,g=null,h=null,i=null,j=null,k=null,l=null,m=null) -> void:
	enqueue("call_func_on_unreliable",false,[id,f,a,b,c,d,e,g,h,i,j,k,l,m])
