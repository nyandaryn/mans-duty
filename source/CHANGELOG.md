## 0.22.0 — 2026-11-18

- НАВЧАННЯ для командира БМ-21 «Град» — новий пункт головного меню. Курс
  іде на карті Авдіївки, на полігоні без противника. П'ять розділів, кожен
  можна пройти окремо:
  1. Марш на вогневу позицію: кабіна, запалювання, стартер, зчеплення й
     передачі, рух полем, машина боком до цілі, стоянкове гальмо.
  2. Переведення в бойове положення: КВП, ручний газ, щитки, кран
     «БОЙОВЕ», стопор пакета, чохол, кронштейн прицілу.
  3. Розвідка цілі дроном СП і позначка далекоміром.
  4. Дані для стрільби й наведення: планшет, кутомір, приціл, рівень,
     бусоль і бульбашка рівня.
  5. Пуск, коректура, зміна позиції: пульт, пристрілювальна серія,
     доповідь СП, поправки, залп, згортання й від'їзд.
  Картка кроку праворуч угорі пояснює, що робити, які клавіші, і показує
  поточні значення: «Кутомір 30-00 → потрібно 33-17». Маркер на місцевості
  веде до потрібних дверей, крана чи вогневої позиції. Над планшетом і
  радіостанцією картка стискається й переходить донизу. F6 виконує крок
  автоматично, якщо застряг; доповідь СП пропустити не можна. Пройдені
  розділи зберігаються. Наприкінці — підсумок: час, центр розривів відносно
  цілі, чи знищено ОП-2, скільки кроків пропущено. Після навчання
  спорядження й обрана операція повертаються.
- Головне меню перероблено. На фоні — місто з кольорокорекцією. Пункти
  меню пронумеровані й підсвічуються. Праворуч — картка «Продовжити» з
  останньою операцією й класом і новина про навчання. Знизу — підказки
  клавіш. Кампанія, «Великий штурм», спорядження й налаштування — окремі
  екрани в тому ж стилі; ESC повертає на крок назад. Шрифти — Noto Sans
  (SIL OFL 1.1, див. FONT-CREDITS.md).
- Налаштування — окремий екран: гучність, чутливість миші,
  повноекранний режим (F11), тіні, вигляд противника, клавіші бійця та
  «Града».
- Пауза, підсумок операції та екран завантаження з назвою операції й
  порадою — у тому ж стилі.
- Виправлено: якщо під час робіт біля «Града» (чохол, стопор, кран,
  кронштейн) натиснути M, відкривалася карта району штурму 1 : 10 000
  замість планшета, а G — команди мінометного розрахунку замість радіо.
- Виправлено: на старті командир «Града» стояв спиною до машини.
- Доповідь СП про розриви тепер іде відносно цілі, по якій стріляли, а не
  відносно найближчого ОП. Опорний пункт без гарнізону вважається знищеним
  після трьох розривів ближче 25 м.
- Повідомлення по радіо переносяться на другий рядок, а не виходять за
  край екрана.
- Збірки для macOS і Windows: dist/kvartal-0.22.0-macos.zip (universal,
  ad-hoc підпис) і dist/kvartal-0.22.0-windows.zip (x86_64). README-macOS.txt
  тепер пояснює перший запуск і для macOS 12 та старших («Захист і безпека»
  → «Загальні»), README-Windows.txt — як пройти SmartScreen.

## 0.21.0 — 2026-11-18

- «Великий штурм» тепер іде на реальній карті Авдіївки. Поле бою — південний
  приватний сектор, рубежі А · вул. Ярослава Гомзи → Б · вул. Спортивна →
  В · вул. Соборна. Будинки, вулиці, лісосмуги й водойми взято з
  OpenStreetMap (ODbL), рельєф — з SRTM. Навколо поля 12 × 12 км
  місцевості: місто, промзона, селища, поля й посадки. Координати — у сітці
  СК-42 (зона 7), як на топографічному аркуші. Противник тримає дев'ять
  опорних пунктів (ОП), по три на кожній вулиці.
- Поле бою малюється швидше: дрібні деталі об'єднано в клітинки по 100 м.
  Кадр зі старту — 3,8 мс замість 6,6 мс, з вулиці — 2,9 мс замість 5,1 мс.
