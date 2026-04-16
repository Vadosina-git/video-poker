# Video Poker — Classic Edition
## Project Design Document (claude.md)

---

## 1. Обзор проекта

**Название:** Video Poker — Classic Edition
**Платформа:** Godot 4.x (Mobile: iOS/Android + Desktop: Windows/macOS/Linux)
**Жанр:** Social Casino / Video Poker
**Стиль:** Классический автомат видео-покера, идентичный машинам в казино Лас-Вегаса (IGT Game King style)
**Монетизация:** Social casino (виртуальная валюта, без реальных денег)

---

## 2. Что такое Video Poker

Video Poker — казино-игра, основанная на пятикарточном дро-покере. Игрок делает ставку, получает 5 карт, выбирает какие оставить (Hold), а остальные заменяются из той же колоды. Выплата определяется итоговой покерной комбинацией по таблице выплат (paytable).

Ключевое отличие от слотов: результат зависит от решений игрока. Это игра навыка + удачи.

### Историческая справка
- Первые машины появились в середине 1970-х
- В 1979 году SIRCOMA (будущая IGT) выпустила Draw Poker
- К 1980-м стал одной из самых популярных казино-игр
- Сейчас — культовый формат, особенно в Лас-Вегасе среди locals

---

## 3. Базовый игровой процесс (Game Flow)

```
[Выбор ставки] → [DEAL] → [5 карт показаны] → [Игрок выбирает HOLD] → [DRAW] → [Замена карт] → [Оценка руки] → [Выплата или проигрыш] → [Повтор]
```

### Пошагово:

1. **Выбор ставки (Bet):** 1–5 монет. Всегда рекомендуется играть 5 (Max Bet), т.к. Royal Flush при 5 монетах платит 800:1 вместо 250:1.
2. **Deal:** Машина раздаёт 5 карт из стандартной колоды 52 карты (без джокеров для Jacks or Better).
3. **Hold/Discard:** Игрок нажимает кнопки HOLD под каждой картой, чтобы отметить карты для сохранения.
4. **Draw:** Машина заменяет незафиксированные карты новыми из той же колоды.
5. **Evaluation:** Итоговая 5-карточная рука оценивается. Если комбинация есть в paytable — выигрыш. Если нет — ставка проиграна.
6. **Payout:** Выигрыш начисляется в кредиты.

### Важные правила:
- Колода тасуется перед каждой раздачей (виртуальная колода из 52 карт)
- Замена карт идёт из ТОГО ЖЕ виртуального дека (оставшиеся 47 карт)
- Никогда нельзя получить дубликат уже имеющейся карты
- Игрок может сбросить все 5 карт или оставить все 5
- При пат-хенде Royal Flush машина автоматически фиксирует все карты

---

## 4. Игровые варианты — 10 машин (Game Variants)

Все 10 вариантов представлены в лобби как отдельные физические машины. Каждый вариант — отдельная машина со своим визуальным оформлением, paytable и правилами.

---

### 4.1 Jacks or Better
**Базовая и самая популярная вариация.** Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**9/6 Full Pay Paytable (за 1 монету / за 5 монет):**

| Комбинация | 1 coin | 2 coins | 3 coins | 4 coins | 5 coins |
|---|---|---|---|---|---|
| Royal Flush | 250 | 500 | 750 | 1000 | **4000** |
| Straight Flush | 50 | 100 | 150 | 200 | 250 |
| Four of a Kind | 25 | 50 | 75 | 100 | 125 |
| Full House | 9 | 18 | 27 | 36 | 45 |
| Flush | 6 | 12 | 18 | 24 | 30 |
| Straight | 4 | 8 | 12 | 16 | 20 |
| Three of a Kind | 3 | 6 | 9 | 12 | 15 |
| Two Pair | 2 | 4 | 6 | 8 | 10 |
| Jacks or Better | 1 | 2 | 3 | 4 | 5 |

**RTP:** 99.54% | **Variance:** Low (σ = 4.42) | **Сложность стратегии:** Низкая

---

### 4.2 Bonus Poker
То же что JoB, но увеличенные выплаты за Four of a Kind в зависимости от ранга. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**8/5 Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5 coins) |
| Straight Flush | 50 |
| 4 Aces | 80 |
| 4 Twos/Threes/Fours | 40 |
| 4 Fives–Kings | 25 |
| Full House | 8 |
| Flush | 5 |
| Straight | 4 |
| Three of a Kind | 3 |
| Two Pair | 2 |
| Jacks or Better | 1 |

**RTP:** 99.17% | **Variance:** Low | **Сложность стратегии:** Низкая

---

### 4.3 Bonus Poker Deluxe
Упрощённый Bonus Poker: ВСЕ четвёрки платят одинаково (80), но Two Pair платит только 1. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**9/6 Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5 coins) |
| Straight Flush | 50 |
| Four of a Kind (любой) | 80 |
| Full House | 9 |
| Flush | 6 |
| Straight | 4 |
| Three of a Kind | 3 |
| Two Pair | 1 |
| Jacks or Better | 1 |

**RTP:** 99.64% | **Variance:** Medium | **Сложность стратегии:** Низкая

---

### 4.4 Double Bonus Poker
Удвоенные выплаты за все четвёрки. Two Pair платит только 1. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**10/7 Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5 coins) |
| Straight Flush | 50 |
| 4 Aces | 160 |
| 4 Twos/Threes/Fours | 80 |
| 4 Fives–Kings | 50 |
| Full House | 10 |
| Flush | 7 |
| Straight | 5 |
| Three of a Kind | 3 |
| Two Pair | 1 |
| Jacks or Better | 1 |

**RTP:** 100.17% | **Variance:** Medium-High | **Сложность стратегии:** Средняя

---

### 4.5 Double Double Bonus Poker
Как Double Bonus, но с бонусами за четвёрки + кикер. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**9/6 Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5 coins) |
| Straight Flush | 50 |
| 4 Aces + 2/3/4 kicker | 400 |
| 4 Aces | 160 |
| 4 Twos/Threes/Fours + A/2/3/4 kicker | 160 |
| 4 Twos/Threes/Fours | 80 |
| 4 Fives–Kings | 50 |
| Full House | 9 |
| Flush | 6 |
| Straight | 4 |
| Three of a Kind | 3 |
| Two Pair | 1 |
| Jacks or Better | 1 |

**RTP:** 100.07% | **Variance:** High | **Сложность стратегии:** Высокая

---

### 4.6 Triple Double Bonus Poker
Экстремальные бонусы за четвёрки с кикером. 4 Aces + 2/3/4 = 800 × 5 = 4000 при Max Bet. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**9/7 Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5 coins) |
| Straight Flush | 50 |
| 4 Aces + 2/3/4 kicker | 800 |
| 4 Aces | 160 |
| 4 Twos/Threes/Fours + A/2/3/4 kicker | 400 |
| 4 Twos/Threes/Fours | 80 |
| 4 Fives–Kings | 50 |
| Full House | 9 |
| Flush | 7 |
| Straight | 4 |
| Three of a Kind | 2 |
| Two Pair | 1 |
| Jacks or Better | 1 |

**RTP:** 99.58% | **Variance:** Very High | **Сложность стратегии:** Высокая

---

### 4.7 Aces and Faces
Как Bonus Poker, но бонусные четвёрки — это Aces и Face cards (J/Q/K), а не мелкие карты. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**8/5 Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5 coins) |
| Straight Flush | 50 |
| 4 Aces | 80 |
| 4 Jacks/Queens/Kings | 40 |
| 4 Twos–Tens | 25 |
| Full House | 8 |
| Flush | 5 |
| Straight | 4 |
| Three of a Kind | 3 |
| Two Pair | 2 |
| Jacks or Better | 1 |

**RTP:** 99.26% | **Variance:** Low-Medium | **Сложность стратегии:** Низкая

---

### 4.8 Deuces Wild
Все четыре двойки — wild. Колода: 52. Wild: 4 (все 2). Мин. комбинация: Three of a Kind.

**NSUD (Not So Ugly Ducks) Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Natural Royal Flush | 250 (800 при 5 coins) |
| 4 Deuces | 200 |
| Wild Royal Flush | 25 |
| 5 of a Kind | 15 |
| Straight Flush | 9 |
| Four of a Kind | 4 |
| Full House | 4 |
| Flush | 3 |
| Straight | 2 |
| Three of a Kind | 1 |

**RTP:** 99.73% (NSUD) / 100.76% (Full Pay, практически не встречается) | **Variance:** Low (для wild-игры) | **Сложность стратегии:** Высокая

---

### 4.9 Joker Poker (Kings or Better)
Колода 53 карты (52 + 1 Joker). Джокер — wild. Мин. комбинация: пара Королей+.

