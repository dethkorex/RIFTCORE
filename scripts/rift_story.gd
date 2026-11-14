extends RefCounted

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
	"Array guardian / Someone outside the ten facilities kept answering NOVA's distress call.",
	"Scrapyard guardian / The last fragment gives NOVA the signed authority to return each facility to local control.",
]

const STANDARD_ENDING := "NOVA seals the Architect's command links. The facilities go dark while repair crews restore their local controls. RX-07 returns to the station with the recovered testimony."
const SECRET_ENDING := "NOVA uses the nine signed memories to hand each facility back to its operators. Across the city, water pumps and lights come back on. RX-07 stays on the line until the final district answers."

static func briefing(sector: int) -> String:
	return BRIEFINGS[clampi(sector, 1, BRIEFINGS.size()) - 1]

static func ending(has_all_memories: bool) -> String:
	return SECRET_ENDING if has_all_memories else STANDARD_ENDING
