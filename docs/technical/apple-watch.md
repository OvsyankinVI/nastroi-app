# Apple Watch

## Приложение watchOS

**Папка:** `ios/NastroiWatch Watch App/`  
**Точка входа:** `NastroiWatchApp.swift` — `@main` структура приложения, `WindowGroup` с **`ContentView`** и **`WatchPeopleStore`** в `environmentObject`.

### Экраны (SwiftUI)

По `ContentView.swift` и связанным типам:

1. **Пустое состояние** — если `watchStore.people.isEmpty`: текст про открытие iPhone-приложения и добавление людей.
2. **Список людей** — `NavigationStack`, `List` с переходом на детальный экран.
3. **`PersonDetailView`** — отображение человека (аватар, настроение, этап и т.д.), переход к спискам рекомендаций.
4. **`RecommendationsListView`** — вложенная навигация для полезных действий и того, чего избегать (данные из модели `WatchPerson`).

### Выбор человека для complication

Жест **swipe** «В виджет» или пункт контекстного меню «Показать в виджете»:

- В App Group и standard `UserDefaults` пишется **`selected_widget_person_id`**
- Вызывается **`WidgetCenter.shared.reloadTimelines(ofKind: "NastroiWatchWidgetExtension")`** и **`reloadAllTimelines()`**

---

## Обмен данными с iPhone

### Отправка с iPhone

**`ios/Runner/AppDelegate.swift`:**

- Регистрируется **`FlutterMethodChannel`** с именем **`nastroi_watch_sync`** (тот же, что в `WatchSyncService`).
- При вызове **`syncPeople`** с аргументом-строкой JSON вызывается **`syncPeopleToWatch`**, которая сохраняет строку в **`pendingPeopleJson`** и пытается **`sendPendingPeopleToWatch()`**.

**`sendPendingPeopleToWatch()`** выполняется только если:

- `WCSession.default.activationState == .activated`
- `session.isWatchAppInstalled == true`

Передача:

- **`updateApplicationContext(["people": jsonString])`**
- **`transferUserInfo(["people": jsonString])`**

Ошибки при `updateApplicationContext` игнорируются в коде (пустой `catch`).

После активации сессии **`activationDidComplete`** снова вызывается отправка отложенных данных.

### Приём на часах

**`WatchPeopleStore.swift`** реализует **`WCSessionDelegate`**:

- **`didReceiveApplicationContext`** — извлекает `"people"` как строку → **`updatePeople(from:)`**
- **`didReceiveUserInfo`** — то же

**`updatePeople`:**

- Декодирует **`[WatchPerson]`**
- Сохраняет JSON в **`UserDefaults(suiteName: appGroupId)`** и **`UserDefaults.standard`** под ключом **`watch_people`**
- На main queue обновляет **`people`** и вызывает **`WidgetCenter.shared.reloadAllTimelines()`**

При старте **`loadSavedPeople()`** поднимает последнее сохранённое состояние из тех же хранилищ.

---

## Виджет watchOS (complication)

Описание UI и ключей — в [widgets.md](widgets.md). Связь с приложением Watch: общие **`watch_people`** и **`selected_widget_person_id`** в App Group.

---

## Ограничения

- Данные не уходят на часы, если приложение Watch не установлено или сессия не активирована — JSON остаётся в **`pendingPeopleJson`** до успешной активации (**память процесса iPhone**; после выгрузки приложения без нового вызова **`syncPeople`** из Flutter отложенная строка может быть потеряна).
- **`transferUserInfo`** ставит данные в очередь доставки при недоступности часов; порядок и задержки задаёт **watchOS/iOS**, не приложение.
- Для связи телефона и часов нужна типичная для пары **Bluetooth/Wi‑Fi** связность в рамках экосистемы Apple; при полном разрыве доставка откладывается.
- Нет собственного экрана «настроек» синка — источник истины по составу людей на телефоне в **`PeopleRepository`**; Watch показывает последний принятый JSON.

Если пользователь добавил человека только через **`LinkPersonPreviewScreen`**, **`syncPeople`** на iPhone может **не** вызываться до следующего **`HomeScreen._persist()`** — на часах список останется прежним при том же раскладе.
