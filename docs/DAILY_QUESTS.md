# Daily Quests — система ежедневных заданий

Игроку каждый день выдаётся 4 случайных задания из пула. У каждого
задания — описание, награда в монетах, кнопка с тремя статусами
(GO / CLAIM / CLAIMED). Прогресс трекается во время игры
независимо от того, открыт ли попап. Сброс — на локальной полуночи
устройства, невыполненные задания пропадают.

Иконка входа — в верхнем меню лобби рядом со store. Над любой
сценой в момент прогресса показывается язычок-баннер; тап на
баннер открывает попап квестов поверх текущей сцены.

---

## 1. Архитектурная карта

| Компонент | Файл | Тип | Ответственность |
|---|---|---|---|
| `DailyQuestManager` | `scripts/daily_quest_manager.gd` | autoload Node | Lifecycle: ролл, прогресс-матчеры, claim, signals. Хук на game-менеджеры через `attach_to_game`. |
| `QuestBannerOverlay` | `scripts/quest_banner_overlay.gd` | autoload CanvasLayer (layer 150) | Слайд-баннер сверху при `quest_progress_updated`. Очередь баннеров с merge-on-same-qid. Тап → emit `banner_tapped`. |
| `QuestPopupOverlay` | `scripts/quest_popup_overlay.gd` | autoload CanvasLayer (layer 120) | Окно списка заданий. Открывается над любой сценой. Содержит UI builder + GO/CLAIM флоу. |
| `lobby_manager.gd` | (часть лобби) | — | Иконка quests в top-bar + красный badge. Вызывает `QuestPopupOverlay.show_popup()`. |
| `main.gd` | — | — | Маршрутизатор: `banner_tapped` → открыть попап; `go_requested(variant_id, mode)` → загрузка машины. |
| `configs/daily_quests.json` | — | данные | Пул шаблонов квестов + `picks_per_day`. |
| `SaveManager.daily_quest_state` | `scripts/save_manager.gd` | persistent state | `{date_iso, active: [{quest_id, progress, claimed, machines_seen?}]}`. |

**Порядок autoload в `project.godot`:** ConfigManager → SaveManager →
**DailyQuestManager** → ... → BigWinOverlay → **QuestBannerOverlay**
→ **QuestPopupOverlay** → ... → ThemeManager.

---

## 2. Жизненный цикл

### 2.1 Старт сессии

`DailyQuestManager._ready()` → `_ensure_today_rolled()`:
- читает `SaveManager.daily_quest_state.date_iso`
- сравнивает с локальной датой (`Time.get_datetime_dict_from_system`)
- не совпала → `_roll_new_quests()` (см. 2.2)

### 2.2 Ежедневный ролл

`_roll_new_quests`:
1. Берёт `ConfigManager.get_daily_quest_pool()`.
2. Фильтрует по `enabled=true`.
3. Перемешивает (`shuffle()`), берёт `picks_per_day` (default 4).
4. Для каждого создаёт entry `{quest_id, progress: 0, claimed: false}`.
5. Для типа `play_different_machines` добавляет `machines_seen: []`.
6. Пишет `SaveManager.set_daily_quest_state({date_iso, active})`.
7. Эмитит `quests_rolled`.

**Важно:** anti-cheat против перевода системных часов отсутствует
(совпадает с поведением daily gift). Перевод часов вперёд = новый
ролл, старые невыполненные пропадают. Перевод назад = бесконечный
текущий день.

### 2.3 Хук на game-сцены

`main.gd._load_game_scene` после создания сцены вызывает
`DailyQuestManager.attach_to_game(scene, variant_id, mode)`. Менеджер:
1. Находит game-manager среди детей сцены (имеет один из сигналов
   `hand_evaluated` / `all_hands_evaluated` / `lines_evaluated`).
2. Подключается к нужному сигналу.
3. Хранит `_attached_manager`, `_attached_variant_id`, `_attached_mode`.

