# Machines Reference — 10 Variants

Полные paytable, RTP, variance и сложность стратегии для всех 10 вариантов.
Ссылка из CLAUDE.md §4. Сами paytable в рантайме читаются из
`data/paytables.json`.

---

## 1. Jacks or Better
Базовая и самая популярная вариация. Колода: 52. Wild: нет. Мин. комбинация: пара Вальтов+.

**9/6 Full Pay (за 1 / за 5 монет):**

| Комбинация | 1 | 2 | 3 | 4 | 5 |
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

RTP: 99.54% | Variance: Low (σ = 4.42) | Стратегия: Низкая

---

## 2. Bonus Poker
То же что JoB, но увеличенные выплаты за Four of a Kind по рангу.

**8/5 Full Pay (за 1 монету):**

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5) |
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

RTP: 99.17% | Variance: Low

---

## 3. Bonus Poker Deluxe
Все четвёрки = 80, но Two Pair = 1.

**9/6 Full Pay:** Royal 250/800, SF 50, 4oaK 80, FH 9, Flush 6, Straight 4, 3oaK 3, 2P 1, JJ 1.
RTP: 99.64% | Variance: Medium

---

## 4. Double Bonus Poker
Удвоенные четвёрки. Two Pair = 1.

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5) |
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

RTP: 100.17% | Variance: Medium-High

---

## 5. Double Double Bonus Poker
Бонусы за четвёрки + кикер.

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5) |
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

RTP: 100.07% | Variance: High

---

## 6. Triple Double Bonus Poker
Экстремальные бонусы. 4 Aces + 2/3/4 = 800 × 5 = 4000 при Max Bet.

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5) |
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

RTP: 99.58% | Variance: Very High

---

## 7. Aces and Faces
Бонусные четвёрки — Aces и Face cards (J/Q/K).

| Комбинация | Выплата |
|---|---|
| Royal Flush | 250 (800 при 5) |
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

RTP: 99.26% | Variance: Low-Medium

---

## 8. Deuces Wild
Все четыре двойки — wild. Мин. комбинация: 3oaK.

**NSUD Paytable:**

| Комбинация | Выплата |
|---|---|
| Natural Royal Flush | 250 (800 при 5) |
| 4 Deuces | 200 |
| Wild Royal Flush | 25 |
| 5 of a Kind | 15 |
| Straight Flush | 9 |
| Four of a Kind | 4 |
| Full House | 4 |
| Flush | 3 |
| Straight | 2 |
| Three of a Kind | 1 |

RTP: 99.73% (NSUD) | Variance: Low | Стратегия: Высокая

---

## 9. Joker Poker (Kings or Better)
Колода 53 карты (52 + Joker). Мин. комбинация: пара Королей+.

| Комбинация | Выплата |
|---|---|
| Natural Royal Flush | 250 (800 при 5) |
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

RTP: 100.65% | Variance: Low-Medium | Стратегия: Очень высокая

---

## 10. Deuces and Joker Wild
Колода 53. Wild: 5 (4 двойки + Joker). Джекпот: 4 Deuces + Joker — 10,000 при Max Bet.

| Комбинация | 1 | 2 | 3 | 4 | 5 |
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

**Особенности:** при ставке < 5 монет — 4 Deuces + Joker оплачивается как 5oaK (9). Только при Max Bet — 10,000.
RTP: 99.07% | Variance: Medium-High

**Реализация:**
- Колода 53 карты (Joker sprite)
- Hand evaluator с 5 wild-картами
- Спец. проверка: рука = все 5 wilds + bet=5 → 10,000

---

## Сводная таблица

| # | Машина | Колода | Wild | Мин. рука | RTP | Variance |
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
