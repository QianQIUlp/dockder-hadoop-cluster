#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

pass_count=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; pass_count=$((pass_count + 1)); }
assert_contains() { grep -Fq "$2" <<<"$1" || fail "expected '$2' in output"; }

output="$("${ROOT_DIR}/hadoop-lab" --help)"
assert_contains "${output}" "lesson list|start|check|reset"
pass "help exposes the learning and recovery surface"

output="$("${ROOT_DIR}/hadoop-lab" version)"
assert_contains "${output}" "Hadoop Lab 2.0.0"
assert_contains "${output}" "Hadoop 3.4.1"
pass "version separates lab and Hadoop versions"

if "${ROOT_DIR}/hadoop-lab" not-a-command >/dev/null 2>&1; then
    fail "unknown command unexpectedly succeeded"
fi
pass "unknown commands fail"

cp "${ROOT_DIR}/hadoop-lab" "${ROOT_DIR}/VERSION" "${ROOT_DIR}/.env.example" "${TEMP_DIR}/"
mkdir -p "${TEMP_DIR}/scripts"
cp "${ROOT_DIR}/scripts/lesson.sh" "${TEMP_DIR}/scripts/"
(
    cd "${TEMP_DIR}"
    ./hadoop-lab init >/dev/null
    [[ -f .env ]]
    before="$(sha256sum .env)"
    ./hadoop-lab init >/dev/null
    after="$(sha256sum .env)"
    [[ "${before}" == "${after}" ]]
) || fail "init did not preserve an existing .env"
pass "init is idempotent and preserves local settings"

mkdir -p "${TEMP_DIR}/bin"
cat > "${TEMP_DIR}/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
    --version) echo 'Docker version 99.0.0, test' ;;
    info) exit 0 ;;
    compose)
        case " $* " in
            *" version "*) echo 'Docker Compose version v99.0.0' ;;
            *" config "*) exit 0 ;;
            *) exit 0 ;;
        esac
        ;;
    ps) exit 0 ;;
    inspect) echo 'missing' ;;
    *) exit 0 ;;
esac
EOF
chmod +x "${TEMP_DIR}/bin/docker"

set +e
json_output="$(cd "${TEMP_DIR}" && PATH="${TEMP_DIR}/bin:${PATH}" ./hadoop-lab status --json 2>/dev/null)"
status_code=$?
set -e
[[ "${status_code}" -ne 0 ]] || fail "stopped JSON status unexpectedly succeeded"
assert_contains "${json_output}" '"overall":"degraded"'
assert_contains "${json_output}" '"name":"hadoop-standalone"'
pass "machine-readable status reports stopped environments as degraded"

set +e
(cd "${TEMP_DIR}" && PATH="${TEMP_DIR}/bin:${PATH}" ./hadoop-lab reset standalone --data </dev/null >/dev/null 2>&1)
status_code=$?
set -e
[[ "${status_code}" -ne 0 ]] || fail "non-interactive data reset succeeded without --yes"
pass "destructive data reset needs explicit confirmation"

printf '%d CLI tests passed.\n' "${pass_count}"
