# Safe Area & Viewport — справочник

Подгружай этот файл при работе с:
- Любой новой сценой / popup / overlay (нужно решить, как взаимодействует
  с safe-area).
- Правкой `scripts/safe_area_manager.gd`, `scripts/main.gd._make_full_rect`,
  `project.godot` (stretch/aspect).
- Жалобами от QA / TestFlight на «полосы по краям», «контент уходит за
  край», «затемнение не покрывает экран», «вырез накрывает кнопку».

---

## 1. Контекст

Современные мобильные устройства имеют «карманы», в которые приложение
рендерится, но UI трогать там нельзя:

- **iOS:** notch, Dynamic Island, скруглённые углы, home indicator (полоска снизу).
- **Android:** display cutout, system gesture areas.

OS отдаёт нам safe-area прямоугольник через
`DisplayServer.get_display_safe_area()`. Всё **внутри** прямоугольника
безопасно для важного UI; всё **снаружи** — фон может туда залезать,
но кнопки / тексты / карты не должны.

В проекте за это отвечает autoload `SafeAreaManager`
(`scripts/safe_area_manager.gd`).

---

## 2. Базовое правило

**Backgrounds — full-bleed (рисуются от края до края экрана).**
**UI children — inset (отступают от safe-area карманов).**

Маршрутизатор: `main.gd._make_full_rect(scene_root)`. Логика:

1. Корневой Control сцены ставится в FULL_RECT (anchors_preset = 15).
2. По всем прямым детям корня:
   - **Skip 1:** ребёнок с именем `"Background"` — full-bleed.
   - **Skip 2:** `ColorRect` / `TextureRect` с anchors FULL_RECT — full-bleed
     (страховка для бэкграундов, построенных скриптом без правильного `name`).
   - **Иначе:** `SafeAreaManager.apply_offsets(child, axes)` — Control
     инсетится со всех сторон.

Поэтому при создании новой сцены или скриптового бэкграунда:
- `.tscn`: ColorRect / TextureRect → `name = "Background"`. Никакой другой
  логики не нужно.
- Скриптовый бэкграунд: либо назови ноду `"Background"`, либо поставь
  ему FULL_RECT (anchors_preset = 15) — тогда страховка сработает.

---

## 3. Симметричный inset для якорей в 1.0

Реальная ловушка, на которой обожгли руки в build 4 → 5. Ребро Control'а:
- `anchor = 0` → следует за верхним/левым краем родителя.
- `anchor = 1` → следует за нижним/правым краем родителя.

Если **оба** ребра оси привязаны к одному краю (например, у `BottomSection`
в `scenes/game.tscn` `anchor_top = 1.0` и `anchor_bottom = 1.0` —
«растёт вверх ото дна»), и просто сдвинуть нижнее ребро на `db`, то
контейнер **сжимается на db пикселей** вместо того чтобы целиком
сдвинуться вверх. Внутренние `VBoxContainer`-дети налезают друг на друга
(в Classic single-hand TOTAL BET налезал на нижний край карт).

Правильное поведение в `_apply_to`:
- `anchor_left == 0` → `offset_left += dl`
- `anchor_left == 1` → `offset_left -= dr`  *(симметрия: правый safe-area тянет правое ребро влево)*
- `anchor_top == 0` → `offset_top += dt`
- `anchor_top == 1` → `offset_top -= db`  *(симметрия для bottom-anchored)*
- `anchor_right == 1` → `offset_right -= dr`
- `anchor_bottom == 1` → `offset_bottom -= db`

Нет правила для `anchor_right == 0` / `anchor_bottom == 0` — это
авто-растягивающиеся Container'ы, у которых дальнее ребро управляется
самим Container'ом по min_size; внешняя правка туда сломает layout.

---

## 4. Per-control opt-in: `safe_area_axes`

Иногда контейнер должен инсетиться **только по одной оси**. Кейс из
practice: лобби, машинная карусель должна свайпаться edge-to-edge
(под Dynamic Island), но header (`TopBar`) и footer всё ещё нуждаются
в notch-clearance.

Решение — мета-ключ на Control:

```gdscript
# В .tscn:
metadata/safe_area_axes = "vertical"

# Или из скрипта до того, как main.gd дойдёт до _make_full_rect:
$VBoxContainer.set_meta("safe_area_axes", "vertical")
```

Значения:
- `"all"` *(default)* — стандартный inset со всех сторон.
- `"vertical"` — inset только сверху/снизу. Левый/правый край контейнера
  доходит до края окна. Используй когда дочерний Container внутри сам
  заботится о горизонтальной обводке (например, `TOP_BAR_SIDE_PAD` в
  `lobby_manager.gd`).
- `"horizontal"` — inset только слева/справа. Применяется крайне редко;
  в проекте сейчас не используется.

`main.gd._make_full_rect` читает это meta и передаёт в
`SafeAreaManager.apply_offsets(child, axes)`.

