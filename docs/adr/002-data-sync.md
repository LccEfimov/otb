# ADR-002: Offline-first data model and MySQL synchronization

- Status: Accepted
- Date: 2026-03-14

## Decision
We adopt an **offline-first** architecture.

### Primary operational database
SQLite is the primary database used by the application runtime.

### Remote synchronization target
MySQL is an optional remote synchronization target.

### Synchronization triggers
Synchronization attempts happen only in two places:
1. after successful local authentication;
2. after successful test completion and local save.

### Failure handling
If MySQL connection is not configured or is unavailable:
- the user still logs in through SQLite;
- the quiz flow continues normally;
- results remain stored locally;
- synchronization failure is logged;
- records are marked for later retry.