**Full Pay Paytable (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Natural Royal Flush | 250 (800 при 5 coins) |
| 5 of a Kind | 200 |
| Wild Royal Flush | 100 |
| Straight Flush | 50 |
| Four of a Kind | 20 |
| Full House | 7 |
| Flush | 5 |
| Straight | 3 |
| Three of a Kind | 2 |
| Two Pair | 1 |
| Kings or Better | 1 |

**RTP:** 100.65% | **Variance:** Low-Medium | **Сложность стратегии:** Очень высокая (тысячи исключений)

---

### 4.10 Deuces and Joker Wild
Колода 53 (52 + 1 Joker). Wild: 5 карт (4 двойки + Joker). Максимальное количество wild-карт среди всех стандартных вариантов. Мин. комбинация: Three of a Kind. Джекпот-рука: 4 Deuces + Joker (все 5 wild), платит только при Max Bet.

**Full Pay Paytable (за 1 монету):**

| Комбинация | 1 coin | 2 coins | 3 coins | 4 coins | 5 coins |
|---|---|---|---|---|---|
| 4 Deuces + Joker | — | — | — | — | **10,000** |
| Natural Royal Flush | 250 | 500 | 750 | 1000 | 4000 |
| 4 Deuces (без Joker) | 25 | 50 | 75 | 100 | 125 |
| Wild Royal Flush | 12 | 24 | 36 | 48 | 60 |
| 5 of a Kind | 9 | 18 | 27 | 36 | 45 |
| Straight Flush | 6 | 12 | 18 | 24 | 30 |
| Four of a Kind | 3 | 6 | 9 | 12 | 15 |
| Full House | 3 | 6 | 9 | 12 | 15 |
| Flush | 3 | 6 | 9 | 12 | 15 |
| Straight | 2 | 4 | 6 | 8 | 10 |
| Three of a Kind | 1 | 2 | 3 | 4 | 5 |

**Ключевая особенность:** 4 Deuces + Joker — при ставке меньше 5 монет, эта комбинация оплачивается как 5 of a Kind (9 coins). Только при Max Bet (5 coins) выплата — **10,000 coins**. Это самый большой джекпот среди стандартных video poker машин.

**RTP:** 99.07% (full pay) | **Variance:** Medium-High | **Сложность стратегии:** Высокая

**Особенности реализации:**
- Колода 53 карты (нужен Joker sprite)
- Hand evaluator должен учитывать 5 wild-карт одновременно
- Специальная проверка: если рука = все 5 wilds И bet = 5 → выплата 10,000 (а не 5 of a Kind)
- При Wild Royal с 4 wild-картами — выгоднее разбить руку и ловить 5 wilds (из-за огромной разницы в выплате)

---

## 4.11 Сводная таблица машин

| # | Машина | Колода | Wild | Мин. рука | Full Pay RTP | Variance |
|---|---|---|---|---|---|---|
| 1 | Jacks or Better | 52 | — | JJ+ | 99.54% | Low |
| 2 | Bonus Poker | 52 | — | JJ+ | 99.17% | Low |
| 3 | Bonus Poker Deluxe | 52 | — | JJ+ | 99.64% | Medium |
| 4 | Double Bonus Poker | 52 | — | JJ+ | 100.17% | Medium-High |
| 5 | Double Double Bonus | 52 | — | JJ+ | 100.07% | High |
| 6 | Triple Double Bonus | 52 | — | JJ+ | 99.58% | Very High |
| 7 | Aces and Faces | 52 | — | JJ+ | 99.26% | Low-Medium |
| 8 | Deuces Wild | 52 | 4 (2s) | 3oaK | 99.73% | Low |
| 9 | Joker Poker | 53 | 1 (Joker) | KK+ | 100.65% | Low-Medium |
| 10 | Deuces and Joker Wild | 53 | 5 (2s+Joker) | 3oaK | 99.07% | Medium-High |

---

## 5. Лобби (Machine Select)

### 5.1 Концепция
Лобби построено в стиле IGT Game King: красная верхняя панель с балансом
и названием «VIDEO POKER», слева — тёмный sidebar с выбором режима игры
(**single / triple / five / ten / ultimate x / spin poker**), в центре —
горизонтально прокручиваемый grid из 10 карточек-машин. Под балансом в
top bar — шестерёнка ⚙ которая открывает popup настроек (на данный момент
содержит только выбор языка). Тап по машине сразу переходит в выбранный
режим (single → `game.tscn`, multi/ultimate x → `multi_hand_game.tscn`,
spin poker → `spin_poker_game.tscn`).

### 5.2 Layout лобби

```
┌──────────────────────────────────────────────────────┐
│ [chip] $24,383        VIDEO POKER           [⚙]      │   ← TopBar (красный)
├──────┬───────────────────────────────────────────────┤
│      │                                               │
│SINGLE│  [JOB] [Bonus] [BPD] [DBL] [DDB]              │
│ PLAY │                                               │
│      │  [TDB] [A&F] [DW]  [JP]  [D&J]                │
│TRIPLE│                                               │
│ PLAY │                                               │
│      │         (drag-scroll горизонтально)           │
│ FIVE │                                               │
│ PLAY │                                               │
│      │                                               │
│ TEN  │                                               │
│ PLAY │                                               │
│      │                                               │
│ULT X │                                               │
│      │                                               │
│SPIN  │                                               │
│POKER │                                               │
└──────┴───────────────────────────────────────────────┘
```

### 5.3 Визуальный стиль машины в лобби

Каждая машина — `PanelContainer` с именем сверху (жёлтый bold) и мини-описанием
внизу. Цвет фона меняется **динамически** в зависимости от выбранного режима
в sidebar (`_recolor_machines` в `lobby_manager.gd` использует `MODE_COLORS`).

| Элемент | Описание |
|---|---|
| **Название** | Жёлтый крупный текст (через `machine.{id}.name` в Translations — всегда английский бренд) |
| **Мини-описание** | Краткий обзор (через `machine.{id}.mini`, локализуется) |
| **Lock overlay** | Затемнение + замок для заблокированных машин (на данный момент все разблокированы) |
| **PLAY (тап по карточке)** | Тап по любой точке карточки → `_on_play_pressed` → `machine_selected` сигнал |

### 5.4 Выбор режима игры (sidebar)

`lobby_manager.gd` хранит `PLAY_MODES` со следующими записями:

| Режим | hands | ultra_vp | spin_poker | Куда ведёт |
|---|---|---|---|---|
| SINGLE PLAY   | 1  | false | false | `game.tscn` |
| TRIPLE PLAY   | 3  | false | false | `multi_hand_game.tscn` |
| FIVE PLAY     | 5  | false | false | `multi_hand_game.tscn` |
| TEN PLAY      | 10 | false | false | `multi_hand_game.tscn` |
| ULTRA VP      | 5  | **true**  | false | `multi_hand_game.tscn` (с множителями) |
| SPIN POKER    | 1  | false | **true**  | `spin_poker_game.tscn` |

Выбор режима сохраняется в `SaveManager.hand_count` / `.ultra_vp` /
`.spin_poker`. При возврате в лобби sidebar восстанавливает последнюю
активную кнопку.

### 5.5 Цветовая схема машин

| Машина | Основной цвет | Акцент |
|---|---|---|
| Jacks or Better | Синий | Золотой |
| Bonus Poker | Красный | Серебро |
| Bonus Poker Deluxe | Пурпурный | Золотой |
| Double Bonus | Тёмно-красный | Хром |
| Double Double Bonus | Бордовый | Золотой |
| Triple Double Bonus | Чёрный | Золотой |
| Aces and Faces | Зелёный | Серебро |
| Deuces Wild | Ярко-зелёный | Жёлтый |
| Joker Poker | Фиолетовый | Жёлтый |
| Deuces and Joker Wild | Изумрудный | Красный |

Примечание: при переключении режима в sidebar общий тон всех машин меняется
по `MODE_COLORS` (single = красный, triple = синий, ...).

### 5.6 Навигация и UX

- **Горизонтальный drag-скролл** grid'а машин (`_setup_drag_scroll` в
  `lobby_manager.gd`, хук на `_input` перехватывает `InputEventMouseMotion`
  когда мышь над `%GridScroll`).
- **Тап по машине** → `machine_selected` сигнал → `main.gd._on_machine_selected`
  → загрузка соответствующей `.tscn` в зависимости от режима.
- **Шестерёнка ⚙** → `_show_settings` → popup с одной кнопкой «LANGUAGE:
  <current>» → под-popup выбора языка (System / English / Русский / Español)
  → `Translations.set_language()` + `reload_current_scene()`.
- **Баланс** — постоянно отображается в top bar (чипсы + сумма).

### 5.7 Разблокировка машин

На данный момент **все машины разблокированы** по умолчанию. Поле `locked`
в `MACHINE_CONFIG` оставлено для будущей прогрессии.

---

## 6. Приоритет реализации

