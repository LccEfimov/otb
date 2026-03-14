from __future__ import annotations

import flet as ft


class StatCard(ft.Card):
    def __init__(self, title: str, value: str) -> None:
        super().__init__(
            content=ft.Container(
                padding=16,
                content=ft.Column(
                    controls=[
                        ft.Text(title, size=14, color=ft.Colors.GREY_700),
                        ft.Text(value, size=24, weight=ft.FontWeight.BOLD),
                    ]
                ),
            )
        )
