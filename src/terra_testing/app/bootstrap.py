from __future__ import annotations

import flet as ft

from terra_testing.app.session_state import SessionState


def bootstrap_app(page: ft.Page) -> None:
    page.session.set("state", SessionState())
