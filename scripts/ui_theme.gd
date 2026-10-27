class_name PurrTheme
extends RefCounted

const INK := Color("403b55")
const REGIONS: Array[Color] = [
	Color("f6cedd"), Color("cce9df"), Color("d6d6f5"),
	Color("fae4b9"), Color("cbe4f4")
]

static func region_color(id: int, count: int) -> Color:
	if count <= REGIONS.size():
		return REGIONS[id]
	return Color.from_hsv(float(id) / float(count), 0.22, 0.96)

static func rounded(color: Color, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func create() -> Theme:
	return preload("res://resources/purr_theme.tres").duplicate(true) as Theme
