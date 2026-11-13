extends RefCounted

const FA_DIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const FACTION_COLORS: Dictionary = {
	1: Color(0.92, 0.20, 0.24), # P1: Crimson Red
	2: Color(0.18, 0.56, 0.98), # P2: Royal Sapphire Blue
	3: Color(0.18, 0.80, 0.40), # P3: Emerald Green
	4: Color(0.98, 0.78, 0.16), # P4: Imperial Sun Gold
}

const FACTION_NAMES_FA: Dictionary = {
	1: "قرمز",
	2: "آبی",
	3: "سبز",
	4: "زرد",
}

const GROUP_COLORS: Dictionary = {
	"brown": Color(0.46, 0.25, 0.14),
	"light_blue": Color(0.32, 0.76, 0.96),
	"pink": Color(0.88, 0.24, 0.58),
	"orange": Color(0.96, 0.52, 0.12),
	"red": Color(0.88, 0.16, 0.18),
	"yellow": Color(0.95, 0.82, 0.14),
	"green": Color(0.14, 0.66, 0.30),
	"dark_blue": Color(0.14, 0.26, 0.72),
	"railroad": Color(0.24, 0.26, 0.30),
	"utility": Color(0.24, 0.56, 0.56),
}

const GROUP_NAMES_FA: Dictionary = {
	"brown": "قهوه‌ای",
	"light_blue": "آبی روشن",
	"pink": "سرخابی",
	"orange": "نارنجی",
	"red": "قرمز",
	"yellow": "زرد",
	"green": "سبز",
	"dark_blue": "آبی تیره",
	"railroad": "راه‌آهن",
	"utility": "خدمات",
}

const STREET_GROUPS: Dictionary = {
	"brown": [1, 3],
	"light_blue": [6, 7],
	"pink": [9, 11],
	"orange": [14, 15],
	"red": [17, 19],
	"yellow": [21, 23],
	"green": [25, 27],
	"dark_blue": [29, 31],
}

