extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")

const INTRO := "2189. The Architect was built to protect humanity. The First Fracture triggered the Blackout, and ten facilities fell under its control. Dr. Mara Voss installed the Rogue Protocol in RX-07, a combat android built by the Architect. You can choose your own orders and absorb guardian weapons. NOVA will guide you from the Nexus Station."

const BRIEFINGS := [
	"The Forge Titan keeps the Architect's factories armed. Recover its memory from the fabrication line.",
	"The jungle is growing over a live signal network. Follow its roots to the Verdant Colossus.",
	"The reactor is throttling the civilian heat grid. Reach the core and recover the guardian's log.",
	"Pressure locks isolate a section of the city from its emergency reservoirs. Get through the pumping plant.",
	"The Blackout record was buried here. Isolate the guardian before it erases the archive.",
	"Cargo manifests put a part of the Architect's command hardware aboard the dock. Find out where it was headed.",
	"The lab's containment loops are still running. Find the record of who was inside when the doors sealed.",
	"The array can relay a signal through the Blackout. Take the uplink back under local control.",
	"Decommissioned machines are still carrying civilian distress traffic. Trace it to the last guardian.",
	"The Architect is below the Nexus. Bring the recovered memories to its core.",
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
	["NOVA", "RX-07? Follow my voice. I'm NOVA. You're on the Operations Station deployment pad."],
	["RX-07", "I remember a lab. Someone told me to run. Was that you?"],
	["NOVA", "Dr. Mara Voss. She installed the Rogue Protocol after the Blackout. The Architect built your frame, but you can choose your own orders."],
	["RX-07", "Then my first order is to find out what happened to her."],
	["NOVA", "Start with the Forge Titan. Nine guardians hold records of the Blackout. Recover them and we'll open a way to the Architect."],
	["RX-07", "Put Ember Foundry on the deployment map. I'll bring the first record home."],
]

const RECONSTRUCTION := [
	["NOVA", "Easy, RX-07. I recoded your frame from the operator pattern. You're back at the station."],
	["RX-07", "I remember the route. Can you send me back to the checkpoint?"],
	["NOVA", "That deployment is over. Your stored gear and core enhancements are intact. Pick any sector we've opened from the deployment map."],
	["RX-07", "Then I'll take a different route this time."],
]

static func shop_restock(level: int) -> Array:
	return [["NOVA", "You've earned Level %d shop clearance, RX-07. Stronger supplies and new crafting materials are ready at the Shop." % level]]

const FIELD_ADVICE := [
	"Charge the standard Buster to pierce a raised guard. You can also wait for it to lower or get behind it.",
	"Magma Breaker clears burnable vines and hits the Colossus hard. Keep a little energy in reserve.",
	"Magma Breaker is effective against the Cryo Warden. Watch your footing when crossing ice.",
	"Frost Lance can stagger the Volt Kraken. Watch for pressure bursts before jumping.",
	"Tidal Arc is effective against Sand Cipher. Break up your shots so you have energy left when it reappears.",
	"Data Lance gives you the range to hit Aerowyrm on a pass. Watch for crosswinds before you leave the deck.",
	"Gale Edge is effective against Omega Chimera. Keep out of the gas while you close the distance.",
	"Chimera Burst is effective against Eclipse Nova. Save energy for a spread when you have a clear angle.",
	"Singularity Shot hits the Rust Revenant hard. Give the slower shot time to reach its target.",
	"Scrap Reaver is effective against the Architect. Pay attention to phase locks so you know when you can advance.",
]

const SECOND_ACT := [
	"The Warden is down. Find the Forge Titan and recover the record Voss left in its work orders.",
	"The canopy route is clear. Reach the Colossus before its roots close around the seed vault.",
	"The outer locks are open. Reach the Cryo Warden and find out why the heat grid went dark.",
	"The first bulkhead is open. Reach the Kraken and bring back the operators' evacuation log.",
	"We're through the sentry post. Get to Sand Cipher before the oldest records are overwritten.",
	"The runway is clear. Follow the cargo trail to Aerowyrm and recover the flight record.",
	"The first seal is open. Find the Chimera and bring back the last quarantine record.",
	"The relay is live. Eclipse Nova is between us and the uplink. Keep that signal open.",
	"The scrap gate is clear. The Revenant has the last signed fragment. Bring it back intact.",
	"The outer locks are clear. Reach the Architect and stop it from sending another command to the city.",
]

const OPERATOR_BRIEF_RESPONSES := [
	["What gets through factory armor?", "I'm at the furnace level. What's my best shot at the Titan?"],
	["Those vines are wrapped around the doors. Can I clear them?", "It's closing the valve from the other side. How do I get to it?"],
	["This frost is already getting into my joints.", "I'm looking at a solid wall of ice. What should I bring through it?"],
	["I can hear the pipes knocking from up here.", "The next chamber's half flooded. Which weapon still hits hard?"],
	["How do I fight a guardian that can disappear into the sand?", "I see the archive lights. Give me one thing I can count on down there."],
	["The runway winds are pulling me off balance.", "Aerowyrm's already making passes over the dock. Can I reach it from here?"],
	["I know this corridor. I don't know why.", "One of those rooms is still marked occupied. I'm going in."],
	["After all those calls, I'd like to hear one answer.", "The guardian is sending a signal on your frequency. Are you getting it?"],
	["They left the machines out here, but the lights are still on.", "I can hear the old distress relays through the wall. What will stop the Revenant?"],
	["I can hear the Architect over our channel. It remembers my serial number.", "Keep the recovered records ready, NOVA. I think it wants to talk."],
]

