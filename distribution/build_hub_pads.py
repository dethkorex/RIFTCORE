"""Build the Operations Hub hardware in Blender. Pass -- followed by asset names to limit export."""
from math import cos, pi, sin, tau
from pathlib import Path
import sys

import bmesh
import bpy

OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "hub"
guides = []
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def finish(name, rgb, metal, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


iron = finish("Undercarriage", (.016, .023, .032), .42, .53)
paint = finish("Midnight ceramic", (.047, .080, .115), .46, .40)
alloy = finish("Armor steel", (.20, .27, .32), .68, .37)
trim = finish("Edge milling", (.43, .49, .52), .68, .32)
tread = finish("Non-slip deck", (.056, .072, .082), .14, .72)
brass = finish("Safety ochre", (.49, .25, .055), .38, .48)
emitter = finish("Light guides", (.10, .72, .89), .18, .26)


def block(name, outline, low, high, mat, bevel=0.006):
    n = len(outline)
    vertices = [(x, y, z) for z in (low, high) for x,y in outline]
    faces = [list(reversed(range(n))), list(range(n, 2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return solid(name, vertices, faces, mat, bevel)


def solid(name, vertices, faces, mat, bevel):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    if bevel:
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Milled edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if mat == emitter:
        guides.append(obj)
    return obj


def disc(radius, low, high, mat, sides=48):
    return block("Drum", [(radius*cos(i*tau/sides), radius*sin(i*tau/sides))
                          for i in range(sides)], low, high, mat)


def segment(start, stop, section, mat, divisions=6, bevel=.002):
    # The radial cross section describes actual lips, sloping plate and fascia.
    n = len(section)
    points = []
    for i in range(divisions+1):
        angle = start + (stop-start)*i/divisions
        points += [(r*cos(angle),r*sin(angle),h) for r,h in section]
    faces = [list(range(n)), list(reversed(range(divisions*n,(divisions+1)*n)))]
    for i in range(divisions):
        for j in range(n):
            a=i*n+j
            b=i*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
    return solid("Radial casting", points, faces, mat, bevel)


def strip(a,b,r1,r2,z,mat,divisions=6):
    segment(a,b,[(r1,z-.009),(r2,z-.009),(r2,z),(r1,z)],mat,divisions)


def fastener(x,y,z):
    for radius,height,mat in [(0.039,.010,iron),(.026,.015,trim)]:
        block("Captive bolt", [(x+radius*cos(i*pi/3),y+radius*sin(i*pi/3)) for i in range(6)],
              z-.005,z+height,mat,.001)


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    objects[0].name=name
    return objects[0]


def station_platform():
    outer, h, count = 1.28, .151, 8
    disc(outer*.94,.012,h*.45,iron,count*2)
    disc(outer*.90,h*.39,h*.64,alloy,count*2)
    disc(outer*.87,h*.60,h*.83,iron)
    disc(.84,.052,h-.012,paint)
    disc(.713,h-.012,h+.001,tread)
    for i in range(count):
        center = -pi/2 + tau*i/count
        half = pi/count-.018
        a,b = center-half,center+half
        segment(a,b,[(outer*.69,h*.42),(outer*.96,h*.30),(outer,h*.52),
                     (outer*.99,h*.74),(outer*.90,h),(outer*.73,h)],alloy)
        strip(a+.025,b-.025,outer*.745,outer*.865,h+.007,paint)
        strip(a+.045,b-.045,outer*.87,outer*.89,h+.007,trim)
        # Visible from a low side camera: a recessed black bezel with a colored lens.
        segment(a+.055,b-.055,[(outer*.985,h*.48),(outer*1.001,h*.48),
                    (outer*1.001,h*.68),(outer*.985,h*.68)],iron)
        segment(center-half*.54,center+half*.54,[(outer,h*.525),(outer*1.004,h*.525),
                    (outer*1.004,h*.63),(outer,h*.63)],emitter)
        for angle in (a+.065,b-.065):
            fastener(outer*.81*cos(angle),outer*.81*sin(angle),h+.009)
        if i%2==0:
            for j in [-1,0,1]:
                angle=center+j*.048
                strip(angle,angle+.020,outer*.756,outer*.833,h+.016,brass,1)
        else:
            strip(center-half*.55,center+half*.55,outer*.785,outer*.814,h+.012,emitter)
    for side in [-1,1]:
        for row in [-2,-1,0,1,2]:
            y=row*.133
            poly=[(.22,y),(.44,y+.045),(.48,y+.080),(.26,y+.038)]
            block("Grip rib",[(side*x,v) for x,v in poly],h+.001,h+.010,alloy,.002)
    export("station_platform")


def export(name):
    root = bpy.data.objects.new("Housing", None)
    bpy.context.collection.objects.link(root)
    chassis = join([obj for obj in bpy.context.scene.objects if obj.type == "MESH"
                    and obj not in guides], "Chassis")
    chassis.parent = root
    if guides:
        join(guides, "LightGuides").parent = root
        guides.clear()
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+".glb")),export_format="GLB",
                              export_animations=False,export_yup=True,export_texcoords=False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)



# Cross-sections are given in the front elevation. Depth increases toward the
# player, so the same socket can flare outward and then taper into its glass.
navy = finish("Enamel - midnight blue", (.061, .077, .149), .31, .43)
rim = finish("Machined indigo", (.185, .218, .337), .49, .39)
edge = finish("Bead-blasted edge", (.30, .36, .48), .48, .38)
glass = finish("Smoked display glass", (.011, .027, .052), .12, .27)


def faceplate(name, x, height, profiles, mat, slope=0):
    vertices = []
    for width, tall, clip, depth in profiles:
        w, h = width / 2, tall / 2
        points = [(-w+clip, h), (w-clip, h), (w, h-clip), (w, -h+clip),
                  (w-clip, -h), (-w+clip, -h), (-w, -h+clip), (-w, h-clip)]
        vertices.extend((x+px, -(depth+slope*py), height+py) for px, py in points)
    last = len(vertices)-8
    faces = [list(range(8)), list(reversed(range(last, last+8)))]
    for offset in range(0, last, 8):
        for i in range(8):
            j = (i+1) % 8
            faces.append((offset+i, offset+j, offset+j+8, offset+i+8))
    return solid(name, vertices, faces, mat, .005)


def framed_display(name, x, y, w, h, depth, chamfer, slope=0):
    faceplate(name+" housing", x, y, [
        (w-.13, h-.08, chamfer, depth-.25), (w, h, chamfer, depth-.10),
        (w, h, chamfer, depth-.045), (w-.13, h-.10, chamfer*.8, depth)
    ], rim, slope)
    faceplate(name+" seal", x, y, [(w-.19,h-.13,chamfer*.79,depth),
                                   (w-.25,h-.19,chamfer*.68,depth+.018)], iron, slope)
    faceplate(name+" face", x, y, [(w-.28,h-.21,chamfer*.61,depth+.018),
                                   (w-.30,h-.23,chamfer*.59,depth+.022)], glass, slope)


def kiosk():
    # Broad kick plinth, recessed service cabinet and a projecting writing shelf.
    faceplate("Kick plinth", 0, .19, [(2.92,.36,.05,-.36),(3.04,.36,.05,.52)], iron)
    faceplate("Service cabinet", 0, .42, [(2.92,.76,.10,-.32),(3.06,.72,.10,.42),
                                         (2.89,.58,.09,.60)], navy)
    faceplate("Removable central panel", 0, .43, [(1.49,.49,.035,.593),(1.43,.46,.03,.62)], paint)
    faceplate("Console shelf", 0, .72, [(2.94,.22,.08,-.18),(3.08,.24,.09,.48),
                                       (2.91,.12,.05,.63)], rim)
    for side in (-1,1):
        faceplate("Armored counter end", 1.175*side,.418,
                  [(.74,.66,.10,.38),(.73,.61,.085,.57),(.60,.48,.064,.65)],rim)
        for row in range(3):
            faceplate("Recessed cooling slot", .59*side,.345+.062*row,
                      [(.19,.018,.008,.619),(.18,.016,.007,.628)],iron)
    faceplate("Reader palm rest",0,.79,[(1.19,.16,.045,.27),(1.12,.112,.035,.54)],paint)
    faceplate("Reader lip",0,.79,[(.79,.021,.008,.543),(.76,.016,.006,.551)],rim)
    faceplate("Rear enclosure", 0, 1.36, [(2.76,1.49,.11,-.58),(2.61,1.48,.11,-.29)], navy)
    for side in (-1,1):
        x = 1.29*side
        faceplate("Upright", x, 1.45, [(.35,1.65,.07,-.42),(.39,1.63,.07,.08),
                                       (.28,1.59,.045,.16)], navy)
        faceplate("Lamp socket", x, 1.63, [(.175,.72,.025,.16),(.169,.70,.025,.18)], iron)
        faceplate("Vertical diffuser", x, 1.63, [(.113,.63,.015,.18),(.107,.62,.015,.19)], emitter)
    faceplate("Hinged screen stand", 0, .87, [(1.12,.36,.06,-.05),(1.08,.34,.06,.29)], paint)
    framed_display("Touchscreen", 0, 1.29, 1.67,.93,.34,.093,-.27)
    framed_display("Overhead nameplate", 0, 2.23, 3.39,.73,.27,.18)
    export("station_kiosk")


def station_sign():
    # The lintel underside is at hub height 4.645. Clamp the rail against it;
    # the two offset hangers carry the sign forward of the window glazing.
    faceplate("Overhead mounting rail",0,1.23,
              [(3.86,.13,.035,-.72),(3.86,.13,.035,-.37),
               (3.80,.10,.025,-.33)],navy)
    for x in (-1.61,1.61):
        faceplate("Ceiling shoe",x,1.19,
                  [(.54,.18,.037,-.66),(.53,.18,.037,-.32),(.45,.14,.028,-.29)],rim)
        # Side elevation of a forged offset yoke, flat where it meets the rail.
        upper = [(-.56,1.17),(-.30,1.17),(-.30,1.02),(.055,.82),
                 (.055,.55),(-.16,.55),(-.16,.72),(-.56,.95)]
        vertices = [(x+dx,-depth,height) for dx in (-.12,.12) for depth,height in upper]
        n = len(upper)
        sides = [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        solid("Offset hanger",vertices,[list(range(n)),list(range(n,2*n))]+sides,rim,.019)
        faceplate("Lower saddle",x,.66,
                  [(.40,.24,.034,-.17),(.40,.24,.034,.062),(.33,.21,.027,.089)],navy)
        faceplate("Hanger pin",x,.691,
                  [(.14,.068,.026,.09),(.12,.056,.022,.10)],edge)
    framed_display("Operations Station", 0, 0, 5.15,1.30,.27,.26)
    for x in (-1.64,1.64):
        faceplate("Subtitle light", x,-.337,[(.64,.027,.012,.295),(.61,.022,.01,.305)],emitter)
    export("operations_sign")


def deployment_platform():
    disc(1.66,.006,.113,iron,48)
    disc(1.62,.09,.235,navy,48)
    disc(1.46,.18,.243,rim,64)
    disc(1.37,.20,.248,paint,72)
    disc(.735,.227,.25,tread,72)
    for i in range(12):
        angle = -pi/2+i*tau/12
        half = pi/12-.008
        a,b = angle-half,angle+half
        segment(a,b,[(1.39,.14),(1.67,.022),(1.76,.073),(1.76,.258),
                     (1.66,.326),(1.49,.326),(1.39,.264)],navy if i%3==1 else rim,3,.009)
        if i%3!=0:
            segment(angle-.131,angle+.131,[(1.748,.088),(1.77,.088),(1.77,.237),
                                           (1.748,.237)],iron,2)
            segment(angle-.110,angle+.110,[(1.768,.114),(1.777,.114),(1.777,.212),
                                           (1.768,.212)],emitter,2)
        if i%3==0:
            strip(a+.07,b-.07,1.53,1.59,.329,edge,3)
    # Flush bezels under the live Godot rings keep the light sources grounded.
    for radius in (.79,1.18):
        segment(0,tau,[(radius-.088,.226),(radius+.088,.226),(radius+.088,.25),
                       (radius-.088,.25)],iron,72)
    framed_display("Deploy badge",0,.198,1.25,.384,1.825,.083)
    export("deployment_platform")



def architectural_bay():
    deck_coat = finish("Deck - satin blue ceramic", (.096,.119,.205), .26,.40)
    deck_alt = finish("Deck - alternate sheet", (.087,.11,.19), .27,.43)
    joint = finish("Deck panel seam", (.036,.047,.079), .34,.52)
    roof = finish("Ceiling alloy", (.105,.13,.218), .22,.47)
    beam = finish("Structural blue", (.068,.089,.158), .35,.43)
    lamp = finish("Frosted ceiling diffuser", (.66,.94,1), .02,.27)
    bsdf = lamp.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (.46,.88,1,1)
    bsdf.inputs["Emission Strength"].default_value = 1.45

    def slab(name,x,z,w,d,cut,h0,h1,material, bevel=.008):
        corners = [(-w/2+cut,-d/2),(w/2-cut,-d/2),(w/2,-d/2+cut),
                   (w/2,d/2-cut),(w/2-cut,d/2),(-w/2+cut,d/2),
                   (-w/2,d/2-cut),(-w/2,-d/2+cut)]
        return block(name,[(x+px,-(z+pz)) for px,pz in corners],h0,h1,material,bevel)

    # Each repeated 4.5-m bay shares clean seams with its neighbors.
    for row in range(4):
        z=2.96+row*1.43
        for col,x in enumerate((-1.125,1.125)):
            slab("Deck tile",x,z,2.234,1.412,.085,-.062,.012,
                 deck_alt if (row+col)%3==0 else deck_coat)
        slab("Four-way seam cap",0,z+.715,.13,.14,.034,-.012,.013,joint,.002)
        slab("Edge seam cap",-2.25,z+.715,.13,.14,.034,-.012,.013,joint,.002)
    slab("Runway lamp pocket",0,4.36,2.87,.105,.043,.012,.018,joint,.002)
    slab("Runway diffuser",0,4.36,2.72,.046,.018,.018,.022,emitter,.001)

    for row in range(5):
        z=-2.91+row*1.97
        slab("Acoustic overhead plate",0,z,4.47,1.946,.055,5.26,5.43,roof)
    slab("Beam upper flange",0,.99,.72,8.95,.08,5.10,5.34,navy)
    slab("Beam lower face",0,.99,.52,8.84,.055,4.91,5.14,beam)
    for z in (0.9,3.85):
        slab("Lamp bezel",0,z,.296,.94,.044,4.863,4.93,iron)
        slab("Ceiling lamp",0,z,.195,.75,.032,4.852,4.87,lamp,.004)
    faceplate("Window lintel",0,4.89,[(4.49,.49,.034,-3.79),(4.49,.49,.034,-2.89),
                                      (4.47,.38,.032,-2.70)],beam)
    export("operations_bay")


def end_bulkhead():
    # The continuous pressure skin overlaps the subdeck, overhead and window sill.
    # Local X runs along the corridor depth when the assembly is installed.
    faceplate("Pressure hull",0,2.61,[(15.0,6.18,.06,-.32),(15.0,6.18,.06,.015)],iron)
    for x in (-6,-3,0,3,6):
        faceplate("Wall cassette",x,2.63,[(2.99,5.70,.14,.018),(2.93,5.60,.17,.085)],navy)
        faceplate("Access cover",x,2.68,[(2.73,3.80,.22,.09),(2.58,3.64,.20,.135)],paint)
        faceplate("Vent recess",x,1.37,[(1.91,.57,.09,.135),(1.83,.51,.07,.157)],iron)
        for row in range(4):
            faceplate("Vent louver",x,1.20+.102*row,[(1.64,.045,.019,.16),(1.59,.037,.016,.19)],rim)
        faceplate("Lamp bezel",x,4.18,[(1.55,.17,.065,.14),(1.46,.14,.05,.17)],iron)
        faceplate("Strip lens",x,4.18,[(1.33,.06,.024,.17),(1.29,.05,.02,.18)],emitter)
        faceplate("Kick plate",x,.25,[(2.99,.73,.04,.06),(2.97,.63,.04,.25)],rim)
        for y in (.74,4.74):
            faceplate("Cassette latch",x+.99,y,[(.21,.082,.025,.09),(.17,.065,.024,.12)],edge)
    export("operations_bulkhead")


builders = {"operations_bulkhead": end_bulkhead, "operations_bay": architectural_bay, "station_platform": station_platform, "station_kiosk": kiosk,
            "operations_sign": station_sign, "deployment_platform": deployment_platform}
targets = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else builders
for target in targets:
    builders[target]()
