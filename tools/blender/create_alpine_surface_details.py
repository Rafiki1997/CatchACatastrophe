"""Native procedural material/decal details for reserved Alpine runtime slots.
Create new textures mathematically; no reference image pixels are edited.
Run in Blender background. Straight-alpha PNGs; no Roblox IDs generated.
"""
import bpy,numpy as np,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/frostbite-peaks/alpine-v2'
N=512;Y,X=np.mgrid[0:N,0:N].astype(np.float32)/(N-1)
rng=np.random.default_rng(903)
dist=[]
for j in range(4):
    for i in range(4):
        px=(i+rng.uniform(.18,.82))/4;py=(j+rng.uniform(.18,.82))/4
        dx=np.abs(X-px);dx=np.minimum(dx,1-dx);dy=np.abs(Y-py);dy=np.minimum(dy,1-dy)
        dist.append(np.sqrt(dx*dx+dy*dy))
ds=np.sort(np.stack(dist),axis=0);gap=ds[1]-ds[0]
crack=np.exp(-(gap/.0025)**2)*.40
bubbles=np.zeros_like(X)
for i in range(55):
    px,py=rng.uniform(0,1,2);r=rng.uniform(.0018,.007)
    dx=np.abs(X-px);dx=np.minimum(dx,1-dx);dy=np.abs(Y-py);dy=np.minimum(dy,1-dy)
    d=np.sqrt(dx*dx+dy*dy)
    bubbles=np.maximum(bubbles,np.exp(-((d-r)/.0011)**2)*rng.uniform(.10,.36))
ice=np.zeros((N,N,4),np.float32)
ice[:,:,:3]=np.array([211,239,249])/255
ice[:,:,3]=np.maximum(crack,bubbles)
def save(name,a):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.alpha_mode='STRAIGHT';im.pixels.foreach_set(a.ravel())
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();return im
save('FP_Alpine_Tex_IceCracks',ice)
track=np.zeros((N,N,4),np.float32);track[:,:,:3]=np.array([128,166,196])/255
mask=np.zeros((N,N),np.float32)
for i in range(6):
    sign=-1 if i%2 else 1;cx=.5+sign*.10;cy=.10+i*.16;ang=sign*.12
    dx=X-cx;dy=Y-cy;u=dx*np.cos(ang)+dy*np.sin(ang);v=-dx*np.sin(ang)+dy*np.cos(ang)
    fore=(u/.047)**2+((v-.014)/.044)**2
    heel=(u/.035)**2+((v+.036)/.025)**2
    body=np.minimum(fore,heel)
    rim=np.exp(-((body-1)/.18)**2)*.37
    fill=np.clip((1-body)*5,0,1)*.15
    tread=(np.cos((v+.06)*270)>.55).astype(np.float32)*np.clip((1-body)*8,0,1)*.05
    mask=np.maximum(mask,np.clip(rim+fill+tread,0,.48))
track[:,:,3]=mask;save('FP_Alpine_Decal_Tracks',track)
assert max(abs(ice[0,:,:]-ice[-1,:,:]).ravel())<.0001
assert max(abs(ice[:,0,:]-ice[:,-1,:]).ravel())<.0001
assert np.count_nonzero(track[:,:,3]>.02)<N*N*.2
(OUT/'surface-details.json').write_text(json.dumps({'source':'native procedural material/detail textures','resolution':[N,N],
    'ice':{'file':'FP_Alpine_Tex_IceCracks.png','tileable':True,'alpha':'straight; pale crack/bubble overlay, no ice plane baked'},
    'tracks':{'file':'FP_Alpine_Decal_Tracks.png','tileable':False,'alpha':'straight; six alternating boot impressions'},
    'integration':'Use existing TextureSlot parts. Art only; no floor, friction, collision or hazard-height changes.'},indent=2))
print('ALPINE_SURFACE_DETAILS_COMPLETE')
