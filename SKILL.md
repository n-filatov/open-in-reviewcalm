---
name: open-in-reviewcalm
description: >
  Open a GitHub pull request in the ReviewCalm desktop app from the terminal.
  Use when the user asks to open, view, or review a PR in ReviewCalm, or to
  focus an already-open PR tab in ReviewCalm. Accepts a GitHub PR URL,
  owner/repo#number, owner/repo/pull/number, github.com/<owner>/<repo>/pull/<number>,
  or three args owner repo number. Launches ReviewCalm if it isn't running and
  re-focuses the existing tab if that PR is already open.
---

# open-in-reviewcalm

Open a GitHub PR in the ReviewCalm desktop app — the skill an agent calls when
the user says "open this PR in ReviewCalm".

This skill is a thin wrapper over the `reviewcalm` CLI shipped with the
ReviewCalm app. The CLI builds a `reviewcalm://open?url=<encoded>` deep link and
hands it to macOS `open`; the app's `reviewcalm://` scheme routes the link
through ReviewCalm's `openGitHubPullRequest` flow, which de-duplicates by tab id
— so an already-open PR just gets its tab focused instead of being opened twice.
ReviewCalm is a private macOS desktop app; this skill ships standalone and public
so any agent/user can install and invoke it.

## When to use

- "open PR `<url>` in ReviewCalm"
- "open `<owner>/<repo>#<number>` in ReviewCalm"
- "open this pull request in review calm" / "view in review calm"
- "focus the reviewcalm tab for PR `<number>`"

## Prerequisites (one-time)

ReviewCalm must be installed and have registered its `reviewcalm://` URL scheme,
and the `reviewcalm` CLI must be reachable from this skill.

```sh
# 1. Build + install the app so the reviewcalm:// scheme registers with
#    LaunchServices (ReviewCalm source is private — use the distributed build):
#    place the .app in /Applications and launch it once.

# 2. Put the reviewcalm CLI on your PATH (reviewcalm/scripts/reviewcalm from
#    a ReviewCalm source/release checkout):
ln -sf /path/to/reviewcalm/scripts/reviewcalm /usr/local/bin/reviewcalm
#   or: ln -sf /path/to/reviewcalm/scripts/reviewcalm ~/.local/bin/reviewcalm
#   or: export REVIEWCALM_CLI=/path/to/reviewcalm/scripts/reviewcalm
```

## Install this skill

Install it into any pi skills location (the repo root here IS the skill
directory — it contains `SKILL.md`):

```sh
# Clone anywhere, then symlink the repo dir into a pi skills location:
git clone https://github.com/n-filatov/open-in-reviewcalm.git
ln -sf "$(pwd)/open-in-reviewcalm" ~/.pi/agent/skills/open-in-reviewcalm
#   or, per-project: .pi/skills/open-in-reviewcalm
```

Pi loads skills from `~/.pi/agent/skills/`, `~/.agents/skills/`, project
`.pi/skills/` (after trust), and the `skills` setting. See the pi skills docs.

## Usage

Run the helper from the skill directory, passing a PR reference in any of
these forms:

```sh
./scripts/open-reviewcalm.sh https://github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner/repo#123
./scripts/open-reviewcalm.sh owner/repo/pull/123
./scripts/open-reviewcalm.sh github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner repo 123
```

The helper:

1. Normalizes the reference to a canonical
   `https://github.com/<lowercased-owner>/<lowercased-repo>/pull/<number>` URL
   (owner/repo are case-insensitive on GitHub, so lower-casing guarantees the
   same PR always maps to the same ReviewCalm tab id `<owner>/<repo>#<number>` —
   this is what makes "focus the existing tab" reliable).
2. Validates it (GitHub host, `/pull/<positive integer>`). Incorrect input exits
   non-zero with a single error message.
3. Delegates to the `reviewcalm` CLI (`reviewcalm` on PATH, or `$REVIEWCALM_CLI`),
   which deep-links ReviewCalm open.

### Dry run / inspection

`--validate-only` prints the normalized URL and the deep link without opening
anything — useful for confirming what will be opened:

```sh
./scripts/open-reviewcalm.sh --validate-only https://github.com/Foo/Bar/pull/7/files
# url=https://github.com/foo/bar/pull/7
# deep_link=reviewcalm://open?url=https%3A%2F%2Fgithub.com%2Ffoo%2Fbar%2Fpull%2F7
```

### Self-test

```sh
./scripts/test-open-reviewcalm.sh   # exits 0 if all normalization/validation cases pass
```

The self-test uses `--validate-only`, so it runs anywhere without the ReviewCalm
app or `reviewcalm://` scheme being installed.

## See also

- [README.md](README.md) — install + overview.
- ReviewCalm registers the `reviewcalm://` deep-link scheme via
  `tauri-plugin-deep-link` + a `tauri-plugin-single-instance` deep-link forward,
  and the app focuses the already-running instance / existing tab.