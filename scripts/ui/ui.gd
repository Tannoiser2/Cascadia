class_name UI
extends RefCounted
## Helper grafici condivisi. Palette «Pacifico nord-occidentale», ripresa dalle carte del gioco:
## carta color crema con le curve di livello, barre in legno scuro, verde abete dei punteggi, azzurro del
## cielo della copertina. Titoli in Jost leggero a lettere spaziate (come «CASCADIA» sulla scatola),
## intestazioni in Lora (il serif delle carte), testi in Jost. Caratteri con licenza SIL Open Font.

const D = preload("res://scripts/data/cs_data.gd")

const PAPER := Color("#f1ead8")
const PAPER_D := Color("#e2d7bd")
const WOOD := Color("#4a2d1b")
const WOOD_L := Color("#6e4529")
const PINE := Color("#1d6b55")
const PINE_L := Color("#2f8d70")
const SKY := Color("#4f9fd1")
const SKY_D := Color("#2b6f9e")
const GOLD := Color("#d9a637")
const INK := Color("#2a2018")
const MUTED := Color("#7a6c58")
const CREAM := Color("#fbf6ea")
const RED := Color("#b8432f")

static var _tex := {}
static var font_title: Font
static var font_body: Font
static var font_semi: Font
static var font_bold: Font
static var font_serif: Font
static var font_serif_b: Font
static var font_italic: Font


static func init_fonts() -> void:
	if font_title != null:
		return
	var jost: FontFile = load("res://assets/fonts/Jost.ttf")
	font_title = _var(jost, 300)
	font_body = _var(jost, 420)
	font_semi = _var(jost, 540)
	font_bold = _var(jost, 680)
	var lora: FontFile = load("res://assets/fonts/Lora-Variable.ttf")
	font_serif = _var(lora, 500)
	font_serif_b = _var(lora, 650)
	font_italic = _var(load("res://assets/fonts/Lora-Italic-Variable.ttf"), 450)


static func _var(f: Font, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = f
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


static func tile_tex(id: String) -> Texture2D:
	return tex(D.tile_texture_path(id))


static func token_tex(a: String) -> Texture2D:
	return tex("res://assets/tokens/%s.webp" % a)


static func card_tex(key: String) -> Texture2D:
	# "orso_A" (fauna) oppure "foresta_E" (Landmark)
	var a := key.substr(0, key.length() - 2)
	if D.ANIMALS.has(a):
		return tex("res://assets/cards/fauna/%s.webp" % key)
	return tex("res://assets/cards/landmark/%s.webp" % key)


static func pcol(s: int) -> Color:
	return Color(D.PLAYER_COLORS[s % D.PLAYER_COLORS.size()])


static func panel_style(bg: Color, border: Color, bw := 1, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


static func paper_style(radius := 10) -> StyleBoxFlat:
	var sb := panel_style(PAPER, Color(WOOD, 0.35), 1, radius)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func wood_style(radius := 8) -> StyleBoxFlat:
	var sb := panel_style(WOOD, Color("#2e1b10"), 1, radius)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	return sb


static func label(text: String, size := 20, col := INK, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Titolo come sulla scatola: lettere maiuscole, sottili e spaziate.
static func title(text: String, size := 64, col := CREAM) -> Label:
	init_fonts()
	var fv := FontVariation.new()
	fv.base_font = font_title
	fv.spacing_glyph = int(size * 0.18)
	var l := label(text.to_upper(), size, col, fv)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l


static func heading(text: String, size := 24, col := WOOD) -> Label:
	init_fonts()
	return label(text, size, col, font_serif_b)


static func italic(text: String, size := 18, col := MUTED) -> Label:
	init_fonts()
	return label(text, size, col, font_italic)


static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, w := 200.0, h := 50.0, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	return b


static func primary(b: Button) -> Button:
	var n := panel_style(PINE, Color("#0f4636"), 1, 8)
	n.shadow_color = Color(0, 0, 0, 0.3)
	n.shadow_size = 4
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", panel_style(PINE_L, Color("#0f4636"), 1, 8))
	b.add_theme_stylebox_override("pressed", panel_style(Color("#0f4636"), Color("#0f4636"), 1, 8))
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CREAM)
	return b


## Coccarda verde dei punti, come sulle carte.
static func draw_badge(ci: CanvasItem, c: Vector2, r: float, text: String, col := PINE) -> void:
	init_fonts()
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var rr := r * (1.0 if i % 2 == 0 else 0.9)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)
	ci.draw_arc(c, r * 0.78, 0, TAU, 40, Color(1, 1, 1, 0.85), maxf(1.5, r * 0.06))
	var fs := int(r * (1.0 if text.length() <= 2 else 0.8))
	var w := font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font_bold, c + Vector2(-w / 2, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Esagono a punta in alto.
static func hex_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := deg_to_rad(-90 + 60 * k)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func make_theme() -> Theme:
	init_fonts()
	var th := Theme.new()
	th.default_font = font_body
	th.default_font_size = 20
	var sb := panel_style(CREAM, Color(WOOD, 0.45), 1, 8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	th.set_stylebox("normal", "Button", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color("#fffaf0")
	sbh.border_color = PINE
	th.set_stylebox("hover", "Button", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = PINE
	sbp.border_color = PINE
	th.set_stylebox("pressed", "Button", sbp)
	var sbd := sb.duplicate()
	sbd.bg_color = Color("#e6dfcf")
	sbd.border_color = Color(WOOD, 0.15)
	th.set_stylebox("disabled", "Button", sbd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", PINE)
	th.set_color("font_pressed_color", "Button", CREAM)
	th.set_color("font_disabled_color", "Button", Color("#a89c88"))
	th.set_font("font", "Button", font_semi)
	th.set_font_size("font_size", "Button", 20)
	th.set_color("font_color", "Label", INK)
	th.set_stylebox("panel", "PanelContainer", paper_style())
	th.set_stylebox("panel", "Panel", paper_style())
	th.set_font("normal_font", "RichTextLabel", font_body)
	th.set_font("bold_font", "RichTextLabel", font_bold)
	th.set_font("italics_font", "RichTextLabel", font_italic)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		th.set_font_size(k, "RichTextLabel", 20)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_font("font", "LineEdit", font_semi)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	th.set_stylebox("normal", "LineEdit", panel_style(Color.WHITE, Color(WOOD, 0.4), 1, 6))
	th.set_stylebox("focus", "LineEdit", panel_style(Color.WHITE, PINE, 2, 6))
	th.set_font("font", "TooltipLabel", font_body)
	th.set_font_size("font_size", "TooltipLabel", 18)
	th.set_color("font_color", "TooltipLabel", INK)
	var tp := panel_style(CREAM, WOOD, 1, 6)
	tp.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tp)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(WOOD_L, 0.7)
	sc.set_corner_radius_all(4)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(k, "VScrollBar", sc)
	var sct := StyleBoxFlat.new()
	sct.bg_color = Color(0, 0, 0, 0.08)
	th.set_stylebox("scroll", "VScrollBar", sct)
	return th
