# Roadmap & Phase History

Ссылка из CLAUDE.md §6, §16.

## Статус фаз

| Фаза | Статус | Состав |
|---|---|---|
| Phase 1 — MVP | ✅ done | Jacks or Better, базовый движок, single-hand, лобби |
| Phase 2 — Wild + 3 машины | ✅ done | Bonus Poker, Deuces Wild, лобби на 3 машины |
| Phase 3 — Kicker + 7 машин | ✅ done | BPD, Double Bonus, DDB, Joker Poker (53-card) |
| Phase 4 — Полный набор 10 | ✅ done | Triple Double Bonus, Aces & Faces, Deuces & Joker |
| Phase 5 — Multi-hand | ✅ done | Triple/Five/Ten/12/25 play |
| Ultra VP | ✅ done | Per-hand множители, 5-hand layout, glyph-анимация |
| Spin Poker | ✅ done | 3×5 reel grid slot-style |
| Double or Nothing | ✅ done | Риск-раунд после выигрыша |
| In-game shop (stub) | ✅ done | Top-up, фиктивные покупки FREE |
| Локализация EN/RU/ES | ✅ done | См. CLAUDE.md §20 |
| Phase 6 — Social & Monetization | ⏳ TODO | Аккаунты, leaderboards, IAP, achievements, push |

## Детальный roadmap по фазам (исторически)

### Phase 1 — MVP
- Базовая структура Godot
- Лобби с 1 машиной + карусель
- Deck, shuffle, deal, draw
- Hand Evaluator (JoB)
- Paytable display 9/6 JoB
- FSM full game loop
- UI карты/кнопки/displays
- Hold toggle
- Базовые звуки/анимации
- Win display + paytable highlight
- Save/Load credits
- Desktop build

### Phase 2 — Wild + 3 машины
- Bonus Poker variant
- Deuces Wild variant
- 3 машины в лобби
- Переход лобби↔машина (zoom)
- Denomination selector
- Free credits timer
- Casino ambient
- Mobile portrait
- Android build

### Phase 3 — Kicker + 7 машин
- Bonus Poker Deluxe
- Double Bonus, Double Double Bonus (kicker)
- Joker Poker (53-card)
- 7 машин с уникальными цветами
- Info popup с paytable
- Royal Flush celebration
- Statistics screen
- iOS build

### Phase 4 — Полный набор 10
- Triple Double Bonus (extreme kicker)
- Aces and Faces
- Deuces and Joker Wild (5-wild evaluator, 10,000 jackpot)
- Configurable paytables (JSON)
- Разблокировка машин (progression)

### Phase 5 — Multi-Hand
- Triple/Five/Ten Play Draw Poker
- UI адаптация

### Phase 6 — Social & Monetization (TODO)
- Аккаунты / авторизация
- Leaderboards
- Daily bonuses
- IAP (покупка кредитов)
- Achievements
- Push notifications
