"""Audit ABI2 images for all frozen exports, including full parameter reconstruction."""
import hashlib,json
from pathlib import Path
import numpy as np
from export_image import build,SCHEMA,MASK64
ROOT=Path(__file__).resolve().parents[2]
def main():
 models=json.loads((ROOT/'results/software_release_v1/catalog.json').read_text())['models'];reports=[]
 for item in models:
  export=ROOT/item['export'];m,regions,memory,identity=build(export);c=np.load(export/'constants.npz');profile=regions['PROFILE'];slots=['embedding']
  for block in range(4):slots.extend(f'blocks.{block}.'+op for op in ['qkv','projection','fc1','fc2'])
  slots+=['gate.scorer','classifier','exit_classifier'];values=0
  for slot,name in enumerate(slots):
   wbase,bbase,mbase,shift,bits=profile[64+5*slot:69+5*slot]
   if name not in m['layers']:assert bits==0;continue
   weights=c[name+'.weight'];perword=64//bits;restored=[]
   for i in range(weights.size):
    word=memory[SCHEMA['regions'][0]['offset']+wbase+i//perword];v=(word>>(i%perword*bits))&((1<<bits)-1)
    restored.append(v-(1<<bits) if v&(1<<(bits-1)) else v)
   assert np.array_equal(np.asarray(restored).reshape(weights.shape),weights)
   n=weights.shape[0]
   for kind,base,key in [('BIAS',bbase,'.bias'),('MULTIPLIER',mbase,'.multiplier')]:
    offset=next(r['offset'] for r in SCHEMA['regions'] if r['kind']==kind)+base
    restored=[x-(1<<64) if x&(1<<63) else x for x in memory[offset:offset+n]]
    assert np.array_equal(restored,c[name+key]);values+=n
   values+=weights.size
  for i,r in enumerate(SCHEMA['regions']):
   assert memory[r['offset']:r['offset']+len(regions[r['kind']])]==[v&MASK64 for v in regions[r['kind']]]
   if i<9:assert profile[16+i]==len(regions[r['kind']])
  assert profile[32:40]==[int.from_bytes(bytes.fromhex(identity)[i:i+4],'little') for i in range(0,32,4)]
  reports.append({'case':item['name'],'family':item['family'],'identity':identity,'exact_parameter_values':values,'payload_words':sum(map(len,regions.values())),'status':'passed'})
 result={'status':'passed','models':reports,'schema_sha256':hashlib.sha256((ROOT/'rtl/config/image_schema.json').read_bytes()).hexdigest(),'exporter_sha256':hashlib.sha256((ROOT/'rtl/scripts/export_image.py').read_bytes()).hexdigest(),'limits':'Host serialization/descriptor audit only; no physical memory placement or whole-RTL equivalence.'}
 out=ROOT/'rtl/build/images';out.mkdir(parents=True,exist_ok=True);(out/'image_audit.json').write_text(json.dumps(result,indent=2)+'\n');print('Image audit passed for',len(reports),'frozen exports')
if __name__=='__main__':main()
