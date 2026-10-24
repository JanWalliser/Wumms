extends RefCounted

# Single-map release objectives. No autoload dependencies: also used during save migration.
const MAP_IDS: Array[String] = ["map_warehouse"]
const SLOT_OBJECTIVES = ["select_3_passives","passives_hard_4","warehouse_trials3_slot"]
const LEGACY_COMPLETIONS = {
	"defeat_reksai":"warehouse_story_clear", "defeat_aatrox":"warehouse_story_clear",
	"defeat_briar":"warehouse_level20_brioche", "defeat_belveth":"warehouse_evolve_yasuff",
	"lab_freeze":"warehouse_fountain2_iceblast", "lab_fuel":"warehouse_miniboss5_megablast",
	"belveth_hard":"warehouse_trials3_slot", "aatrox_hard":"warehouse_extreme_clear",
	"reksai_hard":"warehouse_hard_clear"
}

static func difficulty_hint(id: String) -> String:
	if id=="story": return "Von Anfang an verfügbar"
	for quest in OBJECTIVES:
		if quest["reward_type"]=="difficulty" and quest["reward_value"]==id: return quest["title"]
	return ""

static func shop_hint(id: String) -> String:
	var wanted: String = {"exp_gain":"reach_level_30","projectile_count":"seraföhn_lvl_25","anima_power":"warehouse_extreme_clear"}.get(id,"")
	for quest in OBJECTIVES:
		if quest["id"]==wanted: return quest["title"]
	return "Questabschluss nötig"

static func restore_unlocks(profile: Dictionary, old_schema: int) -> void:
	var completed: Array = profile["completed_quests"]
	if old_schema<4:
		for legacy in LEGACY_COMPLETIONS:
			if completed.has(legacy) and not completed.has(LEGACY_COMPLETIONS[legacy]):
				completed.append(LEGACY_COMPLETIONS[legacy])
	# Replay only permanent entitlements, never currency or purchases. Existing
	# entitlements (including historical maps) are retained rather than removed.
	for quest in OBJECTIVES:
		if not completed.has(quest["id"]): continue
		var key: String = {"weapon":"unlocked_weapons","passive":"unlocked_passives","character":"unlocked_characters","difficulty":"unlocked_difficulties","shop":"unlocked_shop","feature":"features"}.get(quest["reward_type"],"")
		if not key.is_empty() and not profile[key].has(quest["reward_value"]): profile[key].append(quest["reward_value"])
	if profile["features"].has("extreme_and_anima") and not profile["unlocked_difficulties"].has("extreme"): profile["unlocked_difficulties"].append("extreme")
	if profile["unlocked_difficulties"].has("extreme") and not profile["unlocked_difficulties"].has("hard"): profile["unlocked_difficulties"].append("hard")
	if not profile["unlocked_maps"].has("map_warehouse"): profile["unlocked_maps"].push_front("map_warehouse")
	if not profile["unlocked_difficulties"].has("story"): profile["unlocked_difficulties"].push_front("story")
	var slots := 3
	for objective in SLOT_OBJECTIVES:
		if completed.has(objective): slots+=1
	profile["passive_slots"]=maxi(int(profile["passive_slots"]),slots)

