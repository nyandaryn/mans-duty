# Equipment and ballistics — 0.10.0

## Using the loadout

Click a weapon card to open the weapon grid. Hover or focus a card to see its
caliber, empty mass, magazine capacity, muzzle velocity and operating modes.
Choose the assault backpack to enable a 6 × 4 grid. Item footprints occupy
actual cells: paper ammunition packets use 2 × 1; a medkit or rangefinder 2 × 2.
Click the catalog to add, drag to move, right-click to remove. Pack contents
must be removed before unequipping it. Empty pack mass is 1.35 kg; payload
limit is 18 kg. The cell layout is a gameplay abstraction, not a volume solver.

All carryable ammunition is packed in folded kraft-paper packets of 30 rounds,
including the requested 5.45 × 39 format. Other calibers use the same 30-round
inventory convention. Packet paper weighs 8 g. No metal ammunition cans are
carried. Per-round and equipment masses are representative game values.

Enter a name and Save/Update to store a preset. The dropdown loads a complete
weapon / uniform / backpack / contents layout. Saving an existing name updates
it. Files are local `user://loadouts.cfg` and `user://settings.cfg`. Up to 24
named presets, 32 characters per name. A mission receives its own copy;
consumption never edits the selected loadout or saved preset.

## In combat

- **Tab**: inventory, or interrupt handling and return to inventory. Combat continues.
- Select an ammunition packet, then a compatible magazine, then transfer.
- Alternatively select source and destination magazines of the same caliber.
- Handling closes the inventory to show the first-person animation. Weapons
  and movement are blocked during handling. Wounds interrupt the action.
- Backpack access takes 3.4 s; loading is 0.9 s per cartridge. Magazine handling
  without a backpack starts with a 1 s draw and ends with 0.8 s stow. Backpack
  items take 2.2 s to stow. A round is committed only at a completed transfer
  checkpoint. Interruption preserves completed rounds and the chamber.
- Paper packets visibly open and empty; an exhausted packet is discarded.
- **K**: retrieve/stow an equipped laser rangefinder. **Mouse wheel**: optical
  zoom 6–12× (as the Maven RFZ.1 6–12×21; fixed-power hand rangefinders are
  6–7×), kept between uses. **Left mouse**: measure.
  6× view, 0.35 s sampling, 1 m display increments, 5–1200 m modeled range.
  Aim movement invalidates the sample. The first collider is measured;
  an obstructed target cannot be measured through the obstruction. Sky gives
  no return. Opaque leaf texels block a distant reading; transparent gaps do not.
  This is a simplified laser model, without material reflectivity,
  fog/rain attenuation or a beam-footprint solver.
- **H**: first use the two belt medkits. Once exhausted, access a backpack
  medkit before the existing 6 s treatment. In inventory a selected pack
  medkit can be used directly. It is consumed only after treatment completes.
- **T**, **T + 1/2/3**: physical magazine inspection, with a short, deliberately
  coarse weight estimate. Repeating an unchanged inspection does not reroll
  its uncertainty. No precise ammunition count is added to the combat HUD.
- **B** still changes fire mode. **K** is separate from that existing binding.

Yellow tape marks the player's squad (UA); red marks the opposing squad (RF).
Tape follows each upper-arm joint and does not change with camouflage.

## Load and running speed

Hunt, Tofari, Billing & Silk (2016), *Tactical combat movements*, studied 19
soldiers with external loads of 10–30 kg. Repeated 30 m sprint completion time
increased about 0.8% per kg on average; this is not a universal speed law.
Source: https://doi.org/10.1080/00140139.2015.1132780

The game translates that time relationship into speed:

`v(L) = 6.3 / [1 + 0.008 × (L − 10)] m/s`

`L` is total external carried mass, not body mass: clothing/armor/helmet,
weapons, all magazines, chambered cartridges, belt medkits, pack and contents.
The base 6.3 m/s is the game's 10 kg reference. At 20 kg it is 5.83 m/s; at
30 kg, 5.43 m/s. Outside the studied 10–30 kg range the formula is explicitly a
game extrapolation. Injury, stance and aiming restrictions apply separately.
Walking speed is unchanged. Spending ammunition or using medkits reduces mass.

## Projectile flight

`FlightModel` uses G1 drag coefficients by Mach number, representative per-load
BC values, standard-density air (1.225 kg/m³), 340.3 m/s speed of sound and
9.80665 m/s² gravity. Acceleration uses air-relative velocity. RK4 integration
and collision sweeps are bounded to 1/240 s; the projectile is never rendered
as a visible white dot. Wind support is implemented, default weather is calm.
Iron-sight zero and PSO-1 calibration use the same flight solver. Existing
geometric thickness, layered penetration and energy loss remain active.

