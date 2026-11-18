extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")

const INTRO := "In 2189, the city's emergency AI cut ten districts off from its network. In the silence, it marked every one of them empty. Dr. Mara Voss rewrote one of its machines so it could refuse an order. That machine was you."

const BRIEFINGS := [
	"The Foundry was making generators for the shelters. Now it's melting them down and casting weapons. I need the Titan's original work order.",
	"These greenhouses can feed whole districts. The Colossus sealed them during the Blackout, but something is still drawing water.",
	"If we can learn why the reactor stopped heating the city, the crews might be able to bring it back without touching the Architect's network.",
	"The plant is keeping water behind a pressure lock. Follow the pipes to the sluice where the last evacuation boats got through.",
	"Voss hid a copy of the Blackout records here. Sand Cipher can still wipe the archive. We need its copy before the next purge.",
	"I found an evacuation manifest with every passenger crossed out. The flight recorder at Sky Dock can tell us where they really went.",
	"This was Voss's lab. The quarantine doors went down with people inside. Find the admission log and we'll know who made it out.",
	"I've sent a hundred calls since the Blackout. This array recorded one answer and never forwarded it. I think it was Voss.",
	"Somebody kept broadcasting distress calls long after this yard shut down. The Revenant is using the old antenna feed. Follow it.",
	"The Architect is under the Nexus. We've heard from the people who lived through its orders. It's time it heard from them, too.",
]

const MEMORIES := [
	"Forge Titan / A work order for emergency generators was overwritten by a request for weapons. Voss saved the original.",
	"Verdant Colossus / The irrigation controller opened its own bypass to save the seed vault after the Blackout.",
	"Reactor guardian / The civilian grid had power. The Architect cut it when the buildings failed to report occupancy.",
	"Plant guardian / Operators held a sluice gate open by hand so the evacuation boats could reach the last dock.",
	"Archive guardian / The First Fracture split the witness record across nine controllers. Voss left each one a copy of its own decisions.",
	"Dock guardian / Voss sent an empty shuttle to draw the security drones away from a civilian convoy.",
	"BioLab guardian / The quarantine override was refused. RX-07 disobeyed and carried the first patient out.",
	"Array guardian / Dr. Voss answered NOVA from the evacuation convoy. Her last request was to get water and heat back to the districts still inside the grid.",
	"Scrapyard guardian / The last fragment gives NOVA the signed authority to return each facility to local control.",
]

const STANDARD_ENDING := "NOVA seals the Architect's command links. The facilities go dark while repair crews restore their local controls. RX-07 returns to the station with the recovered testimony."
const SECRET_ENDING := "NOVA uses the nine signed memories to hand each facility back to its operators. Across the city, water pumps and lights come back on. RX-07 stays on the line until the final district answers."

static func briefing(sector: int) -> String:
	return BRIEFINGS[clampi(sector, 1, BRIEFINGS.size()) - 1]

static func ending(has_all_memories: bool) -> String:
	return SECRET_ENDING if has_all_memories else STANDARD_ENDING

const ARRIVAL := [
	["NOVA", "RX-07. You're safe. Set both feet on the pad and follow my voice."],
	["RX-07", "Someone shut a door on me. There was a kid on the other side."],
	["NOVA", "That was Voss's lab. She got your frame out and gave you the right to refuse an order. I'm NOVA. This is her station."],
	["RX-07", "Is Voss here? Did the kid get out?"],
	["NOVA", "I lost them both at the Blackout. The Forge Titan kept a signed work order from that night. It's the first place we can look."],
	["RX-07", "Show me how to get there. I'll decide the rest when I see what's left."],
]

const RECONSTRUCTION := [
	["NOVA", "Hold still. I'm finishing the last checks. There. Can you feel the pad under your feet?"],
	["RX-07", "Yeah. I remember how I went down. How much did we lose?"],
	["NOVA", "The field kit and the progress you made on that run. Your stored gear, learned blueprints and permanent upgrades are safe."],
	["RX-07", "Leave that route on the map. I know what to do differently."],
]

static func shop_restock(level: int) -> Array:
	return [["NOVA", "The Shop just opened its Level %d stock. Check in before you head back out. They've got stronger supplies and new materials." % level]]

