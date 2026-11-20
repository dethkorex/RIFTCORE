extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")

enum Mood { NEUTRAL, CONCERNED, RESOLUTE, WRY }

const GUIDE := "NOVA_GUIDE"
const TUTORIAL_TITLE := "Field Tutorial"

const INTRO := "Meridian, Earth, 2189. When the Riftcore fractured, Director Soren kept the Nexus alive by cutting power to the districts. He called it a temporary sacrifice. Dr. Mara Voss built RX-07 to carry power between failing districts until they could share the load again. When Voss vanished during the evacuation, she left her little relay drone NOVA a trail through Meridian's industrial sectors. It starts with a stolen shipment at Ember Foundry."

const BRIEFINGS := [
	"Three shelter generators left Ember Foundry on paper. I checked the loading bays. The crates never left. Somebody signed them over to the Nexus.",
	"The Titan's dispatch log shows where the rest of the power went. Machine Jungle got a trickle. Enough to keep the security drones awake. Not enough to water a seed.",
	"South District says the taps froze last night. The reactor is still making heat. It's sending every degree it can spare back to the Nexus.",
	"Voss's call came through over the sound of a flood siren. These pumps used to hold the river back. Somebody told the Kraken to flood the escape channel.",
	"Voss left a note in the boat roster. Soren's public order and the one he actually sent are both in this archive. She wants us to hear them side by side.",
	"Now we know Soren kept the load on the Nexus on purpose. Voss's boats made it as far as Sky Dock. Their tags went dark right under the control tower.",
	"Flight recorder says the convoy got away. I found something else in it. The Nexus filed a claim on your core the night you were built.",
	"Your core kept the sluice from collapsing at the gate. The Biolab log has the convoy's real call sign. I've found a reply in the array's hold queue.",
	"Voss named Rust Revenant in her message. He used to repair the district regulators. He's kept copies of the crews' control records in the scrapyard.",
	"Every district can help take the load now. The Nexus has cut their controls again. The Architect thinks the city will collapse the moment we touch its supply.",
]

const SECOND_ACT := [
	"The Warden sent the generators to Forge Titan. The Titan's a rolling load regulator. They put a drill on him and told him to tear up the old district lines.",
	"Found a bypass under Briar's roots. Verdant Colossus has been keeping one nursery alive on the water the Nexus didn't notice.",
	"The heat mains are fine. Cryo Warden shut them by hand. It would rather freeze the shelter inlet than risk one more surge going down that line.",
	"The diver marked a gate they wedged open for the boats. The Kraken's still holding the sluice under pressure. The convoy roster's in its control room.",
	"The purge started when we entered. Sand Cipher has the only witness copy with Soren's voice on it. Everything else is a rewritten transcript.",
	"Aerowyrm's recorder has the last two flights of the night. Both carry the same tracking tag. Let's hear which one it actually chased.",
	"Chimera has Voss's first six core tests and the last log from your frame. If you want me to hold off playing it, say so now.",
	"Eclipse Nova has Voss's reply trapped in the broadcast ring. It keeps bouncing the packet back to itself. Get me close enough to pull it straight from the buffer.",
	"Revenant left a test signal on the maintenance frequency. If we get the signed backups, the crews can take back their equipment without a citywide shutdown.",
	"Soren's emergency order is still running in the core. The crews are ready on nine separate lines. The moment you're through, I'll put every one of them on his channel.",
]

