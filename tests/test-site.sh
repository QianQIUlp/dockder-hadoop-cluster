#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="${ROOT_DIR}/site"

pass_count=0
fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}
pass() {
    printf 'PASS: %s\n' "$*"
    pass_count=$((pass_count + 1))
}

assert_file() {
    [[ -f "$1" ]] || fail "missing required site file: ${1#"${ROOT_DIR}/"}"
}

assert_matches() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    grep -Eiq -- "${pattern}" "${file}" || fail "${description}: ${file#"${ROOT_DIR}/"}"
}

assert_not_matches() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if grep -Eiq -- "${pattern}" "${file}"; then
        fail "${description}: ${file#"${ROOT_DIR}/"}"
    fi
}

required_files=(
    "${SITE_DIR}/index.html"
    "${SITE_DIR}/zh/index.html"
    "${SITE_DIR}/404.html"
    "${SITE_DIR}/styles.css"
    "${SITE_DIR}/site.js"
    "${SITE_DIR}/_headers"
    "${SITE_DIR}/favicon.svg"
    "${SITE_DIR}/site.webmanifest"
    "${SITE_DIR}/robots.txt"
)

for required_file in "${required_files[@]}"; do
    assert_file "${required_file}"
done
pass "required Pages files exist"

EN_PAGE="${SITE_DIR}/index.html"
ZH_PAGE="${SITE_DIR}/zh/index.html"
REPOSITORY_URL='https://github.com/QianQIUlp/docker-hadoop-cluster'
HTML_QUOTE_RE="[\"']"

assert_matches "${EN_PAGE}" "<html[^>]*lang=${HTML_QUOTE_RE}en${HTML_QUOTE_RE}" 'English page must declare lang=en'
assert_matches "${ZH_PAGE}" "<html[^>]*lang=${HTML_QUOTE_RE}zh-CN${HTML_QUOTE_RE}" 'Chinese page must declare lang=zh-CN'
pass "page languages are explicit"

for page in "${EN_PAGE}" "${ZH_PAGE}"; do
    assert_matches "${page}" '<title>[^<]+</title>' 'page must have a non-empty title'
    assert_matches "${page}" "<meta[^>]*name=${HTML_QUOTE_RE}description${HTML_QUOTE_RE}[^>]*content=${HTML_QUOTE_RE}[^\"']+${HTML_QUOTE_RE}[^>]*>" 'page must have a meta description'
    assert_matches "${page}" "href=${HTML_QUOTE_RE}${REPOSITORY_URL}([\"'/#?]|$)" 'page must link to the canonical repository'
    assert_not_matches "${page}" 'http://' 'page must not contain insecure HTTP URLs'
    assert_not_matches "${page}" "src=${HTML_QUOTE_RE}https?://" 'scripts and images must not be hotlinked'
done
pass "pages include baseline SEO and repository metadata"

assert_matches "${EN_PAGE}" "href=${HTML_QUOTE_RE}(\\./|/)?styles\\.css${HTML_QUOTE_RE}" 'English page must load the local stylesheet'
assert_matches "${EN_PAGE}" "src=${HTML_QUOTE_RE}(\\./|/)?site\\.js${HTML_QUOTE_RE}" 'English page must load the local script'
assert_matches "${EN_PAGE}" "href=${HTML_QUOTE_RE}(\\./|/)?favicon\\.svg${HTML_QUOTE_RE}" 'English page must load the local favicon'
assert_matches "${EN_PAGE}" "href=${HTML_QUOTE_RE}(\\./|/)?site\\.webmanifest${HTML_QUOTE_RE}" 'English page must load the local manifest'

assert_matches "${ZH_PAGE}" "href=${HTML_QUOTE_RE}(\\.\\./|/)styles\\.css${HTML_QUOTE_RE}" 'Chinese page must load the local stylesheet'
assert_matches "${ZH_PAGE}" "src=${HTML_QUOTE_RE}(\\.\\./|/)site\\.js${HTML_QUOTE_RE}" 'Chinese page must load the local script'
assert_matches "${ZH_PAGE}" "href=${HTML_QUOTE_RE}(\\.\\./|/)favicon\\.svg${HTML_QUOTE_RE}" 'Chinese page must load the local favicon'
assert_matches "${ZH_PAGE}" "href=${HTML_QUOTE_RE}(\\.\\./|/)site\\.webmanifest${HTML_QUOTE_RE}" 'Chinese page must load the local manifest'
pass "pages load local shared assets"

assert_not_matches "${SITE_DIR}/styles.css" "url\\([[:space:]]*${HTML_QUOTE_RE}?https?://" 'stylesheet assets must not be hotlinked'
assert_not_matches "${SITE_DIR}/styles.css" "@import[[:space:]]+(url\\()?${HTML_QUOTE_RE}?https?://" 'stylesheets must not import remote HTTP resources'
assert_not_matches "${SITE_DIR}/site.js" 'https?://' 'site script must not depend on remote HTTP resources'
pass "site assets have no HTTP hotlinks"

NOT_FOUND_PAGE="${SITE_DIR}/404.html"
assert_matches "${NOT_FOUND_PAGE}" "<meta[^>]*name=${HTML_QUOTE_RE}robots${HTML_QUOTE_RE}[^>]*content=${HTML_QUOTE_RE}noindex, nofollow${HTML_QUOTE_RE}" '404 page must not be indexed'
assert_matches "${NOT_FOUND_PAGE}" "href=${HTML_QUOTE_RE}/styles\.css${HTML_QUOTE_RE}" '404 page must load the root stylesheet'
assert_matches "${NOT_FOUND_PAGE}" "href=${HTML_QUOTE_RE}/zh/${HTML_QUOTE_RE}" '404 page must link to the Chinese home page'
assert_not_matches "${NOT_FOUND_PAGE}" "src=${HTML_QUOTE_RE}https?://" '404 scripts and images must not be hotlinked'
pass "custom 404 page preserves static-site semantics"

HEADERS_FILE="${SITE_DIR}/_headers"
assert_matches "${HEADERS_FILE}" '^/\*$' 'headers file must apply policies to every route'
assert_matches "${HEADERS_FILE}" 'Content-Security-Policy:' 'headers file must define a content security policy'
assert_matches "${HEADERS_FILE}" 'Permissions-Policy:' 'headers file must define a permissions policy'
assert_matches "${HEADERS_FILE}" 'X-Content-Type-Options:[[:space:]]*nosniff' 'headers file must prevent MIME sniffing'
assert_matches "${HEADERS_FILE}" 'X-Frame-Options:[[:space:]]*DENY' 'headers file must prevent framing'
assert_not_matches "${HEADERS_FILE}" 'Cache-Control:' 'fixed asset names must use Pages revalidation instead of a stale browser TTL'
pass "Pages security headers are present without stale fixed-asset caching"

printf '%d site checks passed.\n' "${pass_count}"