- Новий клас — КОМАНДИР БМ-21 «ГРАД», лише для «Великого штурму».
  Реактивна система залпового вогню на шасі Урал-375Д стоїть у лісосмузі
  за 5 км від бою. У пакеті 40 ракет 9М22У з великими гальмівними кільцями,
  машина в похідному положенні: пакет зачохлений і застопорений. Усе інше —
  як у справжнього розрахунку, і всю його роботу робиш сам:
  - Водій: запалювання, стартер, зчеплення, п'ять передач і задня,
    роздавальна коробка (пряма / знижена), стоянкове гальмо, ручний газ,
    підкачка шин, броньовані щитки на скло. Двигун глухне, якщо кинути
    зчеплення; гальма слабшають, коли падає тиск повітря.
  - Переведення в бойове положення: кран «БОЙОВЕ / ПОХІД» вимикає ресори
    задніх мостів, чохол знімається за 20 с, пакет розстопорюється,
    кронштейн прицілу ставиться за 8 с. Коробка відбору потужності живить
    електропривід наведення (до 7°/с по горизонту, до 5°/с по куту); без
    неї — ручні маховики. Сектор обстрілу: 102° ліворуч і 70° праворуч.
    Над кабіною (±34°) пуск блокується, якщо кут менший за 11°.
  - Навідник: панорама ПГ-1М і приціл Д726-45. Кутомір, приціл і рівень
    задаються в тисячних. Бусоль, бульбашка рівня, крен машини.
    Наведення — в бусоль: кутомір = αц − ПБ ± 30-00.
  - Командир: пульт управління вогнем. ВБ-55, контроль живлення, ключ
    АВТ / ОДИН, зведення програмного механізму, рукоятка пуску (SPACE).
    У режимі АВТ ракети йдуть через 0,5 с, повний залп — 20 с.
  - Розвідка — дрон спостережного пункту (СП) через ретранслятор:
    до 3 км зв'язку, зум до 28×, лазерний далекомір (до 1200 м). T —
    позначити ціль: її координати потрапляють на планшет.
  - Планшет (M): карта району з сіткою, GPS машини, цілі, дальність і
    дирекційний кут до цілі, перевищення й кут місця, перевірка сектора
    та зони кабіни; таблиці стрільби для трьох варіантів кілець; пам'ятка.
  - Радіо (G): «Штурмовим групам — вперед», «Закріпитися», дрон, доповідь
    СП. СП доповідає відхилення центру розривів: переліт / недоліт у
    метрах, ліворуч / праворуч у тисячних.
  - Ракета летить за тим самим розрахунком, що й таблиця стрільби. Поблизу
    ВП вона зачіпає крони посадки, тож стріляти треба з відкритого поля.
    Розсіювання — порядку Д/326 по дальності й Д/278 по напрямку. Струмінь
    за пакетом небезпечний на ~20 м.
  - ОП вважається знищеним, коли від залоги лишилася третина або ракета
    влучила ближче 7 м. Через 2,5–4 хв після залпу противник накриває ВП
    у відповідь: позицію треба змінити.
  - Звуки пуску — справжні записи БМ-21 (DVIDS, публічне надбання;
    Оперативне командування «Захід», CC BY 4.0). Двигун — запис БМ-21-1
    (Міноборони РФ, CC BY 4.0); тон іде за обертами. Деталі —
    AUDIO-CREDITS.md.
- Обмеження «Града»: перезаряджання немає (лише 40 ракет у пакеті); кільця
  на ракетах не міняються. Таблиця стрільби — модель, підігнана під
  опубліковані дані 9М22У, а не офіційні ТС. Контрбатарейний вогонь
  заскриптований.

## 0.20.0 — 2026-11-17

- Збірка для macOS: `dist/kvartal-0.20.0-macos.zip`, universal (Apple
  Silicon та Intel), ad-hoc підпис. Перший запуск — через «Приватність і
  безпека → Усе одно відкрити» (README-macOS.txt в архіві). Control +
  клацання на Mac — правий клік; F8 / F11 — разом із Fn.
- Розгортання й згортання міномета тепер анімовані: опорна плита, двонога,
  ствол, приціл (при згортанні — у зворотному порядку). Мінометник сідає,
  помічник стає на коліно поруч. Дію скасовує будь-який рух (W A S D) або
  повторне N. Поштовх далі 0,8 м перериває її, як і раніше.
- Пауза штурму. Бійці займають укриття поблизу рубежу, де їх застала
  команда, і тримають його. Вони не перебігають від одного укриття до
  іншого й не встають-лягають без кінця: стріляють з коліна з-за укриття,
  за низьким укриттям лежать. Без цілей — ховаються. Під обстрілом не
  біжать по відкритому далі 12 м. Стріляють лише прицільно по видимих
  цілях, без вогню на придушення, і так бережуть набої.
- Набої в штурмі. Боєць без набоїв бере магазин у сусіда, в якого є
  запасні, або магазини в убитого поруч. Лише коли поруч нічого немає,
  іде на пункт боєпостачання на вихідному рубежі. Раніше цим пунктом була
  точка висадки, де стоїть мінометник, тож після довгої паузи «Почати
  штурм» відправляв майже всіх до міномета.
- Противник ховається:
  - укриття вибирає з кількох десятків точок, серед них тильний бік стін,
    дерев і техніки;
  - тримає укриття, доки воно захищає, і не міняє його щокілька секунд;
  - за низьким укриттям лягає, виглядає з коліна;
  - під час бою не виходить з укриття в обхід.
- Розриви мін і РПО притискають усіх у радіусі ~38 м (мін) / 25 м (РПО):
  бійці на кілька секунд ховаються за укриття, без укриття — лягають і
  не виглядають. Лежачого уламки зачіпають слабше.
- Перезарядка більше не досилає патрон сама. Після заміни порожнього
  магазина затвор пересмикує гравець (V). Чи є патрон у патроннику —
  треба знати або перевірити (I). Боти, як і раніше, досилають самі.
- Далекомір — у підсумку на броні, у кожного класу. K дістає його за
  0,8 с (було 3,4 с з наплічника), K ще раз прибирає за 0,6 с. Діставати
  можна на ходу. У наплічнику він більше не лежить. Зі старих комплектів
  його прибрано, а 0,32 кг входять у масу броні.
- Далекомір міряє відстань до бійця, а не до рельєфу за ним. Промінь
  розходиться приблизно на 2,4 мрад (пляма 0,6 м на 250 м). Як у
  справжнього приладу в режимі першої цілі, вимір — до найближчого
  відбиття в плямі. Раніше тонкий промінь проходив між рукою й тулубом і
  міряв схил позаду.
- Помічник ставить ящик з мінами, навіть коли вже стоїть біля міномета.
  Раніше в бою він займав укриття поруч і вважав, що прийшов: ящик не
  з'являвся. Ставив його, лише якщо його відвели далі ніж на 7 м.
- Акумулятор розвіддрона — 40 хв зависання (як у Mavic 3; було 8 хв). На
  швидкому польоті тратиться до третини швидше. В окулярах видно
  залишок: «АКБ 87 % · ≈34 хв».
