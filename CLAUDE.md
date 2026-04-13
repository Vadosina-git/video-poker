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
Лобби представляет собой зал казино с видом на ряды видео-покерных машин. Игрок свайпает/скроллит горизонтально и тапает на машину, чтобы сесть и начать играть.

### 5.2 Layout лобби

```
┌──────────────────────────────────────────────┐
│  VIDEO POKER — CLASSIC EDITION               │
│  [Credits: 12,500]         [Settings ⚙]      │
├──────────────────────────────────────────────┤
│                                              │
│   ◄  [ MACHINE ]  [ MACHINE ]  [ MACHINE ]  ►
│      Jacks or     Bonus       Bonus Poker    │
│      Better       Poker       Deluxe         │
│                                              │
│      [PLAY]       [PLAY]      [PLAY]         │
│                                              │
├──────────────────────────────────────────────┤
│  ● ● ● ○ ○ ○ ○ ○ ○ ○   (page dots)         │
│                                              │
│  [FREE CREDITS: 02:34:15]                    │
└──────────────────────────────────────────────┘
```

### 5.3 Визуальный стиль машины в лобби

Каждая машина отображается как стилизованная карточка / миниатюра реальной машины:

| Элемент | Описание |
|---|---|
| **Cabinet art** | Уникальный цвет/тема для каждого варианта (JoB = синий, Deuces = зелёный, Bonus = красный и т.д.) |
| **Название** | Крупным шрифтом сверху машины |
| **Мини-paytable** | 3-4 ключевых строки (Royal Flush, специальные выплаты) — для визуальной разницы |
| **RTP badge** | Маленький бейдж с RTP (например, "99.54%") |
| **Variance indicator** | Визуальная шкала (1-5 точек или звёздочек) |
| **Lock icon** | Если машина ещё не разблокирована (Phase-gated) |
| **PLAY button** | Кнопка "Сесть за машину" |

### 5.4 Цветовая схема машин

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

### 5.5 Навигация и UX

- **Горизонтальный скролл** — свайп влево/вправо между машинами
- **3 машины видно одновременно** (центральная крупнее, боковые меньше — эффект карусели)
- **Тап на машину** — выделяет её, показывает подробности (полная paytable, описание)
- **PLAY** — переход на экран игры (transition: zoom-in в экран машины)
- **Кнопка Back** из игры — zoom-out обратно в лобби
- **Page dots** внизу — индикатор текущей позиции в ряду
- **Баланс** — виден всегда в лобби (общий для всех машин)

### 5.6 Элементы лобби

| Элемент | Описание |
|---|---|
| **Credits display** | Общий баланс игрока (вверху) |
| **Free credits timer** | Таймер до следующей порции бесплатных кредитов |
| **Settings gear** | Переход в настройки (звук, скорость, denomination) |
| **Machine carousel** | Горизонтальная карусель из 10 машин |
| **Machine card** | Визуальная карточка машины с названием, цветом, мини-paytable, RTP |
| **PLAY button** | На каждой карточке машины |
| **Lock overlay** | Затемнение + замок для неразблокированных машин |
| **Info button (i)** | На каждой машине — popup с полной paytable и описанием правил |

### 5.7 Разблокировка машин

По умолчанию доступна только Jacks or Better. Остальные открываются по мере прохождения фаз разработки. В будущем можно добавить игровую прогрессию (открытие за достижения/уровень).

| Разблокировано | Машины |
|---|---|
| Сразу | Jacks or Better |
| Phase 2 | + Bonus Poker, Deuces Wild |
| Phase 3 | + Double Bonus, Double Double Bonus, Joker Poker, Bonus Poker Deluxe |
| Phase 4 | + Triple Double Bonus, Aces and Faces, Deuces and Joker Wild |

### 5.8 Структура сцены лобби (Godot)

```
lobby.tscn
├── Background (TextureRect — тёмный казино-фон)
├── TopBar (HBoxContainer)
│   ├── Title (Label — "VIDEO POKER")
│   ├── CreditsDisplay (Label — LED-style)
│   └── SettingsButton (TextureButton — gear icon)
├── MachineCarousel (ScrollContainer + HBoxContainer)
│   ├── MachineCard_1 (scenes/machine_card.tscn)
│   ├── MachineCard_2
│   ├── ...
│   └── MachineCard_10
├── PageDots (HBoxContainer — индикаторы)
├── FreeCreditsBar (HBoxContainer)
│   ├── TimerIcon
│   └── TimerLabel
└── InfoPopup (PopupPanel — полная paytable при нажатии [i])
```

---

## 6. Приоритет реализации