Profiles (game FMJ approximations, not certified ammunition firing tables):

| Weapon | Muzzle m/s | G1 BC | Projectile kg |
| --- | ---: | ---: | ---: |
| AK-74M | 880 | .310 | .0034 |
| M16A2 | 940 | .304 | .0040 |
| SVD | 830 | .411 | .0096 |
| PM | 315 | .120 | .0061 |
| M9 | 365 | .160 | .0080 |
| PKM (LPS, 0.31.0) | 825 | .374 | .0096 |

The solver is independently checked against the Hornady 2022 metric chart's
5.45 V-MAX reference at 50–300 m (BC .285, 856 m/s), within 4 m/s. That
reference validates the solver; it does not turn the game's FMJ into V-MAX.
Also tested: frame-step convergence, wind drift, sight zeros, scope alignment,
centimeter-thick barriers, tapered concrete and overlapping materials.

Sources:
- G1 BRL reference data / JBM: https://jbmballistics.com/downloads.html
- Numeric table mirror: https://github.com/gehtsoft-usa/go_ballisticcalc/blob/master/Drag.go
- Independent manufacturer reference: https://static.hornady.media/presscenter/docs/1410998059-2022-Metric-Ballistics-Chart.pdf

This remains a point-mass game simulation: no spin drift, Coriolis, bullet yaw,
fragment-by-fragment terminal mechanics or certified armor behavior.

## Reconnaissance quadcopter (0.11.0)

Розвіддрон / FPV — 0.11.0:
Додай «Розвіддрон / FPV» у наплічник (3×2 клітинки, комплект 1,2 кг).
J — дістати дрон / надягти або зняти окуляри; також через інвентар Tab.
WASD — горизонтальний рух, миша — курс і нахил камери.
Space — зліт / набір висоти, Ctrl — зниження / посадка, Shift — режим S (спорт).
F після посадки — вимкнути мотори; J — повернутися до бійця.
Підійди до дрона і натисни F: складання у наплічник займає 2,2 с.
Потрібні вільні 3×2 клітинки. Батарея й пошкодження зберігаються.
Пілот не рухається й не стріляє через окуляри, але може бути поранений.
Режим польоту стабілізований (GPS-утримання, як у Mavic 3): стік задає
швидкість, рама нахиляється, тяга й опір повітря розганяють і гальмують
дрон. Відпустиш — гальмує нахилом назад і зависає там, де спинився, проти
вітру й поривів. Це не acro-симулятор. При втраті зв’язку / низькому
заряді — автопосадка; на порожній батареї мотори зупиняються.

Game parameters (from DJI Mavic 3 specs): 40 minutes of hover, a fifth
less flat out; 15 m/s at up to 30° of pitch (N) / 21 m/s at 35° (S, Shift),
0→14 m/s in ~3.6 s, ~17 m to stop from 15 m/s, ~28 m from 21 m/s; climb
6 / 8 m/s, descent 6 m/s easing to ~1 m/s at touchdown; yaw up to 200°/s;
holds within a metre in wind to 12 m/s; thrust to weight 2, sagging in the
last quarter of the charge. Geofence at the edge of the map (the whole
operation area in the great assault), 450 m nominal radio range with
occlusion penalty, 100 m height limit. Pilot-side 0.4 kg controller/goggles remains
counted after deploying the 0.8 kg aircraft. Radio obstruction, battery and
flight controls are approximations; no weapons, automatic enemy markers,
acro/rate flight, GPS return-to-home, repair or battery exchange yet.

## RPO-A Shmel — 0.13.0

Choose the assault pack, then add the launcher from the equipment catalog.
The tube is carried on an exterior attachment and reserves 6 × 2 grid cells;
its loaded mass is 11 kg and the normal 18 kg payload limit still applies.
Press **4** to retrieve or stow, right mouse to aim and left mouse to fire.
Retrieval takes 3.8 seconds. The tube is single-use; only F8 retains it for
debug reuse. A blocked muzzle or interrupted draw does not consume it.
See [SHMEL-REFERENCES.md](SHMEL-REFERENCES.md) for nominal specifications
and the distinction between sourced values and game damage parameters.

## Нове спорядження 0.31.0 у наплічнику