- Наручний екран дрона. Коли дрон у повітрі, а окуляри зняті (J), дрон
  зависає, а картинка з його камери йде на екран на передпліччі (зліва
  внизу). Там же видно АКБ і хвилини, зв'язок, висоту, азимут камери в
  тисячних і відстань до дрона. На слабкому сигналі картинку забиває
  шумом. U ховає й показує екран. Окуляри знову — J. Екран рендериться
  15 разів на секунду і лише тоді, коли його видно.

## 0.19.0 — 2026-11-16

- Класи бійця на вкладці «КЛАС І ЗБРОЯ» екрана підготовки. Кожен клас має
  свою зброю, набої й спорядження в каталозі наплічника:
  - **Стрілець** — АК-74М або M16A4, ПМ або M9, РПО-А, набої 5.45 / 5.56 / 9 мм;
  - **Снайпер** — СВД з ПСО-1, пістолет, набої 7.62 × 54R / 9 мм;
  - **Мінометник** — 82-мм міномет 2Б14 «Піднос», АК-74М, пістолет, міни.

  Стрілець і снайпер діють самостійно, без власної групи й команд. Поле
  «ГРУПА» прибрано. Зміна класу виймає з наплічника речі, яких клас не
  носить, і показує їх список. Старі комплекти й налаштування отримують
  клас за зброєю: з СВД — снайпер, інакше — стрілець.
- Міномет 2Б14. Ствол і двонога (30,1 кг) — на мінометнику; опорну плиту
  (17 кг) і ящик з 10 мінами О-832ДУ несе помічник. Помічник — службовий
  бот із підписом «ПОМІЧНИК», він є лише в мінометника. Мінометник може
  носити міни й сам: вони в каталозі наплічника (3,3 кг, 1 × 2).
  - N — розгорнути міномет: 20 с, якщо помічник з плитою ближче 15 м, і
    32 с самому з плитою. Потрібне відкрите небо над головою. Згортання
    займає 12 с. Рух далі 0,8 м перериває дію.
  - F біля міномета відкриває приціл. У ньому вибирають заряд (0, 1, 2,
    3, 4, Д), приціл 07-50 … 14-17 (45–85°) та азимут у тисячних. Там же
    таблиця стрільби для заряду: дальність, установка прицілу, зміна
    дальності на 1 тисячну, час польоту.
  - Поворотний механізм дає ±70 тис. від напрямку двоноги. Ширший
    перенос — це перенесення двоноги, 6 с. Заряджання займає 2,6 с.
  - Постріл бере міну спершу з ящика біля міномета, потім з наплічника.
    Кнопка «МІНА З ЯЩИКА» в прицілі кладе міну в наплічник.
- Балістика міни — точкова модель з опором повітря (RK4), та сама в
  польоті й у таблиці. Мінімальна дальність 85 м (заряд 0, 85°),
  близько 3100 м на повному змінному заряді, 3922 м на далекобійному.
  Розсіювання від пострілу до пострілу — за початковою швидкістю,
  кутом і напрямком. Свист в останні ~1,5 с падіння, розрив радіусом
  до 24 м; лежачого й присілого зачіпає менше. Точку падіння приціл не
  показує: коригування — за розривами.
- Далекомір показує дирекційний кут у тисячних: «250 м · АЗ 12-34».
- Колишнє меню наказів (G, F1, F2) прибрано. G у мінометника відкриває
  команди розрахунку:
  - «Штурм»: призупинити (групи закріплюються на поточних рубежах і
    чекають) або продовжити;
  - «Міномет»: розгорнути або згорнути;
  - «Помічник»: поставити ящик з мінами біля міномета (або в точці під
    поглядом); вести вогонь 1 / 3 / 5 / усіма мінами з наведеного
    гравцем міномета власними мінами; припинити вогонь; за мною.
- Якщо обрано мінометника, штурм не починається сам. Угорі пише «ШТУРМ
  ОЧІКУЄ КОМАНДИ ГРАВЦЯ · G — РОЗРАХУНОК», доки не дано команду
  «Продовжити штурм».
- Загиблий помічник лишає плиту й міни ящиком на місці. Загибель
  мінометника лишає міномет і власну плиту на місці: новий командир
  підбирає їх через F. Командування переходить до помічника лише тоді,
  коли інших бійців не лишилося.