| Фаза | Варианты | Зависимости |
|---|---|---|
| MVP (Phase 1) | Jacks or Better | Базовый движок, UI, лобби (1 машина) |
| Phase 2 | + Bonus Poker, Deuces Wild | Wild-card evaluator, лобби (3 машины) |
| Phase 3 | + Double Bonus, DDB, Joker Poker, BPD | Kicker logic, 53-card deck, лобби (7 машин) |
| Phase 4 | + Triple Double Bonus, Aces & Faces, Deuces & Joker | 5-wild evaluator, special jackpot, лобби (10 машин) |
| Phase 5 | Multi-hand (Triple/Five/Ten Play) | Multi-hand UI |

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
- **Godot 4.3+** (GDScript основной язык)
- Сборки: Android (APK/AAB), iOS (Xcode export), Windows, macOS, Linux
- Рендерер: **Compatibility** (для максимального охвата устройств, 2D-игра)

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
├── claude.md                    # этот файл
├── scenes/
│   ├── main.tscn                # точка входа
│   ├── lobby/
│   │   ├── lobby.tscn           # зал казино с каруселью машин
│   │   ├── machine_card.tscn    # карточка одной машины в лобби
│   │   └── info_popup.tscn      # popup с полной paytable
│   ├── game.tscn                # основной игровой экран
│   ├── paytable_display.tscn    # компонент paytable
│   ├── card.tscn                # сцена одной карты
│   └── ui/
│       ├── hud.tscn             # credits, bet, win display
│       ├── buttons.tscn         # deal, bet, hold buttons
│       └── win_popup.tscn       # анимация выигрыша
├── scripts/
│   ├── game_manager.gd          # главный контроллер (FSM)
│   ├── lobby_manager.gd         # управление лобби и каруселью
│   ├── machine_card.gd          # логика карточки машины в лобби
│   ├── deck.gd                  # колода, тасовка, раздача
│   ├── hand_evaluator.gd        # оценка покерных комбинаций
│   ├── paytable.gd              # данные paytable, расчёт выплат
│   ├── card.gd                  # логика карты
│   ├── card_visual.gd           # визуализация карты
│   ├── sound_manager.gd         # управление звуками
│   ├── save_manager.gd          # сохранение прогресса
│   ├── denomination.gd          # номиналы ставок
│   └── variants/
│       ├── base_variant.gd      # базовый класс варианта
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
├── assets/
│   ├── cards/                   # спрайты карт (52 + back + joker)
│   ├── sounds/                  # звуковые файлы
│   ├── fonts/                   # LED-шрифт, UI-шрифт
│   ├── themes/                  # Godot Theme resources
│   └── textures/                # фоны, рамки, кнопки
└── data/
    ├── paytables.json           # все таблицы выплат
    └── config.json              # настройки по умолчанию
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

| Настройка | Опции |
|---|---|
| Sound FX | ON / OFF |
| Music | ON / OFF |
| Casino Ambient | ON / OFF |
| Game Speed | Normal / Fast / Turbo |
| Auto Hold hint | ON / OFF (подсказка оптимальных hold) |
| Denomination | Выбор из списка |
| Left/Right Hand Mode | Расположение кнопок (для мобильных) |

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
├── CLAUDE.md                      # Этот документ
├── scenes/
│   ├── main.tscn                  # Точка входа, переключение lobby↔game
│   ├── game.tscn                  # Single-hand игровой экран
│   ├── multi_hand_game.tscn       # Multi-hand игровой экран
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
│   ├── game.gd                    # UI single-hand: FSM, анимации, overlay'и
│   ├── multi_hand_game.gd         # UI multi-hand: N рук, мини-грид
│   ├── game_manager.gd            # FSM single-hand: deal→hold→draw→evaluate
│   ├── multi_hand_manager.gd      # FSM multi-hand: N колод, суммарный payout
│   ├── card_data.gd               # Suit/Rank enum'ы, JOKER поддержка
│   ├── card_visual.gd             # TextureRect с PNG, flip анимации, HELD
│   ├── mini_hand_display.gd       # 5 мини-карт в ряд для multi-hand
│   ├── deck.gd                    # 52/53 карты, Fisher-Yates, multihand draws
│   ├── hand_evaluator.gd          # Стандартные покерные комбинации, hold mask
│   ├── paytable.gd                # Загрузка JSON, lookup по hand_rank
│   ├── paytable_display.gd        # GridContainer с ячейками, подсветка строк
│   ├── lobby_manager.gd           # Grid машин, sidebar режимов, drag-скролл
│   ├── machine_card.gd            # Красная плашка, (i) кнопка, click → play
│   ├── save_manager.gd            # Autoload: credits, denomination, hand_count
│   ├── sound_manager.gd           # Autoload: stub для звуков
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
├── assets/
│   ├── cards/                     # PNG спрайты: card_vp_{rank}{suit}.png
│   ├── textures/                  # SVG кнопки, HELD, MessegBar
│   ├── sounds/                    # (пусто — stub)
│   └── fonts/                     # (пусто — системный шрифт)
└── data/
    ├── paytables.json             # Все 10 таблиц выплат
    └── config.json                # Начальные настройки
