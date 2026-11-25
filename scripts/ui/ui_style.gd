class_name UiStyle
extends RefCounted
## Ortak UI renkleri (docs/08 paleti) ve küçük yardımcılar. M9'da gerçek Theme'e taşınır.

const SAP_GOLD := Color("e8a33d")
const MOSS := Color("5e8c4a")
const ROOT_SHADOW := Color("2b1e3f")
const MUSHROOM := Color("4fb3a9")
const ROT := Color("5a1e5c")
const ROT_EYE := Color("c9d93b")
const SKY_WHITE := Color("f4efe3")
const FONT_SIZE: int = 22
const FONT_SIZE_SMALL: int = 18


static func label(text: String, size: int = FONT_SIZE, color: Color = SKY_WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", ROOT_SHADOW)
	l.add_theme_constant_override(&"outline_size", 6)
	return l


static func panel_style(alpha: float = 0.85) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ROOT_SHADOW, alpha)
	sb.border_color = SAP_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # klavye odağı oyun girdisini çalmasın
	b.add_theme_font_size_override(&"font_size", FONT_SIZE_SMALL)
	return b
