# AGENTS.md

## Project
Информационная система тестирования знаний для ООО «Терра-Инжиниринг».

## Product goal
Собрать и выпустить production-ready v1.0 Windows desktop приложения на Python + Flet для:
- авторизации пользователей;
- управления вопросами, сотрудниками и графиком тестирования;
- прохождения тестов сотрудниками;
- хранения результатов и истории;
- формирования отчётов;
- локальной работы через SQLite;
- опциональной синхронизации в удалённую MySQL.

## Scope of v1.0
Обязательно входит:
- Windows desktop release;
- login/password auth;
- roles: admin, user;
- SQLite as primary operational database;
- optional MySQL synchronization;
- CRUD users;
- CRUD questions / answers / categories;
- test scheduling;
- quiz flow;
- scoring and pass/fail status;
- history and reports;
- PDF / Excel export;
- audit log;
- backup;
- automated tests;
- CI workflows;
- GitHub Release v1.0.0.

Не входит в v1.0:
- face recognition;
- gesture control;
- voice control;
- periodic camera photo capture;
- WebGL / 3D / VR / AR;
- AI adaptive questions;
- mobile build;
- PWA;
- email integration;
- 1C / HRM integration.

## Business rules
- Авторизация всегда выполняется по локальной SQLite.
- Удалённая MySQL не должна блокировать вход.
- Синхронизация выполняется только:
  1. после успешной авторизации;
  2. после завершения теста.
- При недоступности MySQL приложение продолжает работать локально.
- Ошибки sync логируются.
- Несинхронизированные сущности должны быть помечены статусом pending/failed.
- Результаты тестов, сохранённые локально, не должны теряться из-за ошибок sync.

## Functional baseline
- 2 роли: admin, user.
- 17 текущих пользователей, масштабирование до 100+.
- 160 вопросов в банке.
- 20 вопросов в тесте.
- 70% — порог прохождения.
- 30 секунд на вопрос.
- До 3 попыток на сотрудника.

## Technology decisions
- Python 3.11+
- Flet
- SQLAlchemy 2.x
- Pydantic 2.x
- Alembic migrations
- pytest
- Ruff
- bcrypt / passlib or equivalent secure password hashing
- report generation for PDF and Excel
- env-based configuration
- repository/service architecture

## Repository expectations
Repo must contain:
- `pyproject.toml`
- `.env.example`
- `README.md`
- `CHANGELOG.md`
- `docs/`
- `tests/`
- `scripts/`
- `.github/workflows/`

## Quality bar
Before considering the task done:
- app starts locally from a documented command;
- SQLite database is initialized automatically or via a documented command;
- seed data exists;
- demo admin and demo users exist;
- login works;
- admin flows work;
- user can complete a test end-to-end;
- results persist locally;
- sync attempts run in the required two moments;
- sync failures do not break primary user flows;
- tests pass;
- CI is green;
- Windows artifact is built;
- release notes are prepared.
