# open-in-reviewcalm

A [pi](https://github.com/earendil-works/pi-coding-agent) skill that opens a
GitHub pull request in the **ReviewCalm** desktop app from the terminal — the
entry point an agent calls when the user says *"open this PR in ReviewCalm"*.

> **ReviewCalm** is a private macOS desktop app for reviewing GitHub PRs with
> less cognitive load. This skill ships standalone and **public** so any agent
> or user can install and invoke it; it does not contain any ReviewCalm source.
>
> Works with **pi**, **Claude Code**, **Codex**, **OpenCode**, and any agent
> that runs shell — see [Install](#install) for the one-liner per agent and
> slash-command support (`/open-in-reviewcalm` where the agent allows it).

## What it does

Given a GitHub PR reference, it:

1. Normalizes it to a canonical
   `https://github.com/<lowercased-owner>/<lowercased-repo>/pull/<number>` URL
   (owner/repo are case-insensitive on GitHub; lower-casing guarantees the same
   PR always maps to the same ReviewCalm tab id — this is what makes "focus the
   existing tab" reliable).
2. Validates it (GitHub host, `/pull/<positive integer>`).
3. Builds a `reviewcalm://open?url=<encoded>` deep link.
4. If a local browser/URL opener is available, opens that link. If not (for
   example on a VPS/headless agent box), prints the link so you can click or
   copy it on a machine with ReviewCalm installed. ReviewCalm launches the app
   if needed and re-focuses the existing tab if that PR is already open
   (de-duped by tab id).

### Accepted PR reference forms

```sh
./scripts/open-reviewcalm.sh https://github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner/repo#123
./scripts/open-reviewcalm.sh owner/repo/pull/123
./scripts/open-reviewcalm.sh github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner repo 123
```

Default behavior tries to open the ReviewCalm deep link locally. On a
VPS/headless machine it prints a copyable/clickable link instead:

```text
Open in ReviewCalm:
reviewcalm://open?url=https%3A%2F%2Fgithub.com%2Ffoo%2Fbar%2Fpull%2F7
```

`--print-link` always prints the link without opening. `--validate-only` prints
machine-readable normalized fields:

```sh
./scripts/open-reviewcalm.sh --validate-only https://github.com/Foo/Bar/pull/7/files
# url=https://github.com/foo/bar/pull/7
# deep_link=reviewcalm://open?url=https%3A%2F%2Fgithub.com%2Ffoo%2Fbar%2Fpull%2F7
```

## Prerequisites (one-time)

Install ReviewCalm on the machine where the link will be opened, and launch it
once so the `reviewcalm://` URL scheme registers with the OS.

- **Local machine:** the command opens the link through the local browser/URL
  opener.
- **VPS/headless agent:** the command prints the `reviewcalm://` link. Click or
  copy that link on your local machine; ReviewCalm will open/focus the PR tab.

The private ReviewCalm `reviewcalm` CLI is no longer required for normal use.
Legacy CLI delegation is still available with `--use-cli` if you have it.

## Install

The repo root **is** the skill directory (it ships `SKILL.md`). The commands
below install the skill/helper and, where the agent supports custom slash
commands, make this available as:

```text
/open-in-reviewcalm https://github.com/owner/repo/pull/123
```

### pi — `/open-in-reviewcalm`

```sh
mkdir -p ~/.pi/agent/skills ~/.pi/agent/prompts ~/.local/bin && git clone https://github.com/n-filatov/open-in-reviewcalm.git ~/.pi/agent/skills/open-in-reviewcalm && ln -sf ~/.pi/agent/skills/open-in-reviewcalm/scripts/open-reviewcalm.sh ~/.local/bin/open-reviewcalm && ln -sf ~/.pi/agent/skills/open-in-reviewcalm/prompts/open-in-reviewcalm.md ~/.pi/agent/prompts/open-in-reviewcalm.md
```

Pi auto-discovers the skill from `~/.pi/agent/skills/open-in-reviewcalm` and the
slash prompt from `~/.pi/agent/prompts/open-in-reviewcalm.md`, so type
`/open-in-reviewcalm <github-pr-url|owner/repo#N>` in pi.

### Claude Code — `/open-in-reviewcalm`

```sh
mkdir -p ~/.claude/skills ~/.local/bin && git clone https://github.com/n-filatov/open-in-reviewcalm.git ~/.claude/skills/open-in-reviewcalm && ln -sf ~/.claude/skills/open-in-reviewcalm/scripts/open-reviewcalm.sh ~/.local/bin/open-reviewcalm
```

Claude Code auto-loads skills from `~/.claude/skills/<name>/SKILL.md`; the
skill directory name becomes the slash command, so type
`/open-in-reviewcalm <github-pr-url|owner/repo#N>`.

### OpenCode — `/open-in-reviewcalm`

```sh
mkdir -p ~/.local/share ~/.local/bin ~/.config/opencode/commands && git clone https://github.com/n-filatov/open-in-reviewcalm.git ~/.local/share/open-in-reviewcalm && ln -sf ~/.local/share/open-in-reviewcalm/scripts/open-reviewcalm.sh ~/.local/bin/open-reviewcalm && ln -sf ~/.local/share/open-in-reviewcalm/commands/open-in-reviewcalm.md ~/.config/opencode/commands/open-in-reviewcalm.md
```

OpenCode loads global custom commands from `~/.config/opencode/commands/`, so
type `/open-in-reviewcalm <github-pr-url|owner/repo#N>`.

### Codex (OpenAI) — closest supported forms: `/prompts:open-in-reviewcalm` or `$open-in-reviewcalm`

```sh
mkdir -p ~/.agents/skills ~/.local/bin ~/.codex/prompts && git clone https://github.com/n-filatov/open-in-reviewcalm.git ~/.agents/skills/open-in-reviewcalm && ln -sf ~/.agents/skills/open-in-reviewcalm/scripts/open-reviewcalm.sh ~/.local/bin/open-reviewcalm && ln -sf ~/.agents/skills/open-in-reviewcalm/commands/open-in-reviewcalm.md ~/.codex/prompts/open-in-reviewcalm.md
```

Codex supports agent skills from `~/.agents/skills/` and custom prompts from
`~/.codex/prompts/`, but it does **not** currently expose arbitrary top-level
custom commands as `/open-in-reviewcalm`. Use either:

```text
/prompts:open-in-reviewcalm https://github.com/owner/repo/pull/123
$open-in-reviewcalm https://github.com/owner/repo/pull/123
```

### Any other agent (universal)

If an agent only runs shell, install just the helper on `PATH`:

```sh
mkdir -p ~/.local/share ~/.local/bin && git clone https://github.com/n-filatov/open-in-reviewcalm.git ~/.local/share/open-in-reviewcalm && ln -sf ~/.local/share/open-in-reviewcalm/scripts/open-reviewcalm.sh ~/.local/bin/open-reviewcalm
```

Then ask the agent to run `open-reviewcalm <github-pr-url|owner/repo#N>`.

## Run the self-test

```sh
./scripts/test-open-reviewcalm.sh   # exits 0 if all normalization/validation cases pass
```

The self-test uses `--validate-only`, so it runs anywhere without the ReviewCalm
app or `reviewcalm://` scheme being installed.

## Layout

```
open-in-reviewcalm/
├── SKILL.md                      # agent skill instructions (this dir IS the skill)
├── README.md                     # this file
├── commands/
│   └── open-in-reviewcalm.md     # OpenCode/Codex prompt command template
├── prompts/
│   └── open-in-reviewcalm.md     # pi prompt template for /open-in-reviewcalm
└── scripts/
    ├── open-reviewcalm.sh        # normalize + validate + open/print ReviewCalm link
    └── test-open-reviewcalm.sh   # self-test
```

## License

MIT. See [LICENSE](LICENSE).