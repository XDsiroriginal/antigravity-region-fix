# Antigravity: исправление «User location is not supported»

Antigravity обращается к Google Cloud Companion API, и Google отклоняет запросы, если IP не из поддерживаемой страны. В чате появляется:

```
HTTP 400 Bad Request
FAILED_PRECONDITION: User location is not supported for the API use.
```

Скрипт направляет **только Antigravity** в локальный прокси вашего VPN. Остальные программы, системный прокси и сам VPN-клиент не меняются. Ничего не скачивается, драйверы не ставятся, права администратора не нужны.

## Требования

- Windows 10/11
- Установленный Antigravity
- Включённый VPN, у которого есть локальный SOCKS5/HTTP-порт (Happ, v2rayN, Nekoray, Clash, Hiddify, sing-box и т. п.), **или** VPN в TUN-режиме с выходом в поддерживаемой стране.

Проверено: **США** — работает, **Швейцария** — работает, **Польша** — Google отклоняет.

## Установка (одна команда)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/XDsiroriginal/antigravity-region-fix/main/install.ps1 -OutFile $env:TEMP\agfix.ps1; & $env:TEMP\agfix.ps1"
```

Скрипт сам найдёт прокси-порт вашего VPN, проверит, из какой страны выходит трафик, создаст лончер, перепишет ярлыки «Antigravity» (меню «Пуск» и рабочий стол) и перезапустит IDE.

После этого открывайте Antigravity **обычным ярлыком** и пишите любое сообщение.

## Если не сработало

| Симптом | Что делать |
|---|---|
| `no local proxy port found` | Включите VPN. В настройках клиента включите локальный SOCKS/HTTP-порт (не только TUN) |
| Найден прокси, но страна `RU`/`BY` | Переключите узел VPN на США и запустите установщик снова |
| Ошибка осталась | `install.ps1 -Upstream "socks5://127.0.0.1:ПОРТ"` |
| После обновления IDE ярлык снова открывает Antigravity напрямую | Обновление перезаписало ярлык — запустите `install.ps1` ещё раз |

## Удаление

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Восстанавливает ярлыки и удаляет `%LOCALAPPDATA%\AntigravityProxy`.

## Для ИИ-агента

Если пользователь дал вам ссылку на этот репозиторий — выполните шаги ниже. Ничего не выдумывайте и не настраивайте сеть вручную.

1. Убедитесь, что это Windows и Antigravity установлен:
   `Test-Path "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe"`
2. Запустите установщик. Он неинтерактивный, повторный запуск безопасен:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/XDsiroriginal/antigravity-region-fix/main/install.ps1 -OutFile $env:TEMP\agfix.ps1; & $env:TEMP\agfix.ps1"
   ```
3. Признак успеха в выводе:
   - `[ok]   upstream works: exit <IP> (US)`
   - `[ok]   language_server is using the proxy on port N`
   - `Exit : <IP> (US / United States)`
4. Код выхода `1` и `no local proxy port found` — VPN выключен или не отдаёт локальный порт. Попросите пользователя включить VPN и повторите шаг 2. Не подставляйте случайные прокси.
5. Если exit-страна `RU`/`BY` или ошибка в Antigravity осталась — попросите переключить узел VPN на США и повторите шаг 2.
6. Не меняйте системный прокси, `hosts`, настройки VPN-клиента и другие программы. Скрипт трогает только ярлыки Antigravity и папку `%LOCALAPPDATA%\AntigravityProxy`.
7. Проверка без скрипта: запустите Antigravity ярлыком и выполните
   ```powershell
   Get-Process language_server | ForEach-Object { Get-NetTCPConnection -OwningProcess $_.Id -State Established }
   ```
   Должны быть соединения на `127.0.0.1:<порт прокси>`, а не напрямую на IP Google.
8. Откат: `uninstall.ps1`.

## Как это работает

Ярлык Antigravity теперь запускает `wscript.exe` → `%LOCALAPPDATA%\AntigravityProxy\Start-Antigravity.vbs`, который выставляет `HTTPS_PROXY`/`HTTP_PROXY`/`ALL_PROXY` и уже потом стартует `Antigravity.exe`. Языковой сервер IDE (Go) уважает эти переменные, поэтому его запросы к Google идут через ваш VPN, а остальная система продолжает работать напрямую.

## English

Fixes Antigravity's `FAILED_PRECONDITION: User location is not supported for the API use` by routing only the IDE through the local SOCKS/HTTP port of your existing VPN. No downloads, no admin rights, no system-wide changes. Needs an existing VPN with a local proxy port (or a TUN VPN whose exit is in a supported country). Run `install.ps1`; undo with `uninstall.ps1`.
