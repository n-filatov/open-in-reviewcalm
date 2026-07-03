#!/usr/bin/env bash
#
# open-reviewcalm.sh — open a GitHub pull request in the ReviewCalm desktop app.
#
# Helper for the `open-in-reviewcalm` agent skill. Normalizes a PR reference into
# a canonical `https://github.com/<owner>/<repo>/pull/<number>` URL and builds a
# `reviewcalm://open?url=<encoded>` deep link. By default it tries to open that
# deep link with the local OS URL opener; on headless machines/VPSes it prints
# the link so the user can click or copy it on a machine with ReviewCalm
# installed.
#
# ReviewCalm focuses the existing tab for that PR when one is already open.
# Canonical form lowers owner/repo to GitHub's case-insensitive casing so the
# same PR always maps to the same ReviewCalm tab id (`owner/repo#number`).
#
# Accepts:
#   open-reviewcalm.sh <github-pr-url>
#   open-reviewcalm.sh <owner>/<repo>#<number>
#   open-reviewcalm.sh <owner>/<repo>/pull/<number>
#   open-reviewcalm.sh github.com/<owner>/<repo>/pull/<number>
#   open-reviewcalm.sh <owner> <repo> <number>
#   open-reviewcalm.sh --validate-only <ref...>  # print URL + deep link, don't open
#   open-reviewcalm.sh --print-link <ref...>     # print clickable/copyable link, don't open
#   open-reviewcalm.sh --use-cli <ref...>        # legacy: delegate to `reviewcalm` CLI
#   open-reviewcalm.sh --help
set -euo pipefail

MODE="auto"
VALIDATE_ONLY=0

usage() {
  cat >&2 <<'EOF'
usage: open-reviewcalm.sh [--validate-only|--print-link|--use-cli] <github-pull-request-ref>
       open-reviewcalm.sh [--validate-only|--print-link|--use-cli] <owner> <repo> <number>

examples:
  open-reviewcalm.sh https://github.com/owner/repo/pull/123
  open-reviewcalm.sh owner/repo#123
  open-reviewcalm.sh owner/repo/pull/123
  open-reviewcalm.sh github.com/owner/repo/pull/123
  open-reviewcalm.sh owner repo 123

options:
  --validate-only  Print normalized url= and deep_link= fields, then exit.
  --print-link     Print a clickable/copyable ReviewCalm deep link, then exit.
  --use-cli        Legacy mode: delegate to the private ReviewCalm `reviewcalm` CLI.
EOF
}

urlencode() {
  local string="$1" length="${#1}" index char
  for (( index = 0; index < length; index++ )); do
    char="${string:index:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) printf '%s' "$char" ;;
      *) printf '%%%02X' "'$char" ;;
    esac
  done
}

# Build a canonical URL from owner/repo/number (all validated before this runs).
build_canonical_url() {
  local owner="$1" repo="$2" number="$3"
  # GitHub owner/repo are case-insensitive; lower-case so the same PR always
  # maps to the same ReviewCalm tab id (`<owner>/<repo>#<number>`).
  printf 'https://github.com/%s/%s/pull/%s\n' \
    "$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')" \
    "$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')" \
    "$number"
}

validate_segments() {
  local owner="$1" repo="$2" number="$3"
  [ -n "$owner" ] && [ -n "$repo" ] && [ -n "$number" ] || { echo "Missing owner, repo, or number." >&2; return 1; }
  case "$owner" in
    *[![:alnum:]._-]*) echo "Owner has invalid characters: $owner" >&2; return 1 ;;
  esac
  case "$repo" in
    *[![:alnum:]._-]*) echo "Repo has invalid characters: $repo" >&2; return 1 ;;
    *) ;;
  esac
  case "$number" in
    *[!0-9]*) echo "PR number must be a positive integer: $number" >&2; return 1 ;;
    0*) [ "$number" = "0" ] && { echo "PR number must be a positive integer: $number" >&2; return 1; } ;;
  esac
  [ "$number" -gt 0 ] 2>/dev/null || { echo "PR number must be a positive integer: $number" >&2; return 1; }
}

# Parse the path portion of a github.com PR URL into owner/repo/number on stdout.
parse_github_path() {
  local path="$1"
  # Drop any query string or fragment.
  path="${path%%#*}"
  path="${path%%\?*}"
  # Strip leading slashes.
  while [ "${path#/}" != "$path" ]; do path="${path#/}"; done
  # Split on '/'. We read enough segments for either:
  #   github.com/<owner>/<repo>/pull/<number>[/<rest>]
  #   <owner>/<repo>/pull/<number>[/<rest>]
  local seg1 seg2 seg3 seg4 seg5 rest
  IFS='/' read -r seg1 seg2 seg3 seg4 seg5 rest <<<"$path"
  if [ "$seg1" = "github.com" ] || [ "$seg1" = "www.github.com" ]; then
    # github.com/<owner>/<repo>/pull/<number>
    [ "$seg4" = "pull" ] || { echo "Not a pull request URL (expected /pull/<number>)." >&2; return 1; }
    local number="${seg5%%/*}"
    printf '%s\t%s\t%s\n' "$seg2" "$seg3" "$number"
  elif [ "$seg3" = "pull" ]; then
    # <owner>/<repo>/pull/<number> (no host)
    local number="${seg4%%/*}"
    printf '%s\t%s\t%s\n' "$seg1" "$seg2" "$number"
  else
    echo "Could not parse pull request path: $path" >&2
    return 1
  fi
}

print_reviewcalm_link() {
  local url="$1" deep_link="$2"
  cat <<EOF
Open in ReviewCalm:
$deep_link

GitHub PR:
$url
EOF
}

