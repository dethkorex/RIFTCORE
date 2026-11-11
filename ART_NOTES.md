# RIFTCORE visual assets

The concept images and trim sheets were made with the built-in image generation tool. The reference shots and in-game previews were rendered in Godot. The production robots are editable Blender-generated meshes; the concept images are visual references.

| Asset | Project file |
| --- | --- |
| Five robot models | `assets/enemies/*_armored.glb` |
| Robot and environment trim | `assets/neon_factory/factory_trim.png` |
| Platform trim | `assets/neon_factory/platform_trim.png` |
| Forge Titan mesh and trim | `assets/enemies/forge_titan_armored.glb`, `assets/enemies/forge_titan_trim.png` |
| Repeating background | `assets/neon_factory/factory_panorama.png` |
| Title background | `assets/ui/riftcore_title_art.png` |
| Updated security armor and height relief | `assets/enemies/security_trim.png`, `assets/enemies/security_height.png` |

In Godot, edit `scenes/levels/neon_factory_test.tscn`. Move `Actors/RiftcoreMecha` to change the starting position; its mesh, collision, and deployment lightning use the actor's origin. `MARKERS/PlayerSpawn` is a fallback if the actor is placed off solid ground.

The following prompts were used:

## Enemy concepts

Stylized concept: Riftcore Neon Factory production design lineup. Use supplied Godot screenshot as enemy role and ordering reference. Redesign five small game robots left to right: biped scout, four-legged crawler, heavy biped bruiser, low twin-barrel sentry, wide hovering drone. Keep proportions compact and distinctly readable in profile. Upgrade from blockouts to beveled white ceramic and midnight cobalt powered armor over graphite piston joints, like a polished Mega Man-inspired 3D platformer. Amber for scout crawler sentry, hot magenta for bruiser and drone. Directional faceted armor, recessed optic and exposed mechanics, plausible construction. Five complete uncropped models in one row, three-quarter view, neutral dark blue studio, no labels, no text. Deliver one lineup design image.

## Factory trim

Use case stylized concept, production game texture asset. Reference image: the robots are material/color reference only. Generate a square trim atlas, precisely four full width horizontal bands of equal height, hard boundaries at 25%, 50%, 75%. Top band neutral pearl-white ceramic armor with fine panel seams, tiny rivets, sparse scratches. Second band rich cobalt blue painted steel with subtle restrained machining grooves and scattered small fasteners. Third band graphite black brushed gunmetal with parallel ventilation slits and fine mill lines. Bottom band industrial yellow-orange diagonal hazard stripes on dark navy painted steel. Orthographic flat front projection, even neutral albedo texture, no directional lighting, shadows, 3D rendering, perspective, frame, gutters, text, symbols, whitespace or labels. Each band fills its exact area edge to edge. Detailed game production trim map for Riftcore.

## Factory panorama

Use case stylized-concept. Asset: horizontally repeating 2.5D platformer panoramic far background texture for Riftcore Neon Factory. Ultra wide 3:1 panoramic horizontal view into a dark cobalt futuristic factory megastructure, dozens of tall industrial silhouettes, neon cyan reactor cores and occasional magenta smokestacks behind layered blue atmospheric haze. Mostly dim with tiny hot lights, no ground, no characters, no foreground buildings or gameplay objects, no words. Strong horizontal compositions. Left and right edges must match for seamless horizontal repeat; keep both outermost edges as near-identical softly hazed dark indigo open factory bays. Sharp architectural detail toward the middle, restrained contrast for HUD readability. Video game concept backdrop.

## Title art

Image 1 is the user-supplied Riftcore title-screen artwork: use the matching image with a blue and white armored hero standing at left and a colossal cyan industrial reactor with pink accent pipes on the right. Restore it faithfully as a 16:9 full-bleed game menu background, preserve composition, pose, color palette and architectural detail. No added text, buttons or logos. If an unrelated reference is supplied, produce the described heroic 16:9 artwork.

## Platform concepts

