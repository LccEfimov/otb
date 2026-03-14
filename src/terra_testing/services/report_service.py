from __future__ import annotations

from pathlib import Path

from terra_testing.config.settings import get_settings
from terra_testing.reports.excel_report import build_audit_excel, build_results_excel
from terra_testing.reports.pdf_report import build_audit_pdf, build_results_pdf


class ReportService:
    def __init__(self) -> None:
        self.settings = get_settings()

    def export_results_pdf(self, rows: list[dict], filename: str = "results_report.pdf") -> Path:
        output = self.settings.export_dir / filename
        build_results_pdf(rows, output)
        return output

    def export_results_excel(self, rows: list[dict], filename: str = "results_report.xlsx") -> Path:
        output = self.settings.export_dir / filename
        build_results_excel(rows, output)
        return output

    def export_audit_pdf(self, rows: list[dict], filename: str = "audit_report.pdf") -> Path:
        output = self.settings.export_dir / filename
        build_audit_pdf(rows, output)
        return output

    def export_audit_excel(self, rows: list[dict], filename: str = "audit_report.xlsx") -> Path:
        output = self.settings.export_dir / filename
        build_audit_excel(rows, output)
        return output
