# Окружение стороны логики

Обновление 26.09.2026: Android SDK установлен в `C:/Users/fpp/.cache/finni/android-sdk`.
Command-line tools 22.0, API 36, Build Tools 36.0.0, platform-tools 37.0.1,
NDK 28.2.13676358; Gradle 9.3.1 и JDK 17.0.20.1 проверены сборкой.
Лицензии приняты пользователем, Android toolchain проходит doctor.
Debug APK готов; [полные результаты](../../delivery/FINNI_ANDROID_HANDOFF.md).
Ниже сохранена историческая проверка до установки SDK.

Фактическая проверка обновлена 25.09.2026 на Windows 11 25H2 (`10.0.26200.9457`).

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
| JDK на хосте логики | переносимый Microsoft OpenJDK `17.0.20.1` вне Git; SHA-256 `3d9006956fc8af5601cd24ffc4f468bef48279c7ebd8171b9bdf90d0aabfbf1f` |
| Android SDK / adb | не найдены |
| Flutter PATH | SDK установлен переносимо вне Git; глобальный PATH не менялся |

`flutter doctor -v` подтвердил Flutter и Windows, но сообщил об отсутствии Android SDK. Android command-line tools и SDK packages не загружались: официальный процесс требует принятия Android SDK License Agreement пользователем. Рекомендуемый пакет на 25.09.2026 — `commandlinetools-win-15859902_latest.zip`, опубликованный SHA-256 — `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`.

Из-за кириллицы в родительском пути analysis server завершился с ошибкой LSP JSON. Повтор того же `flutter analyze` через временную ASCII-junction прошел без замечаний. Junction удалена после проверки; исходники не копировались.
