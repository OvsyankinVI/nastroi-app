# Сборка и релиз

## Требования к окружению

| Компонент | Версия / примечание |
|-----------|---------------------|
| Flutter SDK | В `pubspec.yaml`: `sdk: ^3.9.0` — использовать совместимый Flutter |
| Dart | Идёт в составе Flutter |
| Xcode | Достаточно свежая для watchOS/iOS targets проекта (конкретная минимальная версия Xcode не закреплена в этом документе; ориентироваться на требования Flutter и Xcode для выбранного SDK) |
| CocoaPods | Для iOS — после `flutter pub get` обычно `pod install` в `ios/` |

## iOS

`ios/Podfile` задаёт **`platform :ios, '16.0'`**.

### Targets в Xcode

При сборке из Xcode или `flutter build ios` участвуют:

- **Runner** — основное приложение
- **NastroiWidgetExtension** — виджет
- **NastroiWatch Watch App** — часы
- **NastroiWatchWidgetExtensionExtension** — complication

### Signing и capabilities

- Каждому таргету нужен **Apple Developer** provisioning с включёнными возможностями, совпадающими с проектом.
- **App Groups**: идентификатор **`group.com.vlad.nastroi`** должен быть включён для Runner и расширений, которые читают/пишут общие данные (`Runner.entitlements`, entitlements виджетов и Watch).

### Команды Flutter

```bash
cd /path/to/nastroi_app
flutter pub get
flutter build ios        # релизная сборка IPA через Xcode/archive или CI
flutter build ipa        # при настроенном экспорте
```

Сборка Watch обычно идёт как зависимость схемы **Runner** с embedded Watch content (проверять в Xcode).

## Android / другие платформы

В репозитории присутствуют стандартные папки **`android/`**, **`macos/`**, **`linux/`**, **`windows/`**. Основная продуктовая логика виджетов и Watch завязана на iOS; для Android при необходимости отдельно настраиваются deep links и поведение `home_widget` / уведомлений.

```bash
flutter build apk
flutter build appbundle
```

## Конфигурация приложения

- Имя и версия: **`pubspec.yaml`** (`version: 1.0.0+1`).
- Отображаемое имя на iOS в **`Info.plist`**: `CFBundleDisplayName` = `Nastroy` (как в файле проекта).

## TestFlight / App Store

Пошаговый релиз не автоматизирован в этом репозитории документацией. Обычный процесс:

1. Увеличить версию/build в Xcode или через `pubspec` + синхронизация с нативными проектами по необходимости.
2. Архивировать **Runner** в Xcode с правильной схемой и подписью.
3. Загрузить в App Store Connect, пройти проверку метаданных для расширений (виджет, Watch).

Убедиться, что все расширения подписаны одной командой и включены в архив основного приложения.