| Фаза | Статус | Состав |
|---|---|---|
| Phase 1 — MVP                    | ✅ done | Jacks or Better, базовый движок, single-hand игровой цикл, лобби |
| Phase 2 — Wild cards + 3 машины  | ✅ done | Bonus Poker, Deuces Wild, лобби на 3 машины |
| Phase 3 — Kicker logic + 7 машин | ✅ done | BPD, Double Bonus, DDB, Joker Poker (53-card deck) |
| Phase 4 — Полный набор 10 машин  | ✅ done | Triple Double Bonus, Aces & Faces, Deuces & Joker (5-wild evaluator) |
| Phase 5 — Multi-hand              | ✅ done | Triple/Five/Ten/12/25 play (`multi_hand_game.tscn` + `multi_hand_manager.gd`) |
| Ultra VP                         | ✅ done | Per-hand множители, 5-hand layout, glyph-based анимация NEXT→ACTIVE |
| Spin Poker                       | ✅ done | 3×5 reel grid slot-style вариант (`spin_poker_game.tscn`) |
| Double or Nothing                | ✅ done | Риск-раунд после выигрыша (single + multi) |
| In-game shop (stub)              | ✅ done | Кнопка top-up в HUD, popup с фиктивными покупками (`FREE`) |
| Локализация EN / RU / ES         | ✅ done | См. §20 — `Translations` autoload + `data/translations.json` |
| Phase 6 — Social & Monetization  | ⏳ TODO | Аккаунты, leaderboards, IAP, achievements, push-notifications |

---

## 7. Дизайн интерфейса — Игровой экран (UI/UX)

### 6.1 Визуальный стиль
Максимально классический, как IGT Game King машина:
- Тёмный фон (чёрный/тёмно-синий)
- Карты — стандартный дизайн, крупные, хорошо читаемые
- Paytable — всегда видна в верхней части экрана (как на реальной машине)
- Выигрышная строка в paytable подсвечивается при выигрыше
- Жёлто-красные акцентные цвета
- Металлическая текстура для рамок (хром/золото)
- LED-стиль для числовых дисплеев (кредиты, ставка, выигрыш)

### 6.2 Расположение элементов (Layout)

#### Portrait (Mobile основной):
```
┌────────────────────────────────┐
│         PAYTABLE               │
│  (таблица выплат, 9 строк)     │
│  Выигрышная строка подсвечена  │
├────────────────────────────────┤
│                                │
│   [Card1] [Card2] [Card3]     │
│       [Card4] [Card5]         │
│                                │
│   [HOLD]  [HOLD]  [HOLD]      │
│       [HOLD]  [HOLD]          │
│                                │
├────────────────────────────────┤
│  CREDITS: 1000  WIN: 0        │
│  BET: 5                       │
├────────────────────────────────┤
│ [BET 1] [BET MAX] [DEAL/DRAW] │
└────────────────────────────────┘
```

#### Landscape (Desktop / Tablet):
```
┌──────────────────────────────────────────────┐
│                   PAYTABLE                    │
│   (полная таблица в 5 столбцов по ставкам)   │
├──────────────────────────────────────────────┤
│                                              │
│   [Card1] [Card2] [Card3] [Card4] [Card5]   │
│   [HOLD]  [HOLD]  [HOLD]  [HOLD]  [HOLD]    │
│                                              │
├──────────────────────────────────────────────┤
│  CREDITS: 1000    BET: 5     WIN: 45         │
├──────────────────────────────────────────────┤
│  [BET 1] [BET MAX]         [DEAL/DRAW]       │
└──────────────────────────────────────────────┘
```

### 6.3 Элементы UI

| Элемент | Описание |
|---|---|
| **Paytable** | Постоянно отображается. Строка текущей ставки подсвечена. При выигрыше — мигает выигрышная строка. |
| **Карты** | 5 карт в ряд. Стандартный покерный дизайн. При HOLD — надпись "HELD" под картой или поверх. |
| **HOLD buttons** | Под каждой картой. Tap/click для toggle. Визуальный фидбэк (подсветка). |
| **BET ONE** | Увеличивает ставку на 1 (цикл 1→2→3→4→5→1). |
| **BET MAX / MAX BET** | Устанавливает ставку 5 и автоматически раздаёт (Deal). |
| **DEAL / DRAW** | Одна кнопка, меняющая надпись. DEAL — начать раунд. DRAW — заменить карты. |
| **Credits display** | LED-стиль. Текущий баланс. |
| **Bet display** | LED-стиль. Текущая ставка (1–5). |
| **Win display** | LED-стиль. Сумма выигрыша в текущей раздаче. |
| **Win label** | Название выигрышной комбинации (например, "FULL HOUSE"). |
| **Game selector** | Меню выбора варианта (JoB, Deuces Wild, etc.). За пределами игрового экрана — в лобби или dropdown. |

### 6.4 Denomination (Номинал)

В social casino — виртуальные кредиты. Номинал определяет стоимость одной монеты.

| Denomination | Bet 1 | Bet 5 (Max) |
|---|---|---|
| 1 credit | 1 | 5 |
| 5 credits | 5 | 25 |
| 25 credits | 25 | 125 |
| 100 credits | 100 | 500 |
| 500 credits | 500 | 2500 |

---

## 8. Игровая математика

### 9.1 Колода и рандом
- Стандартная колода 52 карты (54 для Joker Poker)
- Перед каждой раздачей колода полностью тасуется (Fisher-Yates shuffle)
- RNG должен быть криптографически надёжным
- Раздача: первые 5 карт — рука игрока, следующие 5 (позиции 6–10) — потенциальные замены
- При draw: карта на позиции i заменяется картой на позиции i+5
- Это точная реплика регулируемых казино-машин в Неваде

### 9.2 Оценка рук (Hand Evaluation)
Порядок проверки (от высшей к низшей):

1. Royal Flush — A K Q J 10, все одной масти
2. Straight Flush — 5 подряд одной масти
3. Four of a Kind — 4 карты одного ранга
4. Full House — Three of a Kind + Pair
5. Flush — 5 карт одной масти
6. Straight — 5 карт подряд (A может быть high: A-K-Q-J-10 или low: A-2-3-4-5)
7. Three of a Kind — 3 карты одного ранга
8. Two Pair — 2 пары
9. Jacks or Better — пара J, Q, K или A
10. Nothing — проигрыш

**Для Deuces Wild** — дополнительная логика с wild-картами, проверка 5 of a Kind, Wild Royal vs Natural Royal.

### 9.3 Частота комбинаций (9/6 Jacks or Better, при оптимальной стратегии)

| Комбинация | Частота (примерно) | % рук |
|---|---|---|
| Royal Flush | 1 из ~40,391 | 0.0025% |
| Straight Flush | 1 из ~9,148 | 0.011% |
| Four of a Kind | 1 из ~423 | 0.24% |
| Full House | 1 из ~87 | 1.15% |
| Flush | 1 из ~91 | 1.10% |
| Straight | 1 из ~89 | 1.12% |
| Three of a Kind | 1 из ~13 | 7.44% |
| Two Pair | 1 из ~8 | 12.93% |
| Jacks or Better | 1 из ~5 | 21.46% |
| Nothing (проигрыш) | — | 54.54% |

---

## 9. Звуковой дизайн

### 9.1 Звуки машины (обязательные)
| Событие | Звук |
|---|---|
| Coin insert / Bet | Металлический щелчок монеты |
| Deal | Быстрая раздача карт (шелест) |
| Card flip (Draw) | Щелчок переворота |
| Hold toggle | Короткий click/beep |
| Win (малый) | Короткая мелодия + звон монет |
| Win (средний) | Более продолжительная мелодия |
| Win (Royal Flush) | Фанфары, длинный звон джекпота |
| No win | Тишина или короткий "whomp" |
| Button press | Механический щелчок |

### 9.2 Амбиент
- Опционально: фоновый шум казино (разговоры, звон машин, ambient)
- Переключатель ON/OFF в настройках
- По умолчанию — OFF (только звуки машины)

---

## 10. Анимации

| Элемент | Анимация |
|---|---|
| Deal | Карты появляются поочередно слева направо (~100ms между картами) |
| Hold | Карта слегка поднимается вверх + надпись "HELD" |
| Draw | Незафиксированные карты переворачиваются / заменяются |
| Win | Выигрышные карты подсвечиваются; paytable-строка мигает; Win counter отсчитывает выигрыш |
| Royal Flush | Специальная анимация (вспышки, частицы, экран мигает) |
| Credits counter | Плавный roll-up/roll-down при изменении баланса |
| Paytable highlight | Столбец текущей ставки подсвечен; при выигрыше — строка пульсирует |

---

## 11. Технические спецификации

### 11.1 Движок и версия
- **Godot 4.6** (GDScript основной язык)
- Сборки: Android (APK/AAB), iOS (Xcode export), Windows, macOS, Linux
- Рендерер: **Mobile** (см. `project.godot` → `[rendering] renderer/rendering_method="mobile"`)

### 11.2 Разрешение и масштабирование
- Базовое разрешение: **1080 × 1920** (portrait)
- Landscape alternative: **1920 × 1080**
- Stretch mode: `canvas_items`
- Stretch aspect: `keep_height` (portrait) / `keep_width` (landscape)
- Поддержка Safe Area (notch, island) для iOS

### 11.3 Структура проекта (Godot)