`_show_lobby` вызывает `detach_from_game()` — отписка от сигналов.

### 2.4 Прогресс одного раунда

При сигнале от game-manager'а вызывается `_on_round_complete(results, total_bet_coins)`:
1. Итерирует все active quest entries.
2. Для каждого проверяет `_passes_filters(cfg)` — фильтр по
   `machines[]` и `modes[]` (пустые = любые).
3. `_match_and_advance(cfg, entry, results, total_bet_coins)` —
   switch по `quest.type` инкрементирует прогресс.
4. На каждое изменение `progress` эмитит
   `quest_progress_updated(qid, progress, target)`.
5. Если перешли через `target` → `quest_completed(qid)`.
6. Сохраняет `SaveManager.set_daily_quest_state(state)`.

### 2.5 Claim

`DailyQuestManager.claim_reward(quest_id)`:
1. Проверяет `claimed == false` и `progress >= target`.
2. **Сначала** ставит `claimed = true` (защита от двойного клика —
   повторный вызов идемпотентен, возвращает 0).
3. Сохраняет state.
4. Вызывает `SaveManager.add_credits(reward)`.
5. Эмитит `quest_claimed(qid, reward)`.

---

## 3. Типы заданий

7 типов. Все живут в одном `match` внутри `_match_and_advance`.

| `type` | Подсчёт | Доп. поля |
|---|---|---|
| `play_hands` | +1 за раунд (multi/spin: +N за N рук в раунде через `results.size()`) | — |
| `win_hands` | +1 за каждую руку с `payout > 0` | — |
| `collect_combo` | +1 за руку, чей `hand_rank == quest.hand_rank` | `hand_rank` (string из enum) |
| `accumulate_winnings` | +`payout` за каждую выигрышную руку | — |
| `score_specific_hand` | binary: при первом совпадении `progress = target` | `hand_rank` |
| `total_bet` | +`bet * denom * hand_count` за раунд | — |
| `play_different_machines` | +1 за каждый новый (за день) variant_id; sidecar set `machines_seen` | — |

**`hand_rank`** — строка-имя из `HandEvaluator.HandRank`:
NOTHING / JACKS_OR_BETTER / TWO_PAIR / THREE_OF_A_KIND / STRAIGHT /
FLUSH / FULL_HOUSE / FOUR_OF_A_KIND / STRAIGHT_FLUSH / ROYAL_FLUSH.

Маппинг строки в int — таблица `_HAND_RANK_BY_NAME` в
`daily_quest_manager.gd`.

---

## 4. Фильтры по машине / режиму

Каждый квест имеет два массива:
- `machines: []` — список variant_id. Пусто = любая машина.
- `modes: []` — список mode_id (single_play / triple_play / five_play /
  ten_play / ultra_vp / spin_poker). Пусто = любой режим.

Применяется AND'ом: прогресс идёт только если текущая машина
**и** режим попадают в фильтры (или фильтр пустой).

Список mode_id — см. `lobby_order.json` или `MODE_HANDS` в `lobby_manager.gd`.

---

## 5. Пул заданий: формат

Файл: `configs/daily_quests.json`. Подробное описание полей —
[`docs/CONFIG_REFERENCE.md`](CONFIG_REFERENCE.md) §12.

Пример:
```json
{
  "id": "win_5_hands_in_ultra",
  "type": "win_hands",
  "target": 5,
  "reward": 24000,
  "machines": [],
  "modes": ["ultra_vp"],
  "enabled": true
}
```

Текущий пул — 28 квестов: 4 простых (play/win × N), 6 средних
(collect combo × N), 3 трофейных (Royal/Straight Flush, 4oaK один
раз), 4 экономических (total_bet, accumulate winnings), 1 discovery
(`play_different_machines`), 4 cross-mode только-multi/ultra,
4 машина+режим узких.