- Карта (M) — аркуш 1 : 10 000 у стилі радянських топографічних карт
  Генштабу:
  - прямокутна сітка через 100 м з кілометровими підписами;
  - горизонталі (потовщена — кожна п'ята), позначки висот;
  - будівлі, ліс і окремі дерева, дороги, окопи, болото;
  - рамка, рамкові написи, лінійний масштаб, схема зближення меридіанів.

  Свого місцезнаходження на карті немає. ЛКМ — лінійка (відстань і
  дирекційний кут у тисячних), ПКМ — зсунути або прибрати лінійку,
  коліщатко — масштаб до 5×. Бій триває, поки карта відкрита.
- Підказка клавіш займає два рядки і показує лише дії свого класу
  (4 РПО-А — у стрільця; G, N, F — у мінометника).
- Перевірки:
  - Новий test_mortar (71):
    - калібрування балістики, нотація тисячних та азимут;
    - збіг польоту в світі з таблицею: дальність, напрямок, час;
    - класи, каталог і вибір зброї;
    - розгортання, переривання, перенос двоноги, постріли гравця й
      помічника, ящик, команди штурму;
    - втрата помічника, плита, карта та лінійка.
  - test_equipment: азимут у показах далекоміра.
  - test_svd_scope: СВД лише для снайпера.
  - test_assault_squad: без групи в стрільця.
  - test_offensive_orders: без меню.

## 0.18.0 — 2026-11-16

- Дві стартові аптечки показано в спорядженні: на екрані підготовки вони
  в ряду «ПОЯС» поруч із магазинами до пістолета, у польовому інвентарі
  (Tab) — двома місцями «ПОЯС 1 / ПОЯС 2» поруч із кнопкою лікування.
- Порожнє місце на поясі можна заповнити аптечкою з наплічника: обрана в
  наплічнику аптечка (або перша знайдена) береться тим самим рухом, що й
  інші речі (3,4 с), і кріпиться на пояс (0,7 с). Дію переривають
  поранення й контузія; зайнятий слот і повний пояс аптечок не беруть,
  маса спорядження не змінюється. H, як і раніше, спершу витрачає пояс.
- Присідання — перемикач: одне натискання Ctrl — присісти, наступне —
  встати. Ctrl лежачи піднімає в присід, Shift знімає присід для бігу.
  Ctrl у режимі дрона, як і раніше, знижує висоту без зміни стійки.
- Підказка в наплічнику для аптечки замість тексту про далекомір.
- Перевірки: перемикання присідання подіями вводу (присів після
  відпускання, встав другим натисканням, Shift, вихід з положення лежачи),
  слоти пояса, перенесення обраної аптечки з наплічника, збереження маси,
  відмова для зайнятого слота та повного пояса.

## 0.17.0 — 2026-11-16

- «Великий штурм» без підкріплень: прибрано хвилі кожні 18 с і резерв
  сторін. Обидві армії стоять на полі з першої секунди, кожна втрата
  остаточна. Лічильник на екрані показує живі сили: «СИЛИ 51 : 50».
- Противник від початку тримає всі три рубежі (40 / 30 / 30 % сил,
  для 50 × 50 — 20 / 15 / 15). Захисники втраченого рубежу відходять на
  наступний, а боєприпаси поповнюють за своїм рубежем, а не за
  атакованим. Союзники шикуються в три колони перед точкою висадки,
  командир з особистою групою — за габіонами.
- Після загибелі чи тяжкої контузії командира новий боєць не з'являється:
  за 5 с командування приймає найближчий живий союзник, що вже є на полі
  (його тіло залишає армію ботів, командир займає його місце й напрям).
  Коли союзників не лишилося, загибель командира завершує штурм, а
  контужений командир лишається на полі до кінця бою.
- Меню штурму описує нові правила; прибрано застарілу згадку про ліміт
  30 хвилин.
- Перевірки штурму переписано під нові правила (37): обидві армії одразу
  на полі, захисники на трьох рубежах, відсутність підкріплень, відхід
  захисників, передача командування найближчому бійцю та кінець бою,
  коли передавати нікому.

## 0.16.0 — 2026-11-16

- Поле «Великого штурму» перероблено: замість 63 однакових валів у три
  ряди та бетонних стінок — 31 укриття під антураж. Підбиті БМП, БТР і
  танк із зірваною баштою, згорілі вантажівки й легковики, колона на
  дорозі, протитанкові їжаки, бетонні блоки на перехресті, позиції з
  мішків з піском на кожному рубежі та габіони на точці висадки.
- Укриття стоять через 25–50 м, між ними відкрита місцевість. Корпус
  техніки й мішки з піском зупиняють кулі та не руйнуються; дошки кузова
  пробиваються. Вирви від снарядів — декорація без колізій.
- Штурм не завершується, поки командир живий: прибрано ліміт 30 хвилин,
  а тяжко контуженого командира без резерву більше не знімають з бою —
  він лишається на полі. З резервом його, як і раніше, евакуюють і
  замінюють. Поразка — лише загибель без резерву.
- Додано перевірки: бій триває з контуженим командиром без резерву та
  після 30 хвилин.

## 0.15.0 — 2026-11-16

- Продуктивність «Великого штурму»: новий розмір 50 × 50 (сто ботів і
  гравець). Раніше такий бій давав кілька кадрів на секунду.
- Фізика переведена на вбудований Jolt Physics; не більше 4 фізичних
  кроків за кадр, щоб просідання не наростало лавиною.
- Рівні деталізації ШІ: далекі й невидимі боти оновлюються раз на 2–4
  фізичні кроки з накопиченням часу, тож швидкості, таймери й темп вогню
  ті самі. Боти, що стоять, не проганяють зайвий розрахунок зіткнень.
- Далекі солдати та солдати поза полем зору малюються спрощеною моделлю
  через GPU-інстансинг: десять викликів малювання на весь натовп. Поряд, у
  полі зору та в ПСО — повна модель. Пози, тіла й хітбокси ті самі вузли.
- Модель ботів полегшена: менше граней у пальцях, шнурівках та очах,
  однокольорові матеріали й деталі зброї об'єднані за кістками (26 мешів
  замість 82). Модель гравця та перегляд спорядження не змінені.
- Пошук цілей, перевірки зору, близькі прольоти куль, освітлення під
  кронами й листя використовують просторові індекси замість переборів.
- Далекі гільзи одразу лягають на землю; далекий пил і краплі крові не
  створюються, плями крові на землі зберігаються.
- Механіка зброї, балістики, поранень і кампанія без змін.

## 0.14.0 — 2026-11-16

- Новий окремий режим «Великий штурм»: піхотна битва на карті 400 × 400 м,
  три послідовні рубежі, 12 / 20 / 28 ботів на сторону та гравець.
- Автономні союзні загони наступають різними підходами; особиста група
  зберігає команди гравця. Захоплення не потребує присутності командира.
- Хвилі підкріплення, скінченний резерв, пересування тилової точки після
  захоплення, перевірка безпечної появи. Загиблого або тяжко контуженого
  гравця замінює новий боєць; контузія попереднього не лікується.