```
res://
├── project.godot
├── export_presets.cfg               # Android + iOS export presets
├── CLAUDE.md                        # этот файл
├── scenes/
│   ├── main.tscn                    # точка входа, грузит lobby/game
│   ├── lobby/
│   │   ├── lobby.tscn               # лобби — sidebar + grid машин
│   │   └── machine_card.tscn        # карточка одной машины
│   ├── game.tscn                    # single-hand игровой экран
│   ├── multi_hand_game.tscn         # multi-hand / Ultra VP экран
│   ├── spin_poker_game.tscn         # Spin Poker экран (3×5 grid)
│   ├── mini_hand.tscn               # 5 мини-карт для multi-hand
│   ├── card.tscn                    # TextureRect карты
│   ├── paytable_display.tscn        # компонент paytable
│   └── ui/                          # legacy (не используется)
├── scripts/
│   ├── main.gd                      # загрузка сцен + создание variant
│   ├── game_manager.gd              # FSM single-hand
│   ├── multi_hand_manager.gd        # FSM multi-hand + Ultra VP
│   ├── spin_poker_manager.gd        # FSM Spin Poker
│   ├── lobby_manager.gd             # лобби: sidebar, grid, gift timer, exit confirm
│   ├── machine_card.gd              # карточка машины в лобби
│   ├── game.gd                      # UI single-hand (FSM, DEAL idle blink, auto-shop)
│   ├── multi_hand_game.gd           # UI multi-hand + Ultra VP
│   ├── spin_poker_game.gd           # UI Spin Poker
│   ├── mini_hand_display.gd         # визуал мини-руки (5 маленьких карт)
│   ├── card_visual.gd               # TextureRect карты + flip-анимации
│   ├── card_data.gd                 # Suit/Rank enum'ы, JOKER поддержка
│   ├── deck.gd                      # 52/53 карты, Fisher-Yates
│   ├── hand_evaluator.gd            # оценка стандартных покерных рук
│   ├── paytable.gd                  # загрузка JSON, локализация названий рук
│   ├── paytable_display.gd          # компонент таблицы выплат
│   ├── hud.gd                       # legacy (не используется)
│   ├── config_manager.gd            # autoload: загрузка configs/*.json
│   ├── save_manager.gd              # autoload: credits, denom, hand_count…
│   ├── sound_manager.gd             # autoload: звуки из configs/sounds.json
│   ├── translations.gd              # autoload: i18n (EN / RU / ES)
│   ├── vibration_manager.gd         # autoload: haptic feedback (iOS/Android)
│   ├── multiplier_glyphs.gd         # helper: SVG-глифы множителей Ultra VP
│   └── variants/
│       ├── base_variant.gd          # базовый класс (deal/draw/evaluate)
│       ├── jacks_or_better.gd
│       ├── bonus_poker.gd
│       ├── bonus_poker_deluxe.gd
│       ├── double_bonus.gd
│       ├── double_double_bonus.gd
│       ├── triple_double_bonus.gd
│       ├── aces_and_faces.gd
│       ├── deuces_wild.gd
│       ├── joker_poker.gd
│       └── deuces_and_joker.gd
├── configs/                         # JSON-конфиги (загружаются ConfigManager)
│   ├── animations.json
│   ├── balance.json
│   ├── gift.json
│   ├── init_config.json
│   ├── lobby_order.json
│   ├── machines.json
│   ├── shop.json
│   ├── sounds.json
│   └── ui_config.json
├── assets/
│   ├── cards/                       # спрайты основных карт (PNG)
│   ├── cards/cards_spin/            # квадратные SVG карты для Spin Poker
│   ├── sounds/                      # 22 placeholder MP3
│   ├── icons/                       # App icons: 48–1024px
│   ├── fonts/                       # (системный шрифт)
│   └── textures/
│       ├── glyphs/                  # глифы валюты/цифр для SaveManager
│       └── glyphs_multipliers/      # глифы множителей Ultra VP
├── data/
│   ├── paytables.json               # все таблицы выплат
│   ├── config.json                  # ⚠ LEGACY — удалить, заменён configs/*
│   └── translations.json            # i18n: EN / RU / ES
└── docs/
    ├── export_guide.md
    ├── vibration_setup.md
    ├── improvements_checklist.md
    ├── spin-poker-description.md
    └── superpowers/
```

### 11.4 Game State Machine (FSM)

```
IDLE → BETTING → DEALING → HOLDING → DRAWING → EVALUATING → WIN_DISPLAY → IDLE
```

| Состояние | Описание | Доступные действия |
|---|---|---|
| IDLE | Ожидание ставки | Bet One, Bet Max, Deal (если ставка > 0) |
| BETTING | Выбор ставки | Bet One, Bet Max, Deal |
| DEALING | Анимация раздачи | — (заблокировано) |
| HOLDING | Выбор карт для Hold | Hold toggles, Draw/Deal |
| DRAWING | Анимация замены | — (заблокировано) |
| EVALUATING | Оценка руки | — (автоматически) |
| WIN_DISPLAY | Показ выигрыша | Любая кнопка → IDLE |

### 11.5 Данные карт

Каждая карта представлена:
```gdscript
class_name CardData
var suit: int    # 0=Hearts, 1=Diamonds, 2=Clubs, 3=Spades
var rank: int    # 2-14 (2=2, ..., 10=10, 11=J, 12=Q, 13=K, 14=A)
var index: int   # Уникальный 0–51 (suit * 13 + rank - 2)
```

### 11.6 Deck (колода)

```gdscript
# Псевдокод
var cards: Array[int] = range(52)

func shuffle():
    # Fisher-Yates
    for i in range(51, 0, -1):
        var j = randi() % (i + 1)
        var temp = cards[i]
        cards[i] = cards[j]
        cards[j] = temp

func deal_hand() -> Array:
    shuffle()
    return cards.slice(0, 5)  # hand

func get_replacement(position: int) -> int:
    return cards[5 + position]  # replacement cards at indices 5-9
```

### 11.7 Hand Evaluator (псевдокод)

```gdscript
func evaluate(hand: Array[CardData]) -> String:
    var is_flush = all_same_suit(hand)
    var is_straight = is_consecutive(hand)
    var groups = group_by_rank(hand)  # {rank: count}
    var counts = groups.values().sorted().reversed()

    if is_flush and is_straight:
        if min_rank(hand) == 10:
            return "ROYAL_FLUSH"
        return "STRAIGHT_FLUSH"
    if counts[0] == 4:
        return "FOUR_OF_A_KIND"
    if counts[0] == 3 and counts[1] == 2:
        return "FULL_HOUSE"
    if is_flush:
        return "FLUSH"
    if is_straight:
        return "STRAIGHT"
    if counts[0] == 3:
        return "THREE_OF_A_KIND"
    if counts[0] == 2 and counts[1] == 2:
        return "TWO_PAIR"
    if counts[0] == 2:
        var pair_rank = get_pair_rank(groups)
        if pair_rank >= 11:  # J, Q, K, A
            return "JACKS_OR_BETTER"
    return "NOTHING"
```

### 11.8 Сохранение данных
- **Файл:** `user://save.json`
- **Данные:** credits, denomination, last_variant, settings (sound, music, speed)
- **Автосохранение:** после каждого раунда
- **Защита:** базовая обфускация (не критично для social casino)

---

## 12. Конфигурируемые параметры

Для быстрой настройки без изменения кода:

| Параметр | Тип | По умолчанию | Описание |
|---|---|---|---|
| `starting_credits` | int | 1000 | Начальный баланс |
| `free_credits_amount` | int | 500 | Бесплатные кредиты (подарок) |
| `free_credits_interval_hours` | int | 2 | Интервал бесплатных кредитов |
| `deal_speed_ms` | int | 100 | Задержка между картами при deal |
| `draw_speed_ms` | int | 150 | Задержка при замене карт |
| `win_counter_speed` | float | 0.02 | Скорость подсчёта выигрыша |
| `denominations` | Array | [1,5,25,100,500] | Доступные номиналы |
| `default_denomination` | int | 1 | Номинал по умолчанию |
| `enabled_variants` | Array | ["jacks_or_better"] | Активные варианты игры |
| `auto_hold` | bool | false | Автоматический HOLD лучших карт |
| `speed_mode` | bool | false | Ускоренная игра (без анимаций) |

---

## 13. Спрайты карт

### Требования:
- 52 карты + рубашка (back) + опционально Joker
- Формат: PNG с прозрачностью
- Размер: **300 × 420 px** (при базовом разрешении 1080×1920 — 5 карт шириной ~180px с отступами)
- Стиль: классический четырёхцветный или двухцветный (красный/чёрный)
- Рубашка: классический паттерн (ромбы, завитки) в красном или синем цвете

### Именование:
```
card_2_hearts.png, card_3_hearts.png, ... card_ace_spades.png
card_back.png
card_joker.png
```

Альтернативно — sprite sheet (atlas) 13×4 + back + joker.

---

## 14. Шрифты

