# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-03-14

### Added
- Windows desktop release target
- local SQLite operational database
- local login/password authentication
- admin and user roles
- user management
- question/category/answer management
- test scheduling
- quiz flow with assignment constraints
- result scoring and pass/fail status
- test history
- PDF and Excel export
- audit logging
- backup utilities
- optional MySQL synchronization
- CI workflows
- release packaging
- route guards for protected pages
- sync monitor with retry actions
- edit flow for users and questions

### Changed
- adopted offline-first architecture
- limited first release to Windows desktop only
- defined sync triggers: after login and after test completion
- settings password change now validates current password
- admin results and sync pages now expose richer filtering and summaries

### Fixed
- primary user flow no longer depends on remote DB availability
- session form state for user/question editing now resets predictably

### Known limitations
- no biometric login
- no gesture control
- no voice control
- no camera monitoring
- no PWA or mobile builds
- no AI adaptive testing
- no complex bidirectional conflict resolution
- no production-grade remote MySQL write schema yet

### Added in iterative scaffolding
- live countdown timer skeleton on quiz page
- assignment edit flow and status updates
- date filters for admin results and reports
- audit entries for sync retry and assignment updates

### Added in scaffold updates
- sync queue model and repository for offline-first retry tracking
- audit log export to PDF and Excel
- shared access helpers for authenticated/user/admin page guards

### Release readiness updates
- added `.env.example` with full environment configuration template
- added CI and release GitHub workflows (`.github/workflows/ci.yml`, `.github/workflows/release.yml`)
- added `scripts/release_bundle.py` to build `dist/TerraTesting-win.zip` and SHA-256 checksums
- обновлено `scripts/build_windows.py чтобы всегда производить выпуск zip/checksums
- documented draft-release publishing flow in README and release notes
