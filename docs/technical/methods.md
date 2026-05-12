# Методы и классы (ключевые)

Справочник по основным точкам входа и побочным эффектам. Полные сигнатуры — в исходниках.

## `main.dart`

### `main()`

| | |
|--|--|
| Назначение | Запуск приложения |
| Шаги | `WidgetsFlutterBinding.ensureInitialized()`, `NotificationService.initialize()`, `runApp(NastroiApp())` |
| Побочные эффекты | Инициализация плагина уведомлений |

### `_NastroiAppState._setupDeepLinks`

| | |
|--|--|
| Назначение | Подписка на входящие URI |
| Вход | — |
| Выход | `Future<void>` |
| Побочные эффекты | Подписка на `AppLinks`; при URI — `_openIncomingLink` → `Navigator.push` |
| Ошибки | Исключения при `getInitialLink` подавляются; ошибки stream — `onError: (_) {}` |

### `_openIncomingLink(Uri uri)`

| | |
|--|--|
| Назначение | Маршрутизация deep link |
| Ветки | `nastroi://person/...` → поиск в `PeopleRepository`; иначе импорт через `tryParsePersonFromUri` |
| Побочные эффекты | Навигация, чтение `SharedPreferences` через репозиторий |

---

## `PeopleRepository`

| Метод | Вход | Выход | Побочные эффекты |
|-------|------|-------|------------------|
| `loadPeople` | — | `Future<List<Person>>` | Чтение `SharedPreferences` |
| `savePeople` | `List<Person>` | `Future<void>` | Запись JSON в `people_storage_v1` |

Ошибки парсинга при load → возврат **`mockPeople`** (не пробрасывается наружу).

---

## `NotificationService`

| Метод | Назначение | Побочные эффекты |
|-------|------------|------------------|
| `initialize` | Обёртка над `init` | Инициализация timezone и плагина, запрос iOS-разрешений |
| `rescheduleCycleNotifications` | Перепланирование всех напоминаний | `cancelAll()`, затем до N вызовов `scheduleCycleNotification` |
| `scheduleCycleNotification` | Одно запланированное уведомление на следующую смену этапа | `zonedSchedule` в локальной TZ |

Условия no-op для одного человека: цикл выключен, нет этапов, нет даты старта, `_nextStageChange == null`.

---

## `WidgetService`

| Метод | Назначение | Побочные эффекты |
|-------|------------|------------------|
| `updatePeople` | Обновить данные для виджета iOS | Запись в App Group через `home_widget`, вызов native update виджета |

---

## `WatchSyncService`

| Метод | Назначение | Побочные эффекты |
|-------|------------|------------------|
| `updatePeople` | Отправить список друзей на Watch | `MethodChannel.invokeMethod`; при ошибке — `print`, исключение не пробрасывается |

---

## `Person` (`lib/models/person.dart`)

Важные методы для интеграций:

| Метод | Назначение |
|-------|------------|
| `toMap` / `fromMap` | Хранение в `PeopleRepository` |
| `toExportCode` / `fromExportCode` | Строка в query `data` ссылок и импорт |
| `applyLifeCycleForDate` | Приведение настроения к этапу на дату (используется на главном экране при загрузке/обновлении) |

---

## `HomeScreen._persist`

| | |
|--|--|
| Назначение | Сохранить текущий список и обновить платформу |
| Последовательность | `repository.savePeople` → `WidgetService.updatePeople` → `WatchSyncService.updatePeople` → `NotificationService.rescheduleCycleNotifications` |

Та же цепочка вызывается из **`_init()`** после загрузки из репозитория (иначе виджет/часы/уведомления синхронизируются с диском при старте).

**Не использует** эту цепочку экран **`LinkPersonPreviewScreen`** при **`_addPerson`** — только **`PeopleRepository.savePeople`**.

---

## Нативный iOS: `AppDelegate`

| Элемент | Назначение |
|---------|------------|
| `application(_:didFinishLaunchingWithOptions:)` | Активация `WCSession`, регистрация `FlutterMethodChannel` |
| `syncPeopleToWatch` | Сохранить JSON и попытаться отправить на Watch |
| `sendPendingPeopleToWatch` | `updateApplicationContext` + `transferUserInfo` при активной сессии и установленном приложении Watch |

---

## Нативный watchOS: `WatchPeopleStore`

| Метод / callback | Назначение |
|------------------|------------|
| `loadSavedPeople` | Восстановить JSON из UserDefaults при запуске |
| `session(_:didReceiveApplicationContext:)` | Обновить модель из телефона |
| `session(_:didReceiveUserInfo:)` | То же для очереди `transferUserInfo` |
| `updatePeople(from:)` | Декодирование, сохранение в defaults, `@Published people`, reload виджетов |
