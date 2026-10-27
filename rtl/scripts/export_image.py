"""Build ABI2 typed parameter/profile images from immutable integer exports.

Uses existing quantized weights/tables only. The wide logical image is a testing
and host-transfer format, not a physical SRAM placement or resource-fit claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
SCHEMA=json.loads((ROOT/'rtl/config/image_schema.json').read_text())
MASK64=(1<<64)-1

def check_signed(values,bits,name):
 values=np.asarray(values)
 if not np.issubdtype(values.dtype,np.integer):raise ValueError(name+' must be integer')
 if np.any(values<-(1<<(bits-1))) or np.any(values>(1<<(bits-1))-1):raise ValueError(name+' out of signed range')
 return [int(v) for v in values.flat]
def append(target,values):
 offset=len(target);target.extend(values);return offset
def packed_weights(values,bits):
 xs=check_signed(values,bits,'weights');perword=64//bits;result=[]
 for base in range(0,len(xs),perword):
  result.append(sum((v%(1<<bits))<<(i*bits) for i,v in enumerate(xs[base:base+perword])))
 restored=[]
 for i in range(len(xs)):
  v=result[i//perword]>>(i%perword*bits)&((1<<bits)-1)
  restored.append(v-(1<<bits) if v&(1<<(bits-1)) else v)
 assert xs==restored,'Weight roundtrip failed'
 return result

def build(export):
 m=json.loads((export/'manifest.json').read_text())
 if hashlib.sha256((export/'constants.npz').read_bytes()).hexdigest()!=m['constants_sha256']:raise ValueError('Export constants checksum mismatch')
 c=np.load(export/'constants.npz');config=m['config'];mode=m['mode'];depth=mode['exit_block']
 if (config['width'],config['heads'],config['layers'],config['ffn_ratio'],config['group_size'])!=(128,4,4,2,4):raise ValueError('Unsupported model shape')
 if config['window_samples']//config['patch_samples']!=32 or m['attention_scale_multiplier_q20']!=185364 or m['spec']['version']!=2:raise ValueError('Unsupported numeric contract')
 workload=0 if config['classes']==6 else 1 if config['classes']==35 else -1
 if workload<0:raise ValueError('Unsupported workload')
 mode_id=0 if mode['weight_bits']==8 and mode['keep_groups']==8 and not mode['rts'] and depth==4 else 1 if mode['weight_bits']==4 and mode['keep_groups']==6 and mode['rts'] and depth==4 else 2 if mode['weight_bits']==4 and mode['keep_groups']==4 and mode['rts'] and depth==2 else -1
 if mode_id<0:raise ValueError('Unsupported frozen mode')
 if not 0<=m['input_q12_shift']<=16:raise ValueError('Host exponent outside current core state envelope')
 names=['embedding']
 for block in range(4):names.extend(f'blocks.{block}.'+op for op in ['qkv','projection','fc1','fc2'])
 names+=['gate.scorer','classifier','exit_classifier'];assert len(names)==20
 regions={r['kind']:[] for r in SCHEMA['regions']};descriptors=[]
 for slot,name in enumerate(names):
  if name not in m['layers']:descriptors.append([0]*5);continue
  layer=m['layers'][name];bits=layer['weight_bits'];shape=c[name+'.weight'].shape
  if list(shape)!=layer['shape'] or bits not in (4,8):raise ValueError('Inconsistent weight descriptor')
  weight=append(regions['WEIGHT'],packed_weights(c[name+'.weight'],bits));bias=append(regions['BIAS'],check_signed(c[name+'.bias'],40,name+' bias'))
  multipliers=check_signed(c[name+'.multiplier'],32,name+' multiplier')
  if any(v<=0 for v in multipliers):raise ValueError('Nonpositive multiplier')
  mult=append(regions['MULTIPLIER'],multipliers);shift=layer['q12_to_int8_shift']
  if not -50<=shift<=50:raise ValueError('Invalid activation exponent')
  descriptors.append([weight,bias,mult,shift,bits])
 for block in range(depth):
  for suffix in ['norm1','norm2']:regions['GAMMA'].extend(check_signed(c[f'blocks.{block}.{suffix}.gamma'],24,'gamma'))
 regions['GAMMA'].extend(check_signed(c['norm.gamma'],24,'final gamma'))
 regions['POSITION']=check_signed(c['position'],24,'positions')
 regions['PWL']=check_signed(c['silu_knots'],24,'knots')
 for name,key,bits in [('EXP','exp_table',21),('RSQRT','rsqrt_table',31)]:
  values=[int(v) for v in c[key].flat]
  if any(v<0 or v>1<<(bits-1) for v in values):raise ValueError(name+' table range')
  regions[name]=values
 if len(regions['EXP'])!=4097 or len(regions['RSQRT'])!=1024 or len(regions['PWL'])!=9 or len(regions['POSITION'])!=4096:raise ValueError('Table shape')
 profile=[0]*SCHEMA['profile_words'];profile[:16]=[SCHEMA['magic'],SCHEMA['abi_version'],2,workload,mode_id,depth,32,128,4,256,config['classes'],mode['keep_groups'],int(mode['rts']),4,m['input_q12_shift'],185364]
 shifts=[]
 for block in range(depth):
  values=m['attention_qkv_int8_shifts'][f'blocks.{block}']
  if len(values)!=3 or any(not 0<=v<=16 for v in values):raise ValueError('QKV shift range')
  profile[40+block*3:43+block*3]=values;shifts.extend(values)
 regions['SHIFT']=[d[3] for d in descriptors]+[m['input_q12_shift']]+shifts
 for slot,d in enumerate(descriptors):profile[64+5*slot:69+5*slot]=d
 for i,r in enumerate(SCHEMA['regions'][:9]):profile[16+i]=len(regions[r['kind']])
 source_manifest=hashlib.sha256((export/'manifest.json').read_bytes()).digest()
 digest=hashlib.sha256(source_manifest)
 for r in SCHEMA['regions'][:9]:
  for v in regions[r['kind']]:digest.update(struct.pack('<Q',v&MASK64))
 for v in profile:digest.update(struct.pack('<Q',v&MASK64))
 identity=digest.digest()
 # Word zero is the least-significant identity word on the control bus.
 profile[32:40]=[int.from_bytes(identity[i:i+4],'little') for i in range(0,32,4)]
 regions['PROFILE']=profile
 memory=[0]*SCHEMA['bank_words']
 for r in SCHEMA['regions']:
  values=regions[r['kind']]
  if len(values)>r['words']:raise ValueError(r['kind']+' region capacity exceeded')
  memory[r['offset']:r['offset']+len(values)]=[v&MASK64 for v in values]
 return m,regions,memory,identity.hex()

def write_words(path,words):
 path.write_text(''.join(f'{int(v)&MASK64:016x}\n' for v in words))
 # Preserve Python integers: converting mixed signed/unsigned64 words through
 # an inferred NumPy float array would silently destroy low bits.
 restored=[int(line,16) for line in path.read_text().splitlines()]
 assert restored==[int(v)&MASK64 for v in words],'Hex roundtrip failed'

def main():
 p=argparse.ArgumentParser();p.add_argument('--export',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--bank',type=int,default=0);p.add_argument('--vectors',type=Path);args=p.parse_args()
 if not 0<=args.bank<8:raise ValueError('Invalid bank')
 if args.output.exists():raise ValueError('Refusing to overwrite an existing image directory')
 m,regions,memory,identity=build(args.export);args.output.mkdir(parents=True)
 write_words(args.output/'memory.hex',memory);(args.output/'memory.bin').write_bytes(b''.join(struct.pack('<Q',v) for v in memory))
 transfers=[]
 for r in [SCHEMA['regions'][-1],*SCHEMA['regions'][:-1]]:
  values=regions[r['kind']]
  if not values:continue
  filename=r['kind'].lower()+'.bin';(args.output/filename).write_bytes(b''.join(struct.pack('<Q',v&MASK64) for v in values))
  transfers.append({'kind':r['kind'],'bank':args.bank,'offset_words':0,'bytes':len(values)*8,'file':filename,'sha256':hashlib.sha256((args.output/filename).read_bytes()).hexdigest()})
 if args.vectors:
  v=np.load(args.vectors);raw=v['input_int8'];xs=check_signed(raw,8,'host input');words=[]
  for base in range(0,len(xs),8):words.append(sum((value&255)<<(8*i) for i,value in enumerate(xs[base:base+8])))
  write_words(args.output/'input.hex',words);write_words(args.output/'logits.hex',[int(x) for x in v['logits'].flat])
 result={'status':'logical_image_roundtrips_passed_not_physical_memory_fit','identity_sha256':identity,'abi_version':SCHEMA['abi_version'],'bank':args.bank,'source_manifest_sha256':hashlib.sha256((args.export/'manifest.json').read_bytes()).hexdigest(),'source_constants_sha256':hashlib.sha256((args.export/'constants.npz').read_bytes()).hexdigest(),'schema_sha256':hashlib.sha256((ROOT/'rtl/config/image_schema.json').read_bytes()).hexdigest(),'regions':{name:len(values) for name,values in regions.items()},'transfers':transfers,'memory_sha256':hashlib.sha256((args.output/'memory.bin').read_bytes()).hexdigest()}
 (args.output/'image.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'identity':identity,'payload_words':sum(map(len,regions.values())),'regions':result['regions']}))
if __name__=='__main__':main()
