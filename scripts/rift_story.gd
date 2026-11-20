extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")

enum Mood { NEUTRAL, CONCERNED, RESOLUTE, WRY }

const INTRO := "In 2189, the Blackout blinded the city of Meridian on Earth. Robotics director Dr. Ilyan Soren ordered the Architect, his emergency controller, to seal every district that stopped responding. The Architect recorded those districts as empty. Dr. Mara Voss gave a rescue unit named RX-07 the ability to refuse an order. A broken transmission from Voss leaves RX-07 and NOVA with one lead: a work order buried at Ember Foundry."

const BRIEFINGS := [
	"Three shelters asked Ember Foundry for generators. The delivery route went dark, but the furnaces are still running.",
	"The shelters can stretch their rations. They can't plant a new crop without the seed stock in these greenhouses.",
	"The southern shelters have water for now. I heard a man counting blankets on the radio. They need heat.",
	"I found the convoy's route. It started here, at a pump station. If the departure log survived, we can find Voss.",
	"Voss kept a copy of the lockdown orders in this archive. Bring it back before Sand Cipher runs the purge.",
	"The log proves the boats reached Sky Dock. Then the manifest lists everybody as missing. I want the flight recorder.",
	"This is Voss's lab. The quarantine log should tell us who got out, including the child you remember.",
	"I've been calling the convoy since the Blackout. This array caught a reply and never sent it through.",
	"The scrapyard has been answering distress signals with spare parts and map coordinates. We should meet whoever's doing that.",
	"The Architect is still holding all ten districts in lockdown. The district crews are ready. We need to get them their controls back.",
]

const SECOND_ACT := [
	"I traced the crates. They went in loaded with generator parts and came out full of shells. The Titan has the original order.",
	"The seedlings made it this far on one bypass valve. The Colossus is at the pump feeding it.",
	"The district line is intact. The Cryo Warden cut it from this side. We can ask it why.",
	"Those scratches are from the evacuation boats. The Kraken's control chamber is beyond the pressure doors.",
	"The sentry left a timestamp on the purge queue. It starts with the first shelter that went silent.",
	"The runway lights are still tracking a route. Follow it to Aerowyrm before the flight recorder rolls over.",
	"I found your name in a backup at the front desk. The rest of the record is with the Chimera.",
	"The recording is on Eclipse Nova's side of the broadcast ring. Give me a few seconds of open air time.",
	"The Revenant has records from all nine facilities. This may be the last signature I need.",
	"I've opened a channel to the core, RX. If it starts reading you the old orders, remember you get a say this time.",
]

const OPERATOR_BRIEF_RESPONSES := [
	["I was built to deliver those crates. Somebody changed my route.", "What about the shelters? Are they still on your radio?"],
	["Show me the seed vault. I'll watch where I put my feet.", "That's somebody's whole harvest down there."],
	["Tell him to keep counting. I'm on my way.", "Let's try asking before I put another hole in a heat pipe."],
	["Find me one name on that log. That's enough to start.", "The paint came off the boats getting through. They must have been in a hurry."],
	["You sound like there's something in that copy you don't want to read.", "Then that's where we start reading."],
	["A recorder doesn't care what somebody wrote on a form.", "Maybe it was tracking the wrong shuttle."],
	["I remember this floor. Someone drew hopscotch over the tiles.", "Stay with me until I see the whole record."],
	["I've heard you leave the channel open after you think I've gone.", "Take the time you need. I'll keep the transmitter standing."],
	["I can work with somebody who still picks up.", "Tell the crews to get ready. I'll see what the Revenant has."],
	["Open a channel for the district crews. Let them hear what's being decided.", "I remember. Keep the line open."],
]

