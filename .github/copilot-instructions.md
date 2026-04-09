# CPUMeter — Copilot Instructions

## Versioning

**Always bump the version when making a meaningful commit.**

Meaningful = any commit that changes behavior, fixes a bug, adds a feature, or updates the UI.
Not meaningful = whitespace-only, comment-only, or tooling changes (hooks, CI config).

### Version format: `MAJOR.MINOR`

- `MINOR` bump: new features, UI changes, behavior changes, bug fixes
- `MAJOR` bump: fundamental architectural change or breaking change to user-facing behavior

### Every commit that bumps a version MUST update ALL of these:

1. `CPUMeter/Info.plist` — `CFBundleShortVersionString` key
2. `RELEASE_NOTES.md` — version heading (e.g. `## Version 1.1`)

The settings window reads the version from `Bundle.main` automatically — no code change needed there.

### The pre-commit hook enforces this

`.git/hooks/pre-commit` blocks the commit if the version in docs doesn't match Info.plist.
If you bump the plist but forget the docs, the commit will fail with a clear error message.

### Example workflow

1. Make code changes
2. Bump `CFBundleShortVersionString` in `Info.plist` (e.g. `1.1` → `1.2`)
3. Update the `## Version X.X` heading in `RELEASE_NOTES.md`
4. Commit — hook passes, push
