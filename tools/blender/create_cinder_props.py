"""Build the V2 reusable prop kit. Run with Blender --background --python this_file.

One modeling unit denotes one intended Roblox stud. FBX import scale is verified
at integration, using dimensions recorded in manifest.json. No Studio changes.
"""
import bpy
import bmesh
import json
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'cinder-canyon' / 'props-v1'
OUT.mkdir(parents=True, exist_ok=True)
if (OUT / 'cinder-props.blend').exists():
    raise RuntimeError('Output already exists; choose a new version directory.')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'

# A packed color atlas transfers the facet colors without procedural shaders.
PALETTE = [
    (44, 43, 48), (57, 54, 58), (71, 66, 68), (87, 78, 77),
    (107, 89, 81), (127, 67, 43), (155, 79, 47), (179, 94, 55),
    (199, 113, 66), (219, 141, 86), (112, 52, 26), (180, 69, 16),
    (229, 99, 20), (250, 145, 31), (255, 189, 69), (255, 218, 119),
]
atlas = bpy.data.images.new('CinderPalette', width=256, height=16, alpha=False)
pixels = []
for y in range(16):
    for x in range(256):
        c = PALETTE[x // 16]
        pixels.extend([c[0] / 255, c[1] / 255, c[2] / 255, 1])
atlas.pixels = pixels
atlas.filepath_raw = str(OUT / 'cinder-palette.png')
atlas.file_format = 'PNG'
atlas.save()
atlas.pack()
material = bpy.data.materials.new('Cinder_Palette')
material.use_nodes = True
nodes = material.node_tree.nodes
shader = nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value = 0.82
texture = nodes.new('ShaderNodeTexImage')
texture.image = atlas
texture.interpolation = 'Closest'
material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])

assets_collection = bpy.data.collections.new('EXPORT_ASSETS')
scene.collection.children.link(assets_collection)
preview_collection = bpy.data.collections.new('PREVIEW_ONLY')
scene.collection.children.link(preview_collection)

class MeshBuilder:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.verts, self.faces, self.colors = [], [], []

    def shape(self, rings, sides, center, angles, colors, tilt=(0, 0)):
        """Closed layered irregular prism; rings are (z, rx, ry, phase)."""
        start = len(self.verts)
        for z, rx, ry, phase in rings:
            for a, variation in angles:
                self.verts.append((center[0] + math.cos(a + phase) * rx * variation + tilt[0] * z,
                                   center[1] + math.sin(a + phase) * ry * variation + tilt[1] * z,
                                   center[2] + z))
        self.faces.append(tuple(start + i for i in reversed(range(sides))))
        self.colors.append(colors[0])
        for j in range(len(rings) - 1):
            for i in range(sides):
                self.faces.append((start + j*sides+i, start + j*sides+(i+1)%sides,
                                   start + (j+1)*sides+(i+1)%sides, start + (j+1)*sides+i))
                # Large, coherent bands with occasional side-facet variation.
                self.colors.append(colors[j % len(colors)] + (1 if i % 4 == 0 else 0))
        self.faces.append(tuple(start + (len(rings)-1)*sides+i for i in range(sides)))
        self.colors.append(colors[-1])

    def basalt(self, x, y, radius, height):
        n = 6
        phase = self.rng.uniform(0, 0.7)
        angles = [(i*math.tau/n + phase, self.rng.uniform(0.88, 1.10)) for i in range(n)]
        rings = [(0, radius*.93, radius*.9, 0),
                 (.14, radius, radius*.94, 0),
                 (height*.48, radius*.98, radius*.92, .018),
                 (height-.18, radius*.93, radius*.89, .025),
                 (height, radius*.80, radius*.76, .025)]
        self.shape(rings, n, (x,y,0), angles, [1,2,1,2,3],
                   (self.rng.uniform(-.035,.035), self.rng.uniform(-.035,.035)))

    def crystal(self, x, y, radius, height, tilt):
        n = 5
        phase = self.rng.uniform(0,1)
        angles = [(i*math.tau/n+phase, self.rng.uniform(.9,1.08)) for i in range(n)]
        rings = [(0,radius*.6,radius*.58,0), (.16,radius,radius*.85,0),
                 (height*.66,radius*.83,radius*.72,0),
                 (height*.79,radius*.62,radius*.56,0)]
        self.shape(rings,n,(x,y,.08),angles,[10,12,13,14],tilt)
        # Replace the terminal cap with a sharp, asymmetrical five-facet point.
        self.faces.pop()
        self.colors.pop()
        ring_start = len(self.verts)-n
        tip = len(self.verts)
        self.verts.append((x+tilt[0]*height+.1*radius, y+tilt[1]*height, height+.08))
        for i in range(n):
            self.faces.append((ring_start+i,ring_start+(i+1)%n,tip))
            self.colors.append([14,13,15,12,14][i])

    def sandstone(self, x, y, rx, ry, height):
        n = 9
        phase = self.rng.uniform(0,1)
        angles = [(i*math.tau/n+phase,self.rng.uniform(.88,1.12)) for i in range(n)]
        # Chipped overhanging lips imply horizontal sedimentary strata.
        rings = [(0,rx*.8,ry*.8,0),(.12*height,rx*.96,ry*.93,.018),
                 (.32*height,rx,ry,.025),(.35*height,rx*.92,ry*.94,.025),
                 (.60*height,rx*.88,ry*.9,.035),(.64*height,rx*.82,ry*.87,.035),
                 (.87*height,rx*.77,ry*.79,.05),(height,rx*.59,ry*.62,.065)]
        self.shape(rings,n,(x,y,0),angles,[6,7,6,7,6,8,8,9],(.045,-.025))

    def finish(self, name):
        mesh = bpy.data.meshes.new(name+'_Mesh')
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name='PaletteUV')
        for polygon, swatch in zip(mesh.polygons,self.colors):
            for loop in polygon.loop_indices:
                uv.data[loop].uv = ((min(15,swatch)+.5)/16,.5)
        obj = bpy.data.objects.new(name,mesh)
        assets_collection.objects.link(obj)
        obj.data.materials.append(material)
        # Asset pivot: ground center. All components are individually closed.
        minx,maxx = min(v.co.x for v in mesh.vertices),max(v.co.x for v in mesh.vertices)
        miny,maxy = min(v.co.y for v in mesh.vertices),max(v.co.y for v in mesh.vertices)
        minz = min(v.co.z for v in mesh.vertices)
        for v in mesh.vertices:
            v.co -= Vector(((minx+maxx)/2,(miny+maxy)/2,minz))
        mesh.update()
        bpy.context.view_layer.update()
        return obj

