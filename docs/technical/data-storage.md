# Хранение данных

## Основное приложение (Flutter)

| Механизм | Ключ | Содержимое |
|----------|------|------------|
| `SharedPreferences` | `people_storage_v1` | JSON-массив объектов `Person` (`toMap` / `fromMap`) |

Логика в **`PeopleRepository`** (`lib/data/people_repository.dart`):

- Если ключа нет или строка пустая → возвращается **`mockPeople`** из `lib/data/mock_people.dart`.
- При ошибке `jsonDecode` / парсинга → снова **`mockPeople`**.

Отдельной версионированной миграции схемы JSON в коде нет: все поля читаются через `fromMap` с значениями по умолчанию при отсутствии ключей.

## App Group `group.com.vlad.nastroi`

Используется для обмена данными между основным приложением, виджетом iPhone и (на стороне watch) приложением Watch и complication.

Указание группы:

- iOS Runner: `ios/Runner/Runner.entitlements`
- Расширения виджетов и Watch: собственные `.entitlements` в проекте Xcode

### Ключ `widget_people`

- **Пишет:** Flutter через пакет **`home_widget`** (`WidgetService`: `HomeWidget.saveWidgetData`).
- **Читает:** `WidgetDataStore` в `ios/NastroiWidget/NastroiWidget.swift` (`UserDefaults(suiteName: appGroupId)`).
- **Формат:** JSON-массив с полями `id`, `name`, `mood`, `gender`, `avatarVariant`, опционально `activeStage`. Поле `id` соответствует **`publicId`** человека в приложении.

### Ключ `watch_people`

- **Пишет:** не Flutter напрямую; **`WatchPeopleStore`** на watchOS после приёма данных по WatchConnectivity — сохраняет **ту же JSON-строку**, что пришла с iPhone, в suite App Group и дублирует в `UserDefaults.standard` на часах.
- **Читает:** виджет watchOS (`NastroiWatchWidgetExtension.swift`) и при старте `WatchPeopleStore` для восстановления списка.

Структура элементов декодируется как **`WatchPerson`** / **`WatchWidgetPerson`** в Swift (поля включают `helpfulActions`, `avoidActions`).

### Ключ `selected_widget_person_id`

- **Пишет:** приложение Watch (`ContentView.selectForWidget`) при выборе «Показать в виджете».
- **Читает:** complication (`NastroiWatchWidgetExtension`) для выбора записи из массива `watch_people`; если ID нет — берётся первый человек из списка.

## Локальное состояние UI

- **`app_theme_controller.dart`** — глобальный `ValueNotifier<ThemeMode>` со стартовым значением `ThemeMode.dark`; персистентности темы в коде нет (после перезапуска снова тёмная).

## Что не используется как хранилище основных данных

- Нет Hive/SQLite/Drift для людей.
- Нет облачной синхронизации в зависимостях `pubspec.yaml`.

## Замечание про импорт по ссылке (`LinkPersonPreviewScreen`)

После **«Добавить»** обновляется только ключ **`people_storage_v1`**. Ключи **`widget_people`** и синхронизация на Watch срабатывают только когда выполняется цепочка из **`HomeScreen._persist()`** / **`_init()`**.
