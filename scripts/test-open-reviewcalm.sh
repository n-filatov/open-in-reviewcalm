#!/usr/bin/env bash
#
# Self-test for the open-in-reviewcalm skill helper. Exercises the
# normalization + validation paths (--validate-only) so it can run anywhere
# without the ReviewCalm app or reviewcalm:// scheme being installed.
#
#   ./test-open-reviewcalm.sh   # exit 0 = pass, non-zero = fail
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/open-reviewcalm.sh"

pass=0
fail=0

# expect_ok <description> <expected-normalized-url> <args...>
expect_ok() {
  local desc="$1" expected_url="$2"; shift 2
  local out code
  out=$("$helper" --validate-only "$@" 2>&1) && code=0 || code=$?
  if [ "$code" -ne 0 ]; then
    echo "FAIL: $desc -> exit $code (expected 0). output: $out" >&2
    fail=$((fail + 1)); return
  fi
  local actual_url
  actual_url=$(printf '%s\n' "$out" | sed -n 's/^url=//p')
  if [ "$actual_url" != "$expected_url" ]; then
    echo "FAIL: $desc -> url mismatch" >&2
    echo "  expected: $expected_url" >&2
    echo "  actual:   $actual_url" >&2
    fail=$((fail + 1)); return
  fi
  local actual_deep
  actual_deep=$(printf '%s\n' "$out" | sed -n 's/^deep_link=//p')
  case "$actual_deep" in
    "reviewcalm://open?url="*) ;;
    *)
      echo "FAIL: $desc -> deep_link missing/invalid: $actual_deep" >&2
      fail=$((fail + 1)); return
      ;;
  esac
  pass=$((pass + 1))
}

# expect_fail <description> <args...>
expect_fail() {
  local desc="$1"; shift
  local out code
  out=$("$helper" --validate-only "$@" 2>&1) && code=0 || code=$?
  if [ "$code" -eq 0 ]; then
    echo "FAIL: $desc -> exit 0 (expected non-zero). output: $out" >&2
    fail=$((fail + 1)); return
  fi
  pass=$((pass + 1))
}

# expect_print_link <description> <expected-normalized-url> <args...>
expect_print_link() {
  local desc="$1" expected_url="$2"; shift 2
  local out code expected_deep
  out=$("$helper" --print-link "$@" 2>&1) && code=0 || code=$?
  if [ "$code" -ne 0 ]; then
    echo "FAIL: $desc -> exit $code (expected 0). output: $out" >&2
    fail=$((fail + 1)); return
  fi
  expected_deep=$("$helper" --validate-only "$@" | sed -n 's/^deep_link=//p')
  case "$out" in
    *"Open in ReviewCalm:"*"$expected_deep"*"GitHub PR:"*"$expected_url"*) ;;
    *)
      echo "FAIL: $desc -> printed link output mismatch" >&2
      echo "  expected URL:  $expected_url" >&2
      echo "  expected link: $expected_deep" >&2
      echo "  output:        $out" >&2
      fail=$((fail + 1)); return
      ;;
  esac
  pass=$((pass + 1))
}

expect_ok "full https url" \
  "https://github.com/owner/repo/pull/123" \
  "https://github.com/owner/repo/pull/123"

expect_ok "https url with /files suffix" \
  "https://github.com/owner/repo/pull/123" \
  "https://github.com/owner/repo/pull/123/files"

expect_ok "https url with mixed case + query" \
  "https://github.com/foo/bar/pull/7" \
  "https://github.com/Foo/Bar/pull/7?diff=unified"

expect_ok "www github host" \
  "https://github.com/foo/bar/pull/3" \
  "https://www.github.com/Foo/Bar/pull/3"

expect_ok "owner/repo#number" \
  "https://github.com/owner/repo/pull/7" \
  "owner/repo#7"

expect_ok "github.com path (no scheme)" \
  "https://github.com/foo/bar/pull/42" \
  "github.com/foo/bar/pull/42"

expect_ok "owner/repo/pull/number (no host)" \
  "https://github.com/foo/bar/pull/42" \
  "foo/bar/pull/42"

expect_ok "three positional args" \
  "https://github.com/owner/repo/pull/5" \
  "owner" "repo" "5"

expect_ok "case-insensitive owner/repo normalized to lowercase" \
  "https://github.com/octocat/hello-world/pull/1" \
  "https://github.com/OctoCat/Hello-World/pull/1"

expect_print_link "print-link emits clickable ReviewCalm deep link" \
  "https://github.com/foo/bar/pull/7" \
  "https://github.com/Foo/Bar/pull/7/files"

expect_fail "non-github host"        "https://gitlab.com/foo/bar/pull/1"
expect_fail "issues url, not pull"   "https://github.com/foo/bar/issues/1"
expect_fail "missing pull number"    "foo/bar/pull/"
expect_fail "zero pr number"         "foo/bar#0"
expect_fail "negative pr number"     "foo/bar#-5"
expect_fail "non-numeric # ref"      "foo/bar#abc"
expect_fail "not a url / garbage"    "hello world"
expect_fail "empty arg"              ""
expect_fail "no args provided"

# Zero args: call the helper directly with no args at all.
if $helper --validate-only >/dev/null 2>&1; then
  echo "FAIL: no-args invocation -> exit 0 (expected non-zero)" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

echo "pass=$pass fail=$fail"
if [ "$fail" -ne 0 ]; then
  echo "FAILED $fail test(s)" >&2
  exit 1
fi
exit 0