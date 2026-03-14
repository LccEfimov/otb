# Prompt для запуска Codex с обязательным финальным GitHub Release

Ниже — готовый prompt, который можно целиком отдать Codex.

## Как использовать
1. Открой репозиторий в Codex.
2. Передай Codex этот prompt целиком.
3. Не сокращай prompt и не убирай финальный релизный блок.
4. Если у Codex нет прав на публикацию release, он должен подготовить всё до состояния «остаётся выполнить одну команду».

## Готовый prompt

```text
Ты работаешь как ведущий Python/Flet инженер, тестировщик, release engineer и GitHub maintainer.

Твоя задача:
взять текущий репозиторий проекта, довести его до production-ready состояния для v1.0.0, устранить дефекты, завершить недостающие части, прогнать проверки, подготовить Windows desktop релиз и в конце выпустить GitHub Release.

Источники истины внутри репозитория:
- AGENTS.md
- TASK.md
- README.md
- docs/requirements.md
- docs/scope_v1.md
- docs/adr/001-architecture.md
- docs/adr/002-data-sync.md
- docs/adr/003-release-strategy.md
- docs/release-notes/v1.0.0.md
- CHANGELOG.md

Работай по этим правилам.

1. Общая цель
Нужно завершить v1.0.0 Windows desktop приложения “ИС тестирования знаний” на Python + Flet.
Система должна:
- работать как Windows desktop app;
- использовать SQLite как основную локальную БД;
- использовать MySQL только как optional sync target;
- авторизовывать по локальной SQLite;
- выполнять попытку sync только:
  - после успешного логина;
  - после завершения теста;
- не ломать основной сценарий, если MySQL отсутствует или недоступна.

2. Scope v1.0 обязателен
Входит:
- login/password auth
- роли admin/user
- user CRUD
- question/category/answer CRUD
- test scheduling
- quiz flow
- pass/fail scoring
- history/results
- reports PDF/Excel
- audit log
- backup/restore
- Windows packaging
- CI
- GitHub Release

Не входит:
- биометрия
- gesture/voice control
- photo surveillance
- WebGL/3D/VR/AR
- mobile build
- PWA
- AI adaptive testing
- enterprise integrations

Не расширяй scope v1.0 без крайней необходимости.

3. Режим работы
Работай по этапам и после каждого этапа обновляй:
- CHANGELOG.md
- README.md, если это влияет на запуск/сборку/релиз
- docs, если меняется архитектура или правила эксплуатации

4. Архитектурные требования
Соблюдай:
- layered architecture
- thin Flet pages
- business logic in services
- persistence in repositories
- sync logic isolated in sync layer
- typed Python where practical
- no dangerous hidden coupling between UI and DB

5. Что нужно сделать по коду
Проверь и доведи до рабочего состояния:
- маршрутизацию и route guards;
- login/logout/session flow;
- admin pages;
- user pages;
- quiz flow и timer behavior;
- scheduling rules;
- result persistence;
- sync queue/sync monitor;
- audit log recording;
- report generation;
- backup/restore;
- settings/password change;
- migrations;
- seed data;
- tests.

Исправляй найденные архитектурные и runtime дефекты, а не маскируй их.

6. Quality gates
До релиза обязательно:
- проект устанавливается;
- миграции применяются;
- seed отрабатывает;
- приложение запускается;
- линтер проходит;
- тесты проходят;
- Windows build формируется;
- release notes готовы;
- changelog обновлён.

7. Definition of Done
Считай задачу выполненной только если:
- приложение реально готово к v1.0.0;
- все ключевые сценарии доведены;
- CI workflows не противоречат текущей структуре проекта;
- есть готовые release artifacts;
- есть tag v1.0.0;
- создан GitHub Release или полностью подготовлен draft release.

8. Поведение по Git и коммитам
- Делай небольшие осмысленные коммиты.
- Не оставляй мусорные временные файлы.
- Не ломай документацию.
- Не удаляй ADR/requirements без причины.
- Сохраняй понятную историю изменений.

9. Release workflow обязателен
В конце работы ты ОБЯЗАН:
1. привести репозиторий в зелёное состояние;
2. обновить CHANGELOG.md;
3. финализировать docs/release-notes/v1.0.0.md;
4. убедиться, что версия v1.0.0 согласована в проекте;
5. создать git tag:
   git tag -a v1.0.0 -m "Release v1.0.0"
6. push tag в origin;
7. собрать Windows release artifacts;
8. приложить артефакты к GitHub Release;
9. создать GitHub Release с title `v1.0.0`.

10. Публикация GitHub Release
Предпочтительный порядок:
- сначала подготовить draft release;
- приложить все assets;
- затем publish release.

В release обязательно включи:
- Windows artifact
- source archive
- checksums
- release notes

11. Если прав на публикацию релиза нет
Если ты не можешь опубликовать релиз автоматически, ты НЕ должен останавливаться на полпути.
В этом случае ты обязан:
- подготовить все release assets;
- создать tag локально;
- подготовить точную команду для публикации через GitHub CLI;
- подготовить финальный текст release notes;
- явно перечислить, что уже сделано и что осталось сделать вручную.

12. Команды релиза
Используй подходящий способ, например:
- GitHub Actions release workflow
или
- GitHub CLI

Пример CLI-команды:
gh release create v1.0.0 dist/TerraTesting-win.zip dist/checksums.txt --title "v1.0.0" --notes-file docs/release-notes/v1.0.0.md

13. Финальный отчёт
В самом конце выдай:
- что реализовано;
- какие дефекты исправлены;
- какие файлы ключевые;
- какие тесты пройдены;
- какие артефакты собраны;
- опубликован ли релиз;
- если не опубликован — точные последние ручные шаги.

Начинай с анализа текущего состояния репозитория и gap analysis против файлов AGENTS.md / TASK.md / docs/*.md.
Не ограничивайся обзором — доведи проект до релизного состояния.
```

## Короткая версия
Если нужен совсем короткий запуск, можно использовать и это:

```text
Доведи текущий репозиторий до production-ready v1.0.0 по AGENTS.md, TASK.md и docs/*.md, исправь дефекты, заверши недостающие части, прогони проверки, собери Windows release artifacts, создай tag v1.0.0 и в конце выпусти GitHub Release. Если прав на публикацию нет, подготовь всё до состояния одной финальной команды `gh release create ...`.
```
