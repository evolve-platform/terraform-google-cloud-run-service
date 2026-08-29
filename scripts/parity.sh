#!/usr/bin/env bash
# modules/deploy-managed is a copy of the root module, because lifecycle
# ignore_changes takes a static list and so cannot be made opt-in within one
# module. This keeps the copy honest: every difference between the two is
# recorded in parity.diff, so a fix landing in only one of them fails the check
# instead of going unnoticed.
set -euo pipefail

cd "$(dirname "$0")/.."

GOLDEN="modules/deploy-managed/parity.diff"

render() {
	for f in main.tf variables.tf outputs.tf versions.tf; do
		diff -u --label "a/$f" --label "b/$f" "$f" "modules/deploy-managed/$f" || true
	done
}

case "${1:-check}" in
check)
	if ! render | diff -u "$GOLDEN" - >/dev/null; then
		echo "modules/deploy-managed differs from the root module by more than $GOLDEN records:" >&2
		render | diff -u "$GOLDEN" - >&2 || true
		echo >&2
		echo "Mirror the change into the other copy, or run 'task parity:update' if the new difference is intended." >&2
		exit 1
	fi
	echo "modules/deploy-managed is in parity with the root module"
	;;
update)
	render >"$GOLDEN"
	echo "wrote $GOLDEN"
	;;
*)
	echo "usage: $0 [check|update]" >&2
	exit 2
	;;
esac
