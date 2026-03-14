# ИС тестирования знаний — Terra Engineering

Windows desktop приложение на Python + Flet для тестирования знаний сотрудников ООО «Терра-Инжиниринг».

## Что делает система
Система предназначена для:
- авторизации сотрудников и администратора;
- управления пользователями;
- управления вопросами, ответами и категориями;
- назначения тестирований;
- прохождения тестов с таймером;
- расчёта результата и статуса прохождения;
- хранения истории прохождений;
- формирования отчётов и базовой аналитики (доступно только роли admin);
- локальной работы через SQLite;
- опциональной синхронизации в удалённую MySQL.

## Версия первого релиза
`v1.0.0`

Первый релиз ориентирован только на Windows desktop.

## Бизнес-параметры v1.0
- 2 роли: `admin`, `user`
- 17 текущих пользователей
- масштабирование до 100+ пользователей
- 160 вопросов в банке
- 20 вопросов в одном тесте
- 70% — порог прохождения
- 30 секунд на вопрос
- до 3 попыток на сотрудника

## Архитектурный подход
Приложение работает в модели `offline-first`.

### Основные правила
- локальная SQLite — основная operational database;
- удалённая MySQL — опциональная цель синхронизации;
- вход выполняется по локальной базе;
- отсутствие MySQL не блокирует вход;
- синхронизация запускается:
  - после успешной авторизации;
  - после завершения теста;
- при сбое синхронизации данные сохраняются локально и помечаются для повторной отправки.

Подробности: `docs/adr/002-data-sync.md`

### Флаги синхронизации
- `REMOTE_SYNC_ENABLED` и `REMOTE_DB_URL` включают/отключают удалённую синхронизацию в целом.
- `SYNC_AFTER_LOGIN` управляет попыткой batch-синхронизации после успешного входа.
  - Если `false`, синхронизация после логина не запускается и возвращается причина `disabled_by_flag`.
- `SYNC_AFTER_TEST_COMPLETION` управляет попыткой синхронизации сразу после завершения теста.
  - Если `false`, результат всё равно ставится в локальную очередь sync, но удалённая отправка пропускается с причиной `disabled_by_flag`.
- При выключенной общей удалённой синхронизации (`REMOTE_SYNC_ENABLED=false` или пустой `REMOTE_DB_URL`) возвращается причина `disabled`.


## Стек
- Python 3.11+
- Flet
- SQLAlchemy 2.x
- Pydantic 2.x
- Alembic
- SQLite
- MySQL
- pytest
- Ruff
- ReportLab
- OpenPyXL

## Быстрый старт
```bash
python -m venv .venv
.venv\Scripts\activate
pip install -U pip
pip install -e .[dev]
# Windows (CMD): copy .env.example .env
# PowerShell: Copy-Item .env.example .env
# Linux/macOS: cp .env.example .env
alembic upgrade head
python scripts/seed.py
python -m terra_testing
```

## Релиз
Перед созданием release обязательно запустите линтер локально:
```bash
ruff check .
```

```bash
python scripts/build_windows.py
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
# draft (recommended)
gh release create v1.0.0 dist/TerraTesting-win.zip dist/checksums.txt --title "v1.0.0" --notes-file docs/release-notes/v1.0.0.md --draft
```

Скрипт `scripts/build_windows.py` формирует `dist/TerraTesting-win.zip` и `dist/checksums.txt`.
