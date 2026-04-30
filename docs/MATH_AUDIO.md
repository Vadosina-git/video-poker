# Math, Audio & Animation Spec

Ссылка из CLAUDE.md §8, §9, §10.

---

## Колода и рандом

- 52 карты (54 для Joker Poker)
- Fisher-Yates shuffle перед каждой раздачей
- Раздача: первые 5 — рука, позиции 6–10 — потенциальные замены
- При draw карта на позиции `i` заменяется картой на `i+5`
- Реплика регулируемых машин Невады

## Hand Evaluation (порядок)

1. Royal Flush — A K Q J 10 одной масти
2. Straight Flush — 5 подряд одной масти
3. Four of a Kind
4. Full House — 3oaK + Pair
5. Flush
6. Straight (A может быть high или low)
7. Three of a Kind
8. Two Pair
9. Jacks or Better
10. Nothing

Wild-варианты — доп. логика с wild-картами.

## Псевдокод evaluator

```gdscript
func evaluate(hand: Array[CardData]) -> String:
    var is_flush = all_same_suit(hand)
    var is_straight = is_consecutive(hand)
    var groups = group_by_rank(hand)
    var counts = groups.values().sorted().reversed()
    if is_flush and is_straight:
        if min_rank(hand) == 10: return "ROYAL_FLUSH"
        return "STRAIGHT_FLUSH"
    if counts[0] == 4: return "FOUR_OF_A_KIND"
    if counts[0] == 3 and counts[1] == 2: return "FULL_HOUSE"
    if is_flush: return "FLUSH"
    if is_straight: return "STRAIGHT"
    if counts[0] == 3: return "THREE_OF_A_KIND"
    if counts[0] == 2 and counts[1] == 2: return "TWO_PAIR"
    if counts[0] == 2:
        var pair_rank = get_pair_rank(groups)
        if pair_rank >= 11: return "JACKS_OR_BETTER"
    return "NOTHING"
```

## Deck (псевдокод)

```gdscript
var cards: Array[int] = range(52)
func shuffle():
    for i in range(51, 0, -1):
        var j = randi() % (i + 1)
        var temp = cards[i]; cards[i] = cards[j]; cards[j] = temp
func deal_hand() -> Array: shuffle(); return cards.slice(0, 5)
func get_replacement(position: int) -> int: return cards[5 + position]
```

## Card data

```gdscript
class_name CardData
var suit: int    # 0=Hearts, 1=Diamonds, 2=Clubs, 3=Spades
var rank: int    # 2-14 (14=A)
var index: int   # 0–51 (suit*13 + rank-2)
```

## Частоты (9/6 JoB, оптимальная стратегия)

| Комбинация | Частота | % рук |
|---|---|---|
| Royal Flush | 1 / ~40,391 | 0.0025% |
| Straight Flush | 1 / ~9,148 | 0.011% |
| Four of a Kind | 1 / ~423 | 0.24% |
| Full House | 1 / ~87 | 1.15% |
| Flush | 1 / ~91 | 1.10% |
| Straight | 1 / ~89 | 1.12% |
| Three of a Kind | 1 / ~13 | 7.44% |
| Two Pair | 1 / ~8 | 12.93% |
| Jacks or Better | 1 / ~5 | 21.46% |
| Nothing | — | 54.54% |

---

## Звуки машины

| Событие | Звук |
|---|---|
| Coin insert / Bet | Металлический щелчок |
| Deal | Шелест карт |
| Card flip (Draw) | Щелчок |
| Hold toggle | Click/beep |
| Win (малый) | Мелодия + звон |
| Win (средний) | Длиннее мелодия |
| Win (Royal Flush) | Фанфары + джекпот |
| No win | Тишина / "whomp" |
| Button press | Механический щелчок |

## Амбиент
- Опционально фоновый шум казино
- ON/OFF в настройках, по умолчанию OFF

---

## Анимации

| Элемент | Анимация |
|---|---|
| Deal | Карты слева направо (~100ms между) |
| Hold | Карта поднимается + "HELD" |
| Draw | Перевороты / замены |
| Win | Подсветка карт + paytable строка пульсирует + Win counter |
| Royal Flush | Спец. анимация (вспышки, частицы) |
| Credits counter | Roll-up/roll-down |
| Paytable highlight | Столбец текущей ставки + строка при выигрыше |

---

## Конфигурируемые параметры (configs/balance.json + др.)

| Параметр | Дефолт | Описание |
|---|---|---|
| `starting_credits` | 1000 | Стартовый баланс |
| `free_credits_amount` | 500 | Подарок |
| `free_credits_interval_hours` | 2 | Интервал |
| `deal_speed_ms` | 100 | Задержка между картами |
| `draw_speed_ms` | 150 | Задержка замены |
| `win_counter_speed` | 0.02 | Скорость подсчёта |
| `denominations` | [1,5,25,100,500] | Номиналы |
| `default_denomination` | 1 | По умолчанию |
| `auto_hold` | false | Автохолд |
| `speed_mode` | false | Ускоренная игра |

Полный справочник — `docs/CONFIG_REFERENCE.md`.
