from __future__ import annotations

import flet as ft

from terra_testing.app.bootstrap import bootstrap_app
from terra_testing.app.router import configure_routing
from terra_testing.config.settings import get_settings
from terra_testing.utils.logging import setup_logging


def app_main(page: ft.Page) -> None:
    settings = get_settings()
    page.title = settings.app_name
    page.theme_mode = ft.ThemeMode.LIGHT
    page.window.width = 1200
    page.window.height = 800
    page.window.min_width = 1000
    page.window.min_height = 700

    bootstrap_app(page)
    configure_routing(page)
    page.go("/login")


def main() -> None:
    settings = get_settings()
    setup_logging(settings.log_dir)
    ft.app(target=app_main, view=ft.AppView.FLET_APP)