- Союзники не завмирають назавжди під вогнем без укриття, зміщуються з
  перекритої товаришем лінії вогню, дивляться вперед командира на привалі
  й розподіляють прикриття окремо між автономними групами.
- Обмежено число пошуків шляхів та укриттів за фізичний кадр у битві;
  перевірки зору розподілено між контактами зі збереженням реального LOS.
  Старі втрати з автономних загонів обмежено 20 тілами для продуктивності.
- Стандартна механіка зброї, боєзапасу, поранень і кампанія збережені.

## 0.13.2 — 2026-11-13

- Виправлено постійне зміщення близького пострілу від стегна праворуч і вниз.
  Зброя повертається до точки під центральною міткою; куля летить зі справжнього
  зрізу ствола. Збережено віддачу, розкид, падіння та зіткнення з укриттями.
  Виправлення охоплює автомати, СВД, пістолети й РПО без прицілювання.
  Механіка оптики, відкритих прицілів та стрільби наосліп збережена.
- Виправлено Space впритул до підвіконня: контакт зі стіною більше не
  відхиляє перелазіння через помилкове перекриття перевірочної капсули.
  Збільшено відстань виявлення до 1,4 м; анімація включає крок до опори.
  Боєць вирівнюється з отвором, а біля виступів трохи відступає перед підйомом.
  Ширина фізичної капсули збережена; повний шлях перевіряється з урахуванням рами.
- Додано перевірки справжніх влучань поблизу, стрільби вниз, віддачі та
  перелазіння після притискання до підвіконня звичайним рухом.

## 0.13.1 — 2026-11-13

- Прибрано окремий ліміт швидкості з готовим РПО в руках. Ходьба, біг
  через Shift, присідання та повзання використовують звичайні правила руху.
  Вага спорядження враховується однаково для основної зброї й РПО.
- Прицілювання РПО обмежує швидкість так само, як прицілювання автоматом;
  стан готового гранатомета більше не скасовує знерухомлення від крововтрати.
- Додано порівняння фактичної швидкості руху з автоматом і РПО в тестах.
- Прибрано тимчасові скріншоти, журнали перевірок та проміжні збірки.

## 0.13.0 — 2026-11-13

- Додано одноразовий РПО-А «Шмель»: оригінальна 3D-модель, відкритий
  приціл, перенесення на наплічнику, діставання, прибирання та відкидання.
  У лодауті доступний як предмет спорядження, керування — клавіша 4.
- Використано відкриті номінальні ТТХ РПО-А: 93 мм, 11 кг, 920 мм,
  початкова швидкість 125 м/с. Балістика та вибух мають окрему ігрову модель;
  вона не прогнозує реальну зону ураження. Звуки оригінально синтезовані.
- Вибухи враховують геометричне перекриття кількох точок тіла, тип
  перешкоди й відстань; небезпечні для всіх сторін. Локальні руйнування
  дерева та скла обмежені за обсягом, без повної перебудови навігації.
- Контузія зберігається до кінця операції окремо від здоров'я: порушення
  зору, рівноваги, слуху, реакції та точності. Виражена контузія блокує
  прицілювання, тяжка — бій; постраждалі боти падають і не відновлюють
  нормальну стрільбу після аптечки. Супутні звичайні рани лікуються окремо.
- Одна труба витрачається один раз. Вага враховується й у руках;
  невдалий постріл у перекритий ствол та перерване діставання її не витрачають.
  Лише F8 дозволяє повторне використання. Пресет після пострілу незмінний.
- Додано перевірки спорядження, польоту, захисту перешкодами, лікування,
  стійких симптомів і боєздатності; джерела: SHMEL-REFERENCES.md.

# 0.12.0

- Space now performs contextual traversal through open windows, over low
  fences and onto reachable ledges. The normal jump remains on open ground.
  Detection uses actual collision surfaces, opening clearance and supported
  landing footprints, including rotated buildings and different floor levels.
- Added a first-person stow / plant hands / pull / tuck / release / recover
  animation, with hands attached to sampled world-space contact points and
  a matching third-person tucked-leg pose. Duration increases with ledge
  height and carried mass; the player remains vulnerable throughout.
- Swept capsule checks and physical motion preserve collisions during traversal.
  Dynamic obstructions, destroyed hand supports, wounds and death interrupt it;
  pause freezes it. Low landing ceilings retain a crouched stance. Weapon,
  medical, inventory and field actions cannot overlap the traversal.

# 0.11.2

- Replaced whole-map campaign navigation rebuilds after each fracture with
  coalesced local cell updates and a spatial index of nearby collision shapes.
  Terrain costs, rotated collision footprints and adjacent obstacles remain
  intact; newly opened passages immediately become available to bots.
- Added connected-region checks before A* searches. Unreachable cover points
  no longer cause searches through the entire 635,209-cell settlement grid.
  Destruction updates connectivity incrementally as cells become walkable.
- Throttled unsuccessful enemy flank probes and restricted them to alerted
  enemies instead of retrying an unchanged hidden position every physics tick.

# 0.11.1

- Added the player's world character, selected camouflage, team tape, backpack
  and weapon, with standing, kneeling and prone poses. FPV piloting shows
  goggles and a controller. Camera layers keep this body visible to the drone
  and excluded from the soldier's first-person and scope views.
- Replaced flat-only prone clearance with sampled ground alignment; body,
  camera and damage areas follow slopes without cumulative rotation or sinking.
  Standing and turning still check solid obstacles and low ceilings.
- Drone deployment samples its footprint and tries nearby reachable positions.
  It accepts slopes and small uneven patches while rejecting walls, unsupported
  edges and occupied space. Grounded attitude follows the slope; takeoff levels
  the aircraft, and descending contact disarms it instead of sliding indefinitely.