| Предмет | Клітинки | Маса | Класи |
| --- | ---: | ---: | --- |
| РПГ-7В1 з ПГО-7В3, на кріпленні | 6 × 1 | 7,2 кг | гранатометник |
| Постріл ПГ-7ВЛ «Луч» | 4 × 1 | 2,6 кг | гранатометник |
| РПГ-22 «Нетто», на кріпленні | 5 × 1 | 2,7 кг | стрілець, гранатометник |
| Стрічка 7.62 × 54R ЛПС / 100 | 2 × 2 | ≈2,2 кг | кулеметник |
| FPV-дрон 7" · ПГ-7ВЛ | 3 × 2 | 2,3 кг | оператор БПЛА |
| FPV-дрон 7" · осколковий | 3 × 2 | 1,9 кг | оператор БПЛА |

Ліміт вантажу наплічника 18 кг лишається: РПГ-7 і три постріли — 15 кг.
Джерела характеристик і межі моделей: [WEAPONS-REFERENCES.md](WEAPONS-REFERENCES.md).

## Кулемет ПКМ — 0.31.0

Клас «Кулеметник». ПКМ — 7,5 кг, 650 пострілів/хв, лише автоматичний
вогонь, стрічка на 100 набоїв у сталевій коробці під ствольною коробкою.
На бійці — коробка в кулеметі й дві запасні (300 набоїв); коробка зі
стрічкою важить 1,7 кг, повна — 3,9 кг, набій — 21,8 г. Куля ЛПС
(57-Н-323С): 825 м/с, G1 BC .374, 9,6 г; рана й бронепробиття — як у СВД.

- **X** — сошки: лише лежачи або коли під шарніром сошок у межах їхньої
  довжини є опора (бруствер, підвіконня, стінка, капот). На сошках віддача
  — 0,33 звичайної, розкид прицільного вогню більш ніж удвічі менший, кулемет у
  руках майже не гуляє. Рух швидше 0,6 м/с, перелазіння, гранатомет,
  пристрій чи втрата опори складають сошки.
- **PgUp / PgDn** — приціл 1–15, крок 100 м (типово 3 — 300 м). Повзунок
  рамки підіймається на висоту, що дає кут прицілювання цієї дальності за
  тією самою моделлю польоту, і кулемет біля ока нахиляється на цей кут:
  куля йде вздовж каналу ствола.
- Заміна коробки: кришка ствольної коробки відкидається, стара стрічка
  виходить (1,5 с), нова лягає на лоток, кришка закривається (2,2 с).
  Кулемет стріляє з відкритого затвора: наприкінці стрічки затвор іде
  вперед на порожній патронник, після заміни — **V**.

## РПГ-7В1 з ПГО-7В3 і пострілами ПГ-7ВЛ — 0.31.0

Клас «Гранатометник». **4** — зняти з кріплення (3,0 с) / повернути
(2,4 с); **5** — наступний гранатомет із наплічника (порядок: РПГ-7,
РПО-А, РПГ-22). **R** з РПГ-7 у руках — заряджання 6 с: ліва рука дістає
постріл і вставляє його в дуло. Постріл покидає наплічник лише в кінці,
коли сів у трубу; перерване заряджання лишає його в наплічнику.
Незаряджений РПГ-7 не стріляє (клацання й підказка). Після пострілу він
лишається в руках порожнім; заряджений важчий на 2,6 кг.

Права кнопка миші — приціл ПГО-7: 2,7×, поле 13°, окуляр на 52 мм вище
осі труби. Сітка: шеврони 2–5 — 200–500 м (верхній — оптична вісь),
поділки упередження через 10 тисячних (1/6000 кола) до 40 в обидва боки,
далекомірна шкала внизу ліворуч для цілі заввишки 2,7 м: 2–10 —
200–1000 м. Усі позначки обчислено з польоту ПГ-7ВЛ у грі, а не
перенесено з реальної сітки. Без прицілу, з плеча, граната отримує
випадковий розкид до ±0,012 рад.

Політ ПГ-7ВЛ: 112 м/с з труби; за ≈11 м вмикається маршовий двигун і за
0,4 с (прискорення 440 м/с²) розганяє гранату до ≈270 м/с; далі опір
k·v² і падіння. Підривник зводиться за 2,5 м від дула: ближче граната
розбивається без вибуху. Самоліквідація — через 4,5 с. Бронепробиття
500 мм, цегла — до 1,7 м. По відкритій піхоті кумулятивна граната —
невеликий розрив (до 7 м), не осколкова.

## РПГ-22 «Нетто» — 0.31.0

Класи «Стрілець» і «Гранатометник». **4 / 5** знімає трубу з кріплення
в похідному положенні (2,2 с): складеним РПГ-22 не стріляє й не
прицілюється. **R** — бойове положення, 6 с: кришки знято, висувна труба
витягується й на 60 % дії фіксується, діоптр і рамка піднімаються,
механізм зводиться. Скласти назад не можна: повернутий на кріплення,
РПГ-22 лишається висунутим (це видно й на наплічнику) і наступного разу
знімається вже готовим. Рамка: 5 / 15 / 25 — 50 / 150 / 250 м, позначки
обчислено з польоту гранати: 133 м/с, двигун згоряє в трубі, далі лише
опір і падіння. Бронепробиття 390 мм. Після пострілу трубу відкидає.

