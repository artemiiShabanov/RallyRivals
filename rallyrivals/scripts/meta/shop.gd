class_name Shop
extends RefCounted
## Car shop transactions (code-meta-shop). Always-open and price-gated: buy() spends the car's price
## and adds it to the garage atomically — nothing changes if you can't afford it. Prices and which
## cars are on sale come from the Cars catalog (pink-slip boss trophies never appear).

static func can_buy(def: CarDef) -> bool:
	return def != null and not def.pink_slip_only and not Cars.is_owned(def.id) \
		and Save.can_afford(Cars.price_of(def))

## Returns whether the purchase went through. Fails if it's a trophy, already owned, or unaffordable.
static func buy(def: CarDef) -> bool:
	if def == null or def.pink_slip_only or Cars.is_owned(def.id):
		return false
	if not Save.spend(Cars.price_of(def)):
		return false
	Save.add_car(def.id)
	return true