```

### Ключевые паттерны

**Variant system:** Каждый вариант покера — отдельный класс, наследующий `BaseVariant`. Переопределяет `evaluate()`, `get_payout()`, `get_hand_name()`. Bonus-варианты различают четвёрки по рангу. Kicker-варианты проверяют 5-ю карту. Wild-варианты имеют полный evaluator с подстановкой wild-карт.

**Paytable-driven payouts:** Все выплаты хранятся в `data/paytables.json`. Variant-скрипты используют строковые ключи (например `"four_aces_with_234_kicker"`) для lookup в paytable, минуя ограничения HandRank enum.

**Scene structure (game screen):**
```
TopSection (VBox, anchor top) — title, paytable, balance/status
MiddleSection (dynamic anchors) — карты (+ мини-руки в multi-hand)
BottomSection (VBox, anchor bottom) — total bet, кнопки, padding
```
MiddleSection позиционируется между Top и Bottom через `_layout_middle()`.

**Multi-hand:** `MultiHandManager` создаёт N-1 дополнительных `Deck` экземпляров. При draw каждая extra рука получает те же held-карты но уникальные replacements из своей колоды.

**Card rendering:** Карты — `TextureRect` с PNG-спрайтами из Figma. Путь: `res://assets/cards/card_vp_{rank}{suit}.png`. Joker: `card_vp_joker_red.png`. Рубашка: `card_back.png`.

**Styling:** Все `theme_override` свойства применяются из GDScript (не из .tscn). Цвета из Figma: фон #000086, текст #FFEC00, кнопки SVG-текстуры.

**Lobby:** Game King стиль — красная top bar, grid 5×2 машин, sidebar с режимами (SINGLE/TRIPLE/FIVE/TEN/12/25 PLAY). Горизонтальный drag-скролл. Каждая машина — PanelContainer с (i) кнопкой для info popup.

### Autoloads

- `SaveManager` — credits, denomination, hand_count, last_variant, settings. Сохраняет в `user://save.json`
- `SoundManager` — stub, методы `play()` / `set_enabled()`

### Как добавить новый вариант покера

1. Создать `scripts/variants/new_variant.gd` — `class_name NewVariant extends BaseVariant`
2. Добавить paytable в `data/paytables.json` с уникальным ID
3. Добавить `match` ветку в `main.gd → _create_variant()`
4. Добавить конфиг в `lobby_manager.gd → MACHINE_CONFIG`

### Как работает multi-hand

1. Игрок выбирает режим в sidebar лобби (3/5/10/12/25 рук)
2. `SaveManager.hand_count` сохраняется
3. `main.gd` загружает `multi_hand_game.tscn` вместо `game.tscn`
4. `MultiHandManager.setup(variant, num_hands)` создаёт N-1 доп. колод
5. Bet = bet × num_hands × denomination
6. Deal: primary hand раздаётся, мини-руки показывают рубашки
7. Hold: игрок выбирает на primary hand
8. Draw: primary рука тянет из своей колоды, каждая extra — из своей
9. Evaluate: все руки оценены, total payout = сумма

### Правила для Claude Code

- **Не коммитить без явного одобрения пользователя**
- Все стили — в GDScript, не в .tscn (Godot 4.6 парсер отвергает `theme_override_`)
- Использовать `load()` вместо `preload()` для сцен (избежать circular dependencies)
- Корневые ноды сцен: `anchors_preset = 15` без `layout_mode`
- Карты: `TextureRect` с `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`
- **Локализация — обязательна для любого нового пользовательского текста.**
  Никаких хардкодов английских/русских/испанских строк в коде или сценах.
  Любая новая надпись (Label, Button, заголовок popup'а, статус, бейдж и т.д.)
  должна:
  1. Получить уникальный ключ в `data/translations.json` (обычно
     `модуль.назначение`, например `lobby.cash`, `game.no_win`, `info.title_single`).
  2. Иметь переводы для **всех** трёх языков: `en`, `ru`, `es`.
  3. Извлекаться через `Translations.tr_key("ключ")` или
     `Translations.tr_key("ключ_fmt", [arg1, arg2])` для строк с `%s` / `%d`.
  4. Не дублировать существующие ключи — сначала проверь
     `data/translations.json`.

  Названия покерных рук должны идти через `Paytable.get_hand_display_name(key)`
  (он сам резолвит `hand.{key}` в Translations). Названия машин — через
  `Translations.tr_key("machine.{id}.name")` / `.mini` / `.feature`.

  Текст в `.tscn` оставляй пустым или нейтральным placeholder'ом — реальное
  значение всегда выставляется из `_ready()` через `Translations.tr_key()`.

  При смене языка через настройки лобби (шестерёнка) `Translations.set_language()`
  вызывает `get_tree().reload_current_scene()`, чтобы все label'ы перестроились.
  Поэтому достаточно один раз вызвать `tr_key` в `_ready()` — не нужно
  пересчитывать строки на лету.
