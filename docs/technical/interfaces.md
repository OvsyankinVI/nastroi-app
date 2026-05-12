# Интерфейсы между компонентами

## Flutter ↔ iOS Runner (MethodChannel)

| Параметр | Значение |
|----------|----------|
| Имя канала | `nastroi_watch_sync` |
| Регистрация | `ios/Runner/AppDelegate.swift`, registrar `"NastroiWatchSyncPlugin"` |

### Метод `syncPeople`

**Вызов из Dart:** `WatchSyncService` → `invokeMethod('syncPeople', jsonString)` где **`jsonString`** — **`jsonEncode(List<Map>)`**.

**Ожидание на iOS:** `call.method == "syncPeople"`, `call.arguments` приводится к **`String`**. Иначе — `FlutterMethodNotImplemented` или `FlutterError` с кодом `BAD_ARGS`.

**Эффект:** строка передаётся в **`syncPeopleToWatch`** → WatchConnectivity (см. ниже).

---

## iPhone Runner ↔ Виджет iPhone (App Group + home_widget)

| Элемент | Значение |
|---------|----------|
| App Group | `group.com.vlad.nastroi` |
| Ключ UserDefaults | `widget_people` |
| Запись | Flutter: `home_widget` (`WidgetService`: `HomeWidget.setAppGroupId`, `saveWidgetData`) |
| Чтение | Swift: `UserDefaults(suiteName: appGroupId)?.string(forKey: peopleKey)` |

### Формат JSON (`widget_people`)

Массив объектов (только люди с **`id != 'me'`** в Dart):

| Поле | Тип | Источник |
|------|-----|----------|
| `id` | string | `person.publicId` |
| `name` | string | `person.name` |
| `mood` | string | `person.mood.name` |
| `gender` | string | `person.gender.name` |
| `avatarVariant` | number | `person.avatarVariant` |
| `activeStage` | string или отсутствует | Вычисляется `_getActiveStage`, если цикл включён |

Swift-модель: **`PersonWidgetData`** в `NastroiWidget.swift`.

После записи: **`HomeWidget.updateWidget(iOSName: 'NastroiWidget')`**.

---

## iPhone Runner ↔ Apple Watch приложение (WatchConnectivity)

Передача из **`AppDelegate.sendPendingPeopleToWatch`**:

| Ключ в словаре | Тип | Содержимое |
|----------------|-----|------------|
| `people` | `String` | Тот же JSON, что пришёл из Flutter (`syncPeople`) |

Механизмы:

- **`WCSession.updateApplicationContext`**
- **`WCSession.transferUserInfo`**

Приём на часах: **`WatchPeopleStore`**, ключ `"people"` → **`updatePeople(from:)`**.

### Формат JSON для Watch (payload `syncPeople`)

Массив объектов (снова без `id == 'me'`):

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | string | `publicId` |
| `name` | string | |
| `mood` | string | enum `.name` |
| `gender` | string | |
| `avatarVariant` | number | |
| `activeStage` | string? | Заголовок этапа или `mood.name` |
| `helpfulActions` | массив строк | С этапа или с человека |
| `avoidActions` | массив строк | С этапа или с человека |

Swift: **`WatchPerson`** / декодер в **`WatchPeopleStore`**.

---

## Apple Watch приложение ↔ Виджет watchOS

Общее хранилище на часах:

| Ключ | Назначение |
|------|------------|
| `watch_people` | JSON-массив, сохранённый `WatchPeopleStore` после синка |
| `selected_widget_person_id` | Выбор пользователя в `ContentView` |

Чтение: **`NastroiWatchWidgetExtension`** (`Provider.loadSelectedPerson`). Приоритет: App Group, fallback — `UserDefaults.standard`.

Обновление UI виджета: **`WidgetCenter.shared.reloadAllTimelines()`** / **`reloadTimelines(ofKind:)`**.

---

## Deep link → Flutter Navigator

Внешний контракт для **`nastroi://person/<publicId>`** описан в [deep-links.md](deep-links.md). Виджет iPhone задаёт URL в **`widgetURL`**.

Импорт через **`https://...?data=`** парсится в Dart без отдельного нативного моста (если URI доходит до приложения).

Экран **`LinkPersonPreviewScreen`** после подтверждения «Добавить» **не** дергает канал **`nastroi_watch_sync`** и **не** обновляет **`widget_people`** через Flutter — только **`people_storage_v1`** в `SharedPreferences`.

---

## Модель Person (Dart) ↔ JSON хранилища

Сериализация основного списка — **`Person.toMap` / `Person.fromMap`** в ключе **`people_storage_v1`**. Полный набор полей см. **`lib/models/person.dart`** (включая `cycleStages`, флаги цикла и т.д.).
