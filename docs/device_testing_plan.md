# Device Testing Plan — release_01

Цель: прогнать build на iPhone (реальный девайс) и Android emulator, найти регрессии перед релизом.

---

## 0. Pre-flight (30 мин)

### Окружение
- [ ] Godot 4.6 открывает проект без ошибок
- [ ] Editor → Manage Export Templates → installed для Android + iOS
- [ ] Android SDK + JDK 17 настроены (см. `docs/export_guide.md`)
- [ ] Xcode 15+ установлен, Apple Developer login активен
- [ ] Android Studio: AVD Manager → создан эмулятор (pixel 6, API 34, landscape)
- [ ] iPhone подключён по USB, Trust computer, Developer Mode включён

### Билды
- [ ] Android Debug APK собран: `Project → Export → Android (Debug) → Export Project`
- [ ] iOS Debug Xcode project экспортирован: `Project → Export → iOS (Debug)`
- [ ] В Xcode: открыть экспортированный `.xcodeproj`, Signing & Capabilities → Team выбран, Build & Run на iPhone
- [ ] Android: `adb install build.apk` в эмулятор

### Fallback (если экспорт не работает)
- [ ] Godot editor → Remote Debug → One-click deploy on device (iOS/Android)

---

## 1. Smoke-tests (критические flow, ~20 мин)

Проходить на **обоих** устройствах (iPhone + Android emu).

| # | Сценарий | OK? iOS | OK? Android | Заметки |
|---|---|---|---|---|
| S1 | Первый запуск: лобби открывается, все 10 машин видны | ☐ | ☐ |  |
| S2 | Тап по машине → переход в Single Play + раздача первых 5 карт | ☐ | ☐ |  |
| S3 | DEAL → HOLD тап по каждой карте → DRAW → оценка | ☐ | ☐ |  |
| S4 | Выигрыш на Jacks or Better: paytable row pulse + confetti | ☐ | ☐ |  |
| S5 | Баланс списывается перед deal, начисляется после win | ☐ | ☐ |  |
| S6 | Кнопка ◄ back → confirm → возврат в лобби | ☐ | ☐ |  |
| S7 | Sidebar: переключение Triple / Five / Ten / Ultra VP / Spin Poker | ☐ | ☐ |  |
| S8 | Triple Play: DEAL → HOLD → DRAW — 3 руки оцениваются | ☐ | ☐ |  |
| S9 | Ultra VP: множитель NEXT→ACTIVE переходит между раундами | ☐ | ☐ |  |
| S10 | Spin Poker: DEAL SPIN → шторки раскрываются → 20 линий → выплата | ☐ | ☐ |  |
| S11 | Shop ⊕ открывается (лобби) → покупка пакета → баланс растёт | ☐ | ☐ |  |
| S12 | Shop открывается из игрового экрана (single/multi/ultra) — тот же UI | ☐ | ☐ |  |
| S13 | Gift widget: таймер → «COLLECT!» → claim → фишки летят | ☐ | ☐ |  |
| S14 | Settings ⚙ → Language picker → смена языка → reload | ☐ | ☐ |  |
| S15 | BIG WIN срабатывает при mult ≥ 4 (выиграть Full House при bet 1) | ☐ | ☐ |  |
| S16 | Tap to continue закрывает BIG WIN overlay | ☐ | ☐ |  |
| S17 | Double or Nothing после выигрыша — pick card | ☐ | ☐ |  |
| S18 | Exit confirm при back-кнопке телефона / ◄ в игре | ☐ | ☐ |  |

---

## 2. iOS-specific (~15 мин)

| # | Сценарий | OK? | Заметки |
|---|---|---|---|
| i1 | Safe area respected (notch / Dynamic Island): баланс + title не под notch | ☐ |  |
| i2 | Home indicator не перекрывает кнопки DEAL/DRAW | ☐ |  |
| i3 | Ориентация залочена (landscape only, не переворачивается) | ☐ |  |
| i4 | Haptic feedback на DEAL/DRAW/win срабатывает | ☐ |  |
| i5 | Тап-регистрация точная (нет ложных срабатываний у краёв) | ☐ |  |
| i6 | Свайп магазина scrolling работает горизонтально без рывков | ☐ |  |
| i7 | Нет чёрных полос по краям (stretch_aspect=keep_height корректен) | ☐ |  |
| i8 | App icon отображается корректно (1024 + все размеры) | ☐ |  |
| i9 | Launch splash (boot splash) показывается без мерцаний | ☐ |  |
| i10 | Сворачивание → возврат: состояние сохранено (credits, hand_count) | ☐ |  |

