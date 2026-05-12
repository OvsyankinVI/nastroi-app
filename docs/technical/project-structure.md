# Структура проекта

Корень репозитория — стандартный Flutter-проект с платформенными папками. Ниже — только значимые для продукта «Настрой» пути.

## Дерево (упрощённо)

```
nastroi_app/
├── lib/                          # Dart-код приложения
│   ├── main.dart                 # entrypoint, темы, deep links
│   ├── app.dart                  # не используется импортами (дубликат оболочки)
│   ├── app_colors.dart
│   ├── app_theme_controller.dart # ThemeMode (ValueNotifier)
│   ├── data/
│   │   ├── people_repository.dart
│   │   └── mock_people.dart
│   ├── models/
│   │   ├── person.dart
│   │   └── person_action.dart
│   ├── services/
│   │   ├── notification_service.dart
│   │   ├── widget_service.dart
│   │   └── watch_sync_service.dart
│   ├── utils/
│   │   └── person_link.dart      # HTTPS-ссылка и парсинг import/deep link
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── person_screen.dart
│   │   ├── edit_person_screen.dart
│   │   ├── life_cycle_screen.dart
│   │   ├── create_person_screen.dart
│   │   ├── import_person_screen.dart
│   │   ├── link_person_preview_screen.dart
│   │   └── about_screen.dart
│   └── widgets/
│       └── person_avatar.dart
├── assets/avatars/               # PNG аватаров (Flutter + частично widget)
├── ios/
│   ├── Runner/                   # основное iOS-приложение (Flutter)
│   │   ├── AppDelegate.swift     # WatchConnectivity + MethodChannel
│   │   ├── SceneDelegate.swift
│   │   ├── Info.plist            # URL scheme nastroi, FlutterDeepLinkingEnabled
│   │   └── Runner.entitlements   # App Group
│   ├── NastroiWidget/            # исходники виджета iPhone
│   ├── NastroiWatch Watch App/ # watchOS приложение
│   ├── NastroiWatchWidgetExtension/  # complication watchOS
│   ├── Runner.xcodeproj/
│   └── Podfile                   # platform iOS 16.0
├── android/, macos/, linux/, windows/  # каркас Flutter (Android без deep link intent-filter)
├── test/
│   └── widget_test.dart          # пустой main
├── pubspec.yaml
└── docs/
```

## Xcode targets (iOS)

По `Runner.xcodeproj`:

| Продукт | Назначение |
|---------|------------|
| Runner | Хост Flutter на iPhone |
| NastroiWidgetExtension | Виджет домашнего экрана iOS (папка `NastroiWidget/`) |
| NastroiWatch Watch App | Приложение на Apple Watch |
| NastroiWatchWidgetExtensionExtension | Расширение виджета watchOS (complication) |

Точные имена таргетов и `.appex` смотреть в Xcode при необходимости.

## Ключевые файлы по роли

| Файл | Роль |
|------|------|
| `lib/main.dart` | `runApp`, `NotificationService.initialize`, `AppLinks`, `MaterialApp` |
| `lib/data/people_repository.dart` | Чтение/запись списка людей в `SharedPreferences` |
| `lib/models/person.dart` | Модель `Person`, `CycleStage`, export code |
| `ios/Runner/AppDelegate.swift` | Обработчик `syncPeople`, отправка JSON на Watch |
| `ios/NastroiWidget/NastroiWidget.swift` | Timeline provider, App Intent выбора человека |
| `ios/NastroiWatch Watch App/WatchPeopleStore.swift` | Приём данных с iPhone, сохранение, reload виджета |
| `ios/NastroiWatchWidgetExtension/NastroiWatchWidgetExtension.swift` | Provider complication |
