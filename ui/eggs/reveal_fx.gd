class_name RevealFx
extends Control
## The light behind a freshly hatched card: Jo's white-on-black layers (assets/eggs/fx/, made by
## tools/prepare_fx.py), added on top and tinted with the rarity color. Rarer dinos get more
## layers (Jo, 2026-10-09):
##   N   glow
##   R   + light rays (two copies turning opposite ways)
##   SR  + twinkling sparkles
##   SSR + shockwave ring at the reveal and a slowly turning fossil sigil
##   UR  all of it, cycling through rainbow colors like the Legendary card frame
## Place it centered behind the card; `animated = false` gives a still frame (for share images).

const FX := "res://assets/eggs/fx/"
const SPARKLES := 8
## How bright the layers are, by rarity (N..UR).
const STRENGTH: Array[float] = [0.75, 0.8, 0.9, 1.0, 1.0]

var rarity := 0
var animated := true
var _layers: Array[TextureRect] = []
var _time := 0.0


static func create(dino_rarity: int, is_animated := true) -> RevealFx:
	var fx := RevealFx.new()
	fx.rarity = dino_rarity
	fx.animated = is_animated
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fx


func _ready() -> void:
	pivot_offset = size / 2
	var strength := STRENGTH[rarity]
	if rarity >= DinoDef.Rarity.EPIC:
		var sigil := _layer("sigil", 0.72, 0.55 * strength)
		_spin(sigil, 40.0)
	if rarity >= DinoDef.Rarity.RARE:
		var rays_back := _layer("rays", 1.15, 0.45 * strength)
		_spin(rays_back, -55.0)
		var rays := _layer("rays", 0.95, 0.8 * strength)
		_spin(rays, 32.0)
	var halo := _layer("halo", 1.05, 0.95 * strength)
	if animated:
		var pulse := halo.create_tween().set_loops()
		pulse.tween_property(halo, "scale", Vector2.ONE * 1.08, 1.4).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(halo, "scale", Vector2.ONE * 0.95, 1.4).set_trans(Tween.TRANS_SINE)
	if rarity >= DinoDef.Rarity.SUPER_RARE:
		_add_sparkles(14 + (rarity - DinoDef.Rarity.SUPER_RARE) * 6)
	if rarity >= DinoDef.Rarity.EPIC and animated:
		_shockwave(0.0)
		if rarity == DinoDef.Rarity.LEGENDARY:
			_shockwave(0.25)
	_tint(Palette.RARITY_COLORS[rarity])
	if animated:
		# Bursts open from small.
		scale = Vector2.ONE * 0.15
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if rarity == DinoDef.Rarity.LEGENDARY and animated:
		_time += delta
		_tint(Color.from_hsv(fmod(_time * 0.12, 1.0), 0.55, 1.0))


## One full-size layer, centered, scaled to `relative` of this control, added on top.
func _layer(file: String, relative: float, alpha: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(FX + file + ".webp")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = size * relative
	rect.position = (size - rect.size) / 2
	rect.pivot_offset = rect.size / 2
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _additive()
	rect.set_meta("alpha", alpha)
	add_child(rect)
	_layers.append(rect)
	return rect


func _spin(rect: Control, seconds_per_turn: float) -> void:
	rect.rotation = randf() * TAU
	if not animated:
		return
	var spin := rect.create_tween().set_loops()
	spin.tween_property(rect, "rotation", TAU * signf(seconds_per_turn), absf(seconds_per_turn)).as_relative()


func _shockwave(delay: float) -> void:
	var ring := _layer("ring", 0.5, 1.0)
	ring.scale = Vector2.ONE * 0.4
	var burst := ring.create_tween().set_parallel()
	burst.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.8).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	burst.tween_property(ring, "self_modulate:a", 0.0, 0.8).set_delay(delay + 0.1)
	burst.chain().tween_callback(func() -> void:
		_layers.erase(ring)
		ring.queue_free())


## Sparkles scattered around the card, each twinkling on its own beat.
func _add_sparkles(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var sparkle := TextureRect.new()
		sparkle.texture = load(FX + "sparkle_%d.webp" % (rng.randi_range(1, SPARKLES)))
		sparkle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sparkle.stretch_mode = TextureRect.STRETCH_SCALE
		var px := size.x * rng.randf_range(0.09, 0.17)
		sparkle.size = Vector2.ONE * px
		# In a ring around the card (taller than wide, like the card), not hidden behind it.
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var radius := size.x * rng.randf_range(0.3, 0.47)
		sparkle.position = size / 2 + Vector2(cos(angle), sin(angle) * 1.3) * radius - sparkle.size / 2
		sparkle.pivot_offset = sparkle.size / 2
		sparkle.rotation = rng.randf_range(-0.3, 0.3)
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.material = _additive()
		sparkle.set_meta("alpha", 1.0)
		add_child(sparkle)
		_layers.append(sparkle)
		if animated:
			# Each starts at a random point in its twinkle, so some are always lit.
			var beat := rng.randf_range(0.9, 1.8)
			sparkle.scale = Vector2.ONE * rng.randf_range(0.2, 1.0)
			var twinkle := sparkle.create_tween().set_loops()
			twinkle.tween_property(sparkle, "scale", Vector2.ONE, beat * 0.4).set_trans(Tween.TRANS_SINE)
			twinkle.tween_property(sparkle, "scale", Vector2.ONE * 0.2, beat * 0.6).set_trans(Tween.TRANS_SINE)
			twinkle.tween_interval(rng.randf_range(0.1, 0.8))


func _tint(color: Color) -> void:
	var light := color.lightened(0.15)
	for rect in _layers:
		if is_instance_valid(rect):
			var alpha: float = rect.get_meta("alpha", 1.0)
			rect.modulate = Color(light.r, light.g, light.b, alpha)


static func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material
