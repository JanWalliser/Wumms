extends RefCounted

static var _atlas: Texture2D
static var _cache: Dictionary = {}
const WEAPONS := {"weapon_uwu_blaster":100,"weapon_ani_mines":101,"weapon_anti_shark":102,"weapon_blade_o_rang":104,"weapon_shortbow":114,"weapon_slicers":106,"weapon_batblades":107,"weapon_vortex_glove":118,"weapon_radiant_field":113,"weapon_lioness":111,"weapon_gatling":109,"weapon_tibbers":116,"weapon_paw_poison":112,"weapon_iceblast":110,"weapon_yuumibot":119,"weapon_meow_meow":120,"weapon_sound_wave":13,"weapon_shield_slam":14,"weapon_tentacle_slam":15,"weapon_steel_tempest":16,"weapon_winged_dagger":17,"weapon_crossbow":103,"weapon_mega_blast":105,"weapon_statikk":115,"weapon_transit":108,"weapon_annihilator":117,"weapon_pillory_swipe":4,"weapon_bunny_hop":32,"weapon_guiding_hex":30}
const PASSIVES := {"max_health":121,"armor":122,"health_regen":123,"movement_speed":124,"crit_chance":125,"damage":126,"ability_haste":127,"duration":128,"area_size":129,"projectile_count":130,"exp_gain":131,"pickup_radius":132}

const AUGMENTS := {"augment_armor_up":133,"augment_bite_sized":134,"augment_bullet_mania":135,"augment_card_collector":136,"augment_celebration":137,"augment_circle_of_stats":138,"augment_critical_expansion":139,"augment_cross_country":140,"augment_death_and_taxes":141,"augment_ebb_and_flow":142,"augment_elite_bomber":143,"augment_emotional_support":144,"augment_experienced_fighter":145,"augment_gathering_speed":146,"augment_glass_cannon":147,"augment_heavy_hitter":148,"augment_hoarder":149,"augment_immobile_immolation":150,"augment_juggernaut":151,"augment_larger_than_life":152,"augment_long_range":153,"augment_metabolic_overdrive":154,"augment_mission_critical":155,"augment_pescatarian":156,"augment_pick_me_up":157,"augment_point_blank":158,"augment_ramming_runner":159,"augment_regenerative_tissue":160,"augment_size_scrambler":161,"augment_spray_and_pray":162,"augment_ultimate_speed_up":163,"augment_uptime_upgrade":164,"augment_with_haste":165}
const JINX_E := 166
const JINX_R := 168
const JINX_PASSIVE := 167
const ITEM_PATHS := {"100":"res://assets/ui/swarm/jinx-items/uwu-painted-icon.res","101":"res://assets/ui/swarm/jinx-items/weapon_ani_mines-painted.res","102":"res://assets/ui/swarm/jinx-items/weapon_anti_shark-painted.res","103":"res://assets/ui/swarm/jinx-items/weapon_crossbow-painted.res","104":"res://assets/ui/swarm/jinx-items/weapon_blade_o_rang-painted.res","105":"res://assets/ui/swarm/jinx-items/weapon_mega_blast-painted.res","106":"res://assets/ui/swarm/jinx-items/schnitzel-painted-icon.res","107":"res://assets/ui/swarm/jinx-items/weapon_batblades-painted.res","108":"res://assets/ui/swarm/jinx-items/weapon_transit-painted.res","109":"res://assets/ui/swarm/jinx-items/gatling-painted-icon.res","110":"res://assets/ui/swarm/jinx-items/weapon_iceblast-painted.res","111":"res://assets/ui/swarm/jinx-items/weapon_lioness-painted.res","112":"res://assets/ui/swarm/jinx-items/weapon_paw_poison-painted.res","113":"res://assets/ui/swarm/jinx-items/weapon_radiant_field-painted.res","114":"res://assets/ui/swarm/jinx-items/weapon_shortbow-painted.res","115":"res://assets/ui/swarm/jinx-items/weapon_statikk-painted.res","116":"res://assets/ui/swarm/jinx-items/weapon_tibbers-painted.res","117":"res://assets/ui/swarm/jinx-items/weapon_annihilator-painted.res","118":"res://assets/ui/swarm/jinx-items/weapon_vortex_glove-painted.res","119":"res://assets/ui/swarm/jinx-items/weapon_yuumibot-painted.res","120":"res://assets/ui/swarm/jinx-items/jinx-signature-icon.res","121":"res://assets/ui/swarm/jinx-items/max_health-painted.res","122":"res://assets/ui/swarm/jinx-items/armor-painted.res","123":"res://assets/ui/swarm/jinx-items/health_regen-painted.res","124":"res://assets/ui/swarm/jinx-items/movement_speed-painted.res","125":"res://assets/ui/swarm/jinx-items/crit_chance-painted.res","126":"res://assets/ui/swarm/jinx-items/damage-painted.res","127":"res://assets/ui/swarm/jinx-items/ability_haste-painted.res","128":"res://assets/ui/swarm/jinx-items/duration-painted.res","129":"res://assets/ui/swarm/jinx-items/area_size-painted.res","130":"res://assets/ui/swarm/jinx-items/projectile_count-painted.res","131":"res://assets/ui/swarm/jinx-items/exp_gain-painted.res","132":"res://assets/ui/swarm/jinx-items/pickup_radius-painted.res","133":"res://assets/ui/swarm/jinx-items/augment_armor_up-painted.res","134":"res://assets/ui/swarm/jinx-items/augment_bite_sized-painted.res","135":"res://assets/ui/swarm/jinx-items/augment_bullet_mania-painted.res","136":"res://assets/ui/swarm/jinx-items/augment_card_collector-painted.res","137":"res://assets/ui/swarm/jinx-items/augment_celebration-painted.res","138":"res://assets/ui/swarm/jinx-items/augment_circle_of_stats-painted.res","139":"res://assets/ui/swarm/jinx-items/augment_critical_expansion-painted.res","140":"res://assets/ui/swarm/jinx-items/augment_cross_country-painted.res","141":"res://assets/ui/swarm/jinx-items/augment_death_and_taxes-painted.res","142":"res://assets/ui/swarm/jinx-items/augment_ebb_and_flow-painted.res","143":"res://assets/ui/swarm/jinx-items/augment_elite_bomber-painted.res","144":"res://assets/ui/swarm/jinx-items/augment_emotional_support-painted.res","145":"res://assets/ui/swarm/jinx-items/augment_experienced_fighter-painted.res","146":"res://assets/ui/swarm/jinx-items/augment_gathering_speed-painted.res","147":"res://assets/ui/swarm/jinx-items/augment_glass_cannon-painted.res","148":"res://assets/ui/swarm/jinx-items/augment_heavy_hitter-painted.res","149":"res://assets/ui/swarm/jinx-items/augment_hoarder-painted.res","150":"res://assets/ui/swarm/jinx-items/augment_immobile_immolation-painted.res","151":"res://assets/ui/swarm/jinx-items/augment_juggernaut-painted.res","152":"res://assets/ui/swarm/jinx-items/augment_larger_than_life-painted.res","153":"res://assets/ui/swarm/jinx-items/augment_long_range-painted.res","154":"res://assets/ui/swarm/jinx-items/augment_metabolic_overdrive-painted.res","155":"res://assets/ui/swarm/jinx-items/augment_mission_critical-painted.res","156":"res://assets/ui/swarm/jinx-items/augment_pescatarian-painted.res","157":"res://assets/ui/swarm/jinx-items/augment_pick_me_up-painted.res","158":"res://assets/ui/swarm/jinx-items/augment_point_blank-painted.res","159":"res://assets/ui/swarm/jinx-items/augment_ramming_runner-painted.res","160":"res://assets/ui/swarm/jinx-items/augment_regenerative_tissue-painted.res","161":"res://assets/ui/swarm/jinx-items/augment_size_scrambler-painted.res","162":"res://assets/ui/swarm/jinx-items/augment_spray_and_pray-painted.res","163":"res://assets/ui/swarm/jinx-items/augment_ultimate_speed_up-painted.res","164":"res://assets/ui/swarm/jinx-items/augment_uptime_upgrade-painted.res","165":"res://assets/ui/swarm/jinx-items/augment_with_haste-painted.res","166":"res://assets/ui/swarm/jinx-items/jinx-e-painted-icon.res","167":"res://assets/ui/swarm/jinx-items/jinx_passive-painted.res","168":"res://assets/ui/swarm/jinx-items/jinx-ultimate-icon.res"}

