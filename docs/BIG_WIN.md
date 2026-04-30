# BIG WIN / HUGE WIN Celebration

Ссылка из CLAUDE.md §21.

Полноэкранная победная анимация: вспышки-молнии ×4, затемнение, title-картинка
с паттерном-подложкой, glyph-счётчик 0 → payout за 4с, дождь монет и конфетти,
«tap to continue…». По тапу закрывается.

## Autoload `BigWinOverlay`

`scripts/big_win_overlay.gd` — autoload. Любой игровой экран вызывает:

```gdscript
BigWinOverlay.show_if_qualifies(self, payout, total_bet)
```

- `self` — host Control, куда парентится overlay
- `payout` — полный выигрыш (с denomination)
- `total_bet` — полная ставка раунда

Проверяет `ConfigManager.classify_big_win(payout, total_bet)`:
- `"none"` → выход
- `"big"` / `"huge"` → показывается title-картинка

`BigWinOverlay.show_win(host, amount, level)` — force-show для debug.

## Классификатор порогов

`configs/balance.json`:

```json
"big_win_thresholds": {
  "big_win": {"min": 4, "max": 7},
  "huge_win": {"min": 8}
}
```

`mult = payout / total_bet`:
- `[4, 7]` → `"big"`
- `≥ 8` → `"huge"`
- иначе → `"none"`

`ConfigManager.classify_big_win(payout, bet)`. Ставка должна быть полной
(не «на руку») — это спасает multi-hand от частых срабатываний.

## Подключение

**Single-hand** (`scripts/game.gd` → `_on_hand_evaluated`):
```gdscript
var total_bet: int = _game_manager.bet * SaveManager.denomination
BigWinOverlay.show_if_qualifies(self, payout, total_bet)
```

**Multi-hand + Ultra VP** (`scripts/multi_hand_game.gd` → `_on_hands_evaluated`):
```gdscript
var total_bet: int = _manager.bet * _num_hands * SaveManager.denomination
BigWinOverlay.show_if_qualifies(self, total_payout, total_bet)
```
Ultra VP не нуждается в доп. множителе — `bet=10` уже представляет удвоенную стоимость.

**Spin Poker** (`scripts/spin_poker_game.gd` → `_on_lines_evaluated`):
```gdscript
BigWinOverlay.show_if_qualifies(self, total_payout, _manager.get_total_bet())
```
`get_total_bet()` = `NUM_LINES * bet * denomination`.

## Почему total, а не per-hand

Per-hand слишком часто срабатывал бы на мелких выигрышах. Свёртка в
`total_payout / total_bet`:
- требует чтобы сумма всех payout'ов была большим множителем общей ставки
- натурально редка без реальной крупной комбинации (Flush+, Royal, 4oaK)
- одинаково работает на всех режимах

## Debug cheat

`scripts/game.gd` → `_add_debug_flash_button` — две временные кнопки
**BIG WIN** / **HUGE WIN** в верхнем левом углу. Удалить после тестов
(блок помечен `# TEMP DEBUG`).

## Ассеты

- `assets/big_win/big_win.png` — title для `"big"`
- `assets/big_win/huge_win.png` — title для `"huge"`
- `assets/big_win/big_win_pattern.png` — подложка
- `assets/big_win/glyphs_big_win/` — отдельный набор глифов
  (`glyph_0..9`, `glyph_chip`, `glyph_comma`, `glyph_dot`, `glyph_K`, `glyph_M`)