const OBJECTIVES = [
	{
		"id": "survive_hard_5_min",
		"title": "5 Minuten auf Hard überleben",
		"reward_desc": "Schaltet Bel’Veth-Prüfungen frei",
		"metric": "hard_time_survived",
		"target": 300.0,
		"reward_type": "feature",
		"reward_value": "belveth_trials"
	},
	{
		"id": "survive_2_min",
		"title": "Überlebe 2 Minuten",
		"reward_desc": "Schaltet Blödelrang frei",
		"metric": "time_survived",
		"target": 120.0,
		"reward_type": "weapon",
		"reward_value": "weapon_blade_o_rang"
	},
	{
		"id": "survive_5_min",
		"title": "Überlebe 5 Minuten",
		"reward_desc": "Schaltet Selbstheil-Schnitzel frei",
		"metric": "time_survived",
		"target": 300.0,
		"reward_type": "passive",
		"reward_value": "health_regen"
	},
	{
		"id": "survive_15_min",
		"title": "Überlebe 15 Minuten",
		"reward_desc": "Schaltet Hasi-Hyperschub-Boni frei",
		"metric": "time_survived",
		"target": 900.0,
		"reward_type": "feature",
		"reward_value": "boons_unlocked"
	},
	{
		"id": "warehouse_story_clear",
		"title": "Urzeit-Rexi im Warenhaus besiegen",
		"reward_desc": "Schaltet Hard frei",
		"metric": "boss_kill",
		"target": 1,
		"reward_type": "difficulty",
		"reward_value": "hard"
	},
	{
		"id": "warehouse_level20_brioche",
		"title": "Teamlevel 20 im Warenhaus erreichen",
		"reward_desc": "Schaltet Brioche frei",
		"metric": "char_level",
		"target": 20,
		"reward_type": "character",
		"reward_value": "brioche"
	},
	{
		"id": "warehouse_evolve_yasuff",
		"title": "Eine Waffe im Warenhaus entwickeln",
		"reward_desc": "Schaltet Yasüff frei",
		"metric": "evolve_weapon",
		"target": 1,
		"reward_type": "character",
		"reward_value": "yasüff"
	},
	{
		"id": "warehouse_hard_clear",
		"title": "Urzeit-Rexi auf Hard oder Extreme besiegen",
		"reward_desc": "Schaltet Extreme frei",
		"metric": "boss_hard_reksai",
		"target": 1,
		"reward_type": "difficulty",
		"reward_value": "extreme"
	},
	{
		"id": "five_max_weapons",
		"title": "5 Waffen gleichzeitig auf Stufe 5",
		"reward_desc": "Schaltet Bären-Bot frei",
		"metric": "max_weapons_in_run",
		"target": 5,
		"reward_type": "weapon",
		"reward_value": "weapon_tibbers"
	},
	{
		"id": "blade_lvl_2",
		"title": "Blödelrang auf Stufe 2",
		"reward_desc": "Schaltet Fähigkeitstempo frei",
		"metric": "weapon_level_blade",
		"target": 2,
		"reward_type": "passive",
		"reward_value": "ability_haste"
	},
	{
		"id": "vortex_lvl_4",
		"title": "Wirbel-Handschuh auf Stufe 4",
		"reward_desc": "Schaltet Kritchance frei",
		"metric": "weapon_level_vortex",
		"target": 4,
		"reward_type": "passive",
		"reward_value": "crit_chance"
	},
	{
		"id": "elites_15",
		"title": "15 Elitegegner besiegen",
		"reward_desc": "Schaltet Flächengröße frei",
		"metric": "elite_kills",
		"target": 15,
		"reward_type": "passive",
		"reward_value": "area_size"
	},
	{
		"id": "boxes_200",
		"title": "200 Kisten zerstören",
		"reward_desc": "Schaltet XP-Passiv frei",
		"metric": "boxes_destroyed",
		"target": 200,
		"reward_type": "passive",
		"reward_value": "exp_gain"
	},
	{
		"id": "vacuums_5",
		"title": "5 Magnete aufsammeln",
		"reward_desc": "Schaltet Sammelradius frei",
		"metric": "vacuums_collected",
		"target": 5,
		"reward_type": "passive",
		"reward_value": "pickup_radius"
	},
	{
		"id": "fountain_4",
		"title": "Brunnen 4-mal aktivieren",
		"reward_desc": "Schaltet Glitzer-Gammelfeld frei",
		"metric": "fountain_activated",
		"target": 4,
		"reward_type": "weapon",
		"reward_value": "weapon_radiant_field"
	},
	{
		"id": "warehouse_fountain2_iceblast",
		"title": "Brunnen im Warenhaus 2-mal aktivieren",
		"reward_desc": "Schaltet Eisbein-Panzer frei",
		"metric": "fountain_activated",
		"target": 2,
		"reward_type": "weapon",
		"reward_value": "weapon_iceblast"
	},
	{
		"id": "warehouse_miniboss5_megablast",
		"title": "5 Minibosse im Warenhaus besiegen",
		"reward_desc": "Schaltet Hasi-Megaböller frei",
		"metric": "warehouse_miniboss_kills",
		"target": 5,
		"reward_type": "weapon",
		"reward_value": "weapon_mega_blast"
	},
	{
		"id": "trial_first",
		"title": "Eine Belastungs-Prüfung abschließen",
		"reward_desc": "Schaltet Anime-Minen frei",
		"metric": "trials_completed",
		"target": 1,
		"reward_type": "weapon",
		"reward_value": "weapon_ani_mines"
	},
	{
		"id": "select_3_passives",
		"title": "3 verschiedene Passive wählen",
		"reward_desc": "Schaltet 4. Passivslot frei",
		"metric": "passives_in_run",
		"target": 3,
		"reward_type": "slot",
		"reward_value": "passive_slot_4"
	},
	{
		"id": "evolve_1_weapon",
		"title": "Eine Waffe entwickeln",
		"reward_desc": "Schaltet Kugel-Klonerei frei",
		"metric": "evolve_weapon",
		"target": 1,
		"reward_type": "passive",
		"reward_value": "projectile_count"
	},
	{
		"id": "reach_level_10",
		"title": "Level 10 erreichen",
		"reward_desc": "Schaltet Turbo-Treter frei",
		"metric": "char_level",
		"target": 10,
		"reward_type": "passive",
		"reward_value": "movement_speed"
	},
	{
		"id": "reach_level_20",
		"title": "Level 20 erreichen",
		"reward_desc": "Schaltet Steckdosen-Säbel frei",
		"metric": "char_level",
		"target": 20,
		"reward_type": "weapon",
		"reward_value": "weapon_statikk"
	},
	{
		"id": "reach_level_30",
		"title": "Level 30 erreichen",
		"reward_desc": "Schaltet Hirnschmalz-Hantel Shop-Upgrade frei",
		"metric": "char_level",
		"target": 30,
		"reward_type": "shop",
		"reward_value": "exp_gain"
	},
	{
		"id": "shortbow_lvl_2",
		"title": "Sengender Snackbogen auf Stufe 2",
		"reward_desc": "Schaltet Löwina frei",
		"metric": "weapon_level_shortbow",
		"target": 2,
		"reward_type": "character",
		"reward_value": "löwina"
	},
	{
		"id": "radiant_lvl_4",
		"title": "Glitzer-Gammelfeld auf Stufe 4",
		"reward_desc": "Schaltet Illa-Upsi frei",
		"metric": "weapon_level_radiant",
		"target": 4,
		"reward_type": "character",
		"reward_value": "illaupsi"
	},
	{
		"id": "kills_15k",
		"title": "15.000 Urviecher besiegen",
		"reward_desc": "Schaltet Miezi-Missionen (Yuumi) frei",
		"metric": "total_kills",
		"target": 15000,
		"reward_type": "feature",
		"reward_value": "yuumi_quests"
	},
	{
		"id": "kills_25k",
		"title": "25.000 Urviecher besiegen",
		"reward_desc": "Schaltet Miezi-Mat 1.0 frei",
		"metric": "total_kills",
		"target": 25000,
		"reward_type": "weapon",
		"reward_value": "weapon_yuumibot"
	},
	{
		"id": "jankz_lvl_25",
		"title": "Jankz Level 25",
		"reward_desc": "Schaltet Wirbel-Watschen-Handschuh frei",
		"metric": "char_milestone_jankz",
		"target": 25,
		"reward_type": "weapon",
		"reward_value": "weapon_vortex_glove"
	},
	{
		"id": "seraföhn_lvl_25",
		"title": "Sera-Föhn Level 25",
		"reward_desc": "Schaltet Kugel-Kopierer Shop-Upgrade frei",
		"metric": "char_milestone_seraföhn",
		"target": 25,
		"reward_type": "shop",
		"reward_value": "projectile_count"
	},
	{
		"id": "löwina_lvl_25",
		"title": "Löwina Level 25",
		"reward_desc": "Schaltet Bahn-Bonanza frei",
		"metric": "char_milestone_löwina",
		"target": 25,
		"reward_type": "weapon",
		"reward_value": "weapon_transit"
	},
	{
		"id": "illaupsi_lvl_25",
		"title": "Illa-Upsi Level 25",
		"reward_desc": "Schaltet Nicht-mehr-aufhören frei",
		"metric": "char_milestone_illaupsi",
		"target": 25,
		"reward_type": "passive",
		"reward_value": "duration"
	},
	{
		"id": "brioche_lvl_30",
		"title": "Brioche Level 30",
		"reward_desc": "Schaltet Anti-Hai-Hai-Mine frei",
		"metric": "char_milestone_brioche",
		"target": 30,
		"reward_type": "weapon",
		"reward_value": "weapon_anti_shark"
	},
	{
		"id": "yasüff_lvl_30",
		"title": "Yasüff Level 30",
		"reward_desc": "Schaltet Kampfhasi-Knallbogen frei",
		"metric": "char_milestone_yasüff",
		"target": 30,
		"reward_type": "weapon",
		"reward_value": "weapon_crossbow"
	},
	{
		"id": "rübenrambo_lvl_35",
		"title": "Rüben-Rambo Level 35",
		"reward_desc": "Schaltet Pfoten-Pups-Pest frei",
		"metric": "char_milestone_rübenrambo",
		"target": 35,
		"reward_type": "weapon",
		"reward_value": "weapon_paw_poison"
	},
	{
		"id": "auarora_lvl_35",
		"title": "Aua-Rora Level 35",
		"reward_desc": "Schaltet Der Ananasinator frei",
		"metric": "char_milestone_auarora",
		"target": 35,
		"reward_type": "weapon",
		"reward_value": "weapon_annihilator"
	},
	{
		"id": "xayaya_lvl_35",
		"title": "Xayaya Level 35",
		"reward_desc": "Schaltet Echo-Flederflatschen frei",
		"metric": "char_milestone_xayaya",
		"target": 35,
		"reward_type": "weapon",
		"reward_value": "weapon_batblades"
	},
	{
		"id": "reksai_hard",
		"title": "Urzeit-Rexi auf Hard besiegen",
		"reward_desc": "Schaltet Rüben-Rambo frei",
		"metric": "boss_hard_reksai",
		"target": 1,
		"reward_type": "character",
		"reward_value": "rübenrambo"
	},
	{
		"id": "minibosses_hard_25",
		"title": "25 Halbstarke auf Hard besiegen",
		"reward_desc": "Schaltet Aua-Rora frei",
		"metric": "miniboss_hard_kills",
		"target": 25,
		"reward_type": "character",
		"reward_value": "auarora"
	},
	{
		"id": "belveth_trials_hard_20",
		"title": "20 Belastungs-Prüfungen auf Hard",
		"reward_desc": "Schaltet Xayaya frei",
		"metric": "trials_hard_count",
		"target": 20,
		"reward_type": "character",
		"reward_value": "xayaya"
	},
	{
		"id": "warehouse_trials3_slot",
		"title": "3 Belastungs-Prüfungen auf Hard oder Extreme abschließen",
		"reward_desc": "Schaltet einen weiteren Passivplatz frei (maximal 6)",
		"metric": "trials_hard_count",
		"target": 3,
		"reward_type": "slot",
		"reward_value": "passive_slot_5"
	},
	{
		"id": "passives_hard_4",
		"title": "4 verschiedene Passive auf Hard",
		"reward_desc": "+1 Passivplatz (bis maximal 6)",
		"metric": "passives_in_hard_run",
		"target": 4,
		"reward_type": "slot",
		"reward_value": "passive_slot_6"
	},
	{
		"id": "warehouse_extreme_clear",
		"title": "Urzeit-Rexi auf Extreme besiegen",
		"reward_desc": "Schaltet Knallkraft 100 (Anima) frei",
		"metric": "boss_extreme_reksai",
		"target": 1,
		"reward_type": "feature",
		"reward_value": "extreme_and_anima"
	},
	{
		"id": "story_pastete",
		"title": "Lektionen aus der Pastete",
		"reward_desc": "Jankz-Storybelohnung (500 Gold)",
		"metric": "story_event_1",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_kaffeeklatsch",
		"title": "Kampfkatzen-Kaffeeklatsch",
		"reward_desc": "Sera-Föhn-Storybelohnung (500 Gold)",
		"metric": "story_event_2",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_senf",
		"title": "Gestrandet mit Senf",
		"reward_desc": "Löwina-Storybelohnung (500 Gold)",
		"metric": "story_event_3",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_wollwolf",
		"title": "Der einsame Wollwolf",
		"reward_desc": "Yasüff-Storybelohnung (500 Gold)",
		"metric": "story_event_4",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_frikadellen",
		"title": "Freunde? Frikadellen.",
		"reward_desc": "Brioche-Storybelohnung (500 Gold)",
		"metric": "story_event_5",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_tohuwabohu",
		"title": "Tausend Teile Tohuwabohu",
		"reward_desc": "Rüben-Rambo-Storybelohnung (500 Gold)",
		"metric": "story_event_6",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_muckibuden",
		"title": "Muckibuden-Mäuse",
		"reward_desc": "Aua-Rora-Storybelohnung (500 Gold)",
		"metric": "story_event_7",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	},
	{
		"id": "story_senfsong",
		"title": "Überraschungs-Senfsong für Sera-Föhn",
		"reward_desc": "Xayaya-Storybelohnung (500 Gold)",
		"metric": "story_event_8",
		"target": 1,
		"reward_type": "gold",
		"reward_value": "500"
	}
]
