# Deep Links

Зависимость: **`app_links`** (`AppLinks` в `lib/main.dart`).

## Регистрация платформы

### iOS

`ios/Runner/Info.plist`:

- **`FlutterDeepLinkingEnabled`** = `true`
- **`CFBundleURLTypes`** — схема **`nastroi`**

### Android

`android/app/src/main/AndroidManifest.xml` содержит только `MAIN` / `LAUNCHER` для activity — **нет** `intent-filter` для `https` или кастомной схемы. Открытие ссылок на Android через те же URI, что обрабатывает Dart, может потребовать дополнительной настройки манифеста (сейчас в репозитории не сделано).

## Обработка во Flutter

Класс **`_NastroiAppState`** в `main.dart`:

1. При **`initState`** — **`_setupDeepLinks()`**
2. **`getInitialLink()`** — если приложение открыто по ссылке при холодном старте
3. **`uriLinkStream`** — ссылки, пока приложение запущено

Ошибки при чтении initial link и в stream **глотаются** (`catch (_) {}`, `onError: (_) {}`).

## Поддерживаемые форматы

### 1. Кастомная схема `nastroi://person/<publicId>`

Условие в коде: `uri.scheme == 'nastroi' && uri.host == 'person'`.

- Первый сегмент пути — **`publicId`**
- Загружается список через **`PeopleRepository().loadPeople()`**
- Ищется человек с совпадающим **`publicId`**
- Если найден — **`Navigator.push`** на **`PersonScreen`** с **`isEditable: false`**, **`isMyProfile: false`**, пустые колбэки удаления/пина обновления снаружи (`onPersonUpdated: (_) {}`)

Если человек не найден или `navigator` недоступен — переход **не выполняется** (без сообщения пользователю).

В этом режиме у **`PersonScreen`** не передаётся **`onPersonDeleted`** — кнопки удаления в шапке **нет**.

### 2. Импорт профиля через URI с query `data`

Если схема не попала в ветку выше, вызывается **`tryParsePersonFromUri(uri)`** из `lib/utils/person_link.dart`:

- Ожидается непустой query-параметр **`data`**
- Значение трактуется как **`Person.fromExportCode(data)`**

При успехе — **`LinkPersonPreviewScreen(personFromLink: ...)`**.

После кнопки **«Добавить»** на этом экране выполняется только **`PeopleRepository.savePeople`** — без **`WidgetService`**, **`WatchSyncService`** и **`NotificationService.rescheduleCycleNotifications`**. При возврате на главный экран список в состоянии **`HomeScreen`** может остаться старым до перезапуска приложения (репозиторий уже содержит новую запись). Подробнее: [architecture.md](architecture.md).

Пример формата ссылки, который строит приложение для шаринга: **`https://nastroi.app/person?data=...`** (`buildPersonLink` в `person_link.dart`). Universal Links / Associated Domains для автоматического открытия HTTPS в приложении в **`Runner.entitlements`** не настроены — поведение системы для таких ссылок зависит от окружения.

### 3. Сырой текст (не через AppLinks)

**`tryParsePersonFromRaw`** в `person_link.dart` используется экранами импорта: сначала **`Person.fromExportCode`**, затем **`Uri.parse` + tryParsePersonFromUri**. Это не поток `AppLinks`, а ручной ввод/буфер обмена.

## Виджет iPhone

В `ios/NastroiWidget/NastroiWidget.swift` **`widgetURL`** задаётся как **`nastroi://person/<id>`**, где `id` — поле из JSON виджета (соответствует **`publicId`**).

## Связанные файлы

- `lib/main.dart` — подписка и маршрутизация
- `lib/utils/person_link.dart` — HTTPS-ссылка и парсинг
- `lib/screens/link_person_preview_screen.dart` — предпросмотр импорта
