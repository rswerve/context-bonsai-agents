#!/usr/bin/env bash
# Full certification gate for a source-reconcile candidate.
set -euo pipefail

PARENT="$1"
RUN_DIR="$2"
AM="$PARENT/adoption/auto-maintenance"
TWEAK="$PARENT/tweakcc_context_bonsai"
FIXTURE_INSTALL="$RUN_DIR/certified-runtime"
FIXTURE_HISTORY="$RUN_DIR/certified-runtime-history"

[[ -d "$PARENT/.git" || -f "$PARENT/.git" ]]
[[ -d "$TWEAK/.git" || -f "$TWEAK/.git" ]]
[[ -z "$(git -C "$PARENT" status --porcelain --untracked-files=no)" ]]
[[ -z "$(git -C "$TWEAK" status --porcelain --untracked-files=no)" ]]

(
  cd "$TWEAK"
  bun install --frozen-lockfile
  bun test
  bun run typecheck
)

bun test "$AM/codex/reconcile-codex.test.ts"
zsh -n "$PARENT/adoption/codex/"*.sh "$AM/codex/"*.sh
bash -n "$PARENT/adoption/claude/"*.sh "$AM/"*.sh "$AM/source/"*.sh "$AM/test-support/"*.sh

# Existing fixtures are explicitly forced not to recurse into source syncing.
bash "$AM/source/test-source-reconcile.sh"
CB_SOURCE_DISABLE=1 bash "$AM/test-fixtures.sh"
CB_SOURCE_DISABLE=1 bash "$AM/test-combined.sh"
CB_NOTIFICATION_TEST_ROOT="$RUN_DIR/notification-tests" bash "$AM/test-notifications.sh"
CB_ATTENTION_TEST_ROOT="$RUN_DIR/attention-tests" bash "$AM/test-attention-notification.sh"
CB_INCIDENT_TEST_ROOT="$RUN_DIR/incident-tests" bash "$AM/test-incident-reminder.sh"
"$AM/codex/test-simulated-bumps.sh"

# Prove that the candidate can package and verify an entirely isolated runtime.
CB_INSTALL_ROOT="$FIXTURE_INSTALL" \
CB_RUNTIME_STATE_ROOT="$FIXTURE_HISTORY" \
  "$PARENT/adoption/runtime/install.sh"
CB_INSTALL_ROOT="$FIXTURE_INSTALL" \
  "$PARENT/adoption/runtime/verify.sh"