| Использование | Шрифт (рекомендация) | Стиль |
|---|---|---|
| Paytable | Monospace / LCD-style (Digital-7, DSEG7) | Белый на тёмном, жёлтый highlight |
| Credits/Bet/Win | LED-стиль (DSEG7 Modern) | Зелёный или жёлтый |
| Названия комбинаций | Bold Sans-Serif | Белый, с glow при выигрыше |
| Кнопки | Bold uppercase Sans-Serif | Белый на тёмном |
| UI общий | Roboto / Open Sans | Стандартный |

---

## 15. Настройки (Settings)

### 15.1 Что доступно игроку через UI сейчас

**Шестерёнка ⚙ в лобби** открывает popup `_show_settings`, который содержит
всего одну кнопку «LANGUAGE: <текущий>». Тап по ней открывает sub-popup
выбора языка (System / English / Русский / Español). Подробности —
см. §20 «Система локализации».

**Кнопка SPEED** находится прямо в HUD игрового экрана (не в настройках).
Циклически переключает `speed_level` 0..3, сохраняется в `SaveManager.speed_level`.

**Выбор номинала** (`BET AMOUNT` кнопка в HUD) открывает popup со списком
денежных номиналов. Сохраняется в `SaveManager.denomination`.

**Выбор режима игры** (SINGLE / TRIPLE / FIVE / TEN / ULTRA VP / SPIN
POKER) — через sidebar лобби. Сохраняется в `SaveManager.hand_count` +
`.ultra_vp` + `.spin_poker`.

### 15.2 Что уже хранится в SaveManager, но UI-переключателя нет

`SaveManager.settings` содержит словарь с ключами:

| Ключ | Значения | Статус |
|---|---|---|
| `sound_fx` | `true`/`false` | В save, но UI нет |
| `music` | `true`/`false` | В save, но UI нет |
| `casino_ambient` | `true`/`false` | В save, но UI нет |
| `game_speed` | `"normal"` | В save, но UI нет (реально меняется через кнопку SPEED, это legacy) |
| `auto_hold` | `true`/`false` | В save, но UI нет |

TODO для Phase 6: расширить settings popup галочками для этих параметров
и реально читать/применять их (сейчас они только сохраняются/загружаются).

### 15.3 Что добавить в Phase 6

- Sound FX / Music / Casino Ambient тумблеры (+ подключить к `SoundManager`)
- Auto Hold hint переключатель
- Left/Right Hand Mode (для мобильных — расположение кнопок)

---

## 16. Roadmap

### Phase 1 — MVP (4–6 недель)
- [ ] Базовая структура Godot проекта
- [ ] Лобби с 1 машиной (Jacks or Better) + карусель-заглушки
- [ ] Deck, shuffle, deal, draw
- [ ] Hand Evaluator (Jacks or Better)
- [ ] Paytable display (9/6 JoB)
- [ ] FSM: full game loop
- [ ] UI: карты, кнопки, credits/bet/win displays
- [ ] Hold toggle
- [ ] Базовые звуки
- [ ] Базовые анимации (deal, draw, hold)
- [ ] Win display + paytable highlight
- [ ] Save/Load credits
- [ ] Desktop build (тестирование)

### Phase 2 — Wild Cards + 3 машины (3–4 недели)
- [ ] Bonus Poker variant (52-card, bonus quad logic)
- [ ] Deuces Wild variant (wild-card evaluator)
- [ ] Лобби: 3 машины, карусель работает
- [ ] Переход лобби ↔ машина (zoom transition)
- [ ] Denomination selector
- [ ] Free credits timer
- [ ] Casino ambient sound
- [ ] Mobile portrait layout
- [ ] Android build

### Phase 3 — Kicker Logic + 7 машин (3–4 недели)
- [ ] Bonus Poker Deluxe
- [ ] Double Bonus Poker
- [ ] Double Double Bonus Poker (kicker evaluation)
- [ ] Joker Poker (53-card deck, Joker sprite)
- [ ] Лобби: 7 машин, все карточки с уникальными цветами
- [ ] Info popup с полной paytable в лобби
- [ ] Royal Flush celebration animation
- [ ] Statistics screen
- [ ] iOS build

### Phase 4 — Полный набор 10 машин (3–4 недели)
- [ ] Triple Double Bonus Poker (extreme kicker payouts)
- [ ] Aces and Faces
- [ ] Deuces and Joker Wild (5-wild evaluator, 10,000 jackpot)
- [ ] Лобби: все 10 машин
- [ ] Configurable paytables (JSON)
- [ ] Разблокировка машин (progression)

### Phase 5 — Multi-Hand (4–6 недель)
- [ ] Triple Play Draw Poker (3 руки)
- [ ] Five Play Draw Poker (5 рук)
- [ ] Ten Play Draw Poker (10 рук)
- [ ] UI адаптация для multi-hand

### Phase 6 — Social & Monetization
- [ ] Аккаунты / авторизация
- [ ] Leaderboards
- [ ] Daily bonuses
- [ ] IAP (покупка кредитов)
- [ ] Achievements
- [ ] Push notifications

---

## 17. Glossary

| Термин | Значение |
|---|---|
| **Paytable** | Таблица выплат, определяющая сколько платит каждая комбинация |
| **Full Pay** | Лучшая (самая выгодная для игрока) версия paytable для данного варианта |
| **Short Pay** | Урезанная версия paytable с меньшим RTP |
| **9/6** | Сокращение: 9 за Full House, 6 за Flush (за 1 монету) |
| **RTP** | Return To Player — теоретический % возврата при оптимальной игре |
| **House Edge** | 100% - RTP. Преимущество казино |
| **Wild card** | Карта, заменяющая любую другую для составления комбинации |
| **Kicker** | Пятая карта при Four of a Kind, влияет на выплату в DDB |
| **Pat hand** | Рука, не требующая замены (готовая комбинация) |
| **Max Bet** | Максимальная ставка (5 монет). Активирует бонус Royal Flush |
| **Deal** | Начальная раздача 5 карт |
| **Draw** | Замена незафиксированных карт |
| **Hold** | Фиксация карты (не заменяется при draw) |
| **Credits** | Виртуальная валюта в машине |
| **Denomination** | Номинал одной монеты (определяет стоимость кредита) |
| **Natural** | Комбинация без wild-карт |
| **Variance / Volatility** | Мера колебаний баланса. Low = стабильно, High = резкие свинги |

---

## 18. Справочные ресурсы

