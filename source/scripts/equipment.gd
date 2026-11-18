class_name Equipment
extends RefCounted

# Representative complete-cartridge masses, not projectile masses (kg).
const ROUND_MASS = {"ak74":0.0106,"m16":0.0123,"svd":0.022,"pm":0.010,"m9":0.012}
const WEAPON_MASS = {"ak74":3.40,"m16":3.50,"svd":4.30,"pm":0.65,"m9":0.95}
const MAG_MASS = {"ak74":0.23,"m16":0.11,"svd":0.21,"pm":0.05,"m9":0.09}
const ITEMS = {
 "rpo_a":{"name":"РПО-А «Шмель» / кріплення", "short":"РПО-А · 93 мм","size":Vector2i(6,2),"mass":11.0,"color":Color("596143"),"description":"Одноразовий · 93 мм · 11 кг · 920 мм\nПочаткова швидкість: 125 м/с\nНа зовнішньому кріпленні наплічника. 4 — дістати / прибрати."},
 "ammo_ak74":{"name":"5.45 × 39 / 30", "short":"5.45", "weapon":"ak74","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("89805d")},
 "ammo_m16":{"name":"5.56 × 45 / 30", "short":"5.56", "weapon":"m16","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("788264")},
 "ammo_svd":{"name":"7.62 × 54R / 30", "short":"7.62R", "weapon":"svd","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("9b865f")},
 "ammo_pm":{"name":"9 × 18 / 30", "short":"9×18", "weapon":"pm","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("8b775e")},
 "ammo_m9":{"name":"9 × 19 / 30", "short":"9×19", "weapon":"m9","rounds":30,"size":Vector2i(2,1),"mass":0.008,"color":Color("697d7a")},
 "mortar_mine":{"name":"82-мм міна О-832ДУ", "short":"МІНА 82","size":Vector2i(1,2),"mass":3.3,"color":Color("5d6450"),"description":"Осколкова міна до міномета 2Б14 · 3,1 кг\nЗ основним і додатковими зарядами в конвертах — 3,3 кг."},
 "medkit":{"name":"Універсальна аптечка", "short":"АПТЕЧКА","size":Vector2i(2,2),"mass":0.45,"color":Color("788157")},
 "rangefinder":{"name":"Лазерний далекомір", "short":"ДАЛЕКОМІР","size":Vector2i(2,2),"mass":0.32,"color":Color("606d63")},
 "recon_drone":{"name":"Розвіддрон / FPV", "short":"РОЗВІДДРОН","size":Vector2i(3,2),"mass":1.2,"color":Color("626e60")}
}
const PACK_MASS := 1.35
const BASE_GEAR_MASS := 8.72 # Clothing, boots, helmet, plates, carrier, pouches and the rangefinder in its chest pouch.

# Hunt et al. 2016: 30 m sprint TIME increased ~0.8%/kg over 10–30 kg.
# Reciprocal time -> speed. Outside that range this is a game extrapolation.
static func run_multiplier(load_kg: float) -> float:
 return 1.0/(1.0+0.008*(maxf(0,load_kg)-10.0))

static func carried_mass(weapons: Array, bag: BackpackState, medkits: int=2) -> float:
 var total := BASE_GEAR_MASS+maxi(0,medkits)*0.45+bag.mass()
 for w: WeaponState in weapons:
  total+=float(WEAPON_MASS[w.id])+float(MAG_MASS[w.id])*(w.pouches.size()+1)
  total+=w.ammunition_total()*float(ROUND_MASS[w.id])
 return total
