from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.services.audit_service import AuditService
from terra_testing.services.report_service import ReportService


def test_audit_exports_are_created(tmp_path, monkeypatch):
    monkeypatch.setenv("EXPORT_DIR", str(tmp_path / "exports"))
    init_db()
    audit_service = AuditService()
    audit_service.log("login_success", "admin", "Успешный вход")

    rows = [
        {
            "created_at": "2026-03-14 10:00",
            "event_type": "login_success",
            "actor": "admin",
            "message": "Успешный вход",
        }
    ]

    report_service = ReportService()
    pdf_path = report_service.export_audit_pdf(rows)
    excel_path = report_service.export_audit_excel(rows)

    assert pdf_path.exists()
    assert excel_path.exists()
