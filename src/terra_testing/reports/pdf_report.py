from __future__ import annotations

from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


def _write_rows(c: canvas.Canvas, title: str, rows: list[dict], formatter) -> None:
    width, height = A4
    y = height - 50
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, y, title)
    y -= 30
    c.setFont("Helvetica", 10)
    for row in rows:
        line = formatter(row)
        c.drawString(50, y, line[:140])
        y -= 18
        if y < 60:
            c.showPage()
            y = height - 50
            c.setFont("Helvetica", 10)
    c.save()


def build_results_pdf(rows: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(output), pagesize=A4)
    _write_rows(
        c,
        "Отчёт по результатам тестирования",
        rows,
        lambda row: f"{row.get('full_name', '')} | {row.get('score_percent', 0)}% | {row.get('status', '')}",
    )


def build_audit_pdf(rows: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(output), pagesize=A4)
    _write_rows(
        c,
        "Журнал аудита",
        rows,
        lambda row: f"{row.get('created_at', '')} | {row.get('event_type', '')} | {row.get('actor', '')} | {row.get('message', '')}",
    )
