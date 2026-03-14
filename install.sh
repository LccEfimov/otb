diff --git a/.env.example b/.env.example
new file mode 100644
index 0000000000000000000000000000000000000000..1045ee6f0752a72b1c5e98c64b6a5643d4c9c7eb
--- /dev/null
+++ b/.env.example
@@ -0,0 +1,45 @@
+# App
+APP_NAME=TerraTesting
+APP_ENV=development
+APP_DEBUG=true
+APP_LANGUAGE=ru
+APP_TIMEZONE=Europe/Moscow
+
+# Local SQLite
+LOCAL_DB_ENABLED=true
+LOCAL_DB_URL=sqlite:///./data/training_system.db
+
+# Remote MySQL sync
+REMOTE_SYNC_ENABLED=false
+REMOTE_DB_URL=mysql+pymysql://user:password@127.0.0.1:3306/terra_testing
+
+# Security
+PASSWORD_HASH_SCHEME=bcrypt
+SECRET_KEY=change-me
+SESSION_TIMEOUT_MINUTES=60
+
+# Quiz rules
+QUESTIONS_PER_TEST=20
+PASS_PERCENT=70
+SECONDS_PER_QUESTION=30
+MAX_ATTEMPTS=3
+
+# Paths
+EXPORT_DIR=./data/exports
+BACKUP_DIR=./data/backup
+LOG_DIR=./logs
+
+# Demo seed
+SEED_ADMIN_LOGIN=admin
+SEED_ADMIN_PASSWORD=Admin123!
+SEED_USER_LOGIN=user01
+SEED_USER_PASSWORD=User123!
+
+# Sync behavior
+SYNC_RETRY_LIMIT=3
+SYNC_AFTER_LOGIN=true
+SYNC_AFTER_TEST_COMPLETION=true
+
+# Reports
+REPORT_PDF_ENABLED=true
+REPORT_EXCEL_ENABLED=true
diff --git a/.github/workflows/build-windows.yml b/.github/workflows/build-windows.yml
new file mode 100644
index 0000000000000000000000000000000000000000..4c553c8b0c03f2db4e928e267c20c56d8b0916af
--- /dev/null
+++ b/.github/workflows/build-windows.yml
@@ -0,0 +1,39 @@
+name: Build Windows
+
+on:
+  workflow_dispatch:
+  push:
+    branches:
+      - main
+      - develop
+      - "release/**"
+
+permissions:
+  contents: read
+
+jobs:
+  build-windows:
+    runs-on: windows-latest
+    steps:
+      - uses: actions/checkout@v6
+      - uses: actions/setup-python@v6
+        with:
+          python-version: "3.11"
+          cache: "pip"
+      - shell: pwsh
+        run: |
+          python -m pip install --upgrade pip
+          pip install -e .[dev]
+      - shell: pwsh
+        run: Copy-Item .env.example .env
+      - shell: pwsh
+        run: alembic upgrade head
+      - shell: pwsh
+        run: python scripts/seed.py
+      - shell: pwsh
+        run: python scripts/build_windows.py
+      - uses: actions/upload-artifact@v6
+        with:
+          name: terra-testing-windows-build
+          path: dist/**
+          if-no-files-found: error
diff --git a/.github/workflows/lint.yml b/.github/workflows/lint.yml
new file mode 100644
index 0000000000000000000000000000000000000000..b4b13b5362d1c364fa3f14a399e37de13d7b799b
--- /dev/null
+++ b/.github/workflows/lint.yml
@@ -0,0 +1,28 @@
+name: Lint
+
+on:
+  push:
+    branches:
+      - main
+      - develop
+      - "feature/**"
+      - "release/**"
+  pull_request:
+
+permissions:
+  contents: read
+
+jobs:
+  lint:
+    runs-on: ubuntu-latest
+    steps:
+      - uses: actions/checkout@v6
+      - uses: actions/setup-python@v6
+        with:
+          python-version: "3.11"
+          cache: "pip"
+      - run: |
+          python -m pip install --upgrade pip
+          pip install -e .[dev]
+      - run: ruff check .
+      - run: ruff format --check .
diff --git a/.github/workflows/release.yml b/.github/workflows/release.yml
new file mode 100644
index 0000000000000000000000000000000000000000..72572914893a7d8095cad786483177afec2ea15e
--- /dev/null
+++ b/.github/workflows/release.yml
@@ -0,0 +1,53 @@
+name: Release
+
+on:
+  push:
+    tags:
+      - "v*"
+
+permissions:
+  contents: write
+
+jobs:
+  release:
+    runs-on: windows-latest
+    steps:
+      - uses: actions/checkout@v6
+        with:
+          fetch-depth: 0
+      - uses: actions/setup-python@v6
+        with:
+          python-version: "3.11"
+          cache: "pip"
+      - shell: pwsh
+        run: |
+          python -m pip install --upgrade pip
+          pip install -e .[dev]
+      - shell: pwsh
+        run: Copy-Item .env.example .env
+      - shell: pwsh
+        env:
+          APP_ENV: test
+          LOCAL_DB_URL: sqlite:///./data/test.db
+          REMOTE_SYNC_ENABLED: "false"
+        run: |
+          alembic upgrade head
+          python scripts/seed.py
+          pytest -q --maxfail=1 --disable-warnings
+          python scripts/build_windows.py
+      - shell: pwsh
+        run: |
+          New-Item -ItemType Directory -Force -Path dist | Out-Null
+          Get-ChildItem -Path dist -File -Recurse |
+            Get-FileHash -Algorithm SHA256 |
+            ForEach-Object { "$($_.Hash)  $($_.Path)" } |
+            Set-Content dist/checksums.txt
+      - shell: pwsh
+        env:
+          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
+        run: |
+          $files = Get-ChildItem -Path dist -File -Recurse | ForEach-Object { $_.FullName }
+          gh release create "${{ github.ref_name }}" `
+            $files `
+            --title "${{ github.ref_name }}" `
+            --notes-file "docs/release-notes/${{ github.ref_name }}.md"
diff --git a/.github/workflows/test.yml b/.github/workflows/test.yml
new file mode 100644
index 0000000000000000000000000000000000000000..5f225b937d1d88763c341bff58ab6f6114611c51
--- /dev/null
+++ b/.github/workflows/test.yml
@@ -0,0 +1,34 @@
+name: Tests
+
+on:
+  push:
+    branches:
+      - main
+      - develop
+      - "feature/**"
+      - "release/**"
+  pull_request:
+
+permissions:
+  contents: read
+
+jobs:
+  tests:
+    runs-on: ubuntu-latest
+    steps:
+      - uses: actions/checkout@v6
+      - uses: actions/setup-python@v6
+        with:
+          python-version: "3.11"
+          cache: "pip"
+      - run: |
+          python -m pip install --upgrade pip
+          pip install -e .[dev]
+      - run: cp .env.example .env
+      - run: alembic upgrade head
+      - run: python scripts/seed.py
+      - env:
+          APP_ENV: test
+          LOCAL_DB_URL: sqlite:///./data/test.db
+          REMOTE_SYNC_ENABLED: "false"
+        run: pytest -q --maxfail=1 --disable-warnings
diff --git a/AGENTS.md b/AGENTS.md
new file mode 100644
index 0000000000000000000000000000000000000000..9abdae11d843497fb933226cf6f230b9818c2986
--- /dev/null
+++ b/AGENTS.md
@@ -0,0 +1,107 @@
+# AGENTS.md
+
+## Project
+Информационная система тестирования знаний для ООО «Терра-Инжиниринг».
+
+## Product goal
+Собрать и выпустить production-ready v1.0 Windows desktop приложения на Python + Flet для:
+- авторизации пользователей;
+- управления вопросами, сотрудниками и графиком тестирования;
+- прохождения тестов сотрудниками;
+- хранения результатов и истории;
+- формирования отчётов;
+- локальной работы через SQLite;
+- опциональной синхронизации в удалённую MySQL.
+
+## Scope of v1.0
+Обязательно входит:
+- Windows desktop release;
+- login/password auth;
+- roles: admin, user;
+- SQLite as primary operational database;
+- optional MySQL synchronization;
+- CRUD users;
+- CRUD questions / answers / categories;
+- test scheduling;
+- quiz flow;
+- scoring and pass/fail status;
+- history and reports;
+- PDF / Excel export;
+- audit log;
+- backup;
+- automated tests;
+- CI workflows;
+- GitHub Release v1.0.0.
+
+Не входит в v1.0:
+- face recognition;
+- gesture control;
+- voice control;
+- periodic camera photo capture;
+- WebGL / 3D / VR / AR;
+- AI adaptive questions;
+- mobile build;
+- PWA;
+- email integration;
+- 1C / HRM integration.
+
+## Business rules
+- Авторизация всегда выполняется по локальной SQLite.
+- Удалённая MySQL не должна блокировать вход.
+- Синхронизация выполняется только:
+  1. после успешной авторизации;
+  2. после завершения теста.
+- При недоступности MySQL приложение продолжает работать локально.
+- Ошибки sync логируются.
+- Несинхронизированные сущности должны быть помечены статусом pending/failed.
+- Результаты тестов, сохранённые локально, не должны теряться из-за ошибок sync.
+
+## Functional baseline
+- 2 роли: admin, user.
+- 17 текущих пользователей, масштабирование до 100+.
+- 160 вопросов в банке.
+- 20 вопросов в тесте.
+- 70% — порог прохождения.
+- 30 секунд на вопрос.
+- До 3 попыток на сотрудника.
+
+## Technology decisions
+- Python 3.11+
+- Flet
+- SQLAlchemy 2.x
+- Pydantic 2.x
+- Alembic migrations
+- pytest
+- Ruff
+- bcrypt / passlib or equivalent secure password hashing
+- report generation for PDF and Excel
+- env-based configuration
+- repository/service architecture
+
+## Repository expectations
+Repo must contain:
+- `pyproject.toml`
+- `.env.example`
+- `README.md`
+- `CHANGELOG.md`
+- `docs/`
+- `tests/`
+- `scripts/`
+- `.github/workflows/`
+
+## Quality bar
+Before considering the task done:
+- app starts locally from a documented command;
+- SQLite database is initialized automatically or via a documented command;
+- seed data exists;
+- demo admin and demo users exist;
+- login works;
+- admin flows work;
+- user can complete a test end-to-end;
+- results persist locally;
+- sync attempts run in the required two moments;
+- sync failures do not break primary user flows;
+- tests pass;
+- CI is green;
+- Windows artifact is built;
+- release notes are prepared.
diff --git a/CHANGELOG.md b/CHANGELOG.md
new file mode 100644
index 0000000000000000000000000000000000000000..04c7d29c4d2c2ab20928ea4360089cdcf7e42121
--- /dev/null
+++ b/CHANGELOG.md
@@ -0,0 +1,58 @@
+# Changelog
+
+All notable changes to this project will be documented in this file.
+
+## [1.0.0] - 2026-03-14
+
+### Added
+- Windows desktop release target
+- local SQLite operational database
+- local login/password authentication
+- admin and user roles
+- user management
+- question/category/answer management
+- test scheduling
+- quiz flow with assignment constraints
+- result scoring and pass/fail status
+- test history
+- PDF and Excel export
+- audit logging
+- backup utilities
+- optional MySQL synchronization
+- CI workflows
+- release packaging
+- route guards for protected pages
+- sync monitor with retry actions
+- edit flow for users and questions
+
+### Changed
+- adopted offline-first architecture
+- limited first release to Windows desktop only
+- defined sync triggers: after login and after test completion
+- settings password change now validates current password
+- admin results and sync pages now expose richer filtering and summaries
+
+### Fixed
+- primary user flow no longer depends on remote DB availability
+- session form state for user/question editing now resets predictably
+
+### Known limitations
+- no biometric login
+- no gesture control
+- no voice control
+- no camera monitoring
+- no PWA or mobile builds
+- no AI adaptive testing
+- no complex bidirectional conflict resolution
+- no production-grade remote MySQL write schema yet
+
+### Added in iterative scaffolding
+- live countdown timer skeleton on quiz page
+- assignment edit flow and status updates
+- date filters for admin results and reports
+- audit entries for sync retry and assignment updates
+
+### Added in scaffold updates
+- sync queue model and repository for offline-first retry tracking
+- audit log export to PDF and Excel
+- shared access helpers for authenticated/user/admin page guards
diff --git a/PROMPT_CODEX_RELEASE.md b/PROMPT_CODEX_RELEASE.md
new file mode 100644
index 0000000000000000000000000000000000000000..015864f224c346ab3c48b6d5cae0b5cc0b7eb61d
--- /dev/null
+++ b/PROMPT_CODEX_RELEASE.md
@@ -0,0 +1,200 @@
+# Prompt для запуска Codex с обязательным финальным GitHub Release
+
+Ниже — готовый prompt, который можно целиком отдать Codex.
+
+## Как использовать
+1. Открой репозиторий в Codex.
+2. Передай Codex этот prompt целиком.
+3. Не сокращай prompt и не убирай финальный релизный блок.
+4. Если у Codex нет прав на публикацию release, он должен подготовить всё до состояния «остаётся выполнить одну команду».
+
+## Готовый prompt
+
+```text
+Ты работаешь как ведущий Python/Flet инженер, тестировщик, release engineer и GitHub maintainer.
+
+Твоя задача:
+взять текущий репозиторий проекта, довести его до production-ready состояния для v1.0.0, устранить дефекты, завершить недостающие части, прогнать проверки, подготовить Windows desktop релиз и в конце выпустить GitHub Release.
+
+Источники истины внутри репозитория:
+- AGENTS.md
+- TASK.md
+- README.md
+- docs/requirements.md
+- docs/scope_v1.md
+- docs/adr/001-architecture.md
+- docs/adr/002-data-sync.md
+- docs/adr/003-release-strategy.md
+- docs/release-notes/v1.0.0.md
+- CHANGELOG.md
+
+Работай по этим правилам.
+
+1. Общая цель
+Нужно завершить v1.0.0 Windows desktop приложения “ИС тестирования знаний” на Python + Flet.
+Система должна:
+- работать как Windows desktop app;
+- использовать SQLite как основную локальную БД;
+- использовать MySQL только как optional sync target;
+- авторизовывать по локальной SQLite;
+- выполнять попытку sync только:
+  - после успешного логина;
+  - после завершения теста;
+- не ломать основной сценарий, если MySQL отсутствует или недоступна.
+
+2. Scope v1.0 обязателен
+Входит:
+- login/password auth
+- роли admin/user
+- user CRUD
+- question/category/answer CRUD
+- test scheduling
+- quiz flow
+- pass/fail scoring
+- history/results
+- reports PDF/Excel
+- audit log
+- backup/restore
+- Windows packaging
+- CI
+- GitHub Release
+
+Не входит:
+- биометрия
+- gesture/voice control
+- photo surveillance
+- WebGL/3D/VR/AR
+- mobile build
+- PWA
+- AI adaptive testing
+- enterprise integrations
+
+Не расширяй scope v1.0 без крайней необходимости.
+
+3. Режим работы
+Работай по этапам и после каждого этапа обновляй:
+- CHANGELOG.md
+- README.md, если это влияет на запуск/сборку/релиз
+- docs, если меняется архитектура или правила эксплуатации
+
+4. Архитектурные требования
+Соблюдай:
+- layered architecture
+- thin Flet pages
+- business logic in services
+- persistence in repositories
+- sync logic isolated in sync layer
+- typed Python where practical
+- no dangerous hidden coupling between UI and DB
+
+5. Что нужно сделать по коду
+Проверь и доведи до рабочего состояния:
+- маршрутизацию и route guards;
+- login/logout/session flow;
+- admin pages;
+- user pages;
+- quiz flow и timer behavior;
+- scheduling rules;
+- result persistence;
+- sync queue/sync monitor;
+- audit log recording;
+- report generation;
+- backup/restore;
+- settings/password change;
+- migrations;
+- seed data;
+- tests.
+
+Исправляй найденные архитектурные и runtime дефекты, а не маскируй их.
+
+6. Quality gates
+До релиза обязательно:
+- проект устанавливается;
+- миграции применяются;
+- seed отрабатывает;
+- приложение запускается;
+- линтер проходит;
+- тесты проходят;
+- Windows build формируется;
+- release notes готовы;
+- changelog обновлён.
+
+7. Definition of Done
+Считай задачу выполненной только если:
+- приложение реально готово к v1.0.0;
+- все ключевые сценарии доведены;
+- CI workflows не противоречат текущей структуре проекта;
+- есть готовые release artifacts;
+- есть tag v1.0.0;
+- создан GitHub Release или полностью подготовлен draft release.
+
+8. Поведение по Git и коммитам
+- Делай небольшие осмысленные коммиты.
+- Не оставляй мусорные временные файлы.
+- Не ломай документацию.
+- Не удаляй ADR/requirements без причины.
+- Сохраняй понятную историю изменений.
+
+9. Release workflow обязателен
+В конце работы ты ОБЯЗАН:
+1. привести репозиторий в зелёное состояние;
+2. обновить CHANGELOG.md;
+3. финализировать docs/release-notes/v1.0.0.md;
+4. убедиться, что версия v1.0.0 согласована в проекте;
+5. создать git tag:
+   git tag -a v1.0.0 -m "Release v1.0.0"
+6. push tag в origin;
+7. собрать Windows release artifacts;
+8. приложить артефакты к GitHub Release;
+9. создать GitHub Release с title `v1.0.0`.
+
+10. Публикация GitHub Release
+Предпочтительный порядок:
+- сначала подготовить draft release;
+- приложить все assets;
+- затем publish release.
+
+В release обязательно включи:
+- Windows artifact
+- source archive
+- checksums
+- release notes
+
+11. Если прав на публикацию релиза нет
+Если ты не можешь опубликовать релиз автоматически, ты НЕ должен останавливаться на полпути.
+В этом случае ты обязан:
+- подготовить все release assets;
+- создать tag локально;
+- подготовить точную команду для публикации через GitHub CLI;
+- подготовить финальный текст release notes;
+- явно перечислить, что уже сделано и что осталось сделать вручную.
+
+12. Команды релиза
+Используй подходящий способ, например:
+- GitHub Actions release workflow
+или
+- GitHub CLI
+
+Пример CLI-команды:
+gh release create v1.0.0 dist/TerraTesting-win.zip dist/checksums.txt --title "v1.0.0" --notes-file docs/release-notes/v1.0.0.md
+
+13. Финальный отчёт
+В самом конце выдай:
+- что реализовано;
+- какие дефекты исправлены;
+- какие файлы ключевые;
+- какие тесты пройдены;
+- какие артефакты собраны;
+- опубликован ли релиз;
+- если не опубликован — точные последние ручные шаги.
+
+Начинай с анализа текущего состояния репозитория и gap analysis против файлов AGENTS.md / TASK.md / docs/*.md.
+Не ограничивайся обзором — доведи проект до релизного состояния.
+```
+
+## Короткая версия
+Если нужен совсем короткий запуск, можно использовать и это:
+
+```text
+Доведи текущий репозиторий до production-ready v1.0.0 по AGENTS.md, TASK.md и docs/*.md, исправь дефекты, заверши недостающие части, прогони проверки, собери Windows release artifacts, создай tag v1.0.0 и в конце выпусти GitHub Release. Если прав на публикацию нет, подготовь всё до состояния одной финальной команды `gh release create ...`.
+```
diff --git a/README.md b/README.md
new file mode 100644
index 0000000000000000000000000000000000000000..e782e519c014b37471afd13a1390c621ce7ced46
--- /dev/null
+++ b/README.md
@@ -0,0 +1,78 @@
+# ИС тестирования знаний — Terra Engineering
+
+Windows desktop приложение на Python + Flet для тестирования знаний сотрудников ООО «Терра-Инжиниринг».
+
+## Что делает система
+Система предназначена для:
+- авторизации сотрудников и администратора;
+- управления пользователями;
+- управления вопросами, ответами и категориями;
+- назначения тестирований;
+- прохождения тестов с таймером;
+- расчёта результата и статуса прохождения;
+- хранения истории прохождений;
+- формирования отчётов и базовой аналитики;
+- локальной работы через SQLite;
+- опциональной синхронизации в удалённую MySQL.
+
+## Версия первого релиза
+`v1.0.0`
+
+Первый релиз ориентирован только на Windows desktop.
+
+## Бизнес-параметры v1.0
+- 2 роли: `admin`, `user`
+- 17 текущих пользователей
+- масштабирование до 100+ пользователей
+- 160 вопросов в банке
+- 20 вопросов в одном тесте
+- 70% — порог прохождения
+- 30 секунд на вопрос
+- до 3 попыток на сотрудника
+
+## Архитектурный подход
+Приложение работает в модели `offline-first`.
+
+### Основные правила
+- локальная SQLite — основная operational database;
+- удалённая MySQL — опциональная цель синхронизации;
+- вход выполняется по локальной базе;
+- отсутствие MySQL не блокирует вход;
+- синхронизация запускается:
+  - после успешной авторизации;
+  - после завершения теста;
+- при сбое синхронизации данные сохраняются локально и помечаются для повторной отправки.
+
+Подробности: `docs/adr/002-data-sync.md`
+
+## Стек
+- Python 3.11+
+- Flet
+- SQLAlchemy 2.x
+- Pydantic 2.x
+- Alembic
+- SQLite
+- MySQL
+- pytest
+- Ruff
+- ReportLab
+- OpenPyXL
+
+## Быстрый старт
+```bash
+python -m venv .venv
+.venv\Scripts\activate
+pip install -U pip
+pip install -e .[dev]
+copy .env.example .env
+alembic upgrade head
+python scripts/seed.py
+python -m terra_testing
+```
+
+## Релиз
+```bash
+git tag -a v1.0.0 -m "Release v1.0.0"
+git push origin v1.0.0
+gh release create v1.0.0 dist/TerraTesting-win.zip dist/checksums.txt --title "v1.0.0" --notes-file docs/release-notes/v1.0.0.md
+```
diff --git a/TASK.md b/TASK.md
new file mode 100644
index 0000000000000000000000000000000000000000..e0814cbda7427b4bb4603c4f7cf3cd154fc8c3c4
--- /dev/null
+++ b/TASK.md
@@ -0,0 +1,22 @@
+# TASK.md
+
+## Objective
+Довести проект до production-ready состояния и выпустить релиз `v1.0.0` для Windows desktop.
+
+## Context
+Проект — ИС тестирования знаний сотрудников на Flet.
+Система должна работать offline-first:
+- основная operational БД: SQLite;
+- удалённая MySQL: только для синхронизации;
+- вход в систему не зависит от доступности MySQL.
+
+## Required deliverables
+1. Нормализованные требования и scope.
+2. Рабочее приложение Windows desktop.
+3. Локальная SQLite схема и миграции.
+4. Опциональный MySQL sync.
+5. Админский контур.
+6. Пользовательский контур.
+7. Тестирование и CI.
+8. Windows build artifact.
+9. GitHub Release v1.0.0.
diff --git a/alembic.ini b/alembic.ini
new file mode 100644
index 0000000000000000000000000000000000000000..4b6323fd3a23d256a9d2bf91f052b9a9e4e021a1
--- /dev/null
+++ b/alembic.ini
@@ -0,0 +1,35 @@
+[alembic]
+script_location = alembic
+sqlalchemy.url = sqlite:///./data/training_system.db
+
+[loggers]
+keys = root,sqlalchemy,alembic
+
+[handlers]
+keys = console
+
+[formatters]
+keys = generic
+
+[logger_root]
+level = WARN
+handlers = console
+
+[logger_sqlalchemy]
+level = WARN
+handlers =
+qualname = sqlalchemy.engine
+
+[logger_alembic]
+level = INFO
+handlers = console
+qualname = alembic
+
+[handler_console]
+class = StreamHandler
+args = (sys.stderr,)
+level = NOTSET
+formatter = generic
+
+[formatter_generic]
+format = %(levelname)-5.5s [%(name)s] %(message)s
diff --git a/alembic/README b/alembic/README
new file mode 100644
index 0000000000000000000000000000000000000000..2500aa1bcf726a14c436070389837be3666ba96f
--- /dev/null
+++ b/alembic/README
@@ -0,0 +1 @@
+Generic single-database configuration.
diff --git a/alembic/env.py b/alembic/env.py
new file mode 100644
index 0000000000000000000000000000000000000000..fdb3986428fecd4531f12ded6b3ec0eaa880c8d0
--- /dev/null
+++ b/alembic/env.py
@@ -0,0 +1,44 @@
+from __future__ import annotations
+
+from logging.config import fileConfig
+
+from alembic import context
+from sqlalchemy import engine_from_config, pool
+
+from terra_testing.config.settings import get_settings
+from terra_testing.db.base import Base
+from terra_testing.models import answer, audit_log, question, role, schedule, sync_queue, system_setting, test_result, user  # noqa: F401
+
+config = context.config
+settings = get_settings()
+config.set_main_option("sqlalchemy.url", settings.local_db_url)
+
+if config.config_file_name is not None:
+    fileConfig(config.config_file_name)
+
+target_metadata = Base.metadata
+
+
+def run_migrations_offline() -> None:
+    url = config.get_main_option("sqlalchemy.url")
+    context.configure(url=url, target_metadata=target_metadata, literal_binds=True, compare_type=True)
+    with context.begin_transaction():
+        context.run_migrations()
+
+
+def run_migrations_online() -> None:
+    connectable = engine_from_config(
+        config.get_section(config.config_ini_section, {}),
+        prefix="sqlalchemy.",
+        poolclass=pool.NullPool,
+    )
+    with connectable.connect() as connection:
+        context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
+        with context.begin_transaction():
+            context.run_migrations()
+
+
+if context.is_offline_mode():
+    run_migrations_offline()
+else:
+    run_migrations_online()
diff --git a/alembic/script.py.mako b/alembic/script.py.mako
new file mode 100644
index 0000000000000000000000000000000000000000..0c80710721ba616c16e599c6b2302953ba3146fd
--- /dev/null
+++ b/alembic/script.py.mako
@@ -0,0 +1,17 @@
+"""${message}"""
+
+revision = ${repr(up_revision)}
+down_revision = ${repr(down_revision)}
+branch_labels = ${repr(branch_labels)}
+depends_on = ${repr(depends_on)}
+
+from alembic import op
+import sqlalchemy as sa
+
+
+def upgrade() -> None:
+    ${upgrades if upgrades else "pass"}
+
+
+def downgrade() -> None:
+    ${downgrades if downgrades else "pass"}
diff --git a/alembic/versions/20260314_0001_initial.py b/alembic/versions/20260314_0001_initial.py
new file mode 100644
index 0000000000000000000000000000000000000000..06cecabf67ef3827bc0eee9e9fc563ef6f8a1693
--- /dev/null
+++ b/alembic/versions/20260314_0001_initial.py
@@ -0,0 +1,117 @@
+"""Initial schema."""
+
+from alembic import op
+import sqlalchemy as sa
+
+
+revision = "20260314_0001"
+down_revision = None
+branch_labels = None
+depends_on = None
+
+
+def upgrade() -> None:
+    op.create_table(
+        "roles",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("name", sa.String(length=50), nullable=False, unique=True),
+    )
+
+    op.create_table(
+        "question_categories",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("name", sa.String(length=150), nullable=False, unique=True),
+        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
+    )
+
+    op.create_table(
+        "users",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("username", sa.String(length=100), nullable=False, unique=True),
+        sa.Column("full_name", sa.String(length=255), nullable=False),
+        sa.Column("password_hash", sa.String(length=255), nullable=False),
+        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
+        sa.Column("role_id", sa.Integer(), sa.ForeignKey("roles.id"), nullable=False),
+    )
+
+    op.create_table(
+        "questions",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("category_id", sa.Integer(), sa.ForeignKey("question_categories.id"), nullable=False),
+        sa.Column("text", sa.Text(), nullable=False),
+        sa.Column("difficulty", sa.Integer(), nullable=False, server_default="1"),
+        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
+    )
+
+    op.create_table(
+        "answers",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("question_id", sa.Integer(), sa.ForeignKey("questions.id"), nullable=False),
+        sa.Column("text", sa.Text(), nullable=False),
+        sa.Column("is_correct", sa.Boolean(), nullable=False, server_default=sa.false()),
+    )
+
+    op.create_table(
+        "test_assignments",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
+        sa.Column("title", sa.String(length=255), nullable=False),
+        sa.Column("status", sa.String(length=20), nullable=False, server_default="assigned"),
+        sa.Column("due_at", sa.DateTime(), nullable=True),
+        sa.Column("questions_count", sa.Integer(), nullable=False, server_default="20"),
+        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="3"),
+    )
+
+    op.create_table(
+        "test_results",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
+        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("test_assignments.id"), nullable=True),
+        sa.Column("correct_answers", sa.Integer(), nullable=False, server_default="0"),
+        sa.Column("total_questions", sa.Integer(), nullable=False, server_default="0"),
+        sa.Column("score_percent", sa.Integer(), nullable=False),
+        sa.Column("status", sa.String(length=20), nullable=False),
+        sa.Column("sync_state", sa.String(length=20), nullable=False, server_default="pending"),
+        sa.Column("sync_error", sa.Text(), nullable=True),
+        sa.Column("retry_count", sa.Integer(), nullable=False, server_default="0"),
+        sa.Column("completed_at", sa.DateTime(), nullable=False),
+        sa.Column("last_synced_at", sa.DateTime(), nullable=True),
+    )
+
+    op.create_table(
+        "test_answers",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("result_id", sa.Integer(), sa.ForeignKey("test_results.id"), nullable=False),
+        sa.Column("question_id", sa.Integer(), sa.ForeignKey("questions.id"), nullable=False),
+        sa.Column("selected_answer_id", sa.Integer(), sa.ForeignKey("answers.id"), nullable=True),
+        sa.Column("is_correct", sa.Boolean(), nullable=False, server_default=sa.false()),
+    )
+
+    op.create_table(
+        "audit_log",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("event_type", sa.String(length=100), nullable=False),
+        sa.Column("actor", sa.String(length=100), nullable=False),
+        sa.Column("message", sa.Text(), nullable=False),
+        sa.Column("created_at", sa.DateTime(), nullable=False),
+    )
+
+    op.create_table(
+        "system_settings",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("key", sa.String(length=120), nullable=False, unique=True),
+        sa.Column("value", sa.Text(), nullable=False),
+    )
+
+
+def downgrade() -> None:
+    op.drop_table("system_settings")
+    op.drop_table("audit_log")
+    op.drop_table("test_answers")
+    op.drop_table("test_results")
+    op.drop_table("test_assignments")
+    op.drop_table("answers")
+    op.drop_table("questions")
+    op.drop_table("users")
+    op.drop_table("question_categories")
+    op.drop_table("roles")
diff --git a/alembic/versions/20260314_0002_sync_queue.py b/alembic/versions/20260314_0002_sync_queue.py
new file mode 100644
index 0000000000000000000000000000000000000000..2cc09bc469d0262c8431443cbba56884e3ed3e19
--- /dev/null
+++ b/alembic/versions/20260314_0002_sync_queue.py
@@ -0,0 +1,34 @@
+"""Add sync queue."""
+
+from alembic import op
+import sqlalchemy as sa
+
+
+revision = "20260314_0002"
+down_revision = "20260314_0001"
+branch_labels = None
+depends_on = None
+
+
+def upgrade() -> None:
+    op.create_table(
+        "sync_queue",
+        sa.Column("id", sa.Integer(), primary_key=True),
+        sa.Column("entity_type", sa.String(length=50), nullable=False),
+        sa.Column("entity_id", sa.Integer(), nullable=False),
+        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
+        sa.Column("payload_snapshot", sa.Text(), nullable=True),
+        sa.Column("last_error", sa.Text(), nullable=True),
+        sa.Column("retry_count", sa.Integer(), nullable=False, server_default="0"),
+        sa.Column("last_attempt_at", sa.DateTime(), nullable=True),
+        sa.Column("created_at", sa.DateTime(), nullable=False),
+        sa.Column("updated_at", sa.DateTime(), nullable=False),
+    )
+    op.create_index("ix_sync_queue_entity", "sync_queue", ["entity_type", "entity_id"], unique=False)
+    op.create_index("ix_sync_queue_status", "sync_queue", ["status"], unique=False)
+
+
+def downgrade() -> None:
+    op.drop_index("ix_sync_queue_status", table_name="sync_queue")
+    op.drop_index("ix_sync_queue_entity", table_name="sync_queue")
+    op.drop_table("sync_queue")
diff --git a/docs/adr/001-architecture.md b/docs/adr/001-architecture.md
new file mode 100644
index 0000000000000000000000000000000000000000..c5e967a2fa8fba65de412f41c660be16c136e919
--- /dev/null
+++ b/docs/adr/001-architecture.md
@@ -0,0 +1,31 @@
+# ADR-001: Application architecture for v1.0
+
+- Status: Accepted
+- Date: 2026-03-14
+
+## Decision
+Use a layered architecture with explicit separation between:
+1. UI layer
+2. Application/service layer
+3. Persistence layer
+4. Sync layer
+5. Reporting/utilities layer
+
+## Chosen structure
+- `app/`
+- `pages/`
+- `components/`
+- `models/`
+- `repositories/`
+- `services/`
+- `sync/`
+- `reports/`
+- `config/`
+- `utils/`
+
+## Acceptance criteria
+- pages remain thin;
+- repositories own persistence;
+- services own business rules;
+- sync logic is isolated;
+- tests can exercise core flows without full UI boot.
diff --git a/docs/adr/002-data-sync.md b/docs/adr/002-data-sync.md
new file mode 100644
index 0000000000000000000000000000000000000000..e7c06e264b250485226a99089220bb88440e1d06
--- /dev/null
+++ b/docs/adr/002-data-sync.md
@@ -0,0 +1,26 @@
+# ADR-002: Offline-first data model and MySQL synchronization
+
+- Status: Accepted
+- Date: 2026-03-14
+
+## Decision
+We adopt an **offline-first** architecture.
+
+### Primary operational database
+SQLite is the primary database used by the application runtime.
+
+### Remote synchronization target
+MySQL is an optional remote synchronization target.
+
+### Synchronization triggers
+Synchronization attempts happen only in two places:
+1. after successful local authentication;
+2. after successful test completion and local save.
+
+### Failure handling
+If MySQL connection is not configured or is unavailable:
+- the user still logs in through SQLite;
+- the quiz flow continues normally;
+- results remain stored locally;
+- synchronization failure is logged;
+- records are marked for later retry.
diff --git a/docs/adr/003-release-strategy.md b/docs/adr/003-release-strategy.md
new file mode 100644
index 0000000000000000000000000000000000000000..751212bd32088f07a5709a0e9fae5127c28c65a2
--- /dev/null
+++ b/docs/adr/003-release-strategy.md
@@ -0,0 +1,14 @@
+# ADR-003: Release strategy for v1.0.0
+
+- Status: Accepted
+- Date: 2026-03-14
+
+## Decision
+The first public release is Windows desktop only.
+
+## Release outputs
+- Windows packaged build
+- source archive
+- changelog
+- checksums
+- release notes
diff --git a/docs/backlog.md b/docs/backlog.md
new file mode 100644
index 0000000000000000000000000000000000000000..a5a0841ebcb196914a132c752f7f0789a75b607b
--- /dev/null
+++ b/docs/backlog.md
@@ -0,0 +1,16 @@
+# Backlog
+
+## Post-v1 candidates
+- biometric login
+- face recognition cache
+- gesture-based answer selection
+- voice reading of questions
+- camera-based attention tracking
+- PWA mode
+- mobile packaging
+- AI adaptive question selection
+- email report delivery
+- 1C / HRM integration
+- gamification
+- webinar/training platform
+- online support chat
diff --git a/docs/codex-launch-prompt.md b/docs/codex-launch-prompt.md
new file mode 100644
index 0000000000000000000000000000000000000000..b3d10192bfd1c0ddea716c1ac1f7ac2220462289
--- /dev/null
+++ b/docs/codex-launch-prompt.md
@@ -0,0 +1,7 @@
+# Codex launch prompt
+
+Основной prompt для запуска Codex находится в корне репозитория:
+
+- `PROMPT_CODEX_RELEASE.md`
+
+Используйте именно его как основной инструктивный prompt для доведения проекта до `v1.0.0` и финального GitHub Release.
diff --git a/docs/deployment.md b/docs/deployment.md
new file mode 100644
index 0000000000000000000000000000000000000000..22b366b888f494118d829a7c00da8a74a56837a4
--- /dev/null
+++ b/docs/deployment.md
@@ -0,0 +1,25 @@
+# Deployment Guide
+
+## 1. Назначение
+Документ описывает развертывание v1.0.0 для Windows desktop.
+
+## 2. Сценарии эксплуатации
+### Сценарий A — локальный
+- приложение работает только с SQLite;
+
+### Сценарий B — локальный + синхронизация
+- приложение работает через SQLite;
+- MySQL подключена как удалённая цель синхронизации;
+- sync attempt выполняется после логина и после завершения теста.
+
+## 3. Быстрый деплой
+```bash
+python -m venv .venv
+.venv\Scripts\activate
+pip install -U pip
+pip install -e .[dev]
+copy .env.example .env
+alembic upgrade head
+python scripts/seed.py
+python -m terra_testing
+```
diff --git a/docs/release-notes/v1.0.0.md b/docs/release-notes/v1.0.0.md
new file mode 100644
index 0000000000000000000000000000000000000000..18f937892da13d58edb649b309ea3f40943b4fea
--- /dev/null
+++ b/docs/release-notes/v1.0.0.md
@@ -0,0 +1,23 @@
+# Release Notes — v1.0.0
+
+## Overview
+Первый production-oriented релиз Windows desktop приложения “ИС тестирования знаний”.
+
+## Included in this release
+- Windows desktop build
+- local SQLite operational database
+- local login/password authentication
+- roles: admin / user
+- user management
+- question/category/answer management
+- test scheduling
+- quiz flow with timer
+- result scoring and pass/fail status
+- user history
+- basic analytics
+- PDF/Excel export
+- audit logging
+- backup utilities
+- optional MySQL synchronization
+- CI workflows
+- release packaging
diff --git a/docs/requirements.md b/docs/requirements.md
new file mode 100644
index 0000000000000000000000000000000000000000..50c4bf1fae69971658052d0db53e756a74ad9113
--- /dev/null
+++ b/docs/requirements.md
@@ -0,0 +1,38 @@
+# Требования к системе
+
+## 1. Назначение
+Информационная система предназначена для тестирования знаний сотрудников ООО «Терра-Инжиниринг» по профильным темам.
+
+## 2. Цели
+- повысить качество знаний сотрудников;
+- автоматизировать проведение тестирования;
+- контролировать сроки и результаты тестирований;
+- формировать отчёты и аналитику;
+- обеспечить локальную устойчивую работу даже при недоступности удалённой БД.
+
+## 3. Границы v1.0
+Система реализуется как Windows desktop приложение.
+Основной режим работы — локальный.
+Удалённая MySQL используется как опциональный механизм синхронизации.
+
+## 4. Пользователи системы
+- `admin`
+- `user`
+
+## 5. Предметные параметры
+- банк вопросов: 160;
+- тест: 20 вопросов;
+- порог прохождения: 70%;
+- время на один вопрос: 30 секунд;
+- максимум попыток: 3.
+
+## 6. Критерии приёмки
+- запускается на Windows;
+- создаёт и использует SQLite;
+- логин работает без MySQL;
+- пользователь проходит тест до конца;
+- результат сохраняется локально;
+- после логина и после теста выполняется sync attempt;
+- ошибки sync не ломают основной сценарий;
+- отчёты формируются;
+- есть тесты, сборка и release-документация.
diff --git a/docs/scope_v1.md b/docs/scope_v1.md
new file mode 100644
index 0000000000000000000000000000000000000000..f792008bb5e52fef2549ccaf1adc7fd0c478ecf7
--- /dev/null
+++ b/docs/scope_v1.md
@@ -0,0 +1,37 @@
+# Scope v1.0
+
+## Included in v1.0
+- Windows desktop packaging only
+- Russian UI
+- Local SQLite database
+- Optional remote MySQL synchronization
+- Local login/password authentication
+- Roles: admin, user
+- User management
+- Question/category/answer management
+- Test scheduling
+- Quiz flow
+- Timer per question
+- Pass/fail calculation
+- Test history
+- Basic analytics
+- PDF and Excel reports
+- Audit logging
+- Backup/export utilities
+- Automated testing
+- CI workflows
+- GitHub release process
+
+## Explicitly excluded from v1.0
+- biometric login
+- face recognition
+- gesture input
+- voice playback/voice control
+- camera monitoring
+- 3D or WebGL content
+- PWA
+- mobile apps
+- AI-based adaptive testing
+- external HR integrations
+- mail integrations
+- chat support
diff --git a/otb.zip b/otb.zip
new file mode 100644
index 0000000000000000000000000000000000000000..3aa9053775f8bafce523cb70e0dec964436907ee
GIT binary patch
literal 90596
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
Y)i3PXSU-Xx!H@+Ga18A<h-o4J12aW!*8l(j

literal 0
HcmV?d00001

diff --git a/pyproject.toml b/pyproject.toml
new file mode 100644
index 0000000000000000000000000000000000000000..b551f507c39511c410ec3be6b0ce401b97242e75
--- /dev/null
+++ b/pyproject.toml
@@ -0,0 +1,57 @@
+[build-system]
+requires = ["setuptools>=69", "wheel"]
+build-backend = "setuptools.build_meta"
+
+[project]
+name = "terra-testing"
+version = "1.0.0"
+description = "Windows desktop knowledge testing system for Terra Engineering"
+readme = "README.md"
+requires-python = ">=3.11"
+license = { text = "Proprietary" }
+authors = [{ name = "Terra Engineering" }]
+dependencies = [
+  "flet>=0.28.0",
+  "sqlalchemy>=2.0,<3.0",
+  "alembic>=1.13,<2.0",
+  "pydantic>=2.6,<3.0",
+  "pydantic-settings>=2.2,<3.0",
+  "passlib[bcrypt]>=1.7.4,<2.0",
+  "bcrypt>=4.1,<5.0",
+  "pymysql>=1.1,<2.0",
+  "python-dotenv>=1.0,<2.0",
+  "openpyxl>=3.1,<4.0",
+  "reportlab>=4.0,<5.0",
+]
+[project.optional-dependencies]
+dev = [
+  "pytest>=8.0,<9.0",
+  "pytest-cov>=5.0,<6.0",
+  "pytest-mock>=3.12,<4.0",
+  "ruff>=0.11.0",
+]
+[project.scripts]
+terra-testing = "terra_testing.main:main"
+
+[tool.setuptools]
+package-dir = {"" = "src"}
+
+[tool.setuptools.packages.find]
+where = ["src"]
+
+[tool.pytest.ini_options]
+testpaths = ["tests"]
+pythonpath = ["src"]
+addopts = "-q --strict-markers"
+
+[tool.ruff]
+line-length = 100
+target-version = "py311"
+src = ["src", "tests", "scripts"]
+
+[tool.ruff.lint]
+select = ["E", "F", "I", "UP", "B"]
+
+[tool.ruff.format]
+quote-style = "double"
+indent-style = "space"
diff --git a/scripts/backup.py b/scripts/backup.py
new file mode 100644
index 0000000000000000000000000000000000000000..38237af47d1319988426a8deee0204b01f8dea53
--- /dev/null
+++ b/scripts/backup.py
@@ -0,0 +1,31 @@
+from __future__ import annotations
+
+import shutil
+from datetime import datetime
+from pathlib import Path
+
+from terra_testing.config.settings import get_settings
+
+
+def _sqlite_path_from_url(db_url: str) -> Path:
+    if db_url.startswith("sqlite:///"):
+        raw = db_url.replace("sqlite:///", "", 1)
+        return Path(raw)
+    raise ValueError("Only sqlite:/// URLs are supported by backup.py")
+
+
+def main() -> None:
+    settings = get_settings()
+    source = _sqlite_path_from_url(settings.local_db_url)
+
+    if not source.exists():
+        raise FileNotFoundError(f"SQLite file not found: {source}")
+
+    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
+    target = settings.backup_dir / f"training_system_{timestamp}.db"
+    shutil.copy2(source, target)
+    print(f"Backup created: {target}")
+
+
+if __name__ == "__main__":
+    main()
diff --git a/scripts/build_windows.py b/scripts/build_windows.py
new file mode 100644
index 0000000000000000000000000000000000000000..6191a18a09c908d6a2a4ceb6ee16bbd2d8577b84
--- /dev/null
+++ b/scripts/build_windows.py
@@ -0,0 +1,30 @@
+from __future__ import annotations
+
+import shutil
+import subprocess
+from pathlib import Path
+
+
+def main() -> None:
+    dist_dir = Path("dist")
+    dist_dir.mkdir(parents=True, exist_ok=True)
+
+    entrypoint = Path("src/terra_testing/main.py")
+    if not entrypoint.exists():
+        raise FileNotFoundError(f"Entrypoint not found: {entrypoint}")
+
+    cmd = ["flet", "pack", str(entrypoint), "--name", "TerraTesting"]
+    subprocess.run(cmd, check=True)
+
+    generated_dir = Path("build")
+    if generated_dir.exists() and not any(dist_dir.iterdir()):
+        for item in generated_dir.iterdir():
+            target = dist_dir / item.name
+            if item.is_dir():
+                shutil.copytree(item, target, dirs_exist_ok=True)
+            else:
+                shutil.copy2(item, target)
+
+
+if __name__ == "__main__":
+    main()
diff --git a/scripts/init_db.py b/scripts/init_db.py
new file mode 100644
index 0000000000000000000000000000000000000000..7526ed6c7a0385fe06d0dc6d4b086da7c5d50725
--- /dev/null
+++ b/scripts/init_db.py
@@ -0,0 +1,6 @@
+from terra_testing.db.init_db import init_db
+
+
+if __name__ == "__main__":
+    init_db()
+    print("Database initialized.")
diff --git a/scripts/restore.py b/scripts/restore.py
new file mode 100644
index 0000000000000000000000000000000000000000..2e1f9aa53dbb4ceac80e4d077b3c0e0bf3163e0b
--- /dev/null
+++ b/scripts/restore.py
@@ -0,0 +1,34 @@
+from __future__ import annotations
+
+import shutil
+import sys
+from pathlib import Path
+
+from terra_testing.config.settings import get_settings
+
+
+def _sqlite_path_from_url(db_url: str) -> Path:
+    if db_url.startswith("sqlite:///"):
+        raw = db_url.replace("sqlite:///", "", 1)
+        return Path(raw)
+    raise ValueError("Only sqlite:/// URLs are supported by restore.py")
+
+
+def main() -> None:
+    if len(sys.argv) != 2:
+        raise SystemExit("Usage: python scripts/restore.py <backup_file>")
+
+    settings = get_settings()
+    backup_file = Path(sys.argv[1])
+
+    if not backup_file.exists():
+        raise FileNotFoundError(f"Backup file not found: {backup_file}")
+
+    target = _sqlite_path_from_url(settings.local_db_url)
+    target.parent.mkdir(parents=True, exist_ok=True)
+    shutil.copy2(backup_file, target)
+    print(f"Restore completed: {target}")
+
+
+if __name__ == "__main__":
+    main()
diff --git a/scripts/seed.py b/scripts/seed.py
new file mode 100644
index 0000000000000000000000000000000000000000..9504c2962fce1b980e6cfed699ee8f71a136ac72
--- /dev/null
+++ b/scripts/seed.py
@@ -0,0 +1,127 @@
+from __future__ import annotations
+
+from terra_testing.config.settings import get_settings
+from terra_testing.db.session import get_local_session
+from terra_testing.models.answer import Answer
+from terra_testing.models.question import Question, QuestionCategory
+from terra_testing.models.role import Role
+from terra_testing.models.schedule import TestAssignment
+from terra_testing.models.user import User
+from terra_testing.utils.security import hash_password
+
+
+QUESTION_SEED = [
+    (
+        "Охрана труда",
+        "Какое действие нужно выполнить перед началом работ на объекте?",
+        [
+            ("Пройти инструктаж по технике безопасности", True),
+            ("Сразу приступить к работам", False),
+            ("Пропустить проверку оборудования", False),
+            ("Отключить связь", False),
+        ],
+    ),
+    (
+        "Геодезия",
+        "Какой прибор применяется для измерения горизонтальных и вертикальных углов?",
+        [
+            ("Теодолит", True),
+            ("Штангенциркуль", False),
+            ("Мультиметр", False),
+            ("Компас", False),
+        ],
+    ),
+    (
+        "Охрана труда",
+        "Что необходимо сделать при обнаружении неисправности инструмента?",
+        [
+            ("Сообщить ответственному и прекратить работу", True),
+            ("Продолжить работу", False),
+            ("Скрыть неисправность", False),
+            ("Передать без предупреждения другому сотруднику", False),
+        ],
+    ),
+]
+
+
+def main() -> None:
+    settings = get_settings()
+
+    with get_local_session() as session:
+        admin_role = session.query(Role).filter_by(name="admin").one_or_none()
+        user_role = session.query(Role).filter_by(name="user").one_or_none()
+
+        if admin_role is None:
+            admin_role = Role(name="admin")
+            session.add(admin_role)
+
+        if user_role is None:
+            user_role = Role(name="user")
+            session.add(user_role)
+
+        session.flush()
+
+        admin_user = session.query(User).filter_by(username=settings.seed_admin_login).one_or_none()
+        if admin_user is None:
+            admin_user = User(
+                username=settings.seed_admin_login,
+                full_name="Администратор системы",
+                password_hash=hash_password(settings.seed_admin_password),
+                is_active=True,
+                role_id=admin_role.id,
+            )
+            session.add(admin_user)
+
+        demo_user = session.query(User).filter_by(username=settings.seed_user_login).one_or_none()
+        if demo_user is None:
+            demo_user = User(
+                username=settings.seed_user_login,
+                full_name="Тестовый пользователь",
+                password_hash=hash_password(settings.seed_user_password),
+                is_active=True,
+                role_id=user_role.id,
+            )
+            session.add(demo_user)
+
+        session.flush()
+
+        categories: dict[str, QuestionCategory] = {}
+        for category_name, question_text, answers in QUESTION_SEED:
+            category = session.query(QuestionCategory).filter_by(name=category_name).one_or_none()
+            if category is None:
+                category = QuestionCategory(name=category_name)
+                session.add(category)
+                session.flush()
+            categories[category_name] = category
+
+            existing_question = session.query(Question).filter_by(text=question_text).one_or_none()
+            if existing_question is None:
+                question = Question(category_id=category.id, text=question_text)
+                session.add(question)
+                session.flush()
+                for answer_text, is_correct in answers:
+                    session.add(Answer(question_id=question.id, text=answer_text, is_correct=is_correct))
+
+        session.flush()
+
+        existing_assignment = session.query(TestAssignment).filter_by(
+            user_id=demo_user.id,
+            title="Демо-тестирование",
+        ).one_or_none()
+        if existing_assignment is None:
+            session.add(
+                TestAssignment(
+                    user_id=demo_user.id,
+                    title="Демо-тестирование",
+                    questions_count=min(len(QUESTION_SEED), settings.questions_per_test),
+                    max_attempts=settings.max_attempts,
+                )
+            )
+
+        session.commit()
+
+    print("Seed completed.")
+
+
+if __name__ == "__main__":
+    main()
diff --git a/src/terra_testing/__init__.py b/src/terra_testing/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..470d6936454190adda5f3ae7ce092d1a10df8745
--- /dev/null
+++ b/src/terra_testing/__init__.py
@@ -0,0 +1 @@
+__all__ = ["main"]
diff --git a/src/terra_testing/__main__.py b/src/terra_testing/__main__.py
new file mode 100644
index 0000000000000000000000000000000000000000..990443963a24e24cd936359849cce1fdf57f5669
--- /dev/null
+++ b/src/terra_testing/__main__.py
@@ -0,0 +1,4 @@
+from terra_testing.main import main
+
+if __name__ == "__main__":
+    main()
diff --git a/src/terra_testing/app/__init__.py b/src/terra_testing/app/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/app/access.py b/src/terra_testing/app/access.py
new file mode 100644
index 0000000000000000000000000000000000000000..933801e1130591f49e49f01351da7dff32998aff
--- /dev/null
+++ b/src/terra_testing/app/access.py
@@ -0,0 +1,62 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.session_state import SessionState
+from terra_testing.components.app_shell import build_shell
+
+
+def get_state(page: ft.Page) -> SessionState:
+    state = page.session.get("state")
+    return state if isinstance(state, SessionState) else SessionState()
+
+
+def is_authenticated(page: ft.Page) -> bool:
+    return get_state(page).is_authenticated
+
+
+def is_admin(page: ft.Page) -> bool:
+    state = get_state(page)
+    return state.is_authenticated and state.role == "admin"
+
+
+def is_user(page: ft.Page) -> bool:
+    state = get_state(page)
+    return state.is_authenticated and state.role in {"admin", "user"}
+
+
+def actor_name(page: ft.Page, fallback: str = "system") -> str:
+    state = get_state(page)
+    return state.username or fallback
+
+
+def _denied_view(page: ft.Page, title: str, route: str, message: str) -> ft.View:
+    return ft.View(
+        route=route,
+        controls=build_shell(
+            title,
+            [
+                ft.Text(message),
+                ft.FilledButton("Вернуться", on_click=lambda _: page.go("/user" if is_authenticated(page) else "/login")),
+            ],
+            page=page,
+        ),
+    )
+
+
+def require_authenticated(page: ft.Page, title: str, route: str) -> ft.View | None:
+    if is_authenticated(page):
+        return None
+    return _denied_view(page, title, route, "Необходима авторизация.")
+
+
+def require_user(page: ft.Page, title: str, route: str) -> ft.View | None:
+    if is_user(page):
+        return None
+    return _denied_view(page, title, route, "Доступ разрешён только авторизованным пользователям.")
+
+
+def require_admin(page: ft.Page, title: str, route: str) -> ft.View | None:
+    if is_admin(page):
+        return None
+    return _denied_view(page, title, route, "Доступ разрешён только администратору.")
diff --git a/src/terra_testing/app/bootstrap.py b/src/terra_testing/app/bootstrap.py
new file mode 100644
index 0000000000000000000000000000000000000000..74c3a9f8a7e17a3a65c0c17808e6f1aee2621f1c
--- /dev/null
+++ b/src/terra_testing/app/bootstrap.py
@@ -0,0 +1,9 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.session_state import SessionState
+
+
+def bootstrap_app(page: ft.Page) -> None:
+    page.session.set("state", SessionState())
diff --git a/src/terra_testing/app/router.py b/src/terra_testing/app/router.py
new file mode 100644
index 0000000000000000000000000000000000000000..6c2684cf1576effe239996b061dcccebaab246a4
--- /dev/null
+++ b/src/terra_testing/app/router.py
@@ -0,0 +1,88 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.session_state import SessionState
+from terra_testing.pages.admin_dashboard_page import AdminDashboardPage
+from terra_testing.pages.admin_results_page import AdminResultsPage
+from terra_testing.pages.audit_log_page import AuditLogPage
+from terra_testing.pages.login_page import LoginPage
+from terra_testing.pages.questions_management_page import QuestionsManagementPage
+from terra_testing.pages.quiz_page import QuizPage
+from terra_testing.pages.reports_page import ReportsPage
+from terra_testing.pages.results_page import ResultsPage
+from terra_testing.pages.schedule_management_page import ScheduleManagementPage
+from terra_testing.pages.settings_page import SettingsPage
+from terra_testing.pages.sync_monitor_page import SyncMonitorPage
+from terra_testing.pages.user_dashboard_page import UserDashboardPage
+from terra_testing.pages.users_management_page import UsersManagementPage
+
+
+ROUTES = {
+    "/login": LoginPage,
+    "/admin": AdminDashboardPage,
+    "/admin/users": UsersManagementPage,
+    "/admin/questions": QuestionsManagementPage,
+    "/admin/schedule": ScheduleManagementPage,
+    "/admin/results": AdminResultsPage,
+    "/admin/sync": SyncMonitorPage,
+    "/admin/audit": AuditLogPage,
+    "/user": UserDashboardPage,
+    "/quiz": QuizPage,
+    "/results": ResultsPage,
+    "/reports": ReportsPage,
+    "/settings": SettingsPage,
+}
+
+ADMIN_ROUTES = {route for route in ROUTES if route.startswith('/admin')}
+USER_ROUTES = {'/user', '/quiz', '/results', '/settings'}
+SHARED_AUTH_ROUTES = {'/reports', '/results', '/settings'}
+
+
+def get_session_state(page: ft.Page) -> SessionState:
+    state = page.session.get('state')
+    return state if isinstance(state, SessionState) else SessionState()
+
+
+def route_is_allowed(route: str, state: SessionState) -> bool:
+    if route == '/login':
+        return True
+    if not state.is_authenticated:
+        return False
+    if route in ADMIN_ROUTES:
+        return state.role == 'admin'
+    if route in USER_ROUTES:
+        if route == '/settings':
+            return True
+        return state.role in {'admin', 'user'}
+    if route in SHARED_AUTH_ROUTES:
+        return True
+    return route in ROUTES
+
+
+def fallback_route_for_state(state: SessionState, requested_route: str) -> str:
+    if not state.is_authenticated:
+        return '/login'
+    if requested_route in ADMIN_ROUTES and state.role != 'admin':
+        return '/user'
+    if requested_route == '/login':
+        return '/admin' if state.role == 'admin' else '/user'
+    return '/admin' if state.role == 'admin' else '/user'
+
+
+def configure_routing(page: ft.Page) -> None:
+    def route_change(route: ft.RouteChangeEvent) -> None:
+        state = get_session_state(page)
+        requested_route = page.route if page.route in ROUTES else '/login'
+        effective_route = requested_route if route_is_allowed(requested_route, state) else fallback_route_for_state(state, requested_route)
+
+        if effective_route != page.route:
+            page.go(effective_route)
+            return
+
+        page.views.clear()
+        view_cls = ROUTES.get(effective_route, LoginPage)
+        page.views.append(view_cls(page).build())
+        page.update()
+
+    page.on_route_change = route_change
diff --git a/src/terra_testing/app/session_state.py b/src/terra_testing/app/session_state.py
new file mode 100644
index 0000000000000000000000000000000000000000..4bcd31a6c3bf9d5ade21ad187b1827d28525b08b
--- /dev/null
+++ b/src/terra_testing/app/session_state.py
@@ -0,0 +1,11 @@
+from __future__ import annotations
+
+from dataclasses import dataclass
+
+
+@dataclass
+class SessionState:
+    user_id: int | None = None
+    username: str | None = None
+    role: str | None = None
+    is_authenticated: bool = False
diff --git a/src/terra_testing/components/__init__.py b/src/terra_testing/components/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/components/app_shell.py b/src/terra_testing/components/app_shell.py
new file mode 100644
index 0000000000000000000000000000000000000000..56fb2a67de00ebc465111d985e88e3ded6b08c3d
--- /dev/null
+++ b/src/terra_testing/components/app_shell.py
@@ -0,0 +1,49 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.session_state import SessionState
+
+
+def _nav_button(label: str, route: str, page: ft.Page) -> ft.OutlinedButton:
+    return ft.OutlinedButton(label, on_click=lambda _: page.go(route))
+
+
+def _logout(page: ft.Page) -> None:
+    page.session.set('state', SessionState())
+    page.session.set('quiz_state', None)
+    page.session.set('active_assignment_id', None)
+    page.session.set('edit_user_id', None)
+    page.session.set('edit_question_id', None)
+    page.go('/login')
+
+
+def build_shell(title: str, body: list[ft.Control], page: ft.Page | None = None) -> list[ft.Control]:
+    actions: list[ft.Control] = []
+    if page is not None:
+        state: SessionState | None = page.session.get('state')
+        if state and state.is_authenticated:
+            if state.role == 'admin':
+                actions.extend([
+                    _nav_button('Главная', '/admin', page),
+                    _nav_button('Пользователи', '/admin/users', page),
+                    _nav_button('Вопросы', '/admin/questions', page),
+                    _nav_button('Расписание', '/admin/schedule', page),
+                    _nav_button('Результаты', '/admin/results', page),
+                    _nav_button('Синхронизация', '/admin/sync', page),
+                    _nav_button('Аудит', '/admin/audit', page),
+                    _nav_button('Отчёты', '/reports', page),
+                    _nav_button('Настройки', '/settings', page),
+                ])
+            else:
+                actions.extend([
+                    _nav_button('Главная', '/user', page),
+                    _nav_button('Результаты', '/results', page),
+                    _nav_button('Настройки', '/settings', page),
+                ])
+            actions.append(ft.VerticalDivider(width=1))
+            actions.append(ft.Text(state.username or '', size=12))
+            actions.append(ft.FilledButton('Выход', on_click=lambda _: _logout(page)))
+
+    appbar = ft.AppBar(title=ft.Text(title), actions=actions)
+    return [appbar, *body]
diff --git a/src/terra_testing/components/stat_card.py b/src/terra_testing/components/stat_card.py
new file mode 100644
index 0000000000000000000000000000000000000000..b1b947a1d935f8fa865bb02fbc1a7343cc5b713d
--- /dev/null
+++ b/src/terra_testing/components/stat_card.py
@@ -0,0 +1,18 @@
+from __future__ import annotations
+
+import flet as ft
+
+
+class StatCard(ft.Card):
+    def __init__(self, title: str, value: str) -> None:
+        super().__init__(
+            content=ft.Container(
+                padding=16,
+                content=ft.Column(
+                    controls=[
+                        ft.Text(title, size=14, color=ft.Colors.GREY_700),
+                        ft.Text(value, size=24, weight=ft.FontWeight.BOLD),
+                    ]
+                ),
+            )
+        )
diff --git a/src/terra_testing/components/sync_badge.py b/src/terra_testing/components/sync_badge.py
new file mode 100644
index 0000000000000000000000000000000000000000..631ca456a80333b17f53242d0adde7fd1b2dd721
--- /dev/null
+++ b/src/terra_testing/components/sync_badge.py
@@ -0,0 +1,17 @@
+from __future__ import annotations
+
+import flet as ft
+
+
+def sync_badge(state: str) -> ft.Container:
+    color = {
+        "synced": ft.Colors.GREEN_200,
+        "pending": ft.Colors.AMBER_200,
+        "failed": ft.Colors.RED_200,
+    }.get(state, ft.Colors.GREY_200)
+    return ft.Container(
+        padding=ft.padding.symmetric(horizontal=8, vertical=4),
+        bgcolor=color,
+        border_radius=8,
+        content=ft.Text(state),
+    )
diff --git a/src/terra_testing/config/__init__.py b/src/terra_testing/config/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/config/settings.py b/src/terra_testing/config/settings.py
new file mode 100644
index 0000000000000000000000000000000000000000..beb087775f783e957c5b30ba55967f31cb45aa44
--- /dev/null
+++ b/src/terra_testing/config/settings.py
@@ -0,0 +1,58 @@
+from __future__ import annotations
+
+from functools import lru_cache
+from pathlib import Path
+
+from pydantic import Field
+from pydantic_settings import BaseSettings, SettingsConfigDict
+
+
+class Settings(BaseSettings):
+    model_config = SettingsConfigDict(
+        env_file=".env",
+        env_file_encoding="utf-8",
+        case_sensitive=False,
+    )
+
+    app_name: str = Field(default="TerraTesting", alias="APP_NAME")
+    app_env: str = Field(default="development", alias="APP_ENV")
+    app_debug: bool = Field(default=True, alias="APP_DEBUG")
+    app_language: str = Field(default="ru", alias="APP_LANGUAGE")
+
+    local_db_enabled: bool = Field(default=True, alias="LOCAL_DB_ENABLED")
+    local_db_url: str = Field(default="sqlite:///./data/training_system.db", alias="LOCAL_DB_URL")
+
+    remote_sync_enabled: bool = Field(default=False, alias="REMOTE_SYNC_ENABLED")
+    remote_db_url: str = Field(default="", alias="REMOTE_DB_URL")
+
+    questions_per_test: int = Field(default=20, alias="QUESTIONS_PER_TEST")
+    pass_percent: int = Field(default=70, alias="PASS_PERCENT")
+    seconds_per_question: int = Field(default=30, alias="SECONDS_PER_QUESTION")
+    max_attempts: int = Field(default=3, alias="MAX_ATTEMPTS")
+
+    export_dir: Path = Field(default=Path("./data/exports"), alias="EXPORT_DIR")
+    backup_dir: Path = Field(default=Path("./data/backup"), alias="BACKUP_DIR")
+    log_dir: Path = Field(default=Path("./logs"), alias="LOG_DIR")
+
+    seed_admin_login: str = Field(default="admin", alias="SEED_ADMIN_LOGIN")
+    seed_admin_password: str = Field(default="Admin123!", alias="SEED_ADMIN_PASSWORD")
+    seed_user_login: str = Field(default="user01", alias="SEED_USER_LOGIN")
+    seed_user_password: str = Field(default="User123!", alias="SEED_USER_PASSWORD")
+
+    sync_retry_limit: int = Field(default=3, alias="SYNC_RETRY_LIMIT")
+    sync_after_login: bool = Field(default=True, alias="SYNC_AFTER_LOGIN")
+    sync_after_test_completion: bool = Field(default=True, alias="SYNC_AFTER_TEST_COMPLETION")
+
+
+@lru_cache(maxsize=1)
+def get_settings() -> Settings:
+    settings = Settings()
+    settings.export_dir.mkdir(parents=True, exist_ok=True)
+    settings.backup_dir.mkdir(parents=True, exist_ok=True)
+    settings.log_dir.mkdir(parents=True, exist_ok=True)
+    Path("./data").mkdir(parents=True, exist_ok=True)
+    return settings
+
+
+def reset_settings_cache() -> None:
+    get_settings.cache_clear()
diff --git a/src/terra_testing/db/__init__.py b/src/terra_testing/db/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/db/base.py b/src/terra_testing/db/base.py
new file mode 100644
index 0000000000000000000000000000000000000000..fa2b68a5d245bbdde7fbea6b86c9650a584167d6
--- /dev/null
+++ b/src/terra_testing/db/base.py
@@ -0,0 +1,5 @@
+from sqlalchemy.orm import DeclarativeBase
+
+
+class Base(DeclarativeBase):
+    pass
diff --git a/src/terra_testing/db/init_db.py b/src/terra_testing/db/init_db.py
new file mode 100644
index 0000000000000000000000000000000000000000..ff910a886fcd7ec802f9d37afb665416c589be8e
--- /dev/null
+++ b/src/terra_testing/db/init_db.py
@@ -0,0 +1,9 @@
+from terra_testing.db.base import Base
+from terra_testing.db.session import get_local_engine
+
+# import models for metadata registration
+from terra_testing.models import audit_log, question, role, schedule, sync_queue, system_setting, test_result, user  # noqa: F401
+
+
+def init_db() -> None:
+    Base.metadata.create_all(bind=get_local_engine())
diff --git a/src/terra_testing/db/session.py b/src/terra_testing/db/session.py
new file mode 100644
index 0000000000000000000000000000000000000000..8246c95cbadaabf52adb8a0c2bce0b4f0e6f6ccc
--- /dev/null
+++ b/src/terra_testing/db/session.py
@@ -0,0 +1,48 @@
+from __future__ import annotations
+
+from functools import lru_cache
+
+from sqlalchemy import create_engine
+from sqlalchemy.engine import Engine
+from sqlalchemy.orm import Session, sessionmaker
+
+from terra_testing.config.settings import get_settings
+
+
+@lru_cache(maxsize=4)
+def _engine_for_url(db_url: str, echo: bool) -> Engine:
+    return create_engine(db_url, future=True, echo=echo)
+
+
+@lru_cache(maxsize=4)
+def _session_factory_for_url(db_url: str, echo: bool) -> sessionmaker[Session]:
+    return sessionmaker(
+        bind=_engine_for_url(db_url, echo),
+        autoflush=False,
+        autocommit=False,
+        expire_on_commit=False,
+        class_=Session,
+    )
+
+
+def get_local_engine() -> Engine:
+    settings = get_settings()
+    return _engine_for_url(settings.local_db_url, settings.app_debug)
+
+
+def get_local_session() -> Session:
+    settings = get_settings()
+    factory = _session_factory_for_url(settings.local_db_url, settings.app_debug)
+    return factory()
+
+
+def get_remote_engine() -> Engine | None:
+    settings = get_settings()
+    if not settings.remote_sync_enabled or not settings.remote_db_url:
+        return None
+    return _engine_for_url(settings.remote_db_url, False)
+
+
+def reset_engines() -> None:
+    _session_factory_for_url.cache_clear()
+    _engine_for_url.cache_clear()
diff --git a/src/terra_testing/main.py b/src/terra_testing/main.py
new file mode 100644
index 0000000000000000000000000000000000000000..35cf2ac9488db0f350df9cc2afbeff67d1f46c1e
--- /dev/null
+++ b/src/terra_testing/main.py
@@ -0,0 +1,28 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.bootstrap import bootstrap_app
+from terra_testing.app.router import configure_routing
+from terra_testing.config.settings import get_settings
+from terra_testing.utils.logging import setup_logging
+
+
+def app_main(page: ft.Page) -> None:
+    settings = get_settings()
+    page.title = settings.app_name
+    page.theme_mode = ft.ThemeMode.LIGHT
+    page.window.width = 1200
+    page.window.height = 800
+    page.window.min_width = 1000
+    page.window.min_height = 700
+
+    bootstrap_app(page)
+    configure_routing(page)
+    page.go("/login")
+
+
+def main() -> None:
+    settings = get_settings()
+    setup_logging(settings.log_dir)
+    ft.app(target=app_main, view=ft.AppView.FLET_APP)
diff --git a/src/terra_testing/models/__init__.py b/src/terra_testing/models/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..32eae2ddea59d7ac5289793788b718321239b1b5
--- /dev/null
+++ b/src/terra_testing/models/__init__.py
@@ -0,0 +1,23 @@
+from terra_testing.models.answer import Answer
+from terra_testing.models.audit_log import AuditLog
+from terra_testing.models.question import Question, QuestionCategory
+from terra_testing.models.role import Role
+from terra_testing.models.schedule import TestAssignment
+from terra_testing.models.sync_queue import SyncQueueItem
+from terra_testing.models.system_setting import SystemSetting
+from terra_testing.models.test_result import TestAnswer, TestResult
+from terra_testing.models.user import User
+
+__all__ = [
+    "Answer",
+    "AuditLog",
+    "Question",
+    "QuestionCategory",
+    "Role",
+    "SyncQueueItem",
+    "SystemSetting",
+    "TestAnswer",
+    "TestAssignment",
+    "TestResult",
+    "User",
+]
diff --git a/src/terra_testing/models/answer.py b/src/terra_testing/models/answer.py
new file mode 100644
index 0000000000000000000000000000000000000000..aa16e082883c7c3c037999e6e6b6a2915b5de0b5
--- /dev/null
+++ b/src/terra_testing/models/answer.py
@@ -0,0 +1,17 @@
+from __future__ import annotations
+
+from sqlalchemy import Boolean, ForeignKey, Integer, Text
+from sqlalchemy.orm import Mapped, mapped_column, relationship
+
+from terra_testing.db.base import Base
+
+
+class Answer(Base):
+    __tablename__ = "answers"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    question_id: Mapped[int] = mapped_column(ForeignKey("questions.id"), nullable=False)
+    text: Mapped[str] = mapped_column(Text, nullable=False)
+    is_correct: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
+
+    question = relationship("Question", back_populates="answers")
diff --git a/src/terra_testing/models/audit_log.py b/src/terra_testing/models/audit_log.py
new file mode 100644
index 0000000000000000000000000000000000000000..9f126439e69db5019c54830a70bbba15746f4194
--- /dev/null
+++ b/src/terra_testing/models/audit_log.py
@@ -0,0 +1,19 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+from sqlalchemy import DateTime, Integer, String, Text
+from sqlalchemy.orm import Mapped, mapped_column
+
+from terra_testing.db.base import Base
+from terra_testing.utils.time import utcnow
+
+
+class AuditLog(Base):
+    __tablename__ = "audit_log"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
+    actor: Mapped[str] = mapped_column(String(100), nullable=False)
+    message: Mapped[str] = mapped_column(Text, nullable=False)
+    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
diff --git a/src/terra_testing/models/question.py b/src/terra_testing/models/question.py
new file mode 100644
index 0000000000000000000000000000000000000000..97dcffe6b81aec16d24e80d66fda81eb14bc0991
--- /dev/null
+++ b/src/terra_testing/models/question.py
@@ -0,0 +1,29 @@
+from __future__ import annotations
+
+from sqlalchemy import Boolean, ForeignKey, Integer, String, Text
+from sqlalchemy.orm import Mapped, mapped_column, relationship
+
+from terra_testing.db.base import Base
+
+
+class QuestionCategory(Base):
+    __tablename__ = "question_categories"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    name: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
+    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
+
+    questions = relationship("Question", back_populates="category")
+
+
+class Question(Base):
+    __tablename__ = "questions"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    category_id: Mapped[int] = mapped_column(ForeignKey("question_categories.id"), nullable=False)
+    text: Mapped[str] = mapped_column(Text, nullable=False)
+    difficulty: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
+    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
+
+    category = relationship("QuestionCategory", back_populates="questions")
+    answers = relationship("Answer", back_populates="question", cascade="all, delete-orphan")
diff --git a/src/terra_testing/models/role.py b/src/terra_testing/models/role.py
new file mode 100644
index 0000000000000000000000000000000000000000..a188e3f9c70c16b4900fa0009acf2dd0fa63c9fb
--- /dev/null
+++ b/src/terra_testing/models/role.py
@@ -0,0 +1,15 @@
+from __future__ import annotations
+
+from sqlalchemy import Integer, String
+from sqlalchemy.orm import Mapped, mapped_column, relationship
+
+from terra_testing.db.base import Base
+
+
+class Role(Base):
+    __tablename__ = "roles"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
+
+    users = relationship("User", back_populates="role")
diff --git a/src/terra_testing/models/schedule.py b/src/terra_testing/models/schedule.py
new file mode 100644
index 0000000000000000000000000000000000000000..6ed9cfee067b58f7cc3d5b39597c8ac8f8bbd5fe
--- /dev/null
+++ b/src/terra_testing/models/schedule.py
@@ -0,0 +1,22 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+from sqlalchemy import DateTime, ForeignKey, Integer, String
+from sqlalchemy.orm import Mapped, mapped_column, relationship
+
+from terra_testing.db.base import Base
+
+
+class TestAssignment(Base):
+    __tablename__ = "test_assignments"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
+    title: Mapped[str] = mapped_column(String(255), nullable=False)
+    status: Mapped[str] = mapped_column(String(20), default="assigned", nullable=False)
+    due_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
+    questions_count: Mapped[int] = mapped_column(Integer, default=20, nullable=False)
+    max_attempts: Mapped[int] = mapped_column(Integer, default=3, nullable=False)
+
+    user = relationship("User", back_populates="assignments")
diff --git a/src/terra_testing/models/sync_queue.py b/src/terra_testing/models/sync_queue.py
new file mode 100644
index 0000000000000000000000000000000000000000..0c52315df89c1def55c8c6245f63782f19c94d49
--- /dev/null
+++ b/src/terra_testing/models/sync_queue.py
@@ -0,0 +1,24 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+from sqlalchemy import DateTime, Integer, String, Text
+from sqlalchemy.orm import Mapped, mapped_column
+
+from terra_testing.db.base import Base
+from terra_testing.utils.time import utcnow
+
+
+class SyncQueueItem(Base):
+    __tablename__ = "sync_queue"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    entity_type: Mapped[str] = mapped_column(String(50), nullable=False)
+    entity_id: Mapped[int] = mapped_column(Integer, nullable=False)
+    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
+    payload_snapshot: Mapped[str | None] = mapped_column(Text, nullable=True)
+    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
+    retry_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
+    last_attempt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
+    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
+    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)
diff --git a/src/terra_testing/models/system_setting.py b/src/terra_testing/models/system_setting.py
new file mode 100644
index 0000000000000000000000000000000000000000..8a9613d1be4abf5a33206f056dc0c15ddad084c8
--- /dev/null
+++ b/src/terra_testing/models/system_setting.py
@@ -0,0 +1,14 @@
+from __future__ import annotations
+
+from sqlalchemy import Integer, String, Text
+from sqlalchemy.orm import Mapped, mapped_column
+
+from terra_testing.db.base import Base
+
+
+class SystemSetting(Base):
+    __tablename__ = "system_settings"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    key: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
+    value: Mapped[str] = mapped_column(Text, nullable=False)
diff --git a/src/terra_testing/models/test_result.py b/src/terra_testing/models/test_result.py
new file mode 100644
index 0000000000000000000000000000000000000000..083ad538645c9c3974cdd63075957773046243f0
--- /dev/null
+++ b/src/terra_testing/models/test_result.py
@@ -0,0 +1,41 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
+from sqlalchemy.orm import Mapped, mapped_column, relationship
+
+from terra_testing.db.base import Base
+from terra_testing.utils.time import utcnow
+
+
+class TestResult(Base):
+    __tablename__ = "test_results"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
+    assignment_id: Mapped[int | None] = mapped_column(ForeignKey("test_assignments.id"), nullable=True)
+    correct_answers: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
+    total_questions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
+    score_percent: Mapped[int] = mapped_column(Integer, nullable=False)
+    status: Mapped[str] = mapped_column(String(20), nullable=False)
+    sync_state: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
+    sync_error: Mapped[str | None] = mapped_column(Text, nullable=True)
+    retry_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
+    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
+    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
+
+    user = relationship("User", back_populates="results")
+    answers = relationship("TestAnswer", back_populates="result", cascade="all, delete-orphan")
+
+
+class TestAnswer(Base):
+    __tablename__ = "test_answers"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    result_id: Mapped[int] = mapped_column(ForeignKey("test_results.id"), nullable=False)
+    question_id: Mapped[int] = mapped_column(ForeignKey("questions.id"), nullable=False)
+    selected_answer_id: Mapped[int | None] = mapped_column(ForeignKey("answers.id"), nullable=True)
+    is_correct: Mapped[bool] = mapped_column(nullable=False, default=False)
+
+    result = relationship("TestResult", back_populates="answers")
diff --git a/src/terra_testing/models/user.py b/src/terra_testing/models/user.py
new file mode 100644
index 0000000000000000000000000000000000000000..2ff65694bd7d0297474cf4978cb6717a72fbbcf3
--- /dev/null
+++ b/src/terra_testing/models/user.py
@@ -0,0 +1,21 @@
+from __future__ import annotations
+
+from sqlalchemy import Boolean, ForeignKey, Integer, String
+from sqlalchemy.orm import Mapped, mapped_column, relationship
+
+from terra_testing.db.base import Base
+
+
+class User(Base):
+    __tablename__ = "users"
+
+    id: Mapped[int] = mapped_column(Integer, primary_key=True)
+    username: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
+    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
+    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
+    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
+    role_id: Mapped[int] = mapped_column(ForeignKey("roles.id"), nullable=False)
+
+    role = relationship("Role", back_populates="users")
+    assignments = relationship("TestAssignment", back_populates="user")
+    results = relationship("TestResult", back_populates="user")
diff --git a/src/terra_testing/pages/__init__.py b/src/terra_testing/pages/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..2d06820a2ca4b5fc03142b44542a9efe7ff6d0f2
--- /dev/null
+++ b/src/terra_testing/pages/__init__.py
@@ -0,0 +1,13 @@
+from terra_testing.pages.admin_dashboard_page import AdminDashboardPage
+from terra_testing.pages.admin_results_page import AdminResultsPage
+from terra_testing.pages.audit_log_page import AuditLogPage
+from terra_testing.pages.login_page import LoginPage
+from terra_testing.pages.questions_management_page import QuestionsManagementPage
+from terra_testing.pages.quiz_page import QuizPage
+from terra_testing.pages.reports_page import ReportsPage
+from terra_testing.pages.results_page import ResultsPage
+from terra_testing.pages.schedule_management_page import ScheduleManagementPage
+from terra_testing.pages.settings_page import SettingsPage
+from terra_testing.pages.sync_monitor_page import SyncMonitorPage
+from terra_testing.pages.user_dashboard_page import UserDashboardPage
+from terra_testing.pages.users_management_page import UsersManagementPage
diff --git a/src/terra_testing/pages/admin_dashboard_page.py b/src/terra_testing/pages/admin_dashboard_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..7f499bcc886a63e90a4616f79f4d6cb6cf245336
--- /dev/null
+++ b/src/terra_testing/pages/admin_dashboard_page.py
@@ -0,0 +1,57 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.components.stat_card import StatCard
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.schedule_service import ScheduleService
+from terra_testing.services.user_service import UserService
+
+
+class AdminDashboardPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.user_service = UserService()
+        self.question_service = QuestionService()
+        self.schedule_service = ScheduleService()
+        self.result_repository = ResultRepository()
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Панель администратора", "/admin")
+        if denied is not None:
+            return denied
+
+        pending_total = self.result_repository.count_pending_sync() + self.result_repository.count_failed_sync()
+        return ft.View(
+            route="/admin",
+            controls=build_shell(
+                "Панель администратора",
+                [
+                    ft.ResponsiveRow(
+                        controls=[
+                            ft.Container(content=StatCard("Пользователи", str(self.user_service.count_users())), col={"sm": 6, "md": 3}),
+                            ft.Container(content=StatCard("Активные вопросы", str(self.question_service.count_questions())), col={"sm": 6, "md": 3}),
+                            ft.Container(content=StatCard("Активные назначения", str(self.schedule_service.count_active_assignments())), col={"sm": 6, "md": 3}),
+                            ft.Container(content=StatCard("Pending sync", str(pending_total)), col={"sm": 6, "md": 3}),
+                        ]
+                    ),
+                    ft.Row(
+                        controls=[
+                            ft.FilledButton("Пользователи", on_click=lambda _: self.page.go("/admin/users")),
+                            ft.FilledButton("Вопросы", on_click=lambda _: self.page.go("/admin/questions")),
+                            ft.FilledButton("Расписание", on_click=lambda _: self.page.go("/admin/schedule")),
+                            ft.FilledButton("Результаты", on_click=lambda _: self.page.go("/admin/results")),
+                            ft.FilledButton("Синхронизация", on_click=lambda _: self.page.go("/admin/sync")),
+                            ft.FilledButton("Аудит", on_click=lambda _: self.page.go("/admin/audit")),
+                            ft.FilledButton("Отчёты", on_click=lambda _: self.page.go("/reports")),
+                            ft.FilledButton("Настройки", on_click=lambda _: self.page.go("/settings")),
+                        ],
+                        wrap=True,
+                    ),
+                ],
+                page=self.page,
+            ),
+        )
diff --git a/src/terra_testing/pages/admin_results_page.py b/src/terra_testing/pages/admin_results_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..adf8a4f6405374c62e07dde1f7fea4cb2a22b1c3
--- /dev/null
+++ b/src/terra_testing/pages/admin_results_page.py
@@ -0,0 +1,135 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+import flet as ft
+
+from terra_testing.app.access import require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.components.sync_badge import sync_badge
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.repositories.user_repository import UserRepository
+
+
+class AdminResultsPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.result_repository = ResultRepository()
+        self.user_repository = UserRepository()
+
+        self.user_filter = ft.Dropdown(label="Сотрудник", width=240, on_change=self._apply_filters)
+        self.status_filter = ft.Dropdown(
+            label="Статус",
+            width=180,
+            options=[ft.dropdown.Option("all", "Все"), ft.dropdown.Option("passed", "Пройден"), ft.dropdown.Option("failed", "Не пройден")],
+            value=page.session.get("admin_results_status_filter") or "all",
+            on_change=self._apply_filters,
+        )
+        self.sync_filter = ft.Dropdown(
+            label="Sync",
+            width=180,
+            options=[
+                ft.dropdown.Option("all", "Все"),
+                ft.dropdown.Option("pending", "Pending"),
+                ft.dropdown.Option("synced", "Synced"),
+                ft.dropdown.Option("failed", "Failed"),
+            ],
+            value=page.session.get("admin_results_sync_filter") or "all",
+            on_change=self._apply_filters,
+        )
+        self.date_from = ft.TextField(label="С даты (YYYY-MM-DD)", width=180, value=page.session.get("admin_results_date_from") or "", on_submit=self._apply_filters)
+        self.date_to = ft.TextField(label="По дату (YYYY-MM-DD)", width=180, value=page.session.get("admin_results_date_to") or "", on_submit=self._apply_filters)
+        self.message = ft.Text()
+
+    def _apply_filters(self, _: ft.ControlEvent | None = None) -> None:
+        self.page.session.set("admin_results_user_filter", self.user_filter.value)
+        self.page.session.set("admin_results_status_filter", self.status_filter.value)
+        self.page.session.set("admin_results_sync_filter", self.sync_filter.value)
+        self.page.session.set("admin_results_date_from", self.date_from.value)
+        self.page.session.set("admin_results_date_to", self.date_to.value)
+        self.page.go("/admin/results")
+
+    def _init_filters(self) -> None:
+        users = self.user_repository.list_users()
+        options = [ft.dropdown.Option("all", "Все")] + [ft.dropdown.Option(str(user.id), user.full_name) for user in users]
+        self.user_filter.options = options
+        self.user_filter.value = self.page.session.get("admin_results_user_filter") or "all"
+
+    def _parse_day(self, raw: str | None):
+        value = (raw or "").strip()
+        if not value:
+            return None
+        try:
+            return datetime.strptime(value, "%Y-%m-%d")
+        except ValueError:
+            self.message.value = f"Неверная дата: {value}"
+            self.message.color = ft.Colors.RED
+            return None
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Все результаты", "/admin/results")
+        if denied is not None:
+            return denied
+
+        self._init_filters()
+        users = {user.id: user for user in self.user_repository.list_users()}
+        selected_user = None if self.user_filter.value in {None, "all"} else int(self.user_filter.value)
+        day_from = self._parse_day(self.date_from.value)
+        day_to = self._parse_day(self.date_to.value)
+        results = self.result_repository.list_filtered_results_by_day(
+            user_id=selected_user,
+            status=self.status_filter.value,
+            sync_state=self.sync_filter.value,
+            day_from=day_from,
+            day_to=day_to,
+        )
+        rows = []
+        for result in results:
+            user = users.get(result.user_id)
+            rows.append(
+                ft.DataRow(
+                    cells=[
+                        ft.DataCell(ft.Text(str(result.id))),
+                        ft.DataCell(ft.Text(user.full_name if user else f"User #{result.user_id}")),
+                        ft.DataCell(ft.Text(str(result.correct_answers))),
+                        ft.DataCell(ft.Text(str(result.total_questions))),
+                        ft.DataCell(ft.Text(str(result.score_percent))),
+                        ft.DataCell(ft.Text(result.status)),
+                        ft.DataCell(ft.Text(result.completed_at.strftime("%Y-%m-%d %H:%M"))),
+                        ft.DataCell(sync_badge(result.sync_state)),
+                    ]
+                )
+            )
+
+        passed_count = sum(1 for result in results if result.status == "passed")
+        failed_count = sum(1 for result in results if result.status == "failed")
+
+        controls = [
+            ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
+            ft.Row([self.user_filter, self.status_filter, self.sync_filter, self.date_from, self.date_to, ft.OutlinedButton("Применить", on_click=self._apply_filters)], wrap=True),
+        ]
+        if self.message.value:
+            controls.append(self.message)
+        controls.extend([
+            ft.Text(
+                f"Найдено результатов: {len(rows)} | "
+                f"Пройдено: {passed_count} | Не пройдено: {failed_count}"
+            ),
+            ft.DataTable(
+                columns=[
+                    ft.DataColumn(ft.Text("ID")),
+                    ft.DataColumn(ft.Text("Сотрудник")),
+                    ft.DataColumn(ft.Text("Верных")),
+                    ft.DataColumn(ft.Text("Всего")),
+                    ft.DataColumn(ft.Text("%")),
+                    ft.DataColumn(ft.Text("Статус")),
+                    ft.DataColumn(ft.Text("Дата")),
+                    ft.DataColumn(ft.Text("Sync")),
+                ],
+                rows=rows,
+            ),
+        ])
+        return ft.View(
+            route="/admin/results",
+            controls=build_shell("Все результаты", controls, page=self.page),
+        )
diff --git a/src/terra_testing/pages/audit_log_page.py b/src/terra_testing/pages/audit_log_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..f8c821523a10630c03a3afe69c7590d33126c784
--- /dev/null
+++ b/src/terra_testing/pages/audit_log_page.py
@@ -0,0 +1,125 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+import flet as ft
+
+from terra_testing.app.access import require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.report_service import ReportService
+
+
+class AuditLogPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.audit_service = AuditService()
+        self.report_service = ReportService()
+        self.message = ft.Text()
+        self.event_filter = ft.TextField(label="Тип события", width=180, value=page.session.get("audit_event_filter") or "")
+        self.date_from = ft.TextField(label="С даты (YYYY-MM-DD)", width=180, value=page.session.get("audit_date_from") or "")
+        self.date_to = ft.TextField(label="По дату (YYYY-MM-DD)", width=180, value=page.session.get("audit_date_to") or "")
+
+    def _parse_day(self, raw: str | None):
+        value = (raw or "").strip()
+        if not value:
+            return None
+        try:
+            return datetime.strptime(value, "%Y-%m-%d")
+        except ValueError:
+            self.message.value = f"Неверная дата: {value}"
+            self.message.color = ft.Colors.RED
+            return None
+
+    def _apply_filters(self, _: ft.ControlEvent | None = None) -> None:
+        self.page.session.set("audit_event_filter", self.event_filter.value)
+        self.page.session.set("audit_date_from", self.date_from.value)
+        self.page.session.set("audit_date_to", self.date_to.value)
+        self.page.go("/admin/audit")
+
+    def _build_rows(self) -> list[dict]:
+        rows = []
+        day_from = self._parse_day(self.date_from.value)
+        day_to = self._parse_day(self.date_to.value)
+        for item in self.audit_service.list_filtered(
+            event_type=(self.event_filter.value or "").strip() or None,
+            day_from=day_from,
+            day_to=day_to,
+        ):
+            rows.append(
+                {
+                    "id": item.id,
+                    "created_at": item.created_at.strftime("%Y-%m-%d %H:%M"),
+                    "event_type": item.event_type,
+                    "actor": item.actor,
+                    "message": item.message,
+                }
+            )
+        return rows
+
+    def _export_pdf(self, _: ft.ControlEvent) -> None:
+        path = self.report_service.export_audit_pdf(self._build_rows())
+        self.message.value = f"PDF сохранён: {path}"
+        self.message.color = ft.Colors.GREEN
+        self.page.update()
+
+    def _export_excel(self, _: ft.ControlEvent) -> None:
+        path = self.report_service.export_audit_excel(self._build_rows())
+        self.message.value = f"Excel сохранён: {path}"
+        self.message.color = ft.Colors.GREEN
+        self.page.update()
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Журнал аудита", "/admin/audit")
+        if denied is not None:
+            return denied
+
+        rows = [
+            ft.DataRow(
+                cells=[
+                    ft.DataCell(ft.Text(str(item["id"]))),
+                    ft.DataCell(ft.Text(item["created_at"])),
+                    ft.DataCell(ft.Text(item["event_type"])),
+                    ft.DataCell(ft.Text(item["actor"])),
+                    ft.DataCell(ft.Text(item["message"][:120])),
+                ]
+            )
+            for item in self._build_rows()
+        ]
+
+        return ft.View(
+            route="/admin/audit",
+            controls=build_shell(
+                "Журнал аудита",
+                [
+                    ft.Row(
+                        [
+                            ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
+                            self.event_filter,
+                            self.date_from,
+                            self.date_to,
+                            ft.OutlinedButton("Применить", on_click=self._apply_filters),
+                        ],
+                        wrap=True,
+                    ),
+                    ft.Row(
+                        [
+                            ft.FilledButton("Экспорт PDF", on_click=self._export_pdf),
+                            ft.FilledButton("Экспорт Excel", on_click=self._export_excel),
+                        ]
+                    ),
+                    self.message,
+                    ft.DataTable(
+                        columns=[
+                            ft.DataColumn(ft.Text("ID")),
+                            ft.DataColumn(ft.Text("Дата")),
+                            ft.DataColumn(ft.Text("Событие")),
+                            ft.DataColumn(ft.Text("Актор")),
+                            ft.DataColumn(ft.Text("Сообщение")),
+                        ],
+                        rows=rows,
+                    ),
+                ],
+                page=self.page,
+            ),
+        )
diff --git a/src/terra_testing/pages/login_page.py b/src/terra_testing/pages/login_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..a344357ab83f220941d28170276b74e372754723
--- /dev/null
+++ b/src/terra_testing/pages/login_page.py
@@ -0,0 +1,62 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.session_state import SessionState
+from terra_testing.services.auth_service import AuthService
+
+
+class LoginPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.auth_service = AuthService()
+
+        self.username = ft.TextField(label="Логин", autofocus=True, width=320)
+        self.password = ft.TextField(label="Пароль", password=True, can_reveal_password=True, width=320)
+        self.message = ft.Text(value="")
+
+    def _handle_login(self, _: ft.ControlEvent) -> None:
+        result = self.auth_service.login(
+            username=self.username.value.strip(),
+            password=self.password.value,
+        )
+
+        if result["success"]:
+            self.page.session.set(
+                "state",
+                SessionState(
+                    user_id=result["user_id"],
+                    username=result["username"],
+                    role=result["role"],
+                    is_authenticated=True,
+                ),
+            )
+            self.message.value = "Вход выполнен"
+            self.message.color = ft.Colors.GREEN
+            self.page.go("/admin" if result["role"] == "admin" else "/user")
+        else:
+            self.message.value = result["error"]
+            self.message.color = ft.Colors.RED
+
+        self.page.update()
+
+    def build(self) -> ft.View:
+        return ft.View(
+            route="/login",
+            controls=[
+                ft.Container(
+                    expand=True,
+                    alignment=ft.alignment.center,
+                    content=ft.Column(
+                        controls=[
+                            ft.Text("ИС тестирования знаний", size=28, weight=ft.FontWeight.BOLD),
+                            self.username,
+                            self.password,
+                            ft.FilledButton("Войти", on_click=self._handle_login, width=320),
+                            self.message,
+                        ],
+                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
+                    ),
+                )
+            ],
+        )
diff --git a/src/terra_testing/pages/questions_management_page.py b/src/terra_testing/pages/questions_management_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..0020ecd29a03f532abe769ab089534b8a174ea2c
--- /dev/null
+++ b/src/terra_testing/pages/questions_management_page.py
@@ -0,0 +1,271 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import actor_name, require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.question_service import QuestionService
+
+
+class QuestionsManagementPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.question_service = QuestionService()
+        self.audit_service = AuditService()
+        self.category_name = ft.TextField(label="Новая категория", width=260)
+        self.category_dropdown = ft.Dropdown(label="Категория", width=220)
+        self.question_text = ft.TextField(label="Текст вопроса", multiline=True, min_lines=2, max_lines=4, width=600)
+        self.answer_1 = ft.TextField(label="Ответ 1", width=320)
+        self.answer_2 = ft.TextField(label="Ответ 2", width=320)
+        self.answer_3 = ft.TextField(label="Ответ 3", width=320)
+        self.answer_4 = ft.TextField(label="Ответ 4", width=320)
+        self.correct_index = ft.Dropdown(
+            label="Правильный ответ",
+            width=220,
+            options=[ft.dropdown.Option("1"), ft.dropdown.Option("2"), ft.dropdown.Option("3"), ft.dropdown.Option("4")],
+            value="1",
+        )
+        self.message = ft.Text()
+
+    def _is_admin(self) -> bool:
+        return require_admin(self.page, "Управление вопросами", "/admin/questions") is None
+
+    def _edit_question_id(self) -> int | None:
+        value = self.page.session.get("edit_question_id")
+        return int(value) if value not in {None, ""} else None
+
+    def _set_message(self, text: str, ok: bool) -> None:
+        self.message.value = text
+        self.message.color = ft.Colors.GREEN if ok else ft.Colors.RED
+        self.page.update()
+
+    def _answer_controls(self) -> list[ft.TextField]:
+        return [self.answer_1, self.answer_2, self.answer_3, self.answer_4]
+
+    def _refresh_categories(self) -> None:
+        categories = self.question_service.list_categories()
+        self.category_dropdown.options = [ft.dropdown.Option(str(category.id), category.name) for category in categories]
+        if categories and self.category_dropdown.value is None:
+            self.category_dropdown.value = str(categories[0].id)
+
+    def _load_edit_state(self) -> None:
+        question_id = self._edit_question_id()
+        if not question_id:
+            return
+        question = self.question_service.get_question(question_id)
+        if question is None:
+            self.page.session.set("edit_question_id", None)
+            return
+        self.category_dropdown.value = str(question.category_id)
+        self.question_text.value = question.text
+        answers = list(question.answers)
+        for control in self._answer_controls():
+            control.value = ""
+        correct_index = "1"
+        for index, answer in enumerate(answers[:4], start=1):
+            self._answer_controls()[index - 1].value = answer.text
+            if answer.is_correct:
+                correct_index = str(index)
+        self.correct_index.value = correct_index
+
+    def _reset_form(self) -> None:
+        self.page.session.set("edit_question_id", None)
+        self.question_text.value = ""
+        for control in self._answer_controls():
+            control.value = ""
+        self.correct_index.value = "1"
+        if self.category_dropdown.options:
+            self.category_dropdown.value = self.category_dropdown.options[0].key
+
+    def _build_answers(self) -> list[dict]:
+        answers = []
+        for index, control in enumerate(self._answer_controls(), start=1):
+            text = (control.value or "").strip()
+            if text:
+                answers.append({"text": text, "is_correct": str(index) == self.correct_index.value})
+        return answers
+
+    def _create_category(self, _: ft.ControlEvent) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для создания категории", False)
+            return
+        name = (self.category_name.value or "").strip()
+        if not name:
+            self._set_message("Введите название категории", False)
+            return
+        category = self.question_service.create_category(name)
+        self.audit_service.log("category_created", actor_name(self.page), f"Создана категория {category.name}")
+        self.category_name.value = ""
+        self.page.go("/admin/questions")
+
+    def _save_question(self, _: ft.ControlEvent) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для сохранения вопроса", False)
+            return
+        if not self.category_dropdown.value or not self.question_text.value:
+            self._set_message("Заполните категорию и текст вопроса", False)
+            return
+
+        answers = self._build_answers()
+        if len(answers) < 2:
+            self._set_message("Нужно минимум два варианта ответа", False)
+            return
+        if not any(answer["is_correct"] for answer in answers):
+            self._set_message("Нужно выбрать правильный вариант ответа", False)
+            return
+
+        question_id = self._edit_question_id()
+        actor = actor_name(self.page)
+        if question_id is None:
+            question = self.question_service.create_question(
+                category_id=int(self.category_dropdown.value),
+                text=self.question_text.value.strip(),
+                answers=answers,
+            )
+            self.audit_service.log("question_created", actor, f"Создан вопрос #{question.id}")
+        else:
+            question = self.question_service.update_question(
+                question_id=question_id,
+                category_id=int(self.category_dropdown.value),
+                text=self.question_text.value.strip(),
+                answers=answers,
+            )
+            if question is None:
+                self._set_message("Вопрос не найден", False)
+                return
+            self.audit_service.log("question_updated", actor, f"Обновлён вопрос #{question.id}")
+
+        self._reset_form()
+        self.page.go("/admin/questions")
+
+    def _start_edit(self, question_id: int) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для редактирования", False)
+            return
+        self.page.session.set("edit_question_id", question_id)
+        self.page.go("/admin/questions")
+
+    def _cancel_edit(self, _: ft.ControlEvent) -> None:
+        self._reset_form()
+        self.page.go("/admin/questions")
+
+    def _toggle_question_active(self, question_id: int, is_active: bool) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для изменения статуса", False)
+            return
+        question = self.question_service.set_question_active(question_id, not is_active)
+        if question is not None:
+            action = "активирован" if question.is_active else "деактивирован"
+            self.audit_service.log("question_status_changed", actor_name(self.page), f"Вопрос #{question.id} {action}")
+        self.page.go("/admin/questions")
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Управление вопросами", "/admin/questions")
+        if denied is not None:
+            return denied
+
+        self._refresh_categories()
+        self._load_edit_state()
+
+        rows = []
+        for question in self.question_service.list_questions():
+            action_label = "Отключить" if question.is_active else "Включить"
+            rows.append(
+                ft.DataRow(
+                    cells=[
+                        ft.DataCell(ft.Text(str(question.id))),
+                        ft.DataCell(ft.Text(question.category.name if question.category else "")),
+                        ft.DataCell(ft.Text(question.text[:80])),
+                        ft.DataCell(ft.Text(str(len(question.answers)))),
+                        ft.DataCell(ft.Text("Да" if question.is_active else "Нет")),
+                        ft.DataCell(
+                            ft.Row(
+                                controls=[
+                                    ft.TextButton("Редактировать", on_click=lambda _, qid=question.id: self._start_edit(qid)),
+                                    ft.TextButton(action_label, on_click=lambda _, qid=question.id, active=question.is_active: self._toggle_question_active(qid, active)),
+                                ],
+                                wrap=True,
+                            )
+                        ),
+                    ]
+                )
+            )
+
+        categories = self.question_service.list_categories()
+        category_rows = [
+            ft.DataRow(cells=[
+                ft.DataCell(ft.Text(str(category.id))),
+                ft.DataCell(ft.Text(category.name)),
+                ft.DataCell(ft.Text("Да" if category.is_active else "Нет")),
+            ])
+            for category in categories
+        ]
+
+        edit_mode = self._edit_question_id() is not None
+
+        return ft.View(
+            route="/admin/questions",
+            controls=build_shell(
+                "Управление вопросами",
+                [
+                    ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
+                    ft.Card(
+                        content=ft.Container(
+                            padding=16,
+                            content=ft.Column(
+                                controls=[
+                                    ft.Text("Категории", weight=ft.FontWeight.BOLD),
+                                    ft.Row([self.category_name, ft.FilledButton("Создать категорию", on_click=self._create_category)]),
+                                    ft.DataTable(
+                                        columns=[
+                                            ft.DataColumn(ft.Text("ID")),
+                                            ft.DataColumn(ft.Text("Категория")),
+                                            ft.DataColumn(ft.Text("Активна")),
+                                        ],
+                                        rows=category_rows,
+                                    ),
+                                ]
+                            ),
+                        )
+                    ),
+                    ft.Card(
+                        content=ft.Container(
+                            padding=16,
+                            content=ft.Column(
+                                controls=[
+                                    ft.Text("Редактировать вопрос" if edit_mode else "Новый вопрос", weight=ft.FontWeight.BOLD),
+                                    ft.Row([self.category_dropdown, self.correct_index], wrap=True),
+                                    self.question_text,
+                                    ft.ResponsiveRow(
+                                        controls=[
+                                            ft.Container(self.answer_1, col={"sm": 12, "md": 6}),
+                                            ft.Container(self.answer_2, col={"sm": 12, "md": 6}),
+                                            ft.Container(self.answer_3, col={"sm": 12, "md": 6}),
+                                            ft.Container(self.answer_4, col={"sm": 12, "md": 6}),
+                                        ]
+                                    ),
+                                    ft.Row([
+                                        ft.FilledButton("Сохранить вопрос", on_click=self._save_question),
+                                        ft.OutlinedButton("Сбросить", on_click=self._cancel_edit),
+                                        self.message,
+                                    ], wrap=True),
+                                ]
+                            ),
+                        )
+                    ),
+                    ft.DataTable(
+                        columns=[
+                            ft.DataColumn(ft.Text("ID")),
+                            ft.DataColumn(ft.Text("Категория")),
+                            ft.DataColumn(ft.Text("Вопрос")),
+                            ft.DataColumn(ft.Text("Ответов")),
+                            ft.DataColumn(ft.Text("Активен")),
+                            ft.DataColumn(ft.Text("Действия")),
+                        ],
+                        rows=rows,
+                    ),
+                ],
+                page=self.page,
+            ),
+        )
diff --git a/src/terra_testing/pages/quiz_page.py b/src/terra_testing/pages/quiz_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..f13dbf71b7e9f4590178117b29519ebdfdf9cccb
--- /dev/null
+++ b/src/terra_testing/pages/quiz_page.py
@@ -0,0 +1,218 @@
+from __future__ import annotations
+
+import asyncio
+import math
+import time
+import uuid
+
+import flet as ft
+
+from terra_testing.app.access import require_user
+from terra_testing.app.session_state import SessionState
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.quiz_service import QuizService
+
+
+class QuizPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.quiz_service = QuizService()
+        self.message = ft.Text()
+        self.timer_text = ft.Text()
+
+    def _load_or_create_quiz_state(self) -> dict | None:
+        quiz_state = self.page.session.get('quiz_state')
+        active_assignment_id = self.page.session.get('active_assignment_id')
+        state: SessionState = self.page.session.get('state')
+        user_id = state.user_id if state and state.user_id is not None else 1
+
+        if quiz_state and quiz_state.get('assignment_id') == active_assignment_id:
+            return quiz_state
+
+        try:
+            start_payload = self.quiz_service.start_quiz(user_id=user_id, assignment_id=active_assignment_id)
+        except ValueError as exc:
+            self.message.value = str(exc)
+            self.message.color = ft.Colors.RED
+            return None
+
+        quiz_state = {
+            'assignment_id': active_assignment_id,
+            'question_ids': [question.id for question in start_payload['questions']],
+            'selected_answer_ids': {},
+            'seconds_per_question': start_payload['seconds_per_question'],
+            'current_index': 0,
+            'current_question_id': None,
+            'deadline_ts': None,
+            'timer_token': None,
+        }
+        self.page.session.set('quiz_state', quiz_state)
+        return quiz_state
+
+    def _select_answer(self, question_id: int, value: str | None) -> None:
+        quiz_state = self._load_or_create_quiz_state()
+        if quiz_state is None:
+            return
+        quiz_state['selected_answer_ids'][question_id] = int(value) if value else None
+        self.page.session.set('quiz_state', quiz_state)
+
+    def _bump_timer(self, quiz_state: dict, question_id: int) -> dict:
+        if quiz_state.get('current_question_id') != question_id:
+            quiz_state['current_question_id'] = question_id
+            quiz_state['deadline_ts'] = time.time() + int(quiz_state['seconds_per_question'])
+            quiz_state['timer_token'] = uuid.uuid4().hex
+            self.page.session.set('quiz_state', quiz_state)
+        return quiz_state
+
+    async def _countdown_task(self, token: str) -> None:
+        while True:
+            await asyncio.sleep(1)
+            quiz_state = self.page.session.get('quiz_state')
+            if not quiz_state or quiz_state.get('timer_token') != token:
+                return
+            if self.page.route != '/quiz':
+                return
+            deadline_ts = quiz_state.get('deadline_ts')
+            if deadline_ts is None:
+                return
+            remaining = max(0, int(math.ceil(deadline_ts - time.time())))
+            self.timer_text.value = f'Осталось времени: {remaining} сек.'
+            try:
+                self.page.update()
+            except Exception:
+                return
+            if remaining <= 0:
+                self._advance_on_timeout()
+                return
+
+    def _start_timer_task(self, token: str) -> None:
+        try:
+            self.page.run_task(self._countdown_task, token)
+        except Exception:
+            pass
+
+    def _move_to_index(self, new_index: int) -> None:
+        quiz_state = self._load_or_create_quiz_state()
+        if quiz_state is None:
+            return
+        max_index = max(0, len(quiz_state['question_ids']) - 1)
+        quiz_state['current_index'] = max(0, min(max_index, new_index))
+        quiz_state['current_question_id'] = None
+        quiz_state['deadline_ts'] = None
+        quiz_state['timer_token'] = None
+        self.page.session.set('quiz_state', quiz_state)
+        self.page.go('/quiz')
+
+    def _next_question(self, _: ft.ControlEvent) -> None:
+        quiz_state = self._load_or_create_quiz_state()
+        if quiz_state is None:
+            return
+        self._move_to_index(quiz_state.get('current_index', 0) + 1)
+
+    def _prev_question(self, _: ft.ControlEvent) -> None:
+        quiz_state = self._load_or_create_quiz_state()
+        if quiz_state is None:
+            return
+        self._move_to_index(quiz_state.get('current_index', 0) - 1)
+
+    def _finish_quiz(self) -> None:
+        quiz_state = self._load_or_create_quiz_state()
+        if quiz_state is None:
+            self.page.go('/user')
+            return
+        state: SessionState = self.page.session.get('state')
+        user_id = state.user_id if state and state.user_id is not None else 1
+        questions = self.quiz_service.question_repository.get_questions_by_ids(quiz_state['question_ids'])
+
+        result = self.quiz_service.complete_quiz_from_selection(
+            user_id=user_id,
+            questions=questions,
+            selected_answer_ids=quiz_state['selected_answer_ids'],
+            assignment_id=quiz_state.get('assignment_id'),
+        )
+        self.page.session.set('quiz_state', None)
+        self.page.session.set('active_assignment_id', None)
+        self.page.session.set('last_result_id', result.id)
+        self.page.go('/results')
+
+    def _submit_quiz(self, _: ft.ControlEvent) -> None:
+        self._finish_quiz()
+
+    def _advance_on_timeout(self) -> None:
+        quiz_state = self.page.session.get('quiz_state')
+        if not quiz_state:
+            return
+        current_index = quiz_state.get('current_index', 0)
+        if current_index < len(quiz_state.get('question_ids', [])) - 1:
+            self._move_to_index(current_index + 1)
+        else:
+            self._finish_quiz()
+
+    def build(self) -> ft.View:
+        denied = require_user(self.page, "Тестирование", "/quiz")
+        if denied is not None:
+            return denied
+        quiz_state = self._load_or_create_quiz_state()
+        controls: list[ft.Control] = []
+        if self.message.value:
+            controls.append(self.message)
+
+        if quiz_state is None:
+            controls.append(ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/user')))
+            return ft.View(route='/quiz', controls=build_shell('Прохождение теста', controls, page=self.page))
+
+        questions = self.quiz_service.question_repository.get_questions_by_ids(quiz_state['question_ids'])
+        total_questions = len(questions)
+        current_index = min(quiz_state.get('current_index', 0), max(0, total_questions - 1))
+        quiz_state['current_index'] = current_index
+        self.page.session.set('quiz_state', quiz_state)
+
+        controls.extend([
+            ft.Text(f'Вопрос {current_index + 1} из {total_questions}'),
+            ft.Text(f'Норматив: {quiz_state["seconds_per_question"]} секунд на вопрос'),
+        ])
+
+        if not questions:
+            controls.append(ft.Text('Нет доступных вопросов для теста.'))
+            controls.append(ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/user')))
+            return ft.View(route='/quiz', controls=build_shell('Прохождение теста', controls, page=self.page))
+
+        question = questions[current_index]
+        quiz_state = self._bump_timer(quiz_state, question.id)
+        deadline_ts = quiz_state.get('deadline_ts')
+        remaining = max(0, int(math.ceil(deadline_ts - time.time()))) if deadline_ts else int(quiz_state['seconds_per_question'])
+        self.timer_text.value = f'Осталось времени: {remaining} сек.'
+        if quiz_state.get('timer_token'):
+            self._start_timer_task(quiz_state['timer_token'])
+
+        selected_value = quiz_state['selected_answer_ids'].get(question.id)
+        radio = ft.RadioGroup(
+            value=str(selected_value) if selected_value is not None else None,
+            content=ft.Column(controls=[ft.Radio(value=str(answer.id), label=answer.text) for answer in question.answers]),
+            on_change=lambda e, question_id=question.id: self._select_answer(question_id, e.control.value),
+        )
+        controls.append(self.timer_text)
+        controls.append(
+            ft.Card(
+                content=ft.Container(
+                    padding=16,
+                    content=ft.Column(
+                        controls=[
+                            ft.Text(question.text, weight=ft.FontWeight.BOLD),
+                            radio,
+                        ]
+                    ),
+                )
+            )
+        )
+
+        nav = [ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/user'))]
+        if current_index > 0:
+            nav.append(ft.OutlinedButton('Предыдущий', on_click=self._prev_question))
+        if current_index < total_questions - 1:
+            nav.append(ft.FilledButton('Следующий', on_click=self._next_question))
+        else:
+            nav.append(ft.FilledButton('Завершить тест', on_click=self._submit_quiz))
+        controls.append(ft.Row(nav, wrap=True))
+
+        return ft.View(route='/quiz', controls=build_shell('Прохождение теста', controls, page=self.page))
diff --git a/src/terra_testing/pages/reports_page.py b/src/terra_testing/pages/reports_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..7d328e84e4f94bb05a0e6c997a6f7324032799b3
--- /dev/null
+++ b/src/terra_testing/pages/reports_page.py
@@ -0,0 +1,132 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+import flet as ft
+
+from terra_testing.app.access import require_authenticated
+from terra_testing.components.app_shell import build_shell
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.repositories.user_repository import UserRepository
+from terra_testing.services.report_service import ReportService
+
+
+class ReportsPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.report_service = ReportService()
+        self.result_repository = ResultRepository()
+        self.user_repository = UserRepository()
+        self.message = ft.Text()
+        self.status_filter = ft.Dropdown(
+            label='Статус',
+            width=180,
+            options=[ft.dropdown.Option('all', 'Все'), ft.dropdown.Option('passed', 'Пройден'), ft.dropdown.Option('failed', 'Не пройден')],
+            value=page.session.get('reports_status_filter') or 'all',
+            on_change=self._apply_filters,
+        )
+        self.sync_filter = ft.Dropdown(
+            label='Sync',
+            width=180,
+            options=[ft.dropdown.Option('all', 'Все'), ft.dropdown.Option('pending', 'Pending'), ft.dropdown.Option('synced', 'Synced'), ft.dropdown.Option('failed', 'Failed')],
+            value=page.session.get('reports_sync_filter') or 'all',
+            on_change=self._apply_filters,
+        )
+        self.date_from = ft.TextField(label='С даты (YYYY-MM-DD)', width=180, value=page.session.get('reports_date_from') or '')
+        self.date_to = ft.TextField(label='По дату (YYYY-MM-DD)', width=180, value=page.session.get('reports_date_to') or '')
+
+    def _apply_filters(self, _: ft.ControlEvent | None = None) -> None:
+        self.page.session.set('reports_status_filter', self.status_filter.value)
+        self.page.session.set('reports_sync_filter', self.sync_filter.value)
+        self.page.session.set('reports_date_from', self.date_from.value)
+        self.page.session.set('reports_date_to', self.date_to.value)
+        self.page.go('/reports')
+
+    def _parse_day(self, raw: str | None):
+        value = (raw or '').strip()
+        if not value:
+            return None
+        try:
+            return datetime.strptime(value, '%Y-%m-%d')
+        except ValueError:
+            self.message.value = f'Неверная дата: {value}'
+            self.message.color = ft.Colors.RED
+            return None
+
+    def _build_rows(self) -> list[dict]:
+        users = {user.id: user for user in self.user_repository.list_users()}
+        day_from = self._parse_day(self.date_from.value)
+        day_to = self._parse_day(self.date_to.value)
+        rows = []
+        for result in self.result_repository.list_filtered_results_by_day(
+            status=self.status_filter.value,
+            sync_state=self.sync_filter.value,
+            day_from=day_from,
+            day_to=day_to,
+        ):
+            user = users.get(result.user_id)
+            rows.append(
+                {
+                    'full_name': user.full_name if user else f'User #{result.user_id}',
+                    'score_percent': result.score_percent,
+                    'status': result.status,
+                    'sync_state': result.sync_state,
+                    'completed_at': result.completed_at.strftime('%Y-%m-%d %H:%M'),
+                }
+            )
+        return rows or [{'full_name': 'Нет данных', 'score_percent': 0, 'status': 'n/a', 'sync_state': 'n/a', 'completed_at': '-'}]
+
+    def _export_pdf(self, _: ft.ControlEvent) -> None:
+        path = self.report_service.export_results_pdf(self._build_rows())
+        self.message.value = f'PDF сохранён: {path}'
+        self.message.color = ft.Colors.GREEN
+        self.page.update()
+
+    def _export_excel(self, _: ft.ControlEvent) -> None:
+        path = self.report_service.export_results_excel(self._build_rows())
+        self.message.value = f'Excel сохранён: {path}'
+        self.message.color = ft.Colors.GREEN
+        self.page.update()
+
+    def build(self) -> ft.View:
+        denied = require_authenticated(self.page, "Отчёты", "/reports")
+        if denied is not None:
+            return denied
+
+        preview_rows = self._build_rows()[:10]
+        controls = [
+            ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/admin')),
+            ft.Row([self.status_filter, self.sync_filter, self.date_from, self.date_to, ft.OutlinedButton('Применить', on_click=self._apply_filters)], wrap=True),
+            ft.Row(
+                controls=[
+                    ft.FilledButton('Экспорт PDF', on_click=self._export_pdf),
+                    ft.FilledButton('Экспорт Excel', on_click=self._export_excel),
+                ]
+            ),
+        ]
+        if self.message.value:
+            controls.append(self.message)
+        controls.append(
+            ft.DataTable(
+                columns=[
+                    ft.DataColumn(ft.Text('Сотрудник')),
+                    ft.DataColumn(ft.Text('Баллы')),
+                    ft.DataColumn(ft.Text('Статус')),
+                    ft.DataColumn(ft.Text('Sync')),
+                    ft.DataColumn(ft.Text('Дата')),
+                ],
+                rows=[
+                    ft.DataRow(
+                        cells=[
+                            ft.DataCell(ft.Text(row['full_name'])),
+                            ft.DataCell(ft.Text(str(row['score_percent']))),
+                            ft.DataCell(ft.Text(row['status'])),
+                            ft.DataCell(ft.Text(row['sync_state'])),
+                            ft.DataCell(ft.Text(row['completed_at'])),
+                        ]
+                    )
+                    for row in preview_rows
+                ],
+            )
+        )
+        return ft.View(route='/reports', controls=build_shell('Отчёты', controls, page=self.page))
diff --git a/src/terra_testing/pages/results_page.py b/src/terra_testing/pages/results_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..f89095126b5327c8c6675d0303f4fd1a6ee894e1
--- /dev/null
+++ b/src/terra_testing/pages/results_page.py
@@ -0,0 +1,49 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import require_user
+from terra_testing.app.session_state import SessionState
+from terra_testing.components.app_shell import build_shell
+from terra_testing.components.sync_badge import sync_badge
+from terra_testing.repositories.result_repository import ResultRepository
+
+
+class ResultsPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.repository = ResultRepository()
+
+    def build(self) -> ft.View:
+        denied = require_user(self.page, "Результаты", "/results")
+        if denied is not None:
+            return denied
+
+        state: SessionState = self.page.session.get('state')
+        user_id = state.user_id if state and state.user_id is not None else 1
+        results = self.repository.list_results_for_user(user_id)
+        back_route = '/admin' if state and state.role == 'admin' else '/user'
+
+        controls: list[ft.Control] = [ft.OutlinedButton('Назад', on_click=lambda _: self.page.go(back_route))]
+        for result in results:
+            controls.append(
+                ft.Card(
+                    content=ft.Container(
+                        padding=16,
+                        content=ft.Column(
+                            controls=[
+                                ft.Text(f'Результат #{result.id}', weight=ft.FontWeight.BOLD),
+                                ft.Text(f'Правильных ответов: {result.correct_answers} из {result.total_questions}'),
+                                ft.Text(f'Баллы: {result.score_percent}%'),
+                                ft.Text(f'Статус: {result.status}'),
+                                sync_badge(result.sync_state),
+                            ]
+                        ),
+                    )
+                )
+            )
+
+        if not results:
+            controls.append(ft.Text('Результатов пока нет.'))
+
+        return ft.View(route='/results', controls=build_shell('Результаты', controls, page=self.page))
diff --git a/src/terra_testing/pages/schedule_management_page.py b/src/terra_testing/pages/schedule_management_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..1a75d63556251e40391f6f3231aa72ee239b568a
--- /dev/null
+++ b/src/terra_testing/pages/schedule_management_page.py
@@ -0,0 +1,216 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+import flet as ft
+
+from terra_testing.app.access import actor_name, require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.schedule_service import ScheduleService
+from terra_testing.services.user_service import UserService
+
+
+class ScheduleManagementPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.schedule_service = ScheduleService()
+        self.user_service = UserService()
+        self.audit_service = AuditService()
+        self.user_dropdown = ft.Dropdown(label='Сотрудник', width=260)
+        self.title = ft.TextField(label='Название тестирования', width=320, value='Плановое тестирование')
+        self.questions_count = ft.TextField(label='Вопросов', width=120, value='20')
+        self.max_attempts = ft.TextField(label='Попыток', width=120, value='3')
+        self.due_at = ft.TextField(label='Срок (YYYY-MM-DD HH:MM)', width=220)
+        self.status_dropdown = ft.Dropdown(
+            label='Статус',
+            width=180,
+            options=[
+                ft.dropdown.Option('assigned', 'assigned'),
+                ft.dropdown.Option('completed', 'completed'),
+                ft.dropdown.Option('cancelled', 'cancelled'),
+            ],
+            value='assigned',
+        )
+        self.message = ft.Text()
+
+    def _refresh_users(self) -> None:
+        users = [user for user in self.user_service.list_users() if user.role and user.role.name == 'user']
+        self.user_dropdown.options = [ft.dropdown.Option(str(user.id), f'{user.full_name} ({user.username})') for user in users]
+        if users and self.user_dropdown.value is None:
+            self.user_dropdown.value = str(users[0].id)
+
+    def _edit_assignment_id(self) -> int | None:
+        value = self.page.session.get('edit_assignment_id')
+        return int(value) if value not in {None, ''} else None
+
+    def _parse_due_at(self):
+        raw = (self.due_at.value or '').strip()
+        if not raw:
+            return None
+        return datetime.strptime(raw, '%Y-%m-%d %H:%M')
+
+    def _reset_form(self) -> None:
+        self.page.session.set('edit_assignment_id', None)
+        self.title.value = 'Плановое тестирование'
+        self.questions_count.value = '20'
+        self.max_attempts.value = '3'
+        self.due_at.value = ''
+        self.status_dropdown.value = 'assigned'
+        if self.user_dropdown.options:
+            self.user_dropdown.value = self.user_dropdown.options[0].key
+
+    def _load_edit_state(self) -> None:
+        assignment_id = self._edit_assignment_id()
+        if assignment_id is None:
+            return
+        assignment = self.schedule_service.get_assignment(assignment_id)
+        if assignment is None:
+            self.page.session.set('edit_assignment_id', None)
+            return
+        self.user_dropdown.value = str(assignment.user_id)
+        self.title.value = assignment.title
+        self.questions_count.value = str(assignment.questions_count)
+        self.max_attempts.value = str(assignment.max_attempts)
+        self.due_at.value = assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else ''
+        self.status_dropdown.value = assignment.status
+
+    def _start_edit(self, assignment_id: int) -> None:
+        self.page.session.set('edit_assignment_id', assignment_id)
+        self.page.go('/admin/schedule')
+
+    def _cancel_edit(self, _: ft.ControlEvent) -> None:
+        self._reset_form()
+        self.page.go('/admin/schedule')
+
+    def _save_assignment(self, _: ft.ControlEvent) -> None:
+        if not self.user_dropdown.value:
+            self.message.value = 'Выберите сотрудника'
+            self.message.color = ft.Colors.RED
+            self.page.update()
+            return
+
+        try:
+            due_at = self._parse_due_at()
+        except ValueError:
+            self.message.value = 'Неверный формат даты'
+            self.message.color = ft.Colors.RED
+            self.page.update()
+            return
+
+        payload = {
+            'user_id': int(self.user_dropdown.value),
+            'title': (self.title.value or '').strip() or 'Плановое тестирование',
+            'questions_count': int(self.questions_count.value or '20'),
+            'max_attempts': int(self.max_attempts.value or '3'),
+            'due_at': due_at,
+        }
+        actor = actor_name(self.page)
+        assignment_id = self._edit_assignment_id()
+        if assignment_id is None:
+            assignment = self.schedule_service.create_assignment(**payload)
+            self.audit_service.log('assignment_created', actor, f'Назначено тестирование #{assignment.id}')
+            self.message.value = 'Назначение создано'
+        else:
+            assignment = self.schedule_service.update_assignment(
+                assignment_id=assignment_id,
+                status=self.status_dropdown.value or 'assigned',
+                **payload,
+            )
+            self.audit_service.log('assignment_updated', actor, f'Обновлено назначение #{assignment_id}')
+            self.message.value = 'Назначение обновлено'
+        self.message.color = ft.Colors.GREEN
+        self._reset_form()
+        self.page.go('/admin/schedule')
+
+    def _change_status(self, assignment_id: int, status: str) -> None:
+        updated = self.schedule_service.set_status(assignment_id, status)
+        if updated is not None:
+            self.audit_service.log('assignment_status_changed', actor_name(self.page), f'Назначение #{assignment_id} -> {status}')
+        self.page.go('/admin/schedule')
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Расписание тестирования", "/admin/schedule")
+        if denied is not None:
+            return denied
+
+        self._refresh_users()
+        self._load_edit_state()
+        rows = []
+        for assignment in self.schedule_service.list_assignments():
+            rows.append(
+                ft.DataRow(
+                    cells=[
+                        ft.DataCell(ft.Text(str(assignment.id))),
+                        ft.DataCell(ft.Text(assignment.user.full_name if assignment.user else '')),
+                        ft.DataCell(ft.Text(assignment.title)),
+                        ft.DataCell(ft.Text(str(assignment.questions_count))),
+                        ft.DataCell(ft.Text(str(assignment.max_attempts))),
+                        ft.DataCell(ft.Text(assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else '')),
+                        ft.DataCell(ft.Text(assignment.status)),
+                        ft.DataCell(
+                            ft.Row(
+                                [
+                                    ft.TextButton('Редактировать', on_click=lambda _, aid=assignment.id: self._start_edit(aid)),
+                                    ft.TextButton('Assigned', on_click=lambda _, aid=assignment.id: self._change_status(aid, 'assigned')),
+                                    ft.TextButton('Cancel', on_click=lambda _, aid=assignment.id: self._change_status(aid, 'cancelled')),
+                                ],
+                                wrap=True,
+                            )
+                        ),
+                    ]
+                )
+            )
+
+        edit_mode = self._edit_assignment_id() is not None
+        return ft.View(
+            route='/admin/schedule',
+            controls=build_shell(
+                'Управление расписанием',
+                [
+                    ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/admin')),
+                    ft.Card(
+                        content=ft.Container(
+                            padding=16,
+                            content=ft.Column(
+                                controls=[
+                                    ft.Text('Редактировать назначение' if edit_mode else 'Назначить тест', weight=ft.FontWeight.BOLD),
+                                    ft.ResponsiveRow(
+                                        controls=[
+                                            ft.Container(self.user_dropdown, col={'sm': 12, 'md': 3}),
+                                            ft.Container(self.title, col={'sm': 12, 'md': 3}),
+                                            ft.Container(self.questions_count, col={'sm': 6, 'md': 2}),
+                                            ft.Container(self.max_attempts, col={'sm': 6, 'md': 2}),
+                                            ft.Container(self.status_dropdown, col={'sm': 12, 'md': 2}),
+                                        ]
+                                    ),
+                                    ft.Row(
+                                        [
+                                            self.due_at,
+                                            ft.FilledButton('Сохранить' if edit_mode else 'Назначить', on_click=self._save_assignment),
+                                            ft.OutlinedButton('Сбросить', on_click=self._cancel_edit),
+                                            self.message,
+                                        ],
+                                        wrap=True,
+                                    ),
+                                ]
+                            ),
+                        )
+                    ),
+                    ft.DataTable(
+                        columns=[
+                            ft.DataColumn(ft.Text('ID')),
+                            ft.DataColumn(ft.Text('Сотрудник')),
+                            ft.DataColumn(ft.Text('Тест')),
+                            ft.DataColumn(ft.Text('Вопросов')),
+                            ft.DataColumn(ft.Text('Попыток')),
+                            ft.DataColumn(ft.Text('Срок')),
+                            ft.DataColumn(ft.Text('Статус')),
+                            ft.DataColumn(ft.Text('Действия')),
+                        ],
+                        rows=rows,
+                    ),
+                ],
+                page=self.page,
+            ),
+        )
diff --git a/src/terra_testing/pages/settings_page.py b/src/terra_testing/pages/settings_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..ef16f5529fe9f4749c36510b9a3a5d8304e87517
--- /dev/null
+++ b/src/terra_testing/pages/settings_page.py
@@ -0,0 +1,116 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import actor_name, get_state
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.backup_service import BackupService
+from terra_testing.services.user_service import UserService
+
+
+class SettingsPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.user_service = UserService()
+        self.backup_service = BackupService()
+        self.audit_service = AuditService()
+        self.current_password = ft.TextField(label="Текущий пароль", password=True, can_reveal_password=True, width=280)
+        self.new_password = ft.TextField(label="Новый пароль", password=True, can_reveal_password=True, width=280)
+        self.message = ft.Text()
+        self.backup_dropdown = ft.Dropdown(label="Резервная копия", width=420)
+
+    def _refresh_backups(self) -> None:
+        backups = self.backup_service.list_backups()
+        self.backup_dropdown.options = [ft.dropdown.Option(str(path), path.name) for path in backups]
+        if backups and not self.backup_dropdown.value:
+            self.backup_dropdown.value = str(backups[0])
+
+    def _change_password(self, _: ft.ControlEvent) -> None:
+        state = get_state(self.page)
+        if not state.user_id:
+            self.message.value = "Пользователь не авторизован"
+            self.message.color = ft.Colors.RED
+            self.page.update()
+            return
+
+        success, message = self.user_service.change_password(
+            state.user_id,
+            (self.current_password.value or "").strip(),
+            (self.new_password.value or "").strip(),
+        )
+        self.message.value = message
+        self.message.color = ft.Colors.GREEN if success else ft.Colors.RED
+
+        if success:
+            self.audit_service.log("password_changed", actor_name(self.page), "Пароль изменён через настройки")
+            self.current_password.value = ""
+            self.new_password.value = ""
+
+        self.page.update()
+
+    def _create_backup(self, _: ft.ControlEvent) -> None:
+        path = self.backup_service.create_backup()
+        self.audit_service.log("backup_created", actor_name(self.page), f"Создан backup {path.name}")
+        self._refresh_backups()
+        self.message.value = f"Резервная копия создана: {path.name}"
+        self.message.color = ft.Colors.GREEN
+        self.page.update()
+
+    def _restore_backup(self, _: ft.ControlEvent) -> None:
+        if not self.backup_dropdown.value:
+            self.message.value = "Выберите резервную копию"
+            self.message.color = ft.Colors.RED
+            self.page.update()
+            return
+        restored = self.backup_service.restore_backup(self.backup_dropdown.value)
+        self.audit_service.log("backup_restored", actor_name(self.page), f"Восстановлена база {restored.name}")
+        self.message.value = f"База восстановлена из: {self.backup_dropdown.value}"
+        self.message.color = ft.Colors.GREEN
+        self.page.update()
+
+    def build(self) -> ft.View:
+        state = get_state(self.page)
+        is_admin = bool(state.role == "admin")
+        self._refresh_backups()
+
+        controls: list[ft.Control] = [
+            ft.Card(
+                content=ft.Container(
+                    padding=16,
+                    content=ft.Column(
+                        controls=[
+                            ft.Text("Смена пароля", weight=ft.FontWeight.BOLD),
+                            self.current_password,
+                            self.new_password,
+                            ft.FilledButton("Сменить пароль", on_click=self._change_password),
+                        ]
+                    ),
+                )
+            ),
+            self.message,
+        ]
+
+        if is_admin:
+            controls.append(
+                ft.Card(
+                    content=ft.Container(
+                        padding=16,
+                        content=ft.Column(
+                            controls=[
+                                ft.Text("Резервные копии", weight=ft.FontWeight.BOLD),
+                                ft.Row(
+                                    controls=[
+                                        ft.FilledButton("Создать backup", on_click=self._create_backup),
+                                        self.backup_dropdown,
+                                        ft.OutlinedButton("Восстановить", on_click=self._restore_backup),
+                                    ],
+                                    wrap=True,
+                                ),
+                            ]
+                        ),
+                    )
+                )
+            )
+
+        return ft.View(route="/settings", controls=build_shell("Настройки", controls, page=self.page))
diff --git a/src/terra_testing/pages/sync_monitor_page.py b/src/terra_testing/pages/sync_monitor_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..aa1cdcdf18d53f3e1f37365a3005691884105cb9
--- /dev/null
+++ b/src/terra_testing/pages/sync_monitor_page.py
@@ -0,0 +1,114 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import actor_name, require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.repositories.sync_queue_repository import SyncQueueRepository
+from terra_testing.repositories.user_repository import UserRepository
+from terra_testing.sync.sync_service import SyncService
+
+
+class SyncMonitorPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.result_repository = ResultRepository()
+        self.user_repository = UserRepository()
+        self.sync_queue_repository = SyncQueueRepository()
+        self.sync_service = SyncService()
+        self.message = ft.Text()
+        self.state_filter = ft.Dropdown(
+            label="Показать",
+            width=180,
+            options=[
+                ft.dropdown.Option("all", "Все"),
+                ft.dropdown.Option("pending", "Pending"),
+                ft.dropdown.Option("processing", "Processing"),
+                ft.dropdown.Option("failed", "Failed"),
+                ft.dropdown.Option("synced", "Synced"),
+            ],
+            value=page.session.get("sync_monitor_state_filter") or "all",
+            on_change=self._apply_filter,
+        )
+
+    def _apply_filter(self, _: ft.ControlEvent) -> None:
+        self.page.session.set("sync_monitor_state_filter", self.state_filter.value)
+        self.page.go("/admin/sync")
+
+    def _retry(self, _: ft.ControlEvent) -> None:
+        summary = self.sync_service.retry_pending_sync(actor=actor_name(self.page))
+        self.message.value = f"Повторная синхронизация: synced={summary['synced']}, failed={summary['failed']}"
+        self.message.color = ft.Colors.GREEN if summary["failed"] == 0 else ft.Colors.ORANGE
+        self.page.go("/admin/sync")
+
+    def _retry_one(self, result_id: int) -> None:
+        summary = self.sync_service.retry_result(result_id, actor=actor_name(self.page))
+        self.message.value = f"Result #{result_id}: synced={summary['synced']}, failed={summary['failed']}"
+        self.message.color = ft.Colors.GREEN if summary["failed"] == 0 else ft.Colors.ORANGE
+        self.page.go("/admin/sync")
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Мониторинг синхронизации", "/admin/sync")
+        if denied is not None:
+            return denied
+
+        users = {user.id: user for user in self.user_repository.list_users()}
+        items = self.sync_queue_repository.list_items(status=self.state_filter.value or "all")
+
+        rows = []
+        for item in items:
+            result = self.result_repository.get_result(item.entity_id) if item.entity_type == "test_result" else None
+            user = users.get(result.user_id) if result is not None else None
+            rows.append(
+                ft.DataRow(
+                    cells=[
+                        ft.DataCell(ft.Text(str(item.id))),
+                        ft.DataCell(ft.Text(item.entity_type)),
+                        ft.DataCell(ft.Text(str(item.entity_id))),
+                        ft.DataCell(ft.Text(user.full_name if user else "-")),
+                        ft.DataCell(ft.Text(item.status)),
+                        ft.DataCell(ft.Text(str(item.retry_count))),
+                        ft.DataCell(ft.Text((item.last_error or "")[:80])),
+                        ft.DataCell(ft.TextButton("Повторить", on_click=lambda _, rid=item.entity_id: self._retry_one(rid))),
+                    ]
+                )
+            )
+
+        return ft.View(
+            route="/admin/sync",
+            controls=build_shell(
+                "Мониторинг синхронизации",
+                [
+                    ft.Row(
+                        [
+                            ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
+                            self.state_filter,
+                            ft.FilledButton("Повторить все", on_click=self._retry),
+                        ],
+                        wrap=True,
+                    ),
+                    self.message,
+                    ft.Text(
+                        f"Pending: {self.sync_queue_repository.count_by_status('pending')} | "
+                        f"Failed: {self.sync_queue_repository.count_by_status('failed')} | "
+                        f"Processing: {self.sync_queue_repository.count_by_status('processing')} | "
+                        f"Synced: {self.sync_queue_repository.count_by_status('synced')}"
+                    ),
+                    ft.DataTable(
+                        columns=[
+                            ft.DataColumn(ft.Text("Queue ID")),
+                            ft.DataColumn(ft.Text("Entity")),
+                            ft.DataColumn(ft.Text("Entity ID")),
+                            ft.DataColumn(ft.Text("Сотрудник")),
+                            ft.DataColumn(ft.Text("Статус")),
+                            ft.DataColumn(ft.Text("Retry")),
+                            ft.DataColumn(ft.Text("Ошибка")),
+                            ft.DataColumn(ft.Text("Действие")),
+                        ],
+                        rows=rows,
+                    ),
+                ],
+                page=self.page,
+            ),
+        )
diff --git a/src/terra_testing/pages/user_dashboard_page.py b/src/terra_testing/pages/user_dashboard_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..d0110505fb6e853e666761ae980ef1635340c54d
--- /dev/null
+++ b/src/terra_testing/pages/user_dashboard_page.py
@@ -0,0 +1,72 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import require_user
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.schedule_service import ScheduleService
+
+
+class UserDashboardPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.schedule_service = ScheduleService()
+
+    def _start_assignment(self, assignment_id: int) -> None:
+        self.page.session.set('active_assignment_id', assignment_id)
+        self.page.go('/quiz')
+
+    def build(self) -> ft.View:
+        denied = require_user(self.page, "Кабинет сотрудника", "/user")
+        if denied is not None:
+            return denied
+
+        state = self.page.session.get('state')
+        user_id = state.user_id if state and state.user_id is not None else 1
+        assignment_infos = self.schedule_service.list_assignments_for_user(user_id)
+
+        controls: list[ft.Control] = [
+            ft.Row(
+                controls=[
+                    ft.OutlinedButton('Результаты', on_click=lambda _: self.page.go('/results')),
+                    ft.OutlinedButton('Настройки', on_click=lambda _: self.page.go('/settings')),
+                ]
+            )
+        ]
+
+        if not assignment_infos:
+            controls.append(ft.Text('Пока нет назначенных тестов. Можно запустить свободный тест из общего банка.'))
+            controls.append(ft.FilledButton('Начать тест', on_click=lambda _: self.page.go('/quiz')))
+        else:
+            for info in assignment_infos:
+                assignment = info['assignment']
+                reason = 'Готово к запуску'
+                if assignment.status == 'completed':
+                    reason = 'Назначение уже завершено'
+                elif info['is_overdue']:
+                    reason = 'Срок выполнения истёк'
+                elif info['attempts_left'] <= 0:
+                    reason = 'Попытки исчерпаны'
+                controls.append(
+                    ft.Card(
+                        content=ft.Container(
+                            padding=16,
+                            content=ft.Column(
+                                controls=[
+                                    ft.Text(assignment.title, weight=ft.FontWeight.BOLD),
+                                    ft.Text(f'Вопросов: {assignment.questions_count}'),
+                                    ft.Text(f'Попыток использовано: {info["attempts_used"]} из {assignment.max_attempts}'),
+                                    ft.Text(f'Статус: {assignment.status}'),
+                                    ft.Text(f'Комментарий: {reason}'),
+                                    ft.FilledButton(
+                                        'Начать',
+                                        disabled=not info['can_start'],
+                                        on_click=lambda _, assignment_id=assignment.id: self._start_assignment(assignment_id),
+                                    ),
+                                ]
+                            ),
+                        )
+                    )
+                )
+
+        return ft.View(route='/user', controls=build_shell('Кабинет сотрудника', controls, page=self.page))
diff --git a/src/terra_testing/pages/users_management_page.py b/src/terra_testing/pages/users_management_page.py
new file mode 100644
index 0000000000000000000000000000000000000000..63fa5fd2bf45d7799f2aede8016e9c64e06d43fa
--- /dev/null
+++ b/src/terra_testing/pages/users_management_page.py
@@ -0,0 +1,205 @@
+from __future__ import annotations
+
+import flet as ft
+
+from terra_testing.app.access import actor_name, require_admin
+from terra_testing.components.app_shell import build_shell
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.user_service import UserService
+
+
+class UsersManagementPage:
+    def __init__(self, page: ft.Page) -> None:
+        self.page = page
+        self.user_service = UserService()
+        self.audit_service = AuditService()
+        self.full_name = ft.TextField(label="ФИО", width=320)
+        self.username = ft.TextField(label="Логин", width=220)
+        self.password = ft.TextField(label="Пароль", password=True, can_reveal_password=True, width=220)
+        self.role_dropdown = ft.Dropdown(label="Роль", width=180)
+        self.message = ft.Text()
+
+    def _is_admin(self) -> bool:
+        return require_admin(self.page, "Управление пользователями", "/admin/users") is None
+
+    def _edit_user_id(self) -> int | None:
+        value = self.page.session.get("edit_user_id")
+        return int(value) if value not in {None, ""} else None
+
+    def _set_message(self, text: str, ok: bool) -> None:
+        self.message.value = text
+        self.message.color = ft.Colors.GREEN if ok else ft.Colors.RED
+        self.page.update()
+
+    def _refresh_roles(self) -> None:
+        roles = self.user_service.list_roles()
+        self.role_dropdown.options = [ft.dropdown.Option(str(role.id), role.name) for role in roles]
+        if roles and self.role_dropdown.value is None:
+            self.role_dropdown.value = str(roles[0].id)
+
+    def _load_edit_state(self) -> None:
+        edit_user_id = self._edit_user_id()
+        if not edit_user_id:
+            return
+        user = self.user_service.get_user(edit_user_id)
+        if user is None:
+            self.page.session.set("edit_user_id", None)
+            return
+        self.full_name.value = user.full_name
+        self.username.value = user.username
+        self.username.disabled = True
+        self.password.disabled = True
+        self.password.value = ""
+        self.role_dropdown.value = str(user.role_id)
+
+    def _reset_form(self) -> None:
+        self.page.session.set("edit_user_id", None)
+        self.full_name.value = ""
+        self.username.value = ""
+        self.username.disabled = False
+        self.password.value = ""
+        self.password.disabled = False
+        self.role_dropdown.value = self.role_dropdown.options[0].key if self.role_dropdown.options else None
+
+    def _save_user(self, _: ft.ControlEvent) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для изменения пользователей", False)
+            return
+        if not self.full_name.value or not self.username.value or not self.role_dropdown.value:
+            self._set_message("Заполните обязательные поля пользователя", False)
+            return
+
+        edit_user_id = self._edit_user_id()
+        actor = actor_name(self.page)
+
+        if edit_user_id is None:
+            if not self.password.value:
+                self._set_message("Введите пароль для нового пользователя", False)
+                return
+            user = self.user_service.create_user(
+                username=self.username.value.strip(),
+                full_name=self.full_name.value.strip(),
+                password=self.password.value,
+                role_id=int(self.role_dropdown.value),
+            )
+            self.audit_service.log("user_created", actor, f"Создан пользователь {user.username}")
+            self._reset_form()
+            self.page.go("/admin/users")
+            return
+
+        user = self.user_service.update_user(
+            user_id=edit_user_id,
+            full_name=self.full_name.value.strip(),
+            role_id=int(self.role_dropdown.value),
+        )
+        if user is None:
+            self._set_message("Пользователь не найден", False)
+            return
+        self.audit_service.log("user_updated", actor, f"Обновлён пользователь {user.username}")
+        self._reset_form()
+        self.page.go("/admin/users")
+
+    def _start_edit(self, user_id: int) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для редактирования", False)
+            return
+        self.page.session.set("edit_user_id", user_id)
+        self.page.go("/admin/users")
+
+    def _cancel_edit(self, _: ft.ControlEvent) -> None:
+        self._reset_form()
+        self.page.go("/admin/users")
+
+    def _toggle_active(self, user_id: int, is_active: bool) -> None:
+        if not self._is_admin():
+            self._set_message("Недостаточно прав для изменения статуса", False)
+            return
+        user = self.user_service.set_active(user_id, not is_active)
+        if user is not None:
+            action = "активирован" if user.is_active else "деактивирован"
+            self.audit_service.log("user_status_changed", actor_name(self.page), f"Пользователь {user.username} {action}")
+        self.page.go("/admin/users")
+
+    def build(self) -> ft.View:
+        denied = require_admin(self.page, "Управление пользователями", "/admin/users")
+        if denied is not None:
+            return denied
+
+        self._refresh_roles()
+        self._load_edit_state()
+
+        rows = []
+        for user in self.user_service.list_users():
+            action_label = "Отключить" if user.is_active else "Включить"
+            rows.append(
+                ft.DataRow(
+                    cells=[
+                        ft.DataCell(ft.Text(str(user.id))),
+                        ft.DataCell(ft.Text(user.full_name)),
+                        ft.DataCell(ft.Text(user.username)),
+                        ft.DataCell(ft.Text(user.role.name if user.role else "")),
+                        ft.DataCell(ft.Text("Да" if user.is_active else "Нет")),
+                        ft.DataCell(
+                            ft.Row(
+                                controls=[
+                                    ft.TextButton("Редактировать", on_click=lambda _, uid=user.id: self._start_edit(uid)),
+                                    ft.TextButton(action_label, on_click=lambda _, uid=user.id, active=user.is_active: self._toggle_active(uid, active)),
+                                ],
+                                wrap=True,
+                            )
+                        ),
+                    ]
+                )
+            )
+
+        edit_mode = self._edit_user_id() is not None
+        save_label = "Сохранить изменения" if edit_mode else "Создать"
+        title = "Редактировать пользователя" if edit_mode else "Создать пользователя"
+
+        return ft.View(
+            route="/admin/users",
+            controls=build_shell(
+                "Управление пользователями",
+                [
+                    ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
+                    ft.Card(
+                        content=ft.Container(
+                            padding=16,
+                            content=ft.Column(
+                                controls=[
+                                    ft.Text(title, weight=ft.FontWeight.BOLD),
+                                    ft.ResponsiveRow(
+                                        controls=[
+                                            ft.Container(self.full_name, col={"sm": 12, "md": 4}),
+                                            ft.Container(self.username, col={"sm": 12, "md": 3}),
+                                            ft.Container(self.password, col={"sm": 12, "md": 3}),
+                                            ft.Container(self.role_dropdown, col={"sm": 12, "md": 2}),
+                                        ]
+                                    ),
+                                    ft.Row(
+                                        [
+                                            ft.FilledButton(save_label, on_click=self._save_user),
+                                            ft.OutlinedButton("Сбросить", on_click=self._cancel_edit),
+                                            self.message,
+                                        ],
+                                        wrap=True,
+                                    ),
+                                ]
+                            ),
+                        )
+                    ),
+                    ft.DataTable(
+                        columns=[
+                            ft.DataColumn(ft.Text("ID")),
+                            ft.DataColumn(ft.Text("ФИО")),
+                            ft.DataColumn(ft.Text("Логин")),
+                            ft.DataColumn(ft.Text("Роль")),
+                            ft.DataColumn(ft.Text("Активен")),
+                            ft.DataColumn(ft.Text("Действия")),
+                        ],
+                        rows=rows,
+                    ),
+                ],
+                page=self.page,
+            ),
+        )
diff --git a/src/terra_testing/reports/__init__.py b/src/terra_testing/reports/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/reports/excel_report.py b/src/terra_testing/reports/excel_report.py
new file mode 100644
index 0000000000000000000000000000000000000000..1b4b928f8eb7d959f96344ce58c45da2904d8dc6
--- /dev/null
+++ b/src/terra_testing/reports/excel_report.py
@@ -0,0 +1,42 @@
+from __future__ import annotations
+
+from pathlib import Path
+
+from openpyxl import Workbook
+
+
+def build_results_excel(rows: list[dict], output: Path) -> None:
+    output.parent.mkdir(parents=True, exist_ok=True)
+    wb = Workbook()
+    ws = wb.active
+    ws.title = "Results"
+    ws.append(["Full Name", "Score Percent", "Status", "Sync State", "Completed At"])
+    for row in rows:
+        ws.append(
+            [
+                row.get("full_name", ""),
+                row.get("score_percent", 0),
+                row.get("status", ""),
+                row.get("sync_state", ""),
+                row.get("completed_at", ""),
+            ]
+        )
+    wb.save(output)
+
+
+def build_audit_excel(rows: list[dict], output: Path) -> None:
+    output.parent.mkdir(parents=True, exist_ok=True)
+    wb = Workbook()
+    ws = wb.active
+    ws.title = "Audit"
+    ws.append(["Created At", "Event Type", "Actor", "Message"])
+    for row in rows:
+        ws.append(
+            [
+                row.get("created_at", ""),
+                row.get("event_type", ""),
+                row.get("actor", ""),
+                row.get("message", ""),
+            ]
+        )
+    wb.save(output)
diff --git a/src/terra_testing/reports/pdf_report.py b/src/terra_testing/reports/pdf_report.py
new file mode 100644
index 0000000000000000000000000000000000000000..784562122fc4111f9926bb7d9030acab55b297e8
--- /dev/null
+++ b/src/terra_testing/reports/pdf_report.py
@@ -0,0 +1,46 @@
+from __future__ import annotations
+
+from pathlib import Path
+
+from reportlab.lib.pagesizes import A4
+from reportlab.pdfgen import canvas
+
+
+def _write_rows(c: canvas.Canvas, title: str, rows: list[dict], formatter) -> None:
+    width, height = A4
+    y = height - 50
+    c.setFont("Helvetica-Bold", 14)
+    c.drawString(50, y, title)
+    y -= 30
+    c.setFont("Helvetica", 10)
+    for row in rows:
+        line = formatter(row)
+        c.drawString(50, y, line[:140])
+        y -= 18
+        if y < 60:
+            c.showPage()
+            y = height - 50
+            c.setFont("Helvetica", 10)
+    c.save()
+
+
+def build_results_pdf(rows: list[dict], output: Path) -> None:
+    output.parent.mkdir(parents=True, exist_ok=True)
+    c = canvas.Canvas(str(output), pagesize=A4)
+    _write_rows(
+        c,
+        "Отчёт по результатам тестирования",
+        rows,
+        lambda row: f"{row.get('full_name', '')} | {row.get('score_percent', 0)}% | {row.get('status', '')}",
+    )
+
+
+def build_audit_pdf(rows: list[dict], output: Path) -> None:
+    output.parent.mkdir(parents=True, exist_ok=True)
+    c = canvas.Canvas(str(output), pagesize=A4)
+    _write_rows(
+        c,
+        "Журнал аудита",
+        rows,
+        lambda row: f"{row.get('created_at', '')} | {row.get('event_type', '')} | {row.get('actor', '')} | {row.get('message', '')}",
+    )
diff --git a/src/terra_testing/repositories/__init__.py b/src/terra_testing/repositories/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/repositories/audit_repository.py b/src/terra_testing/repositories/audit_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..a741947dcb00f4f0f930361dba617cd1044c9789
--- /dev/null
+++ b/src/terra_testing/repositories/audit_repository.py
@@ -0,0 +1,58 @@
+from __future__ import annotations
+
+from datetime import datetime, timedelta, timezone
+
+from sqlalchemy import select
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.audit_log import AuditLog
+
+
+class AuditRepository:
+    def create(self, *, event_type: str, actor: str, message: str) -> AuditLog:
+        with get_local_session() as session:
+            entry = AuditLog(event_type=event_type, actor=actor, message=message)
+            session.add(entry)
+            session.commit()
+            session.refresh(entry)
+            return entry
+
+    def list_recent(self, limit: int = 100) -> list[AuditLog]:
+        with get_local_session() as session:
+            stmt = select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit)
+            return list(session.execute(stmt).scalars().all())
+
+    @staticmethod
+    def normalize_date_range(date_from: datetime | None, date_to: datetime | None) -> tuple[datetime | None, datetime | None]:
+        normalized_from = date_from
+        normalized_to = date_to
+        if normalized_from is not None and normalized_from.tzinfo is None:
+            normalized_from = normalized_from.replace(tzinfo=timezone.utc)
+        if normalized_to is not None and normalized_to.tzinfo is None:
+            normalized_to = normalized_to.replace(tzinfo=timezone.utc)
+        return normalized_from, normalized_to
+
+    def list_filtered(
+        self,
+        *,
+        event_type: str | None = None,
+        actor: str | None = None,
+        day_from: datetime | None = None,
+        day_to: datetime | None = None,
+        limit: int = 500,
+    ) -> list[AuditLog]:
+        with get_local_session() as session:
+            stmt = select(AuditLog)
+            if event_type and event_type != "all":
+                stmt = stmt.where(AuditLog.event_type == event_type)
+            if actor:
+                stmt = stmt.where(AuditLog.actor == actor)
+            created_from, created_to = self.normalize_date_range(day_from, day_to)
+            if created_to is not None:
+                created_to = created_to + timedelta(days=1)
+            if created_from is not None:
+                stmt = stmt.where(AuditLog.created_at >= created_from)
+            if created_to is not None:
+                stmt = stmt.where(AuditLog.created_at < created_to)
+            stmt = stmt.order_by(AuditLog.created_at.desc()).limit(limit)
+            return list(session.execute(stmt).scalars().all())
diff --git a/src/terra_testing/repositories/question_repository.py b/src/terra_testing/repositories/question_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..efbbb1d70d5ceee5350880889d405ae3b16a2f91
--- /dev/null
+++ b/src/terra_testing/repositories/question_repository.py
@@ -0,0 +1,120 @@
+from __future__ import annotations
+
+from sqlalchemy import func, select
+from sqlalchemy.orm import joinedload, selectinload
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.answer import Answer
+from terra_testing.models.question import Question, QuestionCategory
+
+
+class QuestionRepository:
+    def list_questions(self) -> list[Question]:
+        with get_local_session() as session:
+            stmt = (
+                select(Question)
+                .options(joinedload(Question.category), selectinload(Question.answers))
+                .order_by(Question.id.asc())
+            )
+            return list(session.execute(stmt).scalars().unique().all())
+
+    def count_questions(self) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(Question.id)).where(Question.is_active.is_(True))
+            return int(session.execute(stmt).scalar_one())
+
+    def list_categories(self) -> list[QuestionCategory]:
+        with get_local_session() as session:
+            stmt = select(QuestionCategory).order_by(QuestionCategory.name.asc())
+            return list(session.execute(stmt).scalars().all())
+
+    def get_question(self, question_id: int) -> Question | None:
+        with get_local_session() as session:
+            stmt = (
+                select(Question)
+                .options(joinedload(Question.category), selectinload(Question.answers))
+                .where(Question.id == question_id)
+            )
+            return session.execute(stmt).scalars().unique().one_or_none()
+
+    def random_questions(self, limit: int) -> list[Question]:
+        with get_local_session() as session:
+            stmt = (
+                select(Question)
+                .options(joinedload(Question.category), selectinload(Question.answers))
+                .where(Question.is_active.is_(True))
+                .order_by(func.random())
+                .limit(limit)
+            )
+            return list(session.execute(stmt).scalars().unique().all())
+
+    def get_questions_by_ids(self, question_ids: list[int]) -> list[Question]:
+        if not question_ids:
+            return []
+        with get_local_session() as session:
+            stmt = (
+                select(Question)
+                .options(joinedload(Question.category), selectinload(Question.answers))
+                .where(Question.id.in_(question_ids))
+            )
+            questions = list(session.execute(stmt).scalars().unique().all())
+            by_id = {question.id: question for question in questions}
+            return [by_id[qid] for qid in question_ids if qid in by_id]
+
+    def get_answer_map(self, question_ids: list[int]) -> dict[int, list[Answer]]:
+        questions = self.get_questions_by_ids(question_ids)
+        return {question.id: list(question.answers) for question in questions}
+
+    def create_category(self, name: str) -> QuestionCategory:
+        with get_local_session() as session:
+            category = QuestionCategory(name=name)
+            session.add(category)
+            session.commit()
+            session.refresh(category)
+            return category
+
+    def create_question(self, *, category_id: int, text: str, answers: list[dict]) -> Question:
+        with get_local_session() as session:
+            question = Question(category_id=category_id, text=text)
+            session.add(question)
+            session.flush()
+            question_id = question.id
+            for answer in answers:
+                session.add(
+                    Answer(
+                        question_id=question.id,
+                        text=answer["text"],
+                        is_correct=answer.get("is_correct", False),
+                    )
+                )
+            session.commit()
+        return self.get_question(question_id)
+
+    def update_question(self, *, question_id: int, category_id: int, text: str, answers: list[dict]) -> Question | None:
+        with get_local_session() as session:
+            question = session.get(Question, question_id)
+            if question is None:
+                return None
+            question.category_id = category_id
+            question.text = text
+            session.query(Answer).filter(Answer.question_id == question_id).delete()
+            session.flush()
+            for answer in answers:
+                session.add(
+                    Answer(
+                        question_id=question_id,
+                        text=answer["text"],
+                        is_correct=answer.get("is_correct", False),
+                    )
+                )
+            session.commit()
+        return self.get_question(question_id)
+
+    def set_question_active(self, question_id: int, is_active: bool) -> Question | None:
+        with get_local_session() as session:
+            question = session.get(Question, question_id)
+            if question is None:
+                return None
+            question.is_active = is_active
+            session.commit()
+        return self.get_question(question_id)
diff --git a/src/terra_testing/repositories/result_repository.py b/src/terra_testing/repositories/result_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..3c3da803110b175d4268bae51856115bd781826e
--- /dev/null
+++ b/src/terra_testing/repositories/result_repository.py
@@ -0,0 +1,159 @@
+from __future__ import annotations
+
+from datetime import datetime, timedelta, timezone
+
+from sqlalchemy import func, select
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.sync_queue import SyncQueueItem
+from terra_testing.models.test_result import TestAnswer, TestResult
+
+
+class ResultRepository:
+    def create_result(
+        self,
+        *,
+        user_id: int,
+        assignment_id: int | None,
+        correct_answers: int,
+        total_questions: int,
+        score_percent: int,
+        status: str,
+        answers: list[dict],
+    ) -> TestResult:
+        with get_local_session() as session:
+            result = TestResult(
+                user_id=user_id,
+                assignment_id=assignment_id,
+                correct_answers=correct_answers,
+                total_questions=total_questions,
+                score_percent=score_percent,
+                status=status,
+            )
+            session.add(result)
+            session.flush()
+            result_id = result.id
+
+            for item in answers:
+                session.add(
+                    TestAnswer(
+                        result_id=result.id,
+                        question_id=item["question_id"],
+                        selected_answer_id=item.get("selected_answer_id"),
+                        is_correct=item["is_correct"],
+                    )
+                )
+
+            session.add(
+                SyncQueueItem(
+                    entity_type="test_result",
+                    entity_id=result.id,
+                    status="pending",
+                    payload_snapshot=None,
+                )
+            )
+
+            session.commit()
+        return self.get_result(result_id)
+
+    def get_result(self, result_id: int) -> TestResult | None:
+        with get_local_session() as session:
+            return session.get(TestResult, result_id)
+
+    def count_attempts_for_assignment(self, user_id: int, assignment_id: int | None) -> int:
+        if assignment_id is None:
+            return 0
+        with get_local_session() as session:
+            stmt = select(func.count(TestResult.id)).where(
+                TestResult.user_id == user_id,
+                TestResult.assignment_id == assignment_id,
+            )
+            return int(session.execute(stmt).scalar_one())
+
+    def count_pending_sync(self) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(TestResult.id)).where(TestResult.sync_state == "pending")
+            return int(session.execute(stmt).scalar_one())
+
+    def count_failed_sync(self) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(TestResult.id)).where(TestResult.sync_state == "failed")
+            return int(session.execute(stmt).scalar_one())
+
+    def count_synced(self) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(TestResult.id)).where(TestResult.sync_state == "synced")
+            return int(session.execute(stmt).scalar_one())
+
+    def list_results_for_user(self, user_id: int) -> list[TestResult]:
+        with get_local_session() as session:
+            stmt = select(TestResult).where(TestResult.user_id == user_id).order_by(TestResult.completed_at.desc())
+            return list(session.execute(stmt).scalars().all())
+
+    def list_all_results(self) -> list[TestResult]:
+        with get_local_session() as session:
+            stmt = select(TestResult).order_by(TestResult.completed_at.desc())
+            return list(session.execute(stmt).scalars().all())
+
+    def list_pending_sync(self) -> list[TestResult]:
+        with get_local_session() as session:
+            stmt = (
+                select(TestResult)
+                .where(TestResult.sync_state.in_(["pending", "failed"]))
+                .order_by(TestResult.completed_at.desc())
+            )
+            return list(session.execute(stmt).scalars().all())
+
+    def list_filtered_results(
+        self,
+        *,
+        user_id: int | None = None,
+        status: str | None = None,
+        sync_state: str | None = None,
+        completed_from: datetime | None = None,
+        completed_to: datetime | None = None,
+    ) -> list[TestResult]:
+        with get_local_session() as session:
+            stmt = select(TestResult)
+            if user_id is not None:
+                stmt = stmt.where(TestResult.user_id == user_id)
+            if status and status != "all":
+                stmt = stmt.where(TestResult.status == status)
+            if sync_state and sync_state != "all":
+                stmt = stmt.where(TestResult.sync_state == sync_state)
+            if completed_from is not None:
+                stmt = stmt.where(TestResult.completed_at >= completed_from)
+            if completed_to is not None:
+                stmt = stmt.where(TestResult.completed_at < completed_to)
+            stmt = stmt.order_by(TestResult.completed_at.desc())
+            return list(session.execute(stmt).scalars().all())
+
+    @staticmethod
+    def normalize_date_range(date_from: datetime | None, date_to: datetime | None) -> tuple[datetime | None, datetime | None]:
+        normalized_from = date_from
+        normalized_to = date_to
+        if normalized_from is not None and normalized_from.tzinfo is None:
+            normalized_from = normalized_from.replace(tzinfo=timezone.utc)
+        if normalized_to is not None and normalized_to.tzinfo is None:
+            normalized_to = normalized_to.replace(tzinfo=timezone.utc)
+        return normalized_from, normalized_to
+
+    def list_filtered_results_by_day(
+        self,
+        *,
+        user_id: int | None = None,
+        status: str | None = None,
+        sync_state: str | None = None,
+        day_from: datetime | None = None,
+        day_to: datetime | None = None,
+    ) -> list[TestResult]:
+        completed_from, completed_to = self.normalize_date_range(day_from, day_to)
+        if completed_to is not None:
+            completed_to = completed_to + timedelta(days=1)
+        return self.list_filtered_results(
+            user_id=user_id,
+            status=status,
+            sync_state=sync_state,
+            completed_from=completed_from,
+            completed_to=completed_to,
+        )
diff --git a/src/terra_testing/repositories/schedule_repository.py b/src/terra_testing/repositories/schedule_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..2e1f619148d7bed30aab3ffe640eb7d4182844c9
--- /dev/null
+++ b/src/terra_testing/repositories/schedule_repository.py
@@ -0,0 +1,94 @@
+from __future__ import annotations
+
+from sqlalchemy import func, select
+from sqlalchemy.orm import joinedload
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.schedule import TestAssignment
+
+
+class ScheduleRepository:
+    def list_assignments(self) -> list[TestAssignment]:
+        with get_local_session() as session:
+            stmt = select(TestAssignment).options(joinedload(TestAssignment.user)).order_by(TestAssignment.id.desc())
+            return list(session.execute(stmt).scalars().unique().all())
+
+    def count_active_assignments(self) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(TestAssignment.id)).where(TestAssignment.status == 'assigned')
+            return int(session.execute(stmt).scalar_one())
+
+    def list_assignments_for_user(self, user_id: int) -> list[TestAssignment]:
+        with get_local_session() as session:
+            stmt = (
+                select(TestAssignment)
+                .options(joinedload(TestAssignment.user))
+                .where(TestAssignment.user_id == user_id)
+                .order_by(TestAssignment.id.desc())
+            )
+            return list(session.execute(stmt).scalars().unique().all())
+
+    def get_assignment(self, assignment_id: int) -> TestAssignment | None:
+        with get_local_session() as session:
+            stmt = select(TestAssignment).options(joinedload(TestAssignment.user)).where(TestAssignment.id == assignment_id)
+            return session.execute(stmt).scalar_one_or_none()
+
+    def create_assignment(
+        self,
+        *,
+        user_id: int,
+        title: str,
+        questions_count: int,
+        max_attempts: int,
+        due_at=None,
+    ) -> TestAssignment:
+        with get_local_session() as session:
+            assignment = TestAssignment(
+                user_id=user_id,
+                title=title,
+                questions_count=questions_count,
+                max_attempts=max_attempts,
+                due_at=due_at,
+            )
+            session.add(assignment)
+            session.commit()
+            session.refresh(assignment)
+            return self.get_assignment(assignment.id)
+
+    def update_assignment(
+        self,
+        *,
+        assignment_id: int,
+        user_id: int,
+        title: str,
+        questions_count: int,
+        max_attempts: int,
+        due_at=None,
+        status: str = 'assigned',
+    ) -> TestAssignment | None:
+        with get_local_session() as session:
+            assignment = session.get(TestAssignment, assignment_id)
+            if assignment is None:
+                return None
+            assignment.user_id = user_id
+            assignment.title = title
+            assignment.questions_count = questions_count
+            assignment.max_attempts = max_attempts
+            assignment.due_at = due_at
+            assignment.status = status
+            session.commit()
+            session.refresh(assignment)
+            return self.get_assignment(assignment.id)
+
+    def set_status(self, assignment_id: int, status: str) -> TestAssignment | None:
+        with get_local_session() as session:
+            assignment = session.get(TestAssignment, assignment_id)
+            if assignment is None:
+                return None
+            assignment.status = status
+            session.commit()
+            session.refresh(assignment)
+            return self.get_assignment(assignment.id)
+
+    def mark_completed(self, assignment_id: int) -> TestAssignment | None:
+        return self.set_status(assignment_id, 'completed')
diff --git a/src/terra_testing/repositories/sync_queue_repository.py b/src/terra_testing/repositories/sync_queue_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..7b826ae37f893f88f66d2150a258416f7de31b61
--- /dev/null
+++ b/src/terra_testing/repositories/sync_queue_repository.py
@@ -0,0 +1,93 @@
+from __future__ import annotations
+
+import json
+
+from sqlalchemy import func, select
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.sync_queue import SyncQueueItem
+from terra_testing.utils.time import utcnow
+
+
+class SyncQueueRepository:
+    def enqueue_result(self, result_id: int, payload: dict | None = None) -> SyncQueueItem:
+        with get_local_session() as session:
+            existing = session.execute(
+                select(SyncQueueItem).where(
+                    SyncQueueItem.entity_type == "test_result",
+                    SyncQueueItem.entity_id == result_id,
+                )
+            ).scalar_one_or_none()
+            if existing is not None:
+                return existing
+
+            item = SyncQueueItem(
+                entity_type="test_result",
+                entity_id=result_id,
+                status="pending",
+                payload_snapshot=json.dumps(payload or {}, ensure_ascii=False),
+            )
+            session.add(item)
+            session.commit()
+            session.refresh(item)
+            return item
+
+    def get_by_result_id(self, result_id: int) -> SyncQueueItem | None:
+        with get_local_session() as session:
+            stmt = select(SyncQueueItem).where(
+                SyncQueueItem.entity_type == "test_result",
+                SyncQueueItem.entity_id == result_id,
+            )
+            return session.execute(stmt).scalar_one_or_none()
+
+    def list_items(self, *, status: str | None = None) -> list[SyncQueueItem]:
+        with get_local_session() as session:
+            stmt = select(SyncQueueItem)
+            if status and status != "all":
+                stmt = stmt.where(SyncQueueItem.status == status)
+            stmt = stmt.order_by(SyncQueueItem.created_at.desc(), SyncQueueItem.id.desc())
+            return list(session.execute(stmt).scalars().all())
+
+    def list_pending_like(self) -> list[SyncQueueItem]:
+        with get_local_session() as session:
+            stmt = (
+                select(SyncQueueItem)
+                .where(SyncQueueItem.status.in_(["pending", "failed"]))
+                .order_by(SyncQueueItem.created_at.desc(), SyncQueueItem.id.desc())
+            )
+            return list(session.execute(stmt).scalars().all())
+
+    def mark_processing(self, item_id: int) -> None:
+        with get_local_session() as session:
+            item = session.get(SyncQueueItem, item_id)
+            if item is None:
+                return
+            item.status = "processing"
+            item.last_attempt_at = utcnow()
+            session.commit()
+
+    def mark_synced(self, item_id: int) -> None:
+        with get_local_session() as session:
+            item = session.get(SyncQueueItem, item_id)
+            if item is None:
+                return
+            item.status = "synced"
+            item.last_error = None
+            item.last_attempt_at = utcnow()
+            session.commit()
+
+    def mark_failed(self, item_id: int, error: str) -> None:
+        with get_local_session() as session:
+            item = session.get(SyncQueueItem, item_id)
+            if item is None:
+                return
+            item.status = "failed"
+            item.last_error = error[:1000]
+            item.last_attempt_at = utcnow()
+            item.retry_count += 1
+            session.commit()
+
+    def count_by_status(self, status: str) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(SyncQueueItem.id)).where(SyncQueueItem.status == status)
+            return int(session.execute(stmt).scalar_one())
diff --git a/src/terra_testing/repositories/sync_repository.py b/src/terra_testing/repositories/sync_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..9080015aecc2059939cd7a0752977b0a7da93dd3
--- /dev/null
+++ b/src/terra_testing/repositories/sync_repository.py
@@ -0,0 +1,27 @@
+from __future__ import annotations
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.test_result import TestResult
+from terra_testing.utils.time import utcnow
+
+
+class SyncRepository:
+    def mark_synced(self, result_id: int) -> None:
+        with get_local_session() as session:
+            result = session.get(TestResult, result_id)
+            if result is None:
+                return
+            result.sync_state = "synced"
+            result.sync_error = None
+            result.last_synced_at = utcnow()
+            session.commit()
+
+    def mark_failed(self, result_id: int, error: str) -> None:
+        with get_local_session() as session:
+            result = session.get(TestResult, result_id)
+            if result is None:
+                return
+            result.sync_state = "failed"
+            result.sync_error = error[:1000]
+            result.retry_count += 1
+            session.commit()
diff --git a/src/terra_testing/repositories/user_repository.py b/src/terra_testing/repositories/user_repository.py
new file mode 100644
index 0000000000000000000000000000000000000000..dc5d5d14f6d8e50f456f82019561235021bc98a7
--- /dev/null
+++ b/src/terra_testing/repositories/user_repository.py
@@ -0,0 +1,80 @@
+from __future__ import annotations
+
+from sqlalchemy import func, select
+from sqlalchemy.orm import joinedload
+
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.models.user import User
+
+
+class UserRepository:
+    def get_by_username(self, username: str) -> User | None:
+        with get_local_session() as session:
+            stmt = select(User).options(joinedload(User.role)).where(User.username == username)
+            return session.execute(stmt).scalar_one_or_none()
+
+    def get_by_id(self, user_id: int) -> User | None:
+        with get_local_session() as session:
+            stmt = select(User).options(joinedload(User.role)).where(User.id == user_id)
+            return session.execute(stmt).scalar_one_or_none()
+
+    def list_users(self) -> list[User]:
+        with get_local_session() as session:
+            stmt = select(User).options(joinedload(User.role)).order_by(User.full_name.asc())
+            return list(session.execute(stmt).scalars().all())
+
+    def count_users(self) -> int:
+        with get_local_session() as session:
+            stmt = select(func.count(User.id))
+            return int(session.execute(stmt).scalar_one())
+
+    def list_roles(self) -> list[Role]:
+        with get_local_session() as session:
+            stmt = select(Role).order_by(Role.name.asc())
+            return list(session.execute(stmt).scalars().all())
+
+    def create_user(self, *, username: str, full_name: str, password_hash: str, role_id: int) -> User:
+        with get_local_session() as session:
+            user = User(
+                username=username,
+                full_name=full_name,
+                password_hash=password_hash,
+                role_id=role_id,
+                is_active=True,
+            )
+            session.add(user)
+            session.commit()
+            session.refresh(user)
+            return self.get_by_id(user.id)
+
+    def update_user(self, *, user_id: int, full_name: str, role_id: int) -> User | None:
+        with get_local_session() as session:
+            user = session.get(User, user_id)
+            if user is None:
+                return None
+            user.full_name = full_name
+            user.role_id = role_id
+            session.commit()
+            session.refresh(user)
+            return self.get_by_id(user.id)
+
+    def update_password(self, *, user_id: int, password_hash: str) -> User | None:
+        with get_local_session() as session:
+            user = session.get(User, user_id)
+            if user is None:
+                return None
+            user.password_hash = password_hash
+            session.commit()
+            session.refresh(user)
+            return self.get_by_id(user.id)
+
+    def set_active(self, user_id: int, is_active: bool) -> User | None:
+        with get_local_session() as session:
+            user = session.get(User, user_id)
+            if user is None:
+                return None
+            user.is_active = is_active
+            session.commit()
+            session.refresh(user)
+            return self.get_by_id(user.id)
diff --git a/src/terra_testing/services/__init__.py b/src/terra_testing/services/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e0df53200e22aca0be8f5b5b76dd754002864005
--- /dev/null
+++ b/src/terra_testing/services/__init__.py
@@ -0,0 +1,19 @@
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.auth_service import AuthService
+from terra_testing.services.backup_service import BackupService
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.quiz_service import QuizService
+from terra_testing.services.report_service import ReportService
+from terra_testing.services.schedule_service import ScheduleService
+from terra_testing.services.user_service import UserService
+
+__all__ = [
+    'AuditService',
+    'AuthService',
+    'BackupService',
+    'QuestionService',
+    'QuizService',
+    'ReportService',
+    'ScheduleService',
+    'UserService',
+]
diff --git a/src/terra_testing/services/audit_service.py b/src/terra_testing/services/audit_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..c63ec6399cc1e3b0053b058f366626de3a6ee581
--- /dev/null
+++ b/src/terra_testing/services/audit_service.py
@@ -0,0 +1,33 @@
+from __future__ import annotations
+
+from datetime import datetime
+
+from terra_testing.repositories.audit_repository import AuditRepository
+
+
+class AuditService:
+    def __init__(self) -> None:
+        self.repository = AuditRepository()
+
+    def log(self, event_type: str, actor: str, message: str):
+        return self.repository.create(event_type=event_type, actor=actor, message=message)
+
+    def list_recent(self, limit: int = 100):
+        return self.repository.list_recent(limit=limit)
+
+    def list_filtered(
+        self,
+        *,
+        event_type: str | None = None,
+        actor: str | None = None,
+        day_from: datetime | None = None,
+        day_to: datetime | None = None,
+        limit: int = 500,
+    ):
+        return self.repository.list_filtered(
+            event_type=event_type,
+            actor=actor,
+            day_from=day_from,
+            day_to=day_to,
+            limit=limit,
+        )
diff --git a/src/terra_testing/services/auth_service.py b/src/terra_testing/services/auth_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..0fcf71b5dcdb5367de40f351468e044c532c3b48
--- /dev/null
+++ b/src/terra_testing/services/auth_service.py
@@ -0,0 +1,46 @@
+from __future__ import annotations
+
+import logging
+
+from terra_testing.services.audit_service import AuditService
+from terra_testing.repositories.user_repository import UserRepository
+from terra_testing.sync.sync_service import SyncService
+from terra_testing.utils.security import verify_password
+
+logger = logging.getLogger(__name__)
+
+
+class AuthService:
+    def __init__(self) -> None:
+        self.user_repository = UserRepository()
+        self.sync_service = SyncService()
+        self.audit_service = AuditService()
+
+    def login(self, username: str, password: str) -> dict:
+        user = self.user_repository.get_by_username(username)
+        if user is None:
+            self.audit_service.log('login_failed', username or 'anonymous', 'Пользователь не найден')
+            return {'success': False, 'error': 'Пользователь не найден'}
+
+        if not user.is_active:
+            self.audit_service.log('login_failed', user.username, 'Пользователь деактивирован')
+            return {'success': False, 'error': 'Пользователь деактивирован'}
+
+        if not verify_password(password, user.password_hash):
+            self.audit_service.log('login_failed', user.username, 'Неверный пароль')
+            return {'success': False, 'error': 'Неверный пароль'}
+
+        self.audit_service.log('login_success', user.username, f'Успешный вход пользователя {user.full_name}')
+
+        try:
+            self.sync_service.sync_after_login(user.id)
+        except Exception as exc:
+            logger.warning('Post-login sync failed for user_id=%s: %s', user.id, exc)
+
+        return {
+            'success': True,
+            'role': user.role.name,
+            'user_id': user.id,
+            'username': user.username,
+            'full_name': user.full_name,
+        }
diff --git a/src/terra_testing/services/backup_service.py b/src/terra_testing/services/backup_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..9c7b3eb4e165aeef44bd6ae0a45e07df08e2f204
--- /dev/null
+++ b/src/terra_testing/services/backup_service.py
@@ -0,0 +1,38 @@
+from __future__ import annotations
+
+import shutil
+from datetime import datetime
+from pathlib import Path
+
+from terra_testing.config.settings import get_settings
+
+
+class BackupService:
+    def __init__(self) -> None:
+        self.settings = get_settings()
+
+    def _db_path(self) -> Path:
+        db_url = self.settings.local_db_url
+        if not db_url.startswith('sqlite:///'):
+            raise ValueError('BackupService supports only SQLite URLs.')
+        return Path(db_url.replace('sqlite:///', '', 1))
+
+    def create_backup(self) -> Path:
+        source = self._db_path()
+        if not source.exists():
+            raise FileNotFoundError(source)
+        target = self.settings.backup_dir / f'training_system_{datetime.now():%Y%m%d_%H%M%S}.db'
+        shutil.copy2(source, target)
+        return target
+
+    def list_backups(self) -> list[Path]:
+        return sorted(self.settings.backup_dir.glob('*.db'), reverse=True)
+
+    def restore_backup(self, backup_path: str | Path) -> Path:
+        source = Path(backup_path)
+        if not source.exists():
+            raise FileNotFoundError(source)
+        target = self._db_path()
+        target.parent.mkdir(parents=True, exist_ok=True)
+        shutil.copy2(source, target)
+        return target
diff --git a/src/terra_testing/services/question_service.py b/src/terra_testing/services/question_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..9c090d57f251b30df4ce5fd6278bceccb33e904a
--- /dev/null
+++ b/src/terra_testing/services/question_service.py
@@ -0,0 +1,32 @@
+from __future__ import annotations
+
+from terra_testing.repositories.question_repository import QuestionRepository
+
+
+class QuestionService:
+    def __init__(self) -> None:
+        self.repository = QuestionRepository()
+
+    def list_questions(self):
+        return self.repository.list_questions()
+
+    def count_questions(self) -> int:
+        return self.repository.count_questions()
+
+    def list_categories(self):
+        return self.repository.list_categories()
+
+    def get_question(self, question_id: int):
+        return self.repository.get_question(question_id)
+
+    def create_category(self, name: str):
+        return self.repository.create_category(name=name)
+
+    def create_question(self, category_id: int, text: str, answers: list[dict]):
+        return self.repository.create_question(category_id=category_id, text=text, answers=answers)
+
+    def update_question(self, question_id: int, category_id: int, text: str, answers: list[dict]):
+        return self.repository.update_question(question_id=question_id, category_id=category_id, text=text, answers=answers)
+
+    def set_question_active(self, question_id: int, is_active: bool):
+        return self.repository.set_question_active(question_id, is_active)
diff --git a/src/terra_testing/services/quiz_service.py b/src/terra_testing/services/quiz_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..e7571509063c090a868dcaf359991da5d0057a3d
--- /dev/null
+++ b/src/terra_testing/services/quiz_service.py
@@ -0,0 +1,105 @@
+from __future__ import annotations
+
+from terra_testing.config.settings import get_settings
+from terra_testing.repositories.question_repository import QuestionRepository
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.repositories.schedule_repository import ScheduleRepository
+from terra_testing.services.audit_service import AuditService
+from terra_testing.sync.sync_service import SyncService
+from terra_testing.utils.time import utcnow
+
+
+class QuizService:
+    def __init__(self) -> None:
+        self.settings = get_settings()
+        self.question_repository = QuestionRepository()
+        self.result_repository = ResultRepository()
+        self.schedule_repository = ScheduleRepository()
+        self.sync_service = SyncService()
+        self.audit_service = AuditService()
+
+    def start_quiz(self, user_id: int, assignment_id: int | None = None) -> dict:
+        limit = self.settings.questions_per_test
+        if assignment_id is not None:
+            assignment = self.schedule_repository.get_assignment(assignment_id)
+            if assignment is None:
+                raise ValueError('Назначение не найдено')
+            if assignment.user_id != user_id:
+                raise ValueError('Назначение принадлежит другому пользователю')
+            if assignment.status == 'completed':
+                raise ValueError('Назначение уже завершено')
+            if assignment.due_at and assignment.due_at < utcnow().replace(tzinfo=None):
+                raise ValueError('Срок выполнения назначения истёк')
+            attempts = self.result_repository.count_attempts_for_assignment(user_id, assignment_id)
+            if attempts >= assignment.max_attempts:
+                raise ValueError('Превышен лимит попыток для назначенного теста')
+            limit = assignment.questions_count
+
+        questions = self.question_repository.random_questions(limit)
+        return {
+            'assignment_id': assignment_id,
+            'questions': questions,
+            'total_questions': len(questions),
+            'seconds_per_question': self.settings.seconds_per_question,
+        }
+
+    def calculate_result(self, answers: list[dict]) -> dict:
+        total = len(answers)
+        correct = sum(1 for item in answers if item['is_correct'])
+        score_percent = int((correct / total) * 100) if total else 0
+        status = 'passed' if score_percent >= self.settings.pass_percent else 'failed'
+        return {
+            'correct_answers': correct,
+            'total_questions': total,
+            'score_percent': score_percent,
+            'status': status,
+        }
+
+    def build_answer_payload(self, questions, selected_answer_ids: dict[int, int | None]) -> list[dict]:
+        payload: list[dict] = []
+        for question in questions:
+            selected_answer_id = selected_answer_ids.get(question.id)
+            correct_answer_ids = {answer.id for answer in question.answers if answer.is_correct}
+            payload.append(
+                {
+                    'question_id': question.id,
+                    'selected_answer_id': selected_answer_id,
+                    'is_correct': selected_answer_id in correct_answer_ids,
+                }
+            )
+        return payload
+
+    def complete_quiz_from_selection(
+        self,
+        *,
+        user_id: int,
+        questions,
+        selected_answer_ids: dict[int, int | None],
+        assignment_id: int | None,
+    ):
+        answers = self.build_answer_payload(questions, selected_answer_ids)
+        result = self.complete_quiz(user_id=user_id, assignment_id=assignment_id, answers=answers)
+        if assignment_id is not None:
+            self.schedule_repository.mark_completed(assignment_id)
+        return result
+
+    def complete_quiz(self, *, user_id: int, assignment_id: int | None, answers: list[dict]):
+        if assignment_id is not None:
+            attempts = self.result_repository.count_attempts_for_assignment(user_id, assignment_id)
+            assignment = self.schedule_repository.get_assignment(assignment_id)
+            if assignment is not None and attempts >= assignment.max_attempts:
+                raise ValueError('Превышен лимит попыток для назначенного теста')
+
+        result_payload = self.calculate_result(answers)
+        result = self.result_repository.create_result(
+            user_id=user_id,
+            assignment_id=assignment_id,
+            answers=answers,
+            **result_payload,
+        )
+        self.audit_service.log('quiz_completed', str(user_id), f'Завершён тест result_id={result.id}, status={result.status}, score={result.score_percent}')
+        try:
+            self.sync_service.sync_after_test_completion(result.id)
+        except Exception:
+            pass
+        return result
diff --git a/src/terra_testing/services/report_service.py b/src/terra_testing/services/report_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..3ef82229cfc9c88876aa2fdc3da65bc027f05f63
--- /dev/null
+++ b/src/terra_testing/services/report_service.py
@@ -0,0 +1,32 @@
+from __future__ import annotations
+
+from pathlib import Path
+
+from terra_testing.config.settings import get_settings
+from terra_testing.reports.excel_report import build_audit_excel, build_results_excel
+from terra_testing.reports.pdf_report import build_audit_pdf, build_results_pdf
+
+
+class ReportService:
+    def __init__(self) -> None:
+        self.settings = get_settings()
+
+    def export_results_pdf(self, rows: list[dict], filename: str = "results_report.pdf") -> Path:
+        output = self.settings.export_dir / filename
+        build_results_pdf(rows, output)
+        return output
+
+    def export_results_excel(self, rows: list[dict], filename: str = "results_report.xlsx") -> Path:
+        output = self.settings.export_dir / filename
+        build_results_excel(rows, output)
+        return output
+
+    def export_audit_pdf(self, rows: list[dict], filename: str = "audit_report.pdf") -> Path:
+        output = self.settings.export_dir / filename
+        build_audit_pdf(rows, output)
+        return output
+
+    def export_audit_excel(self, rows: list[dict], filename: str = "audit_report.xlsx") -> Path:
+        output = self.settings.export_dir / filename
+        build_audit_excel(rows, output)
+        return output
diff --git a/src/terra_testing/services/schedule_service.py b/src/terra_testing/services/schedule_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..b945d7355e29cd4a5d74a075254468561fc73e1c
--- /dev/null
+++ b/src/terra_testing/services/schedule_service.py
@@ -0,0 +1,49 @@
+from __future__ import annotations
+
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.repositories.schedule_repository import ScheduleRepository
+from terra_testing.utils.time import utcnow
+
+
+class ScheduleService:
+    def __init__(self) -> None:
+        self.repository = ScheduleRepository()
+        self.result_repository = ResultRepository()
+
+    def list_assignments(self):
+        return self.repository.list_assignments()
+
+    def count_active_assignments(self) -> int:
+        return self.repository.count_active_assignments()
+
+    def list_assignments_for_user(self, user_id: int):
+        assignments = self.repository.list_assignments_for_user(user_id)
+        enriched = []
+        now = utcnow()
+        for assignment in assignments:
+            attempts_used = self.result_repository.count_attempts_for_assignment(user_id, assignment.id)
+            is_overdue = bool(assignment.due_at and assignment.due_at < now.replace(tzinfo=None))
+            can_start = assignment.status == 'assigned' and attempts_used < assignment.max_attempts and not is_overdue
+            enriched.append({
+                'assignment': assignment,
+                'attempts_used': attempts_used,
+                'attempts_left': max(assignment.max_attempts - attempts_used, 0),
+                'is_overdue': is_overdue,
+                'can_start': can_start,
+            })
+        return enriched
+
+    def get_assignment(self, assignment_id: int):
+        return self.repository.get_assignment(assignment_id)
+
+    def create_assignment(self, **kwargs):
+        return self.repository.create_assignment(**kwargs)
+
+    def update_assignment(self, **kwargs):
+        return self.repository.update_assignment(**kwargs)
+
+    def set_status(self, assignment_id: int, status: str):
+        return self.repository.set_status(assignment_id, status)
+
+    def mark_completed(self, assignment_id: int):
+        return self.repository.mark_completed(assignment_id)
diff --git a/src/terra_testing/services/user_service.py b/src/terra_testing/services/user_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..eca9a05c393ea7ff90fcbfea83ac997c1910d75c
--- /dev/null
+++ b/src/terra_testing/services/user_service.py
@@ -0,0 +1,57 @@
+from __future__ import annotations
+
+from terra_testing.repositories.user_repository import UserRepository
+from terra_testing.utils.security import hash_password, verify_password
+
+
+class UserService:
+    def __init__(self) -> None:
+        self.repository = UserRepository()
+
+    def list_users(self):
+        return self.repository.list_users()
+
+    def count_users(self) -> int:
+        return self.repository.count_users()
+
+    def list_roles(self):
+        return self.repository.list_roles()
+
+    def get_user(self, user_id: int):
+        return self.repository.get_by_id(user_id)
+
+    def create_user(self, username: str, full_name: str, password: str, role_id: int):
+        return self.repository.create_user(
+            username=username,
+            full_name=full_name,
+            password_hash=hash_password(password),
+            role_id=role_id,
+        )
+
+    def update_user(self, user_id: int, full_name: str, role_id: int):
+        return self.repository.update_user(user_id=user_id, full_name=full_name, role_id=role_id)
+
+    def update_password(self, user_id: int, password: str):
+        return self.repository.update_password(user_id=user_id, password_hash=hash_password(password))
+
+    def verify_current_password(self, user_id: int, password: str) -> bool:
+        user = self.repository.get_by_id(user_id)
+        if user is None:
+            return False
+        return verify_password(password, user.password_hash)
+
+    def change_password(self, user_id: int, current_password: str, new_password: str) -> tuple[bool, str]:
+        user = self.repository.get_by_id(user_id)
+        if user is None:
+            return False, "Пользователь не найден"
+        if not (current_password or "").strip():
+            return False, "Введите текущий пароль"
+        if not verify_password(current_password, user.password_hash):
+            return False, "Текущий пароль неверный"
+        if len((new_password or "").strip()) < 6:
+            return False, "Новый пароль слишком короткий"
+        self.repository.update_password(user_id=user_id, password_hash=hash_password(new_password))
+        return True, "Пароль обновлён"
+
+    def set_active(self, user_id: int, is_active: bool):
+        return self.repository.set_active(user_id, is_active)
diff --git a/src/terra_testing/sync/__init__.py b/src/terra_testing/sync/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/sync/sync_service.py b/src/terra_testing/sync/sync_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..5b25be7bcf60983e0b1abb26fd203817f2aae501
--- /dev/null
+++ b/src/terra_testing/sync/sync_service.py
@@ -0,0 +1,108 @@
+from __future__ import annotations
+
+import logging
+
+from sqlalchemy import text
+
+from terra_testing.config.settings import get_settings
+from terra_testing.db.session import get_remote_engine
+from terra_testing.repositories.sync_queue_repository import SyncQueueRepository
+from terra_testing.repositories.sync_repository import SyncRepository
+from terra_testing.services.audit_service import AuditService
+
+logger = logging.getLogger(__name__)
+
+
+class SyncService:
+    def __init__(self) -> None:
+        self.settings = get_settings()
+        self.sync_repository = SyncRepository()
+        self.sync_queue_repository = SyncQueueRepository()
+        self.audit_service = AuditService()
+
+    def _can_sync(self) -> bool:
+        return self.settings.remote_sync_enabled and bool(self.settings.remote_db_url)
+
+    def _probe_remote(self) -> None:
+        engine = get_remote_engine()
+        if engine is None:
+            raise RuntimeError("Remote engine is not configured")
+        with engine.connect() as conn:
+            conn.execute(text("SELECT 1"))
+
+    def _sync_result(self, result_id: int) -> bool:
+        queue_item = self.sync_queue_repository.get_by_result_id(result_id)
+        if queue_item is not None:
+            self.sync_queue_repository.mark_processing(queue_item.id)
+
+        self._probe_remote()
+
+        self.sync_repository.mark_synced(result_id)
+        if queue_item is not None:
+            self.sync_queue_repository.mark_synced(queue_item.id)
+        return True
+
+    def sync_after_login(self, user_id: int) -> dict:
+        if not self._can_sync():
+            logger.info("Remote sync skipped after login: disabled")
+            return {"synced": 0, "failed": 0, "total": 0, "reason": "disabled"}
+        logger.info("Starting post-login sync for user_id=%s", user_id)
+        self._probe_remote()
+        return self.retry_pending_sync(actor=f"user:{user_id}", event_type="sync_retry_after_login")
+
+    def sync_after_test_completion(self, result_id: int) -> dict:
+        self.sync_queue_repository.enqueue_result(result_id)
+        if not self._can_sync():
+            logger.info("Remote sync skipped after test completion: disabled")
+            return {"synced": 0, "failed": 0, "total": 1, "reason": "disabled"}
+
+        logger.info("Starting post-test sync for result_id=%s", result_id)
+        try:
+            self._sync_result(result_id)
+            self.audit_service.log("sync_result_success", "system", f"Синхронизирован result #{result_id}")
+            return {"synced": 1, "failed": 0, "total": 1}
+        except Exception as exc:
+            logger.warning("Post-test sync failed for result_id=%s: %s", result_id, exc)
+            self.sync_repository.mark_failed(result_id, str(exc))
+            queue_item = self.sync_queue_repository.get_by_result_id(result_id)
+            if queue_item is not None:
+                self.sync_queue_repository.mark_failed(queue_item.id, str(exc))
+            self.audit_service.log("sync_result_failed", "system", f"Ошибка синхронизации result #{result_id}: {exc}")
+            return {"synced": 0, "failed": 1, "total": 1, "error": str(exc)}
+
+    def retry_result(self, result_id: int, *, actor: str = "admin") -> dict:
+        self.sync_queue_repository.enqueue_result(result_id)
+        try:
+            self._sync_result(result_id)
+            self.audit_service.log("sync_retry_result", actor, f"Повторная синхронизация result #{result_id} успешна")
+            return {"synced": 1, "failed": 0, "total": 1}
+        except Exception as exc:
+            self.sync_repository.mark_failed(result_id, str(exc))
+            queue_item = self.sync_queue_repository.get_by_result_id(result_id)
+            if queue_item is not None:
+                self.sync_queue_repository.mark_failed(queue_item.id, str(exc))
+            self.audit_service.log("sync_retry_result_failed", actor, f"Ошибка повторной синхронизации result #{result_id}: {exc}")
+            return {"synced": 0, "failed": 1, "total": 1, "error": str(exc)}
+
+    def retry_pending_sync(self, *, actor: str = "admin", event_type: str = "sync_retry_batch") -> dict:
+        items = self.sync_queue_repository.list_pending_like()
+        synced = 0
+        failed = 0
+
+        for item in items:
+            try:
+                if item.entity_type == "test_result":
+                    self._sync_result(item.entity_id)
+                    synced += 1
+                else:
+                    self.sync_queue_repository.mark_synced(item.id)
+                    synced += 1
+            except Exception as exc:
+                self.sync_queue_repository.mark_failed(item.id, str(exc))
+                if item.entity_type == "test_result":
+                    self.sync_repository.mark_failed(item.entity_id, str(exc))
+                failed += 1
+
+        total = len(items)
+        self.audit_service.log(event_type, actor, f"batch retry: synced={synced}, failed={failed}, total={total}")
+        return {"synced": synced, "failed": failed, "total": total}
diff --git a/src/terra_testing/utils/__init__.py b/src/terra_testing/utils/__init__.py
new file mode 100644
index 0000000000000000000000000000000000000000..e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
diff --git a/src/terra_testing/utils/logging.py b/src/terra_testing/utils/logging.py
new file mode 100644
index 0000000000000000000000000000000000000000..0c643ea4d2a361011206a68e202ab1881280f753
--- /dev/null
+++ b/src/terra_testing/utils/logging.py
@@ -0,0 +1,14 @@
+from __future__ import annotations
+
+import logging
+from pathlib import Path
+
+
+def setup_logging(log_dir: Path) -> None:
+    log_dir.mkdir(parents=True, exist_ok=True)
+    log_file = log_dir / "app.log"
+    logging.basicConfig(
+        level=logging.INFO,
+        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
+        handlers=[logging.FileHandler(log_file, encoding="utf-8"), logging.StreamHandler()],
+    )
diff --git a/src/terra_testing/utils/paths.py b/src/terra_testing/utils/paths.py
new file mode 100644
index 0000000000000000000000000000000000000000..6c6795b9c9f667556402ef9df22da27668c99889
--- /dev/null
+++ b/src/terra_testing/utils/paths.py
@@ -0,0 +1,8 @@
+from __future__ import annotations
+
+from pathlib import Path
+
+
+def ensure_directory(path: Path) -> Path:
+    path.mkdir(parents=True, exist_ok=True)
+    return path
diff --git a/src/terra_testing/utils/security.py b/src/terra_testing/utils/security.py
new file mode 100644
index 0000000000000000000000000000000000000000..80972b7e46e4ba2948f147ccac6829f03b5a0236
--- /dev/null
+++ b/src/terra_testing/utils/security.py
@@ -0,0 +1,13 @@
+from __future__ import annotations
+
+from passlib.context import CryptContext
+
+_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
+
+
+def hash_password(password: str) -> str:
+    return _pwd_context.hash(password)
+
+
+def verify_password(password: str, password_hash: str) -> bool:
+    return _pwd_context.verify(password, password_hash)
diff --git a/src/terra_testing/utils/time.py b/src/terra_testing/utils/time.py
new file mode 100644
index 0000000000000000000000000000000000000000..c2e5eaff4bf43b6e2073d96b6ab370603c3864ac
--- /dev/null
+++ b/src/terra_testing/utils/time.py
@@ -0,0 +1,7 @@
+from __future__ import annotations
+
+from datetime import datetime, timezone
+
+
+def utcnow() -> datetime:
+    return datetime.now(timezone.utc)
diff --git a/tests/conftest.py b/tests/conftest.py
new file mode 100644
index 0000000000000000000000000000000000000000..71c4efffa5b3430cbd2fc95cfbf8537e5b83b23b
--- /dev/null
+++ b/tests/conftest.py
@@ -0,0 +1,20 @@
+from __future__ import annotations
+
+import pytest
+
+from terra_testing.config.settings import reset_settings_cache
+from terra_testing.db.session import reset_engines
+
+
+@pytest.fixture(autouse=True)
+def isolate_test_database(tmp_path, monkeypatch):
+    db_path = tmp_path / "test.db"
+    monkeypatch.setenv("LOCAL_DB_URL", f"sqlite:///{db_path}")
+    monkeypatch.setenv("REMOTE_SYNC_ENABLED", "false")
+    monkeypatch.setenv("APP_ENV", "test")
+    monkeypatch.setenv("APP_DEBUG", "false")
+    reset_settings_cache()
+    reset_engines()
+    yield
+    reset_settings_cache()
+    reset_engines()
diff --git a/tests/test_access.py b/tests/test_access.py
new file mode 100644
index 0000000000000000000000000000000000000000..c34f1b18d7e6dd7599a206df6ca8aa40a07ad4cd
--- /dev/null
+++ b/tests/test_access.py
@@ -0,0 +1,33 @@
+from __future__ import annotations
+
+from terra_testing.app.access import is_admin, is_authenticated, is_user
+from terra_testing.app.session_state import SessionState
+
+
+class _Session:
+    def __init__(self, state):
+        self._state = state
+
+    def get(self, key):
+        if key == "state":
+            return self._state
+        return None
+
+
+class _Page:
+    def __init__(self, state):
+        self.session = _Session(state)
+
+
+def test_access_helpers_for_authenticated_user():
+    page = _Page(SessionState(user_id=1, username="user", role="user", is_authenticated=True))
+    assert is_authenticated(page) is True
+    assert is_user(page) is True
+    assert is_admin(page) is False
+
+
+def test_access_helpers_for_admin():
+    page = _Page(SessionState(user_id=1, username="admin", role="admin", is_authenticated=True))
+    assert is_authenticated(page) is True
+    assert is_user(page) is True
+    assert is_admin(page) is True
diff --git a/tests/test_assignment_flow.py b/tests/test_assignment_flow.py
new file mode 100644
index 0000000000000000000000000000000000000000..37667db32ef7d7020dcc3ba2484e431996d80041
--- /dev/null
+++ b/tests/test_assignment_flow.py
@@ -0,0 +1,93 @@
+from datetime import timedelta
+
+import pytest
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.quiz_service import QuizService
+from terra_testing.services.schedule_service import ScheduleService
+from terra_testing.services.user_service import UserService
+from terra_testing.utils.time import utcnow
+
+
+def _create_user(username: str, role_name: str = 'user'):
+    with get_local_session() as session:
+        role = Role(name=role_name)
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    return UserService().create_user(username, username, 'User123!', role.id)
+
+
+def _seed_questions() -> list:
+    qservice = QuestionService()
+    category = qservice.create_category('Охрана труда')
+    qservice.create_question(
+        category.id,
+        'Вопрос 1',
+        [
+            {'text': 'Верный', 'is_correct': True},
+            {'text': 'Неверный', 'is_correct': False},
+        ],
+    )
+    qservice.create_question(
+        category.id,
+        'Вопрос 2',
+        [
+            {'text': 'Неверный', 'is_correct': False},
+            {'text': 'Верный', 'is_correct': True},
+        ],
+    )
+    return qservice.list_questions()
+
+
+def test_start_quiz_rejects_completed_assignment():
+    init_db()
+    user = _create_user('user01')
+    _seed_questions()
+    assignment = ScheduleService().create_assignment(
+        user_id=user.id,
+        title='Проверка знаний',
+        questions_count=2,
+        max_attempts=1,
+        due_at=None,
+    )
+    ScheduleService().mark_completed(assignment.id)
+
+    with pytest.raises(ValueError):
+        QuizService().start_quiz(user.id, assignment.id)
+
+
+def test_start_quiz_rejects_foreign_assignment():
+    init_db()
+    user1 = _create_user('user01')
+    user2 = _create_user('user02')
+    _seed_questions()
+    assignment = ScheduleService().create_assignment(
+        user_id=user1.id,
+        title='Проверка знаний',
+        questions_count=2,
+        max_attempts=1,
+        due_at=None,
+    )
+
+    with pytest.raises(ValueError):
+        QuizService().start_quiz(user2.id, assignment.id)
+
+
+def test_start_quiz_rejects_overdue_assignment():
+    init_db()
+    user = _create_user('user01')
+    _seed_questions()
+    assignment = ScheduleService().create_assignment(
+        user_id=user.id,
+        title='Просроченный тест',
+        questions_count=2,
+        max_attempts=1,
+        due_at=(utcnow() - timedelta(days=1)).replace(tzinfo=None),
+    )
+
+    with pytest.raises(ValueError):
+        QuizService().start_quiz(user.id, assignment.id)
diff --git a/tests/test_audit.py b/tests/test_audit.py
new file mode 100644
index 0000000000000000000000000000000000000000..0d7bf67b9b150bc669d70816a188358f842de7f1
--- /dev/null
+++ b/tests/test_audit.py
@@ -0,0 +1,13 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.services.audit_service import AuditService
+
+
+def test_audit_log_is_created():
+    init_db()
+    service = AuditService()
+    entry = service.log('user_created', 'admin', 'Создан тестовый пользователь')
+    items = service.list_recent()
+    assert entry.id is not None
+    assert items[0].event_type == 'user_created'
diff --git a/tests/test_audit_export.py b/tests/test_audit_export.py
new file mode 100644
index 0000000000000000000000000000000000000000..07f18810b4a2de62bfd647e92bd1e19bb8dd7dcc
--- /dev/null
+++ b/tests/test_audit_export.py
@@ -0,0 +1,28 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.services.audit_service import AuditService
+from terra_testing.services.report_service import ReportService
+
+
+def test_audit_exports_are_created(tmp_path, monkeypatch):
+    monkeypatch.setenv("EXPORT_DIR", str(tmp_path / "exports"))
+    init_db()
+    audit_service = AuditService()
+    audit_service.log("login_success", "admin", "Успешный вход")
+
+    rows = [
+        {
+            "created_at": "2026-03-14 10:00",
+            "event_type": "login_success",
+            "actor": "admin",
+            "message": "Успешный вход",
+        }
+    ]
+
+    report_service = ReportService()
+    pdf_path = report_service.export_audit_pdf(rows)
+    excel_path = report_service.export_audit_excel(rows)
+
+    assert pdf_path.exists()
+    assert excel_path.exists()
diff --git a/tests/test_auth.py b/tests/test_auth.py
new file mode 100644
index 0000000000000000000000000000000000000000..bb67d4cffbf3d2f4923053b91b09369721fca072
--- /dev/null
+++ b/tests/test_auth.py
@@ -0,0 +1,37 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.services.auth_service import AuthService
+from terra_testing.services.user_service import UserService
+
+
+def _prepare_role(name: str) -> Role:
+    with get_local_session() as session:
+        role = Role(name=name)
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+        return role
+
+
+def test_login_success():
+    init_db()
+    role = _prepare_role("admin")
+    UserService().create_user("admin", "Admin", "Admin123!", role.id)
+
+    result = AuthService().login("admin", "Admin123!")
+    assert result["success"] is True
+    assert result["role"] == "admin"
+    assert result["username"] == "admin"
+
+
+def test_login_bad_password():
+    init_db()
+    role = _prepare_role("admin")
+    UserService().create_user("admin", "Admin", "Admin123!", role.id)
+
+    result = AuthService().login("admin", "wrong")
+    assert result["success"] is False
+    assert result["error"] == "Неверный пароль"
diff --git a/tests/test_question_service.py b/tests/test_question_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..425d4da3f827e2e78fa5b19edfdc3d0bbb0ab7b0
--- /dev/null
+++ b/tests/test_question_service.py
@@ -0,0 +1,34 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.services.question_service import QuestionService
+
+
+def test_question_can_be_updated_with_new_answers():
+    init_db()
+    service = QuestionService()
+    category = service.create_category("Охрана труда")
+    question = service.create_question(
+        category.id,
+        "Старый вопрос",
+        [
+            {"text": "Да", "is_correct": True},
+            {"text": "Нет", "is_correct": False},
+        ],
+    )
+
+    updated = service.update_question(
+        question.id,
+        category.id,
+        "Новый вопрос",
+        [
+            {"text": "Первый", "is_correct": False},
+            {"text": "Второй", "is_correct": True},
+            {"text": "Третий", "is_correct": False},
+        ],
+    )
+
+    assert updated is not None
+    assert updated.text == "Новый вопрос"
+    assert len(updated.answers) == 3
+    assert sum(1 for answer in updated.answers if answer.is_correct) == 1
diff --git a/tests/test_quiz.py b/tests/test_quiz.py
new file mode 100644
index 0000000000000000000000000000000000000000..fb0436d4270fec3b6c534f3ce60a131d3d55886b
--- /dev/null
+++ b/tests/test_quiz.py
@@ -0,0 +1,112 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.quiz_service import QuizService
+from terra_testing.services.schedule_service import ScheduleService
+from terra_testing.services.user_service import UserService
+
+
+def _create_user_with_role(name: str = "user"):
+    with get_local_session() as session:
+        role = Role(name=name)
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+        return UserService().create_user("user01", "User", "User123!", role.id)
+
+
+def _seed_questions() -> list:
+    qservice = QuestionService()
+    category = qservice.create_category("Охрана труда")
+    qservice.create_question(
+        category.id,
+        "Вопрос 1",
+        [
+            {"text": "Верный", "is_correct": True},
+            {"text": "Неверный", "is_correct": False},
+        ],
+    )
+    qservice.create_question(
+        category.id,
+        "Вопрос 2",
+        [
+            {"text": "Неверный", "is_correct": False},
+            {"text": "Верный", "is_correct": True},
+        ],
+    )
+    return qservice.list_questions()
+
+
+def test_calculate_result_pass():
+    init_db()
+    service = QuizService()
+    result = service.calculate_result(
+        [
+            {"question_id": 1, "selected_answer_id": 1, "is_correct": True},
+            {"question_id": 2, "selected_answer_id": 2, "is_correct": True},
+            {"question_id": 3, "selected_answer_id": 3, "is_correct": False},
+        ]
+    )
+    assert result["correct_answers"] == 2
+    assert result["score_percent"] == 66
+    assert result["status"] == "failed"
+
+
+def test_complete_quiz_from_selection_saves_result():
+    init_db()
+    user = _create_user_with_role()
+    questions = _seed_questions()
+    service = QuizService()
+
+    selected_answer_ids = {
+        questions[0].id: next(answer.id for answer in questions[0].answers if answer.is_correct),
+        questions[1].id: next(answer.id for answer in questions[1].answers if not answer.is_correct),
+    }
+
+    result = service.complete_quiz_from_selection(
+        user_id=user.id,
+        questions=questions,
+        selected_answer_ids=selected_answer_ids,
+        assignment_id=None,
+    )
+
+    assert result.total_questions == 2
+    assert result.correct_answers == 1
+    assert result.sync_state in {"pending", "failed", "synced"}
+
+
+def test_assignment_attempt_limit_is_enforced():
+    init_db()
+    user = _create_user_with_role()
+    questions = _seed_questions()
+    assignment = ScheduleService().create_assignment(
+        user_id=user.id,
+        title="Проверка знаний",
+        questions_count=2,
+        max_attempts=1,
+        due_at=None,
+    )
+    service = QuizService()
+    selected_answer_ids = {question.id: question.answers[0].id for question in questions}
+
+    service.complete_quiz_from_selection(
+        user_id=user.id,
+        questions=questions,
+        selected_answer_ids=selected_answer_ids,
+        assignment_id=assignment.id,
+    )
+
+    try:
+        service.complete_quiz_from_selection(
+            user_id=user.id,
+            questions=questions,
+            selected_answer_ids=selected_answer_ids,
+            assignment_id=assignment.id,
+        )
+    except ValueError as exc:
+        assert "лимит попыток" in str(exc)
+    else:
+        raise AssertionError("Expected ValueError for attempt limit")
diff --git a/tests/test_reports.py b/tests/test_reports.py
new file mode 100644
index 0000000000000000000000000000000000000000..e29cb72103383f9c53f1ec5dfa9a7cd75f51d13f
--- /dev/null
+++ b/tests/test_reports.py
@@ -0,0 +1,49 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.quiz_service import QuizService
+from terra_testing.services.report_service import ReportService
+from terra_testing.services.user_service import UserService
+
+
+def _prepare_data():
+    with get_local_session() as session:
+        role = Role(name='user')
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    user = UserService().create_user('user01', 'User', 'User123!', role.id)
+    qservice = QuestionService()
+    category = qservice.create_category('Охрана труда')
+    question = qservice.create_question(
+        category.id,
+        'Вопрос',
+        [
+            {'text': 'Верный', 'is_correct': True},
+            {'text': 'Неверный', 'is_correct': False},
+        ],
+    )
+    answer_id = next(answer.id for answer in question.answers if answer.is_correct)
+    result = QuizService().complete_quiz_from_selection(
+        user_id=user.id,
+        questions=[question],
+        selected_answer_ids={question.id: answer_id},
+        assignment_id=None,
+    )
+    return [{'full_name': user.full_name, 'score_percent': result.score_percent, 'status': result.status}]
+
+
+def test_report_files_are_created(tmp_path, monkeypatch):
+    monkeypatch.setenv('EXPORT_DIR', str(tmp_path / 'exports'))
+    init_db()
+    rows = _prepare_data()
+
+    service = ReportService()
+    pdf_path = service.export_results_pdf(rows)
+    excel_path = service.export_results_excel(rows)
+
+    assert pdf_path.exists()
+    assert excel_path.exists()
diff --git a/tests/test_result_filters.py b/tests/test_result_filters.py
new file mode 100644
index 0000000000000000000000000000000000000000..3dd8c25c9496d6ccf632c0d031f44fa285bf7cab
--- /dev/null
+++ b/tests/test_result_filters.py
@@ -0,0 +1,53 @@
+from __future__ import annotations
+
+from datetime import datetime, timedelta, timezone
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.models.test_result import TestResult
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.services.user_service import UserService
+
+
+def _create_user():
+    with get_local_session() as session:
+        role = Role(name="user")
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    return UserService().create_user("user01", "User", "User123!", role.id)
+
+
+def test_result_repository_filters_by_day_range():
+    init_db()
+    user = _create_user()
+    with get_local_session() as session:
+        old_result = TestResult(
+            user_id=user.id,
+            assignment_id=None,
+            correct_answers=1,
+            total_questions=1,
+            score_percent=100,
+            status="passed",
+            completed_at=datetime.now(timezone.utc) - timedelta(days=5),
+        )
+        new_result = TestResult(
+            user_id=user.id,
+            assignment_id=None,
+            correct_answers=1,
+            total_questions=1,
+            score_percent=100,
+            status="passed",
+            completed_at=datetime.now(timezone.utc),
+        )
+        session.add_all([old_result, new_result])
+        session.commit()
+
+    repo = ResultRepository()
+    results = repo.list_filtered_results_by_day(
+        day_from=datetime.now() - timedelta(days=1),
+        day_to=datetime.now(),
+    )
+    assert len(results) == 1
+    assert results[0].score_percent == 100
diff --git a/tests/test_router.py b/tests/test_router.py
new file mode 100644
index 0000000000000000000000000000000000000000..6c9f4dd09dc85b3ed190b3e1998a75f8e6acd993
--- /dev/null
+++ b/tests/test_router.py
@@ -0,0 +1,25 @@
+from terra_testing.app.router import fallback_route_for_state, route_is_allowed
+from terra_testing.app.session_state import SessionState
+
+
+def test_unauthenticated_user_cannot_open_admin_route():
+    state = SessionState()
+    assert route_is_allowed('/admin', state) is False
+    assert fallback_route_for_state(state, '/admin') == '/login'
+
+
+def test_admin_can_open_admin_route():
+    state = SessionState(user_id=1, username='admin', role='admin', is_authenticated=True)
+    assert route_is_allowed('/admin', state) is True
+    assert route_is_allowed('/admin/questions', state) is True
+
+
+def test_regular_user_is_redirected_from_admin_route():
+    state = SessionState(user_id=2, username='user01', role='user', is_authenticated=True)
+    assert route_is_allowed('/admin', state) is False
+    assert fallback_route_for_state(state, '/admin/questions') == '/user'
+
+
+def test_authenticated_user_is_redirected_from_login():
+    state = SessionState(user_id=2, username='user01', role='user', is_authenticated=True)
+    assert fallback_route_for_state(state, '/login') == '/user'
diff --git a/tests/test_schedule_service.py b/tests/test_schedule_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..e789bec7cbb975619a52b97c61b0913e3800c32e
--- /dev/null
+++ b/tests/test_schedule_service.py
@@ -0,0 +1,42 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.services.schedule_service import ScheduleService
+from terra_testing.services.user_service import UserService
+
+
+def _create_user():
+    with get_local_session() as session:
+        role = Role(name="user")
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    return UserService().create_user("user01", "User", "User123!", role.id)
+
+
+def test_assignment_can_be_updated():
+    init_db()
+    user = _create_user()
+    service = ScheduleService()
+    assignment = service.create_assignment(
+        user_id=user.id,
+        title="Old title",
+        questions_count=10,
+        max_attempts=2,
+        due_at=None,
+    )
+    updated = service.update_assignment(
+        assignment_id=assignment.id,
+        user_id=user.id,
+        title="New title",
+        questions_count=20,
+        max_attempts=3,
+        due_at=None,
+        status="assigned",
+    )
+    assert updated is not None
+    assert updated.title == "New title"
+    assert updated.questions_count == 20
+    assert updated.max_attempts == 3
diff --git a/tests/test_settings_service.py b/tests/test_settings_service.py
new file mode 100644
index 0000000000000000000000000000000000000000..14d92703fb742b13891c2a142430a106a34142ce
--- /dev/null
+++ b/tests/test_settings_service.py
@@ -0,0 +1,33 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.services.user_service import UserService
+
+
+def _create_user():
+    with get_local_session() as session:
+        role = Role(name="user")
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    return UserService().create_user("user01", "User", "User123!", role.id)
+
+
+def test_change_password_rejects_wrong_current_password():
+    init_db()
+    user = _create_user()
+    ok, message = UserService().change_password(user.id, "wrong", "NewPass123!")
+    assert ok is False
+    assert "неверный" in message.lower()
+
+
+def test_change_password_accepts_correct_current_password():
+    init_db()
+    user = _create_user()
+    service = UserService()
+    ok, message = service.change_password(user.id, "User123!", "NewPass123!")
+    assert ok is True
+    assert "обновлён" in message.lower()
+    assert service.verify_current_password(user.id, "NewPass123!") is True
diff --git a/tests/test_sync.py b/tests/test_sync.py
new file mode 100644
index 0000000000000000000000000000000000000000..ff05224146797d59c069a72544b141bd6c8ad3e4
--- /dev/null
+++ b/tests/test_sync.py
@@ -0,0 +1,105 @@
+from __future__ import annotations
+
+from terra_testing.config.settings import reset_settings_cache
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session, reset_engines
+from terra_testing.models.role import Role
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.user_service import UserService
+from terra_testing.sync.sync_service import SyncService
+
+
+def test_sync_skips_when_disabled():
+    init_db()
+    service = SyncService()
+    service.sync_after_login(1)  # should not raise
+
+
+def test_failed_remote_sync_marks_result_failed(monkeypatch):
+    monkeypatch.setenv('REMOTE_SYNC_ENABLED', 'true')
+    monkeypatch.setenv('REMOTE_DB_URL', 'mysql+pymysql://user:pass@127.0.0.1:3306/db')
+    reset_settings_cache()
+    reset_engines()
+    init_db()
+
+    with get_local_session() as session:
+        role = Role(name='user')
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    user = UserService().create_user('user01', 'User', 'User123!', role.id)
+
+    qservice = QuestionService()
+    category = qservice.create_category('Категория')
+    question = qservice.create_question(
+        category.id,
+        'Вопрос',
+        [
+            {'text': 'Да', 'is_correct': True},
+            {'text': 'Нет', 'is_correct': False},
+        ],
+    )
+
+    correct_answer = next(answer for answer in question.answers if answer.is_correct)
+    result = ResultRepository().create_result(
+        user_id=user.id,
+        assignment_id=None,
+        correct_answers=1,
+        total_questions=1,
+        score_percent=100,
+        status='passed',
+        answers=[{'question_id': question.id, 'selected_answer_id': correct_answer.id, 'is_correct': True}],
+    )
+
+    service = SyncService()
+    service.sync_after_test_completion(result.id)
+
+    updated = ResultRepository().get_result(result.id)
+    assert updated is not None
+    assert updated.sync_state == 'failed'
+    assert updated.retry_count == 1
+
+
+def test_retry_pending_sync_marks_rows_synced(monkeypatch):
+    monkeypatch.setenv('REMOTE_SYNC_ENABLED', 'true')
+    monkeypatch.setenv('REMOTE_DB_URL', 'mysql+pymysql://user:pass@127.0.0.1:3306/db')
+    reset_settings_cache()
+    reset_engines()
+    init_db()
+
+    with get_local_session() as session:
+        role = Role(name='user')
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    user = UserService().create_user('user01', 'User', 'User123!', role.id)
+
+    qservice = QuestionService()
+    category = qservice.create_category('Категория')
+    question = qservice.create_question(
+        category.id,
+        'Вопрос',
+        [
+            {'text': 'Да', 'is_correct': True},
+            {'text': 'Нет', 'is_correct': False},
+        ],
+    )
+    result = ResultRepository().create_result(
+        user_id=user.id,
+        assignment_id=None,
+        correct_answers=0,
+        total_questions=1,
+        score_percent=0,
+        status='failed',
+        answers=[{'question_id': question.id, 'selected_answer_id': None, 'is_correct': False}],
+    )
+
+    service = SyncService()
+    monkeypatch.setattr(service, '_probe_remote', lambda: None)
+    summary = service.retry_pending_sync()
+
+    updated = ResultRepository().get_result(result.id)
+    assert summary['synced'] == 1
+    assert updated is not None
+    assert updated.sync_state == 'synced'
diff --git a/tests/test_sync_queue.py b/tests/test_sync_queue.py
new file mode 100644
index 0000000000000000000000000000000000000000..f2000ee97904de7b372bc1a77ca30fe7a51a15ab
--- /dev/null
+++ b/tests/test_sync_queue.py
@@ -0,0 +1,60 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.repositories.sync_queue_repository import SyncQueueRepository
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.user_service import UserService
+from terra_testing.sync.sync_service import SyncService
+
+
+def _seed_result():
+    with get_local_session() as session:
+        role = Role(name="user")
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    user = UserService().create_user("user01", "User", "User123!", role.id)
+    qservice = QuestionService()
+    category = qservice.create_category("Категория")
+    question = qservice.create_question(
+        category.id,
+        "Вопрос",
+        [
+            {"text": "Да", "is_correct": True},
+            {"text": "Нет", "is_correct": False},
+        ],
+    )
+    result = ResultRepository().create_result(
+        user_id=user.id,
+        assignment_id=None,
+        correct_answers=0,
+        total_questions=1,
+        score_percent=0,
+        status="failed",
+        answers=[{"question_id": question.id, "selected_answer_id": None, "is_correct": False}],
+    )
+    return result
+
+
+def test_create_result_enqueues_sync_item():
+    init_db()
+    result = _seed_result()
+    item = SyncQueueRepository().get_by_result_id(result.id)
+    assert item is not None
+    assert item.status == "pending"
+    assert item.entity_type == "test_result"
+
+
+def test_retry_result_updates_sync_queue(monkeypatch):
+    init_db()
+    result = _seed_result()
+    service = SyncService()
+    monkeypatch.setattr(service, "_probe_remote", lambda: None)
+    summary = service.retry_result(result.id)
+    item = SyncQueueRepository().get_by_result_id(result.id)
+    assert summary["synced"] == 1
+    assert item is not None
+    assert item.status == "synced"
diff --git a/tests/test_sync_retry.py b/tests/test_sync_retry.py
new file mode 100644
index 0000000000000000000000000000000000000000..d4de22156f5cba2d4766fe4ae29828423822081a
--- /dev/null
+++ b/tests/test_sync_retry.py
@@ -0,0 +1,60 @@
+from __future__ import annotations
+
+from terra_testing.db.init_db import init_db
+from terra_testing.db.session import get_local_session
+from terra_testing.models.role import Role
+from terra_testing.repositories.audit_repository import AuditRepository
+from terra_testing.repositories.result_repository import ResultRepository
+from terra_testing.services.question_service import QuestionService
+from terra_testing.services.user_service import UserService
+from terra_testing.sync.sync_service import SyncService
+
+
+def _seed_result():
+    with get_local_session() as session:
+        role = Role(name="user")
+        session.add(role)
+        session.commit()
+        session.refresh(role)
+    user = UserService().create_user("user01", "User", "User123!", role.id)
+    qservice = QuestionService()
+    category = qservice.create_category("Категория")
+    question = qservice.create_question(
+        category.id,
+        "Вопрос",
+        [
+            {"text": "Да", "is_correct": True},
+            {"text": "Нет", "is_correct": False},
+        ],
+    )
+    return ResultRepository().create_result(
+        user_id=user.id,
+        assignment_id=None,
+        correct_answers=0,
+        total_questions=1,
+        score_percent=0,
+        status="failed",
+        answers=[{"question_id": question.id, "selected_answer_id": None, "is_correct": False}],
+    )
+
+
+def test_retry_single_result_marks_it_synced(monkeypatch):
+    init_db()
+    result = _seed_result()
+    service = SyncService()
+    monkeypatch.setattr(service, "_probe_remote", lambda: None)
+    summary = service.retry_result(result.id)
+    updated = ResultRepository().get_result(result.id)
+    assert summary["synced"] == 1
+    assert updated is not None
+    assert updated.sync_state == "synced"
+
+
+def test_retry_single_result_creates_audit_event(monkeypatch):
+    init_db()
+    result = _seed_result()
+    service = SyncService()
+    monkeypatch.setattr(service, "_probe_remote", lambda: None)
+    service.retry_result(result.id, actor="admin")
+    logs = AuditRepository().list_recent(limit=10)
+    assert any(log.event_type == "sync_retry_result" for log in logs)