# TASK.md

## Objective
Довести проект до production-ready состояния и выпустить релиз `v1.0.0` для Windows desktop.

## Context
Проект — ИС тестирования знаний сотрудников на Flet.
Система должна работать offline-first:
- основная operational БД: SQLite;
- удалённая MySQL: только для синхронизации;
- вход в систему не зависит от доступности MySQL.

## Required deliverables
1. Нормализованные требования и scope.
2. Рабочее приложение Windows desktop.
3. Локальная SQLite схема и миграции.
4. Опциональный MySQL sync.
5. Админский контур.
6. Пользовательский контур.
7. Тестирование и CI.
8. Windows build artifact.
9. GitHub Release v1.0.0.