---

## 5. Letterbox vs notch — две РАЗНЫЕ вещи

Эти два явления выглядят одинаково (полосы по краям), но имеют разные
причины и разные фиксы. Не путай.

### 5.1 Letterbox

Возникает когда aspect окна устройства ≠ aspect вьюпорта проекта.

- В нашем `project.godot`: viewport `1476×680` (aspect 2.17:1).
- iPhone 14 Pro в landscape: 2480×1170 (aspect ~2.12:1).
- Окно шире, чем нужно вьюпорту → Godot оставляет горизонтальные полосы.
- В этих полосах виден `RenderingServer.set_default_clear_color`.
- Background ColorRect, даже full-bleed по вьюпорту, до этих полос
  **не достаёт** — они ВНЕ вьюпорта.

**Фикс:** `window/stretch/aspect = "expand"` в `project.godot`. Тогда
вьюпорт всегда == размеру окна, полос больше нет, FULL_RECT
действительно покрывает весь экран.

### 5.2 Notch / Dynamic Island

Это safe-area inset, OS-уровень. Реальный физический вырез в экране.
- Виден через `DisplayServer.get_display_safe_area()`.
- Отдаётся `SafeAreaManager` в виде margins.
- Фиксится исключительно через `apply_offsets` для UI детей, тогда
  как backgrounds остаются full-bleed.

При жалобе «полоса по краю»:
1. Спроси: полоса **постоянная и одинакового цвета на всех экранах**?
   → letterbox, чини aspect.
2. Полоса **меняется по сцене** (где-то её нет, где-то есть)?
   → safe-area inset чего-то, что должно было быть full-bleed.
   Чек-лист: `name = "Background"` или FULL_RECT? мета `safe_area_axes`
   на родителе?

---

## 6. Что должно быть full-bleed (не инсетиться)

Список того, что заведомо должно покрывать весь экран:
- Background-ColorRect / TextureRect основной сцены.
- Dim-слой popup'ов (Store, Shop, Settings, Info, Double-or-Nothing,
  Shop Gift, BIG WIN). Все они спавнятся как **прямые дети сцены**
  и **после** того как `_make_full_rect` пробежал по детям, поэтому
  не попадают в `_tracked` SafeAreaManager. Если делаешь **новый**
  popup из autoload — проверь, что он добавляется к host (сцена),
  а не как ребёнок до `_make_full_rect` (его инсетит).
- Полноэкранная анимация (BigWinOverlay).
- Loader / spinner (см. `main.gd._create_loader`).

Если в новом popup'е нужно, чтобы **сам контент** уважал safe-area,
а dim — нет: dim делается FULL_RECT внутри overlay-Control'а (он не
инсетится, потому что на месте overlay'я уже `mouse_filter=STOP`),
а внутренний panel / content анкорится в CENTER с собственным
margin'ом, который вычитает safe-area через прямой запрос
`SafeAreaManager.margins`.

---

## 7. Чек-лист при добавлении новой сцены / экрана

1. Корневой Control: `anchors_preset = 15`.
2. Background-ColorRect/TextureRect называется `Background` (страховка
   для FULL_RECT-эвристики).
3. Все UI-контейнеры — прямые дети корня — будут инсечены.
4. Если корневой контейнер должен быть full-width (например, edge-to-edge
   карусель) → добавь `metadata/safe_area_axes = "vertical"`.
5. Bottom-anchored / right-anchored sub-containers (anchor=1 с двух сторон)
   — после фикса в build 6 шевелятся правильно.
6. Не делай скриптовый ColorRect.new() как фон без имени — либо назови
   `Background`, либо поставь FULL_RECT.
7. Не вызывай вручную `SafeAreaManager.apply_offsets()` без причины —
   `main.gd._make_full_rect` уже сделает это.

---

## 8. Чек-лист при добавлении нового popup / overlay

1. Корень overlay — Control с `set_anchors_preset(PRESET_FULL_RECT)`.
2. Добавляется через `host.add_child(overlay)` уже после загрузки сцены
   → SafeAreaManager не трогает.
3. Dim-слой — ColorRect FULL_RECT внутри overlay'я. Покроет весь экран.
4. Контент-panel — CENTER, и если нужно сжаться от safe-area углов
   (например, чтобы кнопка close не залезла под Dynamic Island), читай
   `SafeAreaManager.margins` напрямую и применяй вручную.

---

## 9. Файлы

- `scripts/safe_area_manager.gd` — autoload, источник истины margins.
- `scripts/main.gd._make_full_rect` — диспетчер на каждой сцене.
- `project.godot` — `window/stretch/mode = "canvas_items"`,
  `window/stretch/aspect = "expand"`.
- Триггеры meta — в `scenes/lobby/lobby.tscn` (один-единственный сейчас).

---

*Создан: 2026-05-04 · По итогам безуспешного хождения по граблям с
build 3 → 4 → 5 → 6.*