- [VideoPoker.com](https://www.videopoker.com) — эталонная реализация всех вариантов, бесплатная тренировка
- [Wizard of Odds — Video Poker](https://wizardofodds.com/games/video-poker/) — математика, стратегии, paytables
- [vpFREE2](https://www.vpfree2.com) — база данных paytables по казино
- [Video Poker — Wikipedia](https://en.wikipedia.org/wiki/Video_poker) — общая справка
- IGT Game King — референсная машина для визуального стиля

---

*Документ создан: 2026-04-08*
*Обновлён: 2026-04-10*
*Версия: 2.0*

---

## 19. Актуальная архитектура кода

### Структура проекта

```
res://
├── project.godot                  # Godot 4.6, Mobile renderer
├── export_presets.cfg             # Android + iOS export presets
├── CLAUDE.md                      # Этот документ
├── scenes/
│   ├── main.tscn                  # Точка входа, переключение lobby↔game
│   ├── game.tscn                  # Single-hand игровой экран
│   ├── multi_hand_game.tscn       # Multi-hand игровой экран (3/5/10 + Ultra VP)
│   ├── spin_poker_game.tscn       # Spin Poker: 3×5 reel grid
│   ├── card.tscn                  # TextureRect карты с PNG-спрайтами
│   ├── mini_hand.tscn             # Мини-рука (5 маленьких карт)
│   ├── paytable_display.tscn      # Компонент таблицы выплат
│   ├── lobby/
│   │   ├── lobby.tscn             # Game King лобби с sidebar + grid
│   │   └── machine_card.tscn      # Красная плашка автомата
│   └── ui/
│       ├── hud.tscn               # (legacy, не используется)
│       └── buttons.tscn           # (legacy, не используется)
├── scripts/
│   ├── main.gd                    # Загрузка lobby/game, создание variant по ID
│   ├── game.gd                    # UI single-hand: FSM, анимации, overlay'и, DEAL idle blink, auto-shop
│   ├── multi_hand_game.gd         # UI multi-hand: N рук, мини-грид, Ultra VP множители
│   ├── spin_poker_game.gd         # UI Spin Poker: 3×5 grid, 20 lines, slot-style spin
│   ├── game_manager.gd            # FSM single-hand: deal→hold→draw→evaluate
│   ├── multi_hand_manager.gd      # FSM multi-hand: N колод, суммарный payout
│   ├── spin_poker_manager.gd      # FSM Spin Poker: reel logic, line evaluation
│   ├── card_data.gd               # Suit/Rank enum'ы, JOKER поддержка
│   ├── card_visual.gd             # TextureRect с PNG, flip анимации, HELD
│   ├── mini_hand_display.gd       # 5 мини-карт в ряд для multi-hand
│   ├── deck.gd                    # 52/53 карты, Fisher-Yates, multihand draws
│   ├── hand_evaluator.gd          # Стандартные покерные комбинации, hold mask
│   ├── paytable.gd                # Загрузка JSON, lookup по hand_rank
│   ├── paytable_display.gd        # GridContainer с ячейками, подсветка строк
│   ├── multiplier_glyphs.gd       # SVG-глифы для множителей Ultra VP
│   ├── lobby_manager.gd           # Grid машин, sidebar режимов, drag-скролл, gift timer, exit confirm
│   ├── machine_card.gd            # Красная плашка, (i) кнопка, click → play
│   ├── config_manager.gd          # Autoload: загрузка configs/*.json, fallback defaults
│   ├── save_manager.gd            # Autoload: credits, denomination, hand_count, ultra_vp
│   ├── sound_manager.gd           # Autoload: загрузка звуков из configs/sounds.json
│   ├── translations.gd            # Autoload: i18n EN/RU/ES
│   ├── vibration_manager.gd       # Autoload: haptic feedback (iOS/Android)
│   ├── hud.gd                     # (legacy)
│   └── variants/
│       ├── base_variant.gd        # Базовый класс: deal, draw, evaluate, payout
│       ├── jacks_or_better.gd     # Стандартный evaluator
│       ├── bonus_poker.gd         # 3 уровня четвёрок (Aces/2-4/5-K)
│       ├── bonus_poker_deluxe.gd  # Все четвёрки = 80
│       ├── double_bonus.gd        # Удвоенные четвёрки
│       ├── double_double_bonus.gd # Четвёрки + кикер
│       ├── triple_double_bonus.gd # Экстремальный кикер
│       ├── aces_and_faces.gd      # Четвёрки: Aces/JQK/2-10
│       ├── deuces_wild.gd         # Wild evaluator (двойки wild)
│       ├── joker_poker.gd         # Wild evaluator (Joker wild, 53 карты)
│       └── deuces_and_joker.gd    # 5 wild карт (двойки + Joker)
├── configs/                       # JSON-конфиги (загружаются ConfigManager)
│   ├── animations.json            # Таймеры анимаций (deal/draw/flip скорости)
│   ├── balance.json               # Стартовые кредиты, лимиты, auto-shop threshold
│   ├── gift.json                  # Free chips: интервал, сумма подарка
│   ├── init_config.json           # Начальные настройки при первом запуске
│   ├── lobby_order.json           # Порядок и видимость машин в лобби
│   ├── machines.json              # Все 10 машин: цвета, accents, locked, paytable refs
│   ├── shop.json                  # Пакеты покупок (виртуальная валюта)
│   ├── sounds.json                # Маппинг событий → звуковых файлов
│   └── ui_config.json             # Размеры шрифтов, отступы, UI-параметры
├── data/
│   ├── paytables.json             # Все 10 таблиц выплат
│   └── translations.json          # Локализация EN/RU/ES (~300+ ключей)
├── assets/
│   ├── cards/                     # PNG спрайты: card_vp_{rank}{suit}.png
│   ├── cards/cards_spin/          # SVG квадратные карты для Spin Poker (52+joker+back+wilds)
│   ├── textures/                  # SVG кнопки, HELD, glyphs, glyphs_multipliers
│   ├── sounds/                    # 22 placeholder MP3 (sfx_card_deal, sfx_win_*, sfx_gift_claim и др.)
│   ├── icons/                     # App icons: 48–1024px (icon_48.png ... icon_1024.png)
│   └── fonts/                     # (пусто — системный шрифт)
├── docs/
│   ├── export_guide.md            # Инструкция экспорта Android/iOS
│   ├── vibration_setup.md         # Настройка haptic feedback
│   ├── improvements_checklist.md  # Текущий чеклист улучшений
│   ├── spin-poker-description.md  # Дизайн-документ Spin Poker
│   ├── Video_Poker_improvements_13_04_2026.md
│   └── superpowers/               # Доп. документация
└── export_presets.cfg             # Android + iOS export presets
```

**Примечание:** файл `data/config.json` — legacy, больше не используется.
Вся конфигурация перенесена в `configs/*.json` и загружается через
`ConfigManager`. `data/config.json` следует удалить.

### Краткая сводка

- **3 игровых экрана**: `game.tscn` (single), `multi_hand_game.tscn`
  (3/5/10 рук + Ultra VP), `spin_poker_game.tscn` (3×5 reel grid, 20 lines).
- **1 лобби**: `scenes/lobby/lobby.tscn` + `machine_card.tscn`.
- **10 вариантов покера** в `scripts/variants/` — все наследуют `BaseVariant`.
- **3 FSM-менеджера**: `game_manager.gd`, `multi_hand_manager.gd`,
  `spin_poker_manager.gd`.
- **Вспомогательные утилиты**: `multiplier_glyphs.gd` (SVG-глифы для
  множителей Ultra VP), `translations.gd` (i18n autoload),
  `config_manager.gd` (JSON configs), `vibration_manager.gd` (haptic).

### Ключевые паттерны

**Variant system.** Каждый вариант покера — отдельный класс, наследующий
`BaseVariant`. Обязательные для override методы:
- `evaluate(hand)` → `HandRank` — для wild-вариантов возвращает ближайший
  стандартный ранг и параллельно сохраняет `_last_hand_key`.
- `get_payout(rank, bet)` — для bonus/kicker-вариантов учитывает ранг
  четвёрки и кикера.
- `get_paytable_key(rank)` — возвращает строковый ключ из `paytables.json`
  (например `"four_aces_with_234_kicker"`). Нужен чтобы paytable мог
  посмотреть правильный payout row И чтобы локализация подтянула правильный
  `hand.{key}` из translations.
- `get_hand_name(rank)` — **НЕ override'ится** (кроме `BaseVariant`). Базовая
  реализация вызывает `paytable.get_hand_display_name(get_paytable_key(rank))`
  который резолвит через `Translations.tr_key("hand." + key)`. Любое
  кастомное имя руки должно быть ключом в `translations.json`.

**Config-driven architecture.** Все настройки вынесены из кода в
`configs/*.json` (9 файлов). `ConfigManager` (autoload) загружает их при
старте и предоставляет `get_value(file, key, default)`. Fallback defaults
зашиты в `ConfigManager` на случай отсутствия файла.

**Paytable-driven payouts.** Все выплаты хранятся в `data/paytables.json`.
Variant-скрипты используют строковые ключи для lookup, минуя ограничения
`HandRank` enum'а. Локализация имён — `Paytable.get_hand_display_name(key)`
(см. §20).

**Scene structure (game screen):**
```
TopSection (VBox, anchor top) — title, paytable, balance/status
MiddleSection (dynamic anchors) — карты (+ мини-руки в multi-hand)
BottomSection (VBox, anchor bottom) — total bet, кнопки, padding
```
MiddleSection позиционируется между Top и Bottom через `_layout_middle()`.

**Multi-hand.** `MultiHandManager` создаёт N-1 дополнительных `Deck`
экземпляров. При draw каждая extra рука получает те же held-карты но
уникальные replacements из своей колоды. Флаг `ultra_vp` активирует
режим per-hand множителей (см. «Как работает Ultra VP» ниже).

**Ultra VP** (ранее «Ultimate X»). При `bet == MAX_BET` активируется per-hand
multiplier система: выигрышные руки генерируют множитель для *следующего*
раунда. `MultiHandManager` держит два массива: `hand_multipliers[]`
(применяется *сейчас*) и `next_multipliers[]` (будет промоутед в
`hand_multipliers[]` на следующий DEAL). UI-стороной занимается
`multi_hand_game.gd` + `multiplier_glyphs.gd`: два Control'а на руку
(`_next_displays[i]` — сверху над картой с «NEXT HAND / NX»,
`_active_displays[i]` — снизу с «NX»). Анимация при DEAL: старый ACTIVE
fade out + NEXT (детачим header и value из VBox, header фейдит в месте,
value сдвигается вниз) + новый ACTIVE pop-in.

**Spin Poker.** Отдельный режим, slot-style: 3 ряда × 5 колонок reel grid,
20 линий. Использует собственный `SpinPokerManager`, `spin_poker_game.gd` UI
и квадратные SVG-карты из `assets/cards/cards_spin/`.

### Техническая реализация Spin Poker — барабаны и шторки

**Архитектура рилов.** Каждый из 5 столбцов — это «барабан» (reel). Визуально
представлен 3 ячейками (`_card_rects[row][col]`, row 0/1/2 = top/mid/bot)
из GridContainer. Верхний и нижний ряды закрываются **шторками** — persistent
`TextureRect` с текстурой `card_back_spin.svg`, позиционированные поверх
ячеек (z_index=3). Шторки создаются один раз в `_build_persistent_shutters()`
и живут всё время. Массив: `_col_shutters[col] = {top: TextureRect, bot: TextureRect, open: bool}`.

**Важно: под шторками всегда лицевые карты, никогда не card_back.** При первом
запуске — случайные (`_init_shutters_closed`). При последующих раундах —
карты остаются от предыдущего результата. `_set_card_back()` не вызывается
для строк 0 и 2.

**Анимация барабанов (reel spin).** Используется `Control` с `clip_contents=true`
поверх ячеек (z_index=20). Внутри — plain `Control` (strip) с дочерними
`TextureRect`, расположенными вручную через `tex.position = Vector2(0, ch*i)`
и `tex.size = Vector2(cw, ch)`. **Не VBoxContainer** — он перезаписывает
position дочерних нод при layout, убивая анимацию. Анимация прокрутки:
`strip.position.y` через Timer. Перед стартом анимации обязательно
`await get_tree().process_frame × 2` чтобы clip получил ненулевой size.

**Структура strip:** `[prev_card(s)] [filler×N] [filler×N copy] [target(s)]`.
- Первая карта(ы) = текущие карты на экране (из предыдущего раунда)
- Филлеры удвоены для бесшовной зацикленной прокрутки
- Последняя карта(ы) = целевые (новая раздача)
- Прокрутка: `strip.position.y = -fmod(offset, loop_h)` где `loop_h = cell_h × filler_count`

**Разгон/торможение.** Скорость прокрутки нарастает от 0 до max за ~0.5с
(квадратичный ease-in: `speed = max_speed × t²`). Торможение при остановке:
Tween с `EASE_OUT + TRANS_QUAD` + bounce (отскок ~5px).

**Сценарий DEAL/SPIN:**
1. Шторки закрываются анимированно (если были открыты от прошлого раунда)
2. Под шторками и в среднем ряду — карты прошлого раунда
3. Strip среднего ряда начинается с предыдущей карты (`cell.texture`)
4. Барабаны крутятся через окно среднего ряда (clip = 1 cell tall)
5. Остановка слева направо с задержкой между столбцами

**Сценарий HOLD:**
- При холде: `_animate_shutter_open(col)` — шторки раздвигаются, показывая
  ту же карту из среднего ряда в top/bottom
- При снятии холда: `_animate_shutter_close(col)` — шторки закрываются

**Сценарий DRAW:**
1. Шторки нехолденных столбцов открываются (0.25с), ждём завершения
2. Strip 3 ряда начинается с текущих 3 карт (`_card_rects[row][col].texture`)
3. Барабаны крутятся через все 3 ряда (clip = 3 cells tall)
4. Остановка слева направо

**`_rush` механика.** Тап во время вращения ставит `_rush = true`, все
барабаны мгновенно показывают целевые карты. Защита: `_spin_started_frame`
предотвращает rush от того же клика, что запустил спин. `_rush` сбрасывается
в `false` в начале `_on_deal_spin_complete` и `_on_draw_spin_complete`.

**Скорости.** `SPEED_CONFIGS[0..3]` — четыре уровня. При MAX (level 3)
`base_spin_ms=0` → анимация пропускается полностью.

**Card rendering.** Обычные карты — `TextureRect` с PNG-спрайтами из
Figma. Путь: `res://assets/cards/card_vp_{rank}{suit}.png`. Joker:
`card_vp_joker_red.png`. Рубашка: `card_back.png`. Для Spin Poker — квадратные
SVG из `assets/cards/cards_spin/`.

**Styling.** Все `theme_override` свойства применяются из GDScript (не из
.tscn). Цвета: фон #000086, акцент #FFEC00 (жёлтый), кнопки — SVG-текстуры.

**Lobby.** Game King стиль — красная top bar с балансом и шестерёнкой ⚙,
sidebar с 6 режимами (SINGLE / TRIPLE / FIVE / TEN / ULTRA VP / SPIN
POKER), grid 5×2 машин с drag-scroll. Доп. фичи: gift timer (бесплатные
фишки по таймеру), exit confirm dialog, delete account. См. §5 для деталей.

**Gift system.** Бесплатные фишки по таймеру. Конфиг в `configs/gift.json`
(интервал, сумма). Таймер показывается в лобби. При готовности — claim popup.

**DEAL idle blink.** Кнопка DEAL мигает когда игрок бездействует в состоянии
IDLE, привлекая внимание к началу игры.

**Auto-shop on low balance.** При недостаточном балансе для ставки
автоматически открывается shop popup.

**Локализация.** См. §20. Короткая сводка: любой пользовательский текст
идёт через `Translations.tr_key("key", [args])`. Названия рук — через
`Paytable.get_hand_display_name(key)`. Переключение языка — через ⚙ в
лобби (sub-popup «LANGUAGE»).

### Autoloads

Зарегистрированы в `project.godot` → `[autoload]`:

- **`SaveManager`** (`scripts/save_manager.gd`) — персистентное состояние.
  Поля: `credits`, `denomination`, `last_variant`, `hand_count`, `speed_level`,
  `bet_level`, `ultra_vp`, `spin_poker`, `depth_hint_shown`, `language`,
  `settings: Dictionary`. Плюс utility-методы: `format_money`, `format_short`,
  `create_currency_display`, `set_currency_value`, `estimate_currency_width`,
  `add_credits`, `deduct_credits`. Сохраняется в `user://save.json`.
  Примечание: поле `ultra_vp` (ранее `ultimate_x`) — при загрузке
  принимает оба ключа для обратной совместимости.
- **`SoundManager`** (`scripts/sound_manager.gd`) — загрузка и проигрывание
  звуков. Маппинг событий → файлов из `configs/sounds.json`. 22 placeholder
  MP3 в `assets/sounds/`.
- **`Translations`** (`scripts/translations.gd`) — i18n EN/RU/ES. Подробности в §20.
- **`ConfigManager`** (`scripts/config_manager.gd`) — загрузка всех
  `configs/*.json` (9 файлов: animations, balance, gift, init_config,
  lobby_order, machines, shop, sounds, ui_config). Предоставляет
  `get_value(file, key, default)` с fallback defaults.
- **`VibrationManager`** (`scripts/vibration_manager.gd`) — haptic feedback
  для мобильных платформ (iOS/Android). Различные паттерны вибрации для
  событий (deal, hold, win, jackpot).

### Как добавить новый вариант покера

1. Создать `scripts/variants/new_variant.gd` — `class_name NewVariant extends BaseVariant`.
2. Реализовать `evaluate()`, `get_paytable_key()`, опционально
   `get_payout()`. **НЕ** переопределять `get_hand_name()` — базовый
   класс сам резолвит через Translations.
3. Добавить paytable в `data/paytables.json` с уникальным ID.
4. Добавить `match` ветку в `main.gd → _create_variant()`.
5. Добавить конфиг машины в `configs/machines.json` (ID, цвет, accent,
   locked-флаг) и порядок в `configs/lobby_order.json`.
6. **Локализация:** добавить в `data/translations.json` в каждый из трёх
   языков (`en`/`ru`/`es`) ключи `machine.{id}.name`, `machine.{id}.mini`,
   `machine.{id}.feature`. Названия машин — всегда на английском во всех
   языках (бренды-константы).
7. Если вариант вводит новые ключи рук (`four_aces_with_kicker` и т.п.) —
   добавить `hand.{key}` во все три языка `translations.json`.

### Как работает multi-hand

1. Игрок выбирает режим в sidebar лобби (Triple / Five / Ten / Ultra VP /
   Spin Poker).
2. `SaveManager.hand_count`, `.ultra_vp`, `.spin_poker` сохраняются.
3. `main.gd → _on_machine_selected` смотрит на флаги и загружает нужную
   сцену: `game.tscn` (single), `multi_hand_game.tscn` (multi / Ultra VP),
   `spin_poker_game.tscn` (Spin Poker).
4. `MultiHandManager.setup(variant, num_hands, ultra_vp)` создаёт N-1
   дополнительных `Deck` экземпляров. Если `ultra_vp == true` — включает
   систему per-hand множителей.
5. `Bet = bet × num_hands × denomination`. В Ultra VP при MAX_BET — умножается
   ещё ×2 (цена за активацию фичи).
6. **Deal**: primary рука раздаётся и показывается немедленно, extras
   начинают с backs.
7. **Hold**: игрок выбирает карты на primary руке — тот же hold
   автоматически применяется ко всем extras.
8. **Draw**: primary рука тянет замены из своей колоды; каждая extra рука
   — из своей, параллельно. Ultra VP: если `hand_multipliers[i] > 1`,
   payout этой руки умножается.
9. **Evaluate**: все руки оценены, `total_payout = Σ(payout × multiplier)`.
   В Ultra VP — заполняется `next_multipliers[]` для выигрышных рук
   (по таблице: JJ→2x, 2P→3x, 3oaK→4x, Straight→5x, Flush→6x, FH→8x,
   4oaK→10x, SF/RF→12x). Невыигрышные руки теряют `hand_multipliers[i]`
   (сбрасывается на 1x для следующего раунда).
10. При следующем DEAL: `hand_multipliers[] ← next_multipliers[]`, UI
    проигрывает анимацию «NEXT → ACTIVE» (см. «Ultra VP» выше).

---

## 20. Система локализации (i18n)

Проект полностью локализован. Поддерживаемые языки: **английский (`en`)**,
**русский (`ru`)**, **испанский (`es`)**. Никакого хардкода пользовательского
текста в коде или сценах — всё идёт через один autoload.

### 20.1 Архитектура

```
┌──────────────────────────┐        ┌────────────────────────────┐
│ data/translations.json   │◄───────│ scripts/translations.gd    │
│ { languages: {           │        │ (autoload "Translations")  │
│     en: { key: str, ...} │        │                            │
│     ru: { key: str, ...} │        │ tr_key(key, args) → str    │
│     es: { key: str, ...} │        │ set_language(code)         │
│ }}                       │        │ get_available_codes()      │
└──────────────────────────┘        │ display_name_for_code()    │
                                    └────────────────────────────┘
                                                 ▲
                                                 │
                   ┌─────────────────────────────┴──────────┐
                   │                                        │
            scripts/*.gd                        scripts/variants/*.gd
         (lobby, game, multi-hand,                    (base + overrides
          settings, popups, etc.)                     use paytable key)
```

- **`scripts/translations.gd`** — autoload `Translations`. Парсит JSON один
  раз при запуске (`_ready`). Детектит OS-локаль через `OS.get_locale_language()`
  только если `SaveManager.language == "system"` или пусто; иначе использует
  сохранённый выбор игрока. Фолбэк на `en` → на сам ключ (ключ в рантайме
  видно как надпись — это специально, чтобы сразу замечать пропущенные
  переводы).
- **`data/translations.json`** — единственный источник правды. Структура
  `{ version: 1, languages: { <код>: { <ключ>: <строка>, ... } } }`.
  Ключи плоские, через точку: `модуль.назначение[.подтип]` (например
  `lobby.cash`, `game.bet_one_fmt`, `info_card.active`, `hand.four_aces`,
  `machine.jacks_or_better.name`).
- **`SaveManager.language: String`** — сохраняется в `user://save.json`.
  Значения: `"system"` | `"en"` | `"ru"` | `"es"`. `"system"` — «следовать
  за локалью устройства».
- **Шестерёнка ⚙ в лобби** (`_build_settings_button` в `lobby_manager.gd`)
  открывает settings popup. Там есть одна кнопка `LANGUAGE: <текущий>`
  которая разворачивает подпопап с выбором кода. Выбор языка вызывает
  `Translations.set_language(code)` + `get_tree().reload_current_scene()` —
  весь `main.tscn` перезагружается, `_ready()` каждого Control'а снова
  считывает тексты через `tr_key`.

### 20.2 API

```gdscript
# Простая подстановка
label.text = Translations.tr_key("game.place_your_bet")

# С аргументами (интерполяция через %s / %d)
label.text = Translations.tr_key("game.bet_one_fmt", [bet])
msg.text   = Translations.tr_key("double.msg_fmt",
        [SaveManager.format_money(_double_amount),
         SaveManager.format_money(doubled)])

# Названия покерных рук — всегда через Paytable, не напрямую
var display := paytable.get_hand_display_name(key)
# (paytable.gd внутри делает Translations.tr_key("hand." + key))

# Название/описание/фича машины
Translations.tr_key("machine.%s.name" % variant_id)
Translations.tr_key("machine.%s.mini" % variant_id)
Translations.tr_key("machine.%s.feature" % variant_id)
```

### 20.3 Пространства имён ключей

| Префикс | Где используется |
|---|---|
| `common.*`       | «YES», «NO», «GOT IT», «FREE», «X», «OK» — кнопки подтверждения, общие слова. |
| `lobby.*`        | Кнопки режимов (`mode_single_play`, `mode_ultra_vp`…), заголовки top-bar'а, cash-метка. |
| `settings.*`     | Заголовок и кнопки popup'а настроек и выбора языка. |
| `game.*`         | Всё игровое поле: `deal`, `draw`, `double`, `bet_one_fmt`, `bet_max`, `total_bet`, `balance`, `games`, `win_label`, `no_win`, `place_your_bet`, `hold_cards_then_draw`, `last_win_fmt`, `held`, `winnings`, `try_again`. |
| `game_depth.*`   | Тултип «Game Depth» (single- и multi-варианты текста). |
| `bet_select.*`   | Popup выбора номинала ставки. |
| `shop.*`         | Shop popup (кнопки `FREE`, заголовок). |
| `info.*`         | Info-popup: заголовки (`title_single`, `title_multi`, `title_ultra_vp`), правила (`rules_*`), таблица множителей (`multiplier_table`, `col_winning_hand`, `col_next_multiplier`), таблица машин (`machines_title`, `col_machine`, `col_deck`, `col_rtp`, `col_feature`). |
| `info_card.*`    | Боковая Ultra VP info-карточка (`ultra_vp_title`, `description`, `active`, `press_to_activate`). |
| `double.*`       | Double-or-Nothing popup и статусы (`title`, `msg_fmt`, `pick_card`, `win`, `tie`, `lose`, `win_doubled_fmt`). |
| `hand.*`         | **Все** названия комбинаций (`jacks_or_better`, `two_pair`, `royal_flush`, плюс wild-варианты `wild_royal_flush`, `five_of_a_kind`, `four_deuces_joker`, плюс kicker-ключи `four_aces_with_234_kicker` и т.д.). Ключ = имя ключа в `paytables.json` → `hand.{key}`. |
| `machine.{id}.*` | Per-variant: `name`, `mini` (описание под заголовком в карточке лобби), `feature` (строка в info-таблице машин). `{id}` = variant_id (`jacks_or_better`, `deuces_and_joker`…). |

**Важно:** названия машин (`machine.*.name`) — **английские во всех трёх
языках** (бренды-константы: «Jacks or Better», «Deuces Wild»…). Название
режима `ULTRA VP` — тоже английское во всех языках. Всё остальное
переводится.

### 20.4 Где локализация резолвится автоматически

- **Покерные руки в результатах/бейджах** → `BaseVariant.get_hand_name()` →
  `get_paytable_key()` → `Paytable.get_hand_display_name(key)` →
  `Translations.tr_key("hand." + key)`. Варианты не должны переопределять
  `get_hand_name()` — только `get_paytable_key()`.
- **Paytable-бейджи в `_build_paytable_badges`** — берут имена через
  `_variant.paytable.get_hand_display_name(key)`.
- **Цвет бейджа в `_get_badge_color_for_hand`** — сравнивает уже локализованное
  имя с локализованным же через тот же `get_hand_display_name`.

### 20.5 Как добавлять новый текст — чеклист

1. Придумать ключ вида `модуль.назначение` (или `модуль.назначение_fmt` если
   будут `%s` / `%d`-аргументы). Не дублировать — сперва поискать в
   `data/translations.json`.
2. Добавить строку в **все три** блока `languages.en`, `languages.ru`,
   `languages.es` в `data/translations.json`.
3. В коде использовать `Translations.tr_key("ключ")` или
   `Translations.tr_key("ключ_fmt", [arg1, arg2])`.
4. В `.tscn`-файле не писать финальный текст — оставить пустое значение или
   нейтральный placeholder. Финальное значение выставляется из `_ready()`
   скрипта сцены через `Translations.tr_key()`.
5. Если это новая покерная рука или новая машина — сразу завести ключи
   `hand.{paytable_key}` / `machine.{variant_id}.name` / `.mini` / `.feature`
   во всех языках.

### 20.6 Валидация

- `python3 -c "import json; d=json.load(open('data/translations.json')); \
  print({k: len(v) for k,v in d['languages'].items()})"` — должно вернуть
  одинаковое число ключей для `en` / `ru` / `es`. Любое расхождение = забыт
  перевод.
- Если во время игры видишь в интерфейсе сам ключ (например
  `game.place_your_bet`) — значит этого ключа нет ни в выбранном языке, ни в
  `en` (двухуровневый фолбэк не сработал). Нужно добавить его в JSON.

---

### Правила для Claude Code

- **Всегда отвечать пользователю на русском языке**
- **Не коммитить без явного одобрения пользователя**
- Все стили — в GDScript, не в .tscn (Godot 4.6 парсер отвергает `theme_override_`)
- Использовать `load()` вместо `preload()` для сцен (избежать circular dependencies)
- Корневые ноды сцен: `anchors_preset = 15` без `layout_mode`
- Карты: `TextureRect` с `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`
- **Никаких хардкодов пользовательского текста — только `Translations.tr_key()`.**
  Подробности и полный API — в §20 «Система локализации». Перед добавлением
  любой новой надписи (`Label.text`, `Button.text`, заголовок popup'а,
  статус, win-бейдж, info-popup, название новой руки или машины) сначала
  добавь ключ в `data/translations.json` во все три языка (`en` / `ru` / `es`),
  потом используй `Translations.tr_key("ключ", [опциональные args])`.
  Названия покерных рук — всегда через `Paytable.get_hand_display_name(key)`.
  Текст в `.tscn` оставляй пустым — финальное значение ставится в `_ready()`.
