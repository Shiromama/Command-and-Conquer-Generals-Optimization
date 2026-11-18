"""Compare production GPU shadow masks with independent analytic box/plane ray visibility."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('depth_bmp',type=Path)
parser.add_argument('--screen',action='store_true',help='Check INTZ fullscreen receiver mask')
args=parser.parse_args();base=args.depth_bmp
metadata=json.loads(Path(str(base)+'.calibration.json').read_text())
assert metadata['depth_dump_hr']==metadata['mask_dump_hr']==0,metadata
if args.screen:assert metadata['intz_hr']==metadata['screen_mask_hr']==0,metadata
mask=np.asarray(Image.open(str(base)+('.screen-mask.bmp' if args.screen else '.mask.bmp')).convert('L'))
n=metadata['resolution'];assert mask.shape==(n,n)
coord=(np.arange(n)+0.5)*2/n-1
sx,sy=np.meshgrid(coord,-coord)
eye=np.array(metadata.get('camera_eye',[0,0,300]),dtype=float)
forward=-eye/np.linalg.norm(eye)
right=np.cross(forward,[0,1,0]);right/=np.linalg.norm(right)
up=np.cross(right,forward)
perspective=metadata.get('perspective',False)
if perspective:
 scale=metadata['tan_half_fov'];origin=[np.full((n,n),v) for v in eye]
 direction=[forward[i]+right[i]*sx*scale+up[i]*sy*scale for i in range(3)]
else:
 origin=[eye[i]+right[i]*sx*100+up[i]*sy*100 for i in range(3)]
 direction=[np.full((n,n),v) for v in forward]

def box_interval(origins,directions):
 near=np.full((n,n),-np.inf);far=np.full((n,n),np.inf);possible=np.ones((n,n),dtype=bool)
 for o,d,lo,hi in zip(origins,directions,metadata['box_min'],metadata['box_max']):
  if np.ndim(d)==0 and abs(d)<1e-9:possible&=(o>=lo)&(o<=hi)
  else:
   nonzero=np.abs(d)>1e-9
   safe=np.where(nonzero,d,1.0)
   a=(lo-o)/safe;b=(hi-o)/safe
   near=np.maximum(near,np.where(nonzero,np.minimum(a,b),-np.inf))
   far=np.minimum(far,np.where(nonzero,np.maximum(a,b),np.inf))
   possible&=nonzero|((o>=lo)&(o<=hi))
 return near,far,possible
near,far,hit=box_interval(origin,direction)
plane_t=-origin[2]/direction[2]
box_visible=hit&(far>=np.maximum(near,0))&(near>0)&(near<plane_t)
surface_t=np.where(box_visible,near,plane_t)
position=[o+d*surface_t for o,d in zip(origin,direction)]
x,y,z=position
visible=box_visible|((plane_t>0)&(np.abs(x)<=100)&(np.abs(y)<=100))
near,far,hit=box_interval(position,metadata['light'])
expected=visible&hit&(far>np.maximum(near,1e-3))
# Exclude a 2.5-world-unit edge band; classification must be stable at eight neighbours.
world_span=2*metadata['tan_half_fov']*np.linalg.norm(eye) if perspective else 200
margin=int(np.ceil(2.5*n/world_span));stable=np.ones((n,n),dtype=bool)
for dy in [-margin,0,margin]:
 for dx in [-margin,0,margin]:stable&=(expected==np.roll(np.roll(expected,dy,axis=0),dx,axis=1))
stable[:margin]=False;stable[-margin:]=False;stable[:,:margin]=False;stable[:,-margin:]=False
actual=mask<128;mismatch=stable&(expected!=actual)
roof_core=box_visible&(np.abs(z-40)<1e-3)&(np.abs(x)<15)&(np.abs(y)<15)
result=dict(metadata=metadata,pixels=int(mask.size),stable_pixels=int(stable.sum()),mismatches=int(mismatch.sum()),mismatch_fraction=float(mismatch.sum()/stable.sum()),expected_shadow_pixels=int(expected.sum()),actual_shadow_pixels=int(actual.sum()),roof_core_pixels=int(roof_core.sum()),roof_core_shadow_pixels=int((actual&roof_core).sum()),grayscale_values=[int(v) for v in np.unique(mask)])
projection_path=Path(str(base)+'.screen-projection.json')
if args.screen and projection_path.exists():
 projection=json.loads(projection_path.read_text())
 result['projection_normalization']=projection['normalization']
 result['maximum_pixel_constant']=max(abs(v) for v in projection['pixel_constants'])
 assert result['maximum_pixel_constant']<=1.0,projection
result['pass']=result['mismatch_fraction']<0.001 and result['roof_core_pixels']>0 and result['roof_core_shadow_pixels']==0
if Path(str(base)+'.screen-depth.bmp').exists():
 depth=np.asarray(Image.open(str(base)+'.screen-depth.bmp').convert('L'))/255.0
 distance=sum((position[i]-eye[i])*forward[i] for i in range(3))
 predicted=np.where(visible,601/600-601/(600*distance) if perspective else (distance-1)/600,1.0)
 depth_core=visible.copy()
 for dy in [-margin,0,margin]:
  for dx in [-margin,0,margin]:depth_core&=(box_visible==np.roll(np.roll(box_visible,dy,axis=0),dx,axis=1))
 depth_core&=stable
 max_error=float(np.abs(depth-predicted)[depth_core].max())
 result['sampled_depth_max_error']=max_error
 result['sampled_depth_quantization_limit']=1/255
 result['pass']&=max_error<=1/255
suffix='.screen-comparison.json' if args.screen else '.comparison.json'
Path(str(base)+suffix).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
Image.fromarray(np.uint8(expected)*255).save(str(base)+'.expected-shadow.png')
print(json.dumps(result,indent=2))
if not result['pass']:raise SystemExit(2)
