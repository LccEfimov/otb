# Deployment Guide

## 1. Назначение
Документ описывает развертывание v1.0.0 для Windows desktop.

## 2. Сценарии эксплуатации
### Сценарий A — локальный
- приложение работает только с SQLite;

### Сценарий B — локальный + синхронизация
- приложение работает через SQLite;
- MySQL подключена как удалённая цель синхронизации;
- sync attempt выполняется после логина и после завершения теста.

## 3. Быстрый деплой
```bash
python -m venv .venv
.venv\Scripts\activate
pip install -U pip
pip install -e .[dev]
copy .env.example .env
alembic upgrade head
python scripts/seed.py
python -m terra_testing
```