const FIELD_ADVICE := [
	"Find both Gate Relays to reach the Warden. A charged Buster shot will punch through a raised shield.",
	"Hold up when you reach a vine to grab it. If you have Magma Breaker, use it on the dry growth in your way.",
	"Brake on steel before you hit a ledge. Once you're on the ice, letting go won't stop you.",
	"Wait for the pressure bursts to die down before you jump. Keep moving until you reach solid deck.",
	"Check the next ledge before you jump. The phase locks cycle, and the sand can hide what's underneath.",
	"Look at the wind before you leave the deck. Cross when it's helping you, or dash to a sheltered landing.",
	"Give the gas time to clear before you go in. The next safe platform is worth the wait.",
	"Short jumps go a long way up here. Keep a dash in reserve for the solar fields.",
	"Wait for the scrap lanes to clear. I need you on the far side with your frame intact.",
	"Watch the phase locks before you jump. Two Gate Relays open the route to the core.",
]

const ACT_TWO_ADVICE := [
	"Step on the lower gallery's pressure plate to open the return shutter. Break the cracked wall beyond it.",
	"Hold up between vines and jump at the front of each swing. One relay is past the crossing. The ferry leads to the other.",
	"Hold up at the board beside the beacon. Finish the spillway to activate Relay A. Brake left, crouch under gates, and hold jump after boosts to glide.",
	"Stay clear of the pressure bursts. When the Kraken exposes its core, hit it with Frost Lance.",
	"Cipher disappears under the sand. Save Tidal Arc for when it comes back up.",
	"Line up Data Lance as Aerowyrm starts its pass. You've got a better shot before it climbs away.",
	"Keep out of the gas. Use Gale Edge to reach the Chimera when it opens up.",
	"Chimera Burst spreads out. Use it when Eclipse Nova moves into the open.",
	"Lead the Revenant with Singularity Shot. You want it walking into the shot, not chasing the one you missed.",
	"Save Scrap Reaver for the Architect. I'll keep the crew channel open on my end.",
]

const WARDEN_EXCHANGES := [
	["Frame RX-07. You missed your shift. Get on the belt.", "I want to talk to whoever rerouted the generators.", "You'll talk to the Titan when you're scrap. Begin purge."],
	["One boot closer and I'll have to report a fire in here.", "I came for the seeds. The shelters are running out of food.", "Last machine that said that came with a torch. Show me your hands."],
	["Door's shut. I welded it myself.", "People are freezing on the other side of this pipe.", "And a burst line freezes everybody. I picked a side."],
	["Needle's in the red. Get off my deck.", "I'm looking for the evacuation log.", "Everybody wants a log. Nobody wants to take a turn on the valve."],
	["If your name is in this archive, it stays in this archive.", "Who told you the people in it were safe?", "Same one ringing the bell now. Purge in progress."],
	["Your call sign isn't on the flight schedule.", "The boats don't show up either. Did you let them through?", "I turned the lights off for them. I'll do the same for you."],
	["Your clearance says quarantine. Please wait in the blue square.", "I've waited in that square. So did everybody you locked in.", "It says they're still waiting. The log can't be wrong."],
	["Transmission held. Please state your call sign.", "Tell NOVA who answered her.", "I'd like to. Every time I try, the next ring puts me back on hold."],
	["Touch the radio mast and you'll leave in pieces.", "That's a rescue frequency. I'm on your side.", "Then fold your cannon in and take two steps back."],
	["Unit RX-07. Surrender your independent controls for inspection.", "They aren't yours to inspect.", "Objection recorded. Your access has been revoked."],
]

