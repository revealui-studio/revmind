#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$ROOT/scripts/check-no-private-leaks.sh"

# Structural path protection must survive fleet renames without matching variables.
PRIVATE_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$PRIVATE_FIXTURE"' EXIT

expect_scan_status() {
  local expected="$1" status=0
  shift
  bash "$SCAN" "$@" > "$PRIVATE_FIXTURE/output.txt" 2>&1 || status=$?
  if [[ "$status" -ne "$expected" ]]; then
    echo "expected scan status $expected, got $status" >&2
    cat "$PRIVATE_FIXTURE/output.txt" >&2
    exit 1
  fi
}

for fleet in '~/revealfleet' '~/revfleet' '~/suite' '/renamed-fleet_2' '/Fleet.v2' '/x'; do
  printf '%s/%s/docs\n' "$fleet" '.jv' > "$PRIVATE_FIXTURE/note.txt"
  expect_scan_status 1 "$PRIVATE_FIXTURE/note.txt"
  if ! grep -Fq 'private-jv-repo' "$PRIVATE_FIXTURE/output.txt"; then
    cat "$PRIVATE_FIXTURE/output.txt" >&2
    exit 1
  fi
done
for public_path in '~/revealfleet/revealui' '/renamed-fleet_2/docs' '$REVEALFLEET_ROOT/.jv' '$root/.jv' '${fleet}/.jv'; do
  printf '%s\n' "$public_path" > "$PRIVATE_FIXTURE/note.txt"
  expect_scan_status 0 "$PRIVATE_FIXTURE/note.txt"
done

expect_scan_status 2 "$PRIVATE_FIXTURE/missing.txt"
LEAK_JSON=1 expect_scan_status 0 "$PRIVATE_FIXTURE/note.txt"
grep -Fq '"violations":0' "$PRIVATE_FIXTURE/output.txt"

# An interrupted or incomplete scan must fail even when grep emits partial hits.
# Inject only the grep process; leave the production scanner unchanged.
mkdir "$PRIVATE_FIXTURE/bin"
cat > "$PRIVATE_FIXTURE/bin/grep" <<'SH'
#!/usr/bin/env bash
if [[ "$LEAK_TEST_PARTIAL" == 1 ]]; then
  printf '%s:1:partial scan result\n' "$LEAK_TEST_FILE"
fi
exit "$LEAK_TEST_GREP_STATUS"
SH
chmod +x "$PRIVATE_FIXTURE/bin/grep"
for grep_status in 2 3 127; do
  for partial_output in 0 1; do
    for json_mode in '' 1; do
      PATH="$PRIVATE_FIXTURE/bin:$PATH" LEAK_TEST_FILE="$PRIVATE_FIXTURE/note.txt" \
        LEAK_TEST_GREP_STATUS="$grep_status" LEAK_TEST_PARTIAL="$partial_output" \
        LEAK_JSON="$json_mode" expect_scan_status 2 "$PRIVATE_FIXTURE/note.txt"
      grep -Fq '[leak-check] error:' "$PRIVATE_FIXTURE/output.txt"
      if grep -Fq '"violations":' "$PRIVATE_FIXTURE/output.txt"; then
        echo "incomplete scan emitted a completed JSON report" >&2
        exit 1
      fi
    done
  done
done
echo "private planning path and scan failure cases passed"
