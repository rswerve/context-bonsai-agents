# Claude zero-patch proxy prototype — retired

The live-model Stage-C harness was removed after the 2026-07-24 quota incident.
It expanded one apparent test run into four high-context Opus requests.

Both activation paths now refuse unconditionally:

- `migrate.sh` exits `2` without changing state.
- `control.sh enable` exits `2` without changing state.

The correlation/proxy source and retained evidence remain for diagnosis only.
They are not an installable or supported migration path. Rollback, verification,
and retirement actions remain available so an existing state can always be made
safe.

Maz's live Claude installation remains on the existing host-patch implementation.
