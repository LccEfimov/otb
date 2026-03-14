from __future__ import annotations

import flet as ft


def sync_badge(state: str) -> ft.Container:
    color = {
        "synced": ft.Colors.GREEN_200,
        "pending": ft.Colors.AMBER_200,
        "failed": ft.Colors.RED_200,
    }.get(state, ft.Colors.GREY_200)
    return ft.Container(
        padding=ft.padding.symmetric(horizontal=8, vertical=4),
        bgcolor=color,
        border_radius=8,
        content=ft.Text(state),
    )