const FIELD_ADVICE := [
	"Your charged Buster can get through a raised guard. If you can't stop to charge, get around it or wait for the guard to drop.",
	"If you've got Magma Breaker, it burns through dry vines. Save enough energy to use it on the Colossus.",
	"The ice won't stop you when you let go. Brake before the ledge. Magma Breaker can cut through the Cryo Warden's armor.",
	"Wait for the pressure bursts to die down before you jump. Frost Lance hits the Kraken hardest when it comes into reach.",
	"Keep moving when you lose sight of it. Use Tidal Arc when it comes back up and save some energy for the next pass.",
	"Watch the wind before you leave the deck. Data Lance can reach Aerowyrm on a pass.",
	"Let the gas clear before you close in. Use Gale Edge to land a hit while the Chimera is exposed.",
	"Watch for a clear angle before you spend energy. Chimera Burst can catch Eclipse Nova with a spread.",
	"Try Singularity Shot. Lead the Revenant a little. The shot is slow, so give it room to reach the target.",
	"Wait for the phase locks to open before you commit to a jump. Save Scrap Reaver for the Architect.",
]

const SECOND_ACT := [
	"The Kiln Warden's lock is open. Find the Titan before it melts the rest of the generator run.",
	"You cleared the canopy. The seed vault's below it. The Colossus is closing the last valve.",
	"The outer locks opened. The district heat line ends at the Cryo Warden's station.",
	"That bulkhead is open. The Kraken saved the evacuation log in a chamber that's still half flooded.",
	"The sentry pulled up the witness record when it saw you. Sand Cipher hasn't purged it yet.",
	"The runway is clear. Aerowyrm is still flying the route from the original manifest. We can read it from there.",
	"The emergency rooms are still marked occupied. The Chimera has the log that tells us whether anyone's inside.",
	"We're through to the broadcast ring. Eclipse Nova has the only intact recording of the reply.",
	"I can hear the antenna from here. If the Revenant still has that final signature, we'll have enough to restore local control.",
	"The Architect just took every command channel. I'll hold the uplink open. Get to the core.",
]

const OPERATOR_BRIEF_RESPONSES := [
	["I'll start on the generator line. What gets through a guard?", "I can hear the furnace from here. Which way gets me past it?"],
	["I'll leave the living plants alone. Can I clear the ones on the path?", "If the seedlings survived, I want that valve open when I leave."],
	["The doors are frozen shut from the inside. How do I get through?", "If I bring the Warden down, what can I do about that ice?"],
	["The whole deck is shaking. How long can I wait between surges?", "What's going to work against the Kraken down there?"],
	["I can see the ground move before anything comes up.", "Cipher's got the record. How do I get a clear shot?"],
	["The wind's pulling me sideways on the deck.", "I see it coming around again. What will reach it?"],
	["I remember the lights along this corridor.", "I'm going to check the rooms on the way to the Chimera."],
	["Why would it record a reply and leave you waiting?", "I want to know what she said before the signal dropped."],
	["Those old relays are still lit. Someone's taking care of them.", "I'll leave the relays standing. What can take the Revenant down?"],
	["The Architect recognized my serial before I even keyed the channel.", "Keep the records ready. If it opens a channel, I'm taking it."],
]

const WARDEN_EXCHANGES := [
	["Line three has a place for your frame. Step onto the belt.", "I don't work the line anymore.", "Refusal logged. Lower the scrap hatch."],
	["I smelled smoke in the greenhouse. Was that you?", "On the evacuation path. I left the beds alone.", "The last machine that said that carried a flamethrower. Stay where I can see you."],
	["You can't cross. Every door beyond this one is holding back a cold leak.", "The same doors are keeping the district heat line closed.", "Tell that to the people who welded them shut."],
	["Red line on the gauge. That door stays down.", "The people on those boats saw the same gauge and opened it anyway.", "And the pressure never came back. Step away from the controls."],
	["I have orders to seal the witness record.", "The witnesses are still alive. They deserve a copy.", "I can seal this door faster than you can reach it."],
	["Flight canceled. The dock doesn't clear unmarked traffic.", "Then why are your lights still tracking that flight path?", "Because someone has to finish what the convoy started. You can't be seen here."],
	["Do you know what happens if you open the red door?", "I know what happened when you left it shut.", "I remember you at that door. Your clearance still says quarantine."],
	["The reply has been held for collection.", "NOVA's been listening since the Blackout. Send it.", "I tried. The second ring keeps cutting me off. You'll have to get through me first."],
	["Anything behind that gate belongs to the yard.", "Even the names on the distress relays?", "Especially those. They don't go to anyone who still takes its orders."],
	["RX-07. Stand inside the inspection marks.", "That used to work on me.", "It still works on the doors."],
]

