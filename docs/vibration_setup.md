# Vibration Setup Guide

## Архитектура

`VibrationManager` — autoload синглтон (`scripts/vibration_manager.gd`).
Единый API: `VibrationManager.vibrate("event_name")`.

Toggle: `SaveManager.settings["vibration"]` (true/false), переключается в Settings лобби.

## Android

Работает из коробки через `Input.vibrate_handheld(duration_ms)`.

**Требования:**
- В export preset: включить permission `VIBRATE` (Project → Export → Android → Permissions → ☑ VIBRATE)
- Godot 4.x Mobile renderer

**Ограничения:**
- Только длительность (нет типов light/medium/heavy)
- Минимальная длительность ~10ms (меньше — может не сработать на некоторых устройствах)
- Паттерн (burst) реализован через последовательные вызовы с задержкой

## iOS

### Базовый вариант (текущий)

`Input.vibrate_handheld()` на iOS вызывает `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)` — одиночная фиксированная вибрация ~400ms. Не поддерживает разные длительности.

### Продвинутый вариант (UIImpactFeedbackGenerator)

Для haptic feedback с разными стилями (light/medium/heavy/rigid/soft) нужен GDExtension плагин.

**Варианты плагинов:**

1. **godot-ios-plugins** (официальный набор):
   - Репозиторий: https://github.com/nicemicro/godot-ios-plugins
   - Содержит `haptic` модуль
   - Установка:
     ```
     1. Скачать .xcframework из Releases
     2. Положить в ios/plugins/
     3. В export preset: Plugins → включить Haptic
     4. В GDScript: Engine.get_singleton("Haptic").impact("light")
     ```

2. **Свой GDExtension** (если плагин недоступен):
   - Создать Swift файл с UIImpactFeedbackGenerator
   - Обернуть в GDExtension
   - Минимальный код:

   ```swift
   // HapticPlugin.swift
   import UIKit

   @objc class HapticPlugin: NSObject {
       static let shared = HapticPlugin()
       
       @objc func impact(_ style: String) {
           var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium
           switch style {
           case "light": feedbackStyle = .light
           case "medium": feedbackStyle = .medium
           case "heavy": feedbackStyle = .heavy
           default: break
           }
           let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
           generator.prepare()
           generator.impactOccurred()
       }
   }
   ```

3. **Godot 4.x native approach** (рекомендуемый):
   - Использовать `OS.request_permission()` не нужно — вибрация не требует разрешения на iOS
   - `Input.vibrate_handheld(ms)` вызывает базовую вибрацию
   - Для haptic feedback: ждать официальный плагин или использовать GDExtension

### Обновление VibrationManager для iOS haptics

Когда плагин установлен, обновить `vibration_manager.gd`:

```gdscript
var _haptic_plugin = null

func _ready() -> void:
    if Engine.has_singleton("Haptic"):
        _haptic_plugin = Engine.get_singleton("Haptic")

func vibrate(event_name: String) -> void:
    if not _is_enabled():
        return
    if _haptic_plugin:
        _vibrate_ios(event_name)
    else:
        _vibrate_android(event_name)

func _vibrate_ios(event_name: String) -> void:
    match event_name:
        "button_press", "card_hold", "bet_change", "spin_reel":
            _haptic_plugin.impact("light")
        "card_deal", "card_flip", "spin_stop", "multiplier_activate":
            _haptic_plugin.impact("medium")  
        "win_small", "double_win", "gift_claim":
            _haptic_plugin.impact("medium")
        "win_large", "win_royal_flush", "win_jackpot":
            _haptic_plugin.impact("heavy")
        _:
            _haptic_plugin.impact("light")
```

## Маппинг событий

| Событие | Android (ms) | iOS Haptic |
|---|---|---|
| button_press | 10 | light |
| card_deal | 15 | medium |
| card_flip | 15 | medium |
| card_hold | 10 | light |
| bet_change | 10 | light |
| win_small | 30 | medium |
| win_medium | 40 | medium |
| win_large | 60 | heavy |
| win_royal_flush | 100 (pattern) | heavy |
| win_jackpot | 100 (pattern) | heavy |
| spin_reel | 8 | light |
| spin_stop | 20 | medium |
| double_win | 30 | medium |
| double_lose | 20 | medium |
| gift_claim | 40 | medium |
| multiplier_activate | 25 | medium |

## Тестирование

- **Desktop:** `Input.vibrate_handheld()` ничего не делает — это нормально
- **Android:** протестировать через USB debug или APK install
- **iOS:** протестировать через Xcode build на реальном устройстве (симулятор не вибрирует)