const BOARD_TILES: Array[Dictionary] = [
	{"id": 0, "name": "شروع", "type": "corner", "subtype": "go", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 1, "name": "مولوی", "type": "street", "subtype": "street", "group": "brown", "price": 60, "house_cost": 50, "rents": [4, 20, 60, 180, 320, 450], "tax_amount": 0},
	{"id": 2, "name": "صندوق شانس", "type": "chest", "subtype": "chest", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 3, "name": "بازار بزرگ", "type": "street", "subtype": "street", "group": "brown", "price": 60, "house_cost": 50, "rents": [6, 30, 90, 270, 400, 550], "tax_amount": 0},
	{"id": 4, "name": "مالیات درآمد", "type": "tax", "subtype": "tax", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 150},
	{"id": 5, "name": "راه‌آهن جنوب", "type": "railroad", "subtype": "railroad", "group": "railroad", "price": 200, "house_cost": 0, "rents": [25, 50, 100, 200], "tax_amount": 0},
	{"id": 6, "name": "لاله‌زار", "type": "street", "subtype": "street", "group": "light_blue", "price": 100, "house_cost": 50, "rents": [8, 40, 100, 300, 450, 600], "tax_amount": 0},
	{"id": 7, "name": "بهارستان", "type": "street", "subtype": "street", "group": "light_blue", "price": 120, "house_cost": 50, "rents": [10, 50, 150, 450, 625, 750], "tax_amount": 0},
	{"id": 8, "name": "زندان", "type": "corner", "subtype": "jail", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 9, "name": "ولیعصر", "type": "street", "subtype": "street", "group": "pink", "price": 140, "house_cost": 100, "rents": [12, 60, 180, 500, 700, 900], "tax_amount": 0},
	{"id": 10, "name": "نیروگاه برق", "type": "utility", "subtype": "utility", "group": "utility", "price": 150, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 11, "name": "بلوار کشاورز", "type": "street", "subtype": "street", "group": "pink", "price": 160, "house_cost": 100, "rents": [14, 70, 200, 550, 750, 950], "tax_amount": 0},
	{"id": 12, "name": "کارت شانس", "type": "chance", "subtype": "chance", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 13, "name": "راه‌آهن غرب", "type": "railroad", "subtype": "railroad", "group": "railroad", "price": 200, "house_cost": 0, "rents": [25, 50, 100, 200], "tax_amount": 0},
	{"id": 14, "name": "جردن", "type": "street", "subtype": "street", "group": "orange", "price": 180, "house_cost": 100, "rents": [16, 80, 220, 600, 800, 1000], "tax_amount": 0},
	{"id": 15, "name": "میدان ونک", "type": "street", "subtype": "street", "group": "orange", "price": 200, "house_cost": 100, "rents": [18, 90, 250, 700, 875, 1050], "tax_amount": 0},
	{"id": 16, "name": "پارکینگ آزاد", "type": "corner", "subtype": "free_parking", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 17, "name": "سعادت‌آباد", "type": "street", "subtype": "street", "group": "red", "price": 220, "house_cost": 150, "rents": [20, 100, 300, 750, 925, 1100], "tax_amount": 0},
	{"id": 18, "name": "کارت شانس", "type": "chance", "subtype": "chance", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 19, "name": "شهرک غرب", "type": "street", "subtype": "street", "group": "red", "price": 240, "house_cost": 150, "rents": [22, 110, 330, 800, 975, 1150], "tax_amount": 0},
	{"id": 20, "name": "راه‌آهن شمال", "type": "railroad", "subtype": "railroad", "group": "railroad", "price": 200, "house_cost": 0, "rents": [25, 50, 100, 200], "tax_amount": 0},
	{"id": 21, "name": "اندرزگو", "type": "street", "subtype": "street", "group": "yellow", "price": 260, "house_cost": 150, "rents": [24, 120, 360, 850, 1025, 1200], "tax_amount": 0},
	{"id": 22, "name": "شرکت آب", "type": "utility", "subtype": "utility", "group": "utility", "price": 150, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 23, "name": "نیاوران", "type": "street", "subtype": "street", "group": "yellow", "price": 280, "house_cost": 150, "rents": [26, 130, 390, 900, 1100, 1275], "tax_amount": 0},
	{"id": 24, "name": "برو به زندان", "type": "corner", "subtype": "go_to_jail", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 25, "name": "الهیه", "type": "street", "subtype": "street", "group": "green", "price": 300, "house_cost": 200, "rents": [28, 150, 450, 1000, 1200, 1400], "tax_amount": 0},
	{"id": 26, "name": "صندوق شانس", "type": "chest", "subtype": "chest", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 0},
	{"id": 27, "name": "زعفرانیه", "type": "street", "subtype": "street", "group": "green", "price": 320, "house_cost": 200, "rents": [30, 160, 480, 1050, 1275, 1450], "tax_amount": 0},
	{"id": 28, "name": "راه‌آهن شرق", "type": "railroad", "subtype": "railroad", "group": "railroad", "price": 200, "house_cost": 0, "rents": [25, 50, 100, 200], "tax_amount": 0},
	{"id": 29, "name": "فرشته", "type": "street", "subtype": "street", "group": "dark_blue", "price": 350, "house_cost": 200, "rents": [35, 175, 500, 1100, 1300, 1500], "tax_amount": 0},
	{"id": 30, "name": "مالیات لوکس", "type": "tax", "subtype": "tax", "group": "", "price": 0, "house_cost": 0, "rents": [], "tax_amount": 100},
	{"id": 31, "name": "تجریش", "type": "street", "subtype": "street", "group": "dark_blue", "price": 400, "house_cost": 200, "rents": [50, 200, 600, 1400, 1700, 2000], "tax_amount": 0},
]

static func fa_num(val: Variant) -> String:
	var s: String = str(val)
	var out: String = ""
	for i in range(s.length()):
		var code: int = s.unicode_at(i) - 48
		if code >= 0 and code <= 9:
			out += FA_DIGITS[code]
		else:
			out += s[i]
	return out

static func get_tile(tid: int) -> Dictionary:
	if tid >= 0 and tid < BOARD_TILES.size():
		return BOARD_TILES[tid]
	return {}
