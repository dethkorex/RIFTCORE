from pathlib import Path
import json,sys
root=Path(sys.argv[-1])
rows=[
('neon_factory','Neon Factory','forge_titan','Forge Titan','Fire / Mechanical','magma_breaker','Magma Breaker','ff8b36','fire',1040,'',''),
('machine_jungle','Machine Jungle','verdant_colossus','Verdant Colossus','Nature / Poison','thorn_swarm','Thorn Swarm','a5ff71','nature',1700,'magma_breaker','Toxic root flood'),
('frozen_reactor','Frozen Reactor','cryo_warden','Cryo Warden','Ice','frost_lance','Frost Lance','63dfff','ice',1875,'magma_breaker','Ice traction and coolant vents'),
('abyssal_plant','Abyssal Plant','volt_kraken','Volt Kraken','Electric / Water','tidal_arc','Tidal Arc','70e9ef','electric',2075,'frost_lance','Buoyant water and live electrode grids'),
('buried_archives','Buried Archives','sand_cipher','Sand Cipher','Sand / Technology','data_lance','Data Lance','ffc568','data',2250,'tidal_arc','Phasing ledges and sand geysers'),
('sky_dock','Sky Dock','aerowyrm','Aerowyrm','Wind / Speed','gale_edge','Gale Edge','8bffca','wind',2475,'data_lance','Wind lanes and air lifts'),
('biolab','BioLab','omega_chimera','Omega Chimera','Mutation / Chaos','chimera_burst','Chimera Burst','ff62b1','chaos',2700,'gale_edge','Mutation pulses and bounce pads'),
('orbital_array','Orbital Array','eclipse_nova','Eclipse Nova','Gravity / Light','singularity_shot','Singularity Shot','bc9aff','gravity',2910,'chimera_burst','Low gravity and timed solar fields'),
('scrapyard_expanse','Scrapyard Expanse','rust_revenant','Rust Revenant','Metal / Regeneration','scrap_reaver','Scrap Reaver','ff9452','metal',3160,'singularity_shot','Magnetic pull and scrap presses'),
('riftcore_nexus','RiftCore Nexus','the_architect','The Architect','Corruption / Energy','core_override','Core Override','ff6ca8','core',3600,'scrap_reaver','Corruption gates and phase locks'),
]
enemies={
'frozen_reactor':['Cryo Skater','Shard Crawler','Glacier Bastion','Coolant Sentry','Ice Wisp'],
'abyssal_plant':['Pressure Guard','Arc Crab','Dive Bulwark','Coil Sentry','Current Jelly'],
'buried_archives':['Archive Sentinel','Dune Scarab','Cipher Guard','Glyph Turret','Relic Wisp'],
'sky_dock':['Deck Runner','Gust Stalker','Hangar Bastion','Jet Sentry','Wind Kite'],
'biolab':['Culture Scout','Mutation Crawler','Quarantine Brute','Dose Sentry','Splice Drone'],
'orbital_array':['Solar Scout','Orbit Crawler','Gravity Bastion','Helio Sentry','Nova Probe'],
'scrapyard_expanse':['Salvage Runner','Rivet Crawler','Magnet Bulwark','Scrap Sentry','Rust Kite'],
'riftcore_nexus':['Rift Pursuer','Null Crawler','Nexus Guardian','Breach Sentry','Corrupt Echo']}
entries=[]
for i,(id,title,slug,boss,element,reward,reward_name,color,shot,hp,weak,gimmick) in enumerate(rows,1):
 entries.append(dict(number=i,id=id,title=title,boss_slug=slug,boss=boss,boss_node=''.join(boss.split()),
  element=element,reward=reward,reward_name=reward_name,color=color,shot=shot,health=hp,weak=weak,gimmick=gimmick,
  level=f'res://scenes/levels/{"neon_factory_test" if i==1 else id}.tscn',
  boss_scene=f'res://scenes/levels/{slug}.tscn',enemies=enemies.get(id,[])))
(root/'assets/campaign/sector_plan.json').write_text(json.dumps(entries,indent=2)+'\n')
s='extends RefCounted\n\n# Generated from assets/campaign/sector_plan.json by build_catalog.py.\nconst SECTORS := '+json.dumps(entries,indent=1)+'\n\n'
s+='''static func info(number: int) -> Dictionary:
	return SECTORS[clampi(number - 1, 0, SECTORS.size() - 1)]

static func weapon(id: String) -> Dictionary:
	for entry in SECTORS:
		if entry.reward == id:
			return entry
	return {}
'''
(root/'scripts/sector_catalog.gd').write_text(s)
