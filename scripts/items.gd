extends RefCounted
## Consumables sold in shops and vending machines. Bought items go to the bag (phone → Bag) unless
## used on the spot. `heal` restores HP, `stamina` restores stamina.

const ITEMS := {
	"onigiri": {"name": "Onigiri", "icon": "onigiri", "price": 150, "heal": 15, "stamina": 0, "rarity": 0,
		"desc": "Salmon rice ball wrapped in crisp nori. A courier's best friend."},
	"melonpan": {"name": "Melon Pan", "icon": "melonpan", "price": 200, "heal": 20, "stamina": 10, "rarity": 1,
		"desc": "Sweet bun with a cookie crust. Mio swears by the 24H Mart batch."},
	"coffee": {"name": "Iced Coffee", "icon": "coffee", "price": 180, "heal": 5, "stamina": 50, "rarity": 0,
		"desc": "Black, cold, strong. Restores a lot of stamina."},
	"bento": {"name": "Deluxe Bento", "icon": "bento", "price": 600, "heal": 45, "stamina": 20, "rarity": 2,
		"desc": "Karaage, tamagoyaki and rice. A proper meal between fights."},
	"energy": {"name": "Volt Energy", "icon": "energy", "price": 250, "heal": 0, "stamina": 100, "rarity": 1,
		"desc": "Fizzy, neon and slightly illegal-tasting. Fully restores stamina."},
	"drink": {"name": "Ramune Soda", "icon": "drink", "price": 150, "heal": 5, "stamina": 30, "rarity": 0,
		"desc": "Marble-sealed lemon soda from the vending machine."},
	"bandage": {"name": "Bandages", "icon": "bandage", "price": 300, "heal": 25, "stamina": 0, "rarity": 0,
		"desc": "Quick patch-up for scrapes and bruises."},
	"pills": {"name": "Painkillers", "icon": "pills", "price": 500, "heal": 40, "stamina": 0, "rarity": 1,
		"desc": "Takes the edge off. Don't mix with Volt Energy."},
	"medkit": {"name": "Medical Kit", "icon": "medkit", "price": 800, "heal": 70, "stamina": 30, "rarity": 2,
		"desc": "Field kit from Pharmacist Sato. Gets you back on your feet."},
}
const RARITY_COLORS := [Color(0.45, 0.55, 0.7), Color(0.45, 0.4, 0.85), Color(0.95, 0.65, 0.25)]
