---
name: open-in-reviewcalm
argument-hint: "[github-pr-url|owner/repo#N]"
description: >
  Open a GitHub pull request in the ReviewCalm desktop app from the terminal.
  With no argument, opens the PR for the current git branch using gh pr view;
  if no PR exists, ask whether to create one. Use when the user asks to open,
  view, or review a PR in ReviewCalm, or to focus an already-open PR tab in
  ReviewCalm. Accepts a GitHub PR URL,
  owner/repo#number, owner/repo/pull/number, github.com/<owner>/<repo>/pull/<number>,
  or three args owner repo number. Launches ReviewCalm if it isn't running and
  re-focuses the existing tab if that PR is already open.
---

# open-in-reviewcalm

Open a GitHub PR in the ReviewCalm desktop app — the skill an agent calls when
the user says "open this PR in ReviewCalm".

This skill normalizes a PR reference, builds a
`reviewcalm://open?url=<encoded>` deep link, and either opens it through the
local browser/URL opener or prints the link for headless/VPS sessions. The app's
`reviewcalm://` scheme routes the link through ReviewCalm's
`openGitHubPullRequest` flow, which de-duplicates by tab id — so an already-open
PR just gets its tab focused instead of being opened twice. ReviewCalm is a
private macOS desktop app; this skill ships standalone and public so any
agent/user can install and invoke it.

## When to use

- "open PR `<url>` in ReviewCalm"
- "open `<owner>/<repo>#<number>` in ReviewCalm"
- "open this pull request in review calm" / "view in review calm"
- "open the current branch PR in ReviewCalm"
- "focus the reviewcalm tab for PR `<number>`"

## Prerequisites (one-time)

ReviewCalm must be installed on the machine where the link will be opened, and
it must have registered its `reviewcalm://` URL scheme. Install/launch the app
once on your local machine.

- On a local machine, the helper opens the link through the local browser/URL
  opener.
- On a VPS/headless agent, the helper prints the `reviewcalm://` link. The user
  can click/copy that link locally; ReviewCalm opens the PR or focuses the
  existing PR tab.

The private ReviewCalm `reviewcalm` CLI is not required for normal use. Legacy
CLI delegation is still available with `--use-cli`.

## Install

See [README.md](README.md) for one-line installs for pi, Claude Code, OpenCode,
Codex, and generic shell-capable agents. Where supported, the install exposes a
slash command:

```text
/open-in-reviewcalm [github-pr-url|owner/repo#N]
```

With no argument, the command opens the PR for the current git branch using
`gh pr view`. If no PR exists, report that and ask whether to create a PR.

Codex currently namespaces custom prompts as `/prompts:open-in-reviewcalm` and
supports skills via `$open-in-reviewcalm` / `/skills` rather than arbitrary
custom top-level slash commands.

## Slash usage

When invoked directly as `/open-in-reviewcalm <PR>`, run the bundled helper with
the supplied PR reference. If the helper has also been symlinked onto PATH,
`open-reviewcalm <PR>` is equivalent. If the helper prints a `reviewcalm://`
link instead of opening it, surface that link to the user so they can click/copy
it on their local machine.

## Usage

Run the helper from the skill directory, passing a PR reference in any of
these forms:

```sh
./scripts/open-reviewcalm.sh                         # current branch PR via gh pr view
./scripts/open-reviewcalm.sh https://github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner/repo#123
./scripts/open-reviewcalm.sh owner/repo/pull/123
./scripts/open-reviewcalm.sh github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner repo 123
```

The helper:

1. If no reference is provided, finds the PR for the current branch with
   `gh pr view --json url --jq .url`. If none exists, asks whether to create a
   PR instead of opening anything.
2. Normalizes the reference to a canonical
   `https://github.com/<lowercased-owner>/<lowercased-repo>/pull/<number>` URL
   (owner/repo are case-insensitive on GitHub, so lower-casing guarantees the
   same PR always maps to the same ReviewCalm tab id `<owner>/<repo>#<number>` —
   this is what makes "focus the existing tab" reliable).
3. Validates it (GitHub host, `/pull/<positive integer>`). Incorrect input exits
   non-zero with a single error message.
4. Builds a `reviewcalm://open?url=<encoded>` deep link.
5. Opens the link through the local browser/URL opener when available; otherwise
   prints a clickable/copyable link for headless/VPS sessions.

### Dry run / inspection

`--print-link` always prints the clickable/copyable ReviewCalm link without
opening anything. `--validate-only` prints the normalized URL and deep link as
machine-readable fields — useful for confirming what will be opened:

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