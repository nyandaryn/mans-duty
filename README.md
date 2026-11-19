# MANS DUTY

**English** · [Українська](#українська)

A tactical first-person shooter about assaulting positions in Ukraine. A campaign of ten operations
on 400 × 400 m maps, a large assault with up to 54 × 54 bots and BMP-2 squads on a real map of
Avdiivka, rifleman, sniper, mortarman and BMP driver classes, a recon drone, a BM-21 «Grad»
commander, and a training course for every class.
Made with Godot 4.5.1. The interface is in Ukrainian; no internet connection is needed to play.

## Download

Get the latest build from **[Releases](https://github.com/nyandaryn/mans-duty/releases/latest)**.
Under *Assets*, pick the file for your system:

| System | File |
| --- | --- |
| Windows 10 / 11, 64-bit | `kvartal-<version>-windows.zip` |
| macOS 11+ on Apple Silicon, macOS 10.12+ on Intel | `kvartal-<version>-macos.zip` |
| Linux x86_64 | `kvartal-<version>-linux.tar.gz` |

You need a graphics driver with OpenGL 3.3. On Windows the game falls back to Direct3D 11 without it.

### First launch

The builds are not signed with a developer certificate, so the system warns you the first time.
The game is not damaged.

- **Windows.** Extract the whole archive (right click → *Extract All*); do not run the game from
  inside the zip. Keep `kvartal.exe` and `kvartal.pck` in one folder and run `kvartal.exe`.
  If the blue «Windows protected your PC» window appears, click *More info* → *Run anyway*.
- **macOS.** Double-click the archive and drag «Mans Duty.app» to Applications.
  On macOS 14 and older, Control-click the app → *Open* → *Open*. On macOS 15 and newer, open it
  once, click *Done*, then go to System Settings → Privacy & Security → *Open Anyway*.
- **Linux.**
  ```sh
  tar -xzf kvartal-<version>-linux.tar.gz
  cd kvartal-<version>-linux && ./play.sh
  ```

Step-by-step help is in `README-Windows.txt` and `README-macOS.txt` inside the archives.
Controls and the changelog are in `README.txt` (Ukrainian).

## Development

- The Godot project is in [`source/`](source/): open `source/project.godot` in Godot 4.5.1
  (standard build, not .NET). Notes on the game systems: [`source/README.md`](source/README.md),
  changes: [`source/CHANGELOG.md`](source/CHANGELOG.md).
- Tests are headless scripts in `source/tests/`:
  `godot --headless --path source --script res://tests/test_<name>.gd`.
- Releases: [`tools/release.sh`](tools/release.sh) builds the Windows, macOS and Linux archives
  of the version in `source/project.godot` from the committed `HEAD`, starts each build headless,
  and publishes them as a GitHub release. `--build-only` builds without publishing. It downloads
  Godot 4.5.1 and its export templates into `.build/` on first use. In Claude Code it is the
  `release` skill.

## Credits

Third-party assets and their licenses (CC0, CC BY 4.0, SIL OFL 1.1, ODbL):
`source/assets/*-CREDITS.md`. Godot Engine: MIT, see `GODOT-LICENSE.txt` and
`GODOT-COPYRIGHT.txt`.

---

## Українська

Тактичний шутер від першої особи про штурм позицій в Україні. Кампанія з десяти операцій на картах
400 × 400 м, «Великий штурм» до 54 × 54 ботів на реальній карті Авдіївки з БМП-2 і десантом, класи
стрільця, снайпера, мінометника й механіка-водія БМП, розвідувальний дрон, командир БМ-21 «Град»
і навчальний курс для кожного класу. Зроблено на Godot 4.5.1. Інтерфейс український; інтернет під час гри не потрібен.

## Завантажити

Остання збірка — на сторінці **[Releases](https://github.com/nyandaryn/mans-duty/releases/latest)**.
У розділі *Assets* оберіть файл для своєї системи:

| Система | Файл |
| --- | --- |
| Windows 10 / 11, 64-біт | `kvartal-<версія>-windows.zip` |
| macOS 11+ на Apple Silicon, macOS 10.12+ на Intel | `kvartal-<версія>-macos.zip` |
| Linux x86_64 | `kvartal-<версія>-linux.tar.gz` |

Потрібен відеодрайвер з OpenGL 3.3. На Windows без нього гра сама перейде на Direct3D 11.

### Перший запуск

Збірки не підписані сертифікатом розробника, тому під час першого запуску система попереджає.
Гра не пошкоджена.

- **Windows.** Розпакуйте архів повністю (правий клік → «Видобути все»); не запускайте гру просто
  з архіву. `kvartal.exe` і `kvartal.pck` мають лежати в одній папці; запустіть `kvartal.exe`.
  Якщо з'явиться синє вікно «Windows захистила ваш ПК», натисніть «Докладніше» → «Усе одно
  запустити».
- **macOS.** Розпакуйте архів подвійним клацанням і перетягніть «Mans Duty.app»
  у «Програми». На macOS 14 і старших: Control-клацання по грі → «Відкрити» → «Відкрити».
  На macOS 15 і новіших: відкрийте гру, натисніть «Готово», далі Системні параметри →
  Приватність і безпека → «Усе одно відкрити».
- **Linux.**
  ```sh
  tar -xzf kvartal-<версія>-linux.tar.gz
  cd kvartal-<версія>-linux && ./play.sh
  ```

Покрокові інструкції — у `README-Windows.txt` і `README-macOS.txt` в архівах.
Керування й список змін — у `README.txt`.

## Розробка

- Проєкт Godot лежить у [`source/`](source/): відкрийте `source/project.godot` у Godot 4.5.1
  (звичайна збірка, не .NET). Опис ігрових систем — [`source/README.md`](source/README.md),
  зміни — [`source/CHANGELOG.md`](source/CHANGELOG.md).
- Тести — headless-скрипти в `source/tests/`:
  `godot --headless --path source --script res://tests/test_<назва>.gd`.
- Релізи: [`tools/release.sh`](tools/release.sh) збирає архіви для Windows, macOS і Linux
  з версією з `source/project.godot` із закоміченого `HEAD`, запускає кожну збірку headless
  і публікує їх як реліз на GitHub. `--build-only` — лише зібрати, без публікації. Під час
  першого запуску скрипт сам завантажує Godot 4.5.1 і шаблони експорту в `.build/`. У Claude Code
  це скіл `release`.

## Автори й ліцензії

Сторонні ресурси та їхні ліцензії (CC0, CC BY 4.0, SIL OFL 1.1, ODbL):
`source/assets/*-CREDITS.md`. Рушій Godot — MIT, див. `GODOT-LICENSE.txt` і
`GODOT-COPYRIGHT.txt`.