---

## 3. Android-specific (~15 мин)

| # | Сценарий | OK? | Заметки |
|---|---|---|---|
| a1 | Системная back-кнопка в игре → exit confirm | ☐ |  |
| a2 | Системная back-кнопка в лобби → exit app (confirm или сразу) | ☐ |  |
| a3 | Vibration работает (нужно `<uses-permission android:name="android.permission.VIBRATE">`) | ☐ |  |
| a4 | Разные разрешения: на эмуляторе Pixel 6 (2340×1080), Pixel C tablet (2560×1800) | ☐ |  |
| a5 | Navigation bar не перекрывает контент | ☐ |  |
| a6 | Status bar скрыт в игре (fullscreen) | ☐ |  |
| a7 | Адаптивная иконка (foreground + background) | ☐ |  |
| a8 | Package name: `com.videopoker.classicedition` в AndroidManifest | ☐ |  |
| a9 | APK устанавливается без ошибок signing | ☐ |  |

---

## 4. Микроанимации (регрессии, ~15 мин)

Проверить что все анимации из `micro-animations` работают на обоих:

| # | Анимация | iOS | Android | Где |
|---|---|---|---|---|
| 1.2 | Shimmer sweep на карточках машин | ☐ | ☐ | Lobby |
| 1.3 | Stagger fade-in карточек | ☐ | ☐ | Lobby (enter/mode switch) |
| 1.4 | Tab wiggle при смене режима | ☐ | ☐ | Lobby sidebar |
| 1.7 | Tilt on press карточки | ☐ | ☐ | Lobby |
| 2.1 | Ripple на кнопках | ☐ | ☐ | Lobby / Shop |
| 2.2 | Hover bounce | ☐ | ☐ | (Desktop only, skip mobile) |
| 3.2 | Coin flip на изменении баланса | ☐ | ☐ | Any screen |
| 3.3 | BIG WIN / HUGE WIN overlay | ☐ | ☐ | Single / Multi / Ultra / Spin |
| 3.4 | Chip cascade + trail | ☐ | ☐ | Shop / gift claim |
| 4.1 | Shop open/close bounce | ☐ | ☐ | Shop |
| 4.3 | Confetti burst при покупке | ☐ | ☐ | Shop |
| 4.4 | Badge shine sweep на pack ribbons | ☐ | ☐ | Shop |
| 4.5 | Scrollbar fade | ☐ | ☐ | Lobby / Shop scroll |
| 5.1 | Win celebration (confetti) | ☐ | ☐ | Single-hand на выигрыше |
| 5.2 | Paytable row pulse | ☐ | ☐ | Single-hand на выигрыше |
| 5.2б | Badge blink (multi-hand + Ultra) | ☐ | ☐ | Multi / Ultra VP |
| 5.4 | HELD card lift + golden border | ☐ | ☐ | Single / Multi / Ultra |
| 6.1 | Scene crossfade + entrance slide | ☐ | ☐ | Enter single / multi / ultra |

---

## 5. Performance (~10 мин)

| # | Метрика | iOS target | Android target | Inst |
|---|---|---|---|---|
| P1 | FPS в лобби (idle) | ≥60 | ≥60 | Godot monitor / GPU overlay |
| P2 | FPS во время deal/draw анимации | ≥55 | ≥55 |  |
| P3 | FPS во время BIG WIN (coins rain + confetti) | ≥50 | ≥50 |  |
| P4 | Время загрузки из лобби в игру | ≤2.5с | ≤2.5с | LOADER_DURATION=2s + fade |
| P5 | Размер APK/IPA | ≤40MB | ≤40MB | `du -sh` на exported |
| P6 | Memory footprint в игре | ≤200MB | ≤200MB | Xcode instruments / Android profiler |
| P7 | Battery drain: 10 мин игры | ≤3% | ≤3% | Settings → Battery |

---

## 6. Issue log

Формат: `[device] [severity: critical/major/minor] [area] description`

```
[iPhone 14 Pro] [major] [BIG WIN] счётчик дёргается при переходе 9→10 цифр
[Pixel 6 emu] [minor] [Lobby] shimmer sweep слегка заикается при fade-in карт
```

---

## 7. Sign-off

- [ ] Все S-тесты passing на обоих устройствах
- [ ] Нет critical bugs
- [ ] Major bugs либо починены либо в трекере с планом
- [ ] Performance в пределах targets
- [ ] Готово к production build → TestFlight / internal track

**Дата:** ____________
**Тестировщик:** ____________
