# Video Poker — Checklist доработок
## По документу Video_Poker_improvements_13_04_2026.md

---

| # | Задача | Было | Что изменилось | Стало | Где проверить |
|---|---|---|---|---|---|
| 1 | ConfigManager autoload (A.0) | Конфиги не существовали, всё хардкод | Создан `scripts/config_manager.gd` autoload, загружает 9 JSON при старте | ConfigManager доступен глобально, fallback на defaults если JSON нет | project.godot → autoload, scripts/config_manager.gd |
| 2 | machines.json + paytable rebuild (A.4) | Paytable читал из `data/paytables.json` плоским форматом | `configs/machines.json` с новым форматом (hands[], label_key, ultra_multipliers). paytable.gd переписан | paytable.gd читает из ConfigManager, fallback на legacy файл | configs/machines.json, scripts/paytable.gd → `_load_from_machines()` |
| 3 | lobby_order.json (A.1) | Порядок режимов и машин хардкод в lobby_manager.gd | Создан `configs/lobby_order.json` с 6 режимами и машинами на каждый | Конфиг задаёт структуру лобби | configs/lobby_order.json |
| 4 | balance.json → BET_AMOUNTS (A.3) | `const BET_AMOUNTS = [1,2,4,8,16,32,64,128,256,512,1024,2048]` хардкод | `configs/balance.json` с denominations per mode. Все 3 game scripts читают через `ConfigManager.get_denominations(mode_id)` | Single: [1,2,5,10,25,50,100], Triple: [1,2,5,10,25], и т.д. | configs/balance.json, game.gd/multi_hand_game.gd/spin_poker_game.gd → `_ready()` |
| 5 | init_config.json (A.2) | Стартовый баланс 1000 хардкод в SaveManager | `configs/init_config.json`: starting_balance=20000 | При удалении аккаунта → 20000 кредитов | configs/init_config.json, lobby_manager.gd → `_perform_account_delete()` |
| 6 | shop.json + bonus chips (A.5) | `SHOP_AMOUNTS = [100,500,2500,10000,50000,100000]` хардкод | `configs/shop.json` с 5 IAP пакетами (chips + bonus_chips + badges). Game scripts читают через ConfigManager | Магазин читает пакеты из конфига | configs/shop.json, game.gd → `_build_shop_amounts()` |
| 7 | gift.json + Gift feature (A.6, D) | Подарки не существовали | `configs/gift.json` (2ч, 500 фишек). Лобби: зелёная кнопка CLAIM GIFT с таймером HH:MM:SS | Кнопка в top bar лобби, обратный отсчёт, клейм + анимация | configs/gift.json, lobby_manager.gd → `_build_gift_widget()`, `_on_gift_pressed()` |
| 8 | sounds.json + placeholder (A.7, K.2) | SoundManager stub, нет файлов | `configs/sounds.json` маппинг 21 событие→файл. 22 silent .mp3 в assets/sounds/ | Файлы на месте, замените на реальные звуки | configs/sounds.json, assets/sounds/*.mp3 |
| 9 | animations.json (A.8) | Все тайминги хардкод | `configs/animations.json` с 19 параметрами | Тайминги конфигурируемы без изменения кода | configs/animations.json |
| 10 | ui_config.json (A.9) | UI параметры хардкод | `configs/ui_config.json`: font sizes, colors, paddings | UI настройки конфигурируемы | configs/ui_config.json |
| 11 | Аудит хардкода spin poker (E.3) | Все строки в spin_poker_game.gd хардкод ("PLACE YOUR BET", "GAME OVER" и т.д.) | 17 строк заменены на `Translations.tr_key()` | Все UI-тексты локализованы. DEAL/DRAW/SPIN остались на EN | spin_poker_game.gd — поиск `tr_key` |
| 12 | Переменные в строках (E.4) | Уже работало через `tr_key("key_fmt", [args])` | Проверено, новые ключи используют `_fmt` суффикс и `%s`/`%d` | Все переменные строки через _fmt | data/translations.json — поиск `_fmt` |
| 13 | RichText BBCode (E.5) | Правила в popup — обычный Label | game.gd и multi_hand_game.gd: RichTextLabel с bbcode_enabled=true | Ключевые слова выделены жёлтым/зелёным цветом | game.gd → `_show_info()`, multi_hand_game.gd → `_show_info()` |
| 14 | MAX BET локализация (E.1, E.2) | "MAX BET" хардкод в .tscn, "BET %d" формат | `_bet_max_btn.text = tr_key("game.bet_max")`. Формат "BET LVL %s" | RU: "МАКС. СТАВКА", "Ур. ставки 5" | game.gd, multi_hand_game.gd → поиск `bet_max`, translations.json → `game.bet_one_fmt` |
| 15 | Иконка фишек в WIN/LAST WIN (G.3, F.4) | Числа без иконки | WIN и LAST WIN используют SaveManager currency display (chip glyph + число) | Везде видна иконка фишки перед суммой | game.gd → `_set_win_active()`, `_set_win_dimmed()` |
| 16 | Бейдж центрирование (F.3) | Бейдж мог быть смещён | Позиционирование через `get_global_rect().get_center()` | Бейдж по центру области карт | game.gd → `_position_overlay()` |
| 17 | Popup правил форматирование (F.1) | Label, белый текст без подложки | RichTextLabel, тёмно-синяя подложка (#1a1a66, 70% opacity), ключевые слова жёлтым | Правила с цветовым выделением на подложке | game.gd → `_show_info()` → `rules_panel` |
| 18 | Подсказка над рукой single hand (F.5) | "Выберите карты..." в нижней строке статуса | Floating Label над `_cards_container`, z_index=20 | Подсказка прямо над картами, не в статусбаре | game.gd → `_show_hold_hint()`, `_position_hold_hint()` |
| 19 | Кнопка выхода + диалог (G.7) | Кнопка BACK → мгновенный выход | Диалог "Выйти из-за стола?" [ОСТАТЬСЯ] [ВЫЙТИ] | Подтверждение перед выходом во всех 3 режимах | game.gd, multi_hand_game.gd, spin_poker_game.gd → `_on_back_pressed()` |
| 20 | "ОБЩАЯ СТАВКА" перевод (G.6, G.8) | RU: "ВСЕГО СТАВКА:" | Исправлено на "ОБЩАЯ СТАВКА:" | translations.json → `game.total_bet` RU | data/translations.json |
| 21 | Дизейбл кнопки ставки (G.9) | Кнопка функционально не нажималась, но выглядела активной | `_bet_amount_btn.disabled = true` во время DEALING | Кнопка серая и неактивная во время раунда | game.gd, multi_hand_game.gd, spin_poker_game.gd → `_on_state_changed()` DEALING |
| 22 | Анимация накрутки ×2 (G.4) | game.gd: 1.0с, multi: 1.0с (ultra: 1.5с) | game.gd: 2.0с, multi: 2.0с (ultra: 3.0с) | Накрутка баланса медленнее, заметнее | game.gd → `_animate_credits`, multi_hand_game.gd → `_animate_credits` |
| 23 | Подсветка ставки ×2 (G.1) | flash 0.4с, sweep 0.1с | flash 0.8с, sweep 0.2с | Подсветка столбца paytable длится дольше | game.gd → `_flash_bet_display()`, paytable_display.gd → `sweep_to_max()` |
| 24 | Мигание DEAL при idle (G.10) | Нет | После 5с idle кнопка DEAL пульсирует (modulate 0.4↔1.0) | Кнопка привлекает внимание | game.gd, multi_hand_game.gd, spin_poker_game.gd → `_start_idle_blink_timer()` |
| 25 | Автооткрытие магазина (G.11) | "NOT ENOUGH CREDITS" текст или тишина | Баланс мигает красным 2 раза → авто-открытие магазина | Игрок сразу видит магазин при нехватке кредитов | game.gd, multi_hand_game.gd, spin_poker_game.gd → `_flash_balance_red()` |
| 26 | Multihand UI пакет (H.1-H.7) | Бейджи мелкие, spacing 4px, controlbar широкий, "5 РУК" | Padding 6px, spacing 2px, узкие spacers, "Рук: 5" | Компактнее, читаемее | multi_hand_game.gd → `_make_badge()`, `_build_sidebar()` |
| 27 | Ultimate X → Ultra VP (I.1) | "ULTIMATE X" везде (код, UI, переводы) | Глобальный rename: переменные, ключи, UI-тексты | "ULTRA VP" во всём проекте | Поиск "ultra_vp" по всем .gd файлам |
| 28 | Ultra VP множители backdrop (I.3) | Множители без подложки, сливались с фоном | `draw_rect(Color(0,0,0.1,0.6))` на next/active displays | Тёмная подложка за множителями | multi_hand_game.gd → `_build_mult_zone()` → `draw.connect` |
| 29 | Ultra VP плашка fixed height (I.5) | Разная высота при active/inactive | `_info_card.custom_minimum_size.y = 120` | Плашка не прыгает при смене состояния | multi_hand_game.gd → `_build_info_card()` |
| 30 | Ultra VP бейджи ширина (I.6) | Бейджи сжимались по тексту | `badge.custom_minimum_size.x = 180` | Все бейджи одинаковой ширины | multi_hand_game.gd → `_make_badge()` |
| 31 | Spin: ribbon-иконки линий (J.1) | Простые цветные цифры | SVG ribbon-стрелки, окрашенные через modulate в цвет линии, белый номер | Цветные ribbon-флажки слева и справа от сетки | spin_poker_game.gd → `_make_line_ribbon()`, assets/textures/spin_ribbon.svg |
| 32 | Spin: скорости ×5 медленнее (J.8) | base_spin 700ms, col_stop 180ms | base_spin 3500ms, col_stop 900ms | Барабаны крутятся значительно дольше | spin_poker_game.gd → `SPEED_CONFIGS` |
| 33 | Spin: See Pays интерактивный (J.4) | Простой список "HAND — payout" | Таблица 6 колонок (Hand + bet 1-5). 20 цветных кнопок линий. Тап → подсветка линии. Кнопка X | Полноценный интерактивный экран | spin_poker_game.gd → `_show_paytable()` |
| 34 | Spin: увеличение автомата (J.6) | Grid SIZE_SHRINK_CENTER, фиксированные ячейки 120×120 | Grid SIZE_EXPAND_FILL, ячейки 80×80 min + expand | Сетка заполняет доступное пространство | spin_poker_game.gd → `_grid_panel.size_flags_*` |
| 35 | Удалить аккаунт (C.1) | Нет | Красная кнопка в Settings → 2-шаговое подтверждение → сброс save.json → 20000 кредитов | Кнопка в настройках лобби | lobby_manager.gd → `_delete_account_step1()`, `_step2()`, `_perform_account_delete()` |
| 36 | Инерция свайпа лобби (B.1) | Drag без инерции — список останавливался мгновенно | Tracking velocity + tween на release с EASE_OUT | Список продолжает двигаться с замедлением | lobby_manager.gd → `_drag_velocity`, `_inertia_tween` |
| 37 | Вибрации (K.1) | Нет | VibrationManager autoload: 16 событий, 21 вызов в 3 game scripts. Toggle в Settings | Android: из коробки. iOS: базовый + инструкция для haptic | scripts/vibration_manager.gd, docs/vibration_setup.md |
| 38 | Баланс инкремент анимация (G.5) | При gift claim баланс обновлялся мгновенно | `_animate_balance_increment(old, new, 5.0)` — tween 5 секунд EASE_OUT | Баланс плавно считает от старого к новому | lobby_manager.gd → `_animate_balance_increment()` |
| 39 | Запоминание лейаута рук (G.12) | Уже работало через SaveManager.hand_count | Проверено: hand_count сохраняется в save.json, восстанавливается | Без изменений — уже реализовано | save_manager.gd → `hand_count` |
| 40 | Double кнопки swap (G.3) | [ДА] слева, [НЕТ] справа | Поменяли: [НЕТ] слева, [ДА] справа | Безопасный вариант первый | game.gd, multi_hand_game.gd → double overlay buttons |
| 41 | Spin: рубашка карт (J.2) | SVG рубашка не рендерилась (синий rect перекрывал) | Удалён `<rect fill="#475590">` из card_back_spin.svg | Рубашка отображается корректно | assets/cards/cards_spin/card_back_spin.svg |
| 42 | Spin: кнопка выхода (J.5) | Кнопка BACK с confirm dialog | Работает идентично другим режимам | Диалог "Выйти из-за стола?" | spin_poker_game.gd → `_on_back_pressed()` |
| 43 | Spin: STOP инерция (J.9) | Мгновенная остановка | 4-step deceleration flicker (700ms) перед финальной картой | Барабан тормозит плавно | spin_poker_game.gd → `inertia_ms` в SPEED_CONFIGS |
| 44 | Spin: анимация fold строк (J.7) | Top/bottom ряды просто переключались на рубашки | scale_y 1→0 (collapse) → смена текстуры → 0→1 (expand) | Визуальное "закрытие" строк между раундами | spin_poker_game.gd → `_animate_rows_fold()` |
| 45 | Multihand: "Мультихенд" перевод (H.6) | RU: "МУЛЬТИ-РУКА ВИДЕО ПОКЕР" | Заменено на "МУЛЬТИХЕНД ВИДЕО ПОКЕР" | Корректный термин | data/translations.json → `info.title_multi` |
| 46 | Ultra VP: окно правил (I.7) | Label с белым текстом, таблица без цветов | RichTextLabel с BBCode, тёмная подложка, зелёные keywords. Таблица множителей: строки раскрашены по рангу | Правила с цветовым выделением, яркая таблица | multi_hand_game.gd → `_show_info()` |

---

## Дополнительно выполнено (за рамками improvements.md)

| # | Задача | Что сделано | Где проверить |
|---|---|---|---|
| 47 | SoundManager подключён к sounds.json | Загружает AudioStream из конфига, пул 4 AudioStreamPlayer | scripts/sound_manager.gd |
| 48 | Lobby читает lobby_order.json | PLAY_MODES строятся из ConfigManager. Машины фильтруются по режиму | scripts/lobby_manager.gd → `_build_play_modes()`, `_build_carousel()` |
| 49 | SaveManager defaults = 20000 | DEFAULT_CREDITS = 20000, совпадает с init_config.json | scripts/save_manager.gd |
| 50 | CLAUDE.md §19 обновлён | Архитектура отражает configs/, spin poker, ultra VP, все autoloads | CLAUDE.md |
| 51 | App Store описания EN/RU | Тексты для Google Play и App Store | docs/store_listing.md |
| 52 | Privacy Policy | Опубликована на GitHub Pages | https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html |
| 53 | Экспорт iOS + Android | export_presets.cfg, 11 иконок, project.godot настроен | export_presets.cfg, assets/icons/, docs/export_guide.md |
| 54 | Вибрации (K.1) | VibrationManager autoload, 16 событий, toggle в настройках | scripts/vibration_manager.gd, docs/vibration_setup.md |
| 55 | Иконка выхода | table_exit.svg 48px во всех режимах, верхний левый угол | assets/textures/table_exit.svg |
| 56 | Подсказка над рукой (multihand) | Floating label над primary hand | multi_hand_game.gd → `_show_hold_hint()` |

---

## Осталось сделать вручную

| # | Задача | Детали |
|---|---|---|
| 1 | Заменить placeholder иконки | assets/icons/*.png — сейчас синий фон + "VP". Заменить на финальные перед публикацией |
| 2 | Заменить silent mp3 на реальные звуки | assets/sounds/*.mp3 — 22 тихих файла. Сохранить имена файлов |
| 3 | Создать release keystore (Android) | `keytool -genkeypair ...` — см. docs/export_guide.md |
| 4 | Прописать Apple Team ID + Provisioning Profile (iOS) | В export_presets.cfg → `app_store_team_id`, `provisioning_profile_uuid_*` |
| 5 | Скачать Godot export templates | Editor → Manage Export Templates → Download (Android + iOS) |
| 6 | Собрать и протестировать на устройствах | Android: `adb install`, iOS: Xcode → Archive. См. docs/export_guide.md |
| 7 | Проверить Privacy Policy URL | https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html |
| 8 | Загрузить скриншоты в App Store / Google Play | Минимум 3 landscape скриншота для каждой платформы |
