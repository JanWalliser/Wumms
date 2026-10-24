extends Control

const Icons = preload("res://scripts/ui/swarm_icons.gd")
var entries: Dictionary = {}

func _ready() -> void:
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/swarm/jinx-items/manifest.json"))
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,1920,1080),Color("0b1522"))
	draw_string(ThemeDB.fallback_font,Vector2(35,35),"JINX · 21 Waffen / 12 Stat-Passive / 33 Augments / E, R und Passive",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("eee3c4"))
	var i := 0
	for id in entries:
		var at := Vector2(36+(i%12)*157,58+(i/12)*166)
		draw_texture_rect(Icons.texture(int(entries[id]["index"])),Rect2(at,Vector2(116,116)),false)
		var label: String = id.trim_prefix("weapon_").trim_prefix("augment_")
		draw_string(ThemeDB.fallback_font,at+Vector2(0,135),label,HORIZONTAL_ALIGNMENT_LEFT,150,13,Color("ccdce4"))
		i+=1