const CHARACTER_ABILITIES := {"seraföhn":[200,201,202],"löwina":[203,204,205],"illaupsi":[206,207,208],"brioche":[209,210,211],"yasüff":[212,213,214],"rübenrambo":[215,216,217],"auarora":[218,219,220],"xayaya":[221,222,223]}

static func texture(index: int) -> Texture2D:
	if _cache.has(index): return _cache[index]
	if index >= 200 and index < 224:
		_cache[index] = load("res://assets/ui/swarm/characters/ability-"+str(index)+".res")
		return _cache[index]
	if ITEM_PATHS.has(str(index)):
		_cache[index]=load(ITEM_PATHS[str(index)])
		return _cache[index]
	if index>=39:
		_cache[index]=load("res://assets/ui/swarm/"+["bunny-bow","snack-bow","schnitzel-icon"][index-39]+".res")
		return _cache[index]
	if index>=36:
		_cache[index] = load("res://assets/ui/swarm/"+["jinx-standard","jinx-ultimate","mega-blast"][index-36]+".res")
		return _cache[index]
	if _atlas == null: _atlas = load("res://assets/ui/swarm/icons.res")
	var icon := AtlasTexture.new()
	icon.atlas = _atlas
	# Use the visible painted cell borders, including the slightly taller last row.
	var xs := [0,210,419,627,835,1045,1254]
	var ys := [0,205,409,618,821,1017,1254]
	var column: int = index%6
	var row: int = index/6
	icon.region = Rect2(xs[column]+3,ys[row]+3,xs[column+1]-xs[column]-6,ys[row+1]-ys[row]-6)
	icon.filter_clip = true
	_cache[index] = icon
	return icon

static func choice_index(choice: Dictionary) -> int:
	var id: String = choice.get("id", "")
	if WEAPONS.has(id): return WEAPONS[id]
	if PASSIVES.has(id): return PASSIVES[id]
	if AUGMENTS.has(id): return AUGMENTS[id]
	if choice.get("type", "") == "gold": return 28
	if choice.get("type", "") == "heal": return 20
	return 30