const OPERATOR_BRIEF_RESPONSES := [
	["If those crates are still here, I'm taking them back.", "Then we take his regulator. Let the foundry crew see what it was built to do."],
	["Ask the growers how much power they need. I'll see what I can get them.", "Tell them to keep the bypass open. I'll find the pump that feeds it."],
	["I can take some of the pressure. Tell the shelter to stay on the radio.", "Patch the crew through. Let the Warden hear who it's cutting off."],
	["Start with the log. I want to know who opened those gates for her.", "Get the names out as soon as we have them. Someone will be waiting."],
	["Let the people in the shelters hear what he told the Architect.", "Keep your receiver open. I'll send the original."],
	["Then somebody turned those tags off for a reason.", "I'll keep Aerowyrm busy. Watch where those flights went."],
	["What does the Nexus want with a rescue frame?", "Play it. I've had the sound of that gate in my head since you woke me up."],
	["Did we get Voss's voice this time?", "I'll keep the link clear. Get her message somewhere it can't be cut."],
	["Call the crews. Tell them where we'll send their records.", "Get them ready to take their stations. I'm bringing their controls back."],
	["If we pull the plug without a backup, it's right. Get the crews on the line.", "The core has been carrying the city alone for long enough. I'm ready."],
]

const FIELD_ADVICE := [
	"Activate both Gate Relays to unlock the Warden's door. Hold and release Buster to fire through a purple shield.",
	"Hold Up to grab a vine. Jump near the front of the swing to carry your speed into the next landing.",
	"Brake on steel to take the upper route. For the lower route, keep your speed on the ice and jump before the edge.",
	"Ride the blue currents up. Wait out electrical surges on the amber-edged ceramic decks.",
	"Watch a full phase cycle. Jump so the next platform is solid when you land.",
	"Wait for the wind to favor your crossing. Save your air dash for the last stretch to a sheltered deck.",
	"Wait for the gas to clear, then jump to the next safe platform before it returns.",
	"Low gravity carries you farther. Tap Jump for a short hop and save your air dash for the solar fields.",
	"Watch where the scrap crosses the route. Move through when the lane clears.",
	"Time your jumps around the phase locks. Activate both Gate Relays to reach the core.",
]

const ACT_TWO_ADVICE := [
	"Step on the lower gallery's pressure plate to open the return shutter. Break the cracked wall beyond it.",
	"Jump near the front of the swing to reach the high vine. Use the low leaf to line up the last grab. One relay is past the crossing. The ferry leads to the other.",
	"Hold Up beside the board. Jump floor spikes and crouch under overhead spikes. Hold Jump after boost pads to glide across long gaps. The exit activates Relay A.",
	"Hold Interact at each of the three pressure valves. Wait for the pressure to drop to zero before heading through the release lock.",
	"When Cipher dives under the sand, move clear. Use Tidal Arc when it surfaces.",
	"Fire Data Lance as Aerowyrm lines up a pass, before it climbs out of reach.",
	"Stay clear of the gas. Use Gale Edge when you have a clear shot at Chimera.",
	"Wait until Eclipse Nova moves into the open before firing Chimera Burst.",
	"Aim Singularity Shot ahead of Revenant so it walks into the projectile.",
	"Use Scrap Reaver when you have a clear line to the Architect.",
]

const WARDEN_EXCHANGES := [
	["Last truck out left on the night of the Blackout. The bays are sealed.", "Three shelters are waiting on those generators. Where are they?", "Upstairs. New destination was printed before the paint on the crates dried."],
	["I keep the seedlings alive. That's the only order I still take.", "Good. Show me the pump before the roots dry out.", "Get off that pipe. They're drawing water through it right now."],
	["I welded this door shut for a reason. The heat line buckles every time it opens.", "The south shelters are freezing. I can carry the surge if you let me through.", "The last crew said they could carry it. I had to weld the door myself."],
	["The pumps are above their limit. Get off my deck.", "I'm looking for the convoy that went through here when the water came up.", "Look in the gate log. The crew pulled that lever by hand."],
	["I have orders to delete the audio and keep the transcript.", "Whose voice is on it?", "Soren's. The original's in Cipher's vault. The copy you've heard has pieces missing."],
	["Flight clearance suspended. Identify yourself.", "RX-07. Voss sent boats to this dock. What did you launch?", "We launched everyone we could. I turned the runway lights off so they could leave."],
	["Stand behind the yellow line. Visitors may contaminate the test.", "I was built here. Who locked the file on my core?", "Director Soren. He put in the transfer request before you came online."],
	["The broadcast ring is full. No new messages will go through.", "I'm looking for the reply you held from Voss.", "I heard her answer days ago. Try the uplink before the ring cycles."],
	["Put the cannon down. I need that antenna above you to stay in one piece.", "We're here for the district control records. Voss sent us.", "Revenant has a bench on the maintenance frequency. Let him finish talking before you grab anything."],
	["Independent regulator detected. Transfer to central control is overdue.", "Tell the Architect the district crews are here to take the load.", "Request denied. The core has enough reserve for one more transfer."],
]

