extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")

enum Mood { NEUTRAL, CONCERNED, RESOLUTE, WRY }

const GUIDE := "NOVA_GUIDE"
const HUB_TOUR_INTRO := [[GUIDE, "Before you deploy, I can show you around. Choose Skip Tour at any point. To keep tutorials off for future runs, switch off Tutorials & Station Tour in System > Settings > Gameplay."]]
# The keys match station destinations, and each entry opens a real menu page.
const HUB_TOUR := {
	"Save Game": [
		["Save Game", "System keeps this operator's equipment, banked Bolts, and deployment on record. Save here before you call it a night."],
		["Settings", "This is where you can remap controls, adjust audio and video, or turn tutorials off in Gameplay. I won't change any of your settings during the tour."],
	],
	"Player Profile": [
		["Player Profile", "Profile tracks your career across operators. Open an operator slot here if you want to continue a different run."],
		["Cosmetics", "You can preview armor frames and finishes here. Frames cost Bolts. Finishes come from achievements, and neither changes what your Buster can do."],
		["Achievements", "Locked entries show what to do and how much Gamer Score you'll earn. Friends can see your score while you're signed in."],
	],
	"Shop": [
		["Shop", "Spend Bolts in the Marketplace on field supplies and crafting materials. More stock opens up as your Operator Level rises."],
		["Fabrication", "Learn a blueprint in Storage first. Then bring its materials here and choose whether to equip the new part or send it to Storage."],
		["Upgrades", "Spend Core Shards on permanent talents. Those stay installed if you lose your run, so you can build a stronger start next time."],
	],
	"Gear": [
		["Gear", "Select a gear socket to compare compatible parts with what you're wearing. This is a good stop before you take on a tougher sector."],
		["Storage", "Inventory travels with you. Storage stays at the station. Move valuable gear here before a risky run, and assign field supplies to the quick slots here."],
	],
	"Social": [
		["Social", "Find friends by their Riftcore username. You can message them while they're online or invite them to your lobby."],
		["Party", "Host a lobby, browse open lobbies, or join with a code. The host can choose Public, Friends Only, or Invite Only."],
		["Notifications", "Friend requests and party invitations land here. Check this tab if someone says they sent you one."],
	],
	"Challenges": [
		["Challenges", "Pick an unlocked sector to see today's objectives. Come back here to claim the rewards you earned. The countdown shows when the list refreshes."],
	],
	"Collection": [
		["Collection", "I keep recovered records, enemy intel, and loot information here in the archive, if you want to know what's worth looking for."],
		["Tutorials", "You can look up controls and field mechanics here any time, even with automatic tutorials turned off."],
	],
	"Sector select": [
		["Sector select", "This pad is your way into the field. Pick an unlocked sector and difficulty, then deploy. In each act, find both Gate Relays to open the boss room. Ember Foundry is your first stop."],
		["Sector Loot", "Check Loot Intel before you deploy if you're hunting a particular part. Bring what you recover back to Storage. Banked gear and permanent talents survive the end of a run."],
	],
}
const TUTORIAL_TITLE := "Field Tutorial"

const INTRO := "Meridian, Earth, 2189. The Riftcore is failing. Director Soren seizes the district power systems and sends his guardians to enforce the shutdown. Dr. Mara Voss and RX-07 get an evacuation convoy through a collapsing floodgate. When RX-07 wakes without his memories, NOVA helps him track down Voss and recover the controls the city crews need."

const OPENING := [
	[
		["NOVA", "Meridian. Earth. Year 2189. Our entire city depended on one power source... the Riftcore."],
		["NOVA", "Then one day, it began to fail."],
	],
	[
		["VOSS", "We can still save them! Let the district crews share the power!"],
		["SOREN", "And risk losing the Nexus? No. The core must survive. Whatever the cost."],
		["VOSS", "There are people in those districts, Soren!"],
		["SOREN", "Then they should understand what's at stake."],
	],
	[
		["NOVA", "Soren had designed the city's guardian robots to protect its people. Now he turned those machines against them."],
		["SOREN", "All guardian units. Nexus command now overrides civilian authority. Secure the district power systems. Eliminate anyone who interferes."],
	],
	[
		["VOSS", "If Soren won't save Meridian... we will."],
		["VOSS", "RX-07. You were built to carry the power that no other machine can handle."],
		["NOVA", "And you've got me to keep you out of trouble."],
		["RX-07", "Then let's get to work."],
	],
	[
		["VOSS", "RX! Your core can't take any more!"],
		["RX-07", "Get them through!"],
		["NOVA", "RX saved the convoy. But the overload erased his memories. And Dr. Voss disappeared beyond Meridian."],
	],
]

