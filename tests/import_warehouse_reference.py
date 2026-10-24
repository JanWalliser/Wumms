"""Import the linked Warehouse wave definitions and cumulative XP curve from 14.16."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
x=json.loads((root/'output/swarm-balance/research/map33-14.16.json').read_text(encoding='utf-8-sig'))
mode=x['Maps/Shipping/Map33/Modes/STRAWBERRY']
curve=x[mode['mExperienceCurveData']]['mExperienceRequiredPerLevel']
fixed=list(map(int,curve))
# The archive contains a single descending entry at 91; restore the surrounding +910 step.
fixed[90]=39035
phases=[]
t=3.0
for i,p in enumerate(x['{7cd8af79}']['SubPhases']):
 waves=[]
 for ref in p.get('{a42117a5}',[]):
  for wave_ref in x[ref]['Waves']:
   w=x[wave_ref]
   if not w['name'].startswith('MapA_'): raise ValueError(w['name'])
   entry=dict(w,reference_id=wave_ref)
   child=w.get('{a8705448}',{}).get('WaveToSpawn')
   if child: entry['child_wave']=x[child]
   waves.append(entry)
 phases.append(dict(index=i+1,start=t,end=t+p['duration'],type=p['type'],waves=waves))
 t+=p['duration']
out={'source':'https://raw.communitydragon.org/14.16/game/data/maps/shipping/map33/map33.bin.json','experience':{'cumulative_raw':curve,'cumulative':fixed,'repairs':{'91':'19035 -> 39035: descending archive anomaly; adjacent cumulative steps 900/910/920.'},'interpretation':'Cumulative thresholds; per-level display cost is the difference. Existing strict threshold convention (> display cost) retained.'},'phases':phases,'event_schedule':{'mission':[150,450,750],'trial':[240,540,810],'supply':[90,270,390,570,690,870]},'event_schedule_status':'Approximate windows from public gameplay descriptions. Server spire scripts were not present in map33; not claimed exact. No invented global ten-second spawn pause: long 8/10-second intervals exist in the original waves.'}
(root/'assets/balance/warehouse-14.16.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Imported',len(phases),'phases;',sum(len(p['waves']) for p in phases),'wave definitions; XP level 24 display cost',fixed[23]-fixed[22])
