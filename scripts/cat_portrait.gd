class_name CatPortrait
extends Control
## Original rendered collection shared by menu, hints, pause and reward cards.
@export_enum("happy", "sleepy", "celebrate") var expression := "happy"
var celebration_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if expression == "celebrate" and not PlayerPreferences.reduced_motion:
		celebration_scale = 0.86
		create_tween().tween_method(func(value: float) -> void:
			celebration_scale = value
			queue_redraw(), 0.86, 1.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var height := minf(size.y, size.x * 0.55) * celebration_scale
	var middle := size * Vector2(0.5, 0.5)
	if expression != "sleepy":
		for side in [-1, 1]:
			var small := height * 0.79
			var rect := Rect2(middle + Vector2(side * height * 0.60 - small * 0.5, -small * 0.42), Vector2.ONE * small)
			CatArtwork.paint(self, rect, 2 if side < 0 else 4)
	CatArtwork.paint(self, Rect2(middle - Vector2.ONE * height * 0.5, Vector2.ONE * height), 1 if expression == "sleepy" else 0)
	for side in [-1, 1]:
		CatArtwork.star(self, middle + Vector2(side * height * 0.97, -height * 0.23), 5, Color("d6b65e"))
	if expression == "celebrate":
		for i in range(3):
			CatArtwork.star(self, middle + Vector2((i - 1) * height * 0.38, -height * 0.46), 6 if i == 1 else 4, Color("d6b65e"))
