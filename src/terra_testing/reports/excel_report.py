from __future__ import annotations

from pathlib import Path

from openpyxl import Workbook


def build_results_excel(rows: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    wb = Workbook()
    ws = wb.active
    ws.title = "Results"
    ws.append(["Full Name", "Score Percent", "Status", "Sync State", "Completed At"])
    for row in rows:
        ws.append(
            [
                row.get("full_name", ""),
                row.get("score_percent", 0),
                row.get("status", ""),
                row.get("sync_state", ""),
                row.get("completed_at", ""),
            ]
        )
    wb.save(output)


def build_audit_excel(rows: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    wb = Workbook()
    ws = wb.active
    ws.title = "Audit"
    ws.append(["Created At", "Event Type", "Actor", "Message"])
    for row in rows:
        ws.append(
            [
                row.get("created_at", ""),
                row.get("event_type", ""),
                row.get("actor", ""),
                row.get("message", ""),
            ]
        )
    wb.save(output)