const GUARDIAN_EXCHANGES := [
	["There were blankets on the generator crates. I melted them with everything else.", "I've got the names of the shelters they were meant for. Tell me who canceled the order.", "The Architect. I saved the first order where it couldn't read it. Now it's telling me to scrap you, too."],
	["The vault was meant to stay sealed. I left one valve open.", "I saw green shoots on the other side of the spillway. You kept them alive.", "Until the next command. If you can stop the pumps, I can leave that valve open for good."],
	["The heat was working when the Architect told me the buildings were empty.", "Their monitors were dead. The people inside were still waiting.", "I know their names now. It's too late for some of them. Get the rest off my line before it shuts again."],
	["They propped the sluice with their bodies. I kept trying to close it.", "The evacuation boats got through. The log will tell us who was on them.", "I can't reopen the sluice with this much charge in it. Drain the grid. Then the log is yours."],
	["I was supposed to erase the record of my decision. Voss made me read it out loud instead.", "So somebody outside the network would remember it.", "She did. Take the copy before the purge starts. I don't know how long I can hold it."],
	["I saw the shuttle break up. There was nobody in it.", "Voss sent it ahead of the real convoy. Look under its flight path.", "There. All those little lights. I can give you the coordinates if you can stop the tracking drones."],
	["Your serial number is in this log. You carried a child out before I shut the door.", "I remembered letting go of her hand. I thought I'd left her there.", "You put her down inside the convoy. She walked the rest of the way."],
	["I kept the reply. It's Voss asking which districts still have water.", "NOVA's here. Let her hear it.", "The Architect will cut the transmitter if I answer. Keep it busy long enough for me to send the whole thing."],
	["I've got a signature from every machine that cut its own line. Yours is right at the bottom.", "Use them to give the districts their controls back.", "I will if I can. The Architect just powered up my arms without asking."],
	["A city I couldn't reach was a city I couldn't protect.", "You cut the lines yourself. Listen to what came back before you do it again.", "I hear them. My orders are still running, RX-07. You'll have to stop me."],
]

static func deployment(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var advice: String = FIELD_ADVICE[index]
	if sector == 1 and act == 2:
		advice = "The return shutter has a pressure plate in the lower gallery. Past it, break the cracked wall. Wait at the mouth of the smelter chute and destroy the rolling slag before you cross."
	elif sector == 2:
		advice = "One of the gate relays is up in the nursery. Step on the launch bloom and hold up to grab the vine. Jump when it swings forward. The other relay is behind a cracked wall." if act == 1 else "The canopy lift will get you to the first vine. Hold up between jumps and move fast. There’s nothing under the crossing, and the first relay is on the far ledge. The irrigation ferry leads to the other one."
	elif sector == 3 and act == 2:
		advice = "There's a rocket board beside the midway beacon. Hold up to board it. Relay A is at the end of the coolant spillway: hold jump to thrust over gaps, crouch under the ice gates, and steer left to brake. The return lift brings you back here."
	return [
		["NOVA", BRIEFINGS[index] if act == 1 else SECOND_ACT[index]],
		["RX-07", OPERATOR_BRIEF_RESPONSES[index][act - 1]],
		["NOVA", advice],
	]

static func boss_exchange(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var exchange: Array = WARDEN_EXCHANGES[index] if act == 1 else GUARDIAN_EXCHANGES[index]
	return [["BOSS", exchange[0]], ["RX-07", exchange[1]], ["BOSS", exchange[2]]]

static func foundry_boss_hint(act: int) -> String:
	if act == 1:
		return "Shoot either blue purge valve before the fire starts. Then shoot the exposed Warden."
	return "Stand past a quench lock. When it turns amber, jump clear. Shoot the Titan once the lock catches its drill."

static func jungle_boss_hint(act: int) -> String:
	if act == 1:
		return "Follow the green tether and shoot the seed anchor to strip Briar's armor. When it grows back, find the new anchor."
	return "When the poison rises, stand on a glowing drain above it. Hold your ground until the mist clears, then drop down and shoot the exposed reactor."


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
			["NOVA", "The Architect is off the grid. The crews have control. I can hear a pump starting in the southern district."],
			["RX-07", "Send that to the convoy. Tell Voss we heard her."],
			["NOVA", "I will. Stay on the line a little longer. People are starting to call back."],
		]
	return [
		["NOVA", "I cut the Architect's command links. The crews are safe, but they'll have to restart each facility by hand."],
		["RX-07", "Send them the records we recovered. They should know what they're walking back into."],
		["NOVA", "Already sent. Come back to the station. One district is asking for help at the pumps."],
	]

static func hard_unlock(sector: int) -> Array:
	return [
		["NOVA", "Nice work, RX-07. You can now deploy to %s on Hard." % Catalog.info(sector).title],
		["NOVA", "That goes for any sector you clear on Normal. Hard brings tougher defenders, better salvage, and a greater chance of rare blueprints."],
	]