assets = []
basalts = [
    ('CC_Basalt_Tall',[(0,.65,.84,5.8),(-1.2,.35,.73,4.1),(1.15,.4,.8,4.8),(-.65,-.9,.77,2.7),(.75,-.9,.72,3.1),(1.85,-.65,.5,1.8)]),
    ('CC_Basalt_Wide',[(-2,.4,.8,2.6),(-.65,.65,.95,3.6),(.85,.55,.85,4.0),(2.15,.25,.74,2.7),(-1.45,-.95,.7,1.6),(0,-.8,.77,2.1),(1.45,-.85,.75,1.7)]),
    ('CC_Basalt_Low',[(-1,.3,.95,1.6),(.6,.5,.87,2.2),(-.35,-.9,.73,1.1),(1.2,-.8,.65,.8)]),
]
for index,(name,columns) in enumerate(basalts):
    b=MeshBuilder(120+index)
    for column in columns: b.basalt(*column)
    assets.append(b.finish(name))

crystals = [
    ('CC_Ember_Tall',[(0,.3,.55,4.3,(.025,.035)),(-.75,-.1,.37,2.5,(-.19,0)),(.75,.1,.4,2.9,(.12,.04)),(.1,-.65,.29,1.55,(0,-.14))]),
    ('CC_Ember_Fan',[(0,.35,.48,3.3,(.01,0)),(-.7,.1,.38,2.4,(-.25,.02)),(.68,.1,.37,2.55,(.26,.02)),(-.5,-.6,.27,1.4,(-.12,-.08)),(.55,-.5,.29,1.7,(.11,-.12))]),
    ('CC_Ember_Small',[(0,.15,.34,1.8,(.05,0)),(-.5,-.1,.25,1.12,(-.17,0)),(.46,-.2,.23,.95,(.2,-.1))]),
]
for index,(name,spikes) in enumerate(crystals):
    b=MeshBuilder(230+index)
    # Small dark sockets visually join the crystals to the ground.
    b.basalt(-.45,.1,.73,.38)
    b.basalt(.45,.1,.7,.30)
    for spike in spikes: b.crystal(*spike)
    assets.append(b.finish(name))

