# Диаграммы

Mermaid-схемы для документации. Рендеринг зависит от просмотрщика Markdown (GitHub, VS Code и т.д.).

## Общая архитектура

```mermaid
flowchart LR
  subgraph phone [iPhone]
    F[Flutter App]
    R[Runner + AppDelegate]
    IW[iOS Widget Extension]
  end
  subgraph shared [App Group]
    WK[widget_people]
  end
  subgraph watch_side [Apple Watch]
    WA[Watch App]
    WW[Watch Widget Extension]
    WD[watch_people / selected id]
  end
  F --> R
  F --> WK
  IW --> WK
  R -. WCSession .-> WA
  WA --> WD
  WW --> WD
```

Запись в **`widget_people`** из Flutter выполняется только цепочкой **`HomeScreen` → `WidgetService`** (стрелка «приложение → общее хранилище» на схеме упрощена).

## Запуск и инициализация Flutter

```mermaid
sequenceDiagram
  participant M as main()
  participant N as NotificationService
  participant A as NastroiApp
  M->>N: initialize()
  N-->>M: done
  M->>A: runApp()
  A->>A: _setupDeepLinks()
```

## Сохранение списка людей (HomeScreen)

```mermaid
sequenceDiagram
  participant H as HomeScreen
  participant P as PeopleRepository
  participant W as WidgetService
  participant WS as WatchSyncService
  participant NS as NotificationService
  participant AD as AppDelegate
  participant WC as WCSession
  H->>P: savePeople(people)
  H->>W: updatePeople(people)
  H->>WS: updatePeople(people)
  WS->>AD: syncPeople JSON
  AD->>WC: updateApplicationContext / transferUserInfo
  H->>NS: rescheduleCycleNotifications(people)
```

Экран **`LinkPersonPreviewScreen`** при «Добавить» вызывает только **`PeopleRepository.savePeople`** — шаги **`WidgetService` / Watch / reschedule`** не выполняются.

## Обновление виджета iPhone

```mermaid
flowchart LR
  WS[WidgetService.updatePeople]
  HW[home_widget]
  UD[(UserDefaults App Group)]
  WG[WidgetKit Timeline]
  WS --> HW
  HW --> UD
  HW --> WG
```

## Синхронизация с Apple Watch

```mermaid
sequenceDiagram
  participant F as Flutter
  participant MC as MethodChannel
  participant AD as AppDelegate
  participant WC as WCSession
  participant ST as WatchPeopleStore
  participant WCtr as WidgetCenter
  F->>MC: syncPeople(json)
  MC->>AD: handler
  AD->>WC: applicationContext + userInfo
  WC->>ST: delegate callback
  ST->>ST: save watch_people
  ST->>WCtr: reloadAllTimelines()
```

## Хранилища данных

```mermaid
flowchart TB
  subgraph flutter_storage [Flutter]
    SP[(SharedPreferences people_storage_v1)]
  end
  subgraph app_group [App Group]
    WK[widget_people]
    WP[watch_people]
    SEL[selected_widget_person_id]
  end
  FlutterApp --> SP
  FlutterApp --> WK
  WatchApp --> WP
  WatchApp --> SEL
  WatchWidget --> WP
  WatchWidget --> SEL
  IOSWidget --> WK
```

## Уведомления о цикле

```mermaid
flowchart TD
  R[rescheduleCycleNotifications]
  C[cancelAll]
  L[for each Person]
  S[scheduleCycleNotification]
  Z[zonedSchedule 09:00 next stage]
  R --> C
  R --> L
  L --> S
  S --> Z
```