Use case stylized-concept. Asset: Riftcore Neon Factory 3D platform design lineup, use provided game capture as geometry and order reference. Five distinct assets in left to right order: plated low solid deck, recessed steel grate deck with purple beneath, moving conveyor with small cyan chevrons, vertical industrial lift portal and platform with yellow black safety stripe, thin open jump-through deck with purple edge. Refine with physically beveled gunmetal trim, blue steel deck segments with inset bolts and brush marks, pale chamfer edge catches, cyan embedded lights, modern sci-fi industrial hard surface machining. Keep all upper walkable surfaces clearly readable and precise original proportions. Dark studio orthographic three-quarter view, visible parts fully uncropped, no text or labels.

## Platform trim

Use case stylized-concept, production material trim atlas for the pictured Riftcore platform kit, use image as material reference only. Square flat game texture with four full-width strips of equal height and precise boundaries at 25%, 50%, 75%. Top 25% blue-grey navy brushed armor with broad spaced panel lines and flush bolts; second 25% lighter machined steel bevel trim with slim layered horizontal highlights and screws; third 25% black ribbed traction and recessed grille with fine blue highlights; fourth 25% industrial diagonal yellow and charcoal warning striping. Orthographic flat albedo, clean fine machining detail, no standalone objects, no words or labels, no gutters, no perspective, no drop shadows. Tile each strip horizontally.

## Forge Titan concept

Stylized concept for Forge Titan, Riftcore Neon Factory industrial boss. Use supplied Godot screen capture as left drill, right claw, central reactor, proportions and position reference. Modern hard surface reskin: muscular broad angular white ceramic gauntlets and sharp pauldrons, layered navy armor, dark graphite exposed hydraulic servos, three-tooth claw, heavy conical spiral drill with hot orange helical channels, armored orange reactor ring and narrow helmet visor. Oversized excavator boots with hazard accents. Functional industrial silhouette, as detailed as a hero mech, clean dark blue studio three-quarter view showing entire figure. Preserve orange and cobalt identity and arm side, no labels or text.

## Forge Titan trim

Use case stylized-concept, Forge Titan boss armor albedo trim sheet. Reference is for materials only. Square 2D atlas with four horizontal full-width equal strips precisely divided at 25%, 50%, 75%. First strip worn pearl-white reinforced ceramic, angular panel seams, rivets. Second strip saturated midnight cobalt metal armor with industrial beveled shapes and sparsely worn edges. Third strip dark graphite rotating drill steel with subtle radial-tooling marks represented as fine diagonal grooves and narrow stripes of orange heat discoloration. Last strip alternating ochre yellow and charcoal diagonal industrial stripes with small rivets. Flat texture, neutral even lighting, no cast shadows, no depth perspective, no objects, no writing or marks, no gutters.


## Security detail concept

Production reskin concept for Riftcore Neon Factory. Use current in-game screenshot as anatomy, role, lineup, and light colors reference. Upgrade the five compact robots shown, preserving order: amber scout biped, amber four-leg spider crawler, magenta heavy, amber twin turret, magenta drone. Remove toy-like rounded blank surfaces: sharp architectural chamfers, inset fine concentric metal rings, distinct mechanical fingers/pistons, overlapping gunmetal and cobalt armor panels, off-white ceramic front plating, minimal heat-scuffed wear, small black vent slots and rivets. Strong industrial hard-surface game art close to a modern Mega Man inspired player. Readable at gameplay scale, distinct faces and proportions, consistent neutral studio presentation. Five full objects across wide sheet, no text, no labels.

## Security albedo trim

Use case stylized concept, production PBR albedo atlas for the pictured Riftcore robot finish. Image reference for materials only. Make one square texture with precisely four equal-height, full-width rows: row 1 off-white ceramic with narrow straight inset seams, tiny rivet pairs and sparse scratches; row 2 midnight cobalt paneled steel with neat side grilles and rivets; row 3 dark satin gunmetal with fine milling marks and radiator vents; row 4 gold-edged graphite hazard trim. Crisp, narrow fine details. Front orthographic flat neutral color only, no lighting, rendered objects, perspective, gradients, labels, or margins. Every row fills from left edge to right and joins the next at exactly 25%, 50%, 75%.

