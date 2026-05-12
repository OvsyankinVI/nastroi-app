# Уведомления

Реализация: **`NotificationService`** в `lib/services/notification_service.dart`.

Зависимости из `pubspec.yaml`: `flutter_local_notifications`, `timezone`.

## Типы уведомлений

В коде создаётся один сценарий: **напоминание о смене этапа жизненного цикла** человека.

- **Заголовок:** `У ${person.name} новый этап`
- **Текст:** название следующего этапа (`stage.title` или человекочитаемая метка настроения из `_moodLabel`)

## Инициализация

Вызывается из **`main.dart`** до `runApp`:

```dart
await NotificationService.initialize();
```

Внутри:

1. `timezone.initializeTimeZones()` из пакета `timezone`.
2. `FlutterLocalNotificationsPlugin.initialize` с **`DarwinInitializationSettings`** (alert, badge, sound).
3. Запрос разрешений iOS через `IOSFlutterLocalNotificationsPlugin.requestPermissions`.

В `InitializationSettings` в коде задан только блок **`iOS`**; конфигурация Android в этом файле явно не передаётся (поведение на Android определяется плагином и манифестом по умолчанию).

## Планирование

**`scheduleCycleNotification(Person person)`** вызывается только если:

- `person.lifeCycleEnabled == true`
- `person.cycleStages` не пустой
- `person.cycleStartDateIso` парсится в дату
- **`_nextStageChange`** возвращает следующую смену этапа

Дата и время уведомления: **календарный день** следующей смены, **09:00** локального времени (`tz.TZDateTime.from(..., tz.local)`).

Метод **`zonedSchedule`** использует `AndroidScheduleMode.inexactAllowWhileIdle` в вызове (релевантно для Android).

## Отмена и массовое перепланирование

**`rescheduleCycleNotifications(List<Person> people)`**:

1. **`_plugin.cancelAll()`** — снимает все запланированные уведомления плагина.
2. Для каждого человека вызывается **`scheduleCycleNotification`** (внутри снова проверки — часть людей может не получить ни одного scheduled notification).

Это вызывается **только** из **`HomeScreen`**: при первой загрузке после **`_init`** и при каждом **`_persist()`**.

Экран **`LinkPersonPreviewScreen`** после «Добавить» вызывает только **`PeopleRepository.savePeople`**, **`rescheduleCycleNotifications`** — нет. Расписание обновится после следующего **`HomeScreen._persist()`** или **`_init()`** (часто это полный перезапуск приложения с показом главного экрана).

## Идентификаторы

**`_notificationId(publicId)`** — `publicId.hashCode.abs() % 2^31`. Коллизии теоретически возможны при большом числе людей с конфликтующими хешами.

## Разрешения и ошибки

- Отказ пользователя в разрешениях iOS приведёт к тому, что уведомления не покажутся; код не ветвится на результат `requestPermissions` в явном виде.
- Неверная/пустая зона или проблемы планирования могут проявляться на уровне плагина ОС; в Dart-слое ошибки при `initialize`/`zonedSchedule` не обёрнуты в пользовательский UI в этом файле.

## Связь с моделью

Логика «какой следующий этап» завязана на **`cycleStages`**, **`cycleStartDateIso`** и циклический подсчёт дней (`_nextStageChange`, `_stageForDay`) — дублирует идею расчёта активного этапа в других частях приложения с отличиями в деталях (сравнить с `WidgetService._getActiveStage` / `WatchSyncService._activeStage` при изменениях).