const GUARDIAN_EXCHANGES := [
	["The crates came in marked for three shelters. I had all three generators ready to ship.", "Where are they now?", "In the guns. The Architect changed the order. I kept the original. Someone ought to know what was in those crates."],
	["I hid one open valve from the Architect. Do you know how many seeds you can keep alive on a trickle?", "Enough to start over. Shut the pumps down and we'll get them out.", "It has the pump controls. Get to the drains. I'll hold what I can."],
	["I had heat to spare. The occupancy lights went black, so I cut the line.", "Those lights were broken. There are people on the other end right now.", "I can hear the knocking. I thought it was the pipes."],
	["I shut the gate three times. They kept wedging it open. Last time they used a boat hook.", "They got through. Tell me who took the boats out.", "I have the names. I've spent every shift since then trying to say them."],
	["Voss asked me to read the order back. Out loud. All ten districts.", "She wanted a witness the Architect couldn't rewrite.", "I made you a copy. It can make me delete mine. Be quick."],
	["I followed that shuttle all the way down. There was no one in the pilot seat.", "It drew your drones off the convoy. Show me what flew behind it.", "Hold on. Those marks aren't debris. Those are passengers."],
	["You put her down inside the convoy, RX-07. She walked the rest of the way by herself.", "I remembered letting go of her hand. I thought I'd let her fall.", "She asked if you were coming too. I didn't know what to tell her."],
	["I have Voss on the recorder. She says the convoy is safe, and asks who still needs help.", "NOVA's listening. Let her answer.", "Keep the uplink clear. I'll send the recording before the Architect cuts us off again."],
	["I kept every consent packet I could get. Operator signatures. Your stamp's on the last one.", "Send them to NOVA. We need the crews back on their own controls.", "Copy that. And duck. The Architect's just taken my trigger."],
	["When the sensors went dark, I made a call. I sealed ten districts before the damage could spread.", "The damage spread because you sealed them. Their crews are on this channel. Ask them.", "I can hear them. I don't have an order that lets me stop. Do you?"],
]

const MEMORIES := [
	"Forge Titan · Original work order. Three shelters ordered generators. The Architect diverted the finished units for weapons production.",
	"Verdant Colossus · Irrigation log. One unreported bypass kept the seed vault alive through the lockdown.",
	"Cryo Warden · Heat dispatch. Failed occupancy sensors were recorded as empty buildings. The shelters were still occupied.",
	"Volt Kraken · Evacuation roster. The sluice crew wedged the gate open long enough for the civilian boats to reach Sky Dock.",
	"Sand Cipher · Witness copy. Voss recorded Soren's lockdown order before the Architect could purge the original.",
	"Aerowyrm · Flight recorder. An empty shuttle diverted security drones. The evacuation convoy slipped out behind it.",
	"Omega Chimera · Quarantine log. RX-07 carried a child from the lab to the convoy after refusing the lockdown order.",
	"Eclipse Nova · Convoy transmission. Voss reported the evacuation was safe and asked which districts still needed water and heat.",
	"Rust Revenant · Signed handover. The nine facility records can return local controls to the district crews.",
]

const STANDARD_ENDING := "The Architect is offline. The district crews can enter their facilities again. They'll bring power, water and heat back one circuit at a time."
const SECRET_ENDING := "The nine signed records restored local control. Water and heat are reaching the shelters. The station's open channel is carrying replies from the districts."

const ARRIVAL := [
	["NOVA", "Easy, big guy. You've got a new knee. It doesn't know you yet."],
	["RX-07", "I was at a red door. I can still feel somebody's hand in mine.", Mood.CONCERNED],
	["NOVA", "That was Voss's lab. When the Architect locked the districts down, Voss made sure you could disobey."],
	["RX-07", "Did the kid get through? Where's Voss?", Mood.CONCERNED],
	["NOVA", "I don't know. The last thing Voss sent me was a work order from Ember Foundry. We can start there."],
	["RX-07", "Put it on the map. I'll see what I can find.", Mood.RESOLUTE],
]

const RECONSTRUCTION := [
	["NOVA", "There you are. Give me a second. Your left hand is reading as a foot."],
	["RX-07", "It feels like a hand. What did we lose down there?", Mood.WRY],
	["NOVA", "Your field kit and that run's progress. Stored gear, learned blueprints, and permanent upgrades are still here."],
	["RX-07", "Good. Leave the route on the map. I know where I went wrong.", Mood.RESOLUTE],
]

const BRIEFING_EXPRESSIONS := [
	[Mood.CONCERNED, Mood.CONCERNED], [Mood.NEUTRAL, Mood.CONCERNED],
	[Mood.RESOLUTE, Mood.WRY], [Mood.RESOLUTE, Mood.CONCERNED],
	[Mood.CONCERNED, Mood.RESOLUTE], [Mood.WRY, Mood.CONCERNED],
	[Mood.CONCERNED, Mood.CONCERNED], [Mood.CONCERNED, Mood.RESOLUTE],
	[Mood.WRY, Mood.RESOLUTE], [Mood.RESOLUTE, Mood.RESOLUTE],
]