rocks = [
    ('CC_Sandstone_Wide',[(0,0,2.8,1.65,2.1),(-2.0,-.9,.7,.6,.7)]),
    ('CC_Sandstone_Tall',[(0,0,1.4,1.25,3.5),(1.1,-.7,.65,.75,1.1)]),
    ('CC_Sandstone_Rubble',[(-1.1,.45,1.15,.9,1.25),(1,.35,.9,.75,.95),(-.25,-.85,.7,.6,.65),(1.45,-.85,.4,.35,.4)]),
]
for index,(name,pieces) in enumerate(rocks):
    b=MeshBuilder(340+index)
    for piece in pieces: b.sandstone(*piece)
    assets.append(b.finish(name))

manifest = {'version':1,'units':'1 mesh unit = 1 intended Roblox stud; confirm import scale',
            'pivot':'ground-center','blender_up':'+Z','fbx_up':'+Y',
            'texture':'cinder-palette.png','assets':[]}
for obj in assets:
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    nonmanifold=sum(not edge.is_manifold for edge in bm.edges)
    bm.free()
    obj.data.calc_loop_triangles()
    assert nonmanifold == 0, (obj.name,nonmanifold)
    assert all(poly.area > 1e-8 for poly in obj.data.polygons),obj.name
    assert min(v.co.z for v in obj.data.vertices) >= -1e-5
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.fbx(filepath=str(OUT/(obj.name+'.fbx')),use_selection=True,
        object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
        apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',
        bake_space_transform=False,use_mesh_modifiers=True,mesh_smooth_type='FACE',
        use_triangles=True,path_mode='COPY',embed_textures=True,add_leaf_bones=False,
        bake_anim=False)
    dx,dy,dz=obj.dimensions
    manifest['assets'].append({'name':obj.name,'file':obj.name+'.fbx',
        'dimensions_studs_xyz':[round(dx,3),round(dz,3),round(dy,3)],
        'triangles':len(obj.data.loop_triangles),'nonmanifold_edges':nonmanifold,
        'collision':'decorative; disable collision, use layout collision underneath',
        'glow':'optional Roblox light/effect at placement' if 'Ember' in obj.name else None})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

# Move originals into a labeled gallery AFTER exporting in local coordinates.
for i,obj in enumerate(assets):
    obj.location=((i%3-1)*10,(1-i//3)*9,0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=4.05,depth=.22,
        location=(obj.location.x,obj.location.y,-.14))
    plinth=bpy.context.object
    plinth.name='Preview_Plinth'
    plinth_mat=bpy.data.materials.get('Preview_Plinth') or bpy.data.materials.new('Preview_Plinth')
    plinth_mat.diffuse_color=(.075,.087,.105,1)
    plinth_mat.use_nodes=True
    plinth_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.075,.087,.105,1)
    plinth.data.materials.append(plinth_mat)
    bpy.ops.object.text_add(location=(obj.location.x,obj.location.y-3.6,.025))
    label=bpy.context.object
    label.name='Preview_Label'
    label.data.body=obj.name.replace('CC_','').replace('_',' ').upper()
    label.data.align_x='CENTER'
    label.data.size=.39
    label_mat=bpy.data.materials.get('Preview_Text') or bpy.data.materials.new('Preview_Text')
    label_mat.diffuse_color=(.84,.84,.79,1)
    label_mat.use_nodes=True
    label_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.84,.84,.79,1)
    label.data.materials.append(label_mat)

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.27))
floor=bpy.context.object
floor.name='Preview_Floor'
floor_mat=bpy.data.materials.new('Preview_Floor')
floor_mat.diffuse_color=(.035,.043,.06,1)
floor_mat.use_nodes=True
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.035,.043,.06,1)
floor.data.materials.append(floor_mat)
world=bpy.data.worlds.new('Cinder_Studio')
scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.32,.4,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5

def aim(obj,point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

for location,power,size,color in [((-14,-13,25),6200,15,(1,.86,.72)),((15,2,20),4900,13,(.73,.83,1)),((0,18,24),7000,10,(1,.68,.38))]:
    bpy.ops.object.light_add(type='AREA',location=location)
    light=bpy.context.object
    light.data.energy=power
    light.data.shape='DISK'
    light.data.size=size
    light.data.color=color
    aim(light,(0,0,0))
bpy.ops.object.camera_add(location=(6,-39,48))
camera=bpy.context.object
camera.data.type='ORTHO'
camera.data.ortho_scale=42
aim(camera,(0,0,1))
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1400
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'preview.png')
for obj in list(scene.objects):
    if obj not in assets:
        for collection in list(obj.users_collection): collection.objects.unlink(obj)
        preview_collection.objects.link(obj)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cinder-props.blend'))
bpy.ops.render.render(write_still=True)
print('CINDER_KIT_COMPLETE',json.dumps(manifest))