# 0.11.0

- Added an optional recoverable reconnaissance quadcopter kit (3 x 2 pack
  cells, 1.2 kg including retained goggles/controller), original models and
  timed backpack access, goggles and recovery animations.
- Added stabilized FPV flight, acceleration/braking, physical collisions,
  aircraft camera, altitude/battery/radio telemetry and spatial motor audio.
  The pilot remains vulnerable; injury exits the goggles. Landing and pickup
  preserve charge and damage; a full pack or interrupted recovery retains the
  original aircraft. Radio loss/low battery trigger descent, empty battery
  stops the motors. These are game approximations, not a specific drone model.
- Fixed accumulated per-frame bot wound roll. Excluded internal contacts among
  coarse ragdoll colliders, damped and settled the assembly, and removed the
  artificial falling impulse when the casualty was already prone.
- Hardened PSO render-resource lifetime across weapon swaps and restored its
  camera and texture binding after reload/inventory/field actions. The exact
  reported single-color symptom was not reproduced in the baseline; three GPU
  sequence runs succeeded before and after, with a new lifecycle regression.

# 0.10.1

- Removed exact remaining ammunition counts from combat inventory magazine
  cards, backpack packet labels and transfer status. Transfer progress no
  longer reveals remaining ammunition; physical inspection still provides
  only a qualitative estimate. Caliber labels and printed packet markings remain.

# 0.10.0

- Added a wearable assault backpack with 24 grid cells, item footprints, live
  carried mass and research-based running-speed adjustment.
- Added folded paper packets of 30 rounds for all five calibers, extra medkits,
  and an optional laser rangefinder (K, left click to measure).
- Added named loadout presets, a reorganized equipment screen, and a weapon
  selection grid with hover/focus specifications.
- Added first-person pack access, distinct item retrieval, opening packets,
  magazine-to-magazine cartridge transfer and retained interruption checkpoints.
- Added qualitative magazine weight estimates during physical inspection.
- Replaced in-game constant-drag flight with Mach-dependent G1 / RK4 flight;
  iron sights and PSO-1 now share the same ballistic solver.
- Added team-colored upper-arm tape: yellow squad / red opposing force.
- Imported a CC0 Poly Haven environmental supply crate with 1K PBR textures;
  it is separate from carryable paper ammunition packets.
- Corrected SVD top-round seating and its geometry regression's caliber bounds.

# 0.9.0

- Added original SVD / PSO-1 model, 10-round 7.62×54R magazines, semi-automatic action, hold-open, partial-magazine conservation, inspection/racking, matching rimmed case/live-round debris and caliber-specific projectile energy.
- Fixed 4× picture-in-picture optics with 6° field, angular chevrons/mil/range scale, moving elevation/windage reticle, red illumination, physical eye relief/exit-pupil shadow and near-cover occlusion. Manual controls, finite breath hold, fatigue/posture sway and recoil; rendering sleeps outside ADS.
- Improved drag integration and calibrated zero/holdover to actual bullet trajectories. Added an independent 240 Hz trajectory comparison plus scope/input/lifecycle and ammunition regressions. See OPTICS.md for documented approximations.
- Replaced the old block character design with a CC0-derived anatomical textured male head, new clothing/helmet/carrier/pouches/boots/gloves and balanced arm proportions. Preserved seven outfits, wound attachments, articulated animations and constrained corpses. Updated hitbox/eye alignment and kneeling/headshot regressions.
- Shared geometry/material caching, mipmapped cloth, improved portrait lighting, first-person sleeves/palms, and actual selected rifle with fitted grip in loadout/inventory portraits.
- SVD shot audio remains an explicitly credited acoustic stand-in; no claim of photogrammetry, facial animation or fully calibrated real-world ballistics.

# 0.8.2

- Added group and individual Engage Sector and Assault Point orders to G. Direction is captured on menu opening; sector combat works without a surface hit, while point orders validate navigation and height.
- Sector combat scans a fixed heading, prioritizes observed contacts within 40 degrees each side and retains close-range self-defence. Commands do not reveal hidden targets or bypass perception, reaction, ammunition, wounds or friendly firing-lane checks.
- Assault soldiers run between successive protected positions, pause to fight, hand off overwatch and secure the destination. Extended cover duty cannot indefinitely pin the same advancing soldier to the first position. Suppression, reloads and treatment still constrain movement.
- Added real projectile/perception, routed capsule movement, multiple cover stops, unreachable destination and cover-handoff regressions. Updated command layout and instructions.

# 0.8.1

- Followers mirror commander crouch/prone posture, narrow the formation and follow recorded movement around terrain instead of only a heading-relative slot. Lowered collision matches crouch; healthy tactical prone is separate from wound collapse.
- Sprint catch-up and short exposed dashes to cover remain available with a visible enemy. Separate movement speeds for standing, crouch, crawl and sprint.
- Cover search checks silhouette samples, low protection, geometry-facing candidates, occupied positions and route exposure. Under fire it preserves protection when the formation anchor moves; concealment alone is not treated as bullet cover.
- Protected soldiers take rotating overwatch while others relocate. Low-cover peeks are brief; following a prone commander remains prone. Friendly near-misses no longer trigger enemy suppression states.
- Added posture/trail/speed/cover and live hostile-fire regression, plus an eight-member grove visual/performance audit. No allied health or armor bonuses.

# 0.8.0