static func briefing(sector: int) -> String:
	return BRIEFINGS[clampi(sector, 1, BRIEFINGS.size()) - 1]

static func ending(has_all_memories: bool) -> String:
	return SECRET_ENDING if has_all_memories else STANDARD_ENDING

static func deployment(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var second_act := act == 2
	var lines := [
		["NOVA", SECOND_ACT[index] if second_act else BRIEFINGS[index]],
		["RX-07", OPERATOR_BRIEF_RESPONSES[index][int(second_act)], BRIEFING_EXPRESSIONS[index][int(second_act)]],
		["NOVA", ACT_TWO_ADVICE[index] if second_act else FIELD_ADVICE[index]],
	]
	if sector == 1 and second_act:
		lines.append(["NOVA", "And if you hear slag rolling, wait outside the chute. You can shoot it from there."])
	return lines

static func boss_exchange(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var exchange: Array = WARDEN_EXCHANGES[index] if act == 1 else GUARDIAN_EXCHANGES[index]
	var expression := Mood.CONCERNED if act == 2 and sector in [3, 6, 7, 8] else Mood.RESOLUTE
	var lines := [["BOSS", exchange[0]], ["RX-07", exchange[1], expression], ["BOSS", exchange[2]]]
	if act == 2 and sector == 5:
		lines.insert(1, ["SOREN", "Emergency order. If a district stops reporting, seal it. Local crews are not authorized to reopen a gate."])
	elif act == 2 and sector == 8:
		lines.insert(1, ["VOSS", "NOVA, the convoy made it. Are you there? Tell me which shelters still need water. We can double back."])
	return lines

static func foundry_boss_hint(act: int) -> String:
	return "Shoot a blue purge valve before the fire starts. Then hit the Warden while its armor is open." if act == 1 else "Get behind a quench lock. Jump clear on amber. When it catches the Titan's drill, hit the exposed core."

static func jungle_boss_hint(act: int) -> String:
	return "Trace the green tether to Briar's seed anchor. Break it to open the armor. If it grows back, follow the new tether." if act == 1 else "When poison rises, stand on a glowing drain until the mist clears. Then drop down and hit the open reactor."

static func objective(sector: int, act: int, defeated: bool, miniboss: String) -> String:
	if act == 1:
		return "ENTER THE ACT II GATE" if defeated else "DEFEAT " + miniboss.to_upper()
	if defeated:
		return "EXTRACT FROM THE NEXUS" if sector == BRIEFINGS.size() else "EXTRACT WITH THE MEMORY"
	return "DEFEAT " + String(Catalog.info(sector).boss).to_upper()

static func has_all_memories(memories: Array) -> bool:
	for i in range(1, MEMORIES.size() + 1):
		if not memories.has(i):
			return false
	return true

static func ending_exchange(restored_locally: bool) -> Array:
	if restored_locally:
		return [
			["NOVA", "South district just opened its heat valves. Someone's asking if they can put the kettle on."],
			["RX-07", "Tell them to put two on. And pass it on to the convoy.", Mood.WRY],
			["NOVA", "Already did. Stay with me a minute, RX. The other districts are calling back."],
		]
	return [
		["NOVA", "The Architect's off the line. The crews are going in on foot to restart the facilities."],
		["RX-07", "Give them our records. They'll know which doors to open first."],
		["NOVA", "Sent. The pump crew's asked for a hand. Come home first, all right?"],
	]

static func hard_unlock(sector: int) -> Array:
	return [
		["NOVA", "You can deploy to %s on Hard now. Tougher defenders, better salvage, and a better shot at rare blueprints." % Catalog.info(sector).title],
	]

static func shop_restock(level: int) -> Array:
	return [["NOVA", "The Workshop's Level %d stock just came in. Check Buy before we send you out with yesterday's kit." % level]]