## Security height map

Use case precise-object-edit. Convert supplied square production albedo trim atlas into a true grayscale surface height map with identical framing and exact geometry and feature positions. Neutral midgray on all four flat material bands regardless of their original albedo, near-black only on deep vent slots and very thin carved seam channels, light gray on raised bolt rims and bevels, slight linear grained relief on brushed metal. Hazard stripe colors on the fourth band are paint, do not encode their color as height. Do not move, redraw, rescale or offset any feature. Pure grayscale pixel values, orthographic height data, no shading, no ambient shadows or specular lighting.



## Machine Jungle production art

### jungleConcept

Mode: reference image generation.

Stylized concept asset kit for Riftcore Sector 02 Machine Jungle, nature/poison cybernetic factory overgrown with bioengineered plants. Reference image is art-style only: compact, readable armored game robots with sharp chamfers, machined material detail. Create five distinctly new jungle enemies in a single upper row of a game asset board: Rootrunner agile biped with leaf hood and root blade; Thorn Weaver four-leg spider with needle limbs and poison seed abdomen; Bark Bulwark armored beetle bruiser with layered bark shoulder plates; Spore Sentry rooted turret with three bulb barrels; Canopy Wasp hovering insect with narrow wings and glowing stinger. Emerald/olive ceramic, graphite, ivory edge metal, small jade lights and acid purple poison cores. Lower row shows modular root-ribbed floor tile, perforated canopy catwalk, tall vine wall, thorn bed trap, spore pod trap, and mechanical snap vine. Orthographic three-quarter studio presentation, complete separate objects, blue-green dark neutral background, no labels or text.

### jungleTrim

Mode: text-to-image generation.

Stylized concept game production albedo trim atlas, 1:1 square, for RIFTCORE Machine Jungle. Four exact horizontal full-width rows of equal height: 0–25% chipped ivory bioceramic hard armor plates with tiny fasteners and fine oblique seams; 25–50% deep emerald and moss-green lacquered armor with recessed leaf-shaped grooves and microgrilles; 50–75% dark forest-green graphite and root-vein engineering treads with shallow ribbed machining; 75–100% purple poison containment warning bands with graphite diagonal stripes. Flat front projection, no cast lighting or objects, no lettering or labels, clear strip boundaries, tile left-to-right, believable detail at gameplay scale.

### verdantConcept

Mode: text-to-image generation.

Stylized concept for RIFTCORE Sector 02 boss Verdant Colossus, a giant poison/nature industrial robot. Full body game production design in an athletic planted three-quarter pose on dark teal studio ground, only one boss. Distinct from a humanoid drill boss: broad rhinoceros beetle-inspired biped excavator shape, layered emerald hard armor and cracked ivory bioceramic pauldrons over graphite pistons, twisted artificial wooden root conduits, violet glowing seed reactor, small mint-green horned helmet eyes. Left forearm mechanical grapple vine whip with jade articulated segments and sharp seed tip, right shoulder clusters three spore-launcher bulbs with violet lenses, broad armored claw right hand, large well-defined piston legs and tree-root cleats. Industrial sci-fi robot with living vegetation accents, sharp bevels, premium realistic game mesh presentation matching the armored Neon Factory player, no text or labels, 16:9 uncropped silhouette.

### junglePanorama

Mode: text-to-image generation.

Stylized concept, panoramic seamless horizontal parallax background for RIFTCORE Sector 02 Machine Jungle, distant view into overgrown biomechanical greenhouse megafactory. Muted emerald and midnight teal palette with vine covered industrial towers and arches, bioluminescent jade roots threaded through giant metal lattice, pockets of violet spore light, dense layered greenery under dark mist. No character, no foreground floors, no readable text. Broad sky canopy behind stage platforms. Both outer edges blend into similar softly misted dark green machinery so panorama loops horizontally. Game-ready 3:1 composition.




## Neon Factory security redesign

Reference-image generation using the earlier in-game lineup. The resulting silhouettes informed five independent Blender models and the in-game showroom. Forge Titan keeps its existing model.
