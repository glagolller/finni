# Окружение стороны логики

Фактическая проверка 24.09.2026 на Windows 11 25H2 (`10.0.26200.9457`).

| Компонент | Результат |
| --- | --- |
| Git | `2.54.0.windows.1` |
| GitHub CLI | `2.96.0`, авторизация `ignatenkof` подтверждена |
| Flutter | `3.47.5` stable, revision `6a19cca56475dbfba1478ee68d7bd0c2ef891da1` |
| Dart | `3.13.4` |
| DevTools | `2.60.0` |
| Android Gradle Plugin | `9.1.0` |
| Kotlin plugin | `2.4.0` |
| Java target | 17 в Gradle-конфигурации |
| JDK на хосте логики | не найден |
| Android SDK / adb | не найдены |
| Flutter PATH | SDK установлен переносимо вне Git; глобальный PATH не менялся |

`flutter doctor -v` подтвердил Flutter и Windows, но сообщил об отсутствии Android SDK. Проверка network resources внутри sandbox дала DNS-ошибку, хотя загрузка SDK и pub-пакетов через разрешенное сетевое выполнение прошла успешно.

Из-за кириллицы в родительском пути analysis server завершился с ошибкой LSP JSON. Повтор того же `flutter analyze` через временную ASCII-junction прошел без замечаний. Junction удалена после проверки; исходники не копировались.