**Правило rewards:** награды масштабируются от стартового баланса
(20 000) и средней ставки. На `bet=5 × denom=10 = 50` за раунд:
- Простой квест (10 раздач) ≈ 4,800 монет (≈ 10 раундов выплаты).
- Сложный (Royal Flush один раз) ≈ 60,000 монет (≈ Royal × MaxBet).
- Композитный (Royal в Ultra VP × Jacks) ≈ 120,000 монет (jackpot).

При балансировке держи отношение `reward / target_bet_volume` ~0.5–2.0.

---

## 6. Remote Config

`daily_quests` есть в `ConfigManager._REMOTE_OVERRIDABLE`. Firebase
может переопределять весь словарь (deep-merge). Полезно: тюнинг
наград, добавление сезонных квестов, kill-switch отдельных квестов
через `enabled=false` без релиза.

**НЕ публикуй в Remote Config:**
- Любые квесты с paytables-зависимыми условиями (RTP-ломкое).
- IAP product_id, jackpot multipliers (см. правило в
  [`docs/REMOTE_CONFIG.md`](REMOTE_CONFIG.md)).

---

## 7. UI компоненты

### 7.1 Иконка в top-bar (лобби)

`lobby_manager._make_top_icon_btn("quests", ...)` рядом с store.
Бейдж-кружок (`_quests_badge_node`) — отдельный child Control,
добавлен ПОСЛЕ TextureRect иконки (рендерится поверх; см. PAIN_LOG
2026-05-07 про draw-order). Видимость — `DailyQuestManager.has_claimable()`,
обновляется на сигналах `quest_completed` / `quest_claimed` /
`quests_rolled`.

### 7.2 Баннер прогресса (любая сцена)

`QuestBannerOverlay`. Слайд-полоска шириной 1/3 экрана, anchor
top-center. Показывает заголовок квеста, прогресс-бар с
анимированным fill (prev → curr) и цифрой "N / M" в lockstep.
`+N` floating-метка в центре бара.

**Очередь:**
- Тот же квест что показан → продолжает анимировать ту же полоску.
- Тот же квест что в очереди → обновляет финальное значение,
  записи не плодит.
- Другой квест, баннер занят / fading → enqueue.

Тап на баннер → emit `banner_tapped` → `main.gd` →
`QuestPopupOverlay.show_popup()`.

### 7.3 Попап (любая сцена)

`QuestPopupOverlay`. CanvasLayer 120 — рендерится над лобби и над
game-сценами. Содержит:
- Заголовок + countdown до полуночи (Timer 1с обновляет lable).
- Скролл-список карточек (по одной на active quest).
- Кнопка CLOSE.

**Карточка** (`_build_card`):
- Цветная вертикальная полоса слева (per-type accent).
- Иконка-диск с clipboard SVG.
- Title (RichTextLabel + BBCode) — описание + green-highlighted
  machine/mode, если есть.
- Reward pill — жёлтая капсула с chip-glyph + сумма (через
  `SaveManager.create_currency_display`).
- Прогресс-бар (18px, accent-filled) + "N/M" лейбл.
- Кнопка GO/CLAIM/CLAIMED — белый текст во всех состояниях, 3D-стиль
  (border_bottom thicker = "lip", pressed-state collapses lip).

### 7.4 GO action

Резолюция таргета:
1. `DailyQuestManager.get_navigation_target(qid)` — `(machines[0], modes[0])`.
2. Если variant пуст → fallback `SaveManager.last_variant`.
3. Если и last_variant пуст → `"jacks_or_better"` + force `single_play`.

Эмит `go_requested(variant_id, mode)`. `main.gd._on_quest_go_requested`:
- Same-machine short-circuit: если игрок уже за этой машиной/режимом,
  просто закрывает попап.
- Иначе применяет mode (mutate SaveManager.hand_count/ultra_vp/spin_poker)
  + last_variant + save_game.
- Вызывает `_on_machine_selected(variant_id)` (тот же loader-pipeline
  что и при тапе на машину в лобби).

### 7.5 CLAIM action