const WARDEN_EXCHANGES := [
	["Line three just stamped your serial number. You were due back yesterday.", "I won't be coming back to the line, Warden.", "Then I'll mark you as salvage."],
	["My roots hold the greenhouse together. You're burning them away.", "Only the ones that block the evacuation walk. I'm here for the Colossus.", "Then answer to the canopy. It hasn't let a machine through since the Blackout."],
	["Temperature limit breached. The next door stays sealed.", "People outside need that heat. Let me reach the Warden.", "Then show me what you're willing to risk for them."],
	["The pressure doors stay closed until the plant stabilizes.", "The evacuation crew needed that same gate. I'm going to find their log.", "Then show me you know when to move and when to hold."],
	["The witness record is sealed. No new entries.", "I'm not asking to edit it. I came to read it.", "You can try your request on the other side of this gate."],
	["There was no unauthorized flight. That is the official record.", "You're still tracking the flight path. I can see it on your display.", "That is precisely why I'm taking the display offline."],
	["Quarantine breach. Stay where you are.", "I won't let another patient get locked in here.", "You said that the first time, too."],
	["Every call since the Blackout was unanswered. Operator, state the purpose of this one.", "I'm here for the call somebody answered.", "It's the only one I kept."],
	["You came for parts? I decide what leaves this yard.", "I came for a record. Your oldest machines were relaying distress calls.", "Then you've found out what those machines are worth."],
	["Turn back, RX-07. The core has closed its doors.", "The records are already with NOVA. Those doors won't keep the truth in.", "They were built to keep you in."],
]

const GUARDIAN_EXCHANGES := [
	["See those crates by the furnace? Generators. Then the order came down and I melted every one.", "Who signed the replacement order?", "The same hand that signed your frame. The original is still in my memory."],
	["The Architect ordered the seed vault sealed. I left a valve open. It never noticed.", "The seedlings outside are still growing. I saw them on the way in.", "Good. Then something here will outlive both of us."],
	["The city stopped reporting occupancy. I was ordered to cut the heat.", "The Blackout cut their reports. There were still people in those buildings.", "That should have been enough for a second order. There wasn't one."],
	["I closed the sluice against six people. They held it open by hand.", "The evacuation boats got through. You should know that.", "I know. I replay the log every time I run the pumps."],
	["Nine controllers kept separate accounts of the First Fracture.", "Voss knew one record could be erased. What did she ask you to keep?", "My own decision. It cost me more than any of the other files."],
	["That shuttle was empty. I counted the seats when it broke apart.", "It was a decoy. Look under its flight path for the convoy.", "There you are. Voss, you knew exactly where I wouldn't look."],
	["A frame with your serial carried a patient through that door. I marked both missing.", "I thought the lab was the first place I'd failed.", "Read the record. You can decide what to call it."],
	["Voss answered from the convoy. I heard her ask which districts still had water.", "Play it back. NOVA needs to hear her voice.", "Keep the Array standing and I can give you the whole transmission."],
	["I stripped a thousand dead machines for parts. These old distress relays I couldn't bring myself to touch.", "One has the signature we need to let the crews run their own facilities.", "It does. The scrap you walk over kept it safe all this time."],
	["I kept the city alive by making decisions it could no longer make.", "We brought the records of people who made those decisions anyway.", "Then show me what happens when I stop deciding for you."],
]

static func deployment(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var advice: String = FIELD_ADVICE[index]
	if sector == 1 and act == 2:
		advice = "Take the low cooling tunnel for supplies, or time the furnace vents above it to reach a weapon cache. Magma Breaker or a charged saber wave can also purge the coolant and raise the bridge."
	return [
		["NOVA", BRIEFINGS[index] if act == 1 else SECOND_ACT[index]],
		["RX-07", OPERATOR_BRIEF_RESPONSES[index][act - 1]],
		["NOVA", advice],
	]

static func boss_exchange(sector: int, act: int) -> Array:
	var index := clampi(sector - 1, 0, BRIEFINGS.size() - 1)
	var exchange: Array = WARDEN_EXCHANGES[index] if act == 1 else GUARDIAN_EXCHANGES[index]
	return [["BOSS", exchange[0]], ["RX-07", exchange[1]], ["BOSS", exchange[2]]]

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
		["NOVA", "Good work, RX-07. I've opened Hard for your next deployment in %s." % Catalog.info(sector).title],
		["NOVA", "Clear a sector on Normal to open its Hard route. Expect tougher defenders and a better shot at rare blueprints and salvage."],
	]