- Configurable 0–8 allied assault soldiers, spread follow formation, routed movement, local cover, individual/group orders and finite supplies. Independent follow/move/hold/cover and ceasefire/free-fire orders through G, F1 and F2.
- Shared bidirectional faction perception, human reaction delay, real projectiles, wounds and treatment; opponents can engage allies. Friendly firing-lane checks and separate objective accounting.
- Tab combat inventory with character/equipment, modeled magazine cards, medical kits and an explicitly unavailable backpack area. Live combat continues behind both menus; UI input cannot fire the weapon.
- Timed cartridge-by-cartridge transfer between compatible magazines, including detaching/reinstalling the loaded magazine without modifying the chamber. Interruptions preserve magazine identities and all transferred ammunition.
- Added squad movement/combat/order/lifecycle and inventory/conservation/interruption regressions; verified graphical menus and formation in the Linux build.

# 0.7.0

- Ten sequential campaign missions in two independently progressing branches: five woodland trench lines, three villages and two urban districts.
- Each playable map is 400 x 400 m with its own terrain, biome palette, layout and deterministic seed. Terrain collision matches rendered triangles; below-sea-level ground is playable.
- Excavated trenches with entrance ramps and terrain-shaped firing steps. Tree belts border open fields/clearings; undergrowth is concentrated in belts rather than covering the entire map.
- Irregular settlement placement; varied building dimensions, rotations, heights, pitched/flat roofs, gables, porches, annexes and yard walls. Ground-floor entrances, partitions, furniture and windows have actual collision openings.
- Urban streets, sidewalks, markings, lamps and parked vehicles follow the district layout. Terrain color is supplied to camouflage recognition.
- Mission selector with two branches, layout miniatures, selection/completion/locked states and persistent progress. Victory unlocks the next mission only in its branch; defeat does not. Restart rebuilds campaign destruction.
- Defenders begin at trench/building posts and choose cover within assigned sectors rather than chasing the attacker across the map. Terrain-aware paths and threat-height calculations.
- Added campaign catalog/progress/geometry, full-map route, real capsule movement and campaign UI/lifecycle regression suites. All ten maps visually exercised with active defenders.

# 0.6.0

- Actual weapon and magazine previews; 2x-resolution, MSAA character preview and outfit thumbnail cards.
- Material-dependent projectile energy loss, actual entry/exit chord thickness, oblique/tapered hits and multiple overlapping layers. Low residual energy no longer inherits full injury severity.
- Local cumulative fracture: box sections are replaced by remaining geometry and rigid fragments; mesh craters use boolean subtraction and regenerated collision. Impact marks follow their owning surface.
- Separate bench boards/supports, hollow vehicle skins and metal bins, exact tapered tree trunks. Navigation refreshes after box cuts. Fragments are limited to 96, local fracture operations to 1200 per match.
- Eye-to-anatomy visibility uses the rendered foliage quads and alpha cutouts. Close distance and alertness no longer bypass occlusion or field of view. Shot-time visibility checks prevent stale accurate targeting.
- Time-stamped visual memory, approximate hearing, delayed first response, gradual aiming and wider initial close-contact fire. Exposed route penalties, sprinting to cover and standoff search positions.
- Paired cover/movement roles, remembered-position suppression, side/top peek selection and checked blind-fire muzzle paths. Spatial Ukrainian "Крию!" callout (synthetic eSpeak NG placeholder).
- Nonfatal impacts trigger prone reactions; mobile wounded crawl toward nearby cover, severe bleeding prioritizes treatment in place. Prone movement capsule follows the model.
- Added penetration/destruction and awareness/reaction/squad/injury regression scenarios. These are game approximations, not calibrated structural, medical or human-behaviour simulation.

# 0.5.3

- Magazine inspection 3.8 -> 2.1 s; chamber check 2.5 -> 1.8 s.
- R during the in-hand inspection window promotes the held magazine into reload. Prepared-pouch exchange takes 1.75 s; already-removed loaded magazine takes 2.25 s, plus chambering if needed.
- Separate weapon-well, three chest-pouch and two belt-pouch retrieval/return paths.
- Corrected cartridge seating, added feed lips, rebuilt inclined pistol magazine bodies/floorplates and aligned witness apertures.
- Added 277 handoff, interruption/conservation, geometry and input checks; graphical inspection of magazine and accelerated reload poses.

# 0.5.2

- Replaced sparse shelterbelt rows and open fields with dense woodland across the playable area and surrounding scenery: 1039 trees and 2067 undergrowth patches.
- Narrow winding path replaces straight farm track. Small clearances preserve access to shelters, firing bays and spawn points.
- Taller undergrowth obstructs standing-height recognition; wider overlapping crowns provide forest shade.
- Verified all bot/interior routes, protected insertion and sampled foliage screening; graphical check with active bots averaged about 60 FPS at one viewpoint on RX 550, 1280x720 (not a map-wide performance guarantee).

# 0.5.1

- Fixed cadence drift from discarded frame remainder and floating-point cooldown boundaries.
- AK 600 rpm; M16A2 800 rpm within three-shot bursts. PM/M9 semi-auto trigger cycle gates 0.12/0.10 s, with no held-trigger auto-fire.
- Bots use weapon cycle intervals and preserve within-burst timer remainder.
- Added 37 timing/trigger checks at 4, 20, 30, 60 and 120 Hz.

# 0.5.0

- Two selectable maps: furnished city ground floors and a 192 m shelterbelt with fields and shelters.
- Equipment slots, character preview, seven outfits and enemy uniform selection.
- Distance, exposed body, background color, shade, movement and gunfire based recognition.
- Finite magazines with persistent identity/ammunition; R+slot exchange, I chamber and T magazine inspections.
- No combat hit/kill/ammunition confirmations; return-to-start mission report. Impact blood spray.
- Physical spent cases and live cartridges persist through the match.
- Recorded positional pain voices, stronger blackout, distance gunfire falloff and cumulative temporary tinnitus/muffling.