Two paths по типу сцены:
- **Лобби:** `lobby._spawn_chip_cascade(from_pos, old, new, self)` —
  фишки летят на cash pill, пилюля анимируется автоматически.
  Передаём `self` (popup CanvasLayer 120) как chip_parent чтобы
  фишки рендерились над попапом.
- **Game scene:** `_spawn_quest_cascade_self(from_pos)` — собственная
  cascade, target = `_balance_cd["box"]` (multi/spin/ultra) или
  `_balance_label` (single). Затем `DailyQuestManager.notify_credits_changed()`
  переэмитит `credits_changed` на attached game-manager → балансовый
  лейбл сцены обновится.

Попап остаётся открытым, чтобы можно было клеймить остальные квесты.

---

## 8. Локализация

Все строки в `data/translations.json`. Префиксы:
- `lobby.quests` — лейбл иконки top-bar.
- `quests.title` / `quests.time_to_reset_fmt` / `quests.empty` —
  заголовок попапа, countdown, плейсхолдер пустого списка.
- `quest.btn.go/claim/claimed` — лейблы кнопок.
- `quest.banner.label` — "QUEST PROGRESS" над баннером.
- `quest.desc.{type}` — описание для каждого из 7 типов с placeholder'ами.
- `quest.suffix_fmt = "(%s)"` — обёртка suffix'а с machines/modes.

Имена машин в supercell-сеттинге переопределяет `ThemeManager.machine_title()`
(`"JOKER\nDRAW"` вместо `"Joker Poker"`). `_machine_display_name`
плющит `\n` в пробел для inline-использования.

---

## 9. Добавление нового квеста

1. Открой `configs/daily_quests.json`.
2. Добавь entry в `pool[]`:
   ```json
   {
     "id": "уникальный_snake_case_id",
     "type": "один_из_7_типов",
     "target": число,
     "reward": число_монет,
     "machines": ["variant_id", ...],   // или []
     "modes": ["mode_id", ...],          // или []
     "hand_rank": "ROYAL_FLUSH",         // только для collect_combo / score_specific_hand
     "enabled": true
   }
   ```
3. Перезапусти игру (или удали `user://save.json` для гарантированного
   ролла на чистом state).
4. Проверь что описание читаемо в попапе. Если квест сложного
   типа без существующего перевода — добавь `quest.desc.{newtype}`
   во все три языка.

**Нельзя:** добавить новый `type` без обновления `_match_and_advance`
в `daily_quest_manager.gd` + соответствующего перевода.

---

## 10. Edge-кейсы

- **Двойной клик CLAIM** — `claim_reward` идемпотентен (claimed
  ставится ДО выдачи).
- **Quest_id в save отсутствует в актуальном конфиге** — `get_active_quests`
  фильтрует через `_pool_index`, не падает.
- **Перевод часов назад** — date_iso тот же, прогресс продолжается.
  Допустимо (как у daily gift).
- **Перевод часов вперёд** — date_iso меняется, ролл фрэш, старые
  невыполненные пропадают.
- **Закрытие приложения посреди раунда** — каждый инкремент пишет
  через `SaveManager.set_daily_quest_state` → save_game. Прогресс
  не теряется.
- **Пустой пул в Remote Config** — `_roll_new_quests` безопасно делает
  slice (mini'ит до доступного размера). UI рендерит "no quests available"
  из `quests.empty` translation.

---

## 11. Связанные документы

- [`docs/CONFIG_REFERENCE.md`](CONFIG_REFERENCE.md) §12 — формат `daily_quests.json`.
- [`docs/REMOTE_CONFIG.md`](REMOTE_CONFIG.md) — что можно / нельзя
  публиковать в Firebase.
- [`docs/PAIN_LOG.md`](PAIN_LOG.md) — `chip_parent` injection, draw-order
  overlay paterns (релевантно для UI квестов).
- `CLAUDE.md` §6 — таблица autoloads.
