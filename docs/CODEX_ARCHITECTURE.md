# Фактическая архитектура для Codex

Срез 2026-10-31, проверен по project.godot, сценам и исходникам;
целевые деревья старых документов не считаются реализованным кодом.

## Запуск

- `project.godot`: main_scene `res://scenes/splash.tscn`.
- Файл стартовой сцены: `scenes/splash.tscn`.
- Скрипты стартовой сцены: `core/splash.gd`.

## Слои

- `core` — Оболочка main/lobby, GameRegistry, общая мета, config/save, квесты, shop/IAP и remote config.
- `libs/poker` — Общая покерная библиотека: колода, эвалюатор, варианты, single/multi/spin и сцены.
- `games` — Манифесты VP-модулей и отдельный domino с собственной логикой.
- `scenes` — Splash, main и lobby.
- `configs` — Общий тюнинг и реестр games.json.
- `data` — Paytables и локализация en/ru/es.

## Автозагрузки в фактическом порядке

- ConfigManager → `core/config_manager.gd`
- SaveManager → `core/save_manager.gd`
- GameRegistry → `core/game_registry.gd`
- DailyQuestManager → `core/daily_quest_manager.gd`
- SafeAreaManager → `core/safe_area_manager.gd`
- RemoteConfigManager → `core/remote_config_manager.gd`
- NotificationManager → `core/notification_manager.gd`
- SoundManager → `core/sound_manager.gd`
- Translations → `core/translations.gd`
- VibrationManager → `core/vibration_manager.gd`
- BigWinOverlay → `core/big_win_overlay.gd`
- QuestBannerOverlay → `core/quest_banner_overlay.gd`
- QuestPopupOverlay → `core/quest_popup_overlay.gd`
- ShopOverlay → `core/shop_overlay.gd`
- IapManager → `core/iap_manager.gd`
- ThemeManager → `core/theme_manager.gd`

## Проверки и инструменты

- Найдено 7 файлов `test_*.gd` в `tests/`; это число файлов, не количество assertions.
- `scripts/`: `scripts/build_android_release.sh`, `scripts/generate_android_adaptive_icons.gd`, `scripts/install_revenuecat.sh`, `scripts/patch_ios_export.sh`, `scripts/upload_googleplay.sh`, `scripts/upload_testflight.sh`.
- Ресурсы/аддоны и экспортные папки не переписывались; сборки/сторы в рамках миграции не запускались.
