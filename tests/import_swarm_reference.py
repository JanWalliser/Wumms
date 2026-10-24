"""Reproduce numeric balance from archived 14.16 game records, not guide tooltips."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESEARCH = ROOT / 'output/swarm-balance/research'
raw = json.loads((RESEARCH / 'map33-14.16.json').read_text(encoding='utf-8-sig'))
spells = {v['mScriptName']: v['mSpell'] for v in raw.values() if isinstance(v, dict) and 'mSpell' in v and 'mScriptName' in v}
jinx = json.loads((RESEARCH / 'strawberry_jinx-14.16.json').read_text(encoding='utf-8-sig'))
spells.update({v['mScriptName']: v['mSpell'] for v in jinx.values() if isinstance(v, dict) and 'mSpell' in v and 'mScriptName' in v})
balance_path = ROOT / 'assets/balance/swarm-14.16.json'
balance = json.loads(balance_path.read_text(encoding='utf-8-sig'))
fixtures = {}

def values(spell, field):
    result = spells[spell][field] if field == 'cooldownTime' else next(v['mValues'] for v in spells[spell]['mDataValues'] if v['mName'] == field)
    return [round(x, 5) for x in result]

def weapon(id, name, damage, count=None, radius=None, duration=None, modifiers='', cooldown='cooldownTime', **extra):
    spell = 'Augment_Weapon_' + name
    result = {'reference_units': True, 'reference_spell': spell, 'modifiers': modifiers.split(), 'base_damage': values(spell, damage)[1:6], 'evolution_damage': values(spell, damage)[6], 'base_cooldown': values(spell, cooldown)[1:6], 'evolution_cooldown': values(spell, cooldown)[6], 'base_projectiles': [1]*5, 'evolution_projectiles': 1, 'scales_haste': 'haste' in modifiers.split(), 'scales_duration': 'duration' in modifiers.split(), 'scales_projectiles': 'projectiles' in modifiers.split(), 'scales_area': 'area' in modifiers.split(), 'can_crit': 'crit' in modifiers.split()}
    for source, target, evo in [(count, 'base_projectiles','evolution_projectiles'),(radius,'base_radius','evolution_area_radius'),(duration,'base_duration','evolution_duration')]:
        if source:
            arr=values(spell,source)
            result[target],result[evo]=arr[1:6],arr[6]
    result.update(extra)
    fixtures[id] = {'spell': spell, 'mapping':{'damage':damage,'cooldown':cooldown,'count':count,'radius':radius,'duration':duration}, 'fields': {key: values(spell,key) for key in [damage,cooldown,count,radius,duration] if key}}
    balance['weapons'][id] = result

weapon('weapon_uwu_blaster','RapidShot','Damage','ProjectileCount',modifiers='damage haste crit projectiles',range=1200,projectile_speed=2000,projectile_width=40,burst_interval=0.033)
weapon('weapon_ani_mines','Mine_Wrapper','MineDamage','BaseMinesNum','AoERadius',modifiers='damage haste area projectiles',placement_range=275,mine_delay=0.5,secondary_damage=70,secondary_radius=300)
weapon('weapon_anti_shark','FireBomb','Damage',modifiers='damage haste area',range=750,projectile_speed=1000,projectile_width=12,base_bounces=values('Augment_Weapon_FireBomb','Bounces')[1:6],evolution_bounces=999,base_explosion_damage=values('Augment_Weapon_FireBomb','ExplosionDamage')[1:6],evolution_explosion_damage=200,area_radius=400,bounce_range=600)
weapon('weapon_crossbow','PierceShot','Damage','ProjectileCount',modifiers='damage haste crit projectiles',range=1700,projectile_speed=2000,projectile_width=60,base_bonus_crit=values('Augment_Weapon_PierceShot','BonusCritChance')[1:6],evolution_bonus_crit=0.3)
weapon('weapon_blade_o_rang','Boomerang','Damage','ProjectileCount',modifiers='damage haste crit projectiles',range=800,projectile_speed=2500,projectile_width=100)
weapon('weapon_mega_blast','StarStrike','Damage','NumberOfTargets','ExplosionRadius',modifiers='damage haste area crit',range=800,base_bonus_crit=values('Augment_Weapon_StarStrike','BonusCritChance')[1:6],evolution_bonus_crit=0.3)
weapon('weapon_slicers','HolyBauble','BaseDamage','ProjectileCount',duration='Duration',modifiers='damage haste area duration projectiles',projectile_width=100,orbit_radius=200,evolution_projectile_width=130,evolution_orbit_radius=350,orbit_speed=-2.5,hit_lockout=1.0,push_distance=150,visual_size_multiplier=1.5,evolution_visual_size_multiplier=2.0)
weapon('weapon_batblades','ScatterArrows','Damage','ProjectileCount',modifiers='damage haste crit projectiles',range=2000,projectile_speed=1800,projectile_width=12)
weapon('weapon_transit','Train','BaseDamage',modifiers='damage haste crit armor',range=2750,projectile_speed=850,projectile_width=250)
weapon('weapon_gatling','CorkiE','BaseDamage',radius='CastRange',duration='SprayDuration',modifiers='damage haste duration area',base_range=values('Augment_Weapon_CorkiE','CastRange')[1:6],evolution_range=975,tick_interval=0.25,cone_degrees=28,slow_per_stack=0.25,slow_duration=4,stun_duration=6)
weapon('weapon_iceblast','FrostNova','BaseDamage',radius='AoeSize',duration='Duration',modifiers='damage haste area duration armor',cooldown='Cooldown',armor_ratio=2.5,evolution_shield=200,evolution_shield_hp_ratio=0.2)
weapon('weapon_lioness','DianaQ','BaseDamage','ProjectileCount',modifiers='damage haste crit projectiles',range=900,evolution_range=1250,projectile_speed=2100,projectile_width=70)
weapon('weapon_paw_poison','PoisonTrail','BaseDamagePerSecond',radius='BaseSize',duration='CloudDuration',modifiers='damage area duration movement',distance_required=80,tick_interval=0.25,damage_is_dps=True)
weapon('weapon_radiant_field','HollowRadiance','BaseDamage',radius='Radius',modifiers='damage area max_health',base_cooldown=[0.5]*5,evolution_cooldown=0.5,tick_interval=0.5,hp_ratio=0.05)
weapon('weapon_shortbow','FireStrike','BaseDamage','NumberOfTargets','Radius','BaseDuration',modifiers='damage haste area duration projectiles',range=1100,flight_time=0.5,tick_interval=0.5)
weapon('weapon_statikk','StatikkShiv','BaseDamage','TargetCount',modifiers='damage haste area crit duration',range=1100,evolution_duration=3,evolution_tick_damage=80,tick_interval=0.528)
weapon('weapon_tibbers','Tibbers','TibbersBaseDamage',radius='TibbersBaseAoE',duration='TibbersLifetime',modifiers='damage haste area duration movement',range=700,tick_interval=0.5)
weapon('weapon_annihilator','Nuke','Damage',radius='Radius',modifiers='damage haste area',warmup=3)
weapon('weapon_vortex_glove','CircleShot','Damage','ProjectileCount',modifiers='damage crit projectiles',range=1200,projectile_speed=1500,projectile_width=70,rotation_speed=1)
weapon('weapon_yuumibot','TwinShadows','BaseDamage',radius='CollisionDamageSize',duration='Duration',modifiers='damage haste area duration pickup',range=750,pickup_radius=300,tick_interval=0.5)

spell='Strawberry_JinxAutoAttack'
balance['weapons']['weapon_meow_meow']={'reference_units':True,'reference_spell':spell,'base_damage':[20]*5,'evolution_damage':20,'base_projectiles':values(spell,'MinigunBulletCount')[1:6],'evolution_projectiles':7,'base_cooldown':values(spell,'cooldownTime')[1:6],'evolution_cooldown':values(spell,'cooldownTime')[6],'range':1500,'projectile_speed':3500,'projectile_width':90,'pierce':1,'evolution_pierce':999,'evolution_falloff':0.4,'burst_interval':0.066,'scales_area':False,'scales_duration':False,'scales_haste':True,'scales_projectiles':True,'can_crit':True,'modifiers':['damage','haste','crit','projectiles'],'description':'Gezielte Salve. Jede Kugel trifft das erste Ziel. Weiterentwicklung durchdringt mit 40 % Folgetrefferschaden.'}
fixtures['weapon_meow_meow']={'spell':spell,'fields':{f:values(spell,f) for f in ['Damage','MinigunBulletCount','cooldownTime','FallOffDamagePercent']}}
balance['jinx_abilities']={'unit_scale':0.2,'e':{'cooldown':8,'cast_time':0.35,'damage_level_1':55,'damage_per_level':6,'count':9,'range':2200,'speed':1800,'width':80,'radius':300,'angle_degrees':90},'r':{'cooldown':50,'cast_time':0.75,'damage_level_1':500,'damage_per_level':50,'missing_health_amplification':2,'range':2000,'speed':2000,'width':280,'radius':600,'damage_kind':'true'},'passive':{'kills':70,'duration':8,'ability_haste':150,'movement_status':'Existing 35% decaying comfort tuning retained; archived MSBuff script application not available.'}}
# Keep the explicitly requested responsiveness tuning separate from the archived defaults above.
balance['jinx_abilities']['e'].update(cast_time=0.0,speed=3600,angle_degrees=45,display_width=55)
balance['jinx_abilities']['r'].update(cast_time=0.5,speed=4000,display_width=105.6)
balance['jinx_abilities']['tuning_status']='User-requested responsiveness tuning: immediate E, 45-degree fan, double E/R flight speed, 0.5-second R windup, R artwork at 80%. Original damage, range, hit width and explosion radius retained.'
balance['characters']['jankz']['ability_e']={'cooldown':8,'name':'Fischgräten-Festival','ref_name':'Fishbones!','desc':'Neun Raketen plus Projektilbonus im Fächer zum Mauszeiger. Schaden 55 + 6 pro Teamlevel nach Level 1.','unlock_level':3}
balance['characters']['jankz']['ability_r']={'cooldown':50,'name':'Super-Mega-Todesgurke','ref_name':'Super Mega Death Rocket!','desc':'Rakete zum Mauszeiger. Flächenexplosion mit wahrem Schaden, verstärkt durch fehlendes Gegnerleben.','unlock_level':6}
balance['passives']={}
passive_fixtures={}
for id,source in {'ability_haste':'AbilityHaste','area_size':'AoeSize','armor':'Armor','crit_chance':'CritChance','damage':'DamagePercent','duration':'Duration','exp_gain':'Exp','health_regen':'HealthRegen','max_health':'MaxHealth','movement_speed':'Movespeed','pickup_radius':'PickupRadius','projectile_count':'ProjectileCount'}.items():
    balance['passives'][id]={'levels':values('Augment_Stat_'+source,'StatAmount')[:6],'max_level':5}
    passive_fixtures[id]={'spell':'Augment_Stat_'+source,'values':values('Augment_Stat_'+source,'StatAmount')[:6]}
balance['sources']['weapon_numeric_archive']='https://raw.communitydragon.org/14.16/game/data/maps/shipping/map33/map33.bin.json'
balance['sources']['jinx_numeric_archive']='https://raw.communitydragon.org/14.16/game/data/characters/strawberry_jinx/strawberry_jinx.bin.json'
augment_descriptions={
 'armor_up':'Erlittener Schaden gewährt 8 s lang +5 Rüstung pro Stapel; bis zu 10 Stapel.',
 'bite_sized':'-20 % maximales Leben, +20 % Lauftempo und +36 Fähigkeitstempo; kleinere Figur.',
 'bullet_mania':'-15 % Schaden. Alle sechs Levelaufstiege nach Auswahl ein zusätzliches Projektil.',
 'card_collector':'+5 % Schaden pro Zugangskarte nach Auswahl dieses Augments.',
 'celebration':'Nach einem Levelaufstieg 8 s lang +50 % Schaden/Tempo, +60 % Fläche und +50 Fähigkeitstempo.',
 'circle_of_stats':'Wechselt alle 8 s zwischen Tempo, Fähigkeitstempo, Fläche, Projektilen und Regeneration.',
 'critical_expansion':'Kritische Treffer gewähren 5 s lang +1 % Fläche, bis zu 100 Stapel.',
 'cross_country':'Je 20.000 gelaufene Einheiten nach Auswahl +3 % Schaden, Leben und Fläche.',
 'death_and_taxes':'Getötete Gegner haben 2 % Chance auf eine Explosion und zusätzliche Goldbeute.',
 'ebb_and_flow':'Fähigkeitstempo steigt und fällt zyklisch zwischen -50 und +125.',
 'elite_bomber':'+30 % Schaden gegen Elite-Gegner. Besiegte Eliten hinterlassen eine verzögert explodierende Bombe.',
 'emotional_support':'+50 % Schaden für beschworene Begleiter einschließlich des Zugs.',
 'experienced_fighter':'+10 % Team-XP. Gesammelte XP-Kugeln gewähren stapelbare +2 % Schaden/Tempo für 4 s.',
 'gathering_speed':'-15 % Lauftempo; danach +3 % Tempo je weiterem Levelaufstieg.',
 'glass_cannon':'+40 % Schaden, aber -30 % maximales Leben.',
 'heavy_hitter':'+50 % Schaden, aber -30 Fähigkeitstempo.',
 'hoarder':'Gesammeltes Gold heilt jeweils 0,5 % des maximalen Lebens.',
 'immobile_immolation':'Alle 0,5 s Stillstand zunehmend Leben gegen +20 Fähigkeitstempo tauschen; Bewegung beendet den Bonus.',
 'juggernaut':'+10 Rüstung und +0,5 % Schaden pro Rüstungspunkt.',
 'larger_than_life':'+30 % maximales Leben, +30 Regeneration, -15 % Tempo; größere Figur.',
 'long_range':'Bis zu +30 % Schaden abhängig von der Entfernung zum Gegner.',
 'metabolic_overdrive':'-60 % maximales Leben; jede Sekunde 20 % des maximalen Lebens heilen.',
 'mission_critical':'+10 Prozentpunkte Krit-Chance und +25 Prozentpunkte Krit-Schaden (200 → 225 %); nichtkritische Treffer verursachen 20 % weniger Schaden.',
 'pescatarian':'Getötete Gegner haben 25 % Chance auf ein Heilpaket.',
 'pick_me_up':'Kein automatischer Sammelradius, +15 % XP. Alle 60 s XP und Gold auf der Karte anziehen.',
 'point_blank':'Bis zu +20 % Schaden, je näher der Gegner ist.',
 'ramming_runner':'+10 % Tempo. Zusätzliche Tempoänderungen gewähren oder entziehen proportional Schaden.',
 'regenerative_tissue':'Eingesammelte Heilpakete gewähren dauerhaft +5 Regeneration.',
 'size_scrambler':'Die Flächengröße schwankt zwischen -20 % und +60 %; kein zusätzlicher Schadensbonus.',
 'spray_and_pray':'+4 Projektile für unterstützte Waffen, aber -35 % Schaden.',
 'ultimate_speed_up':'+100 Fähigkeitstempo ausschließlich für die R-Fähigkeit.',
 'uptime_upgrade':'+60 % Dauer für dafür vorgesehene Waffen und Fähigkeiten.',
 'with_haste':'+1 % Lauftempo pro 2 Fähigkeitstempo.'}
balance['augments']={'augment_'+id:{'description':text} for id,text in augment_descriptions.items()}
balance['augment_reference_parameters']={name:{v['mName']:round(v['mValues'][0],5) for v in spell.get('mDataValues',[])} for name,spell in spells.items() if name.startswith('Augment_Special_')}
balance['weapon_rework_status']='All 20 general weapons and Jinx numerics imported from archived 14.16 spell records. Server-script-only timings and geometry remain explicitly documented approximations.'
balance_path.write_text(json.dumps(balance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'tests/fixtures').mkdir(exist_ok=True)
(ROOT/'tests/fixtures/swarm-14.16-reference.json').write_text(json.dumps(fixtures,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'tests/fixtures/swarm-passive-reference.json').write_text(json.dumps(passive_fixtures,indent=2)+'\n',encoding='utf-8')
print('Imported 20 general weapons, Jinx, and 12 passives from archive.')
