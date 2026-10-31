# video poker — инструкции Codex

Social casino: агрегатор игровых модулей с общей метой.

Перед работой прочитай `~/.claude/CLAUDE.md` (единственный общий источник предпочтений),
`../GODOT_CONVENTIONS.md`, затем `docs/CODEX.md`.
Память/уточнения владельца: `docs/CODEX_MEMORY.md` (прочитать в начале сессии).
Сложная задача: `docs/PAIN_LOG.md`. Реальная карта кода: `docs/CODEX_ARCHITECTURE.md`.
Полные проектные правила и тематические указатели: `docs/CODEX_PROJECT_REFERENCE.md`;
старый `CLAUDE.md` сохранён как источник, его Claude-интерфейсы не являются командами Codex.

## Критические правила

- Новая игра только через $add-new-game / /skills; docs/GAME_INTEGRATION.md определяет контракт round_finished и save-отсеки.
- При добавлении модуля core/ и общую оболочку не менять; необходимое изменение контракта сначала обсудить.
- Тюнинг только configs/*.json с ConfigManager; выплаты data/paytables.json и docs/MACHINES_REFERENCE.md. Remote Config не содержит paytables/RTP/IAP product_id.
- Текст только Translations.tr_key, ключи во всех en/ru/es; имена рук через Paytable, machine names английские.
- Порядок автозагрузок брать из project.godot; SaveManager до RemoteConfigManager.
- Safe area, full-bleed/inset и layout всех single/multi/spin сцен проверять совместно; emoji через SVG. OS permission начинается с нашего pre-prompt.
- Статическая типизация, программные стили UI, сцены через load(); новые зависимости только по согласованию.
- Поиск только внутри этого проекта; исключать .godot/, .git/, build/, builds/, exports/, android/build/, ios exports, reference/, ref/, ripped_project/, venv/. Архивы ../_rips/ и ../__vp_configs_backup/ не открывать без прямой просьбы.
- Не печатать секреты, не переносить auth/allowlists в разрешения Codex. Хуки требуют штатного доверия через /hooks.
- Коммиты, отправки, релизы и production только в явно порученном объёме; миграция не разрешает их. Исходники Claude сохранять.
- При правке внешнего ввода, доступа, секретов или выполнения команд применять ~/.agents/skills/security-guidance/SKILL.md.
- После изменений проверять затронутое поведение; отчёт содержит охват, пропуски и провалы, пустой вывод не доказывает успех.

Локальная процедура: `.agents/skills/add-new-game/SKILL.md` (`$add-new-game` или `/skills`).

## Документация по задаче

- `docs/GAME_INTEGRATION.md`
- `docs/MACHINES_REFERENCE.md`
- `docs/CONFIG_REFERENCE.md`
- `docs/REMOTE_CONFIG.md`
- `docs/UI_LAYOUTS.md`
- `docs/MATH_AUDIO.md`
- `docs/SPIN_POKER_IMPL.md`
- `docs/BIG_WIN.md`
- `docs/RELEASE.md`
- `docs/IOS_UPLOAD.md`
- `docs/RELEASE_GUIDE.md`
- `docs/ANDROID_UPLOAD.md`
- `docs/ROADMAP.md`
- `docs/SAFE_AREA.md`
- `docs/PAIN_LOG.md`
- `docs/DAILY_QUESTS.md`
- `docs/GLOSSARY.md`
