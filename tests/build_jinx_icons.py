"""Author the native SVG HUD family. Each semantic item owns a different motif."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/ui/swarm/jinx-items'
OUT.mkdir(exist_ok=True)

def path(d,fill='url(#metal)',stroke='#071721',width=5):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'
def circle(x,y,r,fill='url(#energy)',stroke='#071721',width=4):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def line(d,color='#eefcff',width=5): return path(d,'none',color,width)
def group(body,transform):return f'<g transform="{transform}">{body}</g>'

heart=path('M128 202 C103 180 51 146 54 104 C57 62 105 51 128 85 C151 51 199 62 202 104 C205 146 153 180 128 202','url(#energy)')
shield=path('M128 38 L197 65 L187 151 Q175 185 128 215 Q81 185 69 151 L59 65 Z')+path('M128 61 L172 79 L166 143 Q152 173 128 188 Z','url(#energy)')
bolt=path('M143 29 L65 143 L116 143 L102 224 L197 105 L146 105 Z','url(#energy)')
boot=path('M98 40 L160 40 L150 128 L190 160 Q215 164 209 192 L55 192 L50 168 L91 140 Z')+line('M106 66 L150 66 M101 89 L147 89 M98 113 L143 113','#e7c072',8)
clock=circle(128,129,83,'url(#metal)')+circle(128,129,66,'#112635')+line('M128 79 L128 131 L165 150','url(#energy)',12)+path('M104 25 H151 V44 H104 Z','url(#gold)')
cross=path('M103 48 H153 V102 H206 V153 H153 V207 H103 V153 H50 V102 H103 Z','url(#energy)')
star=path('M128 34 L153 94 L219 99 L169 142 L185 207 L128 174 L71 207 L87 142 L37 99 L103 94 Z','url(#gold)')
arrow=path('M46 198 L153 91 L130 67 L215 42 L190 126 L166 103 L59 210 Z','url(#energy)')
eye=path('M28 127 C85 56 171 56 228 127 C171 198 85 198 28 127 Z')+circle(128,127,40)+circle(128,127,14,'#efffff')
book=path('M37 59 Q83 42 126 64 Q169 42 218 59 V201 Q171 183 128 205 Q82 183 37 201 Z')+line('M128 69 V196 M56 87 L108 89 M56 111 L108 113 M148 88 L198 85 M148 112 L198 109','#9fe5ef',5)
magnet=path('M55 48 H100 V137 Q100 173 128 173 Q156 173 156 137 V48 H201 V139 Q201 218 128 218 Q55 218 55 139 Z')+path('M55 48 H100 V95 H55 Z M156 48 H201 V95 H156 Z','url(#energy)')
hourglass=path('M76 40 H180 V65 Q180 104 144 127 Q180 150 180 189 V215 H76 V189 Q76 150 112 127 Q76 104 76 65 Z')+path('M93 74 H163 Q159 98 128 115 Q97 98 93 74 Z M91 192 L128 153 L165 192 Z','url(#energy)')
bullets=''.join(group(path('M92 190 V83 L108 51 L124 83 V190 Z','url(#gold)')+line('M98 164 H119','#eef8ff',4),f'translate({i*42-32},0)') for i in range(3))
explosion=path('M129 19 L149 84 L207 46 L177 108 L237 126 L173 147 L207 211 L146 176 L127 238 L105 178 L46 213 L77 149 L18 129 L82 107 L45 47 L107 81 Z','url(#energy)')+circle(128,128,34,'#fff3bb')
claw=''.join(path(f'M{60+i*49} 210 Q{29+i*49} 109 {87+i*49} 33 Q{67+i*49} 136 {83+i*49} 195 Z','url(#metal)') for i in range(3))
skull=path('M67 163 Q38 119 60 76 Q81 30 128 35 Q184 30 203 78 Q222 124 190 163 L173 163 V208 H83 V163 Z')+circle(97,116,21,'#10202d')+circle(159,116,21,'#10202d')+path('M128 145 L113 166 H143 Z','#10202d')+line('M109 184 V207 M146 184 V207','#152936',5)
feather=path('M50 211 L101 84 Q149 19 218 39 Q226 110 154 158 Z','url(#energy)')+line('M52 210 L188 69 M91 170 L98 114 M128 135 L175 129','#f6eed8',6)
wave=''.join(line(f'M{47+i*43} {181-i*9} Q{112+i*17} 127 {47+i*43} {73+i*9}','url(#energy)',12) for i in range(4))
mine=circle(128,132,65,'url(#metal)')+''.join(group(path('M115 68 L122 29 H135 L143 68 Z','url(#gold)'),f'rotate({i*60},128,132)') for i in range(6))+circle(128,132,33)
gun=path('M47 100 H112 L130 74 H207 V118 H143 L126 158 H100 L81 201 H49 L73 137 H47 Z')+path('M126 80 H213 V102 H126 Z','url(#energy)')+circle(99,115,21,'url(#gold)')
gatling=path('M37 109 L72 78 H140 V157 H72 L37 139 Z','url(#gold)')+''.join(path(f'M119 {80+i*24} H219 V{96+i*24} H119 Z') for i in range(3))+path('M47 89 L39 33 Q62 28 81 82 Z M79 79 L85 30 Q107 32 107 81 Z','url(#energy)')+circle(83,119,18)
bow=path('M68 44 Q210 118 68 208 L85 168 Q149 126 85 84 Z','url(#gold)')+line('M68 44 L101 126 L68 208','#e9f7ff',4)+group(arrow,'translate(25,30) scale(.72)')
boomerang=path('M37 191 L90 50 Q100 34 117 53 L221 164 L185 190 L109 101 L72 203 Z')+line('M57 180 L101 69 L201 172','url(#energy)',8)
train=path('M60 47 Q128 15 196 47 V184 L172 216 H84 L60 184 Z','url(#gold)')+path('M78 63 H178 V112 H78 Z','url(#energy)')+circle(87,153,12,'#fff4cc')+circle(169,153,12,'#fff4cc')+line('M92 192 H164 M78 219 L65 238 M178 219 L191 238','#d4e2ea',8)
cat=circle(128,137,70,'url(#metal)')+path('M62 100 L56 38 L107 72 M149 72 L201 38 L194 102','url(#energy)')+circle(103,131,13)+circle(153,131,13)+line('M108 166 Q128 185 148 166','#e7a1dd',8)
bear=circle(66,67,29,'url(#gold)')+circle(190,67,29,'url(#gold)')+circle(128,123,86,'url(#metal)')+circle(97,108,13)+circle(159,108,13)+path('M101 151 Q128 127 155 151 L146 177 H110 Z','url(#gold)')
paw=''.join(circle(x,y,r,'url(#energy)') for x,y,r in [(63,90,23),(105,58,23),(152,58,23),(195,90,23),(128,157,52)])
snow=''.join(group(line('M128 37 V219 M109 54 L128 75 L147 54 M109 202 L128 181 L147 202','#dffaff',9),f'rotate({i*60},128,128)') for i in range(3))+circle(128,128,19)
slicer=circle(128,128,76,'url(#gold)')+''.join(group(path('M117 64 L124 26 L161 32 L153 73 Z'),f'rotate({i*90},128,128)') for i in range(4))+circle(128,128,50,'#b56d35')+''.join(circle(x,y,5,'#f2d48a','none') for x,y in [(103,110),(139,92),(155,128),(116,151),(149,153),(95,140)])+circle(128,128,14)
vortex=''.join(group(path('M128 121 Q218 32 206 125 Q199 195 118 192 Q179 170 166 139 Q150 117 128 121 Z','url(#energy)'),f'rotate({i*120},128,128)') for i in range(3))+circle(128,128,17,'#f3f8ff')
ring=circle(128,128,86,'#0d2336')+circle(128,128,66,'url(#energy)')+circle(128,128,47,'#12283a')+''.join(circle(128+x,128+y,9,'url(#gold)') for x,y in [(0,-84),(84,0),(0,84),(-84,0)])
rocket=path('M50 204 L81 139 L60 123 L107 108 Q144 44 212 33 Q213 101 149 147 L133 195 L114 174 Z')+path('M109 110 L146 146 L181 108 L145 73 Z','url(#energy)')+path('M68 180 L42 219 L93 196 Z','url(#gold)')
hand=path('M74 213 L59 138 Q50 107 72 104 L93 135 L89 65 Q92 43 106 59 L115 119 L121 43 Q128 25 141 45 L139 119 L155 60 Q168 43 178 63 L161 132 L184 101 Q204 91 207 113 L178 185 L151 213 Z')+circle(130,153,27)
card=path('M69 37 L204 59 L178 221 L43 200 Z','url(#gold)')+path('M89 64 L176 80 L159 176 L72 160 Z','#17334b')+group(star,'translate(66,73) scale(.39)')
coin=circle(128,128,82,'url(#gold)')+circle(128,128,61,'#af7834')+star

weapons={
'weapon_uwu_blaster':(gun,'#68eaff'), 'weapon_ani_mines':(mine,'#ffa958'),
'weapon_anti_shark':(mine+path('M77 108 L127 78 L178 108 L163 167 H94 Z','url(#energy)')+line('M103 144 H152','#102434',8),'#72bdff'),
'weapon_crossbow':(bow,'#70ebd6'),'weapon_blade_o_rang':(boomerang,'#a3a1ff'),
'weapon_mega_blast':(explosion+group(rocket,'translate(66,60) scale(.5)'),'#ffa74b'),
'weapon_slicers':(slicer,'#e7af64'),'weapon_batblades':(path('M24 74 L94 105 L128 54 L162 105 L232 74 L209 164 L170 145 L128 206 L86 145 L47 164 Z')+circle(128,127,17),'#c49aff'),
'weapon_transit':(train,'#71deff'),'weapon_gatling':(gatling,'#ffb450'),
'weapon_iceblast':(shield+group(snow,'translate(68,72) scale(.47)'),'#9cefff'),
'weapon_lioness':(path('M160 27 Q25 119 169 227 Q69 212 49 133 Q35 46 160 27 Z','url(#gold)')+group(star,'translate(101,37) scale(.42)'),'#ffdf89'),
'weapon_paw_poison':(paw+circle(189,193,22,'#addb75'),'#9ee77a'),
'weapon_radiant_field':(ring,'#c898ff'),'weapon_shortbow':(bow+group(explosion,'translate(124,122) scale(.32)'),'#ff9651'),
'weapon_statikk':(bolt+line('M45 200 L200 45','#f4f6ff',12),'#ada3ff'),
'weapon_tibbers':(bear,'#e0a16a'),'weapon_annihilator':(explosion+circle(128,128,46,'#192d40')+group(bolt,'translate(84,78) scale(.38)'),'#efdf76'),
'weapon_vortex_glove':(hand,'#8eaeff'),'weapon_yuumibot':(cat,'#f19ed9'),'weapon_meow_meow':(gatling,'#f574b8')}
passives={'max_health':(heart,'#ee718c'),'armor':(shield,'#94c7eb'),'health_regen':(cross,'#71e8a4'),'movement_speed':(boot,'#7ee7e6'),'crit_chance':(eye,'#f9b77d'),'damage':(claw,'#ed8c8e'),'ability_haste':(clock,'#80c5ff'),'duration':(hourglass,'#e1baee'),'area_size':(ring+line('M128 12 V57 M128 199 V244 M12 128 H57 M199 128 H244','#f9e5b7',10),'#a99aff'),'projectile_count':(bullets,'#f8cb86'),'exp_gain':(book,'#99d9fa'),'pickup_radius':(magnet,'#db97df')}
def mini(symbol): return group(symbol,'translate(136,137) scale(.42)')
# Secondary symbols encode the particular augment, rather than reusing one star icon.
augments={
'armor_up':(shield+mini(arrow),'#a6d9f5'), 'bite_sized':(group(bear,'translate(41,23) scale(.7)')+mini(boot),'#f3b77c'),
'bullet_mania':(bullets+mini(explosion),'#f6a77a'),'card_collector':(card+mini(coin),'#e7c26f'),
'celebration':(explosion+mini(star),'#f1a1db'),'circle_of_stats':(ring+mini(clock),'#9bdbd1'),
'critical_expansion':(eye+mini(ring),'#efb5f2'),'cross_country':(boot+mini(arrow),'#a6d780'),
'death_and_taxes':(skull+mini(coin),'#eccb74'),'ebb_and_flow':(wave+mini(clock),'#7abde9'),
'elite_bomber':(mine+mini(skull),'#e8a06a'),'emotional_support':(bear+mini(heart),'#ecb6d6'),
'experienced_fighter':(book+mini(claw),'#a0cdee'),'gathering_speed':(boot+mini(clock),'#6ed8b6'),
'glass_cannon':(gun+mini(heart),'#f19b9a'),'heavy_hitter':(claw+mini(hourglass),'#e2ae79'),
'hoarder':(coin+mini(cross),'#e7ce83'),'immobile_immolation':(explosion+mini(boot),'#f28f5c'),
'juggernaut':(shield+mini(claw),'#d4d2bc'),'larger_than_life':(bear+mini(arrow),'#f4cc90'),
'long_range':(arrow+mini(eye),'#9cceef'),'metabolic_overdrive':(heart+mini(bolt),'#d2e891'),
'mission_critical':(eye+mini(star),'#ed9cc0'),'pescatarian':(path('M39 123 Q100 42 185 110 L228 77 V179 L185 146 Q100 222 39 123 Z','url(#metal)')+circle(76,116,9)+mini(cross),'#9cd6d4'),
'pick_me_up':(magnet+mini(clock),'#d3a0ee'),'point_blank':(eye+mini(gun),'#e99d72'),
'ramming_runner':(boot+mini(claw),'#ffbb6a'),'regenerative_tissue':(cross+mini(feather),'#8fdea8'),
'size_scrambler':(ring+mini(wave),'#caa2ed'),'spray_and_pray':(bullets+mini(hand),'#e7b28a'),
'ultimate_speed_up':(rocket+mini(clock),'#ed98bd'),'uptime_upgrade':(hourglass+mini(arrow),'#c9b7f1'),
'with_haste':(clock+mini(boot),'#91e2e4')}
abilities={'jinx_e':(''.join(group(rocket,f'translate({i*49-8},{i*12}) scale(.65)') for i in range(3)),'#6de0ef'), 'jinx_passive':(heart+mini(bolt),'#ef80cc'),'jinx_r':(rocket,'#ee98b8')}
entries={**weapons,**passives,**{'augment_'+k:v for k,v in augments.items()},**abilities}
manifest={}
for i,(id,(body,color)) in enumerate(entries.items(),100):
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><defs>
    <radialGradient id="bg"><stop stop-color="{color}" stop-opacity=".38"/><stop offset="1" stop-color="#09131f"/></radialGradient>
    <linearGradient id="metal" x2=".8" y2="1"><stop stop-color="#f3f4df"/><stop offset=".35" stop-color="#a6c0cf"/><stop offset=".5" stop-color="#536e83"/><stop offset=".73" stop-color="#c4d9dc"/><stop offset="1" stop-color="#3a5265"/></linearGradient>
    <linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#fff0b0"/><stop offset=".4" stop-color="#deae5a"/><stop offset=".6" stop-color="#82512b"/><stop offset="1" stop-color="#f0cf84"/></linearGradient>
    <linearGradient id="energy" x2=".7" y2="1"><stop stop-color="#f6fff8"/><stop offset=".32" stop-color="{color}"/><stop offset="1" stop-color="{color}" stop-opacity=".6"/></linearGradient></defs>
    <rect x="2" y="2" width="252" height="252" rx="12" fill="#08131e" stroke="#917947" stroke-width="4"/><rect x="7" y="7" width="242" height="242" rx="8" fill="url(#bg)" stroke="{color}" stroke-opacity=".35" stroke-width="2"/>
    <g transform="translate(15,12) scale(.88)">{body}</g><path d="M15 35 V15 H35 M221 241 H241 V221" fill="none" stroke="#e2c482" stroke-width="3"/></svg>'''
    (OUT/(id+'.svg')).write_text(svg,encoding='utf-8')
    if id in ['weapon_blade_o_rang','weapon_batblades','weapon_lioness','weapon_statikk']:
        # World sprites use the authored silhouette with alpha, without the HUD panel.
        world=svg[:svg.index('    <rect')]+f'<g transform="translate(15,12) scale(.88)">{body}</g></svg>'
        (ROOT/'assets/projectiles/arsenal'/('world-'+id+'.svg')).write_text(world,encoding='utf-8')
    manifest[id]={'index':i,'path':'res://assets/ui/swarm/jinx-items/'+id+'.res'}
    if (OUT/(id+'-painted.png')).exists(): manifest[id]['path']='res://assets/ui/swarm/jinx-items/'+id+'-painted.res'
# Polished painted signature/R images supersede the matching native sources.
for id,name in [('weapon_meow_meow','jinx-signature-icon'),('jinx_r','jinx-ultimate-icon'),('jinx_e','jinx-e-painted-icon'),('weapon_slicers','schnitzel-painted-icon'),('weapon_gatling','gatling-painted-icon'),('weapon_uwu_blaster','uwu-painted-icon')]:
    manifest[id]['path']='res://assets/ui/swarm/jinx-items/'+name+'.res'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
icon_script=ROOT/'scripts/ui/swarm_icons.gd'
lines=icon_script.read_text(encoding='utf-8').splitlines()
for i,line in enumerate(lines):
    if line.startswith('const ITEM_PATHS := '): lines[i]='const ITEM_PATHS := '+json.dumps({str(v['index']):v['path'] for v in manifest.values()},separators=(',',':'))
icon_script.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'Authored {len(manifest)} individually mapped Jinx icons.')