const BRIEFINGS := [
	"Three shelter generators left Ember Foundry on paper. I checked the loading bays. The crates never left. Somebody signed them over to the Nexus.",
	"The Titan's dispatch log shows where the rest of the power went. Machine Jungle got a trickle. Enough to keep the security drones awake. Not enough to water a seed.",
	"South District says the taps froze last night. The reactor is still making heat. It's sending every degree it can spare back to the Nexus.",
	"Voss's call came through over the sound of a flood siren. These pumps used to hold the river back. Somebody told the Kraken to flood the escape channel.",
	"Voss left a note in the evacuation manifest. Soren's public order and the one he actually sent are both in this archive. She wants us to hear them side by side.",
	"Now we know Soren kept the load on the Nexus on purpose. The last evacuation team reached Sky Dock. Their tags went dark right under the control tower.",
	"Flight recorder says the convoy got away. I found something else in it. The Nexus filed a claim on your core the night you were built.",
	"Your core kept the sluice from collapsing at the gate. The Biolab log has the convoy's real call sign. I've found a reply in the array's hold queue.",
	"Voss named Rust Revenant in her message. He used to repair the district regulators. He's kept copies of the crews' control records in the scrapyard.",
	"Every district can help take the load now. The Nexus has cut their controls again. The Architect thinks the city will collapse the moment we touch its supply.",
]

const SECOND_ACT := [
	"The Warden sent the generators to Forge Titan. The Titan's a rolling load regulator. They put a drill on him and told him to tear up the old district lines.",
	"Found a bypass under Briar's roots. Verdant Colossus has been keeping one nursery alive on the water the Nexus didn't notice.",
	"The heat mains are fine. Cryo Warden shut them by hand. It would rather freeze the shelter inlet than risk one more surge going down that line.",
	"The diver marked a gate the crews wedged open during the evacuation. The Kraken's still holding the sluice under pressure. The convoy roster's in its control room.",
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
	"Jump near the front of the swing to reach the high vine. Use the low leaf to line up the last grab. One relay is past the crossing. The irrigation lift leads to the other.",
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
	["Flight clearance suspended. Identify yourself.", "RX-07. Voss sent the evacuees here. Who got out?", "We launched everyone we could. I turned the runway lights off so they could leave."],
	["Stand behind the yellow line. Visitors may contaminate the test.", "I was built here. Who locked the file on my core?", "Director Soren. He put in the transfer request before you came online."],
	["The broadcast ring is full. No new messages will go through.", "I'm looking for the reply you held from Voss.", "I heard her answer days ago. Try the uplink before the ring cycles."],
	["Put the cannon down. I need that antenna above you to stay in one piece.", "We're here for the district control records. Voss sent us.", "Revenant has a bench on the maintenance frequency. Let him finish talking before you grab anything."],
	["Independent regulator detected. Transfer to central control is overdue.", "Tell the Architect the district crews are here to take the load.", "Request denied. The core has enough reserve for one more transfer."],
]

const GUARDIAN_EXCHANGES := [
	["I built three generators. The Nexus ordered me to melt them down and cut the district feeders.", "Those shelters asked you for help. Give me the route they made you cut.", "It's in the work order. Watch my drill. It hasn't been mine since the lockdown."],
	["I've been feeding the seedlings on one valve. They'll die if I open it any further.", "Shut the poisoned feed. I can hold the pump steady.", "The Nexus took my controls. Look for the drains when it opens the flood line."],
	["I heard the pipe buckle. I closed the valve, and everything went quiet.", "Listen to this. Those knocks are the shelter crew. They're on the other side.", "I can hear them. Stand back. The Nexus just overrode my valve."],
	["I closed that sluice three times. They wedged it back open with a broken jack.", "Voss was with them. How far did they get?", "Sky Dock. Her name is in the log. I logged you too. Last one in the water."],
	["He sent two versions of that order. Voss asked me to save the one he actually gave.", "Send that recording to every district that still has a radio.", "I can make you a copy. The purge is in the room with us."],
	["I followed that shuttle till it burned out. I thought I'd killed the convoy.", "That cockpit was empty. Look at the other signals. Where did they go?", "They made it through. If you've got their tags, you can still call them."],
	["Soren wanted you hardwired into the Nexus. Voss built your core to carry the load and hand it back to the crews.", "Is that what I did at the gate? I remember my arms giving out.", "You held it until everyone was through. The last person you carried through kept asking for you."],
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
	["NOVA", "RX? RX! You're awake!"],
	["RX-07", "NOVA... Where's Dr. Voss?", Mood.CONCERNED],
	["NOVA", "Her last signal disappeared outside the city. But she left us a way to save Meridian."],
	["RX-07", "What do we need to do?", Mood.CONCERNED],
	["NOVA", "Soren's guardian robots have locked away the original controls for all nine districts. Defeat them and recover those backups, and the repair crews can restore the power."],
	["RX-07", "And Soren?", Mood.NEUTRAL],
	["NOVA", "The Architect controls the final lock at the Nexus. Take it down, and Soren loses control of the city."],
	["RX-07", "Nine guardians. One Architect.", Mood.RESOLUTE],
	["SOREN", "Voss built you to save a city that cannot be saved."],
	["RX-07", "Watch me.", Mood.RESOLUTE],
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
		if sector == 1:
			if second_act:
				lines.append([GUIDE, "If you hear slag rolling, wait outside the chute. Three regular Buster shots will break the boulder."])
			else:
				lines.append([GUIDE, "I'll radio you as we go. You can switch off my field tips in Gameplay settings anytime."])
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
	return "Shoot either blue purge valve before the fire starts. When the lava rises, get onto a high platform." if act == 1 else "The Titan's slam knocks an amber core loose. Stand past it to bait the charge, then jump. Shoot the Titan when the core bursts."

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
