extends Node

# AugmentRegistry - All 33 Yuumi-Augments (Miezi-Missionen) with unique trade-offs and gameplay modifiers

class_name AugmentRegistry

static var augments: Dictionary = {
	"augment_armor_up": {
		"id": "augment_armor_up",
		"ref_name": "Armor Up",
		"display_name": "Panzer-Panika",
		"description": "+40 Rüstung, aber -10% Lauftempo.",
		"type": "stat_tradeoff"
	},
	"augment_bite_sized": {
		"id": "augment_bite_sized",
		"ref_name": "Bite Sized",
		"display_name": "Häppchen-Hulk",
		"description": "-25% Flächengröße, aber +30% Lauftempo und +20 Fähigkeitstempo.",
		"type": "stat_tradeoff"
	},
	"augment_bullet_mania": {
		"id": "augment_bullet_mania",
		"ref_name": "Bullet-Mania",
		"display_name": "Kugel-Kirmes",
		"description": "+2 Projektile für alle Waffen, aber -15% Schaden.",
		"type": "stat_tradeoff"
	},
	"augment_card_collector": {
		"id": "augment_card_collector",
		"ref_name": "Card Collector",
		"display_name": "Karten-Kleptomane",
		"description": "+5% permanenter Schaden für jede eingesammelte Zugangskarte.",
		"type": "dynamic"
	},
	"augment_celebration": {
		"id": "augment_celebration",
		"ref_name": "Celebration!",
		"display_name": "Konfetti-Katastrophe!",
		"description": "Jedes Team-Level-up erzeugt eine gewaltige Konfetti-Explosion, die Urviecher wegpustet.",
		"type": "proc"
	},
	"augment_circle_of_stats": {
		"id": "augment_circle_of_stats",
		"ref_name": "Circle of Stats",
		"display_name": "Werte-Walzerei",
		"description": "Erscheint periodisch als leuchtender Kreis: Darin stehend erhältst du +50% Schaden und Tempo.",
		"type": "area_buff"
	},
	"augment_critical_expansion": {
		"id": "augment_critical_expansion",
		"ref_name": "Critical Expansion",
		"display_name": "Krit-Klops-Wachstum",
		"description": "Kritische Treffer vergrößern kurzzeitig deine Flächengröße um +5% (bis zu 10x stapelbar).",
		"type": "stacking"
	},
	"augment_cross_country": {
		"id": "augment_cross_country",
		"ref_name": "Cross Country",
		"display_name": "Querbeet-Quadratlatschen",
		"description": "Ununterbrochene Bewegung gewährt +20% zusätzliches Lauftempo.",
		"type": "stat"
	},
	"augment_death_and_taxes": {
		"id": "augment_death_and_taxes",
		"ref_name": "Death and Taxes",
		"display_name": "Tod und Taschengeld",
		"description": "+30% Goldgewinn; besiegte Gegner haben eine Chance auf Extradublonen.",
		"type": "economy"
	},
	"augment_ebb_and_flow": {
		"id": "augment_ebb_and_flow",
		"ref_name": "Ebb And Flow",
		"display_name": "Ebbe und Böllerflut",
		"description": "Wechselt alle 15 Sekunden rhythmisch zwischen +40 und -20 Fähigkeitstempo.",
		"type": "cycle"
	},
	"augment_elite_bomber": {
		"id": "augment_elite_bomber",
		"ref_name": "Elite Bomber",
		"display_name": "Elite-Eierwerfer",
		"description": "Besiegte Elite-Gegner explodieren in einer gigantischen thermonuklearen Eierschalen-Druckwelle.",
		"type": "proc"
	},
	"augment_emotional_support": {
		"id": "augment_emotional_support",
		"ref_name": "Emotional Support Pet",
		"display_name": "Therapie-Tier mit Aggression",
		"description": "Ein hyperaktives Kuscheltier beißt nahe Feinde und lenkt Schläge ab.",
		"type": "companion"
	},
	"augment_experienced_fighter": {
		"id": "augment_experienced_fighter",
		"ref_name": "Experienced Fighter",
		"display_name": "Veteranen-Vollpfosten",
		"description": "+30% erhöhter Erfahrungsgewinn für das gesamte Team.",
		"type": "stat"
	},
	"augment_gathering_speed": {
		"id": "augment_gathering_speed",
		"ref_name": "Gathering Speed",
		"display_name": "Tempo-Tornado-Turbo",
		"description": "Gewährt jede überlebte Minute +2% Lauftempo dauerhaft dazu.",
		"type": "scaling"
	},
	"augment_glass_cannon": {
		"id": "augment_glass_cannon",
		"ref_name": "Glass Cannon",
		"display_name": "Porzellan-Panzerfaust",
		"description": "+40% verursachter Schaden, aber -40% maximales Leben.",
		"type": "stat_tradeoff"
	},
	"augment_heavy_hitter": {
		"id": "augment_heavy_hitter",
		"ref_name": "Heavy Hitter",
		"display_name": "Schwergewichtiger Schnitzelklopfer",
		"description": "+50% Schaden, aber -20 Fähigkeitstempo.",
		"type": "stat_tradeoff"
	},
	"augment_hoarder": {
		"id": "augment_hoarder",
		"ref_name": "Hoarder",
		"display_name": "Hamster-Habgier",
		"description": "+1% Schaden pro 50 unausgegebene Dönerdublonen im aktuellen Run.",
		"type": "dynamic"
	},
	"augment_immobile_immolation": {
		"id": "augment_immobile_immolation",
		"ref_name": "Immobile Immolation",
		"display_name": "Stehender Grillkäse",
		"description": "Stillstehen entfacht eine Feuerbrunst um dich, kostet aber pro Sekunde 1% Leben.",
		"type": "risk_reward"
	},
	"augment_juggernaut": {
		"id": "augment_juggernaut",
		"ref_name": "Juggernaut",
		"display_name": "Jugger-Joghurt",
		"description": "+300 Max-HP, +25 Rüstung, aber -15% Lauftempo.",
		"type": "stat_tradeoff"
	},
	"augment_larger_than_life": {
		"id": "augment_larger_than_life",
		"ref_name": "Larger Than Life",
		"display_name": "Größer als der Döner",
		"description": "+40% Flächengröße für alle Angriffe, aber -15% Lauftempo.",
		"type": "stat_tradeoff"
	},
	"augment_long_range": {
		"id": "augment_long_range",
		"ref_name": "Long Range",
		"display_name": "Fernweh-Fernschuss",
		"description": "+30% Schaden an entfernten Gegnern, +20% Projektilgeschwindigkeit.",
		"type": "stat"
	},
	"augment_metabolic_overdrive": {
		"id": "augment_metabolic_overdrive",
		"ref_name": "Metabolic Overdrive",
		"display_name": "Stoffwechsel-Sprint",
		"description": "+25% Lauftempo und +10 Lebensregeneration pro Sekunde.",
		"type": "stat"
	},
	"augment_mission_critical": {
		"id": "augment_mission_critical",
		"ref_name": "Mission Critical",
		"display_name": "Operation Krit-Kartoffel",
		"description": "+25% Krit-Chance und +50% Krit-Schaden.",
		"type": "stat"
	},
	"augment_pescatarian": {
		"id": "augment_pescatarian",
		"ref_name": "Pescatarian",
		"display_name": "Fischstäbchen-Fanatiker",
		"description": "Besiegte Gegner lassen gelegentlich frittierte Fischstäbchen fallen, die 50 HP heilen.",
		"type": "drops"
	},
	"augment_pick_me_up": {
		"id": "augment_pick_me_up",
		"ref_name": "Pick-Me-Up",
		"display_name": "Heb-mich-Horst",
		"description": "-50% Aufsammelradius, aber alle 15s saugt ein mächtiger Magnetimpuls alles heran.",
		"type": "pulse"
	},
	"augment_point_blank": {
		"id": "augment_point_blank",
		"ref_name": "Point Blank",
		"display_name": "Null-Abstand-Nudel",
		"description": "+35% Schaden an Gegnern in unmittelbarer Nähe und +15 Rüstung.",
		"type": "stat"
	},
	"augment_ramming_runner": {
		"id": "augment_ramming_runner",
		"ref_name": "Ramming Runner",
		"display_name": "Rennender Rammler",
		"description": "In Gegner hineinlaufen fügt ihnen schweren Rammschaden zu und wirft sie zurück.",
		"type": "melee"
	},
	"augment_regenerative_tissue": {
		"id": "augment_regenerative_tissue",
		"ref_name": "Regenerative Tissue",
		"display_name": "Wieder-Wachs-Waffel",
		"description": "+15 Lebensregeneration und +150 maximale Lebenspunkte.",
		"type": "stat"
	},
	"augment_size_scrambler": {
		"id": "augment_size_scrambler",
		"ref_name": "Size Scrambler",
		"display_name": "Größen-Gulasch",
		"description": "Jedes Geschoss variiert zufällig zwischen 70% und 150% Größe und Schaden.",
		"type": "random"
	},
	"augment_spray_and_pray": {
		"id": "augment_spray_and_pray",
		"ref_name": "Spray and Pray",
		"display_name": "Sprühen und Spaghetti",
		"description": "+4 Projektile für alle Waffen, aber -35% Schaden.",
		"type": "stat_tradeoff"
	},
	"augment_ultimate_speed_up": {
		"id": "augment_ultimate_speed_up",
		"ref_name": "Ultimate Speed-Up",
		"display_name": "Ulti-Ulk-Turbo",
		"description": "+40 Fähigkeitstempo exklusiv für Ultimate-Fähigkeiten (R).",
		"type": "stat"
	},
	"augment_uptime_upgrade": {
		"id": "augment_uptime_upgrade",
		"ref_name": "Uptime Upgrade",
		"display_name": "Extra-langer Eierlauf",
		"description": "+30% Dauer für alle Schilde, Minen, Giftzonen und temporären Buffs.",
		"type": "stat"
	},
	"augment_with_haste": {
		"id": "augment_with_haste",
		"ref_name": "With Haste",
		"display_name": "Hektik-Hamster",
		"description": "+30 Fähigkeitstempo, aber -10 Rüstung.",
		"type": "stat_tradeoff"
	}
}

static func get_augment_data(augment_id: String) -> Dictionary:
	return preload("res://scripts/core/swarm_balance.gd").apply("augments",augment_id,augments.get(augment_id, {}))

static func get_all_augment_ids() -> Array[String]:
	var keys: Array[String] = []
	for k in augments.keys():
		keys.append(k)
	return keys