const GUARDIAN_EXCHANGES := [
	["I built three generators. The Nexus ordered me to melt them down and cut the district feeders.", "Those shelters asked you for help. Give me the route they made you cut.", "It's in the work order. Watch my drill. It hasn't been mine since the lockdown."],
	["I've been feeding the seedlings on one valve. They'll die if I open it any further.", "Shut the poisoned feed. I can hold the pump steady.", "The Nexus took my controls. Look for the drains when it opens the flood line."],
	["I heard the pipe buckle. I closed the valve, and everything went quiet.", "Listen to this. Those knocks are the shelter crew. They're on the other side.", "I can hear them. Stand back. The Nexus just overrode my valve."],
	["I closed that sluice three times. They wedged it back open with a boat hook.", "Voss was with them. How far did they get?", "Sky Dock. Her name is in the log. I logged you too. Last one in the water."],
	["He sent two versions of that order. Voss asked me to save the one he actually gave.", "Send that recording to every district that still has a radio.", "I can make you a copy. The purge is in the room with us."],
	["I followed that shuttle till it burned out. I thought I'd killed the convoy.", "That cockpit was empty. Look at the boats behind it.", "They made it through. If you've got their tags, you can still call them."],
	["Soren wanted you hardwired into the Nexus. Voss built your core to carry the load and hand it back to the crews.", "Is that what I did at the gate? I remember my arms giving out.", "You held it until every boat cleared. The last person you lifted aboard kept asking for you."],
	["She keeps sending the same reply. I kept one copy before the ring could wipe it.", "NOVA, get her voice out of here. I'll hold the uplink open.", "I can clear the channel when the ring slows. Until then, keep moving."],
	["I used to tune those regulators with the crews standing next to me. I kept what they signed.", "Send the signatures to NOVA. It's time the crews had their stations back.", "Sending. Get behind something. The Nexus just put my own trigger out of reach."],
	["When the Riftcore cracked, I shed nine districts to keep one feed alive. Disconnect me and the city goes dark.", "The crews are on this channel. Let them draw together, and I'll carry the surge.", "I have orders to preserve the Nexus. The district lines are locked under my control."],
]

const MEMORIES := [
	"Forge Titan · The original shipment log ties the stolen shelter generators to Soren's order to cut the district feeders.",
	"Verdant Colossus · The nursery log shows a local bypass kept the seed vault alive on power the Nexus had written off.",
	"Cryo Warden · The shelter crew's calls prove the south heat line was intact and occupied when the cutoff went through.",
	"Volt Kraken · The sluice record places Voss aboard the convoy and RX-07 at the gate when the flood reached it.",
	"Sand Cipher · Soren ordered the Architect to mark occupied districts as expendable and lock the crews out.",
	"Aerowyrm · Voss hid the evacuation convoy behind an empty shuttle with the same tracking tag.",
	"Omega Chimera · Voss built RX-07 as a mobile regulator, with a core that can carry a failing circuit until its load can be shared.",
	"Eclipse Nova · Voss is alive. The convoy's district crews can return as soon as they have power and control of the docks.",
	"Rust Revenant · The signed handover records give the district crews the authority to take back their regulators.",
]

