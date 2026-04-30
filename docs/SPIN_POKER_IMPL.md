# Spin Poker — Reels & Shutters Implementation

Ссылка из CLAUDE.md §19. Детальная техническая реализация барабанов и шторок Spin Poker.

## Архитектура рилов

Каждый из 5 столбцов — «барабан» (reel). Визуально 3 ячейки
(`_card_rects[row][col]`, row 0/1/2 = top/mid/bot) из GridContainer.
Верхний и нижний ряды закрываются **шторками** — persistent `TextureRect`
с текстурой `card_back_spin.svg`, поверх ячеек (z_index=3). Шторки
создаются один раз в `_build_persistent_shutters()`. Массив:
`_col_shutters[col] = {top: TextureRect, bot: TextureRect, open: bool}`.

**Важно: под шторками всегда лицевые карты, никогда не card_back.**
При первом запуске — случайные (`_init_shutters_closed`). При последующих
раундах — карты остаются от предыдущего результата. `_set_card_back()` не
вызывается для строк 0 и 2.

## Анимация барабанов (reel spin)

`Control` с `clip_contents=true` поверх ячеек (z_index=20). Внутри —
plain `Control` (strip) с дочерними `TextureRect`, расположенными вручную:
`tex.position = Vector2(0, ch*i)` и `tex.size = Vector2(cw, ch)`.

**Не VBoxContainer** — он перезаписывает position при layout.

Анимация: `strip.position.y` через Timer. Перед стартом —
`await get_tree().process_frame × 2` чтобы clip получил ненулевой size.

### Структура strip
`[prev_card(s)] [filler×N] [filler×N copy] [target(s)]`
- Первая карта(ы) = текущие на экране
- Филлеры удвоены для бесшовной зацикленной прокрутки
- Последняя карта(ы) = целевые
- `strip.position.y = -fmod(offset, loop_h)` где `loop_h = cell_h × filler_count`

### Разгон/торможение
Скорость от 0 до max за ~0.5с (квадратичный ease-in: `speed = max_speed × t²`).
Торможение: Tween `EASE_OUT + TRANS_QUAD` + bounce (~5px).

## Сценарий DEAL/SPIN

1. Шторки закрываются анимированно
2. Под шторками и в среднем ряду — карты прошлого раунда
3. Strip среднего ряда начинается с предыдущей карты (`cell.texture`)
4. Барабаны крутятся через окно среднего ряда (clip = 1 cell tall)
5. Остановка слева направо с задержкой между столбцами

## Сценарий HOLD

- Холд: `_animate_shutter_open(col)` — шторки раздвигаются, показывая ту же карту в top/bottom
- Снятие холда: `_animate_shutter_close(col)` — шторки закрываются

## Сценарий DRAW

1. Шторки нехолденных столбцов открываются (0.25с)
2. Strip 3 ряда начинается с текущих 3 карт
3. Барабаны крутятся через все 3 ряда (clip = 3 cells tall)
4. Остановка слева направо

## `_rush` механика

Тап во время вращения → `_rush = true`, барабаны мгновенно показывают цели.
Защита: `_spin_started_frame` предотвращает rush от того же клика.
`_rush` сбрасывается в `_on_deal_spin_complete` и `_on_draw_spin_complete`.

## Скорости

`SPEED_CONFIGS[0..3]` — четыре уровня. При MAX (level 3) `base_spin_ms=0` →
анимация пропускается полностью.

## Card rendering

Обычные карты — `TextureRect` с PNG-спрайтами. Путь
`res://assets/cards/card_vp_{rank}{suit}.png`. Joker:
`card_vp_joker_red.png`. Рубашка: `card_back.png`. Spin Poker — квадратные
SVG из `assets/cards/cards_spin/`.

## Styling

Все `theme_override` свойства применяются из GDScript (не из `.tscn`).
Цвета: фон `#000086`, акцент `#FFEC00`, кнопки — SVG-текстуры.
