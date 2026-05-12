# Архитектура проекта «Настрой»

Приложение «Настрой» — Flutter-клиент с локальным хранением данных и нативными расширениями под iOS/watchOS. Сетевого backend в зависимостях и коде нет: данные живут на устройстве и синхронизируются с виджетами и часами через платформенные механизмы.

## Компоненты

| Компонент | Технология | Назначение |
|-----------|------------|------------|
| Основное приложение | Flutter (`lib/`) | UI, бизнес-логика людей и циклов, планирование уведомлений |
| Хост iOS | `ios/Runner` | Flutter engine, `MethodChannel`, WatchConnectivity |
| Виджет iPhone | Swift + WidgetKit (`ios/NastroiWidget`, target Xcode `NastroiWidgetExtension`) | Домашний экран iOS, конфигурация через App Intent |
| Приложение Watch | SwiftUI (`ios/NastroiWatch Watch App`) | Список людей, детали, выбор человека для complication |
| Виджет watchOS | Swift + WidgetKit (`ios/NastroiWatchWidgetExtension`) | Complication `accessoryCircular` |

## Слои Flutter

1. **Точка входа** — `lib/main.dart`: инициализация уведомлений, `MaterialApp`, подписка на deep links (`app_links`), глобальный `NavigatorKey`.
2. **Экраны** — `lib/screens/*.dart`, навигация через `Navigator.push` / bottom sheets.
3. **Данные** — `PeopleRepository` + `mock_people.dart`; сериализация моделей в JSON.
4. **Интеграции** — `NotificationService`, `WidgetService` (`home_widget`), `WatchSyncService` (`MethodChannel`).

Файл `lib/app.dart` содержит упрощённый `MaterialApp` с тёмной темой и **нигде не импортируется**; фактическая оболочка — в `main.dart`.

## Поток данных

1. Любой код может вызвать `PeopleRepository.savePeople` → запись в `SharedPreferences`.
2. Цепочка **`WidgetService.updatePeople` → `WatchSyncService.updatePeople` → `NotificationService.rescheduleCycleNotifications`** вызывается **только из `HomeScreen`**: при **`_init()`** после загрузки списка и при **`_persist()`**. Последний вызывается с главного экрана и после колбэков вроде **`onPersonUpdated`**, когда пользователь возвращается из профиля с сохранением — но **не** из **`LinkPersonPreviewScreen._addPerson`** (см. ниже).
3. Виджет iPhone читает JSON из App Group (`widget_people`), записанный через `home_widget` **только** после шага 2.
4. iPhone передаёт JSON на часы через `WCSession` (из `AppDelegate` после `syncPeople` с Flutter), Watch сохраняет `watch_people` и перезагружает таймлайны виджета часов.

### Исключение: `LinkPersonPreviewScreen`

Экран **`lib/screens/link_person_preview_screen.dart`** при нажатии **«Добавить»** вызывает только **`PeopleRepository.savePeople`** — **без** `WidgetService`, **без** `WatchSyncService`, **без** `NotificationService`. Плюс **`HomeScreen`** после возврата назад **не перечитывает** список из репозитория автоматически: добавленный человек может не появиться на сетке до полного перезапуска приложения или другого сценария, который снова инициализирует главный экран (это текущее поведение кода, не «особенность» документации).

Подробнее: [interfaces.md](interfaces.md), [data-storage.md](data-storage.md), [deep-links.md](deep-links.md).

## Диаграмма компонентов

```mermaid
flowchart TB
  subgraph flutter [Flutter]
    Home[HomeScreen]
    Repo[PeopleRepository]
    NS[NotificationService]
    WS[WidgetService]
    WSync[WatchSyncService]
  end
  subgraph prefs [(SharedPreferences)]
    SP[people_storage_v1]
  end
  subgraph ag [App Group group.com.vlad.nastroi]
    WK[widget_people]
    WP[watch_people]
    SEL[selected_widget_person_id]
  end
  subgraph ios [iOS Runner]
    AD[AppDelegate]
    WC[WCSession]
    MC[MethodChannel nastroi_watch_sync]
  end
  subgraph ext_i [iPhone Widget Extension]
    IW[NastroiWidget]
  end
  subgraph watch_app [watchOS App]
    Store[WatchPeopleStore]
  end
  subgraph ext_w [watchOS Widget Extension]
    WW[NastroiWatchWidgetExtension]
  end
  Home --> Repo
  Repo --> SP
  Home --> NS
  Home --> WS
  Home --> WSync
  WS --> WK
  IW --> WK
  WSync --> MC --> AD --> WC
  WC --> Store
  Store --> WP
  Store --> SEL
  WW --> WP
  WW --> SEL
```

Другие экраны используют `PeopleRepository` и колбэки в `HomeScreen`, но **не** вызывают напрямую сервисы виджета, часов и уведомлений — только цепочка из `HomeScreen._persist()` / `_init()`.

## Связанные документы

- [project-structure.md](project-structure.md) — дерево каталогов
- [services.md](services.md) — сервисы Flutter
- [diagrams.md](diagrams.md) — дополнительные Mermaid-схемы
