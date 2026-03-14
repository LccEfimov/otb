# ADR-003: Release strategy for v1.0.0

- Status: Accepted
- Date: 2026-03-14

## Decision
The first public release is Windows desktop only.

## Release outputs
- Windows packaged build
- source archive
- changelog
- checksums
- release notes

## Release notes policy
Release workflow resolves release notes by tag name:
1. Primary path: `docs/release-notes/<tag>.md` (for example, `docs/release-notes/v1.0.0.md`).
2. Fallback path: `CHANGELOG.md`.
3. If both files are missing, publish job fails on preflight before `gh release create` with a clear actionable error.

## Expected repository structure
- `docs/release-notes/`
  - `v1.0.0.md`
  - `v1.0.1.md`
  - `...`

## Workflow guardrail
`release.yml` includes a preflight step in `publish` job to validate release notes file existence and export the selected path into `RELEASE_NOTES_FILE` for release creation.