const STANDARD_ENDING := "The Architect's lock is broken. RX-07 held the damaged grid long enough for the crews to bring it back district by district. The docks have power. Voss's convoy is coming home."
const SECRET_ENDING := "The nine handover records let the crews take the Riftcore's load together. No sector had to go dark for another to stay lit. Voss's convoy is coming home to a city the districts run again."

const ARRIVAL := [
	["NOVA", "RX? Your core's steady. Try opening your hand. Last time I saw you, it was still holding the floodgate."],
	["RX-07", "I remember the boats. The sound stopped all at once. Did Voss make it?", Mood.CONCERNED],
	["NOVA", "I got one packet from her. Three shelter generators were diverted from Ember Foundry. She sent the manifest right before her transmitter cut out."],
	["RX-07", "Then start there. Give the shelter crews our channel. If the power shifts, I need to hear it from them.", Mood.RESOLUTE],
	["NOVA", "Already listening. One of them wants me to tell you the lights have been out for two nights. We can start with those."],
]

const RECONSTRUCTION := [
	["NOVA", "You're back at the station. I had to rebuild your field frame."],
	["RX-07", "What did we bring back?", Mood.CONCERNED],
	[GUIDE, "Your Operator Level is back to 1. You lost your equipped gear and loot from the run. Your stored gear, learned recipes, Profile XP and permanent upgrades are safe."],
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

static func deployment(sector: int, act: int, tell_story := true, teach := true) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var second_act := act == 2
	var lines := []
	if tell_story:
		lines.append(["NOVA", SECOND_ACT[index] if second_act else BRIEFINGS[index]])
		lines.append(["RX-07", OPERATOR_BRIEF_RESPONSES[index][int(second_act)], BRIEFING_EXPRESSIONS[index][int(second_act)]])
	if teach:
		lines.append([GUIDE, ACT_TWO_ADVICE[index] if second_act else FIELD_ADVICE[index]])
		if sector == 1 and second_act:
			lines.append([GUIDE, "If you hear slag rolling, wait outside the chute. You can shoot the boulder from there."])
	return lines

static func boss_exchange(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var exchange: Array = WARDEN_EXCHANGES[index] if act == 1 else GUARDIAN_EXCHANGES[index]
	var expression := Mood.CONCERNED if act == 2 and sector in [3, 6, 7, 8] else Mood.RESOLUTE
	var lines := [["BOSS", exchange[0]], ["RX-07", exchange[1], expression], ["BOSS", exchange[2]]]
	if act == 2 and sector == 5:
		lines.insert(1, ["SOREN", "Cut the district feeds. Log them as empty and lock out their crews. If the city asks, tell them the sensors failed."])
	elif act == 2 and sector == 8:
		lines.insert(1, ["VOSS", "NOVA, we made it. I have crews from all nine districts aboard. Get the docks back and we'll come home. RX, the city can still carry the load together."])
	elif act == 2 and sector == BRIEFINGS.size():
		lines.insert(1, ["SOREN", "I can keep one district alive. If those crews get it wrong, I lose the last one too."])
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
			["NOVA", "Nine lines. Nine crews. They're taking the load together. You can step off the grid now."],
			["VOSS", "RX, I can see the docks from out here. Every light's on. Even the little one by the floodgate."],
			["RX-07", "Leave that one on. I'd like to be there when you land.", Mood.WRY],
		]
	return [
		["NOVA", "We broke the lock. The crews still have to bring the grid back by hand."],
		["RX-07", "Tell them I'll hold the first line. They can bring the rest back one at a time.", Mood.RESOLUTE],
		["VOSS", "The runway just lit up. I'm bringing the crews home, RX. They'll take it from here."],
	]

static func hard_unlock(sector: int) -> Array:
	return [
		["NOVA", "Hard difficulty is unlocked for %s. Choose it at Deploy for tougher enemies and better odds of rare blueprints." % Catalog.info(sector).title],
	]

static func shop_restock(level: int) -> Array:
	return [[GUIDE, "You unlocked new Workshop stock at Operator Level %d. Open Buy to see the new supplies and materials." % level]]
