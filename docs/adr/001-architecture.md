# ADR-001: Application architecture for v1.0

- Status: Accepted
- Date: 2026-03-14

## Decision
Use a layered architecture with explicit separation between:
1. UI layer
2. Application/service layer
3. Persistence layer
4. Sync layer
5. Reporting/utilities layer

## Chosen structure
- `app/`
- `pages/`
- `components/`
- `models/`
- `repositories/`
- `services/`
- `sync/`
- `reports/`
- `config/`
- `utils/`

## Acceptance criteria
- pages remain thin;
- repositories own persistence;
- services own business rules;
- sync logic is isolated;
- tests can exercise core flows without full UI boot.