Задній струмінь (обидва РПГ) — умовний, не настанова: калічить до 8 м
позаду РПГ-7 і до 5 м позаду РПГ-22, слабше з відстанню; стіна ближче
1,1 м за спиною б'є й самого стрільця. Боти-гранатометники не стріляють,
коли за спиною свої в межах 30 м (РПГ-7) або 15 м (РПГ-22).

## FPV-дрони — 0.31.0

Клас «Оператор БПЛА». Два 7-дюймові камікадзе: з бойовою частиною
ПГ-7ВЛ (той самий кумулятивний струмінь, що й з гранатомета) і з
осколковим зарядом у корпусі (розрив до 15 м; на броні — 14 мм при
контакті). **Y** — дістати з наплічника (3,4 с), поставити на землю
перед собою (1 с), надіти окуляри. **Y** знову — зняти окуляри: у повітрі
дрон ще ≈1,3 с тримає останню команду, потім мотори зупиняються, і він
падає; на землі — повертається в наплічник. Розвіддрон, якщо був у
повітрі, чекає й повертається після FPV.

Керування в режимі angle (самовирівнювання): **W / S** — тангаж,
**A / D** — крен, миша — курс і нахил камери (10–55°), **Space / Ctrl**
— газ, **Shift** — форсаж, **ЛКМ** — підрив у повітрі. Нахил 35° дає
≈22 м/с, 50° — ≈28 м/с (≈100 км/год). Бойова частина зводиться за 5 м від
точки зльоту; удар на швидкості її підриває, при падінні без живлення
вона спрацьовує з імовірністю 85 % (ПГ-7ВЛ) чи 50 % (осколкова).

Зв'язок: відео 5,8 ГГц до ≈2,5 км, керування до ≈3,5 км від антен
пілота (1,5 м над землею); будинок на лінії гасить картинку, земля в
першій зоні Френеля — теж. Батарея 6S: ≈7 хв на крейсерському газі,
менше на форсажі. Куля чи осколки збивають FPV, як і розвіддрон.

## Бронежилети — 0.31.0

Вкладка «БРОНЯ» в спорядженні; вибір зберігається в налаштуваннях і в
комплектах.

| Бронежилет | Маса | Плити | Клас плит | М'яка броня | Від уламків проходить | Біг без зброї |
| --- | ---: | --- | --- | --- | ---: | ---: |
| «Корсар М3с» | 11,6 кг | 25 × 30 см | 4 кл. ДСТУ | так | ≈59 % | 21,3 км/год |
| 6Б45 «Ратник» | 9,0 кг | 25,5 × 32 см | Бр5 / 5А | так | ≈58 % | 21,8 км/год |
| Плитоноска | 6,9 кг | 25 × 30 см | 6 кл. ДСТУ | ні | ≈79 % | 22,1 км/год |

Плита тримає кулю, поки бронепробиття кулі (гвинтівкової — 1,0 біля
дула, пістолетної — 0,3, зменшується з енергією) менше за
`клас × (0,72 + 0,28 × цілісність)`, де клас — 1,25 / 1,45 / 1,60. Ціла
плита кожного класу тримає гвинтівкову кулю біля дула; розбита плита
4 класу піддається першою (раніше всі плити були такими, як нинішня
4 класу). Хітбокси плит — реального розміру, верх на яремній вирізці
(1,42 м). М'яка броня зупиняє кулю ПМ, а 9 мм M9 — лише ту, що втратила
понад 20 % енергії; гвинтівкову не зупиняє.

Уламки розриву: шкода зважена за тим, куди влучають уламки в людину на
відкритому і наскільки небезпечна там рана (голова 0,22, шия 0,05,
груди 0,25, живіт 0,18, пах 0,04, плечі 0,03, решта рук 0,07, ноги 0,16).
М'яка броня затримує 76 % уламків на тому, що прикриває, плита — 98 %.

Маса: `L` у формулі бігу тепер — 6,3 кг (форма 1,8, взуття 1,7, шолом 1,4,
пояс із порожніми підсумками 1,0, далекомір 0,4) плюс бронежилет, замість
колишніх сталих 8,72 кг разом із плитами. Боти: наші — у «Корсарах»,
противник — у 6Б45, кожен четвертий з обох боків — у плитоносці.
