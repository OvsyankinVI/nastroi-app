# Сервисы

В проекте нет отдельного слоя «repository service» для сети: персистентность списка людей реализована классом **`PeopleRepository`** в `lib/data/people_repository.dart` (это не файл в `services/`, но выполняет роль хранилища).

Ниже — три класса из `lib/services/` и связь с данными.

## PeopleRepository (`lib/data/people_repository.dart`)

Не в папке `services`, но это основной сервис данных приложения.

- **`loadPeople()`** — читает JSON из `SharedPreferences` по ключу `people_storage_v1`; при отсутствии данных или ошибке парсинга возвращает копию `mockPeople`.
- **`savePeople(List<Person>)`** — сериализует список через `Person.toMap` / `jsonEncode` и сохраняет строку.

Использование **`savePeople` / `loadPeople`**: `HomeScreen`, `main.dart` (поиск по `publicId` для deep link), `LinkPersonPreviewScreen` (только сохранение при «Добавить», без сервисов ниже).

## NotificationService (`lib/services/notification_service.dart`)

Зависимости: `flutter_local_notifications`, `timezone`.

- **`initialize()`** / **`init()`** — инициализация плагина; для iOS — `DarwinInitializationSettings`, запрос разрешений через `IOSFlutterLocalNotificationsPlugin.requestPermissions`.
- **`rescheduleCycleNotifications(List<Person> people)`** — **`cancelAll()`**, затем для каждого человека **`scheduleCycleNotification`**.
- **`scheduleCycleNotification(Person person)`** — планирует одно уведомление, если включён жизненный цикл (`lifeCycleEnabled`), есть этапы и дата старта; время — **09:00** в локальной зоне на дату следующей смены этапа (логика `_nextStageChange`).

Идентификатор уведомления: хеш от `person.publicId` (ограничение по модулю 2³¹).

**`rescheduleCycleNotifications`** вызывается только из **`HomeScreen`** (`_init` / `_persist`). Экран **`LinkPersonPreviewScreen`** после «Добавить» уведомления **не** перепланирует.

Подробнее: [notifications.md](notifications.md).

## WidgetService (`lib/services/widget_service.dart`)

Зависимость: `home_widget`.

Константы:

- **`appGroupId`** — `group.com.vlad.nastroi`
- **`peopleKey`** — `widget_people`

**`updatePeople(List<Person> people)`**:

1. `HomeWidget.setAppGroupId(appGroupId)`
2. Фильтр: только люди с **`id != 'me'`** (профиль «Я» в виджет не попадает).
3. Формируется JSON-массив объектов: `id` (это **`publicId`**), `name`, `mood`, `gender`, `avatarVariant`, опционально `activeStage` при включённом цикле.
4. `HomeWidget.saveWidgetData(peopleKey, jsonEncode(data))`
5. `HomeWidget.updateWidget(iOSName: 'NastroiWidget')` — должно совпадать с **`kind`** виджета в Swift.

Вызывается **только** из `HomeScreen` при **`_init()`** после нормализации списка и в **`_persist()`**: других мест вызова в репозитории нет.

## WatchSyncService (`lib/services/watch_sync_service.dart`)

Канал: **`MethodChannel('nastroi_watch_sync')`**, метод **`syncPeople`**, аргумент — **одна строка JSON** (массив объектов).

**`updatePeople(List<Person> people)`**:

1. Фильтр **`id != 'me'`** (как у виджета iPhone).
2. Поля каждого элемента: `id` (`publicId`), `name`, `mood`, `gender`, `avatarVariant`, `activeStage` (заголовок этапа или имя настроения), `helpfulActions`, `avoidActions` (с учётом активного этапа цикла).
3. `invokeMethod('syncPeople', jsonEncode(data))`; ошибки ловятся, в консоль пишется `print`.

Нативная обработка: `ios/Runner/AppDelegate.swift` — передача на Watch через `WCSession`.

**`WatchSyncService.updatePeople`** вызывается из тех же мест **`HomeScreen`**, что и **`WidgetService.updatePeople`** (`_init` / `_persist`).

Подробнее: [apple-watch.md](apple-watch.md), [interfaces.md](interfaces.md).

## Deep links

Отдельного класса «DeepLinkService» нет. Обработка в **`lib/main.dart`** (`AppLinks`, метод **`_openIncomingLink`**). Форматы ссылок — в [deep-links.md](deep-links.md).