# 0.4.2

- Wound classification uses the full trajectory through each oriented hit region; lateral penetrating shots no longer become automatic grazes.
- Head hit region covers the visible helmet; PM head hits are regression-tested in standing and kneeling poses from front and side.
- Tight bone-aligned arm/thigh/shin regions and separate feet replace oversized diagonal boxes. Central upper-limb tracks trigger the simplified severe-vessel wound.
- Increased penetrating limb damage; disabling wounds interrupt firing, trigger a visible collapse, and restrict movement. Critical player blood loss blocks firing and movement.
- Injured bots use two finite universal kits with six-second visible treatment. Bleeding continues until completion; incoming damage interrupts, pause freezes, death prevents treatment.
- Bot crouch uses a forward supporting leg and a rear grounded knee. Injured players must remain prone (or crouched where lying down is obstructed) until healed.
- The medical model remains a gameplay approximation: no geometric organs/bones, validated armor classes, or calibrated clinical timing. Universal full recovery remains temporary gameplay behavior.

# 0.4.1

- Added F8 / pause-menu debug immortality with an explicit HUD indicator; activation clears injuries and restores health, and disabling restores normal damage.
- Replaced oversized concrete-barrier box collision with the exact tapered mesh, removed marks for invalid surface normals, and added a barrel-obstruction HUD warning.

- Added Z toggle for prone: horizontal body collision and hit regions, 0.85 m/s crawl, low eye level, aimed fire and reduced recoil; sprint/jump and blind-over-cover fire are disabled while prone.
- Check space before lying down, standing up and rotating the horizontal body near walls.
- Moved spawn to a sheltered rear courtyard behind the south-east apartment block, facing the exit; added paving and low cover, with routes around either side.
- Verified all ten initial enemy sightlines are blocked and both exits remain reachable; added 35 posture/spawn regression checks.

# 0.4.0

- Moved head rotation to the base of the neck, aligned the eye with the weapon, limited neck extension in aiming and ragdoll, and added 9 pose/physics regression checks.

- Added original AK-74M geometry in the requested reference style, editable baked weapon scenes, shared 512px metal/polymer/grip maps, revised M16 controls and pistol contours; bots use the same AK model.
- Fixed mixed indexed/unindexed mesh batching dropping geometry. Added 18 geometry preservation / moving assembly checks.

- Fixed PM slide/frame geometry and hard-surface normals; neutral daylight replaces tinted fog.
- Added anatomy-following projectile hit areas, separate degrading armour plates, fatal head hits, grazing/blunt/penetrating/arterial/internal wound categories, limb function loss, bleeding and visual symptoms.
- Added original blood-stain texture projected onto clothing geometry and limited persistent blood marks on ground.
- Added six-second animated universal medical kit; two per match, interrupted by damage, with no armour repair.
- Replaced rigid death tween with jointed physical bodies and a dropped rifle, including pause/restart handling.
- Added bot hearing uncertainty, reaction delay, shared last-known contacts, suppression, reachable/reserved cover, crouch/peek/reposition, aimed bursts, recoil and finite-magazine reload animations/sounds.
- Added collision-limited Q/E lean, C top peek and Alt+Q/E/C blind rifle fire. Crouching now changes the movement capsule and hit areas.
- Added spring camera recoil and weapon kick with stance/movement/aim/burst modifiers. Removed omniscient enemy radar.
- WOUND-MODEL.md documents the simplified injury/armour rules and symptom research sources.

# 0.3.0

- Rebuilt district facades with framed windows, balcony railings, entrances, panel seams, downpipes, AC units and rooftop details.
- Added profiled sedan bodies, wheel arches, tyres, rims, windows, door lines, mirrors, lighting and bumpers.
- Added branched trees with original alpha-cutout foliage, slatted benches, swings, bins, kerbs, drains, manholes, road repairs and vegetation.
- Replaced block characters with rounded anatomy, camouflaged uniforms, helmets, eye protection, plate carriers, pouches, packs, knee pads and boots. Added hip/knee gait and model-based muzzle origins.
- Batched static geometry by material and spatial cell; merged rigid character parts. Enabled budget directional shadows with a menu toggle.
- Preserved simplified gameplay cover and navigation; all ten bot spawns retain routes to the player.

Limits: low-poly procedural art, simple distant buildings, no building interiors, simplified prop collisions, cosmetic bot equipment.

# 0.2.0

- Rebuilt all four weapon models: bevelled metal parts, wood/bakelite/polymer surfaces, actual open iron sights, separate magazines and bolt/slide assemblies.
- Aligned the camera to front/rear sight geometry; aperture on M16A2, open notches on AK-74/PM/M9. No fake sight overlay.
- Animated magazine extraction, insertion and chambering with moving support hand, separate forearms and phase-timed mechanism audio. Retained interrupted-reload state and chamber semantics.
- Corrected two-handed pistol grip and sleeve behavior during slide manipulation.
- Replaced hitscan damage and visible tracers with invisible swept-segment projectiles, muzzle origin, representative muzzle velocity, gravity, quadratic drag and energy-scaled damage. Applied to players and bots.
- Added case ejection, brief small muzzle flash, impact marks and dust.
- Added CC0 recorded shots and handling sounds. Sources and stand-ins are explicitly documented in assets/AUDIO-CREDITS.md.
- Verified 159 weapon-state checks, 24 ballistic/geometry/animation checks, match lifecycle tests, graphical previews and a recorded demo.

Limits: procedural art and animation, approximate exterior ballistics, no penetration/ricochet/wind, several audio recordings substitute for the exact named weapons.

- Поранені боти залишаються лежачи до завершення лікування; пошук укриття для повзання враховує низький силует, а не можливість вести вогонь.
