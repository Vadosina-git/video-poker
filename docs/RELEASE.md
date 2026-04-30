# Release / Store Metadata

Ссылка из CLAUDE.md §22.

Общие креденшалы команды (Team ID, ASC API keys, sandbox тестер, Google
Play developer name) — в `/Users/vadimprokop/Downloads/SHARED_ACCOUNTS_REFERENCE.md`.

## App Store Connect

| Параметр | Значение |
|---|---|
| App Name | **Video Poker Vegas Classic 3D** |
| Bundle ID | `com.khralz.videopoker` |
| SKU | `videopoker-classic-001` |
| Platform | iOS (iPhone only) |
| Primary Language | English (U.S.) |
| Team | KHRALZ (`KQBUD75V9A`) |
| Apple ID (app) | `6762597977` (создано 2026-04-20) |
| Privacy Policy URL | https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html |
| Support URL | https://vadosina-git.github.io/privacy-policy/video-poker-support.html |
| Copyright | © 2026 Ivan Al Zeidi |
| Age Rating | 17+ (Frequent/Intense Simulated Gambling) |
| Min iOS | 15.0 |

## Google Play Console

| Параметр | Значение |
|---|---|
| App name | **Video Poker Vegas Classic 3D** |
| Package name | `com.khralz.videopoker` |
| Developer | KHRALZ |
| Target SDK | 35 |
| Min SDK | 24 |
| Target Audience | 18+ (simulated gambling) |

## Локальные secrets (gitignored)

- `.keystore.env` — Android release keystore credentials
- `.appstore.env` — ASC API key IDs + Apple ID + sandbox creds
- `~/.appstoreconnect/private_keys/AuthKey_{X5959253U4,XL7R7TRL5N}.p8` — API keys

## Release scripts

- `scripts/build_android_release.sh` — signed APK
- `scripts/patch_ios_export.sh` — post-export патч Info.plist + PrivacyInfo + pbxproj
- `scripts/upload_testflight.sh` — загрузка .ipa через ASC API key
- `scripts/install_revenuecat.sh` — установка native бинарей RC плагина

## RevenueCat (IAP)

- Status: проект ещё не создан (на 2026-04-20).
  См. `docs/morning_testing_instructions.md` §10 и §11.
- Public API keys для `scripts/iap_manager.gd`:
  - `RC_API_KEY_IOS` (`appl_*`)
  - `RC_API_KEY_ANDROID` (`goog_*`)

## Runbook

Полная инструкция «как привести Godot-проект к релизной готовности» —
`docs/godot_release_runbook.md`. Применима к другим Godot-приложениям на
KHRALZ.