# Resolve the reviewcalm CLI for legacy --use-cli mode, in priority order:
#   1. $REVIEWCALM_CLI  (explicit override, e.g. /path/to/reviewcalm)
#   2. `reviewcalm`      on PATH (the old install: symlink scripts/reviewcalm)
resolve_reviewcalm_cli() {
  if [ -n "${REVIEWCALM_CLI:-}" ] && [ -x "$REVIEWCALM_CLI" ]; then
    printf '%s' "$REVIEWCALM_CLI"
    return 0
  fi
  if command -v reviewcalm >/dev/null 2>&1; then
    command -v reviewcalm
    return 0
  fi
  return 1
}

has_graphical_session() {
  case "$(uname -s 2>/dev/null || printf unknown)" in
    Darwin*) return 0 ;;
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
  esac

  [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${MIR_SOCKET:-}" ]
}

open_deep_link() {
  local deep_link="$1"
  local uname_s
  uname_s="$(uname -s 2>/dev/null || printf unknown)"

  case "$uname_s" in
    Darwin*)
      command -v open >/dev/null 2>&1 && open "$deep_link" >/dev/null 2>&1
      return $?
      ;;
    MINGW*|MSYS*|CYGWIN*)
      command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c start "" "$deep_link" >/dev/null 2>&1
      return $?
      ;;
  esac

  # WSL can open links on the Windows host even without Linux DISPLAY/WAYLAND.
  if command -v wslview >/dev/null 2>&1; then
    wslview "$deep_link" >/dev/null 2>&1 && return 0
  fi

  # On normal Linux desktops, xdg-open/gio will hand the custom scheme to the
  # registered handler. On headless VPSes, skip noisy open attempts and print.
  if has_graphical_session; then
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$deep_link" >/dev/null 2>&1 && return 0
    fi
    if command -v gio >/dev/null 2>&1; then
      gio open "$deep_link" >/dev/null 2>&1 && return 0
    fi
    if [ -n "${BROWSER:-}" ]; then
      "$BROWSER" "$deep_link" >/dev/null 2>&1 && return 0
    fi
  fi

  return 1
}

main() {
  local args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --validate-only) VALIDATE_ONLY=1; shift ;;
      --print-link|--no-open) MODE="print"; shift ;;
      --use-cli) MODE="cli"; shift ;;
      --) shift; while [ "$#" -gt 0 ]; do args+=("$1"); shift; done ;;
      -*) echo "Unknown option: $1" >&2; usage; exit 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- "${args[@]+"${args[@]}"}"

  if [ "$#" -eq 0 ]; then
    echo "No pull request reference provided." >&2
    usage
    exit 2
  fi

  local owner repo number ref
  if [ "$#" -eq 3 ]; then
    owner="$1"; repo="$2"; number="$3"
  else
    # Single-ref forms. Re-join in case the URL lost its spaces through quoting.
    ref="$*"
    # `parsed` holds the three owner/repo/number lines on success, or the
    # single error message on failure. Capturing stdout+stderr lets us surface
    # exactly one clean error and stop instead of cascading into validate_segments.
    local parsed parse_input
    case "$ref" in
      http://*|https://*)
        # Strip the scheme, then parse github.com/<owner>/<repo>/pull/<number>.
        parse_input="$ref"
        parse_input="${parse_input#http://}"
        parse_input="${parse_input#https://}"
        if ! parsed="$(parse_github_path "$parse_input" 2>&1)"; then
          echo "$parsed" >&2
          exit 2
        fi
        IFS=$'\t' read -r owner repo number <<<"$parsed"
        ;;
      github.com/*|www.github.com/*|*/*/pull/*)
        if ! parsed="$(parse_github_path "$ref" 2>&1)"; then
          echo "$parsed" >&2
          exit 2
        fi
        IFS=$'\t' read -r owner repo number <<<"$parsed"
        ;;
      */*#[0-9]*)
        # owner/repo#number (no host)
        local rest="${ref%%#*}"
        owner="${rest%%/*}"
        repo="${rest#*/}"
        number="${ref##*#}"
        ;;
      *)
        echo "Unrecognized pull request reference: $ref" >&2
        usage
        exit 2
        ;;
    esac
  fi

  if ! validate_segments "$owner" "$repo" "$number"; then
    exit 2
  fi

  local url deep_link
  url="$(build_canonical_url "$owner" "$repo" "$number")"
  deep_link="reviewcalm://open?url=$(urlencode "$url")"

  if [ "$VALIDATE_ONLY" -eq 1 ]; then
    printf 'url=%s\n' "$url"
    printf 'deep_link=%s\n' "$deep_link"
    exit 0
  fi

  if [ "$MODE" = "print" ]; then
    print_reviewcalm_link "$url" "$deep_link"
    exit 0
  fi

  if [ "$MODE" = "cli" ]; then
    local cli
    if ! cli="$(resolve_reviewcalm_cli)"; then
      echo "Could not find the reviewcalm CLI." >&2
      echo "Either symlink it onto your PATH once (from a ReviewCalm checkout):" >&2
      echo "  ln -sf /path/to/reviewcalm/scripts/reviewcalm /usr/local/bin/reviewcalm" >&2
      echo "or set REVIEWCALM_CLI=/path/to/reviewcalm." >&2
      echo "Tip: omit --use-cli to use this helper's built-in deep-link opener/print fallback." >&2
      exit 1
    fi
    exec "$cli" "$url"
  fi

  if open_deep_link "$deep_link"; then
    printf 'Opened in ReviewCalm: %s\n' "$url"
    exit 0
  fi

  echo "No local browser/URL opener detected; open this link on a machine with ReviewCalm installed:"
  print_reviewcalm_link "$url" "$deep_link"
}

main "$@"
