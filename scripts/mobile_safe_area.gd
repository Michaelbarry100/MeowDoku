class_name MobileSafeArea
extends MarginContainer
## Convert physical mobile safe-area insets into logical canvas coordinates.
## Test overrides are logical pixels: left, top, right, bottom. -1 = device.
var test_insets := Vector4(-1, -1, -1, -1)
@export var padding := 16

func _ready() -> void:
	get_viewport().size_changed.connect(update_insets)
	update_insets()

func update_insets() -> void:
	var insets := Vector4.ZERO
	if test_insets.x >= 0:
		insets = test_insets
	elif OS.get_name() in ["Android", "iOS"]:
		var safe := DisplayServer.get_display_safe_area()
		var physical := DisplayServer.screen_get_size()
		if physical.x > 0 and physical.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var scale := get_viewport().get_visible_rect().size / Vector2(physical)
			insets = Vector4(safe.position.x * scale.x, safe.position.y * scale.y, maxf(0, physical.x - safe.end.x) * scale.x, maxf(0, physical.y - safe.end.y) * scale.y)
	add_theme_constant_override("margin_left", padding + int(ceil(insets.x)))
	add_theme_constant_override("margin_top", padding + int(ceil(insets.y)))
	add_theme_constant_override("margin_right", padding + int(ceil(insets.z)))
	add_theme_constant_override("margin_bottom", padding + int(ceil(insets.w)))
