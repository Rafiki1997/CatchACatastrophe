"""Reusable V2 Alpine Expedition art; fitted landmarks await Claude's layout.
Run with Blender 5.1 --background --python tools/blender/create_frostbite_props.py.
No Studio changes. Uses the existing tested palette/export/gallery helpers.
"""
import importlib.util
import math
import random
from pathlib import Path
from mathutils import Vector

source=Path(__file__).with_name('create_garden_bay_props.py')
spec=importlib.util.spec_from_file_location('region_kit',source)
kit=importlib.util.module_from_spec(spec);spec.loader.exec_module(kit)
kit.PALETTE[:8]=[(56,76,97),(78,99,120),(107,133,151),(147,170,186),
    (172,196,209),(192,218,232),(222,237,242),(241,246,240)]
kit.PALETTE[16:21]=[(32,65,61),(43,82,69),(57,103,82),(79,123,96),(109,144,111)]
kit.start('frostbite-peaks')
assets=[]

def snowrock(name,tall=False):
    kit.blob((0,0,1.65 if tall else .95),
             (1.55,1.3,1.8) if tall else (2.4,1.65,1.2),[0,1,2,3],61 if tall else 54)
    # Coherent white caps with a few hanging lobes, not a differently colored boulder.
    top=3.05 if tall else 1.88
    kit.blob((-.13,.05,top),(1.43 if tall else 2.2,1.22 if tall else 1.5,.45),[5,6,7,6],22)
    for i,(x,y,s) in enumerate([(-.8,-.75,.55),(.65,-.8,.6),(.85,.55,.45)]):
        kit.blob((x,y,top-.18),(s,s*.75,.5),[5,6,7],83+i)
    kit.blob((1.35,-.75,.32),(.64,.6,.44),[1,2,3],92)
    kit.blob((1.35,-.75,.62),(.55,.5,.2),[6,7],45)
    return kit.finish(name)

assets.extend([snowrock('FP_Snow_Rock_Wide'),snowrock('FP_Snow_Rock_Tall',True)])

def fir(name,height,radius):
    kit.beam((0,0,0),(.12,0,height*.83),radius*.14,[8,9,10],9)
    for j,(base,span,spread) in enumerate([(.17,.43,1),(.37,.40,.78),(.59,.41,.56)]):
        x=.12*j;z=height*base;h=height*span;r=radius*spread;n=12
        # Three layered fir skirts with irregular lower hems and snow overhangs.
        phase=.12*j;verts=[]
        rng=random.Random(140+j)
        irregular=[rng.uniform(.92,1.07) for i in range(n)]
        for level,rr in [(0,r),(.3*h,r*.77),(h,.06)]:
            for i in range(n):
                a=i*math.tau/n+phase
                verts.append((x+math.cos(a)*rr*irregular[i],math.sin(a)*rr*irregular[i],z+level+(i%2)*.11))
        faces=[tuple(reversed(range(n)))]
        for k in range(2):
            for i in range(n):faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
        faces.append(tuple(2*n+i for i in range(n)))
        kit.mesh('FirSkirt',verts,faces,[16,17,18])
        snowverts=[]
        for level,rr in [(.18,r*.98),(.3*h+.18,r*.80),(h+.16,.075)]:
            for i in range(n):
                a=i*math.tau/n+phase
                snowverts.append((x+math.cos(a)*rr*irregular[i],math.sin(a)*rr*irregular[i],z+level+(i%2)*.1))
        kit.mesh('FirSnow',snowverts,faces,[5,6,7,6])
    return kit.finish(name)

assets.extend([fir('FP_Snow_Fir_Tree',9,2.5),fir('FP_Snow_Fir_Sapling',4.8,1.45)])
kit.blob((0,0,.38),(2.45,1.45,.7),[5,6,7,6],91)
kit.blob((1.3,-.4,.18),(1.1,.85,.42),[6,7],67)
assets.append(kit.finish('FP_Snow_Drift'))

# Icicles point down, their bases joined by a narrow snow/ice lip at the top.
kit.beam((-1.55,0,2.05),(1.55,0,2.05),.18,[5,6,7])
for i in range(7):
    x=-1.38+i*.46;length=[1.1,1.6,1.25,2,1.45,1.8,1.0][i]
    kit.lathe([(2.0-length,.022),(2.0-length*.22,.15),(2.0,.22)],(x,(i%2)*.09,0),6,[3,4,5,6])
assets.append(kit.finish('FP_Icicle_Cluster'))

def box(center,size,color):
    x,y,z=center;sx,sy,sz=[v/2 for v in size]
    verts=[(x+a*sx,y+b*sy,z+c*sz) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return kit.mesh('CrateBoard',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],color)

box((0,0,1.1),(2.3,2.3,2.2),[9,10,11])
for side in (-1,1):
    for x in (-.92,.92):box((x,side*1.18,1.1),(.18,.16,2.18),11)
    for z in (.15,2.06):box((0,side*1.19,z),(2.3,.16,.17),10)
    # X braces on front and rear; rough-hewn four-sided beams.
    kit.beam((-.85,side*1.22,.28),(.85,side*1.22,1.95),.105,11,4)
    kit.beam((.85,side*1.22,.28),(-.85,side*1.22,1.95),.105,11,4)
    for y in (-.85,.85):box((side*1.18,y,1.1),(.16,.16,2.15),10)
    for y in (-.5,0,.5):box((side*1.158,y,1.1),(.035,.025,1.75),8)
kit.blob((-.4,.1,2.25),(1.05,.95,.16),[5,6,7],55)
assets.append(kit.finish('FP_Supply_Crate'))

# A single continuous low-poly rope spirals inward with a loose trailing end.
points=[]
turns=3.3
for i in range(161):
    t=i/160;a=t*math.tau*turns;r=1.08-.76*t
    points.append(Vector((math.cos(a)*r,math.sin(a)*r,.15+.025*math.sin(a))))
verts=[];sides=6
for i,p in enumerate(points):
    tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
    side=tangent.cross(Vector((0,0,1))).normalized();up=side.cross(tangent).normalized()
    for j in range(sides):
        a=j*math.tau/sides;verts.append(p+side*(math.cos(a)*.105)+up*(math.sin(a)*.105))
faces=[tuple(reversed(range(sides)))]
for i in range(len(points)-1):
    for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
kit.mesh('Rope',verts,faces,[10,11,11])
kit.beam((1.08,0,.15),(1.45,-.5,.15),.1,11,6)
assets.append(kit.finish('FP_Rope_Coil'))

kit.deliver(assets,'FrostbitePropsBundle','FROSTBITE PEAKS / ALPINE EXPEDITION')
