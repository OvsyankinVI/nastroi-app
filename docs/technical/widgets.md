# Виджеты

В проекте два виджета на двух платформах Apple: **домашний экран iPhone** и **complication на Apple Watch**.

## Виджет iPhone (WidgetKit)

**Расположение исходников:** `ios/NastroiWidget/`  
**Xcode target:** `NastroiWidgetExtension` (продукт `.appex`)  
**Kind (идентификатор виджета):** `NastroiWidget` — должен совпадать с **`HomeWidget.updateWidget(iOSName: 'NastroiWidget')`** в `WidgetService`.

### Конфигурация

- **`AppIntentConfiguration`** с интентом **`SelectPersonIntent`** — пользователь выбирает человека в настройках виджета.
- **`supportedFamilies`:** только **`.systemSmall`**.

### Данные

- Чтение из **`UserDefaults(suiteName: "group.com.vlad.nastroi")`**, ключ **`widget_people`**.
- JSON декодируется в **`[PersonWidgetData]`** (`id`, `name`, `mood`, `gender`, `avatarVariant`, `activeStage?`).

Запись выполняется из Flutter: **`WidgetService.updatePeople`** через пакет **`home_widget`** (см. [data-storage.md](data-storage.md)).

### Обновление таймлайна

`Timeline` с политикой **`.after(now + 15 минут)`** (`60 * 15` секунд в коде). Это лишь **запрос** к WidgetKit: фактическая частота обновления зависит от батареи, фона и политики системы.

Интеграция **`home_widget`** в Dart вызывает **`updateWidget(iOSName: 'NastroiWidget')`** — это привязка к **iOS**-виджету; отдельной записи в App Group для Android в этом проекте нет.

### Отображение

SwiftUI: аватар из asset по шаблону `gender_avatarVariant_mood`, имя, опционально строка этапа; при отсутствии картинки — emoji по настроению.

### Открытие приложения

**`widgetURL`:** `nastroi://person/<id>` (`id` из данных = `publicId`). Обрабатывается в **`main.dart`**.

---

## Виджет watchOS (complication)

**Расположение:** `ios/NastroiWatchWidgetExtension/`  
**Kind:** `NastroiWatchWidgetExtension` (используется при **`reloadTimelines(ofKind:)`** из приложения Watch).

### Семейство

Только **`.accessoryCircular`** — круглая complication.

### Данные

- Ключ **`watch_people`** — JSON массива **`WatchWidgetPerson`** (включая `helpfulActions`, `avoidActions`).
- Ключ **`selected_widget_person_id`** — какого человека показывать; если нет или не найден — **первый** из списка.

Источник `watch_people` на часах — сохранённый после синка JSON из iPhone (см. [apple-watch.md](apple-watch.md)). Flutter напрямую этот ключ не пишет.

### Обновление таймлайна (код расширения)

`getTimeline` задаёт **`Timeline`** с политикой **`.after(now + 60 секунд)`**. Как и на iPhone, система может обновлять реже.

Дополнительно после приёма данных в **`WatchPeopleStore.updatePeople`** вызывается **`WidgetCenter.shared.reloadAllTimelines()`** (и при выборе человека для виджета — **`reloadTimelines(ofKind:)`**).

### UI

Круг с градиентом по настроению, изображение аватара (`*_complication` при наличии, иначе обычное имя asset), placeholder — системная иконка `person.fill`.

---

## Ограничения (iOS / watchOS)

- **WidgetKit** ограничивает бюджет фоновых обновлений; таймлайн «через N минут» не означает гарантированное срабатывание в момент N.
- Виджет **iPhone**: только **`systemSmall`** — средний/большой размер в коде не объявлен.
- **Complication**: только **`accessoryCircular`** — другие семейства не поддерживаются.
- Данные виджета iPhone — снимок на момент последнего **`WidgetService.updatePeople`** с телефона; локальный расчёт цикла в расширении не выполняется.
- Пока **`HomeScreen`** не выполнил **`_persist()`** после изменений (в т.ч. после импорта только через **`LinkPersonPreviewScreen`**), App Group **`widget_people`** может оставаться старым.
