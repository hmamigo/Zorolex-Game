extends RefCounted
## Paleta del Bosque de Bruma.
## Cuento de hadas calido: verdes oliva, tierras tostadas y niebla cremosa.

# --- base -------------------------------------------------------------
const INK := Color("241a15")
const INK_SOFT := Color("3a2a20")
const CREAM := Color("f7e8c8")
const CREAM_D := Color("dbc79c")

# --- zorro ------------------------------------------------------------
const FUR_D := Color("963e24")
const FUR := Color("c95c32")
const FUR_L := Color("ea8e54")
const FUR_LL := Color("f7b378")
const EYE := Color("241913")
const SCARF_D := Color("345e50")
const SCARF := Color("568c75")
const SCARF_L := Color("92c0a6")
const LEATH_D := Color("5a3824")
const LEATH := Color("895a3a")
const LEATH_L := Color("b07c4f")
const BOOT := Color("3a271d")
const BOOT_L := Color("5e402e")
const GOLD := Color("e8b260")

# --- hongo ------------------------------------------------------------
const CAP_D := Color("803021")
const CAP := Color("b0482d")
const CAP_L := Color("d66c44")
const SPOT := Color("f6e2be")
const STEM := Color("e8d1a8")
const STEM_D := Color("c6aa7e")
const MOSS := Color("627e46")
const MOSS_L := Color("8ba65c")

# --- terreno ----------------------------------------------------------
const GRASS_LL := Color("cbd97e")
const GRASS_L := Color("a8be65")
const GRASS := Color("88a04f")
const GRASS_D := Color("6a8240")
const GRASS_DD := Color("526834")
const DIRT_L := Color("96704e")
const DIRT := Color("795838")
const DIRT_D := Color("5f442b")
const DIRT_DD := Color("48321f")
const STONE_L := Color("9c9080")
const STONE := Color("7d7264")
const STONE_D := Color("5d5449")
const ROOT := Color("4a3527")

# --- bosque / cielo (hora dorada) -------------------------------------
const SKY_TOP := Color("2b444b")
const SKY_MID := Color("82977f")
const SKY_HORIZON := Color("f7c179")
const SUN := Color("ffd494")
const SUN_CORE := Color("fff1cf")
const FOG := Color("f0d5a6")
const FOREST_FAR := Color("97a68f")
const FOREST_MID := Color("607a62")
const FOREST_NEAR := Color("36503f")
const FOREST_FRONT := Color("1c2e25")
const RIM := Color("f6c47e")
const SHADOW := Color("2b3f44")
const FIREFLY := Color("ffe6a3")
const FLOWER_RUST := Color("c86a48")

# --- leyenda de sprites ----------------------------------------------
const LEGEND := {
	".": Color(0, 0, 0, 0),
	"0": INK,
	"1": FUR_D,
	"2": FUR,
	"3": FUR_L,
	"4": FUR_LL,
	"5": CREAM,
	"6": CREAM_D,
	"7": EYE,
	"8": SCARF_D,
	"9": SCARF,
	"a": SCARF_L,
	"b": LEATH_D,
	"c": LEATH,
	"d": LEATH_L,
	"e": BOOT,
	"f": BOOT_L,
	"g": GOLD,
	"h": CAP_D,
	"i": CAP,
	"j": CAP_L,
	"k": SPOT,
	"l": STEM,
	"m": STEM_D,
	"n": MOSS,
	"o": MOSS_L,
}
