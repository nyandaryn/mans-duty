class_name Equipment
extends RefCounted

# Representative complete-cartridge masses, not projectile masses (kg).
const ROUND_MASS = {"ak74":0.0106,"m16":0.0123,"svd":0.022,"pm":0.010,"m9":0.012,"pkm":0.0218}
# PKM 7.5 kg on its bipod; its box of 100 weighs 3.9 kg loaded, so the steel
# box and the belt about 1.7 kg.
const WEAPON_MASS = {"ak74":3.40,"m16":3.50,"svd":4.30,"pm":0.65,"m9":0.95,"pkm":7.50}
const MAG_MASS = {"ak74":0.23,"m16":0.11,"svd":0.21,"pm":0.05,"m9":0.09,"pkm":1.70}
const ITEMS = {
 "rpo_a":{"name":"РПО-А «Шмель» / кріплення", "short":"РПО-А · 93 мм","size":Vector2i(6,2),"mass":11.0,"color":Color("596143"),"description":"Одноразовий · 93 мм · 11 кг · 920 мм\nПочаткова швидкість: 125 м/с\nНа зовнішньому кріпленні наплічника. 4 — дістати / прибрати."},
 "ammo_ak74":{"name":"5.45 × 39 / 30", "short":"5.45", "weapon":"ak74","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("89805d")},
 "ammo_m16":{"name":"5.56 × 45 / 30", "short":"5.56", "weapon":"m16","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("788264")},
 "ammo_svd":{"name":"7.62 × 54R / 30", "short":"7.62R", "weapon":"svd","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("9b865f")},
 "ammo_pkm":{"name":"7.62 × 54R ЛПС / 100 у стрічці", "short":"СТРІЧКА","weapon":"pkm","rounds":100,"size":Vector2i(2,2),"mass":0.008,"color":Color("8f7a55")},
 "ammo_pm":{"name":"9 × 18 / 30", "short":"9×18", "weapon":"pm","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("8b775e")},
 "ammo_m9":{"name":"9 × 19 / 30", "short":"9×19", "weapon":"m9","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("697d7a")},
 "mortar_mine":{"name":"82-мм міна О-832ДУ", "short":"МІНА 82","size":Vector2i(1,2),"mass":3.3,"color":Color("5d6450"),"description":"Осколкова міна до міномета 2Б14 · 3,1 кг\nЗ основним і додатковими зарядами в конвертах — 3,3 кг."},
 "medkit":{"name":"Універсальна аптечка", "short":"АПТЕЧКА","size":Vector2i(2,2),"mass":0.45,"color":Color("788157")},
 "rangefinder":{"name":"Лазерний далекомір 6–12×", "short":"ДАЛЕКОМІР","size":Vector2i(2,2),"mass":0.32,"color":Color("606d63")},
 "recon_drone":{"name":"Розвіддрон / FPV", "short":"РОЗВІДДРОН","size":Vector2i(3,2),"mass":1.2,"color":Color("626e60")},
 # RPG-7V1 6.7 kg, the PGO-7V3 sight 0.5 kg; carried on the outside of the
 # pack. Its grenades inside, three to a load as the grenadier's bag holds:
 # each lies along the pack with its PG-7P charge unscrewed (about 0.65 m),
 # so the launcher and three rounds fill it.
 "rpg7":{"name":"РПГ-7В1 з ПГО-7В3 / кріплення", "short":"РПГ-7","size":Vector2i(6,1),"mass":7.2,"color":Color("5a5f45"),"description":"Багаторазовий · калібр труби 40 мм · 950 мм · 7,2 кг з прицілом\nПриціл ПГО-7В3: 2,7×, 13°, шкала 200–500 м\nНа зовнішньому кріпленні наплічника. 4 — дістати / прибрати, R — заряджання."},
 "pg7vl":{"name":"Постріл ПГ-7ВЛ «Луч»", "short":"ПГ-7ВЛ","size":Vector2i(4,1),"mass":2.6,"color":Color("4f5a3f"),"description":"Кумулятивна граната 93 мм з пороховим зарядом · 2,6 кг\nПочаткова 112 м/с, маршовий двигун до ~270 м/с\nБронепробиття ≥500 мм · цегла 1,7 м · самоліквідація 4–6 с."},
 "rpg22":{"name":"РПГ-22 «Нетто»", "short":"РПГ-22","size":Vector2i(5,1),"mass":2.7,"color":Color("5e6545"),"description":"Одноразовий · 72,5 мм · 2,7 кг · 755 / 850 мм\nПочаткова швидкість 133 м/с · бронепробиття 390–400 мм\nПрямий постріл 160 м · рамка 50 / 150 / 250 м."},
 "fpv_heat":{"name":"FPV-дрон 7\" · ПГ-7ВЛ", "short":"FPV · КУМ","size":Vector2i(3,2),"mass":2.3,"color":Color("4c5446"),"description":"Камікадзе 7\": бойова частина ПГ-7ВЛ (93 мм, ≥500 мм броні)\n~100 км/год · 6–8 хв польоту · аналогове відео 5,8 ГГц\nY — запуск і окуляри."},
 "fpv_frag":{"name":"FPV-дрон 7\" · осколковий", "short":"FPV · ОСК","size":Vector2i(3,2),"mass":1.9,"color":Color("545a48"),"description":"Камікадзе 7\": осколковий заряд у корпусі\nПо піхоті, окопах, легкій техніці\nY — запуск і окуляри."}
}
# Kinds of the grenade launchers a soldier can take up (key 4 / 5).
const LAUNCHERS := ["rpo_a","rpg7","rpg22"]
const FPV := ["fpv_heat","fpv_frag"]
const PACK_MASS := 1.35
# Clothing, boots, helmet, belt and pouches, the rangefinder: VestKind.BODY_GEAR_MASS;
# the body armour on top of it by its kind (VestKind.mass).

# Hunt et al. 2016: 30 m sprint TIME increased ~0.8%/kg over 10–30 kg.
# Reciprocal time -> speed. Outside that range this is a game extrapolation.
static func run_multiplier(load_kg: float) -> float:
 return 1.0/(1.0+0.008*(maxf(0,load_kg)-10.0))

static func carried_mass(weapons: Array, bag: BackpackState, medkits: int=2, vest: String="korsar") -> float:
 var total := VestKind.BODY_GEAR_MASS+VestKind.mass(vest)+maxi(0,medkits)*0.45+bag.mass()
 for w: WeaponState in weapons:
  total+=float(WEAPON_MASS[w.id])+float(MAG_MASS[w.id])*(w.pouches.size()+1)
  total+=w.ammunition_total()*float(ROUND_MASS[w.id])
 return total
